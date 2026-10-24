extends RefCounted

# The Spillway's two pacing locks as data (world 1 pacing levers, /mnt/project-files/world1/BUDGETS.md),
# keyed by park map id; a map with no row has neither. stage_locks.gd reads them.
#
# gate: the park Warden's clamp holds its guard shut (no posture gain, so no stagger) until `packs`
#   director packs of two or more have been broken this attempt, or one activity in `also` is done.
#   Isaac's locked boss door: the Warden asks for the verbs before the fight. `max_s` after the Warden
#   is first engaged the clamp lets go anyway, so a dry spawner can never hold a run.
# lock: the first time the ball comes within `within_m` of the beacon on the ground, the yard
#   ring-locks round it (`radius_m`, centred `ahead_m` toward the beacon) and its crew lands round the
#   ring in `waves`, each `wave_gap_s` after the last is down (Isaac's room waves: a world 1 pack dies
#   in seconds, so the minutes are in the waves, never in health). The last wave down opens it, or
#   `max_s`. Every route crosses the circle, so the lock sits on whichever line the ball takes. The
#   whole crew counts as one of the gate's packs.
const ROWS := {
	"park_dam": {
		"gate": {"packs": 2, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "apron_crew", "within_m": 200.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 75.0, "wave_gap_s": 1.5,
			"waves": [["chaser", "chaser", "lobber"], ["mag_trapper", "lobber", "chaser"], ["chaser", "chaser", "chaser", "lobber"]]},
	},
	"park_flume": {
		"gate": {"packs": 2, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "forecourt_crew", "within_m": 210.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 75.0, "wave_gap_s": 1.5,
			"waves": [["chaser", "chaser", "lobber"], ["plated_brute", "chaser"], ["mag_trapper", "lobber", "lobber", "chaser"]]},
	},
}


static func row(map_id: String) -> Dictionary:
	return ROWS.get(map_id, {})
