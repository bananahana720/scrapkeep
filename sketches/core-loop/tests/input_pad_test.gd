extends SceneTree

const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# S1: saved key bindings apply at boot and a gamepad plays the game.
#   S1-1 the table: every verb has a pad button or axis, the look, retry and pause actions
#        exist, and no pad button serves two verbs;
#   S1-2 a saved cl_jump "key:G" leaves exactly G plus the pad button; a token that decodes to
#        nothing keeps the defaults and warns once;
#   S1-3 the right stick turns the camera 2.6 rad/s at full deflection and far less at half;
#   S1-4 the retry hold on cl_retry restarts at 0.5 s and not before;
#   S1-5 the pad maps to the title, death and summary screens' keys;
#   S1-6 the last device follows the last event.
# Re-pinned 2026-10-10 (wave P-B unit B1, design-v3/SKILL-BAR.md sections 1, 4 and 6): a
# retired verb (the special, F) has no key and no pad, so S1-1 skips it and checks it stays
# padless; keys 1, 2, 3 pick on the D-pad left, up and right, and the ultimate (Q) is LB.

const STEPS := ["title", "play", "die_a", "dead_a", "die_b", "dead_b", "summary", "done"]

var _t := T.new("input_pad_test")
var _game
var _step := -1
var _wait := 0


func _initialize() -> void:
	# The game settles storage_dir in _ready; a settings file already in that folder is the
	# one a player's last session left.
	var dir := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(dir.path_join("settings.json"), FileAccess.WRITE)
	file.store_string('{"bindings": {"cl_jump": "key:G", "cl_fire": "key:NoSuchKeyZ", "cl_boost": "pad:3"}}')
	file.close()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	if _wait < 12:
		return false
	_wait = 0
	if _step < 0:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_table()
		_saved()
		_stick()
		_device()
		_step = 0
		return false
	var flow = _game.flow
	match STEPS[_step]:
		"title":
			_t.eq("S1-5 title", flow.state_name(), "title")
			var key: int = _game.pad_screen_key(_pad(JOY_BUTTON_A))
			_t.eq("S1-5 A on the title is Space", key, KEY_SPACE)
			_game._screen_key(key)
			_t.eq("S1-5 A starts from the title", flow.state_name(), "class_select")
		"play":
			flow.choose_class(0)
			_t.check("S1-5 a run is on", flow.in_play(), "state %s" % flow.state_name())
			_t.eq("S1-5 A in play maps to no screen key", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_NONE)
			_retry()
		"die_a", "die_b":
			_game.run.damage(99999.0, "test")
		"dead_a":
			_t.eq("S1-5 dead", flow.state_name(), "dead")
			_t.eq("S1-5 A on death is N", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
			_t.eq("S1-5 B on death is N", _game.pad_screen_key(_pad(JOY_BUTTON_B)), KEY_N)
			_t.eq("S1-5 a release maps to nothing", _game.pad_screen_key(_pad(JOY_BUTTON_A, false)), KEY_NONE)
			_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
			_t.check("S1-5 A starts a new run from the death screen", flow.in_play(), "state %s" % flow.state_name())
		"dead_b":
			_t.eq("S1-5 dead again", flow.state_name(), "dead")
			_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_B)))
			_t.check("S1-5 B starts a new run from the death screen", flow.in_play(), "state %s" % flow.state_name())
		"summary":
			flow._set_state(flow.SUMMARY)
			_game.summary_latched = false
			_t.eq("S1-5 A on the summary is N", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_N)
			_t.eq("S1-5 B on the summary is Space", _game.pad_screen_key(_pad(JOY_BUTTON_B)), KEY_SPACE)
			_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_B)))
			_t.eq("S1-5 B opens class select from the summary", flow.state_name(), "class_select")
			flow._set_state(flow.SUMMARY)
			_game.summary_latched = false
			_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
			_t.check("S1-5 A starts a new run from the summary", flow.in_play(), "state %s" % flow.state_name())
		"done":
			quit(_t.verdict())
			return true
	_step += 1
	return false


