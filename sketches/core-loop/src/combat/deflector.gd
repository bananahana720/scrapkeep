extends "res://src/combat/counter.gd"

const Augments := preload("res://src/movement/augments.gd")

const RESTITUTION := 0.9
const FACE_LENGTH := 6.0
const FACE_WIDTH := 5.0
const MIN_CLOSING := 3.0
const VAULT_WINDOW := 0.45
const VAULT_LIFT := 0.35
const HP := 60.0

var rebounds := 0
var vaults := 0
var last_vault_speed := 0.0
var _window := 0.0
var _rebound_v := Vector3.ZERO
var _dish: Node3D
var _wall: MeshInstance3D
var _body: MeshInstance3D
var _wall_full := Transform3D.IDENTITY
var _wall_rest := Transform3D.IDENTITY
var windup_pose_enabled := true
var body_cue_enabled := true
var _rim: MeshInstance3D
var _rim_material: StandardMaterial3D


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 2.0
	walk_speed = 2.6
	keep_near = 7.0
	keep_far = 20.0
	attack_range = 16.0
	warn_seconds = 0.9
	live_seconds = 2.6
	rest_seconds = 2.5


static var _warned_asset := false
static var _shared: Dictionary = {}


func _build_tool() -> void:
	_crew.free()
	_crew = null
	var parts := _parts()
	_dish = Node3D.new()
	_dish.name = "DeflectorBody"
	_visual_parent().add_child(_dish)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = parts["body"]
	_body.set_surface_override_material(parts["flash"], _material)
	_dish.add_child(_body)
	_wall = MeshInstance3D.new()
	_wall.name = "DishWall"
	_wall.mesh = parts["wall"]
	_dish.add_child(_wall)
	_wall_full = parts["wall_transform"]
	_build_rim(parts["wall"])
	_wall_rest = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(35.0), deg_to_rad(-12.0))),
		_wall_full.origin + Vector3(0.6, 0.55, -0.15))
	_pose()


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_deflector.glb") as PackedScene).instantiate()
	var painted := PaletteMaterials.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	preload("res://src/presentation/craft/craft_lookdev.gd").enrich_standard_pbr(painted, 0.34, 0.35)
	var flash := 0
	var mesh: Mesh = (scene.find_child("DeflectorBody", true, false) as MeshInstance3D).mesh.duplicate()
	for i in mesh.get_surface_count():
		var surface_material := mesh.surface_get_material(i)
		if surface_material == null and not _warned_asset:
			_warned_asset = true
			push_warning("deflector: surface has no material; using default finish")
		if surface_material != null and surface_material.resource_name == "fleet_paint":
			flash = i
		mesh.surface_set_material(i, painted)
	var wall := scene.find_child("DishWall", true, false) as MeshInstance3D
	var wall_mesh: Mesh = wall.mesh.duplicate()
	for i in wall_mesh.get_surface_count():
		wall_mesh.surface_set_material(i, painted)
	_shared = {"body": mesh, "flash": flash, "wall": wall_mesh, "wall_transform": wall.transform}
	scene.free()
	return _shared


func _pose() -> void:
	var progress := 0.0
	if windup_pose_enabled and not _dead and not is_queued_for_deletion():
		if phase == Phase.WARN:
			progress = clampf(_warn_progress(), 0.0, 1.0)
		elif phase == Phase.LIVE:
			progress = 1.0
	var travel := smoothstep(0.0, 1.0, progress)
	_wall.transform = _wall_rest.interpolate_with(_wall_full, travel)
	_body.transform = Transform3D(Basis.from_scale(Vector3(1.0, lerpf(1.0, 0.85, travel), 1.0)),
		Vector3(0.0, -0.165 * travel, 0.0))
	_paint_rim()


func vault_open() -> bool:
	return phase == Phase.LIVE and _rebound_v != Vector3.ZERO and _window > 0.0 and not _dead


func vault_anchor() -> Vector3:
	if not body_cue_enabled or not vault_open() or not is_instance_valid(_wall):
		return Vector3.INF
	return _wall.global_position


func rim_visible() -> bool:
	return is_instance_valid(_rim) and _rim.is_inside_tree()


func vault_rim_color() -> Color:
	return _rim_material.emission


