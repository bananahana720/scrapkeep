extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Palette := preload("res://src/core/palette.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# The bottom-centre skill bar (design-v3/SKILL-BAR.md section 5): the numbered slots 1, 2 and 3
# (weapon, special, line skill), then CHIP_GAP to the right the two chips (Shift and Ctrl) at
# CHIP_SCALE with no number, one per published slot record (ability_slots.gd), key glyph under
# each, charge pips under the key. Each state reads by more than colour: ready is a bright
# solid frame, cooling is a petrol wedge that shrinks clockwise from twelve under a
# dimmed icon and a sand hand, active is a doubled frame, a 3 px lift and the class tint, unavailable is a
# faded icon struck through. A slot whose cooldown ends swells once, with a rim flash and its
# class shape flaring in the class colour. State colours come from event_kinds' v2 W1 UI rows;
# the icon's accent is the class colour (VISUAL-LANGUAGE.md section 7). A slot whose key a
# prompt on screen already shows draws no keycap while it does (hide_keys), so one key is
# never drawn twice.
#
# Selection is not the active frame. The selected slot (the one left click casts) wears an
# inverted keycap (sand fill, charcoal digit) and the mouse glyph above it: the LMB picture,
# no letters, literally where left click goes. A pick slides the glyph there in GLYPH_SLIDE
# seconds and a snap-back slides it home; its underline drains over the pick's timeout. A
# refused pick shakes the slot SHAKE px and flashes slate, and the glyph stays. A loaded line
# skill wears a hook badge in the class colour on slot 3. During the set piece the bar's marks
# dim to SET_PIECE_ALPHA, because its keys are swallowed, but each slot keeps a solid plate
# behind it, so the row reads as switched off and never as gone (w37 film 059, PF-21).
#
# A slot that cannot fire shows why (PF-21, w37 film 014 and 022): a cooldown is a clock, the
# wedge with a sand hand at its edge and the icon over it, so the slot is never a blank grey
# square; an empty charge that time does not refill (refill "contact", Tally's pressure) is a
# dashed frame over hollow pips, the same hollow pips its pool slot wears, and no clock.

const SLOT := UiTokens.TARGET
const GAP := float(UiTokens.GAP_M)
const KEY_GAP := float(UiTokens.GAP_XS)
const KEY_H := 20.0
const PIP := 3.0
const PIP_GAP := float(UiTokens.GAP_XS)
const PULSE_SECONDS := 0.18
const PULSE_SCALE := 0.12
const SWEEP_STEP := TAU / 64.0
const NUMBERED := 3
const CHIP_SCALE := 0.75
const CHIP_GAP := float(UiTokens.GAP_XL)
const GLYPH_SLIDE := 0.12
const GLYPH_H := 18.0
const GLYPH_GAP := float(UiTokens.GAP_S)
const UNDERLINE := 2.0
const SHAKE := 3.0
const SHAKE_TIME := 0.25
const SHAKE_HZ := 40.0
const BADGE := 18.0
const SET_PIECE_ALPHA := 0.4
const HAND := 2.0
const DASHES := 4

# Reduced motion (Game.set_reduced_motion keeps it current): a refused pick no longer shakes.
static var reduced_motion := false
var slots: Array = []
var tint := Color.WHITE
# The class row's shape (ring, chevron, burst): the ready swell and the charge pips wear
# it, so the bar speaks in the class's motif.
var motif := "ring"
# A line skill waits for the next bite (combat.line_load()): slot 3 wears the hook badge.
var line_loaded := false:
	set(value):
		if value != line_loaded:
			line_loaded = value
			queue_redraw()
# The set piece runs: the bar dims, since every key on it is swallowed.
var set_piece := false:
	set(value):
		if value == set_piece:
			return
		set_piece = value
		self_modulate.a = SET_PIECE_ALPHA if value else 1.0
		_plates.visible = value
		_plates.queue_redraw()
# The mouse glyph's centre x in bar space; it slides toward the selected slot's centre.
var glyph_x := -1.0
var _glyph_from := 0.0
var _glyph_to := -1.0
var _glyph_t := GLYPH_SLIDE
var _refusals := {}
var _clock := 0.0
var _hidden: Array[String] = []
var _pulses := {}
var _last_state := {}
var _shown: Array = []
var _was_pulsing := false
var _refund_pending := {}
var _refund_flashes := {}
var _refund_count := 0
# The set piece's solid plates behind the dimmed slots: a child, so self_modulate leaves it whole.
var _plates := Plates.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plates.bar = self
	add_child(_plates)


class Plates:
	extends Control

	var bar

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		visible = false

	func _draw() -> void:
		var rects: Dictionary = bar.slot_rects()
		for name in rects:
			var back := StyleBoxFlat.new()
			back.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
			back.set_corner_radius_all(int(UiTokens.RADIUS * (rects[name] as Rect2).size.x / SLOT))
			draw_style_box(back, rects[name])


# Whether the set piece's solid plates are up behind the dimmed slots.
func plates_shown() -> bool:
	return _plates.visible


# Why a slot cannot fire, as the bar draws it: "clock" for a cooldown, "empty" for a drained
# charge that only contact refills, "" for a slot that can (or is struck through as unavailable).
static func slot_reason(entry: Dictionary) -> String:
	if entry.get("state", "") != "cooling":
		return ""
	return "empty" if String(entry.get("refill", "time")) == "contact" else "clock"


# The pips an empty slot shows: its pool's, so a drained slot 2 wears slot 1's empty pips.
func pool_pips(entry: Dictionary) -> int:
	var pool := String(entry.get("pool", slot_name(entry)))
	for other in slots:
		if slot_name(other) == pool:
			return int(other["max_charges"])
	return int(entry["max_charges"])


# The bar's size for `count` published slots: up to NUMBERED numbered slots, the rest chips.
static func bar_size(count := NUMBERED + 2) -> Vector2:
	var n := clampi(count, 1, NUMBERED)
	var chips := maxi(count - NUMBERED, 0)
	var width := n * SLOT + (n - 1) * GAP
	if chips > 0:
		width += CHIP_GAP + chips * SLOT * CHIP_SCALE + (chips - 1) * GAP * CHIP_SCALE
	return Vector2(width, SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP * 2.0)


static func is_chip(entry: Dictionary) -> bool:
	return entry.get("group", "bar") == "chip"


static func slot_name(entry: Dictionary) -> String:
	return String(entry.get("slot", entry.get("id", "")))


# Each slot's resting rect in bar space, by slot name: the numbered slots left to right, then
# the chips CHIP_GAP further on at CHIP_SCALE, centred on the slot row.
func slot_rects() -> Dictionary:
	var out := {}
	var x := 0.0
	var prev := ""
	for entry in slots:
		var chip := is_chip(entry)
		if prev == "chip":
			x += GAP * CHIP_SCALE
		elif prev == "bar":
			x += CHIP_GAP if chip else GAP
		var side := SLOT * CHIP_SCALE if chip else SLOT
		out[slot_name(entry)] = Rect2(Vector2(x, (SLOT - side) * 0.5), Vector2(side, side))
		x += side
		prev = "chip" if chip else "bar"
	return out


func update_slots(list: Array, class_tint: Color, class_shape := "ring") -> void:
	var shape := class_shape if class_shape != "" else "ring"
	var changed := class_tint != tint or shape != motif or list != _shown
	tint = class_tint
	motif = shape
	var swelled := false
	for entry in list:
		var id: String = entry["id"]
		if entry["state"] == "ready" and _last_state.get(id, "ready") == "cooling":
			_pulses[id] = PULSE_SECONDS
			swelled = true
		_last_state[id] = entry["state"]
	if swelled:
		_ring_ready()
	slots = list
	if changed:
		# A deep copy: the reading is compared next frame, and a source that mutates its
		# entries in place must still look different.
		_shown = list.duplicate(true)
		custom_minimum_size = bar_size(list.size())
		size = custom_minimum_size
		_plates.size = size
		if _plates.visible:
			_plates.queue_redraw()
		queue_redraw()


# The swell's sound: ability_ready's row resolves to the class's ready pulse, the
# motif's first note, so the bar is where the class tune is first heard. The bar sits
# in the HUD, whose game reaches the audio director.
func _ring_ready() -> void:
	var hud := get_parent()
	var game = hud.get("game") if hud != null else null
	var presentation = game.get("presentation") if game != null else null
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null and audio.has_method("play"):
		audio.play("ability_ready", 0.0, 1.0, "UI")


# The key glyphs of the prompts on screen this tick: a slot on one of them hides its keycap.
func hide_keys(glyphs: Array[String]) -> void:
	if glyphs == _hidden:
		return
	_hidden = glyphs.duplicate()
	queue_redraw()


# The prompts' live glyphs (key_glyphs.shown_glyphs), read wherever the bar answers what it
# shows, so a prompt that appears on a physics tick hides the bar's cap on that same tick and
# a key is never drawn twice between the prompt step and the next HUD frame.
var hidden_source := Callable()


func key_hidden(entry: Dictionary) -> bool:
	if hidden_source.is_valid():
		return entry["key"] in hidden_source.call()
	return entry["key"] in _hidden


func pulse_left(id: String) -> float:
	return _pulses.get(id, 0.0)


func cooldown_refunded(record: Dictionary) -> void:
	if record.get("kind", "") != "cooldown_refunded":
		return
	var slot := String(record.get("slot", ""))
	if not slots.any(func(entry): return slot_name(entry) == slot):
		return
	_refund_pending[slot] = int(_refund_pending.get(slot, 0)) + 1


func refund_flash_count() -> int:
	return _refund_count


func refund_flash_left(slot: String) -> float:
	return _refund_flashes.get(slot, 0.0)


func _step_refunds(delta: float) -> void:
	var was_flashing := not _refund_flashes.is_empty()
	var hud := get_parent()
	var game = hud.get("game") if hud != null else null
	if game != null and game.player != null:
		for record in game.player.abilities.drain_refunds():
			cooldown_refunded(record)
	for slot in _refund_flashes.keys():
		_refund_flashes[slot] = maxf(0.0, float(_refund_flashes[slot]) - delta)
		if _refund_flashes[slot] <= 0.0:
			_refund_flashes.erase(slot)
	for slot in _refund_pending.keys():
		if refund_flash_left(slot) > 0.0:
			continue
		_refund_flashes[slot] = PULSE_SECONDS
		_refund_count += 1
		_refund_pending[slot] -= 1
		if _refund_pending[slot] <= 0:
			_refund_pending.erase(slot)
	if not _refund_flashes.is_empty() or was_flashing:
		queue_redraw()


# A pick the ball refused: the slot shakes and flashes slate for SHAKE_TIME.
func refuse(slot: String) -> void:
	_refusals[slot] = SHAKE_TIME
	queue_redraw()


func shake_offset(slot: String) -> Vector2:
	if reduced_motion or _refusals.get(slot, 0.0) <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_clock * TAU * SHAKE_HZ) * SHAKE, 0.0)


