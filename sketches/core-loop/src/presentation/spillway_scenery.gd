extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Spillway := preload("res://src/world/map_spillway.gd")

# Rim crown families (GEOMETRY.md section 3). L = 40 m is the old rim pitch. Variants are the
# broad crown (1.2L, +0.45L), the low saddle (0.9L, +0.15L) and the blunt headland (0.6L, +0.3L).
# Depth 16 m is the ceiling; the saddle and headland are shallower (chosen: 12 and 14 m).
# Chosen where the spec is open: 6 m joints between families (pitch 126 m, so three families
# span z -186..186), crown roots reach 5 m below the lowest sampled footprint terrain, and
# every sideways ring offset stays inside 1 to 3 m.
const RIM_WIDTH := [48.0, 36.0, 24.0]
const RIM_DEPTH := [16.0, 12.0, 14.0]
const RIM_ADD := [18.0, 6.0, 12.0]
const RIM_GULLY := 6.0
const RIM_FAMILY_PITCH := 126.0
const RIM_START_Z := -186.0
const RIM_WEST_X := -167.0
const RIM_EAST_X := 194.0
# Variant order per family, west then east, chosen so no two neighbouring crowns match in height.
const RIM_WEST_ORDER := [[0, 1, 2], [0, 2, 1], [2, 0, 1]]
const RIM_EAST_ORDER := [[2, 1, 0], [2, 0, 1], [0, 2, 1]]
# Six ring heights as a fraction of the crown add; ring 0 is the buried root, ring 1 the crest line h0.
const RIM_RING_Y := [0.0, 0.0, 0.34, 0.58, 0.82, 1.0]
# Alternate rings contract 15 to 17 percent, which cuts the ledge undersides (plan scale per ring).
const RIM_RING_SCALE := [1.0, 1.0, 0.85, 0.94, 0.83, 0.90]
# Sideways ring offsets in metres (depth axis, length axis), unequal per variant. Each ring leans a
# little further than the one below (1 to 3 m from the base), so a ledge lip stays under 3 m.
const RIM_RING_SHIFT := [
	[Vector2(0, 0), Vector2(0, 0), Vector2(1.0, -1.0), Vector2(1.6, -0.4), Vector2(2.2, -1.4), Vector2(1.4, -0.6)],
	[Vector2(0, 0), Vector2(0, 0), Vector2(-1.2, 1.2), Vector2(-0.6, 1.8), Vector2(-1.8, 1.0), Vector2(-1.0, 2.0)],
	[Vector2(0, 0), Vector2(0, 0), Vector2(1.4, 1.0), Vector2(0.8, 1.6), Vector2(2.0, 0.8), Vector2(1.2, 1.8)],
]
# Plan radius factors, 12, 10 and 11 perimeter points; unequal, none above 1.
const RIM_PLAN_FACTOR := [
	[1.0, 0.9, 0.97, 0.86, 1.0, 0.92, 0.88, 1.0, 0.94, 0.85, 0.98, 0.91],
	[0.96, 1.0, 0.86, 0.94, 0.9, 1.0, 0.88, 0.97, 0.92, 0.85],
	[1.0, 0.88, 0.95, 1.0, 0.86, 0.93, 0.9, 1.0, 0.87, 0.96, 0.92],
]
# Top-ring profile along the crest, x = position from -1 to 1, y = share of the add: a long
# slope, a blunt crest, then a short fracture face. Never below 0.6 so the rings stay ordered.
const RIM_CREST := [
	[Vector2(-1.0, 0.62), Vector2(0.30, 1.0), Vector2(0.55, 1.0), Vector2(0.68, 0.72), Vector2(1.0, 0.70)],
	[Vector2(-1.0, 0.72), Vector2(-0.2, 1.0), Vector2(0.15, 0.94), Vector2(0.70, 0.80), Vector2(1.0, 0.76)],
	[Vector2(-1.0, 0.65), Vector2(-0.5, 1.0), Vector2(0.20, 1.0), Vector2(0.40, 0.68), Vector2(1.0, 0.64)],
]

