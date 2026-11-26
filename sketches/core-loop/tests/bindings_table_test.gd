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
# Table checks read the table, the source or the screens' data and never run a player: the
# table, the state walk (_states), the cut-key source scan, the dev keys' gate and the readers.
# Player-driven checks are in harpoon_canon_test (a scripted ball on a world line and on a body
# line pressing Ctrl, and the HUD's prompts against verb_ready); this file has none. The cut
# keys' source scan (the source names no Q, wheel or C handler) is the check that fails if one
# comes back; the intent check below fails if the keyboard source reads one.
#   - every verb has an action with a key or a button, no key serves two verbs, the InputMap
#     holds the table's actions and no others, and glyph() answers for all nine;
#   - the cut keys (the Q reel, the mouse-wheel reel, the C dash) have no handler in play: the
#     source names none of them, and pressing them moves no intent field;
#   - over every combination of ball states, each key reads as exactly one verb in the highest
#     state that holds;
#   - F1, F3 and F4 do nothing without --dev and work with it;
#   - the field notes, class cards, controls diagram and ability bar name only the table's keys.
# Re-pinned 2026-10-10 for the skill bar (design-v3/SKILL-BAR.md sections 1 and 6, wave P-B
# unit B1): the table holds eleven rows, ten live verbs plus the retired special, whose
# cl_special keeps no key. 2026-10-17: the active joined as the twelfth row and holds F. select owns 1, 2 and 3 (the old card
# bays) and ultimate owns Q, so Q is no longer a cut key: pressing it fills ultimate_pressed
# and nothing else, and the source still names no KEY_Q (the key comes from the table). The
# set_piece state sits above the rest, and the bar shows 1, 2, 3 on its slots and Shift and
# Ctrl on its chips. The field-notes row count stays nine until the HUD unit (B2) re-pins it.
# Re-pinned 2026-10-10 (wave 13 unit B2, SKILL-BAR section 5): the field notes list ten verbs,
# the special row retired and select (caps 1, 2, 3) and ultimate (Q) added; Q names the ultimate's
# row and no cut key. The class kit's movement record is found by its slot, since the card now
# leads with the bar row (1, 2, 3, Q) before the chips.
# Re-pinned 2026-10-10 for the set piece (wave P-B unit B3): SKILL-BAR sections 2 and 4 let Q
# through during the set piece as recall (a full refund in the wind-up), so in set_piece the
# roll, Space (bail) and Q (recall) read, and nothing else.
# Re-pinned 2026-11-26: C returned in Bindings.EXTRA_ACTIONS["cl_consumable"] for held
# consumables (never cl_dash), so FieldNotes may list "C" only for consumables while cl_dash
# stays banned and KEY_C still changes no movement Intent field.

const CUT_NAMES := ["cl_reel", "cl_dash", "KEY_Q", "WHEEL"]
const MENU_GLYPHS := ["key_tab", "key_p", "key_r"]