func flash_color(slot: String) -> Color:
	return Color(Palette.SLATE, FlashGuard.info(clampf(_refusals.get(slot, 0.0) / SHAKE_TIME, 0.0, 1.0)))


func badge_shown() -> bool:
	return line_loaded and slot_rects().has("line")


func selected_entry() -> Dictionary:
	for entry in slots:
		if entry.get("selected", false):
			return entry
	return {}


# The underline under the mouse glyph: the share of the pick's timeout still to run.
func underline_share() -> float:
	return float(selected_entry().get("select_left", 0.0))


# Where the glyph is headed: the selected slot's centre, else slot 1's.
func glyph_target() -> float:
	var rects := slot_rects()
	var entry := selected_entry()
	var name := slot_name(entry) if not entry.is_empty() else (slot_name(slots[0]) if not slots.is_empty() else "")
	return (rects[name] as Rect2).get_center().x if rects.has(name) else 0.0


# How a slot draws, as data, so selected and active read apart by more than one cue: the
# keycap's fill and digit colour, the lift, whether the frame doubles and whether the mouse
# glyph rides it.
func slot_look(entry: Dictionary) -> Dictionary:
	var state: String = entry["state"]
	var selected: bool = entry.get("selected", false)
	var active := state == "active"
	var ink: Color = tint if active else Color(UiTokens.TEXT, 0.5 if state == "unavailable" else 0.95)
	return {"cap_fill": UiTokens.TEXT if selected else Color(UiTokens.INK, UiTokens.PLATE_ALPHA),
		"cap_ink": UiTokens.INK if selected else ink, "lift": 3.0 if active else 0.0, "doubled": active,
		"glyph": selected}


