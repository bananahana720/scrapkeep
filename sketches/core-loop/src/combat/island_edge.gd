extends RefCounted

# Island rims and gaps, read from the terrain's height alone (any map: the greybox Highdraft's
# islands over the net deck, a park's mesas, or a flat stage with no rim at all). The Highdraft
# kinds stand on rims and string across gaps (design-v3/WORLD-ROSTERS.md), so they find them
# here instead of each map naming them.
#
# A rim is where the ground falls at least `drop` below the standing height within one STEP; a
# gap is the stretch past a rim before the ground climbs back within `rise` of that height.

const STEP := 1.5
const DIRECTIONS := 16


# Every rim within `reach` of `at`, one per direction that has one, nearest first: the
# same {at, dir, dist} rows as nearest_rim.
static func rims(terrain, at: Vector3, reach: float, drop: float) -> Array:
	var out: Array = []
	if terrain == null:
		return out
	var base: float = terrain.height(at.x, at.z)
	for i in DIRECTIONS:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * i / DIRECTIONS)
		var d := STEP
		while d <= reach:
			var p := at + dir * d
			if terrain.height(p.x, p.z) < base - drop:
				var rim := at + dir * (d - STEP)
				out.append({"at": Vector3(rim.x, base, rim.z), "dir": dir, "dist": d - STEP})
				break
			d += STEP
	out.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	return out


# The nearest rim within `reach` of `at`: {"at": the last ground point before the fall,
# "dir": the outward flat direction, "dist": flat metres to it}, or {} when none is in reach.
static func nearest_rim(terrain, at: Vector3, reach: float, drop: float) -> Dictionary:
	var found := rims(terrain, at, reach, drop)
	return found[0] if not found.is_empty() else {}


# The far rim across the gap that opens at `rim` along `dir`: the first point within `span`
# whose ground is back within `rise` of `level`, or Vector3.INF when the gap never closes.
static func far_rim(terrain, rim: Vector3, dir: Vector3, span: float, level: float, rise: float) -> Vector3:
	if terrain == null:
		return Vector3.INF
	var d := STEP
	while d <= span:
		var p := rim + dir * d
		var h: float = terrain.height(p.x, p.z)
		if h >= level - rise:
			return Vector3(p.x, h, p.z)
		d += STEP
	return Vector3.INF


# Whether a step of `ahead` metres along `dir` from `at` would fall more than `drop`.
static func falls_ahead(terrain, at: Vector3, dir: Vector3, ahead: float, drop: float) -> bool:
	if terrain == null or dir.length_squared() < 0.0001:
		return false
	var p := at + Vector3(dir.x, 0.0, dir.z).normalized() * ahead
	return terrain.height(p.x, p.z) < terrain.height(at.x, at.z) - drop
