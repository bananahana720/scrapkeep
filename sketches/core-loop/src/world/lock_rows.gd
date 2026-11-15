extends RefCounted

# The Spillway's two pacing locks as data (world 1 pacing levers, /mnt/project-files/world1/BUDGETS.md),
# keyed by park map id; a map with no row has neither. stage_locks.gd reads them.
#
# gate: the park Warden's clamp holds its guard shut (no posture gain, so no stagger) until `packs`
#   director packs of two or more have been broken this attempt, or one activity in `also` is done.
#   Isaac's locked boss door: the Warden asks for the verbs before the fight. `max_s` after the Warden
#   is first engaged the clamp lets go anyway, so a dry spawner can never hold a run.
# lock: the first time the ball stands on level ground within `within_m` of the beacon (on any ground
#   within the inner share of it, stage_locks.gd lock_arms), the yard
#   ring-locks round it (`radius_m`, centred `ahead_m` toward the beacon) and its crew lands round the
#   ring in `waves`, each `wave_gap_s` after the last is down (Isaac's room waves: a world 1 pack dies
#   in seconds, so the minutes are in the waves, never in health). The last wave down opens it, or
#   `max_s`. Every route crosses the circle, so the lock sits on whichever line the ball takes. The
#   whole crew counts as one of the gate's packs. No plated or holding kind rides in a ring: an
#   ungrown ball inside a wall with a mag pit or a brute's plating has no way out but the clock
#   (completionist seed 9, heft 1.0, timed out the 75 s lock on 99beaf80).
# sentry: once, the first time the ball is on the ground within `within_m` of the beacon, one `kind`
#   lands `ahead_m` up the ball's line to the beacon and `side_m` to its right: a plain enemy, no crew
#   and no pack. On the dam a lobber, so its shell is met and dodged on the way into the yard, before
#   the Warden's fight (systems audit pass E, change 4; ruling cu, harder sooner). It lands 130 m before
#   the yard shuts, so a ball at cruise meets at least one shell (a lobber's first lands 5.5 s after it is
#   in range). When the yard shuts, a sentry still outside the wall leaves (stage_locks.gd _retire_sentry);
#   one that landed inside the ring (a ball that first touched ground close in) stays and fights.
const ROWS := {
	"park_dam": {
		# 5 packs, was 4 (13 Nov, PR 956, a taste call Andrew can overturn): with packs arriving on the route the
		# gate lit early and a learner reached the stagger sooner; one more pack keeps the extra supply as fighting.
		"gate": {"packs": 5, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "apron_crew", "within_m": 200.0, "sentry": {"kind": "lobber", "within_m": 330.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 60.0, "wave_gap_s": 3.5,
			"waves": [["chaser", "chaser", "lobber"], ["lobber", "lobber", "chaser"], ["chaser", "chaser", "chaser", "lobber"], ["lobber", "chaser", "chaser"], ["chaser", "chaser", "lobber", "lobber"]],
			# Reservoir (overtime.gd): the sluice sheet runs down the apron (+z is downhill there).
			"overtime": {"flow": [0.0, 0.0, 1.0]}},
	},
	"park_flume": {
		"gate": {"packs": 1, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "forecourt_crew", "within_m": 210.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["chaser", "chaser", "lobber"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber", "lobber"], ["lobber", "chaser", "chaser"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber"], ["chaser", "chaser", "chaser", "lobber"]]},
	},
}


static func row(map_id: String) -> Dictionary:
	return ROWS.get(map_id, {})
