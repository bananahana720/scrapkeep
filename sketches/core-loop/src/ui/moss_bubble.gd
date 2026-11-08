extends Control

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")

# Moss is never seen (DESIGN-V2 sections 12 and 15): a voice from the hatch and a pair
# of hands. His line is a speech bubble whose tail runs off the screen's left edge, the
# side his counter is on, with a hand below it that gestures what he just did. The line
# comes from shop.gd at his counter and lore_rows.gd on zone entry.
#
# Exasperation lives in the bubble, not in extra words: each beat of the conversation
# loop sharpens the bubble's corners, cuts teeth into its edge and shakes it harder,
# and a grumbling beat lands with a squash. The restart line rewinds it: the bubble
# shrinks, turns back and comes round smooth again. The relent is the one good-news
# motion (VISUAL-LANGUAGE section 8, bounce means good news): an amber, rounded bubble
# that pops with overshoot over the moss_relent row's star. Colour and shape per fact
# come from event_kinds' LOOT_ROWS.

const TEXT_WIDTH := 330.0
const FONT := 20
const PAD := Vector2(20.0, 14.0)
const TAIL := 28.0
const RADIUS := 18.0
const TOOTH := 16.0
const MAX_EXASPERATION := 5
const HOLD_BASE := 1.6
const HOLD_PER_WORD := 0.3
const FADE := 0.25
const HAND := 15.0
const GESTURE_SECONDS := 0.6
const INTRO_HOLD := 4.0

# Reduced motion (Game.set_reduced_motion keeps it current): the bubble's shake and tail wag stop.
static var reduced_motion := false

var text := ""
var kind := "moss_beat"
var mood := ""
var exasperation := 0.0
var shown_exasperation := 0.0
var grumble := false
# While Moss's counter is open his line stays up until the next one replaces it.
var sticky := false
var gesture := ""
var _label: Label
var _clock := 0.0
var _hold := 0.0
var _gesture_clock := 0.0
var _body := Vector2.ZERO
var _spin := 0.0
var _pop := 1.0
var _tween: Tween
var _game
var _exchange: Array = []
var _exchange_index := 0
var _zones_played := {}
var _intros_played := {}
var _intro_queue: Array = []
var _intro_showing := false


class ExchangeInput extends Node:
	var bubble

	func _input(event: InputEvent) -> void:
		bubble._exchange_input(event)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(TEXT_WIDTH, 0.0)
	_label.add_theme_font_override("font", UiFonts.bold())
	_label.add_theme_font_size_override("font_size", FONT)
	_label.add_theme_color_override("font_color", Palette.SAND)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _ready() -> void:
	_game = get_parent().game
	_install_exchange_input.call_deferred()
	_game.events.run_started.connect(_on_run_started)
	_game.events.stage_entered.connect(_on_stage_entered)
	_game.events.warden_sighted.connect(_on_warden_sighted)
	_game.events.warden_engaged.connect(_on_warden_engaged)
	_game.events.boss_arena_entered.connect(_on_boss_arena_entered)
	# Reading is optional and momentum is sacred: firing or hooking walks away from it.
	_game.events.shot_fired.connect(func(_w: String, _from: Vector3, _to: Vector3): _end_exchange())
	_game.events.grapple_fired.connect(func(_anchor: Vector3): _end_exchange())
	_game.events.flow_changed.connect(func(_state: String):
		if not _game.flow.in_stage():
			_end_exchange())


func _install_exchange_input() -> void:
	# Listen after the game's overlays are built. The exchange only reads the interact key.
	var listener := ExchangeInput.new()
	listener.name = "LoreExchangeInput"
	listener.bubble = self
	listener.process_mode = Node.PROCESS_MODE_ALWAYS
	_game.add_child(listener)


func _on_run_started(_class_id: String) -> void:
	_end_exchange(false)
	_end_intro()
	_zones_played.clear()
	_intros_played.clear()


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_end_exchange(false)
	_end_intro()
	# Flow places the new Warden after this signal, clearing the previous engagement.
	_begin_exchange.call_deferred(stage)


func _begin_exchange(stage: int) -> void:
	if stage != _game.run.stage or not _game.flow.in_stage() or _game.flow.engaged():
		return
	var zone := "%d-%d" % [_game.ctx.stages.world_of(stage), _game.ctx.stages.local(stage)]
	if _zones_played.has(zone):
		return
	var exchange_id := ""
	for row in LoreRows.ROWS:
		if row["kind"] == "exchange" and row["zone"] == zone:
			if exchange_id == "":
				exchange_id = row["exchange"]
			if row["exchange"] == exchange_id:
				_exchange.append(row)
	if _exchange.is_empty():
		return
	_zones_played[zone] = true
	_exchange_index = 0
	position = Vector2(0.0, get_viewport().get_visible_rect().size.y * 0.30)
	_show_exchange_line()


