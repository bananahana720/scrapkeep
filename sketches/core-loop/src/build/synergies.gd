extends RefCounted

# Named combos (TADR-008 data). A synergy is live while every part it needs is held;
# it is never a part of its own, so a retry that restores the part list restores the
# synergy with it. Each one has a visible effect the player can point at:
#
#   Storm Lattice: Cross Split + Chain Arc. Every split bolt chains (combat reads the
#     storm_lattice transformer), chain gets a level, damage +25%, and the ball grows a
#     spinning lattice halo.
#   Thermal Shock: Frost Vane + Arc Coil. The slam's arc shatters any ice near it into a
#     shard nova at double damage, then the slam refreezes the water around you. The
#     ball grows a frosted coil ring.

const ROWS := {
	"storm_lattice": {
		"name": "Storm Lattice",
		"needs": ["cross_split", "chain_arc"],
		"text": "split bolts chain; chain +1, damage +25%",
		"transformers": ["storm_lattice"],
		"patterns": {"chain_arc": 1},
		"mods": {"weapon_damage": 1.25},
	},
	"thermal_shock": {
		"name": "Thermal Shock",
		"needs": ["frost_vane", "arc_coil"],
		"text": "slam shatters ice into a shard nova, then refreezes",
		"transformers": ["thermal_shock"],
		# Appended after the parts' own slam element, so the arc shatters first and the
		# frost lays fresh ice after it.
		"elements": {"slam": "frost"},
		"dials": {"shatter_damage": 2.0},
	},
}


static func active(held: Array) -> Array:
	var live: Array = []
	for key in ROWS:
		var complete := true
		for need in ROWS[key]["needs"]:
			if not need in held:
				complete = false
				break
		if complete:
			live.append(key)
	return live


# The part in pool that would complete a synergy the run is one part short of.
static func completing_part(held: Array, pool: Array) -> String:
	for key in ROWS:
		var missing: Array = []
		for need in ROWS[key]["needs"]:
			if not need in held:
				missing.append(need)
		if missing.size() == 1 and missing[0] in pool:
			return missing[0]
	return ""


# The synergy this part would complete if taken now, for the gate's hint line.
static func completed_by(part_id: String, held: Array) -> String:
	for key in ROWS:
		var needs: Array = ROWS[key]["needs"]
		if not part_id in needs or key in active(held):
			continue
		var after: Array = held.duplicate()
		after.append(part_id)
		if key in active(after):
			return key
	return ""
