extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

const PLATE_RADIUS := 3.6
const LEAD := 0.9
const TILT := 0.35
const FLING_UP := 30.0
const FLING_SIDE := 22.0
const RIDE_UP := 9.0
const RIDE_KICK := 4.0
const RIDE_TIER := SpeedTier.FAST
const HP := 45.0

const PRIMARY_WARN := 1.0
const DOUBLE_SNAP_WARN := 0.65
const DOUBLE_SNAP_LEAD := 0.55
const DOUBLE_SNAP_JUMP_GRACE := 0.25
const DOUBLE_SNAP_RIDE_UP := 15.0
const TURBO_UP := 13.0
const TURBO_KICK := 12.0

const DEPLOY_S := 0.14
const KICK_S := 0.09
const FOLD_S := 0.18

var flings := 0
var rides := 0
var double_snaps := 0
var turbo_launches := 0
var _plate: MeshInstance3D
var _side := Vector3.RIGHT
var _kicker_dir := Vector3.FORWARD
var _fold_t := 0.0
var _double_snap := false
var _ratchet_sparked := false
var _turbo_used := false
var _jump_bus: Node

static var _shared: Dictionary = {}


func setup(target_ref, terrain_ref, root_ref, live_ref: Callable, threat: float, spec_ref := {}) -> void:
	super(target_ref, terrain_ref, root_ref, live_ref, threat, spec_ref)
	_jump_bus = world_root.get_node_or_null("GameEvents") if world_root != null else null
	if _jump_bus != null and not _jump_bus.jumped.is_connected(_on_player_jumped):
		_jump_bus.jumped.connect(_on_player_jumped)


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = PRIMARY_WARN
	live_seconds = TILT + 0.05
	rest_seconds = 3.0
	attack_range = 26.0


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		var body := MeshInstance3D.new()
		body.name = "RampBody"
		body.mesh = parts["body"]
		body.set_surface_override_material(parts["flash"], _material)
		_visual_parent().add_child(body)
	_plate = MeshInstance3D.new()
	if parts.is_empty():
		var craft = load("res://src/presentation/craft/enemy_boss_craft.gd")
		_plate.name = "RampPlate"
		_plate.mesh = craft.ramp_flipper_plate(Vector3(PLATE_RADIUS * 1.6, 0.18, PLATE_RADIUS * 1.6))
		_plate.material_override = PaletteMaterials.hazard_stripe()
	else:
		_plate.name = "RampPlate"
		_plate.mesh = parts["plate"]
	_plate.position = Vector3(0.0, CREW_HALF + 0.4, -0.4)
	_plate.scale = Vector3.ONE * 0.4
	_visual_parent().add_child(_plate)


static var _warned_asset := false


static func reset_for_tests() -> void:
	_shared.clear()
	_warned_asset = false


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	if not ResourceLoader.exists("res://assets/models/world_one/enemy_ramp_flipper.glb"):
		return {}
	var packed := load("res://assets/models/world_one/enemy_ramp_flipper.glb") as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	painted.metallic = 0.22
	PaletteMaterials.surface_grain(painted)
	var body: Mesh = (scene.find_child("RampBody", true, false) as MeshInstance3D).mesh.duplicate()
	var plate: Mesh = (scene.find_child("RampPlate", true, false) as MeshInstance3D).mesh.duplicate()
	var flash := -1
	for i in body.get_surface_count():
		var surface_material := body.surface_get_material(i)
		if surface_material == null and not _warned_asset:
			_warned_asset = true
			push_warning("ramp_flipper: surface has no material; using default finish")
		if surface_material != null and surface_material.resource_name == "fleet_paint":
			flash = i
		body.surface_set_material(i, painted)
	for i in plate.get_surface_count():
		plate.surface_set_material(i, painted)
	if flash < 0:
		scene.free()
		if not _warned_asset:
			_warned_asset = true
			push_warning("ramp_flipper: fleet_paint missing; keeping greybox crew and plate")
		return {}
	_shared = {"body": body, "plate": plate, "flash": flash}
	scene.free()
	return _shared


