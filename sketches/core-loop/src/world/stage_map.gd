extends RefCounted

const Palette := preload("res://src/core/palette.gd")

# One stage's shape as data plus a height function. The terrain builds the ground
# from sample(), and every other question (where you spawn, where the beacon stands,
# where an event's ring is, where the flood can rise) is answered from these fields,
# so the geometry and the events that use it cannot disagree.

var title := ""
var spawn := Vector2.ZERO
var heading := Vector3(0.0, 0.0, 1.0)
var beacon := Vector2.ZERO
var scrap_lines: Array = []
# The flood's bowl: centre (Vector2), radius, depth (m of water at full), plane_size
# (Vector2) and plane_centre (Vector2). Empty for a map with no basin.
var basin := {}
# Participatory event sites keyed by event id. Each holds what that event needs:
# "ring" (Vector2, the start ring), plus "route" (PackedVector2Array) for a surge run
# or a stampede, or "relay" (Vector2) for a hold.
var sites := {}
# Events this map carries whatever stage_defs' event_mix says: an event unique to a map.
var unique_events: Array[String] = []
# Where spawns and rescues stay: the playable floor inside the rim walls.
var play_rect := Rect2(-150.0, -150.0, 300.0, 300.0)


# [height, tint]. The tint is the ground's own reading of the feature it belongs to.
func sample(_x: float, _z: float) -> Array:
	return [0.0, Palette.SAND]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(_parent: Node3D, _ground: Callable) -> void:
	pass


static func box(parent: Node3D, size: Vector3, origin: Vector3, mat: Material, turn := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	body.rotation.y = turn
	var mesh := MeshInstance3D.new()
	var shape_mesh := BoxMesh.new()
	shape_mesh.size = size
	mesh.mesh = shape_mesh
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


static func cylinder(parent: Node3D, radius: float, height_m: float, origin: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = origin
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height_m
	mesh.mesh = cyl
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = radius
	cyl_shape.height = height_m
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)
	return body


# A grapple post: a tall copper mast with an amber cap, the movement colour, so a hook
# point reads as one from across the stage.
static func grapple_post(parent: Node3D, foot: Vector3, height_m: float) -> void:
	cylinder(parent, 0.9, height_m, foot + Vector3.UP * height_m * 0.5, Palette.solid(Palette.COPPER))
	var cap := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 1.4
	ball.height = 2.8
	cap.mesh = ball
	cap.material_override = Palette.solid(Palette.AMBER, 1.2)
	cap.position = foot + Vector3.UP * (height_m + 0.6)
	parent.add_child(cap)


# A pylon wall: a sheer concrete slab in the verdigris the ground uses for any face a
# pylon can bite, so the engineer can read a turret spot at a glance.
static func pylon_wall(parent: Node3D, foot: Vector3, length: float, height_m: float, turn: float) -> void:
	box(parent, Vector3(length, height_m, 1.6), foot + Vector3.UP * (height_m * 0.5 - 0.5),
		Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL), turn)