# All instances stay outside the stage-1 play rectangle plus an 8 m apron. No collisions.
static func build(stage_root: Node3D) -> Node3D:
	var scenery := Node3D.new()
	scenery.name = "SpillwayScenery"
	stage_root.add_child(scenery)
	var stone: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var recess: Array[Transform3D] = []
	var metal: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	var banners: Array[Transform3D] = []
	var masonry: Array[Transform3D] = []
	var water: Array[Transform3D] = []
	var pools: Array[Transform3D] = []
	var mist: Array[Transform3D] = []
	var cables: Array[Transform3D] = []
	var cabins: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var glyphs: Array[Transform3D] = []

	# A downstream retaining wall with three valve towers above the existing rim.
	_place(stone, Vector3(0, 70, 247), Vector3(270, 100, 22))
	_place(trim, Vector3(0, 122, 247), Vector3(282, 5, 28))
	for x in [-112.0, -84.0, -56.0, -28.0, 0.0, 28.0, 56.0, 84.0, 112.0]:
		_place(trim, Vector3(x, 71, 230), Vector3(8, 94, 12))
		_place(recess, Vector3(x + 11, 109, 235.5), Vector3(10, 13, 1))
		_place(stone, Vector3(x, 128, 247), Vector3(7, 8, 25))
	for x in [-90.0, 0.0, 90.0]:
		_place(stone, Vector3(x, 138, 247), Vector3(27, 35, 32))
		_place(trim, Vector3(x, 157, 247), Vector3(33, 4, 38))
		_place(stone, Vector3(x, 165, 247), Vector3(19, 12, 23))
		_place(metal, Vector3(x, 173, 247), Vector3(24, 4, 28))
		for dx in [-7.0, 0.0, 7.0]:
			_place(recess, Vector3(x + dx, 143, 230.5), Vector3(3, 12, 1))
		_place(metal, Vector3(x, 94, 224), Vector3(3, 40, 3))

	# Shallow block faces and lintels give the retaining wall scale in three batches.
	for row in 14:
		for col in 18:
			var x := -126.0 + col * 14.0 + (3.0 if row % 2 else 0.0)
			_place(masonry, Vector3(x, 29.0 + row * 6.4, 235.0), Vector3(13.5, 6.0, 0.45))
	for x in [-90.0, 0.0, 90.0]:
		_place(banners, Vector3(x + 12, 106, 228), Vector3(7, 26, 0.25))
		_place(metal, Vector3(x + 12, 120, 228), Vector3(11, 0.7, 1.0))
		for floor_index in 3:
			_place(trim, Vector3(x, 132 + floor_index * 10, 229), Vector3(28, 1.0, 2.0))

	# All water is behind the existing southern rim, never on a traversable shelf.
	for x in [-103.0, -47.0, 37.0, 93.0]:
		# Spill mist: a small cluster of irregular, feathered patches per fall. Sizes, offsets and
		# in-plane rolls vary from a fixed seed, so no row or grid reads; alpha stays at the cap.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(absf(x) * 31.0) + 7
		for j in 11:
			_place_mist(mist, Vector3(x + rng.randf_range(-15.0, 15.0), rng.randf_range(30.0, 42.0), 211.0 + rng.randf_range(0.0, 11.0)),
				Vector2(rng.randf_range(10.0, 22.0), rng.randf_range(6.0, 13.0)), rng.randf_range(-0.7, 0.7))
		# Ledge spray where the sheet strikes the visible dam face, above the rim line.
		for j in 8:
			_place_mist(mist, Vector3(x + rng.randf_range(-8.0, 8.0), rng.randf_range(38.0, 58.0), 222.0 + rng.randf_range(0.0, 3.0)),
				Vector2(rng.randf_range(8.0, 16.0), rng.randf_range(5.0, 11.0)), rng.randf_range(-1.0, 1.0))
	# G05: the four sheets and the tailrace are hand-broken meshes in world metres (water_edges.glb),
	# each inside the box it replaces, so they take one identity placement.
	_place(water, Vector3.ZERO, Vector3.ONE)
	_place(pools, Vector3.ZERO, Vector3.ONE)
	# Shingled shoulders are deliberately irregular; each exposed lip catches the key.
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			var h := 74.0 + 15.0 * sin(i * 1.8 + side)
			var x: float = side * (246.0 + 8.0 * sin(i * 2.1))
			for shelf in 4:
				var width := 36.0 - shelf * 4.0
				_place(rocks, Vector3(x + side * shelf * 5, h * 0.25 * shelf + 12, z), Vector3(width, h * 0.20, 32), i * 0.27)
			for j in 4:
				var foot := Vector3(x + side * 15 + j * 3, h * 0.75 + h * 0.18 + 12, z - 15 + j * 7)
				var size := 0.6 + 0.4 * sin(j * 2.3 + i)
				_place(trunks, foot + Vector3(0, 3, 0), Vector3(0.55, 3, 0.55))
				_place(leaves, foot + Vector3(-2, 6, 0), Vector3(5, 4, 4) * size)
				_place(leaves, foot + Vector3(2, 8, 1), Vector3(4, 5, 4) * size)
			for j in 3:
				_place(rocks, Vector3(side * (206 + j * 2), 31, z + j * 2), Vector3(0.5, 0.3, 0.7), j)
	# The rim skyline is the crown, saddle and headland families of GEOMETRY.md section 3, baked
	# into the shoulder batch below. West crowns end at x=-158, east ones start at x=184.
	var rim := rim_plan(Spillway.new())
	# Service balconies, lanterns and ball-culture marks share existing batches.
	for x in [-90.0, 0.0, 90.0]:
		_place(metal, Vector3(x, 91, 221), Vector3(29, 1, 8))
		for dx in [-12.0, 12.0]:
			_place(metal, Vector3(x + dx, 99, 218), Vector3(0.7, 16, 0.7))
			_place(lamps, Vector3(x + dx, 104, 217), Vector3(1.1, 1.8, 1.1))
		_place(metal, Vector3(x, 107, 218), Vector3(26, 0.6, 0.6))
		_place(glyphs, Vector3(x + 12, 106, 227.6), Vector3(2.6, 2.6, 0.5))
		# Gyro rings are narrow segments around the sphere, no letters or warning bands.
		for k in 16:
			var a := k * TAU / 16.0
			var tr := Transform3D(Basis(Vector3.FORWARD, -a).scaled(Vector3(0.27, 1.3, 0.2)), Vector3(x + 12 + cos(a) * 2.5, 106 + sin(a) * 4.1, 227.3))
			cables.append(tr)
	for k in 36:
		var x := -250.0 + k * 14.0
		_place(cables, Vector3(x, 157 - 16 * (1.0 - pow(x / 260.0, 2)), 267), Vector3(14.2, 0.24, 0.24))
	for x in [-171.0, -24.0, 137.0]:
		var cable_y := 157 - 16 * (1.0 - pow(x / 260.0, 2))
		_place(cables, Vector3(x, cable_y - 4, 267), Vector3(0.3, 8, 0.3))
		_place(cabins, Vector3(x, cable_y - 11, 267), Vector3(8, 6, 6))
		_place(metal, Vector3(x, cable_y - 7.5, 267), Vector3(10, 0.7, 8))
		_place(recess, Vector3(x, cable_y - 10, 263.9), Vector3(6, 2.7, 0.2))

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var rock := _eroded_rock()
	# One opaque cliff draw: the shoulder shelves and the rim crowns share the batch, so the
	# rim swap adds no draw. The cliff shader reads world position, not vertex colour.
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for placement in rocks:
		cliff.append_from(_placed_rock(rock, placement), 0, Transform3D.IDENTITY)
	for crown in rim:
		cliff.append_from(crown_mesh(crown), 0, crown_transform(crown))
	cliff.index()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 2.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var canopy := SphereMesh.new()
	# Spray cards: a two-triangle quad facing the play area with a soft radial alpha edge,
	# so the shared triangle budget is not spent on spheres.
	var puff := QuadMesh.new()
	puff.size = Vector2(2, 2)
	puff.flip_faces = true
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 6
	canopy.rings = 2
	_batch(scenery, "Masonry", box, stone, Color("b79468"))
	_batch(scenery, "LimestoneCaps", box, trim, Color("d5b785"))
	_batch(scenery, "Recesses", box, recess, Color("454943"))
	_batch(scenery, "CopperValves", box, metal, Color("885e43"))
	_batch(scenery, "SandstoneShoulders", cliff.commit(), [Transform3D.IDENTITY], Color("b37d50"))
	_batch(scenery, "CottonwoodTrunks", trunk, trunks, Color("766744"))
	_batch(scenery, "CottonwoodCrowns", canopy, leaves, Color("728249"))
	_batch(scenery, "BlockFaces", box, masonry, Color("bda078"))
	_batch(scenery, "ValvePennants", box, banners, Color("6e8982"))
	_batch(scenery, "SpillSheets", _water_edge_mesh("SpillSheets", box), water, Color.WHITE)
	_batch(scenery, "Tailrace", _water_edge_mesh("Tailrace", box), pools, Color.WHITE)
	_batch(scenery, "WaterMist", puff, mist, Color("bcd4da"))
	_batch(scenery, "CablesAndGyros", box, cables, Color("c7b18c"))
	_batch(scenery, "CableCars", box, cabins, Color("537b72"))
	_batch(scenery, "LanternLenses", box, lamps, Color("f2cc88"))
	_batch(scenery, "BallInsignia", canopy, glyphs, Color("e2ceb0"))
	_merge_opaque(scenery)
	return scenery


