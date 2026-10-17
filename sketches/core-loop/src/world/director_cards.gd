extends RefCounted

# Calibrated against the stage-1 park interval arm over 20 seeds at fixed tiers 0 and 2.
const I0 := 1.20
const K := 0.08
const ELITE_MULTIPLIER := 2.0
# The interval arm and settled rewards share the selected run's row.
const RUN_TIERS := {
	0: {"cap_weight": 1.0, "interval_weight": 1.0, "event_core_multiplier": 1.0, "rare_weight": 1.0},
	1: {"cap_weight": 1.25, "interval_weight": 0.8, "event_core_multiplier": 1.25, "rare_weight": 1.25,
		"elite_stats": {"plating": 30.0}},
}
# stage_cap bounds members of this kind in one purchase, separately from the shared alive cap.
const CARDS := {
	"chaser": {"cost": 1, "weight": 1.0, "stage_cap": 4},
	"lobber": {"cost": 2, "weight": 1.0, "stage_cap": 3},
	"mag_trapper": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"bola_thrower": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"hooker": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"plated_brute": {"cost": 5, "weight": 1.0, "stage_cap": 2},
	"netcaster": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"deflector": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"winch_drone": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"gyro_jammer": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"swatter": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"ramp_flipper": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"catch_trap": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"reactor_relic": {"cost": 8, "weight": 1.0, "stage_cap": 1},
	"swarm_remnant": {"cost": 8, "weight": 1.0, "stage_cap": 1},
	"mind_hand": {"cost": 8, "weight": 1.0, "stage_cap": 1},
	"burrower": {"cost": 3, "weight": 1.0, "stage_cap": 3},
	"drill_crew": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"lamp_swarm": {"cost": 2, "weight": 1.0, "stage_cap": 3},
	"line_cutter": {"cost": 3, "weight": 1.0, "stage_cap": 3},
	"anchor_crew": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"kite_drone": {"cost": 2, "weight": 1.0, "stage_cap": 3},
	"prop_crew": {"cost": 3, "weight": 1.0, "stage_cap": 1},
}


static func cost(kinds: Array, elite := false) -> float:
	var total := 0.0
	var counts := {}
	for kind in kinds:
		if not CARDS.has(kind):
			push_warning("director credit: no card for %s" % kind)
			return INF
		counts[kind] = int(counts.get(kind, 0)) + 1
		if counts[kind] > CARDS[kind].stage_cap:
			return INF
		total += CARDS[kind].cost
	return total * (ELITE_MULTIPLIER if elite else 1.0)


static func weight(kinds: Array) -> float:
	if kinds.is_empty() or not is_finite(cost(kinds)):
		return 0.0
	var total := 0.0
	for kind in kinds:
		total += CARDS[kind].weight
	return total / kinds.size()
