extends "res://src/combat/counter.gd"

const FIELD_RADIUS := 7.0
const DRIFT := 11.0
const DRIFT_HZ := 0.7
const HP := 40.0

var _aerial: MeshInstance3D
var _phase0 := 0.0
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 1.0
	warn_seconds = 1.0
	live_seconds = 3.0
	rest_seconds = 3.8
	attack_range = 20.0


func _build_tool() -> void:
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		for part in parts:
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
			if part.name == "GyroAerial":
				_aerial = mi
		return
	_aerial = MeshInstance3D.new()
	_aerial.name = "GyroAerialFallback"
	_aerial.mesh = preload("res://src/presentation/world23_chunk_craft.gd").get_gyro_jammer_chassis_mesh()
	_aerial.position = Vector3(0.0, CREW_HALF + 1.25, -0.2)
	_visual_parent().add_child(_aerial)


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_one/enemy_gyro_jammer.glb", "gyro_jammer")
	return _shared


func _commit(_to_ball: Vector3) -> Node3D:
	return _commit_ring(Threat.Type.INSTANT, _ball(), FIELD_RADIUS, 4.0)


func _go_live() -> void:
	# The drift phase comes from where the jammer stands, never from its runtime identity.
	var p := global_position
	_phase0 = fposmod(p.x * 0.37 + p.z * 0.61, TAU)


func _live(_delta: float) -> bool:
	var field := telegraph()
	if field == null:
		return false
	var player = _player()
	if not field.contains(_real_ball()):
		if _holding():
			_release("left")
		return true
	if not _holding() and not _catch():
		return true
	var v: Vector3 = player.planar_velocity()
	var across := v.cross(Vector3.UP).normalized() if v.length() > 1.0 else Vector3.RIGHT
	_pull(across * DRIFT * sin(_phase0 + _t * TAU * DRIFT_HZ))
	return true


func _pose() -> void:
	if _aerial != null:
		_aerial.rotation.y += 0.3 if phase == Phase.LIVE else 0.05
