extends RefCounted

# The Spillway's two pacing locks as data (world 1 pacing levers, /mnt/project-files/world1/BUDGETS.md),
# keyed by park map id; a map with no row has neither. stage_locks.gd reads them.
#
# gate: the park Warden's clamp holds its guard shut (no posture gain, so no stagger) until `packs`
#   director packs of two or more have been broken this attempt, or one activity in `also` is done.
#   Isaac's locked boss door: the Warden asks for the verbs before the fight. `max_s` after the Warden
#   is first engaged the clamp lets go anyway, so a dry spawner can never hold a run.
# lock: the first time the ball comes within `within_m` of the beacon on the ground, the yard
#   ring-locks round it (`radius_m`, centred `ahead_m` toward the beacon) and its crew (`kinds`) lands
#   round the ring. All of them down opens it, or `max_s`. Every route crosses the circle, so the lock
#   sits on whichever line the ball takes. The crew counts as one of the gate's packs.
const ROWS := {
	"park_dam": {
		"gate": {"packs": 2, "also": ["enemy_camp"], "max_s": 120.0},
		"lock": {"id": "apron_crew", "within_m": 200.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 60.0,
			"kinds": ["chaser", "chaser", "lobber", "mag_trapper"]},
	},
	"park_flume": {
		"gate": {"packs": 2, "also": ["enemy_camp"], "max_s": 120.0},
		"lock": {"id": "forecourt_crew", "within_m": 210.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 60.0,
			"kinds": ["plated_brute", "chaser", "chaser", "lobber"]},
	},
}


static func row(map_id: String) -> Dictionary:
	return ROWS.get(map_id, {})
