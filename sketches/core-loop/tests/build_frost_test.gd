extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# The element x material table in the world. The test registers a patch of water 3 m
# deep over the flat top shelf through the build's register_material() seam (the same
# one the world can use), then checks:
#   control   with no ice, a ball rolled over the water sinks to the ground under it;
#   ice       frost on the water makes StaticBody3D slabs, and the same ball rolls on
#             them at the water's surface;
#   overlap   ice formed where the ball already sits forms under it, never inside it;
#   dash      with Frost Vane, a real air dash over the water leaves ice behind;
#   electrify arc on water strikes an enemy standing in it;
#   shatter   arc on ice bursts it;
#   melt      slabs leave when their window ends.

const LANE_X := -62.0
const LANE_FROM := -92.0
const LANE_TO := -62.0
const WATER_CENTRE := Vector2(-62.0, -77.0)
const WATER_RADIUS := 26.0
const DEPTH := 3.0
const ROLL_SPEED := 12.0
const ROLL_TICKS := 60

var _game
var _build
var _source := Intent.Scripted.new()
var _failures := 0
var _ticks := 0
var _phase := "boot"
var _wait := 0
var _surface := 0.0
var _ground_top := 0.0
var _control := {}
var _ice := {}
var _dashes := 0
var _arc_hits := 0
var _overlap := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _water(point: Vector3) -> Dictionary:
	if Vector2(point.x - WATER_CENTRE.x, point.z - WATER_CENTRE.y).length() <= WATER_RADIUS:
		return {"surface_y": _surface}
	return {}


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks > 90 * 30:
		_report("timeout", false, "stalled in phase %s" % _phase)
		return _finish()
	_wait += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = _source
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_build = _game.ctx.get_meta("build")
			_game.events.dashed.connect(func(_d: Vector3): _dashes += 1)
			_game.events.enemy_struck.connect(func(_e: Node3D, kind: String, _f: float):
				if kind == "arc":
					_arc_hits += 1)
			_next("settle")
		"settle":
			if _wait == 10:
				_setup_water()
				_roll_from_lane_start()
				_control = {"start_z": _game.player.ball_position().z, "min_y": 999.0}
				_next("control")
		"control":
			_control["min_y"] = minf(_control["min_y"], _game.player.ball_position().y)
			if _wait == ROLL_TICKS:
				_check_control()
				_lay_ice()
				_roll_from_lane_start()
				_ice = {"start_z": _game.player.ball_position().z, "min_y": 999.0}
				_next("ice")
		"ice":
			if _wait > 10:
				_ice["min_y"] = minf(_ice["min_y"], _game.player.ball_position().y)
			if _wait == ROLL_TICKS:
				_check_ice()
				_build.field.clear()
				_source.hold = {}
				var at: Vector3 = _game.ctx.terrain.drop_point(LANE_X, -80.0, 1.05)
				_game.player.reset_to(at)
				_game.player.body().global_position = at
				_next("sink")
		"sink":
			if _wait == 30:
				_check_overlap_start()
				_next("overlap")
		"overlap":
			if _wait == 15:
				_check_overlap_end()
				_start_dash()
				_next("dash_arm")
		"dash_arm":
			if _wait == 3:
				_source.press = {"boost_pressed": true}
				_next("dash")
		"dash":
			if _wait == 40:
				_check_dash()
				_start_electrify()
				_next("electrify")
		"electrify":
			if _wait == 50:
				_check_electrify()
				_check_shatter()
				_check_melt()
				return _finish()
	return false


func _next(phase: String) -> void:
	_phase = phase
	_wait = 0


func _setup_water() -> void:
	var terrain = _game.ctx.terrain
	_ground_top = -INF
	for i in 13:
		var z := lerpf(LANE_FROM - 6.0, LANE_TO + 6.0, i / 12.0)
		_ground_top = maxf(_ground_top, terrain.height(LANE_X, z))
	_surface = _ground_top + DEPTH
	_build.register_material("water", _water)


func _roll_from_lane_start() -> void:
	var at := Vector3(LANE_X, _surface + 1.4, LANE_FROM)
	_game.player.reset_to(at, Vector3(0.0, 0.0, ROLL_SPEED))
	_game.player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, 1.0))
	_source.hold = {"move": Vector2(0.0, 1.0)}


func _check_control() -> void:
	_report("control sinks", _control["min_y"] < _surface - 1.0,
		"no ice: over water surfaced at %.2f m the ball sank to %.2f m (ground under it tops out at %.2f m)"
			% [_surface, _control["min_y"], _ground_top])


