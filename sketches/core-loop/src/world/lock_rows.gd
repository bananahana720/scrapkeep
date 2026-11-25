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
#   The last two waves each carry one of the world's lesson kinds on top of the run-down crew (W1-65,
#   gameplay critique finding 4): a jolt layer's mat, answered by a jump or by speed, then a sluice
#   flap, ridden as a ramp at speed or jumped. Neither traps the ball (the flap flings it), so the rule stands,
#   and the climax before the Warden asks two questions that are not "go faster" alone.
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
			"waves": [["chaser", "chaser", "lobber"], ["lobber", "lobber", "chaser"], ["chaser", "chaser", "chaser", "lobber"], ["lobber", "chaser", "chaser", "jolt_layer"], ["chaser", "chaser", "lobber", "lobber", "ramp_flipper"]],
			# Reservoir (overtime.gd): the sluice sheet runs down the apron (+z is downhill there).
			"overtime": {"flow": [0.0, 0.0, 1.0]}},
	},
	"park_flume": {
		"gate": {"packs": 1, "also": ["enemy_camp"], "max_s": 75.0},
		"lock": {"id": "forecourt_crew", "within_m": 210.0, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["chaser", "chaser", "lobber"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber", "lobber"], ["lobber", "chaser", "chaser"], ["chaser", "lobber", "lobber"], ["chaser", "chaser", "lobber", "jolt_layer"], ["chaser", "chaser", "chaser", "lobber", "ramp_flipper"]]},
	},
	# Worlds 2 & 3 yard locks (W50): non-holding, unplated waves so an ungrown ball is never trapped inside the ring
	# (no pit_jaw, drill_crew, plated_brute, mag_trapper, anchor_crew, or rim-only ballast_heavy). Warden gates stay
	# omitted on W2/W3 until their maps author command cables (wayfinding_rows_test.gd:590, park_schema.gd:511-515).
	"park_pit": {
		"lock": {"id": "bench_crew", "within_m": 190.0, "sentry": {"kind": "burrower", "within_m": 310.0, "ahead_m": 55.0, "side_m": 18.0}, "radius_m": 26.0, "ahead_m": 10.0, "max_s": 65.0, "wave_gap_s": 3.5,
			"waves": [["burrower", "burrower", "lamp_swarm"], ["chaser", "burrower", "lobber"], ["burrower", "lamp_swarm", "lamp_swarm"], ["burrower", "chaser", "prop_crew"], ["burrower", "burrower", "lamp_swarm", "prop_crew"]]},
	},
	"park_sinkhole": {
		"lock": {"id": "cenote_crew", "within_m": 200.0, "sentry": {"kind": "lobber", "within_m": 320.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["burrower", "burrower", "lamp_swarm"], ["lamp_swarm", "lobber", "burrower"], ["burrower", "prop_crew", "chaser", "lobber"], ["burrower", "lamp_swarm", "splitter"], ["burrower", "burrower", "prop_crew", "lamp_swarm"], ["burrower", "lamp_swarm", "prop_crew", "splitter"]]},
	},
	"park_islands": {
		"lock": {"id": "mooring_crew", "within_m": 200.0, "sentry": {"kind": "line_cutter", "within_m": 320.0, "ahead_m": 60.0, "side_m": 18.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 70.0, "wave_gap_s": 3.5,
			"waves": [["line_cutter", "line_cutter", "kite_drone"], ["kite_drone", "chaser", "lobber"], ["line_cutter", "kite_drone", "gap_net"], ["line_cutter", "line_cutter", "kite_drone", "lobber"], ["kite_drone", "kite_drone", "gap_net", "chaser"], ["line_cutter", "line_cutter", "kite_drone", "gap_net"]]},
	},
	"park_crown": {
		"lock": {"id": "summit_crew", "within_m": 210.0, "sentry": {"kind": "kite_drone", "within_m": 330.0, "ahead_m": 60.0, "side_m": 20.0}, "radius_m": 28.0, "ahead_m": 10.0, "max_s": 75.0, "wave_gap_s": 3.5,
			"waves": [["line_cutter", "kite_drone", "kite_drone"], ["line_cutter", "line_cutter", "gap_net"], ["kite_drone", "lobber", "chaser", "gap_net"], ["line_cutter", "kite_drone", "dispatcher"], ["line_cutter", "line_cutter", "kite_drone", "gap_net"], ["kite_drone", "kite_drone", "gap_net", "dispatcher"], ["line_cutter", "line_cutter", "kite_drone", "kite_drone", "gap_net"]]},
	},
}


static func row(map_id: String) -> Dictionary:
	return ROWS.get(map_id, {})
