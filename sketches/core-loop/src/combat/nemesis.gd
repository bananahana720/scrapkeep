extends RefCounted

const AXES := ["range", "spread", "fuse", "cc", "air", "plating"]

const PILOT := {
	"pylon_engineer": ["plating"],
	"runner_gunner": ["spread"],
	"demolitions_caster": ["fuse"],
	"tarn": ["range"],
	"tally": ["cc", "plating"],
	"remembered_cannon": ["fuse"],
}

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

const PACK_WEIGHT := 1.5
const OFFER_WEIGHT := 1.5
const FROM_WORLD := 2


static func of(class_id: String) -> Array:
	return PILOT.get(class_id, [])


static func pack_presses(class_id: String, kinds: Array) -> bool:
	var axes := of(class_id)
	if axes.is_empty():
		return false
	for kind in kinds:
		for axis in KIND_AXES.get(String(kind), []):
			if axis in axes:
				return true
	return false


static func answers(class_id: String, tags: Array) -> bool:
	var axes := of(class_id)
	for tag in tags:
		if String(tag) in axes:
			return true
	return false
