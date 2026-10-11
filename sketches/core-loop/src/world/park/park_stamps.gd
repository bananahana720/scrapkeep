extends RefCounted

# The height stamps the park bake applies (design-v3/PARK.md 2.2 `stamp`, section 3). Pure
# functions: tools/park_bake.gd calls them on its grids; the runtime never evaluates a stamp.
#
# Frame. A row's piece axes come from its `at`, `yaw_deg` and `size` [length, height, width]:
# u runs along the yaw (0 faces +z, turning toward +x) and v across it, both scaled so the
# footprint is -0.5..0.5 on each. Elliptic stamps use r = length of (2u, 2v), 1 on the rim.
#
# Composition. The base plain is y 0 and rows apply in file order, each adding its offset to
# what is there (PARK.md 2.1: stamps raise or cut it). A raise is positive, a cut negative,
# zero outside the footprint, so a mesa stamped on a ramp rides the slope. A row's `y` places
# its recipe, never its stamp.
#
# Ramp. A `ramp` falls by its height from its start (u -0.5) to its end (u +0.5) along its yaw:
# offset h at the start, 0 at the end (the convention park/stages/1-park_dam.md section 2
# proposes, adopted here).
#
# Shapes, each a starting value to tune in play:
#   plateau  rectangle, +h, sheer edge (one grid step of slope).
#   mesa     rectangle, +h, sides slope over 30 percent of h inward from the edge.
#   ridge    rectangle, +h along the centre line, falling as 1 - (2v)^2 across; the ends slope
#            over half the width.
#   butte    ellipse, +h, sides over the outer 15 percent of the radius.
#   spire    ellipse, +h, a smoothstep cone over the outer 60 percent of the radius.
#   wash     rectangle, -h, a half-pipe: flat floor over the middle 40 percent of the width,
#            curved walls; the ends open over min(width, length / 4) so a ball rolls in and out.
#   channel  rectangle, -h, steep walls over min(20 percent of h, a quarter of the width); ends
#            open like a wash.
#   bowl     ellipse, -h * (1 - r^2).
#   crater   ellipse, a bowl -h inside r 0.8 and a rim raised 0.2 h peaking at r 0.85.
#   sinkhole ellipse, -h inside r 0.9, a near-vertical wall to 0 at the rim.
#   terrace  rectangle, a stepped cut -h in n = max(1, round(h / 20)) benches of equal depth,
#            each bench a ring of equal width over the outer half (a 4 m bench is one flat cut).

const TERRACE_STEP_M := 20.0

# The material slots surface.bin stores, one byte per 2 m cell (PARK.md section 3, Materials).
const SURFACE_SLOTS := ["sand", "sandstone", "concrete", "tailings", "basalt", "net"]
const SURFACE_DEFAULT := 0
# Each landform's slot; the net slot is reserved for the net deck recipe (never the colour map).
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


# A row's frame, computed once per row: centre, axes, size and stamp kind.
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


# The axis-aligned box [min_x, min_z, max_x, max_z] that holds the footprint.
static func bounds(f: Dictionary) -> Array:
	var hl: Vector2 = f["along"] * f["length"] * 0.5
	var hw: Vector2 = f["across"] * f["width"] * 0.5
	var ex := absf(hl.x) + absf(hw.x)
	var ez := absf(hl.y) + absf(hw.y)
	var c: Vector2 = f["at"]
	return [c.x - ex, c.y - ez, c.x + ex, c.y + ez]


# The point's (u, v) in the row's frame; inside the rectangle when both are within 0.5.
static func local(f: Dictionary, x: float, z: float) -> Vector2:
	var rel: Vector2 = Vector2(x, z) - (f["at"] as Vector2)
	return Vector2(rel.dot(f["along"]) / f["length"], rel.dot(f["across"]) / f["width"])


# Whether (x, z) lies in the footprint: the rectangle, or the inscribed ellipse for elliptic stamps.
static func inside(f: Dictionary, x: float, z: float) -> bool:
	var p := local(f, x, z)
	if f["ellipse"]:
		return 4.0 * (p.x * p.x + p.y * p.y) <= 1.0
	return absf(p.x) <= 0.5 and absf(p.y) <= 0.5


# The stamp's height offset at (x, z), zero outside its footprint.
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
	# Distances in metres from the point to the footprint's side edges and end edges.
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
