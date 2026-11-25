extends RefCounted

const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The Waking's three Dig attack families as pure rules (design page "The Waking's Attacks",
# Andrew's "Give it attacks" tap, 2026-10-17). Each commit turns a seed, the ball, its
# velocity, the floor centre, the phase and the bound radius into hazard descriptors in
# mind_attacks.gd's shape, so MindAttacks.build lays them and MindAttacks.covers tests them.
# Nothing here touches the tree.
#
# Every family is a floor threat: waking.gd lands it only on a ball that FloorRule calls on
# the floor, so a ball carving the rim bank or in the air is spared.
#
# Phase k is the Waking's floor: 1 Spoil, 2 Seam, 3 Bedrock, 4 the pit. Phase k exposes
# families 1..min(k, 3); the pit is the same three, faster, with lanes out of every bore.
#
# Extra descriptor field: delay, seconds after the attack's first warning that this one's
# warning starts. Delays are multiples of GAP, so no two warnings start within GAP seconds
# (the warning gap ruling, "Gap wins", 2026-10-17 20:11Z).

const FAMILIES := ["burrow", "cave_in", "bore"]
const PIT_PHASE := 4
const GAP := 0.2
const CLEAR := Tuning.RADIUS
const HEIGHT := 3.0
const PHASE_TIGHTEN := 0.1
const TIGHTEN_PHASES := 3

const LANE_HALF := 1.6
const BURROW_WARN := 1.4
const BURROW_LIVE := 0.7
# Seam on: a second lane off the first by this bearing, radians.
const BURROW_OFF := Vector2(0.4, 0.8)
const CAVE_COUNT := 3
const CAVE_R := 4.0
const CAVE_WARN := 1.5
const CAVE_LIVE := 0.6
# The holes walk down the ball's line: the first this far ahead, then every CAVE_STEP.
const CAVE_LEAD := 3.0
const CAVE_STEP := 8.0
const BORE_R := 6.0
const BORE_WARN := 1.6
const BORE_LIVE := 0.8
# Pit: lanes fanned out of the bore hole.
const PIT_SPRAY := 3

const DAMAGE := {"burrow": 8.0, "cave_in": 8.0, "bore": 12.0}

const RECOMMITS := 4
const RECOMMIT_STRIDE := 104729
const FALLBACK_PATHS := ["drop", "none"]
const SEARCH_STEP := 0.5
const SEARCH_BEARINGS := 72


# removed: families a broken weak point took away (weak_points.gd); never all of them.
static func exposed(phase: int, removed := []) -> Array:
	var open := FAMILIES.slice(0, clampi(phase, 1, FAMILIES.size()))
	var kept := open.filter(func(f): return not removed.has(f))
	return kept if not kept.is_empty() else open


# The family a phase introduces, the one it teaches first.
static func newest(phase: int, removed := []) -> String:
	return exposed(phase, removed)[-1]


static func choose(seed: int, phase: int, removed := []) -> String:
	var open := exposed(phase, removed)
	return open[_rng(seed).randi() % open.size()]


# Maps any floor/pit phase (1..4) onto the 3-phase boss anthem ruling (1=Base, 2=+10 BPM, 3=+20 BPM).
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


# The set laid always leaves escape_point non-null: a set with none is recommitted on other
# seeds, then trimmed from the last descriptor, else nothing is laid ("none").
static func commit_safe(family: String, seed: int, ball: Vector3, velocity: Vector3, center: Vector3, phase: int, cruise_speed: float,
		radius: float, removed := []) -> Dictionary:
	var first: Array = []
	for k in RECOMMITS + 1:
		var descs := commit(family, seed + k * RECOMMIT_STRIDE, ball, velocity, center, phase, radius, removed)
		if k == 0:
			first = descs
		if escape_point(descs, ball, cruise_speed, center, radius) != null:
			return {"descriptors": descs, "path": "first" if k == 0 else "recommit"}
	for n in range(first.size() - 1, 0, -1):
		var kept := first.slice(0, n)
		if escape_point(kept, ball, cruise_speed, center, radius) != null:
			return {"descriptors": kept, "path": "drop"}
	return {"descriptors": [], "path": "none"}


# A tunnel from the Waking straight down the ball's bearing; Seam on, a second one 0.2 s behind.
static func burrow(seed: int, ball: Vector3, center: Vector3, phase: int, radius: float) -> Array:
	var rng := _rng(seed)
	var bearing := _bearing(rng, ball, center)
	var warn := _warn(BURROW_WARN, phase)
	var out := [_lane("burrow", 0, center, bearing, warn, radius)]
	if phase >= 2:
		var off := rng.randf_range(BURROW_OFF.x, BURROW_OFF.y) * (1.0 if rng.randf() < 0.5 else -1.0)
		var second := _lane("burrow", 1, center, bearing + off, warn, radius)
		second["delay"] = GAP
		out.append(second)
	return out


# Three holes down the ball's line, each warning GAP after the last.
static func cave_in(seed: int, ball: Vector3, velocity: Vector3, center: Vector3, phase: int, radius: float) -> Array:
	var rng := _rng(seed)
	var heading := _flat(velocity)
	if heading.length() < 1.0:
		var b := _bearing(rng, ball, center) + PI
		heading = Vector3(cos(b), 0.0, sin(b))
	heading = heading.normalized()
	var out := []
	for i in CAVE_COUNT:
		var at := _inside(_flat(ball) + heading * (CAVE_LEAD + CAVE_STEP * i), center, radius - CAVE_R)
		var d := _disc("cave_in", i, at, CAVE_R, _warn(CAVE_WARN, phase), CAVE_LIVE)
		d["delay"] = GAP * i
		out.append(d)
	return out


# The drill up through the floor under the ball. In the pit, lanes spray out of the hole.
static func bore(seed: int, ball: Vector3, center: Vector3, phase: int, radius: float, removed := []) -> Array:
	var rng := _rng(seed)
	var at := _inside(_flat(ball), center, radius - BORE_R)
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


# The nearest point inside the bound, CLEAR outside every region, that the ball reaches at
# cruise before the first warning ends; null when there is none. Banks count only as floor
# here: a ball crawling up a bank below grip speed is not carving.
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
	if _flat(p - center).length() > radius - CLEAR:
		return false
	for d in descriptors:
		if MindAttacks.covers(d, p, CLEAR):
			return false
	return true


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


# How far a ray from `from` along `dir` runs before it leaves the bound circle.
static func _chord(from: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var p := _flat(from - center)
	var u := _flat(dir).normalized()
	var b := p.dot(u)
	var c := p.length_squared() - radius * radius
	return maxf(0.0, -b + sqrt(maxf(0.0, b * b - c)))


static func _inside(p: Vector3, center: Vector3, limit: float) -> Vector3:
	var v := _flat(p - center).limit_length(maxf(0.0, limit))
	return Vector3(center.x + v.x, center.y, center.z + v.z)


static func _warn(base: float, phase: int) -> float:
	return ChallengeDials.tell("waking", base - PHASE_TIGHTEN * (clampi(phase, 1, TIGHTEN_PHASES) - 1), Hazard.MIN_WARN)


static func _bearing(rng: RandomNumberGenerator, ball: Vector3, center: Vector3) -> float:
	var v := _flat(ball - center)
	if v.length() < CLEAR:
		return rng.randf() * TAU
	return atan2(v.z, v.x)


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
