extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")
const Crown := preload("res://src/world/map_highdraft_crown.gd")

# Highdraft: the crown, greybox zone map: slots, the net deck's height and material, islands
# higher and farther apart than the first Highdraft's, a bridge route from spawn to beacon that
# needs no thermal, barges and thermals placed clear of bridges and skirts, falls off island
# rims landing on the deck, and the contraption specs building. Evidence limit: headless
# physics on the greybox; no lift, harpoon, camera or feel claim.

const GRAVITY := 26.0
const FALLS := 20
const FALL_SEED := 11
const FALL_OFFSET := 2.0
const FALL_CLEAR := 2.0
# The balls do not collide with one another (layer 2, mask 1), so all twenty drop together
# and share one FALL_SECONDS of physics.
const FALL_SECONDS := 4.0
const REST_TOLERANCE := 0.3
const SIM_CAP_SECONDS := 100.0
const TOP_ABOVE_DECK := 24.0
const CHAIN_RATIO := 1.4
const ROUTE_CLEARANCE := 1.0
const ROUTE_GRADE := 0.5
const RAMP_STEP := 1.5
const BETWEEN := Vector2(-60.0, 20.0)
const KEYS := ["spawn", "mid", "west", "vault", "beacon"]


class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(Crown.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


var _t := T.new("highdraft_crown_zone_test")
var _scene: Node3D
var _terrain
var _balls: Array[RigidBody3D] = []
var _drops: Array[Vector3] = []
var _lowest := INF
var _ticks := 0
var _hz := 90.0


func _initialize() -> void:
	_hz = float(Engine.physics_ticks_per_second)
	_scene = Node3D.new()
	root.add_child(_scene)
	_terrain = ProbeTerrain.new()
	_terrain.build(_scene)
	var map = _terrain.map()
	_t.check("(1) map fills the ZoneSchema slots", ZoneSchema.validate(map).is_empty(), str(ZoneSchema.validate(map)))
	_t.eq("(1) title", map.title, "Highdraft: the crown")
	_check_deck(map)
	_check_islands(map)
	_check_route()
	_check_placements(map)
	_check_ramps(map)
	_plan_falls(map)


func _check_deck(map) -> void:
	_t.near("(2) ground between the spawn and west islands is the deck", _terrain.height(BETWEEN.x, BETWEEN.y), Highdraft.NET_H, 0.001)
	var deck: Dictionary = _terrain.material_at(Vector3(BETWEEN.x, Highdraft.NET_H, BETWEEN.y))
	_t.eq("(2) material on the deck", deck.get("material"), "net")
	var isle: Vector2 = Crown.CROWN_ISLANDS["spawn"]["at"]
	var top: Dictionary = _terrain.material_at(Vector3(isle.x, 50.0, isle.y))
	_t.check("(2) material on an island is not net", top.get("material") != "net", "got %s" % str(top.get("material")))
	_t.near("(3) net_deck_height()", map.net_deck_height(), Highdraft.NET_H)


func _chain(isles: Dictionary) -> float:
	var s: Vector2 = isles["spawn"]["at"]
	var m: Vector2 = isles["mid"]["at"]
	var b: Vector2 = isles["beacon"]["at"]
	return s.distance_to(m) + m.distance_to(b)


func _closest_pair(isles: Dictionary) -> float:
	var ids: Array = isles.keys()
	var best := INF
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			best = minf(best, (isles[ids[i]]["at"] as Vector2).distance_to(isles[ids[j]]["at"]))
	return best


func _check_islands(map) -> void:
	var isles: Dictionary = Crown.CROWN_ISLANDS
	_t.check("(4) the crown keeps the parent's island keys", KEYS.all(func(k): return isles.has(k)) and isles.size() >= 5,
		"keys %s" % [isles.keys()])
	var low := INF
	var low_id := ""
	for id in isles:
		if float(isles[id]["top"]) < low:
			low = isles[id]["top"]
			low_id = id
	_t.check("(4) every island top at least NET_H + %d" % TOP_ABOVE_DECK, low >= Highdraft.NET_H + TOP_ABOVE_DECK,
		"lowest top %.1f (%s), need >= %.1f" % [low, low_id, Highdraft.NET_H + TOP_ABOVE_DECK])
	var ratio := _chain(isles) / _chain(Highdraft.ISLANDS)
	_t.check("(4) spawn-to-beacon chain at least %.1fx the first zone's" % CHAIN_RATIO, ratio >= CHAIN_RATIO,
		"crown %.1f m, first %.1f m, ratio %.3f" % [_chain(isles), _chain(Highdraft.ISLANDS), ratio])
	_t.check("(4) closest island pair farther apart than the first zone's", _closest_pair(isles) > _closest_pair(Highdraft.ISLANDS),
		"crown %.1f m, first %.1f m" % [_closest_pair(isles), _closest_pair(Highdraft.ISLANDS)])
	var first = Highdraft.new()
	_t.check("(4) spawn and beacon differ from the first Highdraft's", map.spawn != first.spawn and map.beacon != first.beacon,
		"crown %s / %s, first %s / %s" % [map.spawn, map.beacon, first.spawn, first.beacon])
	_t.eq("(4) the first Highdraft keeps its own spawn", first.spawn, Highdraft.ISLANDS["spawn"]["at"])


func _check_route() -> void:
	var isles: Dictionary = Crown.CROWN_ISLANDS
	var route: Array = [isles["spawn"]["at"], isles["mid"]["at"], isles["beacon"]["at"]]
	var lowest := INF
	var steepest := 0.0
	var worst_at := Vector2.ZERO
	var samples := 0
	var last := NAN
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var steps := int(ceil(a.distance_to(b)))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps)
			var h: float = _terrain.height(p.x, p.y)
			samples += 1
			if h < lowest:
				lowest = h
				worst_at = p
			if not is_nan(last):
				steepest = maxf(steepest, absf(h - last) / maxf(a.distance_to(b) / steps, 0.001))
			last = h
	_t.check("(5) bridge route never drops to the deck", lowest >= Highdraft.NET_H + ROUTE_CLEARANCE,
		"%d samples, lowest %.2f at %s (need >= %.1f)" % [samples, lowest, str(worst_at), Highdraft.NET_H + ROUTE_CLEARANCE])
	_t.check("(5) bridge route grade", steepest <= ROUTE_GRADE, "steepest %.3f (limit %.1f)" % [steepest, ROUTE_GRADE])


