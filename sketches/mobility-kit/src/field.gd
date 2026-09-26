extends RefCounted

const LabMaterials := preload("res://src/lab_materials.gd")

const HALF := 125.0
const STEP := 1.5625
const RUN_X := -62.0
const RUN_TOP_Z := -112.0
const RUN_BOT_Z := 8.0
const RUN_TOP_H := 34.0
const PIPE_END_Z := 62.0
const PAD_CENTER := Vector2(30.0, 60.0)
const BANK_CENTER := Vector2(56.0, -30.0)
const BENCH_CENTER := Vector2(30.0, 76.0)
const BENCH_TOP := 9.5
const BENCH_HALF := Vector2(13.0, 12.0)

const POST_HEIGHT := 26.0
const POST_SUNK := 3.0
const WALL_SIZE := Vector3(36.0, 34.0, 2.5)
const WALL_X := 78.0
const WALL_Z := [34.0, 46.0]

var spawn := Vector3.ZERO
var downhill_start := Vector3.ZERO
var enemy_spawns: Array[Vector3] = []
# Grapple targets the headless test can aim at, and the two magnet walls' stand-off
# points, so a test does not have to guess where the geometry ended up.
var grapple_anchors: Array[Vector3] = []
var cling_spots: Array[Vector3] = []


# The whole terrain is one continuous height field: features are blended into the
# base by weight instead of stitched from separate meshes, so there are no seams
# for a rolling sphere to catch on and every contact normal is meaningful.
static func height(x: float, z: float) -> float:
	var h := _base(x, z)
	var bank := _bank(x, z)
	h = lerpf(h, bank[0], bank[1])
	var pad_w := 1.0 - smoothstep(26.0, 52.0, Vector2(x, z).distance_to(PAD_CENTER))
	h = lerpf(h, 0.0, pad_w)
	var run := _corridor(x, z)
	h = lerpf(h, run[0], run[1])
	return h + _rim(x, z)


static func _base(x: float, z: float) -> float:
	var hills := 3.2 * sin(x * 0.045) * cos(z * 0.038) + 1.8 * sin((x + z) * 0.028) + 1.1 * cos(x * 0.09 - z * 0.05)
	var mountain := 30.0 * exp(-(pow(x - RUN_X, 2.0) / 4000.0 + pow(z - RUN_TOP_Z, 2.0) / 6000.0))
	return hills + mountain


static func _corridor(x: float, z: float) -> Array:
	var dx := x - RUN_X
	var adx := absf(dx)
	if adx > 46.0 or z > PIPE_END_Z + 16.0:
		return [0.0, 0.0]
	var centre: float
	if z <= RUN_TOP_Z:
		centre = RUN_TOP_H
	elif z >= RUN_BOT_Z:
		centre = 0.0
	else:
		centre = RUN_TOP_H * (1.0 - smoothstep(0.0, 1.0, (z - RUN_TOP_Z) / (RUN_BOT_Z - RUN_TOP_Z)))
	var pipe := clampf(inverse_lerp(-40.0, 4.0, z), 0.30, 1.0)
	var arc := minf(adx, 16.0)
	var cross := 20.0 - sqrt(400.0 - arc * arc)
	if adx > 16.0:
		cross += (adx - 16.0) * 0.8
	var weight := (1.0 - smoothstep(26.0, 44.0, adx)) * (1.0 - smoothstep(PIPE_END_Z, PIPE_END_Z + 14.0, z))
	return [centre + cross * pipe, weight]


static func _bank(x: float, z: float) -> Array:
	var d := Vector2(x, z).distance_to(BANK_CENTER)
	var weight := smoothstep(20.0, 30.0, d) * (1.0 - smoothstep(50.0, 62.0, d))
	if weight <= 0.0:
		return [0.0, 0.0]
	var t := clampf((d - 30.0) / 24.0, 0.0, 1.0)
	return [16.0 * t * t, weight]


static func _rim(x: float, z: float) -> float:
	return 14.0 * smoothstep(104.0, 124.0, maxf(absf(x), absf(z)))


static func drop_point(x: float, z: float, clearance := 1.6) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


