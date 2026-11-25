extends "res://src/combat/counter.gd"

const SpeedTier := preload("res://src/movement/speed_tier.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

# The ramp-flipper (DESIGN-V2 section 15.4): a crew figure hauling a hinged floor plate.
# It drops the plate where the ball will roll and the warning is an instant ring over
# it; the plate is drawn tilting up over the warning, so the fling is shown before it
# happens. Live, a grounded ball on the plate is flung up and off its line, sideways,
# for TILT seconds. Jump while it tilts and you ride it as a ramp instead: the fling
# turns into lift along your own line, with the break refund.
# Flow (design-v3/SPILLWAY-ROSTER.md): in the Spillway it is a sluice flap, and speed is the
# other answer. A ball that reaches the plate at FAST tier or above is never caught: it rides
# the plate as a launch ramp along its own line, RIDE_UP lift plus a RIDE_KICK shove forward.

const PLATE_RADIUS := 3.6
const LEAD := 0.9
const TILT := 0.35
const FLING_UP := 30.0
const FLING_SIDE := 22.0
const RIDE_UP := 9.0
const RIDE_KICK := 4.0
const RIDE_TIER := SpeedTier.FAST
const HP := 45.0

const DEPLOY_S := 0.14
const KICK_S := 0.09
const FOLD_S := 0.18

var flings := 0
var rides := 0
var _plate: MeshInstance3D
var _side := Vector3.RIGHT
var _fold_t := 0.0

static var _shared: Dictionary = {}


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.2
	warn_seconds = 1.0
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
		var box := BoxMesh.new()
		box.size = Vector3(PLATE_RADIUS * 1.6, 0.18, PLATE_RADIUS * 1.6)
		_plate.mesh = box
		_plate.material_override = Palette.hazard_stripe()
	else:
		_plate.name = "RampPlate"
		_plate.mesh = parts["plate"]
	_plate.position = Vector3(0.0, CREW_HALF + 0.4, -0.4)
	_plate.scale = Vector3.ONE * 0.4
	_visual_parent().add_child(_plate)


static var _warned_asset := false


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	if not ResourceLoader.exists("res://assets/models/world_one/enemy_ramp_flipper.glb"):
		return {}
	var packed := load("res://assets/models/world_one/enemy_ramp_flipper.glb") as PackedScene
	if packed == null:
		return {}
	var scene := packed.instantiate()
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
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


func _commit(_to_ball: Vector3) -> Node3D:
	var aim: Vector3 = _ball() + target.planar_velocity() * LEAD
	var heading: Vector3 = target.planar_velocity()
	_side = heading.cross(Vector3.UP).normalized() if heading.length() > 1.0 else Vector3.RIGHT
	if _strafe < 0.0:
		_side = -_side
	var ring := _commit_ring(Threat.Type.INSTANT, aim, PLATE_RADIUS, 2.0)
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
	var ring := telegraph()
	var player = _player()
	if ring == null or not ring.contains(_real_ball()) or not player.state.on_floor():
		broken_by = "missed"
		return
	if player.speed_tier() >= RIDE_TIER:
		broken_by = "speed"
		_ride(player.planar_velocity().normalized() * RIDE_KICK)
		return
	if _catch(TILT):
		flings += 1


func _live(_delta: float) -> bool:
	if not _holding():
		return false
	_pull(Vector3.UP * FLING_UP + _side * FLING_SIDE)
	return true


func _on_broken(method: String) -> void:
	if method == "jump":
		_ride(Vector3.ZERO)


func _ride(kick: Vector3) -> void:
	rides += 1
	var step := get_physics_process_delta_time()
	if step > 0.0:
		_player().add_external_accel((Vector3.UP * RIDE_UP + kick) / step)
	if fleet != null:
		fleet.discover("flap_ride", _real_ball())


func _on_end() -> void:
	if _plate != null:
		_plate.top_level = false
		_plate.position = Vector3(0.0, CREW_HALF + 0.4, -0.4)
		_plate.rotation = Vector3.ZERO
		_plate.scale = Vector3.ONE * 0.4
		_fold_t = FOLD_S if EnemyMotion.motion_scale > 0.0 else 0.0


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
