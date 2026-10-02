extends SceneTree

const Game := preload("res://src/game.gd")
const Reach := preload("res://src/world/map_reach.gd")
const Traversal := preload("res://tools/traversal_line.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")

const HEIGHTS := [Vector3(0.0, 57.23, -160.0), Vector3(-62.1, 30.7, -25.4), Vector3(-58.0, 28.2, -10.0),
	Vector3(74.0, 3.4, 86.0), Vector3(68.0, 1.4, 112.5), Vector3(74.0, 9.7, 116.0),
	Vector3(0.0, -2.2, 86.0), Vector3(0.0, -8.0, 134.0), Vector3(-28.0, -6.55, 134.0)]
const IDLE_SCALE := 8.0
const CHANNEL := [Vector2(-78.0, -44.0), Vector2(-66.0, -30.0), Vector2(-58.0, -10.0), Vector2(-24.0, 20.0)]

var _game
var _t := T.new("reach_map_test")
var _started := false
var _starts: Array = []
var _idle_ticks := 0
var _clock_start := 0.0


func _initialize() -> void:
	SimClock.ticks = true
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.flow.force_warden = true
		_game.player.source = Intent.Scripted.new()
		_game.events.event_started.connect(func(id: String): _starts.append(id))
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_check_map()
		_clock_start = _game.world.events.stage_time
		_game.player.body().freeze = true
		Engine.time_scale = IDLE_SCALE
		return false
	_idle_ticks += 1
	if _game.world.events.stage_time - _clock_start < 120.0 and _idle_ticks < int(121 * Engine.physics_ticks_per_second / IDLE_SCALE):
		return false
	_t.check("120 seconds idle publishes no timed starts", _starts.is_empty(), "starts %s" % [_starts])
	var elapsed: float = _game.world.events.stage_time - _clock_start
	_t.check("empty mix advances without stalling", elapsed >= 120.0 and elapsed <= 120.0 + IDLE_SCALE / Engine.physics_ticks_per_second + 0.001,
		"%.6f simulated seconds" % elapsed)
	Engine.time_scale = 1.0
	_game.free()
	quit(_t.verdict())
	return true


func _check_map() -> void:
	var terrain = _game.ctx.terrain
	var map = terrain.map()
	_t.eq("Reach script", map.get_script(), Reach)
	_t.eq("parent title retained", map.title, "The Cable Reach")
	_t.eq("extended marble path", map.marble_path.size(), 7)
	_t.eq("inherited surge site retained", map.sites["surge_run"]["ring"], Vector2(-44.0, -164.0))
	_t.eq("activity points published", map.activity_sites, {"ambush_altar": Vector2(-16.0, 44.0),
		"cracked_cache": Vector2(70.0, -4.0), "hauler_bounty": Vector2(0.0, -88.0)})
	for point in HEIGHTS:
		_t.near("built height at %.1f,%.1f" % [point.x, point.z], terrain.height(point.x, point.z), point.y, 0.5)
	_check_feet()
	_check_lines()
	var largest := 0.0
	for i in CHANNEL.size() - 1:
		var a: Vector2 = CHANNEL[i]
		var b: Vector2 = CHANNEL[i + 1]
		var steps := int(ceil(a.distance_to(b)))
		var last: float = terrain.height(a.x, a.y)
		for step in range(1, steps + 1):
			var p := a.lerp(b, float(step) / steps)
			var h: float = terrain.height(p.x, p.y)
			largest = maxf(largest, h - last)
			last = h
	_t.check("channel steps rise at most 0.3 m", largest <= 0.3, "largest rise %.4f m" % largest)
	_check_wall_rule()


func _check_feet() -> void:
	var holder: Node3D = _game.ctx.terrain.geometry_root(1)
	var count := 0
	for body in holder.get_children():
		if not body is StaticBody3D:
			continue
		var post := Reach.POSTS.any(func(p): return Vector2(body.position.x, body.position.z).distance_to(Vector2(p.x, p.z)) < 0.01)
		var wall := Vector2(body.position.x, body.position.z) in [Vector2(-58.0, -133.0), Vector2(52.0, 80.0)]
		if post or wall:
			_foot(body)
			count += 1
	_t.eq("all 15 posts and two pylon walls checked", count, 17)
	_foot(_game.world.contraptions[1].walls[0]["body"])


