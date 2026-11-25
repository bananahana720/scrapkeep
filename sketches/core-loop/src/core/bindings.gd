extends RefCounted

const VERBS := {
	"roll": {"intent": "move", "fail": "verb_fail_roll", "glyph": "key_w", "label": "W A S D", "icon": "",
		"actions": {
			"cl_forward": {"keys": [KEY_W, KEY_UP], "axis": [JOY_AXIS_LEFT_Y, -1]},
			"cl_back": {"keys": [KEY_S, KEY_DOWN], "axis": [JOY_AXIS_LEFT_Y, 1]},
			"cl_left": {"keys": [KEY_A, KEY_LEFT], "axis": [JOY_AXIS_LEFT_X, -1]},
			"cl_right": {"keys": [KEY_D, KEY_RIGHT], "axis": [JOY_AXIS_LEFT_X, 1]},
		}},
	"look": {"intent": "", "fail": "none", "glyph": "key_mouse", "label": "mouse", "icon": "",
		"actions": {
			"cl_look": {"motion": true},
			"cl_look_left": {"axis": [JOY_AXIS_RIGHT_X, -1]},
			"cl_look_right": {"axis": [JOY_AXIS_RIGHT_X, 1]},
			"cl_look_up": {"axis": [JOY_AXIS_RIGHT_Y, -1]},
			"cl_look_down": {"axis": [JOY_AXIS_RIGHT_Y, 1]},
		}},
	"jump": {"intent": "jump_pressed", "fail": "verb_fail_jump", "glyph": "key_space", "label": "Space", "icon": "ab_sable_vault",
		"actions": {"cl_jump": {"keys": [KEY_SPACE], "pad": JOY_BUTTON_A}}},
	"fire": {"intent": "fire_pressed", "fail": "verb_fail_fire", "glyph": "key_lmb", "label": "LMB", "icon": "ab_sable_weapon",
		"actions": {"cl_fire": {"button": MOUSE_BUTTON_LEFT, "axis": [JOY_AXIS_TRIGGER_RIGHT, 1]}}},
	"harpoon": {"intent": "harpoon_pressed", "fail": "dry_tick", "glyph": "key_rmb", "label": "RMB", "icon": "ab_sable_move",
		"actions": {"cl_harpoon": {"button": MOUSE_BUTTON_RIGHT, "axis": [JOY_AXIS_TRIGGER_LEFT, 1]}}},
	"haul": {"intent": "brake_held", "fail": "verb_fail_haul", "glyph": "key_ctrl", "label": "Ctrl", "icon": "ab_sable_smash",
		"actions": {"cl_haul": {"keys": [KEY_CTRL], "pad": JOY_BUTTON_X}}},
	"boost": {"intent": "boost_pressed", "fail": "verb_fail_boost", "glyph": "key_shift", "label": "Shift", "icon": "cat_mobility",
		"actions": {"cl_boost": {"keys": [KEY_SHIFT], "pad": JOY_BUTTON_B}}},
	"special": {"intent": "special_pressed", "fail": "verb_fail_special", "glyph": "key_f", "label": "F", "icon": "ab_sable_special",
		"retired": true, "actions": {"cl_special": {"keys": []}}},
	"interact": {"intent": "interact_pressed", "fail": "verb_fail_interact", "glyph": "key_e", "label": "E", "icon": "ab_sable_mount",
		"actions": {"cl_interact": {"keys": [KEY_E], "pad": JOY_BUTTON_Y}}},
	"select": {"intent": "slot_pick", "fail": "verb_fail_select", "glyph": "key_1", "label": "1 2 3", "icon": "",
		"actions": {
			"cl_bay_1": {"keys": [KEY_1], "pad": JOY_BUTTON_DPAD_LEFT},
			"cl_bay_2": {"keys": [KEY_2], "pad": JOY_BUTTON_DPAD_UP},
			"cl_bay_3": {"keys": [KEY_3], "pad": JOY_BUTTON_DPAD_RIGHT},
		}},
	"ultimate": {"intent": "ultimate_pressed", "fail": "verb_fail_ultimate", "glyph": "key_q", "label": "Q", "icon": "",
		"actions": {"cl_ultimate": {"keys": [KEY_Q], "pad": JOY_BUTTON_LEFT_SHOULDER}}},
	"active": {"intent": "active_pressed", "fail": "verb_fail_active", "glyph": "key_f", "label": "F", "icon": "cat_damage",
		"actions": {"cl_active": {"keys": [KEY_F], "pad": JOY_BUTTON_DPAD_DOWN}}},
}
const EXTRA_ACTIONS := {
	"cl_retry": {"keys": [KEY_R], "pad": JOY_BUTTON_RIGHT_SHOULDER},
	"cl_pause": {"keys": [KEY_P, KEY_ESCAPE], "pad": JOY_BUTTON_START},
	"cl_consumable": {"keys": [KEY_C]},
	"cl_radio_next": {"keys": [KEY_PERIOD]},
	"cl_radio_prev": {"keys": [KEY_COMMA]},
	"cl_radio_skip": {"keys": [KEY_SLASH]},
	"cl_radio_pin": {"keys": [KEY_SEMICOLON]},
}
const CONSUMABLE_ACTION := "cl_consumable"
const CONSUMABLE_PAD := JOY_BUTTON_LEFT_STICK
const SITTING_CHORD_PAD := JOY_BUTTON_RIGHT_STICK
static var _consumable_pad_down := false
static var _consumable_pad_chord_used := false
const SELECT_ACTIONS := ["cl_bay_1", "cl_bay_2", "cl_bay_3"]
const UI_PAD := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
const VERB_FIELDS := ["intent", "fail", "glyph", "label", "icon", "actions"]

