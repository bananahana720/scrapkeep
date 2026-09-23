extends CharacterBody3D

const LabMaterials := preload("res://src/lab_materials.gd")
const SPEED := 4.0
const GRAVITY := 26.0

var target

var _knock := Vector3.ZERO
var _flash := 0.0
var _material: StandardMaterial3D
var _base_color := Color(0.72, 0.28, 0.34)


func setup(target_ref) -> void:
	target = target_ref
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0
	capsule.height = 3.0
	shape.shape = capsule
	add_child(shape)
	_material = LabMaterials.solid(_base_color)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 1.0
	capsule_mesh.height = 3.0
	mesh.mesh = capsule_mesh
	mesh.material_override = _material
	add_child(mesh)


func knock(direction: Vector3, force: float) -> void:
	_knock = direction.normalized() * force
	_knock.y = maxf(_knock.y, force * 0.2)


func flash() -> void:
	_flash = 1.0


func _physics_process(delta: float) -> void:
	var chase := Vector3.ZERO
	if target != null:
		var to_target: Vector3 = target.ball_position() - global_position
		to_target.y = 0.0
		if to_target.length() > 2.5:
			chase = to_target.normalized() * SPEED
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = chase
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = _knock.y if _knock.y > 0.0 else velocity.y
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	_knock = _knock.move_toward(Vector3.ZERO, 16.0 * delta)

	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		_material.albedo_color = _base_color.lerp(Color(1.0, 1.0, 0.85), _flash)
		_material.emission_enabled = true
		_material.emission = Color(1.0, 0.9, 0.6)
		_material.emission_energy_multiplier = _flash * 2.0
	elif _material.emission_enabled:
		_material.emission_enabled = false
		_material.albedo_color = _base_color