static func _water_edge_mesh(node_name: String, fallback: Mesh) -> Mesh:
	var packed := load("res://assets/models/world_one/water_edges.glb") as PackedScene
	if packed == null:
		return fallback
	var scene := packed.instantiate()
	var found: Mesh = null
	for candidate in scene.find_children(node_name, "MeshInstance3D", true, false):
		found = (candidate as MeshInstance3D).mesh
	scene.free()
	return found if found != null else fallback


static func _place(into: Array[Transform3D], at: Vector3, size: Vector3, turn := 0.0) -> void:
	into.append(Transform3D(Basis(Vector3.UP, turn).scaled(size), at))


static func _place_mist(into: Array[Transform3D], at: Vector3, half: Vector2, roll: float) -> void:
	into.append(Transform3D(Basis(Vector3.BACK, roll).scaled(Vector3(half.x, half.y, 1.0)), at))


static func _merge_opaque(parent: Node3D) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var material: StandardMaterial3D
	for child in parent.get_children():
		var mat = child.material_override
		if not mat is StandardMaterial3D or mat.emission_enabled or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var arrays: Array = child.mesh.surface_get_arrays(0)
		var offset := vertices.size()
		vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
		normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		for color in arrays[Mesh.ARRAY_COLOR]:
			colors.append(color * mat.albedo_color.srgb_to_linear())
		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)
		if material == null:
			material = mat.duplicate()
			material.albedo_color = Color.WHITE
		child.free()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 0.0, [])
	var view := MeshInstance3D.new()
	view.name = "DamAndLedgeDressing"
	view.mesh = importer.get_mesh()
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)


