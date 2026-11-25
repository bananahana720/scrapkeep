extends RefCounted

const KINDS := ["rock", "pebble", "scrap", "cable"]
const KEYS := ["kind", "density", "scale", "slope", "bury", "seed", "mesh", "slot"]
const KIT := {
	"rubble": {"segments": 7, "rings": 4, "squash": 0.7, "jitter": 0.24, "seed": 3.0},
	"pebble": {"segments": 6, "rings": 3, "squash": 0.6, "jitter": 0.2, "seed": 5.0},
}
const KIT_TRIANGLE_CAP := 60
const VERTEX_BUDGET := 400000
const RANGE := {"rock": 220.0, "pebble": 120.0, "scrap": 160.0, "cable": 160.0}
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
