extends RefCounted

const I0 := 1.20
const K := 0.08
const ELITE_MULTIPLIER := 2.0
const RELAY_STAKE_MAX := 4
const RUN_TIERS := {
	0: {"cap_weight": 1.0, "interval_weight": 1.0, "event_core_multiplier": 1.0, "rare_weight": 1.0},
	1: {"cap_weight": 1.25, "interval_weight": 0.8, "event_core_multiplier": 1.25, "rare_weight": 1.25,
		"elite_stats": {"plating": 30.0}},
	2: {"cap_weight": 1.3, "interval_weight": 0.77, "event_core_multiplier": 1.3, "rare_weight": 1.3,
		"elite_stats": {"plating": 30.0}},
	3: {"cap_weight": 1.35, "interval_weight": 0.74, "event_core_multiplier": 1.35, "rare_weight": 1.35,
		"elite_stats": {"plating": 30.0}},
	4: {"cap_weight": 1.4, "interval_weight": 0.71, "event_core_multiplier": 1.4, "rare_weight": 1.4,
		"elite_stats": {"plating": 30.0}},
	5: {"cap_weight": 1.45, "interval_weight": 0.68, "event_core_multiplier": 1.5, "rare_weight": 1.5,
		"elite_stats": {"plating": 30.0}},
}
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
	"linker": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"foreman": {"cost": 3, "weight": 1.0, "stage_cap": 1},
	"prop_crew": {"cost": 3, "weight": 1.0, "stage_cap": 1},
	"pit_jaw": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"splitter": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"ballast_heavy": {"cost": 5, "weight": 1.0, "stage_cap": 2},
	"gap_net": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"jolt_layer": {"cost": 3, "weight": 1.0, "stage_cap": 2},
	"boom_tender": {"cost": 4, "weight": 1.0, "stage_cap": 2},
	"dispatcher": {"cost": 4, "weight": 1.0, "stage_cap": 1},
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


static func staked(base: float, stakes: int) -> float:
	return base * (1 + clampi(stakes, 0, RELAY_STAKE_MAX))
