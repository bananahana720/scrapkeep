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
# Visual vertices one map's scatter may add on top of the relief view (acceptance G4); on a park,
# the visual vertices drawn from any one camera (PARK.md section 9).
const VERTEX_BUDGET := 400000
# A park chunk batch's visibility range per kind: metres from the camera to the batch's bounds
# centre (PARK.md section 3 starts rocks at 220 and pebbles at 90). A range must reach past a 160 m
# chunk's half-diagonal (113 m) or a camera standing in a chunk's corner would not draw it, so
# pebbles start at 120.
const RANGE := {"rock": 220.0, "pebble": 120.0, "scrap": 160.0, "cable": 160.0}
# A park's kit rows when its file brings none (park_map.gd leaves `kit` empty until the park
# files carry rows). One row per kind, so each kind merges to one MultiMesh per chunk; the
# densities keep the worst camera under VERTEX_BUDGET.
const PARK_KIT := [
	{"kind": "rock", "density": 0.6, "scale": Vector2(0.3, 0.8), "slope": 0.8, "bury": 0.35, "seed": "scatter_park_rock", "mesh": "kit:rubble", "slot": "stone"},
	{"kind": "pebble", "density": 1.5, "scale": Vector2(0.1, 0.25), "slope": 0.8, "bury": 0.3, "seed": "scatter_park_pebble", "mesh": "kit:pebble", "slot": "stone"},
	{"kind": "scrap", "density": 0.1, "scale": Vector2(0.25, 0.45), "slope": 0.85, "bury": 0.3, "seed": "scatter_park_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
	{"kind": "cable", "density": 0.12, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_park_cable", "mesh": "prim:coil", "slot": "cable"},
]


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


# A chunked table merges every row of a kind into one MultiMesh, which carries one mesh and one
# material: the rows of a kind must share both.
static func kind_problems(rows: Array) -> Array[String]:
	var found: Array[String] = []
	var first := {}
	for row: Dictionary in rows:
		var kind := String(row.get("kind", ""))
		var look := "%s|%s" % [row.get("mesh", ""), row.get("slot", "")]
		if not first.has(kind):
			first[kind] = look
		elif first[kind] != look:
			found.append("%s rows differ in mesh or slot (%s, %s)" % [kind, first[kind], look])
	return found