func _build_rim(wall_mesh: Mesh) -> void:
	var box := wall_mesh.get_aabb()
	var sizes := [box.size.x, box.size.y, box.size.z]
	var thin := sizes.find(sizes.min())
	var normal := Vector3.ZERO
	normal[thin] = 1.0
	var craft := preload("res://src/presentation/world23_chunk_craft.gd")
	var radius := 0.5 * float(sizes.max())
	_rim_material = preload("res://src/presentation/craft/craft_lookdev.gd").make_weathered_pbr(
		EventKinds.state_color("will_break"), 0.36, 0.42,
		EventKinds.state_color("will_break"), PLATE_GLOW_LIVE, 0.5, 0.34
	)
	_rim = MeshInstance3D.new()
	_rim.name = "VaultRim"
	_rim.mesh = craft.get_deflector_vault_rim_mesh(maxf(radius - 0.06, 0.4), 0.12)
	_rim.material_override = _rim_material
	_rim.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), box.get_center())


func _paint_rim() -> void:
	if _rim == null:
		return
	var on := body_cue_enabled and vault_open()
	if not on:
		_rim_clock = 0.0
		if _rim.get_parent() != null:
			_wall.remove_child(_rim)
		return
	if _rim.get_parent() == null:
		_wall.add_child(_rim)
	_rim_clock += get_physics_process_delta_time()
	var swing := 1.0
	if _pulses():
		swing += PULSE_DEPTH * sin(TAU * PULSE_HZ * _rim_clock)
	_rim_material.emission = EventKinds.state_color("will_break")
	_rim_material.emission_energy_multiplier = PLATE_GLOW_LIVE * swing


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	var face := global_position + to_ball.normalized() * (CREW_RADIUS + 0.6)
	return _commit_lane(Threat.Type.LANE, face, to_ball, FACE_LENGTH, FACE_WIDTH, 2.5)


func _go_live() -> void:
	_window = 0.0
	if holds != null and not holds.ctx.events.jumped.is_connected(_on_jumped):
		holds.ctx.events.jumped.connect(_on_jumped)


func _live(delta: float) -> bool:
	var face := telegraph()
	if face == null:
		return false
	_window = maxf(0.0, _window - delta)
	if rebounds > 0 and _window <= 0.0 and _rebound_v != Vector3.ZERO:
		return false
	if _rebound_v != Vector3.ZERO:
		return true
	var player = _player()
	var ball := _real_ball()
	if not face.contains(ball):
		return true
	var v: Vector3 = player.state.velocity
	var normal: Vector3 = face.dir
	var into := v.dot(normal)
	if into > -MIN_CLOSING:
		return true
	var out := v - normal * into * (1.0 + RESTITUTION)
	var step := get_physics_process_delta_time()
	if not player.crowd_control(String(row["mechanic"]), (out - v) / step):
		return true
	rebounds += 1
	_rebound_v = out
	_window = VAULT_WINDOW
	return true


func _on_jumped(_air: bool) -> void:
	if _window <= 0.0 or _rebound_v == Vector3.ZERO or phase != Phase.LIVE:
		return
	_window = 0.0
	var player = _player()
	var flat := Vector3(_rebound_v.x, 0.0, _rebound_v.z)
	var speed := Augments.vault_exit(_rebound_v.length(), player.tuning.f("jump_speed"))
	var dir := (flat.normalized() + Vector3.UP * VAULT_LIFT).normalized() if flat.length() > 0.1 else Vector3.UP
	player.set_velocity_now(dir * speed)
	vaults += 1
	last_vault_speed = speed
	holds.gift_refund()
	holds.ctx.events.shield_vaulted.emit(player.ball_position(), speed)
	if fleet != null:
		fleet.discover("shield_vault", player.ball_position())


func _on_end() -> void:
	_rebound_v = Vector3.ZERO
	_window = 0.0


func _exit_tree() -> void:
	if is_instance_valid(_rim) and not _rim.is_inside_tree():
		_rim.free()
	if is_instance_valid(_wall) and not is_dead():
		_wall.transform = _wall_rest
		_body.transform = Transform3D.IDENTITY
	if holds != null and is_instance_valid(holds) and holds.ctx.events.jumped.is_connected(_on_jumped):
		holds.ctx.events.jumped.disconnect(_on_jumped)
	super._exit_tree()