func step(delta: float) -> void:
	_step_refunds(delta)
	_clock += delta
	for id in _pulses.keys():
		_pulses[id] = maxf(0.0, _pulses[id] - delta)
		if _pulses[id] <= 0.0:
			_pulses.erase(id)
	var refusing := not _refusals.is_empty()
	for slot in _refusals.keys():
		_refusals[slot] = _refusals[slot] - delta
		if _refusals[slot] <= 0.0:
			_refusals.erase(slot)
	var target := glyph_target()
	var gliding := _glyph_t < GLYPH_SLIDE
	if glyph_x < 0.0:
		glyph_x = target
		_glyph_to = target
	elif not is_equal_approx(target, _glyph_to):
		_glyph_from = glyph_x
		_glyph_to = target
		_glyph_t = 0.0
		gliding = true
	if _glyph_t < GLYPH_SLIDE:
		_glyph_t = minf(GLYPH_SLIDE, _glyph_t + delta)
		glyph_x = lerpf(_glyph_from, _glyph_to, smoothstep(0.0, 1.0, _glyph_t / GLYPH_SLIDE))
	# Only the swell, a refusal, the glide and the draining underline animate on their own;
	# slot readings redraw in update_slots.
	if not _pulses.is_empty() or _was_pulsing or refusing or gliding or underline_share() > 0.0:
		queue_redraw()
	_was_pulsing = not _pulses.is_empty()


