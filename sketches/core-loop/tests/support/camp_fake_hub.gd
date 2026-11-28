extends Node

# A stand-in for the camp hub's API (hub.root, piece, socket, add_station, ball, game) so the
# camp features run against the real GLB collision at 90 physics ticks with no Game. The ball
# is a plain RigidBody3D on layer 2 that mirrors the player ball's size, mass and gravity.

const CampRecords := preload("res://src/core/camp_records.gd")

signal walk_entered
signal walk_left

var root: Node3D
var ball
var game = null
var camp_records = CampRecords.new()
var pieces := {}
var stations: Array = []


class FakeBall:
	extends Node3D

	var rigid := RigidBody3D.new()

	func _init() -> void:
		rigid.mass = 6.0
		rigid.gravity_scale = 26.0 / 9.8
		rigid.continuous_cd = true
		rigid.collision_layer = 0
		rigid.set_collision_layer_value(2, true)
		rigid.collision_mask = 0
		rigid.set_collision_mask_value(1, true)
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.0
		shape.shape = sphere
		rigid.add_child(shape)
		var mat := PhysicsMaterial.new()
		mat.friction = 0.9
		mat.bounce = 0.25
		rigid.physics_material_override = mat
		rigid.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		rigid.angular_damp = 0.25
		rigid.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		rigid.linear_damp = 0.0
		add_child(rigid)

	func body() -> RigidBody3D:
		return rigid

	func reset_to(point: Vector3, velocity := Vector3.ZERO) -> void:
		rigid.global_position = point
		rigid.linear_velocity = velocity
		rigid.angular_velocity = Vector3.ZERO


func _init() -> void:
	root = Node3D.new()
	add_child(root)
	ball = FakeBall.new()
	root.add_child(ball)


# Loads res://assets/models/camp/<stem>.glb at a transform; its imported -col body is solid.
func place(stem: String, at: Vector3, yaw := 0.0) -> Node3D:
	var node: Node3D = load("res://assets/models/camp/%s.glb" % stem).instantiate()
	root.add_child(node)
	node.global_transform = Transform3D(Basis(Vector3.UP, yaw), at)
	pieces[stem] = node
	return node


func piece(id: String) -> Node3D:
	return pieces[id]


func socket(id: String, socket_name: String) -> Transform3D:
	var node := pieces[id].find_child(socket_name, true, false) as Node3D
	return node.global_transform


func add_station(id: String, at: Vector3, label: String, key: String, radius: float, on_press: Callable) -> void:
	stations.append({"id": id, "at": at, "label": label, "key": key, "radius": radius, "on_press": on_press})
