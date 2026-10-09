extends RefCounted

# The vocabulary of a map's ground scatter (stage_map.gd `scatter`). Rows live in the map files;
# this file holds what every row shares: the kinds, the kit meshes and the check a row must pass.
#   kind     what the piece is; "rock", "pebble", "scrap" or "cable"
#   density  instances per 100 m2 of the map's play rect, before the slope test drops some
#   scale    uniform scale range applied to the mesh source, metres across for a kit mesh
#   slope    the steepest ground (normal.y floor) an instance may stand on
#   bury     fraction of the instance's height pushed below the ground, so it reads embedded
#   seed     the name hashed into the row's private RandomNumberGenerator
#   mesh     "kit:<name>" (KIT below), "glb:<path>" (first mesh of a kit GLB) or "prim:coil"
#   slot     the material slot (material_slots.gd) every instance of the row shares
const KINDS := ["rock", "pebble", "scrap", "cable"]
const KEYS := ["kind", "density", "scale", "slope", "bury", "seed", "mesh", "slot"]
# Closed, faceted, under 60 triangles: a lat-long solid of `segments` x `rings`, each vertex pushed
# in or out by up to `jitter`, one unit across before the row's scale, `squash` high.
const KIT := {
	"rubble": {"segments": 7, "rings": 4, "squash": 0.7, "jitter": 0.24, "seed": 3.0},
	"pebble": {"segments": 6, "rings": 3, "squash": 0.6, "jitter": 0.2, "seed": 5.0},
}
const KIT_TRIANGLE_CAP := 60
# Visual vertices one map's scatter may add on top of the relief view (acceptance G4).
const VERTEX_BUDGET := 400000


static func problems(row: Dictionary) -> Array[String]:
	var found: Array[String] = []
	for key in KEYS:
		if not row.has(key):
			found.append("missing " + key)
	if not found.is_empty():
		return found
	if not String(row["kind"]) in KINDS:
		found.append("unknown kind " + String(row["kind"]))
	if String(row["mesh"]).begins_with("kit:") and not KIT.has(String(row["mesh"]).trim_prefix("kit:")):
		found.append("unknown kit mesh " + String(row["mesh"]))
	return found