static func _batch(parent: Node3D, label: String, mesh: Mesh, placements: Array[Transform3D], tint: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = Palette.look_texture("sandstone-strata")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / 6.0
	var source := mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for placement in placements:
		var offset := vertices.size()
		if label == "WaterMist":
			uvs.append_array(source[Mesh.ARRAY_TEX_UV])
		var variation := 0.91 + 0.09 * sin(placement.origin.x * 4.7 + placement.origin.z * 2.3 + placement.origin.y)
		var normal_basis := placement.basis.inverse().transposed()
		for i in source_vertices.size():
			vertices.append(placement * source_vertices[i])
			var shade := variation * (0.84 + 0.16 * clampf(source_vertices[i].y + 0.5, 0.0, 1.0))
			colors.append(Color(shade, shade, shade))
			normals.append((normal_basis * source_normals[i]).normalized())
		for index in source_indices:
			indices.append(offset + index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	if label == "WaterMist":
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	var view := MeshInstance3D.new()
	view.name = label
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 0.0, [])
	view.mesh = importer.get_mesh()
	view.material_override = material
	if label == "SandstoneShoulders":
		var strata := ShaderMaterial.new()
		strata.shader = preload("res://src/presentation/sandstone.gdshader")
		strata.set_shader_parameter("cliff_only", true)
		view.material_override = strata
	elif label in ["SpillSheets", "Tailrace"]:
		var flowing := ShaderMaterial.new()
		flowing.shader = preload("res://src/presentation/spill_water.gdshader")
		flowing.set_shader_parameter("falling", label == "SpillSheets")
		view.material_override = flowing
	elif label == "WaterMist":
		# Spill mist at the four falls only (LIGHTING-TARGETS: #BCD4DA); the scenery test caps
		# its alpha at 0.12, so bigger cards and a cooler tint carry it, not more opacity.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color("bcd4da", 0.12)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var soft := Gradient.new()
		# Card UVs, not triplanar, so each card carries one falloff.
		material.uv1_triplanar = false
		material.uv1_scale = Vector3.ONE
		soft.offsets = PackedFloat32Array([0.0, 0.3, 0.6, 0.85, 1.0])
		soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.06), Color(1, 1, 1, 0)])
		var falloff := GradientTexture2D.new()
		falloff.gradient = soft
		falloff.fill = GradientTexture2D.FILL_RADIAL
		falloff.fill_from = Vector2(0.5, 0.5)
		falloff.fill_to = Vector2(1.0, 0.5)
		material.albedo_texture = falloff
	elif label == "LanternLenses":
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.1
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)


