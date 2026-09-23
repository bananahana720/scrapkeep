extends CharacterBody3D

const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Rules := preload("res://src/rules.gd")

const GRAVITY := 26.0
const CONTACT_COOLDOWN := 0.9

signal died(foe: Node3D, scrap_value: int)

# The ball-lab dummy plus the three things a stage loop needs: health, a scrap
# drop and the ability to hurt the player back.
var kind := "chaser"
var target
var run
var hp := 26.0
var hp_max := 26.0
var speed := 7.0
var contact_damage := 9.0
var scrap_value := 3
var body_radius := 1.0

var _knock := Vector3.ZERO
var _flash := 0.0
var _contact_clock := 0.0
var _material: StandardMaterial3D
var _base_color := Palette.RUST


func setup(foe_kind: String, target_ref, run_ref, tier: int) -> void:
	kind = foe_kind
	target = target_ref
	run = run_ref
	var spec: Dictionary = Rules.FOES[kind]
	hp_max = Rules.foe_health(kind, tier)
	hp = hp_max
	speed = float(spec["speed"])
	contact_damage = Rules.foe_contact_damage(kind, tier)
	scrap_value = int(spec["scrap"])
	var scale_factor := float(spec["scale"])
	body_radius = scale_factor
	_base_color = Palette.RUST if kind == "chaser" else Palette.VERDIGRIS
	if kind == "miniboss":
		_base_color = Palette.CHARCOAL.lerp(Palette.RUST, 0.55)

	add_to_group("foe")
	# The copied player ball looks for this group to decide a stomp or a ram.
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.0 * scale_factor
	capsule.height = 3.0 * scale_factor
	shape.shape = capsule
	add_child(shape)

	_material = Materials.solid(_base_color)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 1.0 * scale_factor
	capsule_mesh.height = 3.0 * scale_factor
	mesh.mesh = capsule_mesh
	mesh.material_override = _material
	add_child(mesh)


func knock(direction: Vector3, force: float) -> void:
	_knock = direction.normalized() * force
	_knock.y = maxf(_knock.y, force * 0.2)


func knock_velocity() -> Vector3:
	return _knock


func flash() -> void:
	_flash = 1.0


func take_damage(amount: float) -> void:
	if amount <= 0.0 or hp <= 0.0:
		return
	hp -= amount
	flash()
	if hp <= 0.0:
		died.emit(self, scrap_value)
		queue_free()


func _physics_process(delta: float) -> void:
	_contact_clock = maxf(0.0, _contact_clock - delta)
	var chase := Vector3.ZERO
	if target != null and speed > 0.0 and run != null and run.live():
		var to_target: Vector3 = target.ball_position() - global_position
		to_target.y = 0.0
		if to_target.length() > 1.5:
			chase = to_target.normalized() * speed
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

	_touch_player()
	_tick_flash(delta)


func _touch_player() -> void:
	if target == null or run == null or not run.live() or _contact_clock > 0.0:
		return
	var gap: float = global_position.distance_to(target.ball_position())
	if gap < body_radius + 1.5:
		_contact_clock = CONTACT_COOLDOWN
		run.damage(contact_damage)


func _tick_flash(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		_material.albedo_color = _base_color.lerp(Color(1.0, 1.0, 0.85), _flash)
		_material.emission_enabled = true
		_material.emission = Palette.AMBER
		_material.emission_energy_multiplier = _flash * 2.0
	elif _material.emission_enabled:
		_material.emission_enabled = false
		_material.albedo_color = _base_color
