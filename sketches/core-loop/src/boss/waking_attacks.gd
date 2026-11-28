extends RefCounted

const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const FAMILIES := ["burrow", "cave_in", "bore"]
const PIT_PHASE := 4
const GAP := 0.2
const CLEAR := BossAttacks.CLEAR
const HEIGHT := 3.0
const PHASE_TIGHTEN := 0.1
const TIGHTEN_PHASES := 3

const LANE_HALF := 1.6
const BURROW_WARN := 1.4
const BURROW_LIVE := 0.7
const BURROW_OFF := Vector2(0.4, 0.8)
const CAVE_COUNT := 3
const CAVE_R := 4.0
const CAVE_WARN := 1.5
const CAVE_LIVE := 0.6
const CAVE_LEAD := 3.0
const CAVE_STEP := 8.0
const BORE_R := 6.0
const BORE_WARN := 1.6
const BORE_LIVE := 0.8
const PIT_SPRAY := 3

const DAMAGE := {"burrow": 8.0, "cave_in": 8.0, "bore": 12.0}

const FALLBACK_PATHS := ["drop", "none"]


static func exposed(phase: int, removed := []) -> Array:
	return BossAttacks.exposed(FAMILIES, phase, removed)


static func newest(phase: int, removed := []) -> String:
	return exposed(phase, removed)[-1]


static func choose(seed: int, phase: int, removed := []) -> String:
	return BossAttacks.choose(FAMILIES, seed, phase, removed)


static func anthem_phase(phase: int) -> int:
	return clampi(phase, 1, FAMILIES.size())


static func commit(family: String, seed: int, ball: Vector3, velocity: Vector3, center: Vector3, phase: int, radius: float, removed := []) -> Array:
	match family:
		"burrow":
			return burrow(seed, ball, center, phase, radius)
		"cave_in":
			return cave_in(seed, ball, velocity, center, phase, radius)
		"bore":
			return bore(seed, ball, center, phase, radius, removed)
	push_error("waking_attacks: unknown family %s" % family)
	return []


static func commit_safe(family: String, seed: int, ball: Vector3, velocity: Vector3, center: Vector3, phase: int, cruise_speed: float,
		radius: float, removed := []) -> Dictionary:
	var make := func(s: int) -> Array:
		return commit(family, s, ball, velocity, center, phase, radius, removed)
	var check := func(descs: Array) -> bool:
		return BossAttacks.escape_point(descs, ball, cruise_speed, center, radius) != null
	return BossAttacks.commit_safe(seed, make, check)


static func burrow(seed: int, ball: Vector3, center: Vector3, phase: int, radius: float) -> Array:
	var rng := BossAttacks.rng(seed)
	var bearing := BossAttacks.bearing(rng, ball, center)
	var warn := _warn(BURROW_WARN, phase)
	var out := [_lane("burrow", 0, center, bearing, warn, radius)]
	if phase >= 2:
		var off := rng.randf_range(BURROW_OFF.x, BURROW_OFF.y) * (1.0 if rng.randf() < 0.5 else -1.0)
		var second := _lane("burrow", 1, center, bearing + off, warn, radius)
		second["delay"] = GAP
		out.append(second)
	return out


static func cave_in(seed: int, ball: Vector3, velocity: Vector3, center: Vector3, phase: int, radius: float) -> Array:
	var rng := BossAttacks.rng(seed)
	var heading := BossAttacks.flat(velocity)
	if heading.length() < 1.0:
		var b := BossAttacks.bearing(rng, ball, center) + PI
		heading = Vector3(cos(b), 0.0, sin(b))
	heading = heading.normalized()
	var out := []
	for i in CAVE_COUNT:
		var at := _inside(BossAttacks.flat(ball) + heading * (CAVE_LEAD + CAVE_STEP * i), center, radius - CAVE_R)
		var d := _disc("cave_in", i, at, CAVE_R, _warn(CAVE_WARN, phase), CAVE_LIVE)
		d["delay"] = GAP * i
		out.append(d)
	return out


static func bore(seed: int, ball: Vector3, center: Vector3, phase: int, radius: float, removed := []) -> Array:
	var rng := BossAttacks.rng(seed)
	var at := _inside(BossAttacks.flat(ball), center, radius - BORE_R)
	var out := [_disc("bore", 0, at, BORE_R, _warn(BORE_WARN, phase), BORE_LIVE)]
	if phase >= PIT_PHASE and not removed.has("pit_spray"):
		var start := rng.randf() * TAU
		for i in PIT_SPRAY:
			var lane := _lane("burrow", i, at, start + TAU * i / PIT_SPRAY, _warn(BURROW_WARN, phase), radius)
			lane["ahead"] = maxf(0.0, _chord(at, lane["dir"], center, radius) - LANE_HALF)
			lane["delay"] = GAP * (i + 1)
			lane["id"] = "waking_bore_spray_%d" % i
			out.append(lane)
	return out


static func _lane(family: String, n: int, from: Vector3, bearing: float, warn: float, radius: float) -> Dictionary:
	var d := _base(family, n, "lane", Threat.Type.LANE, warn, BURROW_LIVE)
	d["from"] = from
	d["dir"] = Vector3(cos(bearing), 0.0, sin(bearing))
	d["behind"] = 0.0
	d["ahead"] = radius - LANE_HALF
	d["half"] = LANE_HALF
	return d


static func _disc(family: String, n: int, at: Vector3, r: float, warn: float, live: float) -> Dictionary:
	var d := _base(family, n, "annulus", Threat.Type.INSTANT, warn, live)
	d["at"] = at
	d["band"] = Vector2(0.0, r)
	return d


static func _base(family: String, n: int, shape: String, type: int, warn: float, live: float) -> Dictionary:
	return {"family": family, "family_index": FAMILIES.find(family) + 1, "id": "waking_%s_%d" % [family, n], "shape": shape,
		"type": type, "warn": warn, "live": live, "height": HEIGHT, "delay": 0.0}


static func _chord(from: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var p := BossAttacks.flat(from - center)
	var u := BossAttacks.flat(dir).normalized()
	var b := p.dot(u)
	var c := p.length_squared() - radius * radius
	return maxf(0.0, -b + sqrt(maxf(0.0, b * b - c)))


static func _inside(p: Vector3, center: Vector3, limit: float) -> Vector3:
	var v := BossAttacks.flat(p - center).limit_length(maxf(0.0, limit))
	return Vector3(center.x + v.x, center.y, center.z + v.z)


static func _warn(base: float, phase: int) -> float:
	return ChallengeDials.tell("waking", base - PHASE_TIGHTEN * (clampi(phase, 1, TIGHTEN_PHASES) - 1), Hazard.MIN_WARN)
