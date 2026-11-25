extends RefCounted

# The verbs the player has, by id, and the one table every key comes from. Per verb:
#   intent   the Intent field a press fills ("" where no Intent field carries it: the camera
#            reads the mouse itself)
#   fail     the cue id of the answer to a press that cannot succeed
#   actions  the InputMap actions the verb registers, each with its default "keys" (physical
#            keycodes), its mouse "button", or "motion" for the mouse look, and its gamepad
#            defaults: "pad" (a JOY_BUTTON_* index) and "axis" ([JOY_AXIS_*, sign]).
#   glyph    the key glyph id a prompt, a card or a diagram draws for the verb
#   label    what that glyph spells in words
#   icon     the verb's icon id ("" where the verb has no prompt picture)
#   retired  true on a verb no key fills any more (the old F special), kept for its readers
# game.gd registers every action from here and holds no key table of its own.
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
	# Retired (SKILL-BAR section 6): F is unbound in play and the special is slot 2, cast by
	# left click after a 2. The row stays, with no key, so the screens that still list the
	# special verb keep reading it until wave P-B's HUD unit drops it; special_* are now the
	# router's outputs, and no key fills them.
	"special": {"intent": "special_pressed", "fail": "verb_fail_special", "glyph": "key_f", "label": "F", "icon": "ab_sable_special",
		"retired": true, "actions": {"cl_special": {"keys": []}}},
	"interact": {"intent": "interact_pressed", "fail": "verb_fail_interact", "glyph": "key_e", "label": "E", "icon": "ab_sable_mount",
		"actions": {"cl_interact": {"keys": [KEY_E], "pad": JOY_BUTTON_Y}}},
	# Keys 1, 2, 3 pick the bar slot left click casts (SKILL-BAR section 1). The actions keep
	# their cl_bay names from Tally's old card bays.
	"select": {"intent": "slot_pick", "fail": "verb_fail_select", "glyph": "key_1", "label": "1 2 3", "icon": "",
		"actions": {
			"cl_bay_1": {"keys": [KEY_1], "pad": JOY_BUTTON_DPAD_LEFT},
			"cl_bay_2": {"keys": [KEY_2], "pad": JOY_BUTTON_DPAD_UP},
			"cl_bay_3": {"keys": [KEY_3], "pad": JOY_BUTTON_DPAD_RIGHT},
		}},
	# Q is the ultimate (SKILL-BAR section 4); LB is free since the special retired.
	"ultimate": {"intent": "ultimate_pressed", "fail": "verb_fail_ultimate", "glyph": "key_q", "label": "Q", "icon": "",
		"actions": {"cl_ultimate": {"keys": [KEY_Q], "pad": JOY_BUTTON_LEFT_SHOULDER}}},
	# F fires the racked active (src/combat/actives), the one item slot on a key. The key is
	# bound always; with --actives off nothing is racked and a press does nothing.
	"active": {"intent": "active_pressed", "fail": "verb_fail_active", "glyph": "key_f", "label": "F", "icon": "cat_damage",
		"actions": {"cl_active": {"keys": [KEY_F], "pad": JOY_BUTTON_DPAD_DOWN}}},
}
# Actions that belong to no verb: the retry hold (R, RB), the pause (P and Escape, Start) and
# the pilot radio (radio_deck.gd): period turns the dial on (D-pad down is the active's), comma
# turns it back, slash skips to the next track, semicolon pins the track on air through a boss.
const EXTRA_ACTIONS := {
	"cl_retry": {"keys": [KEY_R], "pad": JOY_BUTTON_RIGHT_SHOULDER},
	"cl_pause": {"keys": [KEY_P, KEY_ESCAPE], "pad": JOY_BUTTON_START},
	"cl_consumable": {"keys": [KEY_C]},
	"cl_radio_next": {"keys": [KEY_PERIOD]},
	"cl_radio_prev": {"keys": [KEY_COMMA]},
	"cl_radio_skip": {"keys": [KEY_SLASH]},
	"cl_radio_pin": {"keys": [KEY_SEMICOLON]},
}
# Pocket Consumable Belt quick-tap (W47-C1): keyboard C via InputMap + gamepad D-pad Up
# quick-tap read without colliding with cl_bay_2's InputMap pad uniqueness check.
const CONSUMABLE_ACTION := "cl_consumable"
const CONSUMABLE_PAD := JOY_BUTTON_DPAD_UP
# The bar slot each select action picks, by its index in Intent.slot_pick.
const SELECT_ACTIONS := ["cl_bay_1", "cl_bay_2", "cl_bay_3"]
# The engine's ui_* actions have no pad button, so a pad moves menu focus but cannot press or go
# back. Boot adds these two rows to ui_accept and ui_cancel and keeps the engine's key events.
const UI_PAD := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
const VERB_FIELDS := ["intent", "fail", "glyph", "label", "icon", "actions"]

# The ball states a key can be read in, highest first (LEGIBILITY section 3): a key means one
# verb in the highest state that holds, and a world swing is also airborne.
# set_piece is the ultimate's ride (SKILL-BAR section 6): every key but the roll, Space (bail)
# and Q is swallowed.
const STATES := ["set_piece", "line_body", "line_world", "charging", "mounted", "air", "ground"]

# What each verb's key does in each state. "any" is the reading of every state not named.
# "refused" is a press the ball answers with a failure cue; "brake or slam" is the ground and
# air reading of Ctrl, which a charge does not change. "" is a key that does nothing there.
# The retired special has no row, so it reads "" everywhere.
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
	# Q reads "recall" in the set piece: it cancels the wind-up with a full refund (SKILL-BAR
	# sections 2 and 4); in flight the press is refused busy.
	"ultimate": {"any": "ultimate", "set_piece": "recall"},
	"active": {"any": "fire active", "set_piece": ""},
}


# The InputMap actions of the whole table: action name to its binding record.
static func actions() -> Dictionary:
	var out := {}
	for verb in VERBS:
		out.merge(VERBS[verb]["actions"])
	out.merge(EXTRA_ACTIONS)
	return out


static func consumable_just_pressed() -> bool:
	return InputMap.has_action(CONSUMABLE_ACTION) and Input.is_action_just_pressed(CONSUMABLE_ACTION)


# The verb that registers `action`, or "" for an action the table does not hold.
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


# The ball's highest state. `line` is "" for no line, "body" or "world"; `set_piece` is true
# while the ultimate rides.
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


# Every verb that reads the physical key `key` or the mouse button `button` in `state`. A key
# belongs to one verb, so the answer holds one entry for a bound key and none for a free one.
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


# One token per event, comma separated: "key:<name>" (OS.get_keycode_string of the physical
# keycode), "mouse:<button index>", "pad:<JOY_BUTTON index>" or "axis:<trigger JOY_AXIS index>".
# Mouse motion and the sticks cannot be bound.
static var _warned_tokens := {}
const TRIGGER_AXES := [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]


# "desk" for a key or mouse button, "pad" for a pad button, "axis" for a trigger.
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


# The events `text` names. A token that does not parse is skipped and warns once per token text.
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