func build(parent: Node3D) -> void:
	spawn = drop_point(RUN_X, -100.0, 2.5)
	downhill_start = drop_point(RUN_X, -78.0, 2.0)
	enemy_spawns = [
		drop_point(18.0, 30.0), drop_point(44.0, 34.0), drop_point(6.0, 52.0),
		drop_point(52.0, 58.0), drop_point(24.0, 14.0), drop_point(-8.0, 66.0),
	]
	_build_terrain(parent)
	_build_props(parent)
	_build_sky(parent)


func _build_terrain(parent: Node3D) -> void:
	var cells := int(round(2.0 * HALF / STEP))
	var side := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for j in side:
		var z := -HALF + j * STEP
		for i in side:
			heights[j * side + i] = height(-HALF + i * STEP, z)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(side * side)
	normals.resize(side * side)
	uvs.resize(side * side)
	for j in side:
		for i in side:
			var idx := j * side + i
			var x := -HALF + i * STEP
			var z := -HALF + j * STEP
			var y: float = heights[idx]
			verts[idx] = Vector3(x, y, z)
			uvs[idx] = Vector2(x, z) * 0.1
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < side - 1 else 0)]
			var back: float = heights[idx - (side if j > 0 else 0)]
			var front: float = heights[idx + (side if j < side - 1 else 0)]
			normals[idx] = Vector3(left - right, 2.0 * STEP, back - front).normalized()

	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var w := 0
	for j in cells:
		for i in cells:
			var a := j * side + i
			var b := a + 1
			var c := a + side
			var d := c + 1
			# Clockwise from above: Godot's front-face winding, and a trimesh collider
			# only collides on its front faces.
			indices[w] = a
			indices[w + 1] = b
			indices[w + 2] = c
			indices[w + 3] = b
			indices[w + 4] = d
			indices[w + 5] = c
			w += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = LabMaterials.ground_material()
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)


func _build_props(parent: Node3D) -> void:
	var ramp_mat := LabMaterials.striped(Color(0.85, 0.45, 0.20), Color(0.25, 0.14, 0.10))
	var bench_mat := LabMaterials.striped(Color(0.30, 0.55, 0.70), Color(0.16, 0.28, 0.38))
	var pillar_mat := LabMaterials.solid(Color(0.62, 0.62, 0.68))

	# Steep kicker aimed at the bench: clearing the gap needs roughly fast-tier speed.
	_add_box(parent, Vector3(15.0, 1.6, 19.0), _tilt(Vector3(30.0, 4.4, 45.0), Vector3.RIGHT, -34.0), ramp_mat)
	# Shallow kicker for long low launches across the pad.
	_add_box(parent, Vector3(14.0, 1.6, 22.0), _tilt(Vector3(-6.0, 2.3, 26.0), Vector3.RIGHT, -16.0), ramp_mat)

	_add_box(parent, Vector3(BENCH_HALF.x * 2.0, BENCH_TOP * 2.0, BENCH_HALF.y * 2.0),
		Transform3D(Basis.IDENTITY, Vector3(BENCH_CENTER.x, 0.0, BENCH_CENTER.y)), bench_mat)
	# The slow route: a 15 degree service ramp up the east face of the bench.
	_add_box(parent, Vector3(9.0, 1.4, 38.0), _tilt(Vector3(50.0, 4.6, 76.0), Vector3.RIGHT, -15.0), bench_mat)
	_add_box(parent, Vector3(12.0, 1.4, 9.0),
		Transform3D(Basis.IDENTITY, Vector3(48.0, BENCH_TOP - 0.7, 90.0)), bench_mat)

	for spot in [Vector2(2.0, 40.0), Vector2(14.0, 48.0), Vector2(26.0, 38.0),
			Vector2(38.0, 50.0), Vector2(48.0, 40.0), Vector2(10.0, 62.0), Vector2(56.0, 66.0)]:
		_add_pillar(parent, Vector3(spot.x, 0.0, spot.y), pillar_mat)

	_build_grapple_rig(parent)
	_build_magnet_walls(parent)


