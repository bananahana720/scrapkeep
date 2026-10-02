extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Reach := preload("res://src/world/map_reach.gd")
const TraversalLine := preload("res://tools/traversal_line.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The slice table's Cable Reach (unit Z3): the built terrain has the marble extension, the
# berm and the kicker at the heights the layout sheet computed; every post and wall this map
# adds stands on its ground; a ball-sized sphere swept along each pilot's authored line meets
# nothing but Rivet's cracked wall; the marble run has no end cup; and the three-stage
# game's gorge is untouched.

const HEIGHT_TOLERANCE := 0.5
const FOOT_DEPTH := 1.5
const STEP_RISE := 0.3
const SWEEP_STEP := 1.0
const SIDE_SWEEP := 4.0
const POINTS := [
	{"at": Vector2(-62.1, -25.4), "h": 30.7, "what": "the marble's new last segment (the gorge gives 33.5)"},
	{"at": Vector2(-58.0, -10.0), "h": 28.2, "what": "the marble and tunnel w1 join"},
	{"at": Vector2(74.0, 86.0), "h": 3.4, "what": "the halfpipe's exit"},
	{"at": Vector2(68.0, 112.5), "h": 1.4, "what": "the berm face"},
	{"at": Vector2(74.0, 116.0), "h": 9.7, "what": "the berm crest"},
	{"at": Vector2(0.0, 86.0), "h": -2.2, "what": "the kicker lip"},
	{"at": Vector2(0.0, 134.0), "h": -8.0, "what": "the middle gate slot"},
	{"at": Vector2(-28.0, 134.0), "h": -6.55, "what": "the bay's cradle"},
	{"at": Vector2(0.0, -160.0), "h": 57.2, "what": "the spawn"},
]
const CHANNEL := [Vector2(-100.0, -54.0), Vector2(-78.0, -44.0), Vector2(-66.0, -30.0), Vector2(-58.0, -10.0), Vector2(-24.0, 20.0)]

var _t := T.new("reach_map_test")
var _game
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	if _ticks == 4:
		_game.flow.enter_stage(1, Vector3.ZERO, false)
		return false
	if _ticks < 12:
		return false
	_check_map()
	_check_heights()
	_check_footing()
	_check_channel()
	_check_lines()
	_check_marble_side()
	_game.free()
	quit(_t.verdict())
	return true


func _terrain():
	return _game.ctx.terrain


func _check_map() -> void:
	var map = _terrain().map()
	_t.check("slice map is the Reach", map.get_script() == Reach and map.title == "The Cable Reach",
		"active map script is the Reach: %s, title '%s'" % [map.get_script() == Reach, map.title])
	_t.check("cracked wall breaks at cruise here only", _wall_flag(map) and not _wall_flag(_terrain().map_for(1).get_script().new() if false else load("res://src/world/map_gorge.gd").new()),
		"Reach wall spec break_at_cruise %s, gorge's %s" % [_wall_flag(map), _wall_flag(load("res://src/world/map_gorge.gd").new())])


func _wall_flag(map) -> bool:
	for spec in map.contraptions:
		if spec["id"] == "cracked_wall":
			return spec.get("break_at_cruise", false)
	return false


func _check_heights() -> void:
	for p in POINTS:
		var at: Vector2 = p["at"]
		var h: float = _terrain().height(at.x, at.y)
		_t.check("height at %s" % at, absf(h - float(p["h"])) <= HEIGHT_TOLERANCE,
			"%s: built %.2f, sheet %.2f, within %.1f m" % [p["what"], h, p["h"], HEIGHT_TOLERANCE])


# Every post and wall the Reach adds: the collider's bottom is at or below the lowest ground
# under its footprint edge (nothing floats) and no more than 1.5 m below the highest ground
# there (nothing is buried). The kept landmark pieces are exempt.
func _check_footing() -> void:
	var posts := 0
	var walls := 0
	var bad := []
	var worst_gap := 0.0
	var worst_depth := 0.0
	for body in _terrain().geometry_root(1).get_children():
		if not body is StaticBody3D or body.name == "Ground":
			continue
		var shape: Shape3D = null
		for c in body.get_children():
			if c is CollisionShape3D:
				shape = c.shape
		var points: Array[Vector2] = []
		var bottom := 0.0
		if shape is CylinderShape3D and absf((shape as CylinderShape3D).radius - 0.9) < 0.001:
			posts += 1
			bottom = body.position.y - (shape as CylinderShape3D).height * 0.5
			for k in 8:
				points.append(Vector2(body.position.x, body.position.z) + Vector2.from_angle(TAU * k / 8.0) * 0.9)
		elif shape is BoxShape3D and absf((shape as BoxShape3D).size.z - 1.6) < 0.001 and absf((shape as BoxShape3D).size.y - 8.0) < 0.001:
			walls += 1
			var size: Vector3 = (shape as BoxShape3D).size
			bottom = body.position.y - size.y * 0.5
			for i in 12:
				for j in [-1.0, 1.0]:
					var local := Vector3(size.x * (float(i) / 11.0 - 0.5), 0.0, j * size.z * 0.5)
					var world: Vector3 = body.global_transform * local
					points.append(Vector2(world.x, world.z))
		else:
			continue
		points.append(Vector2(body.position.x, body.position.z))
		var low := INF
		var high := -INF
		for p in points:
			var g: float = _terrain().height(p.x, p.y)
			low = minf(low, g)
			high = maxf(high, g)
		worst_gap = maxf(worst_gap, bottom - low)
		worst_depth = maxf(worst_depth, high - bottom)
		if bottom > low + 0.0001 or high - bottom > FOOT_DEPTH:
			bad.append("%s at %s: bottom %.2f, ground %.2f to %.2f" % [body.name, body.position, bottom, low, high])
	_t.check("the Reach builds every post and wall", posts == Reach.POSTS.size() and walls == Reach.WALLS.size(),
		"%d posts of %d, %d walls of %d found" % [posts, Reach.POSTS.size(), walls, Reach.WALLS.size()])
	_t.check("posts and walls stand on their ground", bad.is_empty(),
		"worst float %.2f m, worst burial %.2f m (limit %.1f); offenders %s" % [worst_gap, worst_depth, FOOT_DEPTH, bad])


# The marble channel's last four points: no step of 1 m rises more than 0.3 m, so the end cup is gone.
func _check_channel() -> void:
	var worst := -INF
	var at := Vector2.ZERO
	for k in range(CHANNEL.size() - 1):
		var a: Vector2 = CHANNEL[k]
		var b: Vector2 = CHANNEL[k + 1]
		var steps := ceili(a.distance_to(b) / 1.0)
		var last: float = _terrain().height(a.x, a.y)
		for i in range(1, steps + 1):
			var p := a.lerp(b, float(i) / steps)
			var h: float = _terrain().height(p.x, p.y)
			if h - last > worst:
				worst = h - last
				at = p
			last = h
	_t.check("the marble channel has no end cup", worst <= STEP_RISE,
		"largest rise in a 1 m step along the last four marble points is %.3f m at %s (limit %.1f)" % [worst, at, STEP_RISE])


func _ground_rid() -> RID:
	var ground: Node = _terrain().geometry_root(1).get_node_or_null("Ground")
	return ground.get_rid() if ground != null else RID()


# Every static body a ball-sized sphere overlaps at p (the terrain's own body excluded), as
# {"name", "owner"}: the owner is the node that holds the body, the stage's geometry root for
# a map prop, "Contraptions" for the wall, anything else for an interactable device.
func _hits(p: Vector2, lateral := 0.0, along := Vector2.ZERO) -> Array:
	var at := p
	if lateral != 0.0:
		var side := Vector2(-along.y, along.x).normalized()
		at = p + side * lateral
	var h: float = _terrain().height(at.x, at.y)
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.exclude = [_ground_rid()]
	query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, h + Tuning.RADIUS + 0.05, at.y))
	var names := []
	for hit in _game.get_world_3d().direct_space_state.intersect_shape(query, 8):
		var body = instance_from_id(hit["collider_id"])
		names.append({"name": String(body.name), "owner": String(body.get_parent().name), "at": (body as Node3D).global_position})
	return names