const STATES := ["set_piece", "line_body", "line_world", "charging", "mounted", "air", "ground"]

const READS := {
	"roll": {"any": "drive"},
	"look": {"any": "look"},
	"jump": {"any": "jump", "air": "double jump", "mounted": "slingshot", "set_piece": "bail"},
	"fire": {"any": "fire", "charging": "release", "set_piece": ""},
	"harpoon": {"any": "bite", "line_body": "fling", "line_world": "fling", "charging": "cancel", "set_piece": ""},
	"haul": {"any": "brake", "line_body": "smash", "line_world": "winch", "charging": "brake or slam", "mounted": "refused", "air": "slam",
		"set_piece": ""},
	"boost": {"any": "go", "mounted": "refused", "set_piece": ""},
	"interact": {"any": "interact", "mounted": "dismount", "set_piece": ""},
	"select": {"any": "pick", "charging": "swap", "set_piece": ""},
	"ultimate": {"any": "ultimate", "set_piece": "recall"},
	"active": {"any": "fire active", "set_piece": ""},
}


static func actions() -> Dictionary:
	var out := {}
	for verb in VERBS:
		out.merge(VERBS[verb]["actions"])
	out.merge(EXTRA_ACTIONS)
	return out


static func _pad_claimed_elsewhere(button: int) -> bool:
	for action in actions().keys():
		if action == CONSUMABLE_ACTION or not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == button:
				return true
	return false


static func step_consumable_pad_state(l3_down: bool, r3_down: bool) -> bool:
	if l3_down:
		if not _consumable_pad_down:
			_consumable_pad_chord_used = r3_down
		elif r3_down:
			_consumable_pad_chord_used = true
		_consumable_pad_down = true
		return false
	var fired := _consumable_pad_down and not _consumable_pad_chord_used and not r3_down
	_consumable_pad_down = false
	_consumable_pad_chord_used = false
	return fired


static func consumable_just_pressed() -> bool:
	if InputMap.has_action(CONSUMABLE_ACTION) and Input.is_action_just_pressed(CONSUMABLE_ACTION):
		return true
	var l3_down := false
	var r3_down := false
	if not _pad_claimed_elsewhere(CONSUMABLE_PAD):
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			l3_down = Input.is_joy_button_pressed(0, CONSUMABLE_PAD)
			r3_down = Input.is_joy_button_pressed(0, SITTING_CHORD_PAD)
		else:
			for pad_id in pads:
				if Input.is_joy_button_pressed(pad_id, CONSUMABLE_PAD):
					l3_down = true
				if Input.is_joy_button_pressed(pad_id, SITTING_CHORD_PAD):
					r3_down = true
	return step_consumable_pad_state(l3_down, r3_down)