func _lay_ice() -> void:
	var made := 0
	var tries := 0
	var z := LANE_FROM - 3.0
	while z <= LANE_TO + 3.0:
		var result: Dictionary = _build.apply_element("frost", Vector3(LANE_X, _surface + 1.0, z), "test")
		tries += 1
		if result.get("behaviour", "") == "create_surface":
			made += 1
		z += 3.0
	var bodies := 0
	for slab in _build.field.slabs():
		var body: StaticBody3D = slab["body"]
		if body is StaticBody3D and body.get_collision_layer_value(1) and is_equal_approx(slab["top"], _surface):
			bodies += 1
	_ice["made"] = made
	# Frost that lands on ice already made meets ice, not water, and the table has no
	# frost x ice row, so slabs never stack: they land about one radius apart.
	_report("frost makes ice", made >= 6 and made < tries and bodies == _build.field.slab_count(),
		"frost x water every 3 m along the lane made %d slabs from %d applications (frost on ice does nothing); %d are StaticBody3D on the world layer with their top at the water surface"
			% [made, tries, bodies])


func _check_ice() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var travelled: float = ball.z - _ice["start_z"]
	var speed: float = _game.player.planar_velocity().length()
	_report("ball rolls on ice", _ice["min_y"] > _surface + 0.8 and travelled > 5.0 and speed > 6.0,
		"on the ice the ball stayed at or above %.2f m (surface %.2f m, radius 1), rolled %.1f m and kept %.1f m/s"
			% [_ice["min_y"], _surface, travelled, speed])


# The ball rests on the ground; the water is set 0.3 m above its centre, so a slab at
# the surface would form through it.
func _check_overlap_start() -> void:
	var ball: Vector3 = _game.player.ball_position()
	_surface = ball.y + 0.3
	var result: Dictionary = _build.apply_element("frost", ball, "test")
	_overlap = {"y": ball.y, "top": result.get("top", INF)}


func _check_overlap_end() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var bottom: float = _overlap["y"] - 1.0
	_report("ice never forms in the ball", _overlap["top"] <= bottom and absf(ball.y - _overlap["y"]) < 0.15,
		"water 0.3 m over the ball's centre: the slab formed with its top at %.2f m under the ball's bottom %.2f m; the ball moved %.3f m"
			% [_overlap["top"], bottom, absf(ball.y - _overlap["y"])])
	_build.field.clear()
	_surface = _ground_top + DEPTH


func _start_dash() -> void:
	_game.run.add_part("frost_vane", "test")
	var at := Vector3(LANE_X, _surface + 2.5, LANE_FROM + 4.0)
	_game.player.reset_to(at, Vector3(0.0, 0.0, 10.0))
	_game.player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, 1.0))
	_source.hold = {"move": Vector2(0.0, 1.0)}


func _check_dash() -> void:
	var slabs: int = _build.field.slab_count()
	_report("frost vane dash freezes", _dashes >= 1 and slabs >= 2,
		"Frost Vane air dash over the water (%d dash published) left %d ice slabs behind" % [_dashes, slabs])


func _start_electrify() -> void:
	_source.hold = {}
	var far: Vector3 = _game.ctx.terrain.drop_point(LANE_X + 40.0, -120.0, 1.05)
	_game.player.reset_to(far)
	_game.player.body().global_position = far
	_build.field.clear()
	var spot: Vector3 = _game.ctx.terrain.drop_point(LANE_X, -70.0, 2.4)
	_game.ctx.spawner.spawn_enemy("chaser", spot)
	_arc_hits = 0
	var result: Dictionary = _build.apply_element("arc", Vector3(spot.x, _surface + 1.0, spot.z), "test")
	_overlap["zone"] = result.get("behaviour", "")


func _check_electrify() -> void:
	_report("arc electrifies water", _overlap["zone"] == "electrify" and _arc_hits >= 1,
		"arc x water resolved to %s; an enemy standing in it took %d arc hits in 0.55 s" % [_overlap["zone"], _arc_hits])


func _check_shatter() -> void:
	_build.apply_element("frost", Vector3(LANE_X, _surface + 1.0, -84.0), "test")
	var before: int = _build.field.slab_count()
	var result: Dictionary = _build.apply_element("arc", Vector3(LANE_X, _surface + 1.0, -84.0), "test")
	_report("arc shatters ice", result.get("behaviour", "") == "shatter" and result.get("shattered", 0) >= 1
			and _build.field.slab_count() < before,
		"arc x ice resolved to %s, shattering %d slab(s): %d before, %d after"
			% [result.get("behaviour", "nothing"), result.get("shattered", 0), before, _build.field.slab_count()])


func _check_melt() -> void:
	_build.apply_element("frost", Vector3(LANE_X, _surface + 1.0, -70.0), "test")
	var before: int = _build.field.slab_count()
	_build.field.step(10.0)
	_report("ice melts", before >= 1 and _build.field.slab_count() == 0,
		"%d slab(s) before the 9 s window ended, %d after" % [before, _build.field.slab_count()])


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _finish() -> bool:
	print("build_frost_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
