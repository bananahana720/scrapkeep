extends RefCounted

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Arena := preload("res://src/boss/arena.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The Mind's four attack families as pure rules: each commit turns a seed, the ball, the
# floor centre, the phase and the bound radius (default Arena.FLOOR_R) into hazard
# descriptors, the arguments hazard.gd's commit_lane, commit_sector and commit_annulus take
# plus warn and live seconds. Nothing here touches the tree; build() lays a descriptor
# onto a real Hazard.
#
# Every family leaves a way out: escape_point() finds a floor point outside every region,
# reachable at cruise before the shortest warn ends. Phase k exposes families 1..k.
#
# Descriptor fields:
#   family, family_index (1-based), id, shape ("lane", "sector" or "annulus"), type
#   (threat_grammar Type), warn, live, height
#   lane:    from, dir, behind, ahead, half
#   sector:  at, band (Vector2 r_in, r_out), from_angle, to_angle
#   annulus: at, band
#   plate also carries the brace: verb, hit_mult_floor, weak_window

const FAMILIES := ["lane", "split_lane", "rush", "plate"]
# 3-phase boss anthem pacing (W49-COMBAT): Base / +10 BPM / +20 BPM + anime whole-step finale lift.
const ANTHEM_BPM_DELTA := [0, 10, 20]
const ANTHEM_PHASE_NAMES := ["Read", "Adapt", "Finale"]
const FINALE_WHOLE_STEP_SEMITONES := 2
# Floors the brief fixes for the Mind: no warn under the Warden's adapt warn, and a
# braced verb never meets more than BRACE_MULT times plating.
const WARN_FLOOR := 1.2
const BRACE_MULT := 1.4
const VERBS := Rules.CONTACT_KINDS
const CLEAR := Tuning.RADIUS
const HEIGHT := 3.0
# Later phases tighten each warn by this much per phase. Tightening stops at
# TIGHTEN_PHASES, so every phase stays at or above WARN_FLOOR.
const PHASE_TIGHTEN := 0.1
const TIGHTEN_PHASES := 3

const LANE_HALF := 1.6
const LANE_WARN := 1.4
const LANE_LIVE := 0.8
const SPLIT_WARN := 1.6
const SPLIT_LIVE := 0.8
# The second lane's bearing off the first, radians.
const SPLIT_OFF := Vector2(0.35, 0.7)
const RUSH_WARN := 1.5
const RUSH_LIVE := 0.6
const RUSH_HALF_BAND := 4.0
const PLATE_WARN := 1.8
const PLATE_LIVE := 1.0
const PLATE_HALF_BAND := 4.0
const PLATE_HALF_SPAN := PI / 4.0
const PLATE_WINDOW := 2.5

const SEARCH_STEP := 0.5
const SEARCH_BEARINGS := 72


# One phase per posture chunk; phase k exposes families 1..k.
static func phase_cap() -> int:
	return FAMILIES.size()


# Maps the Mind's 4 fight phases onto the 3-phase boss anthem (1=Base, 2=+10 BPM, 3..4=+20 BPM finale).
static func anthem_phase(fight_phase: int) -> int:
	return clampi(fight_phase, 1, ANTHEM_BPM_DELTA.size())


static func anthem_bpm_delta(fight_phase: int) -> int:
	return ANTHEM_BPM_DELTA[anthem_phase(fight_phase) - 1]


static func anthem_phase_name(fight_phase: int) -> String:
	return ANTHEM_PHASE_NAMES[anthem_phase(fight_phase) - 1]


static func finale_lift_semitones(fight_phase: int) -> int:
	return FINALE_WHOLE_STEP_SEMITONES if anthem_phase(fight_phase) >= ANTHEM_BPM_DELTA.size() else 0


# removed: families a broken weak point took away (weak_points.gd); never all of them.
static func exposed(phase: int, removed := []) -> Array:
	var open := FAMILIES.slice(0, clampi(phase, 1, phase_cap()))
	var kept := open.filter(func(f): return not removed.has(f))
	return kept if not kept.is_empty() else open


static func choose(seed: int, phase: int, removed := []) -> String:
	var open := exposed(phase, removed)
	var rng := _rng(seed)
	return open[rng.randi() % open.size()]


static func commit_any(seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R, removed := []) -> Array:
	return commit(choose(seed, phase, removed), seed, ball, center, phase, radius)


static func commit(family: String, seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Array:
	match family:
		"lane":
			return lane(seed, ball, center, phase, radius)
		"split_lane":
			return split_lane(seed, ball, center, phase, radius)
		"rush":
			return rush(seed, ball, center, phase, radius)
		"plate":
			return plate(seed, ball, center, phase, radius)
	push_error("mind_attacks: unknown family %s" % family)
	return []


# commit or commit_any made a guarantee: the set laid always leaves escape_point non-null.
# A set with no escape is recommitted at seed + k * RECOMMIT_STRIDE, k up to RECOMMITS, in the
# same family set; then its descriptors are dropped from the last until an escape exists;
# then a single lane pointed away from the ball is laid. "path" names the step that held
# ("first", "recommit", "drop", "single"; "none" with no descriptors when the ball cannot
# reach any clear floor at all, so nothing is laid).
const RECOMMITS := 4
const RECOMMIT_STRIDE := 104729
const FALLBACK_PATHS := ["drop", "single", "none"]


static func commit_safe(family: String, seed: int, ball: Vector3, center: Vector3, phase: int, cruise_speed: float, radius := Arena.FLOOR_R, removed := []) -> Dictionary:
	var first: Array = []
	for k in RECOMMITS + 1:
		var s := seed + k * RECOMMIT_STRIDE
		var descs: Array = commit_any(s, ball, center, phase, radius, removed) if family == "" else commit(family, s, ball, center, phase, radius)
		if k == 0:
			first = descs
		if escape_point(descs, ball, cruise_speed, center, radius) != null:
			return {"descriptors": descs, "path": "first" if k == 0 else "recommit"}
	for n in range(first.size() - 1, 0, -1):
		var kept := first.slice(0, n)
		if escape_point(kept, ball, cruise_speed, center, radius) != null:
			return {"descriptors": kept, "path": "drop"}
	var away := [away_lane(ball, center, phase, radius)]
	if escape_point(away, ball, cruise_speed, center, radius) != null:
		return {"descriptors": away, "path": "single"}
	return {"descriptors": [], "path": "none"}


# The last resort: a lane from just off the centre pointing away from the ball, so the ball
# is never inside it.
static func away_lane(ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Dictionary:
	var v := _flat(ball - center)
	var bearing := (atan2(v.z, v.x) if v.length() > 0.0 else 0.0) + PI
	var d := _lane_desc("lane", 0, center, bearing, _warn(LANE_WARN, phase), LANE_LIVE, radius)
	d["from"] = center + _flat(d["dir"]) * CLEAR
	d["ahead"] = float(d["ahead"]) - CLEAR
	return d


# One lane from the Mind at the centre straight down the ball's bearing.
static func lane(seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Array:
	var rng := _rng(seed)
	var bearing := _bearing(rng, ball, center)
	return [_lane_desc("lane", 0, center, bearing, _warn(LANE_WARN, phase), LANE_LIVE, radius)]


# The ball's lane plus a second one off to a seeded side, so one sidestep is cut.
static func split_lane(seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Array:
	var rng := _rng(seed)
	var bearing := _bearing(rng, ball, center)
	var off := rng.randf_range(SPLIT_OFF.x, SPLIT_OFF.y) * (1.0 if rng.randf() < 0.5 else -1.0)
	var warn := _warn(SPLIT_WARN, phase)
	return [_lane_desc("split_lane", 0, center, bearing, warn, SPLIT_LIVE, radius),
		_lane_desc("split_lane", 1, center, bearing + off, warn, SPLIT_LIVE, radius)]


# A ring about the centre whose band holds the ball's radius: step in or out of it.
static func rush(_seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Array:
	var rb := _flat(ball - center).length()
	var d := _base("rush", 0, "annulus", Threat.Type.INSTANT, _warn(RUSH_WARN, phase), RUSH_LIVE)
	d["at"] = center
	d["band"] = Vector2(maxf(0.0, rb - RUSH_HALF_BAND), minf(radius, rb + RUSH_HALF_BAND))
	return [d]


# The brace: a sector sweep over the ball's band, then a named verb meets more plating
# while the weak point stays open for weak_window seconds.
static func plate(seed: int, ball: Vector3, center: Vector3, phase: int, radius := Arena.FLOOR_R) -> Array:
	var rng := _rng(seed)
	var bearing := _bearing(rng, ball, center)
	var rb := _flat(ball - center).length()
	var d := _base("plate", 0, "sector", Threat.Type.WAVE, _warn(PLATE_WARN, phase), PLATE_LIVE)
	d["at"] = center
	d["band"] = Vector2(maxf(0.0, rb - PLATE_HALF_BAND), minf(radius, rb + PLATE_HALF_BAND))
	d["from_angle"] = bearing - PLATE_HALF_SPAN
	d["to_angle"] = bearing + PLATE_HALF_SPAN
	d["verb"] = VERBS[rng.randi() % VERBS.size()]
	d["hit_mult_floor"] = 1.0 / BRACE_MULT
	d["weak_window"] = ChallengeDials.punish("mind", PLATE_WINDOW)
	return [d]


# What a hit of this verb is worth against the plate's brace.
static func hit_mult(d: Dictionary, verb: String) -> float:
	return float(d["hit_mult_floor"]) if verb == d.get("verb", "") else 1.0


# A Hazard laid from a descriptor, not yet in the tree.
static func build(d: Dictionary) -> Node3D:
	var h := Hazard.new()
	match d["shape"]:
		"lane":
			h.commit_lane(d["id"], d["type"], d["from"], d["dir"], d["behind"], d["ahead"], d["half"], d["height"], d["warn"], d["live"])
		"sector":
			h.commit_sector(d["id"], d["type"], d["at"], d["band"], d["from_angle"], d["to_angle"], d["height"], d["warn"], d["live"])
		"annulus":
			h.commit_annulus(d["id"], d["type"], d["at"], d["band"], d["height"], d["warn"], d["live"])
	return h


# The nearest floor point inside the bound radius, at least CLEAR outside every region, that the
# ball reaches at cruise before the shortest warn ends; null when there is none.
static func escape_point(descriptors: Array, ball: Vector3, cruise_speed: float, center := Vector3.ZERO, radius := Arena.FLOOR_R):
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
		if covers(d, p, CLEAR):
			return false
	return true


# The descriptor's region grown by pad metres, on the flat; mirrors Hazard.contains().
static func covers(d: Dictionary, p: Vector3, pad := 0.0) -> bool:
	match d["shape"]:
		"lane":
			var dir: Vector3 = _flat(d["dir"]).normalized()
			var local := _flat(p - d["from"])
			var along := local.dot(dir)
			var lateral := local.dot(Vector3.UP.cross(dir).normalized())
			return along >= -float(d["behind"]) - pad and along <= float(d["ahead"]) + pad and absf(lateral) <= float(d["half"]) + pad
		"annulus":
			var r := _flat(p - d["at"]).length()
			return r >= d["band"].x - pad and r <= d["band"].y + pad
		"sector":
			var v := _flat(p - d["at"])
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


static func _lane_desc(family: String, n: int, center: Vector3, bearing: float, warn: float, live: float, radius: float) -> Dictionary:
	var d := _base(family, n, "lane", Threat.Type.LANE, warn, live)
	d["from"] = center
	d["dir"] = Vector3(cos(bearing), 0.0, sin(bearing))
	d["behind"] = 0.0
	# The far corners sit inside the bound radius: sqrt(ahead^2 + half^2) < radius.
	d["ahead"] = radius - LANE_HALF
	d["half"] = LANE_HALF
	return d


static func _base(family: String, n: int, shape: String, type: int, warn: float, live: float) -> Dictionary:
	return {"family": family, "family_index": FAMILIES.find(family) + 1, "id": "mind_%s_%d" % [family, n], "shape": shape,
		"type": type, "warn": warn, "live": live, "height": HEIGHT}


static func _warn(base: float, phase: int) -> float:
	return ChallengeDials.tell("mind", base - PHASE_TIGHTEN * (clampi(phase, 1, TIGHTEN_PHASES) - 1), WARN_FLOOR)


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
