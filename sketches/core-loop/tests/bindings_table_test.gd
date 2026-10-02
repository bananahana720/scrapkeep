extends SceneTree

const Game := preload("res://src/game.gd")
const Bindings := preload("res://src/core/bindings.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const ClassKit := preload("res://src/ui/class_kit.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/ui/icons.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# C1: the game's keys come from one table of nine verbs (src/core/bindings.gd).
#   - every verb has an action with a key or a button, no key serves two verbs, the InputMap
#     holds the table's actions and no others, and glyph() answers for all nine;
#   - the cut keys (the Q reel, the mouse-wheel reel, the C dash) have no handler in play: the
#     source names none of them, and pressing them moves no intent field and reels no line;
#   - over every combination of ball states, each key reads as exactly one verb in the highest
#     state that holds;
#   - F1, F3 and F4 do nothing without --dev and work with it;
#   - the field notes, class cards, controls diagram and ability bar name only the table's keys.

const CUT_NAMES := ["cl_reel", "cl_dash", "KEY_Q", "WHEEL"]
const MENU_GLYPHS := ["key_tab", "key_p", "key_r"]

var _game
var _t := T.new("bindings_table_test")
var _frames := 0


class SpyBall:
	extends Node3D

	var reels := 0

	func reel_step(_metres: float) -> void:
		reels += 1


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _frames < 4:
		return false
	_table()
	_states()
	_cut_keys()
	_dev_keys()
	_readers()
	quit(_t.verdict())
	return true


func _table() -> void:
	var seen_keys := {}
	var duplicated: Array = []
	var bare: Array = []
	for verb in Bindings.VERBS:
		var row: Dictionary = Bindings.VERBS[verb]
		if row["actions"].is_empty():
			bare.append(verb)
		for action in row["actions"]:
			var record: Dictionary = row["actions"][action]
			if not (record.has("keys") or record.has("button") or record.has("motion")):
				bare.append(action)
			for key in record.get("keys", []):
				if seen_keys.has(key):
					duplicated.append("%s: %s and %s" % [OS.get_keycode_string(key), seen_keys[key], verb])
				seen_keys[key] = verb
			if record.has("button"):
				var id := "button%d" % record["button"]
				if seen_keys.has(id):
					duplicated.append("%s: %s and %s" % [id, seen_keys[id], verb])
				seen_keys[id] = verb
	_t.eq("every verb has an action with a key or a button", bare, [])
	_t.eq("no key is bound to two verbs", duplicated, [])
	_t.eq("nine verbs", Bindings.VERBS.size(), 9)

	var table_actions := Bindings.actions()
	var strays: Array = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not table_actions.has(String(action)):
			strays.append(String(action))
	_t.eq("every action in the InputMap comes from the table", strays, [])
	var missing: Array = []
	for action in table_actions:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
			missing.append(action)
	_t.eq("every table action is registered with an event", missing, [])

	var no_glyph: Array = []
	var no_icon: Array = []
	for verb in Bindings.VERBS:
		if Bindings.glyph(verb) == "":
			no_glyph.append(verb)
		if Bindings.icon(verb) != "" and not Icons.has(Bindings.icon(verb)):
			no_icon.append(verb)
	_t.eq("glyph() answers for all nine verbs", no_glyph, [])
	_t.eq("a verb's icon is a known icon id", no_icon, [])
	_t.eq("glyph() answers empty for a word that is not a verb", Bindings.glyph("reel"), "")
	var read_actions: Array = []
	var source := (load("res://src/movement/intent.gd") as GDScript).source_code
	var at := source.find("\"cl_")
	while at >= 0:
		var end := source.find("\"", at + 1)
		var action := source.substr(at + 1, end - at - 1)
		if not table_actions.has(action):
			read_actions.append(action)
		at = source.find("\"cl_", end)
	_t.eq("the keyboard source reads only the table's actions", read_actions, [])


# Every combination of line, charge, mount and air: the state is the highest that holds, and
# each key of the table reads as exactly one verb in it.
func _states() -> void:
	var keys: Array = []
	var buttons: Array = []
	for verb in Bindings.VERBS:
		for record in Bindings.VERBS[verb]["actions"].values():
			keys.append_array(record.get("keys", []))
			if record.has("button"):
				buttons.append(record["button"])
	var wrong_state: Array = []
	var ambiguous: Array = []
	var reached := {}
	for line in ["", "body", "world"]:
		for charging in [false, true]:
			for mounted in [false, true]:
				for airborne in [false, true]:
					var state := Bindings.ball_state(line, charging, mounted, airborne)
					reached[state] = true
					var want := "line_body" if line == "body" else "line_world" if line == "world" \
						else "charging" if charging else "mounted" if mounted else "air" if airborne else "ground"
					if state != want:
						wrong_state.append("%s %s %s %s gave %s" % [line, charging, mounted, airborne, state])
					for key in keys:
						if Bindings.verbs_on(state, key, 0).size() != 1:
							ambiguous.append("%s in %s" % [OS.get_keycode_string(key), state])
					for button in buttons:
						if Bindings.verbs_on(state, 0, button).size() != 1:
							ambiguous.append("button %d in %s" % [button, state])
	_t.eq("the ball's state is the highest that holds, a world swing included", wrong_state, [])
	_t.eq("every key reads as exactly one verb in every state", ambiguous, [])
	var order := Bindings.STATES.duplicate()
	var seen: Array = reached.keys()
	seen.sort_custom(func(a, b): return order.find(a) < order.find(b))
	_t.eq("all six states are reachable, highest first", seen, order)
	_t.check("Ctrl is neither the brake nor the slam while a line stands",
		not Bindings.reading("haul", "line_body") in ["brake", "slam"] and not Bindings.reading("haul", "line_world") in ["brake", "slam"],
		"on a body %s, on the world %s" % [Bindings.reading("haul", "line_body"), Bindings.reading("haul", "line_world")])
	_t.check("Ctrl is the brake on the ground and the slam in the air", Bindings.reading("haul", "ground") == "brake" and Bindings.reading("haul", "air") == "slam",
		"ground %s, air %s" % [Bindings.reading("haul", "ground"), Bindings.reading("haul", "air")])


func _press(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event


func _cut_keys() -> void:
	for path in ["res://src/game.gd", "res://src/movement/intent.gd", "res://src/movement/player_ball.gd", "res://src/movement/chase_camera.gd"]:
		var source := (load(path) as GDScript).source_code
		var found: Array = []
		for name in CUT_NAMES:
			if source.contains(name):
				found.append(name)
		_t.eq("%s names no cut key" % path.get_file(), found, [])

	var keyboard := Intent.Keyboard.new()
	var intent := Intent.new()
	var quiet := Intent.new()
	for code in [KEY_Q, KEY_C]:
		_press(_key(code, true))
		keyboard.poll(intent)
		_press(_key(code, false))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_press(wheel)
	keyboard.poll(intent)
	var changed: Array = []
	for info in quiet.get_property_list():
		var name: String = info["name"]
		if info["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and intent.get(name) != quiet.get(name):
			changed.append(name)
	_t.eq("Q, C and the wheel change no intent field", changed, [])

	var spy := SpyBall.new()
	var real_player = _game.player
	_game.player = spy
	_game.test_mode = false
	for button in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = true
		_game._input(event)
	for code in [KEY_Q, KEY_C]:
		_game._input(_key(code, true))
	_game.test_mode = true
	_game.player = real_player
	_t.eq("the wheel, Q and C in play reel no line", spy.reels, 0)
	spy.free()


func _dev_keys() -> void:
	_t.check("the game launched without --dev is not in dev mode", not _game.dev and not Game._launch_flag("--dev"), "dev %s" % _game.dev)
	var before := _tuning_files()
	var panel_before: bool = _game.panel.visible
	var interpolating_before: bool = _game.interpolating()
	_game.test_mode = false
	for code in [KEY_F1, KEY_F3, KEY_F4]:
		_game._input(_key(code, true))
	_game.test_mode = true
	_t.check("F1, F3 and F4 do nothing without --dev",
		_game.panel.visible == panel_before and _game.interpolating() == interpolating_before and _tuning_files() == before,
		"panel %s, interpolation %s, new tuning files %s" % [_game.panel.visible, _game.interpolating(), _tuning_files().size() - before.size()])

	_game.dev = true
	_game.test_mode = false
	_game._input(_key(KEY_F1, true))
	var panel_toggled: bool = _game.panel.visible != panel_before
	_game._input(_key(KEY_F1, true))
	_game._input(_key(KEY_F3, true))
	var interpolation_toggled: bool = _game.interpolating() != interpolating_before
	_game._input(_key(KEY_F3, true))
	_game._input(_key(KEY_F4, true))
	_game.test_mode = true
	_game.dev = false
	var written := _tuning_files().filter(func(file): return not file in before)
	for file in written:
		DirAccess.remove_absolute("user://".path_join(file))
	_t.check("F1, F3 and F4 work with --dev", panel_toggled and interpolation_toggled and written.size() == 1,
		"F1 toggled the panel %s, F3 toggled interpolation %s, F4 wrote %d file" % [panel_toggled, interpolation_toggled, written.size()])


static func _tuning_files() -> Array:
	return Array(DirAccess.get_files_at("user://")).filter(func(file: String) -> bool: return file.begins_with("tuning-"))


# The screens that name keys read the table: the field notes' list, the class cards' kit rows,
# the controls diagram and the ability bar's slot keys.
func _readers() -> void:
	var glyphs: Array = []
	for verb in Bindings.VERBS:
		glyphs.append(Bindings.glyph(verb))
	var allowed: Array = glyphs.duplicate()
	allowed.append_array(MENU_GLYPHS)
	for key in "wasd":
		allowed.append("key_" + key)

	var rows: Array = FieldNotes.CONTROLS
	var verb_rows_ok := true
	var detail := PackedStringArray()
	for i in FieldNotes.VERB_ROWS.size():
		var verb: String = FieldNotes.VERB_ROWS[i][0]
		var row: Dictionary = rows[i]
		var caps_ok: bool = row["caps"] == [Bindings.glyph(verb)] or (verb == "roll" and row["caps"] == ["key_w", "key_a", "key_s", "key_d"])
		if row["keys"] != Bindings.label(verb) or not caps_ok:
			verb_rows_ok = false
			detail.append("%s: keys %s caps %s" % [verb, row["keys"], row["caps"]])
	_t.check("the field notes list the nine verbs with their table keys, in order", verb_rows_ok and FieldNotes.VERB_ROWS.size() == 9, "; ".join(detail))
	var named: Array = []
	for row in rows:
		var keys: String = row["keys"]
		if keys.begins_with("Q") or keys.contains("wheel") or keys == "C":
			named.append(keys)
	_t.eq("no field-notes row names Q, C or the wheel as a key", named, [])
	var cap_strays: Array = []
	for row in rows:
		for cap in row.get("caps", []):
			if not cap in allowed:
				cap_strays.append(cap)
	_t.eq("every cap in the field notes is a table key or a menu key", cap_strays, [])

	var slot_strays: Array = []
	for def in _game.flow.classes:
		for record in ClassKit.keys(def):
			if not record["key"] in glyphs:
				slot_strays.append("%s %s" % [def.display_name, record["key"]])
		var movement: Dictionary = ClassKit.keys(def)[1]
		var want := "key_rmb" if "grapple" in AbilityState.ABILITIES[String(def.movement_id)].get("augments", []) else "key_shift"
		if movement["key"] != want:
			slot_strays.append("%s movement %s, want %s" % [def.display_name, movement["key"], want])
		for key in ControlsDiagram.entries(def):
			if not key in allowed and not key == ControlsDiagram.LOOK:
				slot_strays.append("diagram %s %s" % [def.display_name, key])
	_t.eq("the class kit rows and the diagram name only table keys, each pilot's movement on its own", slot_strays, [])

	var bar_strays: Array = []
	var want_keys := {AbilityState.WEAPON: "fire", AbilityState.MOVEMENT: "harpoon", AbilityState.SPECIAL: "special", AbilityState.SMASH: "haul"}
	for slot in want_keys:
		if AbilityState.KEYS[slot] != Bindings.label(want_keys[slot]):
			bar_strays.append("%s reads %s" % [slot, AbilityState.KEYS[slot]])
	for record in _game.player.abilities.slots():
		if not ("key_" + String(record["key"]).to_lower()) in glyphs:
			bar_strays.append("slot %s shows %s" % [record["slot"], record["key"]])
	_t.eq("the ability bar's slot keys are the table's", bar_strays, [])