static func verb_of_action(action: String) -> String:
	for verb in VERBS:
		if VERBS[verb]["actions"].has(action):
			return verb
	return ""


static func glyph(verb: String) -> String:
	return VERBS[verb]["glyph"] if VERBS.has(verb) else ""


static func label(verb: String) -> String:
	return VERBS[verb]["label"] if VERBS.has(verb) else ""


static func icon(verb: String) -> String:
	return VERBS[verb]["icon"] if VERBS.has(verb) else ""


static func ball_state(line: String, charging: bool, mounted: bool, airborne: bool, set_piece := false) -> String:
	if set_piece:
		return "set_piece"
	if line == "body":
		return "line_body"
	if line == "world":
		return "line_world"
	if charging:
		return "charging"
	if mounted:
		return "mounted"
	return "air" if airborne else "ground"


static func reading(verb: String, state: String) -> String:
	var row: Dictionary = READS.get(verb, {})
	return String(row.get(state, row.get("any", "")))


static func verbs_on(state: String, key: int, button: int) -> Array[String]:
	var out: Array[String] = []
	for verb in VERBS:
		if reading(verb, state) == "":
			continue
		for record in VERBS[verb]["actions"].values():
			if (key != 0 and key in record.get("keys", [])) or (button != 0 and record.get("button", 0) == button):
				if not verb in out:
					out.append(verb)
	return out


static var _warned_tokens := {}
const TRIGGER_AXES := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]


static func reset_for_tests() -> void:
	_warned_tokens.clear()
	_consumable_pad_down = false
	_consumable_pad_chord_used = false


static func kind_of(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "pad"
	if event is InputEventJoypadMotion:
		return "axis"
	return "desk"


static func encode(events: Array) -> String:
	var tokens: PackedStringArray = []
	for event in events:
		if event is InputEventKey and event.physical_keycode != KEY_NONE:
			tokens.append("key:" + OS.get_keycode_string(event.physical_keycode))
		elif event is InputEventMouseButton and event.button_index != 0:
			tokens.append("mouse:%d" % event.button_index)
		elif event is InputEventJoypadButton and event.button_index >= 0:
			tokens.append("pad:%d" % event.button_index)
		elif event is InputEventJoypadMotion and event.axis in TRIGGER_AXES:
			tokens.append("axis:%d" % event.axis)
	return ",".join(tokens)


static func decode(text: String) -> Array:
	var out := []
	for raw in text.split(",", false):
		var token := raw.strip_edges()
		var event: InputEvent = null
		if token.begins_with("key:"):
			var code := OS.find_keycode_from_string(token.substr(4))
			if code != KEY_NONE:
				var key := InputEventKey.new()
				key.physical_keycode = code
				event = key
		elif token.begins_with("mouse:") and token.substr(6).is_valid_int():
			var index := token.substr(6).to_int()
			if index > 0:
				var click := InputEventMouseButton.new()
				click.button_index = index
				event = click
		elif token.begins_with("pad:") and token.substr(4).is_valid_int():
			var index := token.substr(4).to_int()
			if index >= 0 and index < JOY_BUTTON_SDL_MAX:
				var pad := InputEventJoypadButton.new()
				pad.button_index = index
				event = pad
		elif token.begins_with("axis:") and token.substr(5).is_valid_int() and token.substr(5).to_int() in TRIGGER_AXES:
			var trigger := InputEventJoypadMotion.new()
			trigger.axis = token.substr(5).to_int()
			trigger.axis_value = 1.0
			event = trigger
		if event != null:
			out.append(event)
		elif not _warned_tokens.has(token):
			_warned_tokens[token] = true
			push_warning("bindings: skipped token \"%s\"" % token)
	return out
