extends RefCounted

# Each pilot's nemesis: the one or two answer axes its kit is weakest on, and which enemy kinds
# press each axis (design-v3/ENEMY-PRIORITY.md section 5, levers 2b and 8). One vocabulary for the
# two sides of "Nudge loot" (Andrew, 2026-10-17 00:01Z):
# - the director weighs an authored pack that holds a nemesis kind by PACK_WEIGHT from world 2
#   (director.gd _draw_authored), so each pilot meets its bad matchups often enough to learn them;
# - reward gates and shops weigh a part or item whose `answers` tag holds the pilot's nemesis axis
#   by OFFER_WEIGHT, so a hard matchup becomes a run where you hunted for the fix. No guarantee.
#
# The axes are the item-side `answers` tags: range, spread, fuse, cc, air, plating.
#   range    the kit's reach is short: perched, hovering or lobbing enemies sit out of it.
#   spread   one target at a time: swarms and streams outnumber it.
#   fuse     the hit lands late: fast movers leave the charge or the lane before it lands.
#   cc       a held ball has an empty gun: grabs and traps shut the kit off.
#   air      airborne enemies the kit cannot reach from the ground.
#   plating  low damage a hit: plating shrugs it off.
# Keyed by ClassDef id (what fleet.gd build_read() sends as "class"). A design call from
# section 5's table, for Andrew's veto; the matchup lab (lever 7) measures it.

const AXES := ["range", "spread", "fuse", "cc", "air", "plating"]

const PILOT := {
	"pylon_engineer": ["plating"],
	"runner_gunner": ["spread"],
	"demolitions_caster": ["fuse"],
	"tarn": ["range"],
	"tally": ["cc", "plating"],
	"remembered_cannon": ["fuse"],
}

# The enemy kinds (director KIND_NAMES) that press each axis, from section 5's "Hard against".
const KIND_AXES := {
	"plated_brute": ["plating"],
	"deflector": ["plating"],
	"swarm_remnant": ["spread", "fuse"],
	"lamp_swarm": ["spread"],
	"dispatcher": ["spread"],
	"chaser": ["fuse"],
	"burrower": ["fuse"],
	"kite_drone": ["fuse", "range", "air"],
	"winch_drone": ["range"],
	"lobber": ["range"],
	"line_cutter": ["range"],
	"catch_trap": ["cc"],
	"mag_trapper": ["cc"],
	"anchor_crew": ["cc"],
	"netcaster": ["air", "cc"],
}

# Start values (section 4, levers 2b and 8).
const PACK_WEIGHT := 1.5
# 2026-10-18 (w17 answers): Andrew's ruling is 1.5. At 1.5 offer_weights_test failed one check on its
# fixed seed, the alpha Tally random bot's weighted share (0.807 against the 0.80 cap; base 0.787).
# The sweep was non-monotonic: 1.45 and 1.4 held, 1.35 and 1.3 failed the same check, 1.25 and
# below held. The largest multiplier that holds in 0.05 steps is 1.45, left here for Andrew to veto.
# Measured over 20 seeds (alpha list, Tally random bot, same quantity): mean 0.790 sd 0.020 at 1.0
# (nudge off; 7 of 20 seeds already over 0.80), 0.783 sd 0.019 at 1.45, 0.788 sd 0.025 at 1.5. The
# means differ by less than the sd, so the 1.5 failure is that seed's draw, not a shifted mean.
const OFFER_WEIGHT := 1.45
# Nemesis packs lean in from this world on; world one teaches the verbs first.
const FROM_WORLD := 2


static func of(class_id: String) -> Array:
	return PILOT.get(class_id, [])


# True when any of `kinds` presses one of the pilot's nemesis axes.
static func pack_presses(class_id: String, kinds: Array) -> bool:
	var axes := of(class_id)
	if axes.is_empty():
		return false
	for kind in kinds:
		for axis in KIND_AXES.get(String(kind), []):
			if axis in axes:
				return true
	return false


# True when an `answers` tag list holds one of the pilot's nemesis axes.
static func answers(class_id: String, tags: Array) -> bool:
	var axes := of(class_id)
	for tag in tags:
		if String(tag) in axes:
			return true
	return false
