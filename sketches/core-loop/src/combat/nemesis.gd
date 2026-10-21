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
# 2026-10-18 (w17 answers): Andrew's 1.5. On offer_weights_test's one fixed seed, alpha Tally's
# random bot read 0.807 against the 0.80 cap (base 0.787). Over 20 seeds (alpha list, Tally random
# bot) the mean share is 0.790 sd 0.020 at 1.0, 0.783 at 1.45 and 0.788 sd 0.025 at 1.5, and the
# base crosses 0.80 on 7 of 20 seeds, so that was seed noise. Coordinator ruling on #149: keep 1.5
# and judge the alpha share check on the mean over 20 seeds against the unchanged 60 to 80% band.
const OFFER_WEIGHT := 1.5
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
