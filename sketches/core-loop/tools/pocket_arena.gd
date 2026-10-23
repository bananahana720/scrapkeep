extends RefCounted
# A lab pocket (tools/lab_pockets/<shape>.glb) stood up as the matchup lab's arena (--pocket=<shape>).
# The glb is loaded at runtime with GLTFDocument (the folder is .gdignore'd, as tests/lab_pockets_test.gd does),
# every mesh gets a trimesh collider, and meshes whose names start with `slick` get friction 0 (the crevice's choke
# walls). The pocket sits LIFT metres over the legacy map, so nothing of that map touches it; the legacy ground's
# collider is switched off by the lab.
#
# Frames: mojulo (x along travel, y lateral, z up) is Godot (x, z, -y); the entry is x = 0 in the pocket's own frame,
# so a pocket point (x, y_up, z) is at `origin + (x, y_up, z)` in the world.
#
# Height queries (`height`, which PocketTerrain answers `terrain.height` with) are a downward ray against the
# pocket's FLOOR class: every collider except the overhead ride structure (names starting with `rail` or `pillar`: the
# rail grove's rails, posts and pillars), because a ray from above would stand a walker on a rail. Those colliders
# still block bodies; they only leave the height question.

const DIR := "res://tools/lab_pockets/"
const SHAPES := ["half_pipe", "rolling_wall", "crevice", "hazard_field", "rail_grove"]
# The pocket's height over the legacy map's ground (the legacy ground collider is disabled too).
const LIFT := 300.0
# Physics layer bit 1 is the world layer the ball, enemies and the camera collide with; bit 20 marks the floor class
# for height rays only (nothing collides on it).
const WORLD_LAYER := 1
const HEIGHT_LAYER := 20
const OVERHEAD_PREFIXES := ["rail", "pillar"]
const SLICK_PREFIX := "slick"
# The pilot starts this far in from the entry, on the centre line, this far over the floor.
const START_X := 2.5
const START_LIFT := 1.6
# The pack stands this far short of the far end (x = length) at the first.
const FAR_MARGIN := 3.0
# A pack spot's floor may differ from the lane centre's by this much at the same station.
const PACK_FLAT_M := 0.3
# A ball this far past the pocket's footprint is out of the arena (flow rescues it back to the start).
const EDGE_SLACK := 4.0

var shape := ""
var origin := Vector3.ZERO
var root: Node3D
# The pocket's footprint in its own frame: x from min_x to max_x, lateral (Godot z) from min_z to max_z, y from min_y to max_y.
var bounds := AABB()
var rescues := 0
var slick_meshes: Array = []
var floor_meshes: Array = []
var overhead_meshes: Array = []
var _space: PhysicsDirectSpaceState3D = null


static func valid(name: String) -> bool:
	return name in SHAPES


# Loads the glb. Returns null when it will not import.
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


# Stands the pocket up under `parent` with its colliders. False when the glb will not load.
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


# A mesh's transform in the pocket's own frame: its chain below the glb root (the root itself is the placement).
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


# The lateral centre line (Godot z, pocket frame).
func lane_z() -> float:
	return bounds.position.z + bounds.size.z * 0.5


# World y of the ray's start and end: over the tallest point, under the lowest.
func _top() -> float:
	return origin.y + bounds.end.y + 2.0


func _bottom() -> float:
	return origin.y + bounds.position.y - 2.0


# A downward ray at world (x, z) against the floor class. Returns the hit point or Vector3.INF on a miss.
func floor_hit(x: float, z: float) -> Vector3:
	if _space == null:
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, _top(), z), Vector3(x, _bottom(), z), 1 << (HEIGHT_LAYER - 1))
	var hit := _space.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3.INF


# World height of the pocket's floor at (x, z); a miss (off the footprint, or a gap with no floor) reads the lowest
# floor point of the footprint, so a fall settles at the pocket's bottom rather than at the legacy map.
func height(x: float, z: float) -> float:
	var hit := floor_hit(x, z)
	return hit.y if hit != Vector3.INF else _bottom() + 2.0


func inside(point: Vector3) -> bool:
	var p := point - origin
	return p.x > bounds.position.x - EDGE_SLACK and p.x < bounds.end.x + EDGE_SLACK \
		and p.z > bounds.position.z - EDGE_SLACK and p.z < bounds.end.z + EDGE_SLACK


# Where the pilot's ball starts: the entry, on the lane, resting on the floor with the ball's clearance.
func start_point() -> Vector3:
	var x := origin.x + START_X
	var z := origin.z + lane_z()
	return Vector3(x, height(x, z) + START_LIFT, z)


# The pack's `count` spots on the far side, `spread` apart, as Director._place_pack lines them up. The line runs across
# the lane at the farthest station (from FAR_MARGIN short of the far end back to the half-way mark) where every spot
# stands on the lane's own floor (within PACK_FLAT_M of the lane centre): a half pipe's channel floor, the open floor
# of the rolling wall and the rail grove, clear of the hazard field's pits. Where no station is flat across (the
# crevice's 5 m slot is narrower than the line), the pack stands in file down the lane instead.
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
		# In file the last member holds the station and the rest stand back toward the entry.
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
