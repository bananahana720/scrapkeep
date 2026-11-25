extends RefCounted


const TERRACE_STEP_M := 20.0

const SURFACE_SLOTS := ["sand", "sandstone", "concrete", "tailings", "basalt", "net"]
const SURFACE_DEFAULT := 0
const LANDFORM_SURFACE := {
	"arroyo": 0, "dry_wash": 0, "saguaro_stand": 0,
	"slot_canyon": 1, "slickrock": 1, "mesa_rim": 1, "butte": 1, "spire": 1, "hoodoo_field": 1,
	"cliff_dwelling": 1, "horseshoe_bend": 1, "river_canyon": 1, "gooseneck": 1, "sky_island": 1,
	"sinkhole": 1, "cenote_pool": 1, "travertine_terrace": 1,
	"canal": 2, "flume": 2, "penstock": 2, "pipeline": 2, "dam_face": 2, "spillway_tunnel": 2,
	"headframe": 2,
	"open_pit": 3, "tailings_bench": 3, "adit": 3, "shaft": 3, "flooded_shaft": 3,
	"lava_tube": 4, "meteor_crater": 4,
}

const ELLIPSES := ["butte", "spire", "bowl", "crater", "sinkhole"]


static func surface_slot(landform: String) -> int:
	return int(LANDFORM_SURFACE.get(landform, -1))


static func frame(row: Dictionary) -> Dictionary:
	var a := deg_to_rad(float(row["yaw_deg"]))
	var size: Array = row["size"]
	return {
		"stamp": String(row["stamp"]),
		"at": Vector2(float(row["at"][0]), float(row["at"][1])),
		"along": Vector2(sin(a), cos(a)),
		"across": Vector2(cos(a), -sin(a)),
		"length": maxf(float(size[0]), 0.001),
		"height": float(size[1]),
		"width": maxf(float(size[2]), 0.001),
		"ellipse": ELLIPSES.has(String(row["stamp"])),
	}


static func bounds(f: Dictionary) -> Array:
	var hl: Vector2 = f["along"] * f["length"] * 0.5
	var hw: Vector2 = f["across"] * f["width"] * 0.5
	var ex := absf(hl.x) + absf(hw.x)
	var ez := absf(hl.y) + absf(hw.y)
	var c: Vector2 = f["at"]
	return [c.x - ex, c.y - ez, c.x + ex, c.y + ez]


static func local(f: Dictionary, x: float, z: float) -> Vector2:
	var rel: Vector2 = Vector2(x, z) - (f["at"] as Vector2)
	return Vector2(rel.dot(f["along"]) / f["length"], rel.dot(f["across"]) / f["width"])


static func inside(f: Dictionary, x: float, z: float) -> bool:
	var p := local(f, x, z)
	if f["ellipse"]:
		return 4.0 * (p.x * p.x + p.y * p.y) <= 1.0
	return absf(p.x) <= 0.5 and absf(p.y) <= 0.5


static func offset(f: Dictionary, x: float, z: float) -> float:
	var p := local(f, x, z)
	var u := p.x
	var v := p.y
	var h: float = f["height"]
	var length: float = f["length"]
	var width: float = f["width"]
	if f["ellipse"]:
		var r := 2.0 * sqrt(u * u + v * v)
		if r > 1.0:
			return 0.0
		match f["stamp"]:
			"butte":
				return h * clampf((1.0 - r) / 0.15, 0.0, 1.0)
			"spire":
				return h * smoothstep(1.0, 0.4, r)
			"bowl":
				return -h * (1.0 - r * r)
			"crater":
				var cut := 0.0
				if r < 0.8:
					cut = -h * (1.0 - (r / 0.8) * (r / 0.8))
				return cut + 0.2 * h * maxf(0.0, 1.0 - absf(r - 0.85) / 0.15)
			"sinkhole":
				return -h * clampf((1.0 - r) / 0.1, 0.0, 1.0)
		return 0.0
	if absf(u) > 0.5 or absf(v) > 0.5:
		return 0.0
	var side_m := (0.5 - absf(v)) * width
	var end_m := (0.5 - absf(u)) * length
	match f["stamp"]:
		"plateau":
			return h
		"mesa":
			return h * clampf(minf(side_m, end_m) / maxf(0.3 * h, 0.001), 0.0, 1.0)
		"ramp":
			return h * (0.5 - u)
		"ridge":
			var t := 2.0 * v
			return h * (1.0 - t * t) * clampf(end_m / (0.5 * width), 0.0, 1.0)
		"wash":
			var t := absf(2.0 * v)
			var depth := 1.0
			if t > 0.4:
				var w := (t - 0.4) / 0.6
				depth = 1.0 - w * w
			return -h * depth * _open_end(end_m, length, width)
		"channel":
			var wall := maxf(minf(0.2 * h, 0.25 * width), 0.001)
			return -h * clampf(side_m / wall, 0.0, 1.0) * _open_end(end_m, length, width)
		"terrace":
			var n := maxi(1, roundi(h / TERRACE_STEP_M))
			var s := minf(1.0 - absf(2.0 * u), 1.0 - absf(2.0 * v))
			var k := mini(n, int(floor(s * 2.0 * n)) + 1)
			return -h * float(k) / float(n)
	return 0.0


static func _open_end(end_m: float, length: float, width: float) -> float:
	var run := maxf(minf(width, 0.25 * length), 0.001)
	return clampf(end_m / run, 0.0, 1.0)
