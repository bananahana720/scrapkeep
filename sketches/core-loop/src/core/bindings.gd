extends RefCounted

# The nine verbs the player has, by id, and the one table every key comes from. Per verb:
#   intent   the Intent field a press fills ("" where no Intent field carries it: the camera
#            reads the mouse itself)
#   fail     the cue id of the answer to a press that cannot succeed
#   actions  the InputMap actions the verb registers, each with its default "keys" (physical
#            keycodes), its mouse "button", or "motion" for the mouse look. Keyboard and
#            mouse only: a pad column joins this table with the gamepad milestone.
#   glyph    the key glyph id a prompt, a card or a diagram draws for the verb
#   label    what that glyph spells in words
#   icon     the verb's icon id ("" where the verb has no prompt picture)
# game.gd registers every action from here and holds no key table of its own.
const VERBS := {
	"roll": {"intent": "move", "fail": "none", "glyph": "key_w", "label": "W A S D", "icon": "",
		"actions": {
			"cl_forward": {"keys": [KEY_W, KEY_UP]},
			"cl_back": {"keys": [KEY_S, KEY_DOWN]},
			"cl_left": {"keys": [KEY_A, KEY_LEFT]},
			"cl_right": {"keys": [KEY_D, KEY_RIGHT]},
		}},
	"look": {"intent": "", "fail": "none", "glyph": "key_mouse", "label": "mouse", "icon": "",
		"actions": {"cl_look": {"motion": true}}},
	"jump": {"intent": "jump_pressed", "fail": "verb_fail_jump", "glyph": "key_space", "label": "Space", "icon": "ab_sable_vault",
		"actions": {"cl_jump": {"keys": [KEY_SPACE]}}},
	"fire": {"intent": "fire_pressed", "fail": "verb_fail_fire", "glyph": "key_lmb", "label": "LMB", "icon": "ab_sable_weapon",
		"actions": {"cl_fire": {"button": MOUSE_BUTTON_LEFT}}},
	"harpoon": {"intent": "harpoon_pressed", "fail": "dry_tick", "glyph": "key_rmb", "label": "RMB", "icon": "ab_sable_move",
		"actions": {"cl_harpoon": {"button": MOUSE_BUTTON_RIGHT}}},
	"haul": {"intent": "brake_held", "fail": "verb_fail_haul", "glyph": "key_ctrl", "label": "Ctrl", "icon": "ab_sable_smash",
		"actions": {"cl_haul": {"keys": [KEY_CTRL]}}},
	"boost": {"intent": "boost_pressed", "fail": "verb_fail_boost", "glyph": "key_shift", "label": "Shift", "icon": "cat_mobility",
		"actions": {"cl_boost": {"keys": [KEY_SHIFT]}}},
	"special": {"intent": "special_pressed", "fail": "verb_fail_special", "glyph": "key_f", "label": "F", "icon": "ab_sable_special",
		"actions": {"cl_special": {"keys": [KEY_F]}}},
	"interact": {"intent": "interact_pressed", "fail": "verb_fail_interact", "glyph": "key_e", "label": "E", "icon": "ab_sable_mount",
		"actions": {"cl_interact": {"keys": [KEY_E]}}},
}
const VERB_FIELDS := ["intent", "fail", "glyph", "label", "icon", "actions"]

# The ball states a key can be read in, highest first (LEGIBILITY section 3): a key means one
# verb in the highest state that holds, and a world swing is also airborne.
const STATES := ["line_body", "line_world", "charging", "mounted", "air", "ground"]

# What each verb's key does in each state. "any" is the reading of every state not named.
# "refused" is a press the ball answers with a failure cue; "brake or slam" is the ground and
# air reading of Ctrl, which a charge does not change.
const READS := {
	"roll": {"any": "drive"},
	"look": {"any": "look"},
	"jump": {"any": "jump", "air": "double jump", "mounted": "slingshot"},
	"fire": {"any": "fire"},
	"harpoon": {"any": "bite", "line_body": "fling", "line_world": "fling", "charging": "cancel"},
	"haul": {"any": "brake", "line_body": "smash", "line_world": "winch", "charging": "brake or slam", "mounted": "refused", "air": "slam"},
	"boost": {"any": "go", "mounted": "refused"},
	"special": {"any": "special", "charging": "release"},
	"interact": {"any": "interact", "mounted": "dismount"},
}


# The InputMap actions of the whole table: action name to its binding record.
static func actions() -> Dictionary:
	var out := {}
	for verb in VERBS:
		out.merge(VERBS[verb]["actions"])
	return out


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


# The ball's highest state. `line` is "" for no line, "body" or "world".
static func ball_state(line: String, charging: bool, mounted: bool, airborne: bool) -> String:
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
