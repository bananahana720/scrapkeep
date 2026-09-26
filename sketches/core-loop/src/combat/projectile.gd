extends Node3D

const Palette := preload("res://src/core/palette.gd")

const GRAVITY := 26.0
const DAMAGE := 12.0
const HIT_RADIUS := 2.6
const LIFETIME := 7.0

signal hit_player(amount: float)

var target
var terrain
var velocity := Vector3.ZERO

var _age := 0.0


func setup(target_ref, terrain_ref, origin: Vector3, launch_velocity: Vector3) -> void:
	target = target_ref
	terrain = terrain_ref
	position = origin
	velocity = launch_velocity
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	mesh.mesh = sphere
	mesh.material_override = Palette.solid(Palette.AMBER, 3.0)
	add_child(mesh)
	var glow := OmniLight3D.new()
	glow.light_color = Palette.AMBER
	glow.omni_range = 12.0
	glow.light_energy = 2.5
	add_child(glow)


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	position += velocity * delta
	if target != null and position.distance_to(target.ball_position()) < HIT_RADIUS:
		hit_player.emit(DAMAGE)
		queue_free()
		return
	if _age > LIFETIME or position.y < terrain.height(position.x, position.z) - 1.0:
		queue_free()