func _foot(body: StaticBody3D) -> void:
	var shape: CollisionShape3D = body.get_children().filter(func(node): return node is CollisionShape3D)[0]
	var edge: Array[Vector3] = []
	var bottom := 0.0
	if shape.shape is CylinderShape3D:
		bottom = body.global_position.y - shape.shape.height * 0.5
		for k in 72:
			var angle := TAU * k / 72.0
			edge.append(body.to_global(Vector3(cos(angle) * shape.shape.radius, 0.0, sin(angle) * shape.shape.radius)))
	else:
		var size: Vector3 = shape.shape.size
		bottom = body.global_position.y - size.y * 0.5
		for k in 45:
			var f := float(k) / 44.0
			for sign_value in [-1.0, 1.0]:
				edge.append(body.to_global(Vector3(lerpf(-size.x, size.x, f) * 0.5, 0.0, sign_value * size.z * 0.5)))
				edge.append(body.to_global(Vector3(sign_value * size.x * 0.5, 0.0, lerpf(-size.z, size.z, f) * 0.5)))
	var lowest := INF
	for at in edge:
		lowest = minf(lowest, _game.ctx.terrain.height(at.x, at.z))
	var depth := lowest - bottom
	_t.check("footprint footing at %.1f,%.1f" % [body.position.x, body.position.z], depth >= -0.001 and depth <= 1.5,
		"bottom %.4f lowest edge ground %.4f burial %.4f" % [bottom, lowest, depth])


func _check_lines() -> void:
	var routes := Traversal.load_routes()
	for pilot in Traversal.PILOTS:
		var points := Traversal.route_of(routes, pilot)
		var hits := _sweep(points, 0.0, pilot == "rivet")
		_t.check("%s authored line is clear" % pilot, hits.is_empty(), "%s" % [hits])
	for offset in [-4.0, 4.0]:
		var hits := _sweep([Vector2(-66.0, -30.0), Vector2(-58.0, -10.0)], offset, false)
		_t.check("marble last segment offset %.0f is clear" % offset, hits.is_empty(), "%s" % [hits])


func _sweep(points: Array, offset: float, allow_wall: bool) -> Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	q.shape = sphere
	q.collision_mask = 1
	var ground: StaticBody3D = _game.ctx.terrain.geometry_root(1).get_node("Ground")
	var excluded: Array[RID] = [ground.get_rid()]
	if allow_wall:
		excluded.append(_game.world.contraptions[1].walls[0]["body"].get_rid())
	q.exclude = excluded
	var space = _game.get_world_3d().direct_space_state
	var hits: Array = []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * offset
		var steps := int(ceil(a.distance_to(b)))
		for step in steps:
			var p := a.lerp(b, float(step) / steps) + side
			var next := a.lerp(b, float(step + 1) / steps) + side
			var from: Vector3 = _game.ctx.terrain.drop_point(p.x, p.y, Tuning.RADIUS + 0.05)
			var to: Vector3 = _game.ctx.terrain.drop_point(next.x, next.y, Tuning.RADIUS + 0.05)
			q.transform.origin = from
			q.motion = to - from
			var overlap: Array = space.intersect_shape(q, 8)
			var motion: PackedFloat32Array = space.cast_motion(q)
			if not overlap.is_empty() or motion[0] < 0.9999:
				hits.append({"at": from, "safe": motion[0], "bodies": overlap.map(func(hit): return str(hit["collider"].get_path()))})
	return hits


func _check_wall_rule() -> void:
	var props = _game.world.contraptions[1]
	var wall: Dictionary = props.walls[0]
	var ball: Vector3 = wall["body"].global_position
	var facts: Array = []
	props._step_wall(wall, ball, Vector3(0.0, 0.0, 13.99), null, facts)
	_t.check("Reach wall holds below cruise", not wall["broken"] and facts.is_empty())
	props._step_wall(wall, ball, Vector3(0.0, 0.0, 14.0), null, facts)
	_t.check("Reach wall breaks at cruise without sprint", wall["broken"] and facts.any(func(f): return f.get("fact") == "wall_crumbled"))
	props.reset()
