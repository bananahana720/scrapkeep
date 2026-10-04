extends SceneTree

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Contraptions := preload("res://src/world/contraptions.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const ZoneSchema := preload("res://src/world/zone_schema.gd")
const Highdraft := preload("res://src/world/map_highdraft.gd")

# Highdraft's Lift as data: harpoon posts on island rims, three thermal columns on the
# deck, two barges cycling between islands, each held to contraptions.gd's and
# augments.gd's own facts. Evidence limit: headless, the ball is a point the test moves;
# the thermal ride assumes the ball glides throughout, which augments.gd's glide rule
# (glides only while falling) does not yet allow. No camera, feel or full-ride claim.

const GRAVITY := 26.0
const BARGE := 1
const LANE_TOLERANCE := 0.01
# barge_isle's smoothstep peak is 1.5 x 24.3 m / 8 s = 4.6 m/s; a rider is carried at
# speeds like that, a jump between ends is not one.
const MAX_BARGE_SPEED := 5.0
const RIDE_START := 5.0
const RIDE_SECONDS := 3.0
const RIDE_GAIN := 20.0
const EYE_GAP := 12.0
const AXIS_TOLERANCE := 1.5
const DECK_POINTS := [Vector2(-35.0, 10.0), Vector2(40.0, 80.0), Vector2(-40.0, -100.0),
	Vector2(60.0, -60.0), Vector2(-90.0, 40.0), Vector2(100.0, 0.0)]


# Terrain takes only maps it builds itself (terrain.gd _init), so this one fills its own row.
class ProbeTerrain extends "res://src/world/terrain.gd":
	func _init() -> void:
		super({"DEFS": []})
		maps.append(Highdraft.new())
		_worlds.append(1)
		_roots.append(null)
		_heights.append(PackedFloat32Array())


class GlidingKit:
	var gliding := true


var _t := T.new("highdraft_lift_test")
var _scene: Node3D
var _terrain
var _map
var _contraptions
var _hz := 90.0
var _ticks := 0
var _barge_ticks := 0
var _last := Vector3.INF
var _to_a := INF
var _to_b := INF
var _off_lane := 0.0
var _speed := 0.0
var _stepped := false


func _initialize() -> void:
	_hz = float(Engine.physics_ticks_per_second)
	_scene = Node3D.new()
	root.add_child(_scene)
	_terrain = ProbeTerrain.new()
	_terrain.build(_scene)
	_map = _terrain.map()
	_check_posts()
	_check_deck()


func _top() -> float:
	var top := -INF
	for id in Highdraft.ISLANDS:
		top = maxf(top, float(Highdraft.ISLANDS[id]["top"]))
	return top


func _island_of(p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	for id in Highdraft.ISLANDS:
		var isle: Dictionary = Highdraft.ISLANDS[id]
		if best.is_empty() or p.distance_to(isle["at"]) < p.distance_to(best["at"]):
			best = isle
	return best


# (a) The posts fill ZoneSchema's hard_points and each stands on an island top.
func _check_posts() -> void:
	var issues: Array = ZoneSchema.validate(_map)
	_t.check("(a) ZoneSchema.validate", issues.is_empty(), str(issues))
	_t.eq("(a) one hard point per post", _map.hard_points.size(), Highdraft.POSTS.size())
	_t.eq("(a) one post per island", Highdraft.POSTS.size(), Highdraft.ISLANDS.size())
	var bad := []
	for post in Highdraft.POSTS:
		var at: Vector2 = post["at"]
		var isle := _island_of(at)
		var h: float = _map.sample(at.x, at.y)[0]
		if h <= Highdraft.NET_H + 10.0 or at.distance_to(isle["at"]) > float(isle["radius"]):
			bad.append("%s height %.2f, %.2f m from centre (radius %.0f)" % [str(at), h, at.distance_to(isle["at"]), isle["radius"]])
	_t.check("(a) every post on an island top, inside its radius", bad.is_empty(), str(bad))


# (f) The deck under the columns and at open points is the net, so a fall reset lands there.
func _check_deck() -> void:
	var points: Array = DECK_POINTS.duplicate()
	for spec in _map.contraptions:
		if spec["kind"] == "thermal":
			points.append(spec["at"])
	var bad := []
	for p in points:
		var h: float = _terrain.height(p.x, p.y)
		if absf(h - Highdraft.NET_H) > 0.001:
			bad.append("%s %.3f" % [str(p), h])
	_t.check("(f) terrain.height at %d deck points == NET_H" % points.size(), bad.is_empty(), str(bad))


# (b) The specs build, every column stands on the deck and tops out above every island.
func _check_built() -> void:
	_t.eq("(b) thermals built", _contraptions.thermals.size(), 3)
	_t.eq("(b) barges built", _contraptions.barges.size(), 2)
	_t.eq("(b) cables built", _contraptions.cables.size(), 1)
	var top := _top()
	var bad := []
	for t in _contraptions.thermals:
		var base: Vector3 = t["base"]
		var height: float = t["spec"]["height"]
		if absf(base.y - Highdraft.NET_H) > 0.001 or base.y + height <= top:
			bad.append("%s base y %.2f, top %.2f" % [t["spec"]["id"], base.y, base.y + height])
	_t.check("(b) every thermal base on the deck, top above %.0f" % top, bad.is_empty(), str(bad))
	_check_barge_clear()


# (c) part: each barge, docked at either end, sits over ground no higher than its own
# underside, so its lane is clear of island tops and bridges.
func _check_barge_clear() -> void:
	var bad := []
	for spec in _map.contraptions:
		if spec["kind"] != "barge":
			continue
		var size: Vector3 = spec["size"]
		for end in ["a", "b"]:
			var at: Vector3 = spec[end]
			var under := at.y - size.y * 0.5
			for i in 15:
				for j in 15:
					var x := at.x - size.x * 0.5 + size.x * i / 14.0
					var z := at.z - size.z * 0.5 + size.z * j / 14.0
					var h: float = _map.sample(x, z)[0]
					if h > under:
						bad.append("%s.%s ground %.2f over underside %.2f at (%.1f, %.1f)" % [spec["id"], end, h, under, x, z])
	_t.check("(c) barge footprints clear of island tops and bridges", bad.is_empty(), str(bad.slice(0, 4)))


# (e) A harpoon aimed at each post from 12 m inward at mid-height bites the post.
func _check_harpoon() -> void:
	var space := _scene.get_world_3d().direct_space_state
	var reach: float = Tuning.new().f("rope_range")
	var ground: Callable = _terrain.ground_callable(1)
	var bad := []
	for post in Highdraft.POSTS:
		var at: Vector2 = post["at"]
		var foot: Vector3 = ground.call(at.x, at.y, -0.5)
		var mid := foot + Vector3.UP * float(post["height"]) * 0.5
		var inward: Vector2 = ((_island_of(at)["at"] as Vector2) - at).normalized()
		var eye := mid + Vector3(inward.x, 0.0, inward.y) * EYE_GAP
		var aim: Dictionary = Augments.grapple_target(space, eye, mid - eye, eye, reach, 0.0)
		var axis := INF
		if aim.has("point"):
			var p: Vector3 = aim["point"]
			axis = Vector2(p.x - at.x, p.z - at.y).length()
		if aim.get("state") != Augments.AIM_REACH or axis > AXIS_TOLERANCE:
			bad.append("%s state %s, %.2f m off axis" % [str(at), str(aim.get("state")), axis])
	_t.check("(e) harpoon bites every post (rope_range %.0f)" % reach, bad.is_empty(), str(bad))


# (c) Barge BARGE steps once per physics frame over one period, read the way world.gd
# steps it; the body shows a placement a physics tick after it is made.
func _step_barge() -> void:
	_barge_ticks -= 1
	var spec: Dictionary = _contraptions.barges[BARGE]["spec"]
	var a: Vector3 = spec["a"]
	var b: Vector3 = spec["b"]
	var at: Vector3 = _contraptions.barge_position(BARGE)
	if _stepped:
		_to_a = minf(_to_a, at.distance_to(a))
		_to_b = minf(_to_b, at.distance_to(b))
		_off_lane = maxf(_off_lane, at.distance_to(Geometry3D.get_closest_point_to_segment(at, a, b)))
		if _last != Vector3.INF:
			var speed := at.distance_to(_last) * _hz
			if not (speed <= _speed):
				_speed = speed
		_last = at
	_stepped = true
	_contraptions.step(1.0 / _hz, Vector3(0.0, -1000.0, 0.0), Vector3.ZERO, null, false)
	if _barge_ticks > 0:
		return
	var period := 2.0 * (float(spec["travel"]) + float(spec["dwell"]))
	_t.check("(c) %s reaches a and b on its lane over one period" % spec["id"],
		_to_a < LANE_TOLERANCE and _to_b < LANE_TOLERANCE and _off_lane < LANE_TOLERANCE,
		"period %.1f s: closest to a %.4f m, to b %.4f m, off lane %.4f m" % [period, _to_a, _to_b, _off_lane])
	_t.check("(c) %s peak speed rideable" % spec["id"], _speed <= MAX_BARGE_SPEED,
		"peak %.2f m/s (limit %.1f)" % [_speed, MAX_BARGE_SPEED])


func _accel(facts: Array) -> float:
	var up := 0.0
	for f in facts:
		if f["kind"] == "accel":
			up += (f["accel"] as Vector3).y
	return up


# (d) thermal_c lifts only a gliding ball inside its column, at contraptions' THERMAL_LIFT.
func _check_thermal() -> void:
	var column: Dictionary = {}
	for t in _contraptions.thermals:
		if t["spec"]["id"] == "thermal_c":
			column = t
	if column.is_empty():
		_t.check("(d) thermal_c built", false, "no thermal_c")
		return
	var base: Vector3 = column["base"]
	var dt := 1.0 / _hz
	var kit := GlidingKit.new()
	var inside := base + Vector3.UP * RIDE_START
	var lift: Array = _contraptions.step(dt, inside, Vector3.ZERO, kit, false).filter(func(f): return f["kind"] == "accel")
	_t.check("(d) gliding inside thermal_c yields one accel fact of 34", lift.size() == 1 and (lift[0]["accel"] as Vector3).y == 34.0, str(lift))
	var idle := GlidingKit.new()
	idle.gliding = false
	_t.eq("(d) not gliding: no lift", _accel(_contraptions.step(dt, inside, Vector3.ZERO, idle, false)), 0.0)
	var outside := inside + Vector3.RIGHT * (float(column["spec"]["radius"]) + 1.0)
	_t.eq("(d) outside the radius: no lift", _accel(_contraptions.step(dt, outside, Vector3.ZERO, kit, false)), 0.0)
	var y := inside.y
	var vy := 0.0
	for i in int(RIDE_SECONDS * _hz):
		var up := _accel(_contraptions.step(dt, Vector3(base.x, y, base.z), Vector3(0.0, vy, 0.0), kit, false))
		vy += (up - GRAVITY) * dt
		y += vy * dt
	_t.check("(d) %.0f s gliding in thermal_c gains height" % RIDE_SECONDS, y - inside.y > RIDE_GAIN,
		"gain %.2f m (need > %.0f), top of column %.1f" % [y - inside.y, RIDE_GAIN, base.y + float(column["spec"]["height"])])


func _physics_process(_delta: float) -> bool:
	_ticks += 1
	# Contraptions read global positions, which exist once the scene is in the tree.
	if _ticks == 1:
		_contraptions = Contraptions.new()
		_terrain.geometry_root(1).add_child(_contraptions)
		_contraptions.setup(_map, _terrain.ground_callable(1), 14.0, GRAVITY)
		_check_built()
		_check_harpoon()
		if _contraptions.barges.size() <= BARGE:
			return _finish()
		var spec: Dictionary = _contraptions.barges[BARGE]["spec"]
		_barge_ticks = int(2.0 * (float(spec["travel"]) + float(spec["dwell"])) * _hz) + 2
	_step_barge()
	if _barge_ticks > 0:
		return false
	_check_thermal()
	return _finish()


func _finish() -> bool:
	_scene.free()
	quit(_t.verdict())
	return true