func _process(delta: float) -> void:
	step(delta)


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in slots:
		if not key_hidden(entry):
			out.append_array(Keycap.words(entry["key"]))
	return out


func _draw() -> void:
	var rects := slot_rects()
	for entry in slots:
		var name := slot_name(entry)
		_draw_slot(entry, rects[name], CHIP_SCALE if is_chip(entry) else 1.0)
	if not slots.is_empty():
		_draw_glyph()


func _draw_slot(entry: Dictionary, rect: Rect2, scale: float) -> void:
	var name := slot_name(entry)
	var state: String = entry["state"]
	var look := slot_look(entry)
	var color: Color = tint if state == "active" else EventKinds.UI_ROWS.get("ability_" + state, {}).get("color", UiTokens.TEXT)
	var shake := shake_offset(name)
	rect.position += shake
	var key_centre := Vector2(rect.get_center().x, SLOT + KEY_GAP + KEY_H * 0.5)
	var left := pulse_left(entry["id"])
	if left > 0.0:
		rect = rect.grow(rect.size.x * PULSE_SCALE * 0.5 * sin(PI * (1.0 - left / PULSE_SECONDS)))
	if look["doubled"]:
		rect = rect.grow(2.0)
	rect.position.y -= look["lift"]
	var radius := int(UiTokens.RADIUS * scale)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA) if state != "unavailable" else Color(Palette.VERDIGRIS, 0.5)
	back.set_corner_radius_all(radius)
	draw_style_box(back, rect)

	var reason := slot_reason(entry)
	if reason == "clock":
		_draw_sweep(rect, float(entry["cooldown_frac"]))
	var icon_alpha: float = {"ready": 1.0, "active": 1.0, "cooling": 0.6 if reason == "clock" else 0.4, "unavailable": 0.28}[state]
	var icon: String = entry["icon"]
	draw_texture_rect(Icons.texture(icon), rect.grow(-rect.size.x * 0.17), false, Icons.tint(icon, Color(tint, icon_alpha)))
	if reason == "clock":
		_draw_hand(rect, float(entry["cooldown_frac"]))
	if state == "unavailable":
		var inset := 8.0 * scale
		draw_line(rect.position + Vector2(inset, rect.size.y - inset), rect.end - Vector2(inset, rect.size.y - inset), Color(color, 0.9), 3.0)
	var flash := flash_color(name)
	if flash.a > 0.0:
		var wash := StyleBoxFlat.new()
		wash.bg_color = Color(flash, flash.a * 0.55)
		wash.set_corner_radius_all(radius)
		draw_style_box(wash, rect)

	var frame_color: Color = tint if left > 0.0 else (Color(flash, 1.0) if flash.a > 0.0 else color)
	if reason == "empty":
		_draw_dashed(rect, frame_color)
	else:
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = frame_color
		frame.set_border_width_all({"ready": 3, "active": 3, "cooling": 1, "unavailable": 1}[state])
		frame.set_corner_radius_all(radius)
		draw_style_box(frame, rect)
	var refund_left := refund_flash_left(name)
	if refund_left > 0.0:
		var row: Dictionary = EventKinds.UI_ROWS["cooldown_refunded"]
		var refund_color := Color(row["color"], refund_left / PULSE_SECONDS)
		draw_texture_rect(Icons.shape(row["shape"]), rect.grow(-rect.size.x * 0.2), false, refund_color)
	if look["doubled"]:
		var outer := StyleBoxFlat.new()
		outer.draw_center = false
		outer.border_color = Color(color, 0.55)
		outer.set_border_width_all(2)
		outer.set_corner_radius_all(radius + 3)
		draw_style_box(outer, rect.grow(5.0))

	if left > 0.0:
		var t := 1.0 - left / PULSE_SECONDS
		var reach := rect.size.x * (0.7 + 0.5 * t)
		draw_texture_rect(Icons.shape(motif), Rect2(rect.get_center() - Vector2(reach, reach) * 0.5, Vector2(reach, reach)), false, Color(tint, 0.6 * (1.0 - t)))
	if name == "line" and line_loaded:
		var badge := Rect2(Vector2(rect.end.x - BADGE * 0.6, rect.position.y - BADGE * 0.4), Vector2(BADGE, BADGE))
		draw_circle(badge.get_center(), BADGE * 0.55, Color(UiTokens.INK, UiTokens.PLATE_ALPHA))
		draw_texture_rect(Icons.texture(Icons.REEL), badge, false, Icons.tint(Icons.REEL, tint))
	if not key_hidden(entry):
		_draw_cap(key_centre + Vector2(shake.x, 0.0), entry["key"], look, KEY_H * scale)
	var max_charges: int = entry["max_charges"]
	var full: int = entry["charges"]
	if reason == "empty":
		max_charges = pool_pips(entry)
		full = 0
	if max_charges > 1 or reason == "empty":
		var step_x := PIP * 3.0
		var y := SLOT + KEY_GAP + KEY_H + PIP_GAP + PIP
		for c in max_charges:
			var at := Vector2(key_centre.x + (c - (max_charges - 1) * 0.5) * step_x, y)
			var pip := Rect2(at - Vector2(PIP, PIP) * 1.3, Vector2(PIP, PIP) * 2.6)
			draw_texture_rect(Icons.shape(motif), pip, false, tint if c < full else Color(tint, 0.25))