func _approaching_fast(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not player.has_method("speed_tier") or int(player.speed_tier()) < RIDE_TIER:
		return false
	var vel: Vector3 = target.planar_velocity() if target != null and target.has_method("planar_velocity") else player.planar_velocity()
	if vel.length_squared() <= 1.0 or to_ball.length() <= PLATE_RADIUS * 1.5:
		return true
	var to_unit := Vector3(-to_ball.x, 0.0, -to_ball.z)
	return to_unit.length_squared() <= 0.01 or vel.normalized().dot(to_unit.normalized()) > 0.0


func _commit(_to_ball: Vector3) -> Node3D:
	_double_snap = _approaching_fast(_to_ball)
	warn_seconds = DOUBLE_SNAP_WARN if _double_snap else PRIMARY_WARN
	_ratchet_sparked = false
	_turbo_used = false
	var heading: Vector3 = target.planar_velocity()
	var aim: Vector3 = _ball() + heading * (DOUBLE_SNAP_LEAD if _double_snap else LEAD)
	_side = heading.cross(Vector3.UP).normalized() if heading.length() > 1.0 else Vector3.RIGHT
	if _strafe < 0.0:
		_side = -_side
	if heading.length() > 1.0:
		_kicker_dir = heading.normalized()
	elif _to_ball.length() > 0.1:
		_kicker_dir = Vector3(-_to_ball.x, 0.0, -_to_ball.z).normalized()
	else:
		_kicker_dir = Vector3.FORWARD
	if _double_snap:
		double_snaps += 1
	var ring := _commit_ring(Threat.Type.INSTANT, aim, PLATE_RADIUS, 2.0)
	ring.warn_seconds = warn_seconds
	_fold_t = 0.0
	_plate.top_level = true
	_plate.scale = Vector3.ONE
	_plate.global_position = ring.center + Vector3.UP * 0.1
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "slam_dust", _plate.global_position, 10)
	return ring


func _go_live() -> void:
	if world_root != null and is_inside_tree() and _plate != null:
		FxLibrary.burst(world_root, "brass_spark", _plate.global_position + Vector3.UP * 0.4, 10)
		FxLibrary.burst(world_root, "slam_dust", _plate.global_position, 8)
	if _turbo_used:
		broken_by = "jump"
		return
	var ring := telegraph()
	var player = _player()
	if ring == null or player == null:
		broken_by = "missed"
		return
	if _double_snap:
		var ball := _real_ball()
		var flat := Vector2(ball.x - ring.center.x, ball.z - ring.center.z).length()
		if flat > PLATE_RADIUS + 1.5:
			broken_by = "missed"
			return
		if ring.contains(ball) and player.state.on_floor():
			if int(player.speed_tier()) >= RIDE_TIER:
				rides += 1
				var step := get_physics_process_delta_time()
				if step > 0.0:
					var pvel: Vector3 = player.planar_velocity()
					var kick: Vector3 = pvel.normalized() * RIDE_KICK if pvel.length() > 0.5 else _kicker_dir * RIDE_KICK
					player.add_external_accel((Vector3.UP * DOUBLE_SNAP_RIDE_UP + kick) / step)
				if fleet != null:
					fleet.discover("flap_ride", ball)
			elif _catch(TILT):
				flings += 1
		return
	if not ring.contains(_real_ball()) or not player.state.on_floor():
		broken_by = "missed"
		return
	if player.speed_tier() >= RIDE_TIER:
		broken_by = "speed"
		_ride(player.planar_velocity().normalized() * RIDE_KICK)
		return
	if _catch(TILT):
		flings += 1


func _live(_delta: float) -> bool:
	if _turbo_used:
		return false
	if _double_snap and not _holding():
		return _t < TILT
	if not _holding():
		return false
	_pull(Vector3.UP * FLING_UP + _side * FLING_SIDE)
	return true


func _on_player_jumped(_air: bool) -> void:
	if not _double_snap or _turbo_used or _dead:
		return
	var ring := telegraph()
	if ring == null:
		return
	var ball := _real_ball()
	var flat := Vector2(ball.x - ring.center.x, ball.z - ring.center.z).length()
	if flat > PLATE_RADIUS + 1.5 or ball.y - ring.center.y > 4.5:
		return
	if phase == Phase.LIVE or (phase == Phase.WARN and _t >= warn_seconds - DOUBLE_SNAP_JUMP_GRACE):
		_turbo_launch()
		broken_by = "jump"


func _on_broken(method: String) -> void:
	if method == "jump":
		if _double_snap and not _turbo_used:
			_turbo_launch()
		elif not _double_snap:
			_ride(Vector3.ZERO)


