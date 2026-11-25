extends RefCounted

const DIR := "res://tools/lab_pockets/"
const SHAPES := ["half_pipe", "rolling_wall", "crevice", "hazard_field", "rail_grove"]
const LIFT := 300.0
const WORLD_LAYER := 1
const HEIGHT_LAYER := 20
const OVERHEAD_PREFIXES := ["rail", "pillar"]
const SLICK_PREFIX := "slick"
const START_X := 2.5
const START_LIFT := 1.6
const FAR_MARGIN := 3.0
const PACK_FLAT_M := 0.3
const EDGE_SLACK := 4.0

var shape := ""
var origin := Vector3.ZERO
var root: Node3D
var bounds := AABB()
var rescues := 0
var slick_meshes: Array = []
var floor_meshes: Array = []
var overhead_meshes: Array = []
var _space: PhysicsDirectSpaceState3D = null


static func valid(name: String) -> bool:
	return name in SHAPES


static func load_scene(name: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(DIR + name + ".glb", state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


static func is_overhead(mesh_name: String) -> bool:
	for prefix in OVERHEAD_PREFIXES:
		if mesh_name.begins_with(prefix):
			return true
	return false


static func is_slick(mesh_name: String) -> bool:
	return mesh_name.begins_with(SLICK_PREFIX)


func build(parent: Node3D, shape_name: String, at: Vector3) -> bool:
	var scene := load_scene(shape_name)
	if scene == null:
		return false
	shape = shape_name
	origin = at
	root = scene
	root.name = "LabPocket"
	parent.add_child(root)
	root.global_position = origin
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		var local := _local(mesh_instance)
		var box: AABB = local * mesh_instance.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.set_collision_layer_value(WORLD_LAYER, true)
		body.collision_mask = 0
		var overhead := is_overhead(String(mi.name))
		if not overhead:
			body.set_collision_layer_value(HEIGHT_LAYER, true)
		var collider := CollisionShape3D.new()
		collider.shape = mesh_instance.mesh.create_trimesh_shape()
		body.add_child(collider)
		if is_slick(String(mi.name)):
			var material := PhysicsMaterial.new()
			material.friction = 0.0
			body.physics_material_override = material
			body.set_meta("slick", true)
			slick_meshes.append(mi)
		(floor_meshes if not overhead else overhead_meshes).append(mi)
		mesh_instance.add_child(body)
	_space = root.get_world_3d().direct_space_state
	return true


func _local(node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf


func length() -> float:
	return bounds.end.x


func lane_z() -> float:
	return bounds.position.z + bounds.size.z * 0.5


func _top() -> float:
	return origin.y + bounds.end.y + 2.0


func _bottom() -> float:
	return origin.y + bounds.position.y - 2.0


func floor_hit(x: float, z: float) -> Vector3:
	if _space == null:
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, _top(), z), Vector3(x, _bottom(), z), 1 << (HEIGHT_LAYER - 1))
	var hit := _space.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3.INF


func height(x: float, z: float) -> float:
	var hit := floor_hit(x, z)
	return hit.y if hit != Vector3.INF else _bottom() + 2.0


func inside(point: Vector3) -> bool:
	var p := point - origin
	return p.x > bounds.position.x - EDGE_SLACK and p.x < bounds.end.x + EDGE_SLACK \
		and p.z > bounds.position.z - EDGE_SLACK and p.z < bounds.end.z + EDGE_SLACK


func start_point() -> Vector3:
	var x := origin.x + START_X
	var z := origin.z + lane_z()
	return Vector3(x, height(x, z) + START_LIFT, z)


func pack_spots(count: int, spread: float) -> Array:
	var x := length() - FAR_MARGIN
	while x >= length() * 0.5:
		var spots := _line(count, spread, origin.x + x, true)
		if _flat(spots, origin.x + x):
			return spots
		x -= 0.5
	return _line(count, spread, origin.x + length() - FAR_MARGIN, false)


func _line(count: int, spread: float, x: float, across: bool) -> Array:
	var out := []
	for i in count:
		var offset := spread * (float(i) - float(count - 1) * 0.5)
		var at_x := x if across else x - spread * float(count - 1 - i)
		var at_z := origin.z + lane_z() + (offset if across else 0.0)
		var hit := floor_hit(at_x, at_z)
		out.append(Vector3(at_x, hit.y if hit != Vector3.INF else height(at_x, at_z), at_z))
	return out


func _flat(spots: Array, x: float) -> bool:
	var centre := floor_hit(x, origin.z + lane_z())
	if centre == Vector3.INF:
		return false
	for spot in spots:
		if floor_hit(spot.x, spot.z) == Vector3.INF or absf(spot.y - centre.y) > PACK_FLAT_M:
			return false
	return true