# A slot's keycap: the shared drawn key, or on the selected slot the inverted cap (sand fill,
# charcoal digit), so the pick reads on the number itself.
func _draw_cap(at: Vector2, key: String, look: Dictionary, height: float) -> void:
	if not look["glyph"] or Keycap.is_mouse(key):
		Keycap.draw(self, at, key, look["cap_ink"], height)
		return
	var cap := Keycap.size_of(key, height)
	var box := StyleBoxFlat.new()
	box.bg_color = look["cap_fill"]
	box.border_color = look["cap_fill"]
	box.set_border_width_all(2)
	box.border_width_bottom = 4
	box.set_corner_radius_all(int(height * 0.2))
	draw_style_box(box, Rect2(at - cap * 0.5, cap))
	var fs := Keycap.font_size(height)
	var text := Keycap.label(key)
	var font := UiFonts.bold()
	var baseline := at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - 1.0
	draw_string(font, Vector2(at.x - UiFonts.width(text, fs) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, look["cap_ink"])


# The mouse glyph over the selected slot, and its underline draining over the timeout.
func _draw_glyph() -> void:
	var x := glyph_x if glyph_x >= 0.0 else glyph_target()
	var w := GLYPH_H * 0.8
	var top := -GLYPH_GAP - GLYPH_H - UNDERLINE - 2.0
	var rect := Rect2(Vector2(x - w * 0.5, top), Vector2(w, GLYPH_H))
	draw_texture_rect(Icons.texture("key_lmb"), rect, false, Icons.tint("key_lmb", UiTokens.TEXT))
	var share := underline_share()
	if share > 0.0:
		var y := rect.end.y + 2.0 + UNDERLINE * 0.5
		draw_line(Vector2(x - w * 0.5, y), Vector2(x - w * 0.5 + w * share, y), UiTokens.TEXT, UNDERLINE)


# The remaining cooldown as a petrol wedge: it fills the part of the slot still to come back
# and shrinks clockwise from twelve, linearly, as the ability returns; the icon draws over it.
func _draw_sweep(rect: Rect2, frac: float) -> void:
	# A sliver under one degree has no area to triangulate, and a full wedge's first and
	# last edge points coincide, so both ends are handled without building a polygon.
	if frac < 1.0 / 360.0:
		return
	if frac >= 1.0 - 1.0 / 360.0:
		draw_rect(rect, Color(Palette.VERDIGRIS, 0.8))
		return
	var centre := rect.get_center()
	var half := rect.size * 0.5
	var stop := -PI * 0.5 + TAU
	var points := PackedVector2Array([centre])
	var angle := -PI * 0.5 + (1.0 - frac) * TAU
	while angle < stop:
		points.append(_edge(centre, half, angle))
		angle += SWEEP_STEP
	var last := _edge(centre, half, stop)
	if points[points.size() - 1].distance_to(last) > 0.01:
		points.append(last)
	if points.size() >= 3:
		draw_colored_polygon(points, Color(Palette.VERDIGRIS, 0.8))


# The clock's hand: a sand line from the slot's centre to the wedge's leading edge, so a
# cooling slot reads as time running out and not as a slot that is simply grey.
func _draw_hand(rect: Rect2, frac: float) -> void:
	if frac < 1.0 / 360.0:
		return
	var centre := rect.get_center()
	var angle := -PI * 0.5 + (1.0 - frac) * TAU
	# A clock hand is round: it stops inside the slot's rounded corners.
	draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * (rect.size.x * 0.5 - HAND * 2.0), UiTokens.TEXT, HAND)
	draw_circle(centre, HAND * 1.5, UiTokens.TEXT)


# An empty charge's frame: DASHES dashes a side, so the slot reads as hollow, not as cooling.
func _draw_dashed(rect: Rect2, color: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for d in DASHES:
			var t0 := (d + 0.2) / DASHES
			var t1 := (d + 0.8) / DASHES
			draw_line(a.lerp(b, t0), a.lerp(b, t1), color, 2.0)


static func _edge(centre: Vector2, half: Vector2, angle: float) -> Vector2:
	var dir := Vector2(cos(angle), sin(angle))
	var reach := minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
	return centre + dir * reach
