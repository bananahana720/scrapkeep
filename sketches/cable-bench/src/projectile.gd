extends Node3D

const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Layout := preload("res://src/layout.gd")

const GRAVITY := 26.0
const HIT_RADIUS := 2.6

var velocity := Vector3.ZERO
var damage := 12.0
var target
var run

var _life := 6.0
var _marker: MeshInstance3D


# Fired to arrive at `to` after exactly `flight` seconds, so the ground marker is
# the honest telegraph rather than a decoration near the answer.
func setup(from: Vector3, to: Vector3, flight: float, hit: float, target_ref, run_ref) -> void:
	global_position = from
	damage = hit
	target = target_ref
	run = run_ref
	velocity = (to - from) / flight + Vector3.UP * 0.5 * GRAVITY * flight
	_life = flight + 2.0

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 1.4
	mesh.mesh = sphere
	mesh.material_override = Materials.solid(Palette.AMBER, 2.2)
	add_child(mesh)

	_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = HIT_RADIUS
	disc.bottom_radius = HIT_RADIUS
	disc.height = 0.12
	_marker.mesh = disc
	var mat := Materials.solid(Palette.ARC, 1.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = Vector3(to.x, Layout.height(to.x, to.z) + 0.2, to.z)


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	_life -= delta
	if target != null and run != null and run.live():
		if global_position.distance_to(target.ball_position()) < HIT_RADIUS:
			run.damage(damage)
			queue_free()
			return
	if _life <= 0.0 or global_position.y < Layout.height(global_position.x, global_position.z) - 1.0:
		queue_free()
