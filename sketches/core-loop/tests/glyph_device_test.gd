extends SceneTree

const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const RestartMeter := preload("res://src/ui/restart_meter.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# S4: the on-screen caps follow the device in use and the keys actually bound.
#   S4-1 keyboard with the default InputMap: Glyphs.of is the table glyph for all nine verbs;
#   S4-2 pad: the pad id of each verb, cl_retry on both devices;
#   S4-3 a rebinding of cl_jump to G reads as key_g, and a live prompt redraws with G;
#   S4-4 a pad event switches the live prompts and the ability bar to pad caps, a key event back;
#   S4-5 Keycap.label and Keycap.words give the pad caps' text and leave key_space alone.
# Re-pinned 2026-10-10 (wave P-B unit B1, design-v3/SKILL-BAR.md sections 1, 4 and 6): F
# retired, so the special verb has no pad reading and LB is the ultimate's (Q); keys 1, 2, 3
# pick a slot on the D-pad (input_pad_test pins the buttons); the bar is five slots, 1, Shift,
# 2, Ctrl, 3. The pad bar's number caps stay key_1..key_3 until wave P-B's HUD unit draws
# them (B2): Glyphs has no D-pad picture yet.
# Re-pinned 2026-10-10 (wave 13 unit B2, SKILL-BAR section 5): the HUD draws the bar in its own
# order, the numbered slots 1, 2, 3 and then the Shift and Ctrl chips. The number caps read the
# select actions' keys, which stay key_1..key_3 on the pad (no D-pad glyph yet).
# Re-pinned 2026-10-24 (#445, actives on by default): the racked active's F chip is the sixth
# cap. Re-pinned 2026-10-24 (D-pad glyphs): Glyphs draws the D-pad, so on the pad the number
# caps read D-pad left, up and right and the active's chip D-pad down.

var _t := T.new("glyph_device_test")
var _game
var _wait := 0
var _started := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 4:
		return false
	_caps()
	_defaults_and_pad()
	_live_and_rebind()
	_device_switch()
	_meter()
	quit(_t.verdict())
	return true


func _pad_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	return event


func _key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SPACE
	event.pressed = true
	return event



func _caps() -> void:
	for pair in [["pad_a", "A"], ["pad_lb", "LB"], ["pad_rt", "RT"], ["pad_ls", "L"], ["key_space", "Space"], ["key_f", "F"]]:
		_t.eq("S4-5 label %s" % pair[0], Keycap.label(pair[0]), pair[1])
		_t.eq("S4-5 words %s" % pair[0], Array(Keycap.words(pair[0])), [pair[1]])
	# A D-pad cap is a picture (a cross with its arm lit): square, and no word on the HUD.
	for key in ["pad_dl", "pad_du", "pad_dr", "pad_dd"]:
		_t.check("S4-5 %s is a square picture" % key, Keycap.words(key).is_empty() and Keycap.size_of(key, 24.0) == Vector2(24.0, 24.0),
			"words %s size %s" % [Keycap.words(key), Keycap.size_of(key, 24.0)])


func _defaults_and_pad() -> void:
	Glyphs.device = "kbm"
	var strays := []
	for verb in Bindings.VERBS:
		if Glyphs.of(verb) != Bindings.glyph(verb):
			strays.append("%s %s" % [verb, Glyphs.of(verb)])
	_t.check("S4-1 keyboard defaults are the table glyphs", strays.is_empty(), "strays %s" % [strays])
	_t.eq("S4-2 cl_retry on the keyboard", Glyphs.of_action("cl_retry", ""), "key_r")
	Glyphs.device = "pad"
	var want := {"jump": "pad_a", "haul": "pad_x", "boost": "pad_b", "ultimate": "pad_lb", "interact": "pad_y",
		"fire": "pad_rt", "harpoon": "pad_lt", "roll": "pad_ls", "look": "pad_rs"}
	for verb in want:
		_t.eq("S4-2 pad %s" % verb, Glyphs.of(verb), want[verb])
	_t.check("S4-2 the retired special has no pad reading", not Glyphs.of("special").begins_with("pad_"),
		"special reads %s on the pad" % Glyphs.of("special"))
	_t.eq("S4-2 cl_retry on the pad", Glyphs.of_action("cl_retry", ""), "pad_rb")
	_t.eq("S4-2 cl_pause on the pad", Glyphs.of_action("cl_pause", ""), "pad_start")
	Glyphs.device = "kbm"


func _view(point: Vector3) -> Dictionary:
	var ready := {"harpoon": false, "haul": false, "boost": false, "interact": false, "jump": true}
	return {"ready": ready, "line": "", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": point, "haul": point, "boost": point, "interact": point, "jump": point}}


func _live_and_rebind() -> void:
	var glyphs = _game.hud.key_glyphs
	var cam: Camera3D = _game.camera.cam
	var point := cam.global_position - cam.global_transform.basis.z * 6.0
	glyphs.new_run()
	glyphs.step(0.016, _view(point))
	glyphs._process(0.0)
	_t.check("S4-3 jump prompt is live", "jump" in glyphs.shown_verbs() and glyphs._placed.size() > 0, "shown %s placed %d" % [glyphs.shown_verbs(), glyphs._placed.size()])
	_t.eq("S4-3 prompt reads Space first", Array(glyphs.drawn_words()).has("Space"), true)
	var old: Array = InputMap.action_get_events("cl_jump")
	for event in old:
		if event is InputEventKey:
			InputMap.action_erase_event("cl_jump", event)
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	InputMap.action_add_event("cl_jump", g)
	_t.eq("S4-3 Glyphs.of(jump) after the rebinding", Glyphs.of("jump"), "key_g")
	glyphs._process(0.0)
	var placed_glyphs: Array = glyphs._placed.map(func(p): return p["glyph"])
	_t.check("S4-3 the live prompt redrew with G", placed_glyphs == ["key_g"] and Array(glyphs.drawn_words()).has("G"),
		"placed %s words %s" % [placed_glyphs, glyphs.drawn_words()])
	InputMap.action_erase_event("cl_jump", g)
	for event in old:
		if event is InputEventKey:
			InputMap.action_add_event("cl_jump", event)
	_t.eq("S4-3 restored", Glyphs.of("jump"), "key_space")


func _meter() -> void:
	var meter := RestartMeter.new()
	root.add_child(meter)
	Glyphs.device = "pad"
	meter.set_fraction(0.5)
	var need := Keycap.size_of("pad_rb", RestartMeter.KEY_H).x + RestartMeter.GAP + RestartMeter.BAR.x
	_t.check("S4-6 the restart meter covers the RB cap on the pad", meter.custom_minimum_size.x >= need, "min %.1f need %.1f" % [meter.custom_minimum_size.x, need])
	Glyphs.device = "kbm"
	meter.free()


func _bar_keys() -> Array:
	var out := []
	for record in AbilitySlots.new().slots(_game):
		out.append(record["key"])
	return out


func _device_switch() -> void:
	var glyphs = _game.hud.key_glyphs
	var cam: Camera3D = _game.camera.cam
	var point := cam.global_position - cam.global_transform.basis.z * 6.0
	_game.note_device(_key_event())
	_t.eq("S4-4 bar on the keyboard", _bar_keys(), ["key_1", "key_2", "key_3", "key_shift", "key_ctrl", "key_f"])
	_game.note_device(_pad_event())
	_t.eq("S4-4 bar on the pad", _bar_keys(), ["pad_dl", "pad_du", "pad_dr", "pad_b", "pad_x", "pad_dd"])
	glyphs.new_run()
	glyphs.step(0.016, _view(point))
	glyphs._process(0.0)
	_t.eq("S4-4 prompt on the pad", glyphs._placed.map(func(p): return p["glyph"]), ["pad_a"])
	_game.note_device(_key_event())
	glyphs._process(0.0)
	_t.eq("S4-4 prompt back on the keyboard", glyphs._placed.map(func(p): return p["glyph"]), ["key_space"])
	_t.eq("S4-4 bar back on the keyboard", _bar_keys(), ["key_1", "key_2", "key_3", "key_shift", "key_ctrl", "key_f"])
