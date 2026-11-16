extends Node

# The launch take (world 1 unit 17): the cut from pilot select or the camp's launch gate into the dam happens under one
# comic swipe, so the lead-in reads as a single take with no hard cut and no black frame. A play runs four phases:
#   wind    the world it leaves moves first (the title camera lifts, or the gate fires the ball), WIND_S
#   cover   a sand panel with amber speed lines sweeps in from the bottom left, COVER_S, a whoosh on its way
#   hold    on the first fully covered frame on_cover runs (the run starts, the ball is placed over the dam); the panel
#           stays, speed lines turning and FWOOSH! stamped, until ready_check() says the dam is drawn, HOLD_MIN_S to HOLD_MAX_S
#   reveal  the panel sweeps on out through the top right, REVEAL_S, over the ball already dropping in
# Reduced motion keeps the panel still (no lines turning, no camera move) and shortens the wind to nothing.
# A stage launch (flow.gd, dam to flume and flume to the Slag Bowl) rides the same take with play_over_flight: the cannon
# shot is the wind, so the player watches it go, the panel closes over the flight's last COVER_S, and on_cover waits for
# cover_gate (the flight's end). The launch has stamped its own word, so this take stamps none, except the part a reward
# gate just gave: its name and family glyph in its rarity colour, so the gate that vanished on the take is confirmed (PF-22).
#
# Only a played game runs it: bots, tests and every headless run call on_cover at once (live is false), so run timing
# and every run-start test stay as they were. A test sets live (and steps it with advance()) to drive the phases.

const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const SHADER := preload("res://src/presentation/launch_take.gdshader")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Icons := preload("res://src/ui/icons.gd")

enum { IDLE, WIND, COVER, HOLD, REVEAL }

const WIND_S := 0.45
const COVER_S := 0.24
const HOLD_MIN_S := 0.1
const HOLD_MAX_S := 1.5
const REVEAL_S := 0.34
const SPIN_RATE := 0.9
const WORD := "FWOOSH!"
# Above the screens (5) and the HUD's achievement layer, under the boot card (128).
const LAYER := 120

signal covered
signal finished

var live := false
# A test drives the take in a headless game: game._take_live() reads this.
var force_live := false
var reduced_motion := false
var phase := IDLE
var shown_ms := 0
var _t := 0.0
var _on_cover := Callable()
var _ready_check := Callable()
var _cover_gate := Callable()
var _wind_s := WIND_S
var _wordless := false
var _layer: CanvasLayer
var _panel: ColorRect
var _word: Label
var _glyph: TextureRect
var _material: ShaderMaterial


func _ready() -> void:
	name = "LaunchTake"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.visible = false
	add_child(_layer)
	_panel = ColorRect.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("base", Palette.SAND)
	_material.set_shader_parameter("streak", Palette.AMBER)
	_material.set_shader_parameter("ink", Palette.CHARCOAL)
	_panel.material = _material
	_layer.add_child(_panel)
	_word = Label.new()
	_word.text = WORD
	_word.set_anchors_preset(Control.PRESET_CENTER)
	_word.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_word.grow_vertical = Control.GROW_DIRECTION_BOTH
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.add_theme_font_size_override("font_size", 96)
	_word.add_theme_color_override("font_color", Palette.CHARCOAL)
	_word.add_theme_color_override("font_outline_color", Palette.AMBER)
	_word.add_theme_constant_override("outline_size", 18)
	var font: Font = UiFonts.bold()
	if font != null:
		_word.add_theme_font_override("font", font)
	_word.rotation = -0.12
	_word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_word)
	_glyph = TextureRect.new()
	_glyph.name = "PartGlyph"
	_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.visible = false
	_word.add_child(_glyph)
	_set_progress(0.0)
	set_process(false)


func busy() -> bool:
	return phase != IDLE


# Runs wind (once, at the start), then the swipe, calling on_cover under full cover. ready_check() is polled through the hold.
# Not live, on_cover runs now and nothing shows. Returns true when the take plays.
func play(on_cover: Callable, wind := Callable(), ready_check := Callable()) -> bool:
	return _begin(on_cover, wind, ready_check, Callable(), 0.0 if HighdraftFx.preferred else WIND_S, false)


# The take over a cannon shot of flight_s: the shot is the wind, so the panel waits and closes over the flight's last
# COVER_S, and on_cover waits at full cover until cover_gate() says the flight is over. Then the same hold and reveal as
# play. No word: the launch stamped its own. With a taken part's id, the stamp is that part's name and glyph; "" keeps it wordless.
func play_over_flight(on_cover: Callable, cover_gate: Callable, ready_check := Callable(), flight_s := 0.0, taken_part := "") -> bool:
	return _begin(on_cover, Callable(), ready_check, cover_gate, maxf(0.0, flight_s - COVER_S), true, taken_part)


