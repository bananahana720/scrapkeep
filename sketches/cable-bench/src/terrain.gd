extends RefCounted

const Layout := preload("res://src/layout.gd")
const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")


func build(parent: Node3D) -> void:
	_build_surface(parent)
	_build_kickers(parent)
	_build_rails(parent)
	_build_scrap_heap(parent)
	_build_sky(parent)


func _build_surface(parent: Node3D) -> void:
	var cells := int(round(2.0 * Layout.HALF / Layout.STEP))
	var side := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	for j in side:
		var z := -Layout.HALF + j * Layout.STEP
		for i in side:
			heights[j * side + i] = Layout.height(-Layout.HALF + i * Layout.STEP, z)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(side * side)
	normals.resize(side * side)
	uvs.resize(side * side)
	for j in side:
		for i in side:
			var idx := j * side + i
			var x := -Layout.HALF + i * Layout.STEP
			var z := -Layout.HALF + j * Layout.STEP
			verts[idx] = Vector3(x, heights[idx], z)
			uvs[idx] = Vector2(x, z) * 0.1
			var left: float = heights[idx - (1 if i > 0 else 0)]
			var right: float = heights[idx + (1 if i < side - 1 else 0)]
			var back: float = heights[idx - (side if j > 0 else 0)]
			var front: float = heights[idx + (side if j < side - 1 else 0)]
			normals[idx] = Vector3(left - right, 2.0 * Layout.STEP, back - front).normalized()

	var indices := PackedInt32Array()
	indices.resize(cells * cells * 6)
	var w := 0
	for j in cells:
		for i in cells:
			var a := j * side + i
			var b := a + 1
			var c := a + side
			var d := c + 1
			# Clockwise seen from above is Godot's front face, and a trimesh collider
			# only collides on front faces: get this backwards and the ball falls through.
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
	var mat := Materials.ground_material()
	mat.albedo_texture = Materials.checker_texture(Palette.SAND, Palette.SANDSTONE)
	view.material_override = mat
	var body := StaticBody3D.new()
	body.name = "Terrain"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.add_child(view)
	parent.add_child(body)


func _build_kickers(parent: Node3D) -> void:
	var mat := Materials.striped(Palette.RUST, Palette.CHARCOAL)
	for i in Layout.MESAS.size():
		_add_box(parent, Layout.KICKER_SIZE, Layout.kicker_transform(i), mat, "Kicker%d" % i)


func _build_rails(parent: Node3D) -> void:
	# Visual only: a rail that could catch the ball would ruin the straightaway.
	var mat := Materials.solid(Palette.VERDIGRIS)
	for sz in Layout.SIDING_Z:
		for offset in [-2.6, 2.6]:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(300.0, 0.25, 0.7)
			mesh.mesh = box
			mesh.material_override = mat
			var z: float = sz + offset
			mesh.position = Vector3(0.0, Layout.height(0.0, z) + 0.12, z)
			parent.add_child(mesh)


func _build_scrap_heap(parent: Node3D) -> void:
	# The secret: a horseshoe of wrecked plate with one gap, hiding a cache.
	var mat := Materials.striped(Palette.RUST, Palette.COPPER)
	var centre := Layout.SECRET
	var ground := Layout.height(centre.x, centre.y)
	var ring := [
		{"offset": Vector2(0.0, -11.0), "size": Vector3(24.0, 9.0, 4.0), "yaw": 0.0},
		{"offset": Vector2(-11.0, 0.0), "size": Vector3(4.0, 9.0, 22.0), "yaw": 0.0},
		{"offset": Vector2(11.0, 0.0), "size": Vector3(4.0, 9.0, 22.0), "yaw": 0.0},
		{"offset": Vector2(-7.5, 11.0), "size": Vector3(9.0, 9.0, 4.0), "yaw": 0.0},
		{"offset": Vector2(8.5, 11.0), "size": Vector3(7.0, 9.0, 4.0), "yaw": 0.0},
	]
	for piece in ring:
		var offset: Vector2 = piece["offset"]
		var size: Vector3 = piece["size"]
		var at := Vector3(centre.x + offset.x, ground + size.y * 0.35, centre.y + offset.y)
		_add_box(parent, size, Transform3D(Basis(Vector3.UP, float(piece["yaw"])), at), mat, "Heap")


func _add_box(parent: Node3D, size: Vector3, xform: Transform3D, mat: Material, name: String) -> void:
	var body := StaticBody3D.new()
	body.name = name
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


func _build_sky(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.26, 0.44)
	sky_material.sky_horizon_color = Palette.AMBER.lerp(Palette.SAND, 0.4)
	sky_material.ground_bottom_color = Palette.CHARCOAL
	sky_material.ground_horizon_color = Palette.SANDSTONE
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_light_color = Palette.SAND.lerp(Palette.VERDIGRIS, 0.35)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -118.0, 0.0)
	sun.light_energy = 1.15
	sun.light_color = Palette.SAND
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	parent.add_child(sun)