func _bridge_gap(p: Vector2) -> float:
	var isles: Dictionary = Crown.CROWN_ISLANDS
	var best := INF
	for pair in Crown.CROWN_BRIDGES:
		var a: Vector2 = isles[pair[0]]["at"]
		var b: Vector2 = isles[pair[1]]["at"]
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best


func _check_placements(map) -> void:
	var isles: Dictionary = Crown.CROWN_ISLANDS
	var tops: Array = isles.values().map(func(i): return float(i["top"]))
	var half_diag := Vector2(Highdraft.BARGE_SIZE.x, Highdraft.BARGE_SIZE.z).length() * 0.5
	var clear := Highdraft.BRIDGE_HALF + Highdraft.BRIDGE_SKIRT + half_diag
	var bad := []
	for spec in map.contraptions.filter(func(s): return s["kind"] == "barge"):
		for end in [spec["a"], spec["b"]]:
			var flat := Vector2(end.x, end.z)
			if not tops.any(func(top): return is_equal_approx(end.y, top - Highdraft.BARGE_SIZE.y * 0.5)) or _bridge_gap(flat) < clear:
				bad.append("%s %s gap %.1f" % [spec["id"], str(end), _bridge_gap(flat)])
	_t.check("(6) every barge end sits at an island top and clear of a bridge", bad.is_empty(), "need gap >= %.1f; %s" % [clear, bad])
	bad = []
	for spec in map.contraptions.filter(func(s): return s["kind"] == "thermal"):
		if not _open_deck(map, spec["at"], float(spec["radius"])):
			bad.append(spec["id"])
		elif Highdraft.NET_H + float(spec["height"]) <= tops.max():
			bad.append("%s short" % spec["id"])
	_t.check("(6) every thermal rises from open deck past every top", bad.is_empty(), str(bad))
	var ids: Array = map.activity_sites.map(func(s): return s["id"])
	var on_tops: bool = map.activity_sites.all(func(s): return map.sample(s["at"].x, s["at"].y)[0] >= Highdraft.NET_H + TOP_ABOVE_DECK)
	_t.check("(7) one camp and one combat site, both on island tops", ids.count("enemy_camp") == 1
		and (ids.has("ambush_altar") or ids.has("hauler_bounty")) and on_tops, "sites %s, on tops %s" % [ids, on_tops])


# Every ramp's centre line in the map's height field, metre by metre from the foot to the
# rim, rises without a drop from the deck to the island top, no step over RAMP_STEP; the
# terrain beside it, away from the bridge and past one grid cell, is still the deck.
func _check_ramps(map) -> void:
	var ramps: Array = map._ramps()
	_t.check("(10) the beacon island has a ramp", ramps.any(func(r): return r["island"] == "beacon"), str(ramps))
	for ramp in ramps:
		var line: Dictionary = map.ramp_line(ramp)
		var foot: Vector2 = line["foot"]
		var rim: Vector2 = line["rim"]
		var steps := int(ceil(foot.distance_to(rim)))
		var heights: Array[float] = []
		for s in steps + 1:
			var p := foot.lerp(rim, float(s) / steps)
			heights.append(map.sample(p.x, p.y)[0])
		var drop := 0.0
		var step := 0.0
		for k in range(1, heights.size()):
			drop = maxf(drop, heights[k - 1] - heights[k])
			step = maxf(step, absf(heights[k] - heights[k - 1]))
		var name := "%s ramp side %+.0f" % [ramp["island"], ramp["side"]]
		_t.near("(10) %s starts on the deck" % name, heights[0], Highdraft.NET_H, 0.01)
		_t.near("(10) %s ends at the island top" % name, heights[-1], float(line["top"]), 0.01)
		_t.check("(10) %s rises monotonically, steps <= %.1f m" % [name, RAMP_STEP], drop <= 0.001 and step <= RAMP_STEP,
			"%d samples over %.1f m, worst drop %.3f, worst step %.3f" % [heights.size(), foot.distance_to(rim), drop, step])
		var axis: Vector2 = (foot - rim).normalized()
		var out := Vector2(-axis.y, axis.x) * signf(ramp["side"]) * (Highdraft.RAMP_HALF + Highdraft.RAMP_SKIRT + Terrain.STEP + 1.0)
		var beside: Vector2 = foot.lerp(rim, 0.5) + out
		_t.near("(10) deck beside the %s at %s" % [name, str(beside)], _terrain.height(beside.x, beside.y), Highdraft.NET_H, 0.001)