func _pad(button: int, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _table() -> void:
	var owner_of := {}
	var shared: Array = []
	var bare: Array = []
	var all := Bindings.actions()
	var retired_pads: Array = []
	for verb in Bindings.VERBS:
		if Bindings.VERBS[verb].get("retired", false):
			for action in Bindings.VERBS[verb]["actions"]:
				if (all[action] as Dictionary).has("pad") or (all[action] as Dictionary).has("axis"):
					retired_pads.append(action)
			continue
		var has_pad := false
		for action in Bindings.VERBS[verb]["actions"]:
			var record: Dictionary = all[action]
			if record.has("pad") or record.has("axis"):
				has_pad = true
		if not has_pad:
			bare.append(verb)
	for action in all:
		var record: Dictionary = all[action]
		if record.has("pad"):
			var verb: String = Bindings.verb_of_action(action)
			if verb == "":
				verb = action
			if owner_of.has(record["pad"]) and owner_of[record["pad"]] != verb:
				shared.append("%d: %s and %s" % [record["pad"], owner_of[record["pad"]], verb])
			owner_of[record["pad"]] = verb
	_t.eq("S1-1 every verb has a pad button or an axis", bare, [])
	_t.eq("S1-1 a retired verb has no pad reading", retired_pads, [])
	_t.eq("S1-1 1, 2, 3 pick on the D-pad", Bindings.SELECT_ACTIONS.map(func(a): return int(all[a].get("pad", -1))),
		[JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT])
	_t.eq("S1-1 the ultimate is LB", int(all["cl_ultimate"].get("pad", -1)), JOY_BUTTON_LEFT_SHOULDER)
	_t.eq("S1-1 no pad button serves two verbs", shared, [])
	for action in ["cl_look_left", "cl_look_right", "cl_look_up", "cl_look_down", "cl_retry", "cl_pause"]:
		_t.check("S1-1 %s is registered with an event" % action, InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "")
	for action in ["cl_retry", "cl_pause"]:
		var kinds := _kinds(action)
		_t.check("S1-1 %s has a key and a pad button" % action, kinds.has("key") and kinds.has("pad"), "kinds %s" % [kinds])
	var pause_keys: Array = []
	for event in InputMap.action_get_events("cl_pause"):
		if event is InputEventKey:
			pause_keys.append(event.physical_keycode)
	_t.eq("S1-1 pause keeps P and Escape", pause_keys, [KEY_P, KEY_ESCAPE])
	_t.check("S1-1 Start is pause", InputMap.event_is_action(_pad(JOY_BUTTON_START), "cl_pause"), "")
	_t.check("S1-1 RB is retry", InputMap.event_is_action(_pad(JOY_BUTTON_RIGHT_SHOULDER), "cl_retry"), "")
	var back := InputEventJoypadMotion.new()
	back.axis = JOY_AXIS_LEFT_Y
	back.axis_value = 1.0
	_t.check("S1-1 the left stick down is cl_back", InputMap.event_is_action(back, "cl_back"), "")


func _kinds(action: String) -> Array:
	var out := []
	for event in InputMap.action_get_events(action):
		var kind := "other"
		if event is InputEventKey:
			kind = "key"
		elif event is InputEventJoypadButton:
			kind = "pad"
		elif event is InputEventJoypadMotion:
			kind = "axis"
		elif event is InputEventMouseButton:
			kind = "mouse"
		out.append(kind)
	return out


func _saved() -> void:
	var events := InputMap.action_get_events("cl_jump")
	var keys: Array = []
	var pads: Array = []
	var others := 0
	for event in events:
		if event is InputEventKey:
			keys.append(event.physical_keycode)
		elif event is InputEventJoypadButton:
			pads.append(event.button_index)
		else:
			others += 1
	_t.eq("S1-2 cl_jump has exactly the G key", keys, [KEY_G])
	_t.eq("S1-2 cl_jump keeps its pad button", pads, [JOY_BUTTON_A])
	_t.eq("S1-2 cl_jump has nothing else", others, 0)
	_t.check("S1-2 Space no longer jumps", not InputMap.event_is_action(_key(KEY_SPACE), "cl_jump"), "")
	_t.eq("S1-2 a token that decodes to nothing keeps cl_fire's defaults", _kinds("cl_fire"), ["mouse", "axis"])
	_t.check("S1-2 and warns once", Bindings._warned_tokens.has("key:NoSuchKeyZ"), "warned %s" % [Bindings._warned_tokens.keys()])
	_t.eq("S1-2 a file may carry a pad token", Bindings.decode("pad:3")[0].button_index, 3)
	var boost_keys: Array = []
	var boost_pads: Array = []
	for event in InputMap.action_get_events("cl_boost"):
		if event is InputEventKey:
			boost_keys.append(event.physical_keycode)
		elif event is InputEventJoypadButton:
			boost_pads.append(event.button_index)
	_t.eq("S1-2 a pad-only override keeps the keyboard key", boost_keys, [KEY_SHIFT])
	_t.eq("S1-2 and replaces only the pad button", boost_pads, [3])


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _stick() -> void:
	var camera = _game.camera
	Input.action_press("cl_look_right", 1.0)
	var yaw_before: float = camera.yaw
	for i in 10:
		_game.step_stick_look(0.1)
	_t.near("S1-3 full deflection turns 2.6 rad/s of yaw", yaw_before - camera.yaw, 2.6, 0.05)
	Input.action_release("cl_look_right")
	Input.action_press("cl_look_right", 0.5)
	yaw_before = camera.yaw
	for i in 10:
		_game.step_stick_look(0.1)
	var half: float = yaw_before - camera.yaw
	_t.check("S1-3 half deflection turns much less than half", half > 0.0 and half < 0.5 * 2.6 * 0.5, "turned %.3f rad in 1 s" % half)
	Input.action_release("cl_look_right")
	Input.action_press("cl_look_up", 1.0)
	for i in 100:
		_game.step_stick_look(0.1)
	_t.check("S1-3 up stops at the pitch clamp", is_equal_approx(camera.pitch, 0.55), "pitch %.3f" % camera.pitch)
	Input.action_release("cl_look_up")
	Input.action_press("cl_look_down", 1.0)
	for i in 100:
		_game.step_stick_look(0.1)
	_t.check("S1-3 down stops at the pitch clamp", is_equal_approx(camera.pitch, -1.25), "pitch %.3f" % camera.pitch)
	Input.action_release("cl_look_down")


# Run once a run is on: the hold reads cl_retry, the action RB and R both fill.
func _retry() -> void:
	var game = _game
	Input.action_press("cl_retry")
	for i in 4:
		game.step_restart_hold(0.1, Input.is_action_pressed("cl_retry"))
	_t.check("S1-4 a 0.4 s hold does not restart", not game._restart_latched and absf(game.restart_hold_fraction() - 0.8) < 0.01, "fraction %.2f" % game.restart_hold_fraction())
	Input.action_release("cl_retry")
	game.step_restart_hold(0.1, Input.is_action_pressed("cl_retry"))
	_t.eq("S1-4 letting go clears the hold", game.restart_hold_fraction(), 0.0)
	Input.action_press("cl_retry")
	for i in 5:
		game.step_restart_hold(0.1, Input.is_action_pressed("cl_retry"))
	_t.check("S1-4 a 0.5 s hold restarts", game._restart_latched, "")
	Input.action_release("cl_retry")
	game.step_restart_hold(0.1, Input.is_action_pressed("cl_retry"))
	_t.check("S1-4 the latch clears on release", not game._restart_latched, "")


func _device() -> void:
	var game = _game
	game.note_device(_pad(JOY_BUTTON_A))
	_t.eq("S1-6 a pad button reads pad", game.last_device, "pad")
	game.note_device(_key(KEY_W))
	_t.eq("S1-6 a key reads kbm", game.last_device, "kbm")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.1
	game.note_device(stick)
	_t.eq("S1-6 a stick inside the deadzone changes nothing", game.last_device, "kbm")
	stick.axis_value = 0.6
	game.note_device(stick)
	_t.eq("S1-6 a stick past the deadzone reads pad", game.last_device, "pad")
	game.note_device(InputEventMouseMotion.new())
	_t.eq("S1-6 mouse motion reads kbm", game.last_device, "kbm")
	game.note_device(_pad(JOY_BUTTON_Y))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	game.note_device(click)
	_t.eq("S1-6 a mouse button reads kbm", game.last_device, "kbm")
