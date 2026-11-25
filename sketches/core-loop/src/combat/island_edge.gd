extends RefCounted

const STEP := 1.5
const DIRECTIONS := 16


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


static func nearest_rim(terrain, at: Vector3, reach: float, drop: float) -> Dictionary:
	var found := rims(terrain, at, reach, drop)
	return found[0] if not found.is_empty() else {}


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


static func falls_ahead(terrain, at: Vector3, dir: Vector3, ahead: float, drop: float) -> bool:
	if terrain == null or dir.length_squared() < 0.0001:
		return false
	var p := at + Vector3(dir.x, 0.0, dir.z).normalized() * ahead
	return terrain.height(p.x, p.z) < terrain.height(at.x, at.z) - drop
