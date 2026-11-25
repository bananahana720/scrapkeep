extends "res://src/combat/counter.gd"

const FxLibrary := preload("res://src/presentation/fx_library.gd")

# The swatter (DESIGN-V2 section 15.4): a crew figure behind a long low paddle arm. The
# warning is a wedge swept by the paddle, low (PADDLE_REACH), so a jump clears it. When
# it fills the paddle swings: a ball the wedge contains is batted along the sweep, a
# hard sideways knock that throws it off its line but never slows it, and for BAT
# seconds the knock owns the ball. Boost inside that time and you ride it: the knock
# becomes your speed, with the break refund. The paddle never damages; its punishment
# is the line it takes from you, usually into its pack.

const SWEEP_RADIUS := 7.5
const SWEEP_HALF_DEG := 55.0
const PADDLE_REACH := 1.6
const BAT := 0.35
const KNOCK := 16.0
const HP := 45.0

const SWING_S := 0.09
const RETURN_S := 0.28

var swats := 0
var _paddle: Node3D
var _sweep_dir := Vector3.RIGHT
var _swung := false
var _return_t := 0.0
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.6
	walk_speed = 4.2
	keep_near = 3.0
	keep_far = 26.0
	attack_range = 7.0
	warn_seconds = 0.8
	live_seconds = BAT + 0.05
	rest_seconds = 2.4


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.mesh = part.mesh
			mi.transform = part.xform
			_visual_parent().add_child(mi)
			if part.paddle:
				mi.name = "SwatterPaddle"
				_paddle = mi
			else:
				mi.name = "SwatterBody"
				# A body mesh with no fleet_paint surface keeps its own finish (F012).
				if part.body >= 0:
					mi.set_surface_override_material(part.body, _material)
		return
	_paddle = Node3D.new()
	_paddle.position = Vector3(0.0, -CREW_HALF + 0.5, 0.0)
	_visual_parent().add_child(_paddle)
	_box(Vector3(0.2, 0.2, 5.5), Palette.CHARCOAL, Vector3(0.0, 0.0, 2.9), 0.0, _paddle)
	_box(Vector3(0.3, 1.0, 1.6), Palette.RUST.darkened(0.2), Vector3(0.0, 0.2, 5.4), 0.0, _paddle)
	_box(Vector3(0.32, 0.18, 1.62), Palette.HAZARD, Vector3(0.0, 0.62, 5.4), 0.6, _paddle)


static var _warned_asset := false


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var path := ModelVariants.path("res://assets/models/world_one/enemy_swatter.glb")
	if not ResourceLoader.exists(path):
		return _shared
	var packed := load(path) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := -1
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("swatter: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"mesh": mesh, "xform": mi.transform, "body": body, "paddle": mi.name.begins_with("SwatterPaddle")})
	scene.free()
	return _shared


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	_swung = false
	_return_t = 0.0
	var heading := to_ball.normalized() if to_ball.length() > 0.1 else Vector3.FORWARD
	_sweep_dir = heading.cross(Vector3.UP) * (1.0 if _strafe > 0.0 else -1.0)
	_clear_telegraph()
	_telegraph = Telegraph.wedge(world_root, terrain, Threat.Type.INSTANT, global_position, heading, SWEEP_RADIUS, SWEEP_HALF_DEG, PADDLE_REACH)
	return _telegraph


func _go_live() -> void:
	_swung = true
	swats += 1
	if world_root != null and is_inside_tree():
		var tip := _paddle.to_global(Vector3(0.0, 0.3, 3.2)) if is_instance_valid(_paddle) else global_position + _sweep_dir * 2.5 + Vector3.UP * 0.9
		FxLibrary.burst(world_root, "brass_spark", tip, 10)
		FxLibrary.burst(world_root, "steam_puff", tip, 5)
	var wedge := telegraph()
	if wedge == null or not wedge.contains(_real_ball()):
		broken_by = "missed"
		return
	var step := get_physics_process_delta_time()
	_catch(BAT, _sweep_dir * KNOCK / step)


func _on_end() -> void:
	_return_t = RETURN_S if EnemyMotion.motion_scale > 0.0 else 0.0


func _on_broken(method: String) -> void:
	if method == "boost" and fleet != null:
		fleet.discover("paddle_ride", _real_ball())


func _live(_delta: float) -> bool:
	return _holding()


func _pose() -> void:
	if _paddle == null:
		return
	var swing := 0.0
	if phase == Phase.WARN:
		var u := clampf(_t / warn_seconds, 0.0, 1.0)
		swing = -0.65 * (u * u * (3.0 - 2.0 * u))
	elif phase == Phase.LIVE:
		var u := clampf(_t / SWING_S, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - u, 3.0)
		swing = lerpf(-0.65, 1.25, eased)
	elif _return_t > 0.0:
		_return_t = maxf(0.0, _return_t - get_physics_process_delta_time())
		var r := _return_t / RETURN_S
		swing = 1.25 * (r * r) * cos((1.0 - r) * PI * 0.65 * EnemyMotion.motion_scale)
	_paddle.rotation.y = swing * (1.0 if _strafe > 0.0 else -1.0)