func _is_prop(hit: Dictionary) -> bool:
	return hit["owner"] in ["Stage1", "Contraptions"]


# Each pilot's authored line, swept at 1 m steps. A map prop or contraption on it fails the
# check, Rivet's cracked wall excepted. An interactable device is another unit's (the
# interactables table), so it is printed as a note and not counted.
func _check_lines() -> void:
	var routes := TraversalLine.load_routes()
	var devices := {}
	for pilot in TraversalLine.PILOTS:
		var line := TraversalLine.route_of(routes, pilot)
		var found := {}
		var length := 0.0
		var wall_seen := false
		for k in range(line.size() - 1):
			var a := line[k]
			var b := line[k + 1]
			length += a.distance_to(b)
			var steps := ceili(a.distance_to(b) / SWEEP_STEP)
			for i in range(steps + 1):
				var p := a.lerp(b, float(i) / steps)
				for hit in _hits(p):
					if not _is_prop(hit):
						devices["%s %s" % [hit["owner"], hit["at"]]] = pilot
					elif hit["name"] == "cracked_wall" and pilot == "rivet":
						wall_seen = true
					else:
						found[hit["name"]] = p
		_t.check("%s's line is clear of props" % pilot, line.size() >= 2 and found.is_empty(),
			"%d waypoints, %.0f m swept at %.0f m steps: prop hits %s" % [line.size(), length, SWEEP_STEP, found])
		if pilot == "rivet":
			_t.check("the sweep sees the cracked wall on Rivet's line", wall_seen, "the one allowed hit, found by the sweep: %s" % wall_seen)
	print("NOTE interactable devices under the authored lines (not counted): %s" % [devices])


# The satellite tower stands 0.8 m outside a ball riding the channel wall top: sweep the
# marble's last segment 4 m to each side and name whatever it meets.
func _check_marble_side() -> void:
	var a: Vector2 = Reach.REACH_MARBLE[-2]
	var b: Vector2 = Reach.REACH_MARBLE[-1]
	var steps := ceili(a.distance_to(b) / SWEEP_STEP)
	var found := {}
	for side in [-SIDE_SWEEP, SIDE_SWEEP]:
		for i in range(steps + 1):
			var p := a.lerp(b, float(i) / steps)
			for hit in _hits(p, side, b - a):
				found[hit["name"]] = p
	_t.check("the marble's last segment is clear at 4 m to each side", found.is_empty(),
		"sphere swept along (%s)->(%s) offset %.0f m each way: hits %s" % [a, b, SIDE_SWEEP, found])