# Intro rows are the Warden's line (subject "warden") and the world boss's line. The Warden
# line plays when the Warden is sighted (flow.gd warden_sighted), before the fight, and clears
# the moment the Warden is engaged: a fight's screen holds no intro (LEGIBILITY word budget).
# The boss line plays when the arena opens, which only the last zone of a world reaches, where
# the pilot's own threat line wins over the boss's general one. Each plays once per run and
# zone once it has reached the screen, and waits out an exchange.
func _zone_of(stage: int) -> String:
	return "%d-%d" % [_game.ctx.stages.world_of(stage), _game.ctx.stages.local(stage)]


func _on_warden_sighted(stage: int) -> void:
	_queue_intro(_zone_of(stage), true)


func _on_warden_engaged(_stage: int) -> void:
	_end_exchange(false)
	_end_intro()


func _on_boss_arena_entered() -> void:
	_queue_intro(_zone_of(_game.run.stage), false)


func _queue_intro(zone: String, warden: bool) -> void:
	var key := "%s/%s" % [zone, "warden" if warden else "boss"]
	if _intros_played.has(key) or _intro_queue.any(func(queued): return queued["intro_key"] == key):
		return
	var pilot: String = _game.run.class_id()
	var chosen := {}
	for row in LoreRows.ROWS:
		if row["kind"] == "intro" and row["zone"] == zone and (row.get("subject", "") == "warden") == warden:
			if row.get("pilot", pilot) != pilot:
				continue
			chosen = row
			if row.has("pilot"):
				break
	if not chosen.is_empty():
		var entry := chosen.duplicate()
		entry["intro_key"] = key
		_intro_queue.append(entry)
	_flush_intro()


func _flush_intro() -> void:
	if _intro_queue.is_empty() or not _exchange.is_empty() or get_tree().paused:
		return
	var row: Dictionary = _intro_queue.pop_front()
	_intros_played[String(row["intro_key"])] = true
	position = Vector2(0.0, get_viewport().get_visible_rect().size.y * 0.30)
	_say(String(row["text"]), "moss_beat", "intro", 0.0, false, "")
	_hold = INTRO_HOLD
	_intro_showing = true


func _end_intro() -> void:
	_intro_queue.clear()
	if _intro_showing:
		_intro_showing = false
		_clear_line()


func _show_exchange_line() -> void:
	var line: Dictionary = _exchange[_exchange_index]
	_say("%s: %s" % [line["speaker"], line["text"]], "moss_beat", "exchange", 0.0, false, "")


func _advance_exchange() -> void:
	_exchange_index += 1
	if _exchange_index >= _exchange.size():
		_end_exchange()
	else:
		_show_exchange_line()


func _end_exchange(flush := true) -> void:
	if _exchange.is_empty():
		return
	_exchange.clear()
	_exchange_index = 0
	_clear_line()
	if flush:
		_flush_intro()


func _clear_line() -> void:
	if _tween != null:
		_tween.kill()
	_hold = 0.0
	text = ""
	_label.text = ""
	visible = false
	modulate.a = 0.0


# Only the interact key advances; Escape and ui_accept (Space and pad A are jump) are never
# read. Fire and hook dismiss silently, and so does cruise speed (see _process).
func _exchange_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if _intro_showing:
		if event.is_action_pressed("cl_interact") or event.is_action_pressed("cl_fire") or event.is_action_pressed("cl_harpoon"):
			_end_intro()
		return
	if _exchange.is_empty():
		return
	if event.is_action_pressed("cl_interact"):
		_advance_exchange()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cl_fire") or event.is_action_pressed("cl_harpoon"):
		_end_exchange()


# Ends a zone-entry exchange early, as the fire and hook keys do. Public so a test can clear it.
func dismiss_exchange() -> void:
	_end_exchange()


func row() -> Dictionary:
	return EventKinds.LOOT_ROWS.get(kind, EventKinds.LOOT_ROWS["moss_beat"])


func showing() -> bool:
	return visible and modulate.a > 0.05 and text != ""


