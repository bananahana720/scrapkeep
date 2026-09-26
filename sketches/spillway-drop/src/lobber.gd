extends CharacterBody3D

const Materials := preload("res://src/materials.gd")

const GRAVITY := 26.0
const SHOT_RANGE := 75.0
const CYCLE := 3.6
const TELEGRAPH := 1.3
const FLIGHT := 1.9

# The lobber never moves. Its whole job is to make standing still expensive, so
# it telegraphs long and leads the shot by a fixed flight time.
signal hit_player(amount: float)
signal died(at: Vector3, scrap_value: int)
signal fired(origin: Vector3, launch_velocity: Vector3)

var target
var hp := 26.0
var max_hp := 26.0
var scrap_value := 4

var _clock := 0.0
var _knock := Vector3.ZERO
var _material: StandardMaterial3D
var _muzzle: MeshInstance3D
var _muzzle_material: StandardMaterial3D


func setup(target_ref, health: float, scrap: int) -> void:
	target = target_ref
	hp = health
	max_hp = health
	scrap_value = scrap
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 4.0, 2.4)
	shape.shape = box
	add_child(shape)

	_material = Materials.solid(Materials.VERDIGRIS)
	var mesh := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(2.4, 4.0, 2.4)
	mesh.mesh = body
	mesh.material_override = _material
	add_child(mesh)

	_muzzle_material = Materials.solid(Materials.AMBER, 0.2)
	_muzzle = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.9
	bulb.height = 1.8
	_muzzle.mesh = bulb
	_muzzle.material_override = _muzzle_material
	_muzzle.position = Vector3.UP * 2.6
	add_child(_muzzle)


func knock(_direction: Vector3, _force: float) -> void:
	pass


func flash() -> void:
	_muzzle_material.emission_energy_multiplier = 4.0


func take_damage(amount: float) -> void:
	hp -= amount
	flash()
	if hp <= 0.0:
		died.emit(global_position, scrap_value)
		queue_free()


func muzzle_point() -> Vector3:
	return global_position + Vector3.UP * 2.6


# Fixed flight time turns the arc into one solve instead of an iterative aim.
static func lob_velocity(from: Vector3, to: Vector3, flight: float) -> Vector3:
	var v := (to - from) / flight
	v.y += 0.5 * GRAVITY * flight
	return v


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	velocity = Vector3.ZERO
	if target == null:
		return
	var to_target: Vector3 = target.ball_position() - global_position
	if to_target.length() > SHOT_RANGE:
		_clock = 0.0
		_muzzle_material.emission_energy_multiplier = 0.2
		_muzzle.scale = Vector3.ONE
		return

	_clock += delta
	var charge := clampf((_clock - (CYCLE - TELEGRAPH)) / TELEGRAPH, 0.0, 1.0)
	_muzzle_material.emission_energy_multiplier = 0.2 + charge * 5.0
	_muzzle.scale = Vector3.ONE * (1.0 + charge * 0.9)
	if _clock < CYCLE:
		return
	_clock = 0.0
	_muzzle.scale = Vector3.ONE
	var origin := muzzle_point()
	var aim: Vector3 = target.ball_position() + target.state.velocity * FLIGHT * 0.5
	fired.emit(origin, lob_velocity(origin, aim, FLIGHT))
