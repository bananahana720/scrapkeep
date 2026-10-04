extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")

# Highdraft greybox zone map: slots, the net deck's height and material, a bridge route
# from spawn to beacon that needs no thermal, falls off island rims landing on the deck,
# and the contraption specs building. Evidence limit: headless physics on the greybox;
# no lift, harpoon, camera or feel claim.

const GRAVITY := 26.0
const FALLS := 20
const FALL_SEED := 11
# Just off a rim: past the skirt, on open deck.
const FALL_OFFSET := 2.0
const FALL_CLEAR := 2.0
# Balls drop one after another, each with its own FALL_SECONDS of physics (360 ticks at
# 90 Hz), so the falls take 80 s of sim time; the cap below leaves room.
const FALL_SECONDS := 4.0
const REST_TOLERANCE := 0.3
const SIM_CAP_SECONDS := 100.0
const ROUTE := [Vector2(0.0, 120.0), Vector2(0.0, 40.0), Vector2(0.0, -60.0)]
const ROUTE_CLEARANCE := 1.0
const ROUTE_GRADE := 0.5
const BETWEEN := Vector2(-35.0, 10.0)


# Terrain takes only registered maps (terrain.gd _init), so this one fills its own row.
class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(Highdraft.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


var _t := T.new("highdraft_zone_test")
var _scene: Node3D
var _terrain
var _drops: Array[Vector3] = []
var _ball: RigidBody3D
var _index := -1
var _ball_ticks := 0
var _low := INF
var _worst := 0.0
var _worst_at := Vector3.ZERO
var _lowest := INF
var _ticks := 0
var _hz := 90.0
var _contraptions
var _barge_ticks := 0
var _barge_stepped := false
var _to_a := INF
var _to_b := INF
var _off_lane := 0.0


func _initialize() -> void:
	_hz = float(Engine.physics_ticks_per_second)
	_scene = Node3D.new()
	root.add_child(_scene)
	_terrain = ProbeTerrain.new()
	_terrain.build(_scene)
	var map = _terrain.map()
	_t.check("(1) map fills the ZoneSchema slots", ZoneSchema.validate(map).is_empty(), str(ZoneSchema.validate(map)))
	_check_deck(map)
	_check_route()
	_plan_falls(map)


func _check_deck(map) -> void:
	var at := Vector3(BETWEEN.x, 0.0, BETWEEN.y)
	_t.near("(2) ground between the mid and west islands is the deck", _terrain.height(at.x, at.z), Highdraft.NET_H, 0.001)
	var deck: Dictionary = _terrain.material_at(Vector3(at.x, Highdraft.NET_H, at.z))
	_t.eq("(2) material on the deck", deck.get("material"), "net")
	var isle: Vector2 = Highdraft.ISLANDS["spawn"]["at"]
	var top: Dictionary = _terrain.material_at(Vector3(isle.x, 30.0, isle.y))
	_t.check("(2) material on an island is not net", top.get("material") != "net", "got %s" % str(top.get("material")))
	_t.near("(3) net_deck_height()", map.net_deck_height(), Highdraft.NET_H)


func _check_route() -> void:
	var lowest := INF
	var steepest := 0.0
	var worst_at := Vector2.ZERO
	var samples := 0
	var last := NAN
	for i in ROUTE.size() - 1:
		var a: Vector2 = ROUTE[i]
		var b: Vector2 = ROUTE[i + 1]
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
	_t.check("(4) bridge route never drops to the deck", lowest >= Highdraft.NET_H + ROUTE_CLEARANCE,
		"%d samples, lowest %.2f at %s (need >= %.1f)" % [samples, lowest, str(worst_at), Highdraft.NET_H + ROUTE_CLEARANCE])
	_t.check("(4) bridge route grade", steepest <= ROUTE_GRADE, "steepest %.3f (limit %.1f)" % [steepest, ROUTE_GRADE])


func _build_contraptions(map) -> void:
	_contraptions = Contraptions.new()
	_terrain.geometry_root(1).add_child(_contraptions)
	_contraptions.setup(map, _terrain.ground_callable(1), 14.0, GRAVITY)
	_t.eq("(6) thermals built", _contraptions.thermals.size(), 2)
	_t.eq("(6) barges built", _contraptions.barges.size(), 1)
	_t.eq("(6) cables built", _contraptions.cables.size(), 1)
	var spec: Dictionary = _contraptions.barges[0]["spec"]
	_barge_ticks = int(2.0 * (float(spec["travel"]) + float(spec["dwell"])) * _hz) + 2


# The barge is an AnimatableBody synced to physics, so its position is read once per
# physics tick, the way world.gd steps it, while the falls run beside it.
func _step_barge() -> void:
	if _barge_ticks <= 0:
		return
	_barge_ticks -= 1
	var spec: Dictionary = _contraptions.barges[0]["spec"]
	var a: Vector3 = spec["a"]
	var b: Vector3 = spec["b"]
	# The body shows a placement a physics tick after it is made, so the first read waits.
	if _barge_stepped:
		var at: Vector3 = _contraptions.barge_position(0)
		_to_a = minf(_to_a, at.distance_to(a))
		_to_b = minf(_to_b, at.distance_to(b))
		_off_lane = maxf(_off_lane, at.distance_to(Geometry3D.get_closest_point_to_segment(at, a, b)))
	_barge_stepped = true
	_contraptions.step(1.0 / _hz, Vector3(0.0, -1000.0, 0.0), Vector3.ZERO, null, false)
	if _barge_ticks > 0:
		return
	var period := 2.0 * (float(spec["travel"]) + float(spec["dwell"]))
	_t.check("(6) barge moves between a and b over one period", _to_a < 0.05 and _to_b < 0.05 and _off_lane < 0.01,
		"period %.1f s: closest to a %.3f m, to b %.3f m, off lane %.3f m" % [period, _to_a, _to_b, _off_lane])


func _plan_falls(map) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FALL_SEED
	var ids: Array = Highdraft.ISLANDS.keys()
	var barge: Dictionary = map.contraptions.filter(func(s): return s["kind"] == "barge")[0]
	var lane := AABB((barge["a"] as Vector3) - Highdraft.BARGE_SIZE * 0.5, Vector3.ZERO).expand((barge["b"] as Vector3) + Highdraft.BARGE_SIZE * 0.5).grow(2.0)
	var tries := 0
	while _drops.size() < FALLS and tries < 1000:
		tries += 1
		var isle: Dictionary = Highdraft.ISLANDS[ids[_drops.size() % ids.size()]]
		var flat: Vector2 = (isle["at"] as Vector2) + Vector2.from_angle(rng.randf_range(0.0, TAU)) * (float(isle["radius"]) + Highdraft.SKIRT + FALL_OFFSET)
		if not _open_deck(map, flat):
			continue
		var at := Vector3(flat.x, float(isle["top"]) + Tuning.RADIUS, flat.y)
		if lane.has_point(Vector3(at.x, lane.get_center().y, at.z)):
			continue
		_drops.append(at)
	_t.eq("(5) drop spots found off island rims", _drops.size(), FALLS)


# The spot and a ring FALL_CLEAR around it are all deck, so a drop lands on the net and
# not on a bridge or skirt.
func _open_deck(map, p: Vector2) -> bool:
	for k in 9:
		var q := p if k == 8 else p + Vector2.from_angle(k * TAU / 8.0) * FALL_CLEAR
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
	# Contraptions read global positions, which exist once the scene is in the tree.
	if _ticks == 1:
		_build_contraptions(_terrain.map())
	_step_barge()
	if _ticks / _hz > SIM_CAP_SECONDS:
		_t.check("finished inside the sim cap", false, "sim %.2f s, ball %d of %d" % [_ticks / _hz, _index + 1, _drops.size()])
		return _finish()
	if _ball != null:
		_ball_ticks += 1
		_low = minf(_low, _ball.global_position.y)
		if _ball_ticks < int(FALL_SECONDS * _hz):
			return false
		var miss := absf(_ball.global_position.y - (Highdraft.NET_H + Tuning.RADIUS))
		if miss > _worst:
			_worst = miss
			_worst_at = _drops[_index]
		_lowest = minf(_lowest, _low)
		_ball.free()
		_ball = null
	_index += 1
	if _index >= _drops.size():
		_check_falls()
		return _finish()
	_ball = _make_ball(_drops[_index])
	_ball_ticks = 0
	_low = INF
	return false


func _check_falls() -> void:
	var want := Highdraft.NET_H + Tuning.RADIUS
	_t.check("(5) %d rim falls rest on the net deck" % _drops.size(), _worst <= REST_TOLERANCE,
		"rest y vs NET_H + radius %.2f after %.1f s each: worst miss %.4f m from %s (limit %.1f)" % [want, FALL_SECONDS, _worst, str(_worst_at), REST_TOLERANCE])
	_t.check("(5) no fall passes below the deck", _lowest >= Highdraft.NET_H,
		"lowest centre y %.3f, NET_H %.1f" % [_lowest, Highdraft.NET_H])


func _finish() -> bool:
	_scene.free()
	quit(_t.verdict())
	return true