# One press of the talk key: a beat record from shop.talk().
func beat(record: Dictionary) -> void:
	if record.is_empty():
		return
	_end_exchange(false)
	# A beat or bark replaces an intro line: the next press must not clear it as the intro.
	_intro_showing = false
	var mood_now := "beat"
	if record.get("relent", false):
		mood_now = "relent"
	elif record.get("restart", false):
		mood_now = "restart"
	var level := 0.0 if mood_now != "beat" else float(record.get("exasperation", 0))
	_say(String(record.get("text", "")), "moss_relent" if mood_now == "relent" else "moss_beat", mood_now,
		level, bool(record.get("grumble", false)), "give" if mood_now == "relent" else "tap")


# A verb's bark ({line_id, text, root}) with the fact it answered (a LOOT_ROWS kind).
func bark(line: Dictionary, fact: String) -> void:
	if line.is_empty():
		return
	_end_exchange(false)
	_intro_showing = false
	var refused := fact == "shop_refused"
	_say(String(line.get("text", "")), fact, "refuse" if refused else "bark", 0.0, refused,
		"refuse" if refused else ("give" if fact in ["shop_bought", "shop_charge", "shop_sold"] else ""))


func hush() -> void:
	_end_exchange(false)
	_intro_showing = false
	_hold = 0.0
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		if _hold <= 0.0:
			visible = false)