# Bakes one shelf with the base _batch rule: positions by the placement, normals by its
# inverse transpose, so non-uniform scale keeps the lit normals the base had.
static func _placed_rock(rock: ArrayMesh, placement: Transform3D) -> ArrayMesh:
	var source := rock.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var normal_basis := placement.basis.inverse().transposed()
	var out_vertices := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for i in vertices.size():
		out_vertices.append(placement * vertices[i])
		out_normals.append((normal_basis * normals[i]).normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_vertices
	arrays[Mesh.ARRAY_NORMAL] = out_normals
	arrays[Mesh.ARRAY_INDEX] = source[Mesh.ARRAY_INDEX]
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return baked


static func _eroded_rock() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 5:
		var ring := PackedVector3Array()
		var y := -1.0 + row / 2.0
		for col in 8:
			var a := col * TAU / 8.0
			var lip := 1.0 if row % 2 == 0 else 0.92
			var r := (0.91 + 0.09 * sin(col * 2.7 + row * 0.4)) * lip * (1.0 - maxf(y, 0.0) * 0.12)
			ring.append(Vector3(cos(a) * r, y + sin(col * 2.1) * 0.05, sin(a) * r))
		rings.append(ring)
	for row in 4:
		for col in 8:
			var j := (col + 1) % 8
			for v in [rings[row][col], rings[row][j], rings[row + 1][col], rings[row][j], rings[row + 1][j], rings[row + 1][col]]:
				st.add_vertex(v)
	for col in 8:
		for v in [Vector3(0, 1, 0), rings[4][(col + 1) % 8], rings[4][col], Vector3(0, -1, 0), rings[0][col], rings[0][(col + 1) % 8]]:
			st.add_vertex(v)
	st.generate_normals()
	st.index()
	return st.commit()


# The three sides' crown records: where each crown stands and how tall it is over the sampled
# solid crest. `crest` is the highest terrain under the footprint, `root` how far the shell
# reaches below the lowest, so the shell only adds mass above and around existing stone.
static func rim_plan(map: RefCounted) -> Array:
	var plan := []
	for side in [-1, 1]:
		var orders: Array = RIM_WEST_ORDER if side < 0 else RIM_EAST_ORDER
		for f in 3:
			var z := RIM_START_Z + f * RIM_FAMILY_PITCH
			for v in orders[f]:
				var width: float = RIM_WIDTH[v]
				var entry := {"side": side, "variant": v, "family": f, "width": width, "depth": RIM_DEPTH[v], "add": RIM_ADD[v],
					"x": RIM_WEST_X if side < 0 else RIM_EAST_X, "z": z + width * 0.5, "yaw": 0.0 if side < 0 else PI}
				var hi := -INF
				var lo := INF
				for zi in range(-int(width * 0.5) - 2, int(width * 0.5) + 3, 2):
					for xi in range(-int(RIM_DEPTH[v] * 0.5) - 4, int(RIM_DEPTH[v] * 0.5) + 5, 2):
						var h: float = map.sample(entry["x"] + xi, entry["z"] + zi)[0]
						hi = maxf(hi, h)
						lo = minf(lo, h)
				entry["crest"] = hi
				entry["root"] = hi - lo + 5.0
				plan.append(entry)
				z += width + RIM_GULLY
	return plan


static func crown_transform(crown: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, crown["yaw"]), Vector3(crown["x"], crown["crest"], crown["z"]))