func _build_contraptions(map) -> void:
	var contraptions = Contraptions.new()
	_terrain.geometry_root(1).add_child(contraptions)
	contraptions.setup(map, _terrain.ground_callable(1), 14.0, GRAVITY)
	_t.eq("(8) thermals built", contraptions.thermals.size(), 3)
	_t.eq("(8) barges built", contraptions.barges.size(), 2)
	_t.eq("(8) cables built", contraptions.cables.size(), 1)


func _plan_falls(map) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FALL_SEED
	var isles: Dictionary = Crown.CROWN_ISLANDS
	var ids: Array = isles.keys()
	var lanes: Array[AABB] = []
	for barge in map.contraptions.filter(func(s): return s["kind"] == "barge"):
		lanes.append(AABB((barge["a"] as Vector3) - Highdraft.BARGE_SIZE * 0.5, Vector3.ZERO).expand((barge["b"] as Vector3) + Highdraft.BARGE_SIZE * 0.5).grow(2.0))
	var tries := 0
	while _drops.size() < FALLS and tries < 1000:
		tries += 1
		var isle: Dictionary = isles[ids[_drops.size() % ids.size()]]
		var flat: Vector2 = (isle["at"] as Vector2) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * (float(isle["radius"]) + Highdraft.SKIRT + FALL_OFFSET)
		if not _open_deck(map, flat, FALL_CLEAR):
			continue
		var at := Vector3(flat.x, float(isle["top"]) + Tuning.RADIUS, flat.y)
		if lanes.any(func(lane: AABB): return lane.has_point(Vector3(at.x, lane.get_center().y, at.z))):
			continue
		_drops.append(at)
	_t.eq("(9) drop spots found off island rims", _drops.size(), FALLS)


# The spot and a ring `ring` metres around it are all deck.
func _open_deck(map, p: Vector2, ring: float) -> bool:
	for k in 9:
		var q := p if k == 8 else p + Vector2.from_angle(k * TAU / 8.0) * ring
		if map.sample(q.x, q.y)[0] > Highdraft.NET_H:
			return false
	return true


func _make_ball(at: Vector3) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = 6.0
	b.can_sleep = false
	b.continuous_cd = true
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.linear_damp = 0.0
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	b.angular_damp = 0.25
	b.gravity_scale = GRAVITY / 9.8
	var material := PhysicsMaterial.new()
	material.friction = 0.9
	material.bounce = 0.25
	b.physics_material_override = material
	b.collision_layer = 0
	b.collision_mask = 0
	b.set_collision_layer_value(2, true)
	b.set_collision_mask_value(1, true)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	b.add_child(shape)
	_scene.add_child(b)
	b.position = at
	return b


func _physics_process(_delta: float) -> bool:
	_ticks += 1
	if _ticks == 1:
		_build_contraptions(_terrain.map())
		for at in _drops:
			_balls.append(_make_ball(at))
		return false
	if _ticks / _hz > SIM_CAP_SECONDS:
		_t.check("finished inside the sim cap", false, "sim %.2f s" % (_ticks / _hz))
		return _finish()
	for b in _balls:
		_lowest = minf(_lowest, b.global_position.y)
	if _ticks < int(FALL_SECONDS * _hz) + 1:
		return false
	_check_falls()
	return _finish()


func _check_falls() -> void:
	var want := Highdraft.NET_H + Tuning.RADIUS
	var worst := 0.0
	var worst_at := Vector3.ZERO
	for i in _balls.size():
		var miss := absf(_balls[i].global_position.y - want)
		if miss > worst:
			worst = miss
			worst_at = _drops[i]
	_t.check("(9) %d rim falls rest on the net deck" % _balls.size(), _balls.size() == FALLS and worst <= REST_TOLERANCE,
		"rest y vs NET_H + radius %.2f after %.1f s: worst miss %.4f m from %s (limit %.1f)" % [want, FALL_SECONDS, worst, str(worst_at), REST_TOLERANCE])
	_t.check("(9) no fall passes below the deck", _lowest >= Highdraft.NET_H,
		"lowest centre y %.3f, NET_H %.1f" % [_lowest, Highdraft.NET_H])


func _finish() -> bool:
	_scene.free()
	quit(_t.verdict())
	return true
