extends RefCounted

# The nine verbs the player has, by id. `intent` names the Intent field a press of the verb
# fills ("" where no Intent field carries it: the camera reads the mouse itself); `fail` is
# the cue id of the answer to a press that cannot succeed. Ids and field names only: no key
# codes live here.
const VERBS := {
	"roll": {"intent": "move", "fail": "none"},
	"look": {"intent": "", "fail": "none"},
	"jump": {"intent": "jump_pressed", "fail": "verb_fail_jump"},
	"fire": {"intent": "fire_pressed", "fail": "verb_fail_fire"},
	"harpoon": {"intent": "harpoon_pressed", "fail": "dry_tick"},
	"haul": {"intent": "reel_held", "fail": "verb_fail_haul"},
	"boost": {"intent": "boost_pressed", "fail": "verb_fail_boost"},
	"special": {"intent": "special_pressed", "fail": "verb_fail_special"},
	"interact": {"intent": "interact_pressed", "fail": "verb_fail_interact"},
}
const VERB_FIELDS := ["intent", "fail"]

