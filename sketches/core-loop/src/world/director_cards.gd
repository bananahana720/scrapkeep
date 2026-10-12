extends RefCounted

# KE9 credit cards: what one authored pack costs the credit director (director.gd, mode "credit").
# A card is a pack: its price is the sum of its members' KIND_COST, and the elite pack pays
# ELITE_MULT on top. The prices are a first proposal for the coordinator to tune in play; a kind
# with no row costs DEFAULT_KIND_COST. `weight` and `stage_cap` are carried on every card for the
# coordinator's review; this pass reads neither (see the KE9 report).

const KIND_COST := {
	"chaser": 1.0, "lobber": 1.0,
	"mag_trapper": 1.5, "bola_thrower": 1.5, "hooker": 1.5, "netcaster": 1.5, "gyro_jammer": 1.5,
	"swatter": 1.5, "ramp_flipper": 1.5, "catch_trap": 1.5, "winch_drone": 1.5,
	"plated_brute": 2.0, "deflector": 2.0,
	"reactor_relic": 3.0, "swarm_remnant": 3.0, "mind_hand": 3.0,
}
const DEFAULT_KIND_COST := 1.5
const ELITE_MULT := 2.0
const DEFAULT_WEIGHT := 1.0
const DEFAULT_STAGE_CAP := 3


# The sum of the members' kind prices.
static func base_cost(kinds: Array) -> float:
	var total := 0.0
	for kind in kinds:
		total += float(KIND_COST.get(String(kind), DEFAULT_KIND_COST))
	return total


# A pack's price in credits; the elite pack pays ELITE_MULT times its members.
static func cost_of(pack: Dictionary, elite := false) -> float:
	var base := base_cost(pack.get("kinds", []))
	return base * ELITE_MULT if elite else base


# The whole card for one pack: price, draw weight and the last stage it may appear on.
static func card(pack: Dictionary, elite := false) -> Dictionary:
	return {"cost": cost_of(pack, elite), "weight": DEFAULT_WEIGHT, "stage_cap": DEFAULT_STAGE_CAP}
