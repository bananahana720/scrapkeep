extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")

const SPEED := 4.6
const GRAVITY := 26.0
const TOUCH_COOLDOWN := 0.85

signal hit_player(amount: float)
signal died(at: Vector3, scrap_value: int)

var target
var hp := 40.0
var max_hp := 40.0
var scrap_value := 3
var contact_damage := 9.0
var miniboss := false

var _radius := 1.0
var _knock := Vector3.ZERO
var _flash := 0.0
var _touch := 0.0
var _material: StandardMaterial3D
var _base_color := Palette.RUST


func setup(target_ref, health: float, body_scale: float, damage: float, scrap: int) -> void:
	target = target_ref
	hp = health
	max_hp = health
	contact_damage = damage
	scrap_value = scrap
	miniboss = body_scale > 1.6
	_radius = body_scale
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = _radius
	capsule.height = _radius * 3.0
	shape.shape = capsule
	add_child(shape)

	_base_color = Palette.COPPER if miniboss else Palette.RUST
	_material = Palette.solid(_base_color, 0.35 if miniboss else 0.0)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = _radius
	capsule_mesh.height = _radius * 3.0
	mesh.mesh = capsule_mesh
	mesh.material_override = _material
	add_child(mesh)


func knock(direction: Vector3, force: float) -> void:
	_knock = direction.normalized() * force / (2.2 if miniboss else 1.0)
	_knock.y = maxf(_knock.y, force * 0.2)


func flash() -> void:
	_flash = 1.0


func take_damage(amount: float) -> void:
	hp -= amount
	flash()
	if hp <= 0.0:
		died.emit(global_position, scrap_value)
		queue_free()


func _physics_process(delta: float) -> void:
	_touch = maxf(0.0, _touch - delta)
	var chase := Vector3.ZERO
	if target != null:
		var to_target: Vector3 = target.ball_position() - global_position
		var reach: float = _radius + 1.6
		if Vector3(to_target.x, 0.0, to_target.z).length() < reach and absf(to_target.y) < reach * 2.0:
			if _touch <= 0.0:
				_touch = TOUCH_COOLDOWN
				hit_player.emit(contact_damage)
		to_target.y = 0.0
		if to_target.length() > _radius + 1.4:
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
		_material.emission = Palette.AMBER
		_material.emission_energy_multiplier = _flash * 2.0
	elif _material.emission_enabled and not miniboss:
		_material.emission_enabled = false
		_material.albedo_color = _base_color