var _game
var _t := T.new("bindings_table_test")
var _frames := 0


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
			if not (record.has("keys") or record.has("button") or record.has("motion") or record.has("pad") or record.has("axis")):
				bare.append(action)
			if record.has("pad"):
				var pad_id := "pad%d" % record["pad"]
				if seen_keys.has(pad_id) and seen_keys[pad_id] != verb:
					duplicated.append("%s: %s and %s" % [pad_id, seen_keys[pad_id], verb])
				seen_keys[pad_id] = verb
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
	var retired: Array = Bindings.VERBS.keys().filter(func(v): return Bindings.VERBS[v].get("retired", false))
	_t.eq("twelve rows, the special the one retired", [Bindings.VERBS.size(), retired], [12, ["special"]])
	_t.eq("1, 2, 3 are select and Q is ultimate", [Bindings.VERBS["select"]["actions"].keys(), Bindings.VERBS["ultimate"]["actions"].keys(),
		Bindings.VERBS["ultimate"]["actions"]["cl_ultimate"]["keys"]], [["cl_bay_1", "cl_bay_2", "cl_bay_3"], ["cl_ultimate"], [KEY_Q]])
	# 2026-10-17 (item tiers and actives): F came back as the active's key, never the special's.
	_t.check("F is the active's key: cl_special has no event and only cl_active holds F",
		InputMap.has_action("cl_special") and InputMap.action_get_events("cl_special").is_empty() and seen_keys.get(KEY_F, "") == "active",
		"cl_special events %d, F bound to %s" % [InputMap.action_get_events("cl_special").size() if InputMap.has_action("cl_special") else -1, seen_keys.get(KEY_F, "")])

	var table_actions := Bindings.actions()
	var strays: Array = []
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_") and not table_actions.has(String(action)):
			strays.append(String(action))
	_t.eq("every action in the InputMap comes from the table", strays, [])
	var missing: Array = []
	for action in table_actions:
		if action == "cl_special":
			continue
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
	# The set piece sits above every other state; in it only the roll, Space (bail) and Q (recall) read.
	var live_in_set_piece: Array = []
	for line in ["", "body", "world"]:
		for charging in [false, true]:
			var state := Bindings.ball_state(line, charging, false, true, true)
			reached[state] = true
			if state != "set_piece":
				wrong_state.append("%s %s set piece gave %s" % [line, charging, state])
	for key in keys:
		var on := Bindings.verbs_on("set_piece", key, 0)
		if on.size() > 1:
			ambiguous.append("%s in set_piece" % OS.get_keycode_string(key))
		for verb in on:
			if not verb in live_in_set_piece:
				live_in_set_piece.append(verb)
	_t.eq("the ball's state is the highest that holds, a world swing included", wrong_state, [])
	_t.eq("every key reads as exactly one verb in every state", ambiguous, [])
	_t.eq("in a set piece only the roll, the bail and the recall read",
		[live_in_set_piece, Bindings.reading("jump", "set_piece"), Bindings.reading("ultimate", "set_piece")],
		[["roll", "jump", "ultimate"], "bail", "recall"])
	var order := Bindings.STATES.duplicate()
	var seen: Array = reached.keys()
	seen.sort_custom(func(a, b): return order.find(a) < order.find(b))
	_t.eq("all six states are reachable, highest first", seen, order)
	_t.check("Ctrl is neither the brake nor the slam while a line stands",
		not Bindings.reading("haul", "line_body") in ["brake", "slam"] and not Bindings.reading("haul", "line_world") in ["brake", "slam"],
		"on a body %s, on the world %s" % [Bindings.reading("haul", "line_body"), Bindings.reading("haul", "line_world")])
	_t.check("Ctrl is the brake on the ground and the slam in the air", Bindings.reading("haul", "ground") == "brake" and Bindings.reading("haul", "air") == "slam",
		"ground %s, air %s" % [Bindings.reading("haul", "ground"), Bindings.reading("haul", "air")])
	_t.check("mounted, Ctrl and Shift read as refused, and a charge does not hide the brake from the slam",
		Bindings.reading("haul", "mounted") == "refused" and Bindings.reading("boost", "mounted") == "refused"
		and Bindings.reading("haul", "charging") == "brake or slam",
		"mounted Ctrl %s, Shift %s, charging Ctrl %s" % [Bindings.reading("haul", "mounted"), Bindings.reading("boost", "mounted"), Bindings.reading("haul", "charging")])

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
	for code in [KEY_C]:
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
	_t.eq("C and the wheel change no intent field", changed, [])
	# Q last: a just-pressed key reads as pressed until the frame turns over.
	var q_intent := Intent.new()
	_press(_key(KEY_Q, true))
	keyboard.poll(q_intent)
	_press(_key(KEY_Q, false))
	var q_changed: Array = []
	for info in quiet.get_property_list():
		var q_name: String = info["name"]
		if info["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and q_intent.get(q_name) != quiet.get(q_name):
			q_changed.append(q_name)
	_t.eq("Q fills ultimate_pressed and nothing else", q_changed, ["ultimate_pressed"])


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
	# select is one verb on three keys; its row's glyph is key_1, and 2 and 3 are its own too.
	glyphs.append_array(["key_2", "key_3"])
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
		var caps_ok: bool = row["caps"] == [Bindings.glyph(verb)] or (verb == "roll" and row["caps"] == ["key_w", "key_a", "key_s", "key_d"]) \
			or (verb == "select" and row["caps"] == ["key_1", "key_2", "key_3"])
		if row["keys"] != Bindings.label(verb) or not caps_ok:
			verb_rows_ok = false
			detail.append("%s: keys %s caps %s" % [verb, row["keys"], row["caps"]])
	_t.check("the field notes list the ten verbs with their table keys, in order", verb_rows_ok and FieldNotes.VERB_ROWS.size() == 10
		and not FieldNotes.VERB_ROWS.any(func(r): return r[0] == "special"), "; ".join(detail))
	var c_is_consumable: bool = KEY_C in Bindings.EXTRA_ACTIONS.get(Bindings.CONSUMABLE_ACTION, {}).get("keys", [])
	var named: Array = []
	for row in rows:
		var keys: String = row["keys"]
		var does: String = String(row.get("does", "")).to_lower()
		var c_cut := keys == "C" and (not c_is_consumable or not does.contains("consumable"))
		if (keys.begins_with("Q") and keys != Bindings.label("ultimate")) or keys.contains("wheel") or c_cut:
			named.append(keys)
	_t.eq("no field-notes row names a cut key (Q reel, C dash or wheel)", named, [])
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
		var movement: Dictionary = ClassKit.keys(def).filter(func(r): return r["slot"] == AbilityState.MOVEMENT)[0]
		var want := "key_rmb" if "grapple" in AbilityState.ABILITIES[String(def.movement_id)].get("augments", []) else "key_shift"
		if movement["key"] != want:
			slot_strays.append("%s movement %s, want %s" % [def.display_name, movement["key"], want])
		for key in ControlsDiagram.entries(def):
			if not key in allowed and not key == ControlsDiagram.LOOK:
				slot_strays.append("diagram %s %s" % [def.display_name, key])
	_t.eq("the class kit rows and the diagram name only table keys, each pilot's movement on its own", slot_strays, [])

	var bar_strays: Array = []
	var want_keys := {AbilityState.WEAPON: "1", AbilityState.MOVEMENT: Bindings.label("boost"), AbilityState.SPECIAL: "2",
		AbilityState.SMASH: Bindings.label("haul"), AbilityState.LINE: "3"}
	for slot in want_keys:
		if AbilityState.KEYS[slot] != want_keys[slot]:
			bar_strays.append("%s reads %s" % [slot, AbilityState.KEYS[slot]])
	for record in _game.player.abilities.slots():
		if not ("key_" + String(record["key"]).to_lower()) in glyphs:
			bar_strays.append("slot %s shows %s" % [record["slot"], record["key"]])
	_t.eq("the ability bar's slot keys are the table's", bar_strays, [])