func _turbo_launch() -> void:
	if _turbo_used:
		return
	_turbo_used = true
	turbo_launches += 1
	rides += 1
	var player = _player()
	if player != null:
		var vel: Vector3 = player.planar_velocity()
		var dir := vel.normalized() if vel.length() > 0.5 else _kicker_dir
		var cur_vel: Vector3 = player.state.velocity
		var cur_planar := Vector2(cur_vel.x, cur_vel.z).length()
		var cruise: float = player.tuning.f("cruise") if player.get("tuning") != null else 14.0
		var blazing_floor := cruise * SpeedTier.MULTIPLES[SpeedTier.BLAZING] + 0.5
		var target_speed := maxf(cur_planar + TURBO_KICK, blazing_floor)
		var launch_vel := Vector3(dir.x * target_speed, maxf(cur_vel.y, 0.0) + TURBO_UP, dir.z * target_speed)
		player.set_velocity_now(launch_vel, "launched")
		player.state.velocity = launch_vel
		player.state.tier = SpeedTier.BLAZING
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", _real_ball(), 16)
		FxLibrary.burst(world_root, "steam_puff", _plate.global_position if _plate != null else global_position, 10)
	if fleet != null:
		fleet.discover("flap_ride", _real_ball())


func _ride(kick: Vector3) -> void:
	rides += 1
	var step := get_physics_process_delta_time()
	if step > 0.0:
		_player().add_external_accel((Vector3.UP * RIDE_UP + kick) / step)
	if fleet != null:
		fleet.discover("flap_ride", _real_ball())


func _on_end() -> void:
	_double_snap = false
	_ratchet_sparked = false
	_turbo_used = false
	warn_seconds = PRIMARY_WARN
	if _plate != null:
		_plate.top_level = false
		_plate.position = Vector3(0.0, CREW_HALF + 0.4, -0.4)
		_plate.rotation = Vector3.ZERO
		_plate.scale = Vector3.ONE * 0.4
		_fold_t = FOLD_S if not Comfort.reduced_motion else 0.0


func _exit_tree() -> void:
	if is_instance_valid(_jump_bus) and _jump_bus.jumped.is_connected(_on_player_jumped):
		_jump_bus.jumped.disconnect(_on_player_jumped)
	super._exit_tree()


func _pose() -> void:
	if _plate == null:
		return
	if not _plate.top_level:
		if _fold_t > 0.0:
			_fold_t = maxf(0.0, _fold_t - get_physics_process_delta_time())
			var r := _fold_t / FOLD_S
			var eased := r * r
			_plate.position = Vector3(0.0, CREW_HALF + 0.4 + 0.35 * eased, -0.4 - 0.55 * eased)
			_plate.rotation = Vector3(-0.45 * eased, 0.0, 0.0)
			_plate.scale = Vector3.ONE * lerpf(0.4, 0.72, eased)
		return
	var tilt := 0.0
	if _double_snap:
		if phase == Phase.WARN:
			var d := clampf(_t / DEPLOY_S, 0.0, 1.0)
			var settle := 1.0 - pow(1.0 - d, 3.0)
			_plate.scale = Vector3.ONE * lerpf(0.65, 1.0, settle)
			var u := clampf(_t / maxf(warn_seconds, 0.001), 0.0, 1.0)
			if u < 0.45:
				var a := u / 0.45
				tilt = 0.26 * (a * a * (3.0 - 2.0 * a))
			elif u < 0.55:
				tilt = 0.26
			else:
				if not _ratchet_sparked and world_root != null and is_inside_tree():
					_ratchet_sparked = true
					FxLibrary.burst(world_root, "brass_spark", _plate.global_position + Vector3.UP * 0.3, 8)
				var b := (u - 0.55) / 0.45
				tilt = lerpf(0.26, 0.56, b * b * (3.0 - 2.0 * b))
		elif phase == Phase.LIVE:
			_plate.scale = Vector3.ONE
			var k := clampf(_t / KICK_S, 0.0, 1.0)
			tilt = lerpf(0.56, 0.92, 1.0 - pow(1.0 - k, 3.0))
		_plate.rotation = Vector3.ZERO
		_plate.rotate(_kicker_dir.cross(Vector3.UP).normalized() if _kicker_dir.length() > 0.1 else Vector3.RIGHT, tilt)
		return
	if phase == Phase.WARN:
		var d := clampf(_t / DEPLOY_S, 0.0, 1.0)
		var settle := 1.0 - pow(1.0 - d, 3.0)
		_plate.scale = Vector3.ONE * lerpf(0.65, 1.0, settle)
		var u := clampf(_t / warn_seconds, 0.0, 1.0)
		tilt = 0.28 * (u * u * (3.0 - 2.0 * u))
	elif phase == Phase.LIVE:
		_plate.scale = Vector3.ONE
		var k := clampf(_t / KICK_S, 0.0, 1.0)
		tilt = lerpf(0.28, 0.65, 1.0 - pow(1.0 - k, 3.0))
	_plate.rotation = Vector3(0.0, 0.0, 0.0)
	_plate.rotate(_side.cross(Vector3.UP).normalized() if _side.length() > 0.1 else Vector3.FORWARD, tilt)