func _begin(on_cover: Callable, wind: Callable, ready_check: Callable, cover_gate: Callable, wind_s: float, wordless: bool, taken_part := "") -> bool:
	if busy():
		return false
	if not live:
		on_cover.call()
		finished.emit()
		return false
	reduced_motion = HighdraftFx.preferred
	_on_cover = on_cover
	_ready_check = ready_check
	_cover_gate = cover_gate
	_wind_s = wind_s
	var stamped := _dress_word(taken_part)
	_wordless = wordless and not stamped
	_t = 0.0
	_layer.visible = true
	_set_progress(0.0)
	_material.set_shader_parameter("lines", 0.0 if reduced_motion else 1.0)
	phase = WIND if wind_s > 0.0 else COVER
	if wind.is_valid():
		wind.call()
	set_process(true)
	return true


# The part a gate gave, told after the take began (the launch can start before the gate's event reaches its owner).
func stamp_taken(part_id: String) -> void:
	if phase == IDLE or part_id == "":
		return
	if _dress_word(part_id):
		_wordless = false


# The stamp's look: FWOOSH! as ever, or the taken part's name and family glyph in its rarity colour.
# True when it stamps a part.
func _dress_word(taken_part: String) -> bool:
	var look := RewardGates.taken_look(taken_part) if taken_part != "" else {}
	_word.text = String(look["name"]) if not look.is_empty() else WORD
	var color: Color = look["color"] if not look.is_empty() else Palette.CHARCOAL
	_word.add_theme_color_override("font_color", color)
	_word.add_theme_color_override("font_outline_color", Palette.CHARCOAL if not look.is_empty() else Palette.AMBER)
	var icon := String(look.get("icon", ""))
	_glyph.visible = icon != ""
	if icon != "":
		var side := 96.0
		_glyph.texture = Icons.texture(icon)
		_glyph.modulate = Icons.tint(icon, color)
		_glyph.size = Vector2(side, side)
		var extent := _word.get_minimum_size()
		_glyph.position = Vector2(-side - 16.0, (extent.y - side) * 0.5)
	return not look.is_empty()


func _process(delta: float) -> void:
	advance(minf(delta, 1.0 / 30.0))


# One step of the take. A hitch counts for at most 1/30 s, so a slow frame never skips the cover.
func advance(delta: float) -> void:
	if phase == IDLE:
		return
	_t += delta
	var vp_size := _layer.get_viewport().get_visible_rect().size if _layer.is_inside_tree() else Vector2(16.0, 9.0)
	_material.set_shader_parameter("aspect", vp_size.x / maxf(1.0, vp_size.y))
	if not reduced_motion:
		_material.set_shader_parameter("spin", _t * SPIN_RATE)
	match phase:
		WIND:
			if _t >= _wind_s:
				_next(COVER)
		COVER:
			_set_progress(minf(1.0, _t / COVER_S))
			if _t >= COVER_S and (not _cover_gate.is_valid() or bool(_cover_gate.call())):
				_next(HOLD)
				_cover()
		HOLD:
			_set_progress(1.0)
			var drawn: bool = not _ready_check.is_valid() or bool(_ready_check.call())
			if (_t >= HOLD_MIN_S and drawn) or _t >= HOLD_MAX_S:
				_next(REVEAL)
		REVEAL:
			_set_progress(1.0 + minf(1.0, _t / REVEAL_S))
			if _t >= REVEAL_S:
				_end()


func _next(next: int) -> void:
	phase = next
	_t = 0.0


func _cover() -> void:
	var call := _on_cover
	_on_cover = Callable()
	if call.is_valid():
		call.call()
	shown_ms = Time.get_ticks_msec()
	covered.emit()


func _end() -> void:
	phase = IDLE
	_ready_check = Callable()
	_cover_gate = Callable()
	_dress_word("")
	_layer.visible = false
	_set_progress(0.0)
	set_process(false)
	finished.emit()


# The word stamps in at full cover and is gone before the panel starts to leave.
func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)
	var stamp := clampf((value - 0.7) / 0.3, 0.0, 1.0) * clampf((1.25 - value) / 0.15, 0.0, 1.0)
	_word.visible = stamp > 0.0 and not _wordless
	_word.modulate.a = stamp
	_word.scale = Vector2.ONE * (1.0 if reduced_motion else lerpf(1.35, 1.0, stamp))
	_word.pivot_offset = _word.size * 0.5


func covering() -> bool:
	return phase == HOLD


func progress() -> float:
	return float(_material.get_shader_parameter("progress"))
