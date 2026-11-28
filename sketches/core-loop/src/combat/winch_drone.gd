extends "res://src/combat/counter.gd"

const HOVER := 5.5
const CLIMB := 4.0
const LANE_LENGTH := 20.0
const LANE_WIDTH := 2.2
const PULL := 7.0
const WINCH := 1.8
const PACK_REACH := 30.0
const SNAP_SPEED := 19.0
const HP := 30.0

var winched := 0
var _rotor: MeshInstance3D
var _drum: MeshInstance3D
var _aim: Node3D
var _rotor_rest := Transform3D.IDENTITY
var _drum_rest := Transform3D.IDENTITY
var _pose_phase := Phase.ROAM
var _spin := Vector2.ZERO
var _coast_from := Vector2.ZERO
var _aim_angle := 0.0
var _level_from := 0.0
var windup_pose_enabled := true
const IDLE_SPIN := 4.0
var _idle_from := 0
var _spin_base := 0.0
var _recovering := false


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 4
	weight = 0.8
	walk_speed = 5.0
	keep_near = 8.0
	keep_far = 22.0
	attack_range = 18.0
	warn_seconds = 1.0
	live_seconds = WINCH + 0.1
	rest_seconds = 3.5
	row = row.duplicate()
	row["breaks"] = (row["breaks"] as Array) + ["speed"]


static var _warned_asset := false
static var _shared: Array = []


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var dressing := Node3D.new()
	dressing.name = "WinchBody"
	_aim = dressing
	_visual_parent().add_child(dressing)
	for part in _parts():
		var mi := MeshInstance3D.new()
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.rotor:
			mi.name = "WinchRotor"
			_rotor = mi
			_rotor_rest = mi.transform
			dressing.add_child(mi)
		elif part.drum:
			mi.name = "WinchDrum"
			_drum = mi
			_drum_rest = mi.transform
			dressing.add_child(mi)
		else:
			mi.name = "Body"
			mi.set_surface_override_material(part.body, _material)
			dressing.add_child(mi)


static func _parts() -> Array:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_winch_drone.glb") as PackedScene).instantiate()
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh.duplicate()
		var body := 0
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("winch_drone: surface has no material; using default finish")
			if surface_material != null and surface_material.resource_name == "fleet_paint":
				body = i
			mesh.surface_set_material(i, painted)
		_shared.append({"mesh": mesh, "xform": mi.transform, "body": body, "rotor": mi.name.begins_with("WinchRotor"), "drum": mi.name.begins_with("WinchDrum")})
	scene.free()
	return _shared


func _wants_attack(to_ball: Vector3) -> bool:
	return to_ball.length() <= attack_range


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	return _commit_lane(Threat.Type.LANE, global_position, to_ball, LANE_LENGTH, LANE_WIDTH)


func _go_live() -> void:
	var lane := telegraph()
	if lane == null or not lane.contains(_real_ball()) or not _catch(WINCH, Vector3.ZERO, global_position):
		broken_by = "missed"
		return
	winched += 1


func _live(_delta: float) -> bool:
	if not _holding():
		return false
	if strain() >= 1.0:
		holds.snap(self, "speed")
		return false
	var to := pack_centre() - _real_ball()
	to.y = 0.0
	if to.length() > 1.5:
		_pull(to.normalized() * PULL)
	return true


func _on_broken(_method: String) -> void:
	if fleet != null:
		fleet.discover("cable_snap", _real_ball())


func strain() -> float:
	var player = _player()
	if player == null:
		return 0.0
	return clampf(player.planar_velocity().length() / SNAP_SPEED, 0.0, 1.0)


func pack_centre() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for enemy in get_tree().get_nodes_in_group(GROUP):
		if enemy == self or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(global_position) <= PACK_REACH:
			sum += enemy.global_position
			count += 1
	return sum / count if count > 0 else global_position


func _move(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = desired
	var ground: float = terrain.height(global_position.x, global_position.z) if terrain != null else 0.0
	velocity = Vector3(horizontal.x, (ground + HOVER - global_position.y) * CLIMB, horizontal.z)
	move_and_slide()
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)


func _pose() -> void:
	if _aim == null:
		return
	if not windup_pose_enabled:
		_aim.transform = Transform3D.IDENTITY
		_rotor.transform = _rotor_rest
		_drum.transform = _drum_rest
		return
	if phase == Phase.WARN:
		if _pose_phase == Phase.ROAM:
			_spin_base = _spin.y if _recovering else _idle_angle()
		var progress := clampf(_warn_progress(), 0.0, 1.0)
		_aim_angle = deg_to_rad(32.0) * smoothstep(0.0, 1.0, progress)
		_spin = Vector2(2.25 * TAU * progress * progress, _spin_base + 3.25 * TAU * progress * progress)
	elif phase == Phase.LIVE:
		_aim_angle = deg_to_rad(32.0)
		_spin = Vector2(2.25 * TAU * (1.0 + 2.0 * _t / warn_seconds), _spin_base + 3.25 * TAU * (1.0 + 2.0 * _t / warn_seconds))
		_recovering = true
	else:
		if _pose_phase != Phase.ROAM:
			_coast_from = _spin
			_level_from = _aim_angle
			_recovering = true
		if _recovering:
			var recovery := clampf(_t / 0.25, 0.0, 1.0)
			_aim_angle = _level_from * (1.0 - smoothstep(0.0, 1.0, recovery))
			var stops := Vector2(ceilf(_coast_from.x / TAU), ceilf(_coast_from.y / TAU)) * TAU
			_spin = _coast_from.lerp(stops, 1.0 - pow(1.0 - recovery, 3.0))
			if recovery >= 1.0:
				_recovering = false
				_idle_from = Engine.get_physics_frames()
				_spin = Vector2.ZERO
		else:
			_aim_angle = 0.0
			_spin = Vector2(0.0, _idle_angle())
	_pose_phase = phase
	_aim.rotation.x = _aim_angle
	_drum.transform = _drum_rest * Transform3D(Basis(Vector3.RIGHT, _spin.x), Vector3.ZERO)
	_rotor.transform = _rotor_rest * Transform3D(Basis(Vector3.UP, _spin.y), Vector3.ZERO)


func _idle_angle() -> float:
	return fposmod(IDLE_SPIN * float(Engine.get_physics_frames() - _idle_from) * get_physics_process_delta_time(), TAU)