func _build_grapple_rig(parent: Node3D) -> void:
	var post_mat := LabMaterials.solid(Color(0.46, 0.42, 0.38))
	var cap_mat := LabMaterials.solid(Color(1.0, 0.72, 0.30), 1.4)
	# Four flank the halfpipe, two the bench gap, four the open pad and the turn.
	for spot in [Vector2(-84.0, 12.0), Vector2(-40.0, 12.0), Vector2(-84.0, 44.0), Vector2(-40.0, 44.0),
			Vector2(16.0, 58.0), Vector2(44.0, 58.0), Vector2(56.0, 20.0), Vector2(-20.0, 14.0),
			Vector2(46.0, 10.0), Vector2(4.0, 86.0)]:
		_add_post(parent, spot, post_mat, cap_mat)
	# One arch over the halfpipe, one over the kicker that aims at the bench gap.
	_add_arch(parent, Vector2(-84.0, 28.0), Vector2(-40.0, 28.0), post_mat, cap_mat)
	_add_arch(parent, Vector2(16.0, 46.0), Vector2(44.0, 46.0), post_mat, cap_mat)


func _add_post(parent: Node3D, spot: Vector2, post_mat: Material, cap_mat: Material) -> Vector3:
	var base := height(spot.x, spot.y) - POST_SUNK
	var body := StaticBody3D.new()
	body.position = Vector3(spot.x, base + POST_HEIGHT * 0.5, spot.y)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.7
	cyl.bottom_radius = 1.1
	cyl.height = POST_HEIGHT
	mesh.mesh = cyl
	mesh.material_override = post_mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.9
	cyl_shape.height = POST_HEIGHT
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	var cap := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.6
	cap.mesh = torus
	cap.material_override = cap_mat
	cap.position = Vector3(0.0, POST_HEIGHT * 0.5, 0.0)
	body.add_child(cap)
	parent.add_child(body)
	var top := Vector3(spot.x, base + POST_HEIGHT, spot.y)
	grapple_anchors.append(top)
	return top


func _add_arch(parent: Node3D, a: Vector2, b: Vector2, post_mat: Material, cap_mat: Material) -> void:
	var left := _add_post(parent, a, post_mat, cap_mat)
	var right := _add_post(parent, b, post_mat, cap_mat)
	var beam_y := minf(left.y, right.y) - 1.0
	var span := Vector2(b.x - a.x, b.y - a.y)
	var centre := Vector3((a.x + b.x) * 0.5, beam_y, (a.y + b.y) * 0.5)
	var length := span.length() + 2.0
	var xform := Transform3D(Basis(Vector3.UP, atan2(span.x, span.y) - PI * 0.5), centre)
	_add_box(parent, Vector3(length, 1.4, 2.0), xform, post_mat)
	grapple_anchors.append(centre)


func _build_magnet_walls(parent: Node3D) -> void:
	var wall_mat := LabMaterials.striped(Color(0.42, 0.34, 0.58), Color(0.22, 0.18, 0.32))
	for entry in WALL_Z:
		var z: float = entry
		var base: float = maxf(height(WALL_X - WALL_SIZE.x * 0.5, z), height(WALL_X + WALL_SIZE.x * 0.5, z)) - 8.0
		var centre := Vector3(WALL_X, base + WALL_SIZE.y * 0.5, z)
		_add_box(parent, WALL_SIZE, Transform3D(Basis.IDENTITY, centre), wall_mat)
		# 1.2 m off the face, inside the corridor, and high enough to ride down.
		var offset: float = (WALL_SIZE.z * 0.5 + 1.0 + 1.2) * (1.0 if z < WALL_Z[1] else -1.0)
		cling_spots.append(Vector3(WALL_X, base + 26.0, z + offset))


func _tilt(origin: Vector3, axis: Vector3, degrees: float) -> Transform3D:
	return Transform3D(Basis(axis, deg_to_rad(degrees)), origin)


func _add_box(parent: Node3D, size: Vector3, xform: Transform3D, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.transform = xform
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)


func _add_pillar(parent: Node3D, origin: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = origin + Vector3(0.0, 7.0, 0.0)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.8
	cyl.bottom_radius = 2.4
	cyl.height = 16.0
	mesh.mesh = cyl
	mesh.material_override = mat
	var shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 2.2
	cyl_shape.height = 16.0
	shape.shape = cyl_shape
	body.add_child(shape)
	body.add_child(mesh)
	parent.add_child(body)


func _build_sky(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.34, 0.60)
	sky_material.sky_horizon_color = Color(0.62, 0.68, 0.74)
	sky_material.ground_bottom_color = Color(0.14, 0.15, 0.18)
	sky_material.ground_horizon_color = Color(0.50, 0.52, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_density = 0.0012
	env.fog_light_color = Color(0.62, 0.68, 0.76)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -125.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	parent.add_child(sun)