func _say(line: String, fact: String, mood_now: String, level: float, grumbles: bool, hand: String) -> void:
	text = line
	kind = fact
	mood = mood_now
	exasperation = clampf(level, 0.0, MAX_EXASPERATION)
	grumble = grumbles
	gesture = hand
	_gesture_clock = 0.0
	_clock = 0.0
	_label.text = line
	_label.add_theme_color_override("font_color", Palette.SAND)
	_label.size = Vector2(TEXT_WIDTH, 0.0)
	_body = Vector2(TEXT_WIDTH, _label.get_minimum_size().y) + PAD * 2.0
	_label.position = Vector2(TAIL, 0.0) + PAD
	size = Vector2(TAIL + _body.x + 12.0, _body.y + HAND * 3.5)
	pivot_offset = Vector2(0.0, _body.y * 0.5)
	_hold = HOLD_BASE + HOLD_PER_WORD * line.split(" ", false).size()
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12).set_ease(Tween.EASE_OUT)
	match mood_now:
		"restart":
			_spin = -0.35
			_pop = 0.7
			_tween.tween_property(self, "_spin", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "_pop", 1.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", 0.0, 0.45)
		"relent":
			_spin = 0.0
			_pop = 0.6
			_tween.tween_property(self, "_pop", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", 0.0, 0.3)
		_:
			_spin = 0.0
			_pop = 0.9 if grumbles else 0.96
			_tween.tween_property(self, "_pop", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_tween.tween_property(self, "shown_exasperation", exasperation, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not _intro_queue.is_empty() and not visible:
		_flush_intro()
	if not visible:
		return
	_clock += delta
	_gesture_clock += delta
	if not _exchange.is_empty() and _game.player != null \
			and _game.player.state.velocity.length() > _game.ctx.tuning.f("cruise"):
		_end_exchange()
		return
	# A line waits out a pause (the pick screen over the bay's greeting) instead of
	# expiring unread behind it.
	if _exchange.is_empty() and not sticky and _hold > 0.0 and not get_tree().paused:
		_hold -= delta
		if _hold <= 0.0:
			hush()
	queue_redraw()


# The bubble's outline: a rounded box whose corners tighten and whose edge grows teeth
# as Moss's patience runs out.
func outline(e: float) -> PackedVector2Array:
	var r := maxf(3.0, RADIUS - e * 3.0)
	var box := Rect2(Vector2(TAIL, 0.0), _body)
	var corners := [
		[box.position + Vector2(r, r), PI, PI * 1.5],
		[Vector2(box.end.x - r, box.position.y + r), PI * 1.5, TAU],
		[box.end - Vector2(r, r), 0.0, PI * 0.5],
		[Vector2(box.position.x + r, box.end.y - r), PI * 0.5, PI],
	]
	var ring := PackedVector2Array()
	for c in corners:
		for step in 5:
			var a: float = lerpf(c[1], c[2], step / 4.0)
			ring.append(c[0] + Vector2(cos(a), sin(a)) * r)
	if e <= 0.05:
		return ring
	# Square teeth along the straight edges only, pointing out, so the outline never
	# crosses itself at a tight corner. At the send-off the bubble is a cog: the scrap
	# glyph, which is what Moss keeps telling you to bring.
	var toothed := PackedVector2Array()
	var amp := e * 1.6
	for i in ring.size():
		var a := ring[i]
		var b := ring[(i + 1) % ring.size()]
		toothed.append(a)
		var n := int(a.distance_to(b) / TOOTH)
		if n < 1:
			continue
		var normal := (b - a).orthogonal().normalized()
		for k in n:
			var rise := a.lerp(b, (k + 0.3) / n)
			var fall := a.lerp(b, (k + 0.7) / n)
			toothed.append_array([rise, rise + normal * amp, fall + normal * amp, fall])
	return toothed


func _draw() -> void:
	if text == "":
		return
	var e := shown_exasperation
	var shake := Vector2(sin(_clock * TAU * 13.0), cos(_clock * TAU * 11.0)) * (e * 0.8 + (3.0 if grumble else 0.0)) * exp(-_clock * 5.0)
	if reduced_motion:
		shake = Vector2.ZERO
	var squash := Vector2(1.0 / _pop, _pop) if grumble and mood == "beat" else Vector2(_pop, _pop)
	draw_set_transform(pivot_offset + shake, _spin, squash)
	var root := -pivot_offset
	var edge: Color = row().get("color", Palette.SAND)
	if mood == "relent":
		var star := Icons.shape(String(row().get("shape", "star")))
		var burst := _body.y * 1.6
		draw_texture_rect(star, Rect2(root + Vector2(TAIL + _body.x - burst * 0.5, -burst * 0.3), Vector2(burst, burst)), false, Color(edge, 0.35))
	var body := outline(e)
	var shifted := PackedVector2Array()
	for p in body:
		shifted.append(p + root)
	var mid_y := _body.y * 0.5
	var wag := 0.0 if reduced_motion else sin(_clock * TAU * 3.0) * e * 1.5
	var tail := PackedVector2Array([root + Vector2(TAIL + 2.0, mid_y - 10.0), root + Vector2(-4.0, mid_y + 8.0 + wag), root + Vector2(TAIL + 2.0, mid_y + 10.0)])
	draw_colored_polygon(tail, Color(Palette.CHARCOAL, 0.94))
	draw_colored_polygon(shifted, Color(Palette.CHARCOAL, 0.94))
	shifted.append(shifted[0])
	draw_polyline(shifted, edge, 3.0 if mood == "relent" else 2.0 + e * 0.3)
	draw_line(tail[0], tail[1], edge, 2.0)
	draw_line(tail[1], tail[2], edge, 2.0)
	var glyph := String(row().get("shape", "none"))
	if glyph != "none" and mood in ["refuse", "bark"]:
		draw_texture_rect(Icons.shape(glyph), Rect2(root + Vector2(TAIL + _body.x - 14.0, -10.0), Vector2(24.0, 24.0)), false, edge)
	draw_set_transform(Vector2.ZERO)
	_label.position = Vector2(TAIL, 0.0) + PAD + shake
	_draw_hand(Vector2(0.0, _body.y + HAND * 1.8), edge)


# One of Moss's hands at the counter's edge: a mitt that slides out to give, taps on a
# grumble, or holds up a flat palm and wags when he refuses.
func _draw_hand(at: Vector2, edge: Color) -> void:
	var t := clampf(_gesture_clock / GESTURE_SECONDS, 0.0, 1.0)
	if gesture == "" or t >= 1.0:
		return
	var reach := sin(t * PI)
	var p := at
	var angle := 0.0
	match gesture:
		"give":
			p.x += -HAND + reach * HAND * 3.0
		"tap":
			p.x += HAND * 0.8
			p.y += -absf(sin(t * TAU * 2.0)) * HAND * 0.7
		"refuse":
			p.x += HAND * 1.2 * reach
			angle = sin(t * TAU * 3.0) * 0.35
	draw_set_transform(p, angle, Vector2.ONE)
	var palm := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		palm.append(Vector2(cos(a) * HAND, sin(a) * HAND * 0.8))
	draw_colored_polygon(palm, Palette.SANDSTONE)
	palm.append(palm[0])
	draw_polyline(palm, Palette.CHARCOAL, 2.0)
	var fingers := 4
	for i in fingers:
		var x := -HAND * 0.6 + i * HAND * 0.4
		var tip := Vector2(x, -HAND * 1.35) if gesture == "refuse" else Vector2(HAND * 1.35, -HAND * 0.5 + i * HAND * 0.33)
		var base := Vector2(x, -HAND * 0.5) if gesture == "refuse" else Vector2(HAND * 0.5, -HAND * 0.5 + i * HAND * 0.33)
		draw_line(base, tip, Palette.CHARCOAL, 7.0)
		draw_line(base, tip, Palette.SANDSTONE, 4.5)
	draw_set_transform(Vector2.ZERO)
