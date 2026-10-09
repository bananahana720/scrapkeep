extends RefCounted

# Ground scatter and relief (wave 12 probe P-GROUND). One row per map and kind: scatter.gd
# reads ROWS and builds one MultiMeshInstance3D per row, presentation only, never a collider.
#   density  instances per 100 m2 of the map's play rect, before the slope test drops some
#   scale    uniform scale range applied to the mesh source
#   slope    the steepest ground (normal.y floor) an instance may stand on
#   bury     fraction of the instance's height pushed below the ground, so it reads embedded
#   seed     the name hashed into the row's private RandomNumberGenerator
#   mesh     "glb:<path>" (first mesh of a kit GLB) or "prim:coil" (a flat cable coil)
#   slot     the kit material slot (dig_scenery.gd SLOTS) every instance of the row shares
const ROWS := [
	{"map": "spillway", "kind": "rock", "density": 1.4, "scale": Vector2(0.12, 0.3), "slope": 0.8, "bury": 0.35, "seed": "scatter_spillway_rock", "mesh": "glb:res://assets/models/dig_stone/rubble_cluster.glb", "slot": "stone"},
	{"map": "spillway", "kind": "scrap", "density": 0.3, "scale": Vector2(0.2, 0.38), "slope": 0.85, "bury": 0.3, "seed": "scatter_spillway_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
	{"map": "spillway", "kind": "cable", "density": 0.2, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_spillway_cable", "mesh": "prim:coil", "slot": "elastomer"},
	{"map": "dig", "kind": "rock", "density": 1.8, "scale": Vector2(0.12, 0.32), "slope": 0.8, "bury": 0.35, "seed": "scatter_dig_rock", "mesh": "glb:res://assets/models/dig_stone/rubble_cluster.glb", "slot": "stone"},
	{"map": "dig", "kind": "scrap", "density": 0.35, "scale": Vector2(0.2, 0.38), "slope": 0.85, "bury": 0.3, "seed": "scatter_dig_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
	{"map": "dig", "kind": "cable", "density": 0.2, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_dig_cable", "mesh": "prim:coil", "slot": "elastomer"},
	{"map": "dig_deep", "kind": "rock", "density": 2.2, "scale": Vector2(0.12, 0.34), "slope": 0.8, "bury": 0.35, "seed": "scatter_dig_deep_rock", "mesh": "glb:res://assets/models/dig_stone/rubble_cluster.glb", "slot": "stone"},
	{"map": "dig_deep", "kind": "scrap", "density": 0.4, "scale": Vector2(0.2, 0.38), "slope": 0.85, "bury": 0.3, "seed": "scatter_dig_deep_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
	{"map": "dig_deep", "kind": "cable", "density": 0.25, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_dig_deep_cable", "mesh": "prim:coil", "slot": "elastomer"},
]

# Visual relief per map: terrain.gd draws the ground at STEP / sub with a seeded noise offset of
# at most amp metres (period in metres), shading the dips by shade. The collider keeps the 2 m
# grid, so the ball rolls on exactly the ground it rolled on before.
const RELIEF := {
	"spillway": {"sub": 2, "amp": 0.12, "period": 3.0, "shade": 0.35, "seed": "relief_spillway"},
	"dig": {"sub": 2, "amp": 0.12, "period": 2.6, "shade": 0.35, "seed": "relief_dig"},
	"dig_deep": {"sub": 2, "amp": 0.14, "period": 2.6, "shade": 0.4, "seed": "relief_dig_deep"},
}
const KINDS := ["rock", "scrap", "cable"]


static func for_map(map_id: String) -> Array:
	return ROWS.filter(func(r: Dictionary) -> bool: return r["map"] == map_id)