# A closed irregular buttress in crown-local metres: origin at the crest line, +x toward the
# arena, z along the crest. Six rings with unequal profiles, no noise; faceted normals.
static func crown_mesh(crown: Dictionary) -> ArrayMesh:
	var rings := crown_rings(crown)
	var n := rings[0].size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for k in 5:
		for i in n:
			var j := (i + 1) % n
			for p in [rings[k][i], rings[k][j], rings[k + 1][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]]:
				st.add_vertex(p)
	var top := Vector3.ZERO
	var base := Vector3.ZERO
	for i in n:
		top += rings[5][i] / n
		base += rings[0][i] / n
	for i in n:
		var j := (i + 1) % n
		for p in [top, rings[5][j], rings[5][i], base, rings[0][i], rings[0][j]]:
			st.add_vertex(p)
	st.generate_normals()
	st.index()
	return st.commit()


static func crown_rings(crown: Dictionary) -> Array[PackedVector3Array]:
	var v: int = crown["variant"]
	var factors: Array = RIM_PLAN_FACTOR[v]
	var n := factors.size()
	var hx: float = crown["depth"] * 0.5
	var hz: float = crown["width"] * 0.5
	var add: float = crown["add"]
	var rings: Array[PackedVector3Array] = []
	for k in 6:
		var ring := PackedVector3Array()
		for i in n:
			var a := (i + 0.3 * sin(i * 2.3 + v)) * TAU / n
			var c := cos(a)
			var s := sin(a)
			var px: float = hx * signf(c) * pow(absf(c), 0.55) * factors[i] * RIM_RING_SCALE[k]
			var pz: float = hz * signf(s) * pow(absf(s), 0.55) * factors[i] * RIM_RING_SCALE[k]
			var shift: Vector2 = RIM_RING_SHIFT[v][k]
			px = clampf(px + shift.x, -hx, hx)
			pz = clampf(pz + shift.y, -hz, hz)
			var y: float = -crown["root"] if k == 0 else add * RIM_RING_Y[k]
			if k >= 2:
				y *= lerpf(1.0, _crest_share(v, pz / hz), (k - 1) / 4.0)
			ring.append(Vector3(px, y, pz))
		rings.append(ring)
	# The highest top-ring point sits exactly `add` over the crest line.
	var peak := 0.0
	for p in rings[5]:
		peak = maxf(peak, p.y)
	for k in range(2, 6):
		for i in n:
			var pt := rings[k][i]
			pt.y *= add / peak
			rings[k][i] = pt
	return rings


static func _crest_share(variant: int, t: float) -> float:
	var keys: Array = RIM_CREST[variant]
	t = clampf(t, -1.0, 1.0)
	for i in keys.size() - 1:
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if t <= b.x:
			return lerpf(a.y, b.y, (t - a.x) / (b.x - a.x))
	return keys[keys.size() - 1].y
