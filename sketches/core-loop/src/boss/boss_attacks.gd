extends RefCounted

const Tuning := preload("res://src/movement/tuning.gd")

const CLEAR := Tuning.RADIUS
const RECOMMITS := 4
const RECOMMIT_STRIDE := 104729
const SEARCH_STEP := 0.5
const SEARCH_BEARINGS := 72


static func exposed(families: Array, phase: int, removed := []) -> Array:
	var open := families.slice(0, clampi(phase, 1, families.size()))
	var kept := open.filter(func(f): return not removed.has(f))
	return kept if not kept.is_empty() else open


static func choose(families: Array, seed: int, phase: int, removed := []) -> String:
	var open := exposed(families, phase, removed)
	return open[rng(seed).randi() % open.size()]


static func commit_safe(seed: int, make: Callable, check: Callable, single := Callable()) -> Dictionary:
	var first: Array = []
	for k in RECOMMITS + 1:
		var descs: Array = make.call(seed + k * RECOMMIT_STRIDE)
		if k == 0:
			first = descs
		if check.call(descs):
			return {"descriptors": descs, "path": "first" if k == 0 else "recommit"}
	for n in range(first.size() - 1, 0, -1):
		var kept := first.slice(0, n)
		if check.call(kept):
			return {"descriptors": kept, "path": "drop"}
	if single.is_valid():
		var away: Array = single.call()
		if check.call(away):
			return {"descriptors": away, "path": "single"}
	return {"descriptors": [], "path": "none"}


static func escape_point(descriptors: Array, ball: Vector3, cruise_speed: float, center: Vector3, radius: float):
	if descriptors.is_empty():
		return Vector3(ball.x, center.y, ball.z)
	var warn := INF
	for d in descriptors:
		warn = minf(warn, float(d["warn"]))
	var reach := cruise_speed * warn
	var start := Vector3(ball.x, center.y, ball.z)
	if _clear(descriptors, start, center, radius):
		return start
	var r := SEARCH_STEP
	while r <= reach:
		for i in SEARCH_BEARINGS:
			var a := TAU * i / SEARCH_BEARINGS
			var p := start + Vector3(cos(a), 0.0, sin(a)) * r
			if _clear(descriptors, p, center, radius):
				return p
		r += SEARCH_STEP
	return null


static func _clear(descriptors: Array, p: Vector3, center: Vector3, radius: float) -> bool:
	if flat(p - center).length() > radius - CLEAR:
		return false
	for d in descriptors:
		if covers(d, p, CLEAR):
			return false
	return true


static func covers(d: Dictionary, p: Vector3, pad := 0.0) -> bool:
	match d["shape"]:
		"lane":
			var dir: Vector3 = flat(d["dir"]).normalized()
			var local := flat(p - d["from"])
			var along := local.dot(dir)
			var lateral := local.dot(Vector3.UP.cross(dir).normalized())
			return along >= -float(d["behind"]) - pad and along <= float(d["ahead"]) + pad and absf(lateral) <= float(d["half"]) + pad
		"annulus":
			var r := flat(p - d["at"]).length()
			return r >= d["band"].x - pad and r <= d["band"].y + pad
		"sector":
			var v := flat(p - d["at"])
			var r := v.length()
			if r < d["band"].x - pad or r > d["band"].y + pad:
				return false
			if r <= pad and d["band"].x <= pad:
				return true
			var a0: float = d["from_angle"]
			var a1: float = d["to_angle"]
			var sgn := signf(a1 - a0) if a1 != a0 else 1.0
			var u := wrapf((atan2(v.z, v.x) - a0) * sgn, -PI, PI)
			var margin := (1.0 + pad) / maxf(r, 1.0)
			return u >= -margin and u <= absf(a1 - a0) + margin
	return false


static func bearing(gen: RandomNumberGenerator, ball: Vector3, center: Vector3) -> float:
	var v := flat(ball - center)
	if v.length() < CLEAR:
		return gen.randf() * TAU
	return atan2(v.z, v.x)


static func rng(seed: int) -> RandomNumberGenerator:
	var gen := RandomNumberGenerator.new()
	gen.seed = seed
	return gen


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
