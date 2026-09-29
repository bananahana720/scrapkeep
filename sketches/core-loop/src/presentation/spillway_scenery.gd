extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Spillway := preload("res://src/world/map_spillway.gd")

# Rim crown families, CLIFF-R2 section 1. Each crown is one closed solid: 12 perimeter stations
# (six along the arena face, six along the back, both lists ordered by world Z) and five height
# rings: buried base, h0 (the highest terrain under the footprint), then .35, .70 and 1.0 of the
# local crest rise. C = broad crown, S = saddle, H = blunt headland (variant 0, 1, 2).
const RIM_WIDTH := [48.0, 36.0, 24.0]
const RIM_DEPTH := [16.0, 12.0, 14.0]
const RIM_ADD := [18.0, 6.0, 12.0]
const RIM_GULLY := 6.0
const RIM_FAMILY_PITCH := 126.0
const RIM_START_Z := -186.0
const RIM_WEST_X := -167.0
# East centres per variant, so every root lies on the terrain side of X=200.
const RIM_EAST_X := [192.0, 194.0, 193.0]
# Family order along increasing world Z. F2 is C/S/H on both sides.
const RIM_WEST_ORDER := [[0, 1, 2], [0, 2, 1], [0, 1, 2]]
const RIM_EAST_ORDER := [[2, 1, 0], [2, 0, 1], [0, 1, 2]]
# Fraction of the crest rise per ring, and the fraction of full depth kept at each ring.
const RIM_RING_Y := [0.0, 0.0, 0.35, 0.70, 1.0]
const RIM_RING_DEPTH := [1.0, 1.0, 0.95, 0.85, 0.75]
# The two crest ends shorten by 1 m at the top ring only.
const RIM_END_TRIM := 1.0
# Crest profile, u along the unit's world-Z interval : metres above h0, linear between.
const RIM_CREST := [
	[Vector2(0, 8), Vector2(0.20, 16), Vector2(0.38, 18), Vector2(0.64, 17), Vector2(0.85, 12), Vector2(1, 8)],
	[Vector2(0, 3), Vector2(0.20, 5), Vector2(0.40, 6), Vector2(0.60, 5.5), Vector2(0.85, 4), Vector2(1, 3)],
	[Vector2(0, 5), Vector2(0.20, 10), Vector2(0.38, 12), Vector2(0.64, 12), Vector2(0.85, 10), Vector2(1, 6)],
]
# Arena-face stations (u). Each fold spans one face segment, so its ends are stations.
const RIM_FACE_U := [
	[0.0, 0.13, 0.43, 0.55, 0.85, 1.0],
	[0.0, 0.18, 0.356, 0.744, 0.87, 1.0],
	[0.0, 0.125, 0.251, 0.709, 0.85, 1.0],
]
# Face segments (index of the first station) carrying a diagonal fold: C two, S one, H one.
const RIM_FOLDS := [[1, 3], [2], [2]]
const RIM_FOLD_DEPTH := 0.72
# Groove chains per variant, low end to high end: [band k, w0, h0, w1, h1] where w runs along the
# fold's low-to-high direction and h up the band, both as fractions of the quad. S and H run one
# groove through two or three bands (meeting on the shared edge) to reach their rise; C keeps one band per fold.
const RIM_FOLD_BANDS := [
	[[2, 0.14, 0.14, 0.86, 0.86]],
	[[1, 0.10, 0.8, 0.3, 1.0], [2, 0.3, 0.0, 0.6, 1.0], [3, 0.6, 0.0, 0.88, 1.0]],
	[[2, 0.12, 0.0, 0.6, 1.0], [3, 0.6, 0.0, 0.88, 0.6]],
]

# Shoulder hulls, section 2: one continuous hull per old four-shelf stack. Plan outline in
# normalised (d outward from the arena, e along Z) coordinates, chamfered so no corner is a knife.
const HULL_OUTLINE := [
	Vector2(1.0, -0.62), Vector2(1.0, 0.35), Vector2(0.72, 0.98), Vector2(0.05, 1.0), Vector2(-0.75, 0.90),
	Vector2(-1.0, 0.25), Vector2(-1.0, -0.45), Vector2(-0.55, -1.0), Vector2(0.25, -1.0), Vector2(0.82, -0.90),
]
# Per level: centre d, semi d, centre e, semi e. Each level nests inside the one below.
const HULL_LEVELS := [
	[2.0, 31.0, 0.0, 26.0],
	[4.0, 27.0, -1.0, 24.0],
	[8.0, 22.0, -3.0, 20.0],
	[14.0, 15.0, -4.0, 18.0],
]
const HULL_FOLD_DEPTH := 0.9
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

	# Lintels give the retaining wall scale.
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
	# Shoulders: 16 continuous hulls (below) replace the 64 shelves; 48 small scattered rocks and the
	# cottonwoods keep their transforms.
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			for j in 3:
				_place(rocks, Vector3(side * (206 + j * 2), 31, z + j * 2), Vector3(0.5, 0.3, 0.7), j)
	var cottonwoods := cottonwood_transforms()
	trunks.append_array(cottonwoods["trunks"])
	leaves.append_array(cottonwoods["leaves"])
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
	for hull in shoulder_plan():
		cliff.append_from(shoulder_mesh(hull), 0, Transform3D.IDENTITY)
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
	_dam_detail(scenery)
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


# I01: broad cast courses and repaired service frames from dam.glb, on the wall's front face
# (z 236, at most 1.2 m proud). One node with a surface per slot, so each slot keeps the sheet's
# roughness; no material_override, so _merge_opaque leaves it as its own three draws.
const DAM_PATH := "res://assets/models/world_one/dam.glb"
const DAM_FACE := Vector3(0, 0, 236)
const DAM_TINT := {"paint": Color.WHITE, "bare_metal": Color("7a7a70"), "rubber": Color("454943")}
const DAM_ROUGHNESS := {"paint": 0.8, "bare_metal": 0.45, "rubber": 0.95}


static func _dam_detail(parent: Node3D) -> void:
	var packed := load(DAM_PATH) as PackedScene
	if packed == null:
		push_warning("spillway_scenery: dam.glb missing, the dam face stays bare")
		return
	var scene := packed.instantiate()
	var mesh := ArrayMesh.new()
	for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in view.mesh.get_surface_count():
			var arrays := view.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				vertices[i] += DAM_FACE
			arrays[Mesh.ARRAY_VERTEX] = vertices
			var slot: String = view.mesh.surface_get_material(surface).resource_name
			var material := StandardMaterial3D.new()
			material.resource_name = slot
			material.albedo_color = DAM_TINT.get(slot, Color.WHITE)
			material.roughness = DAM_ROUGHNESS.get(slot, 1.0)
			material.vertex_color_use_as_albedo = true
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	scene.free()
	var node := MeshInstance3D.new()
	node.name = "DamDetail"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	GraphicsPreset.register_scenery(node)


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


# The cottonwood placements on the shoulder stacks, unchanged from round 1.
static func cottonwood_transforms() -> Dictionary:
	var trunks: Array[Transform3D] = []
	var leaves: Array[Transform3D] = []
	for hull in shoulder_plan():
		for j in 4:
			var foot: Vector3 = hull["roots"][j]
			var size := 0.6 + 0.4 * sin(j * 2.3 + hull["i"])
			_place(trunks, foot + Vector3(0, 3, 0), Vector3(0.55, 3, 0.55))
			_place(leaves, foot + Vector3(-2, 6, 0), Vector3(5, 4, 4) * size)
			_place(leaves, foot + Vector3(2, 8, 1), Vector3(4, 5, 4) * size)
	return {"trunks": trunks, "leaves": leaves}


# The 16 shoulder stations: side, index, centre, height h, and the four root points.
static func shoulder_plan() -> Array:
	var plan := []
	for side in [-1.0, 1.0]:
		for i in 8:
			var z := -176.0 + i * 56.0
			var h := 74.0 + 15.0 * sin(i * 1.8 + side)
			var x: float = side * (246.0 + 8.0 * sin(i * 2.1))
			var roots := []
			for j in 4:
				roots.append(Vector3(x + side * 15 + j * 3, h * 0.75 + h * 0.18 + 12, z - 15 + j * 7))
			plan.append({"side": side, "i": i, "x": x, "z": z, "h": h, "roots": roots})
	return plan


# The four old shelf placements of one station, for the envelope the hull must stay inside.
static func shelf_placements(hull: Dictionary) -> Array[Transform3D]:
	var shelves: Array[Transform3D] = []
	for shelf in 4:
		var width := 36.0 - shelf * 4.0
		_place(shelves, Vector3(hull["x"] + hull["side"] * shelf * 5, hull["h"] * 0.25 * shelf + 12, hull["z"]), Vector3(width, hull["h"] * 0.20, 32), hull["i"] * 0.27)
	return shelves


# The old shelves' union AABB in world metres.
static func shoulder_envelope(hull: Dictionary) -> AABB:
	var rock := _eroded_rock()
	var box := AABB()
	var first := true
	for placement in shelf_placements(hull):
		var baked := _placed_rock(rock, placement)
		for v in baked.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			if first:
				box = AABB(v, Vector3.ZERO)
				first = false
			else:
				box = box.expand(v)
	return box


static func _level_point(hull: Dictionary, level: int, k: int) -> Vector3:
	var row: Array = HULL_LEVELS[level]
	var n: Vector2 = HULL_OUTLINE[k]
	var d: float = row[0] + row[1] * n.x
	var e: float = row[2] + row[3] * n.y
	return Vector3(hull["x"] + hull["side"] * d, 0.0, hull["z"] + e)


# Heights of the four levels at station k: bottom of the old stack, two irregular mid levels,
# and an upper surface at least 0.15 m over the root height, never above the old top.
static func hull_levels_y(hull: Dictionary, k: int) -> Array:
	var h: float = hull["h"]
	var bottom := 12.0 - h * 0.2 + 0.2
	var root_y: float = hull["roots"][0].y
	var top := root_y + 0.15 + 0.4 + 0.4 * sin(k * 2.7 + hull["i"])
	var span := top - bottom
	return [bottom, bottom + span * 0.34 + 1.2 * sin(k * 2.1 + hull["i"]), bottom + span * 0.68 + 1.2 * sin(k * 1.7 + hull["side"]), top]


static func hull_rings(hull: Dictionary) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	for level in 4:
		var ring := PackedVector3Array()
		for k in HULL_OUTLINE.size():
			var p := _level_point(hull, level, k)
			p.y = hull_levels_y(hull, k)[level]
			ring.append(p)
		rings.append(ring)
	return rings


# One closed hull in world metres: 10 stations, three bands, fan caps, two recessed folds.
static func shoulder_mesh(hull: Dictionary) -> ArrayMesh:
	var rings := hull_rings(hull)
	var n := rings[0].size()
	var tris := PackedVector3Array()
	var middle := Vector3(hull["x"] + hull["side"] * 15.0, 0.0, hull["z"] - 4.0)
	# Folds: arena-facing segment 5 in band 1, segment 4 in band 2.
	var folds := {[1, 5]: [0.5, 8.0], [2, 4]: [0.5, 6.0]}
	for band in 3:
		for i in n:
			var j := (i + 1) % n
			var a := rings[band][i]
			var b := rings[band][j]
			var c := rings[band + 1][j]
			var d := rings[band + 1][i]
			var key := [band, i]
			if folds.has(key):
				var t_mid: float = folds[key][0]
				var rise: float = folds[key][1]
				var t_half: float = rise * 0.5 / ((d.y - a.y + c.y - b.y) * 0.5)
				_fold_quad(tris, a, b, c, d, Vector2(0.14, t_mid - t_half), Vector2(0.86, t_mid + t_half), HULL_FOLD_DEPTH, middle)
			else:
				_quad(tris, a, b, c, d, middle)
	_fan_cap(tris, rings[3], Vector3.UP)
	_fan_cap(tris, rings[0], Vector3.DOWN)
	return _solid(tris)


# Wall triangles are oriented away from the vertical axis through `middle`.
static func _outward_tri(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, middle: Vector3) -> void:
	var centroid := (a + b + c) / 3.0
	var hint := Vector3(centroid.x - middle.x, 0.0, centroid.z - middle.z)
	_oriented_tri(tris, a, b, c, hint)


static func _oriented_tri(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	if (b - a).cross(c - a).dot(hint) < 0.0:
		tris.append_array([a, c, b])
	else:
		tris.append_array([a, b, c])


static func _quad(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, middle: Vector3) -> void:
	_outward_tri(tris, a, b, d, middle)
	_outward_tri(tris, b, c, d, middle)


# A quad A B C D (in order) with a groove between P and Q, two points inside it at the (s, t)
# parameters, both pushed `depth` metres into the parent flank. Six triangles instead of two.
static func _fold_quad(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, sp: Vector2, sq: Vector2, depth: float, middle: Vector3) -> void:
	var p := a.lerp(b, sp.x).lerp(d.lerp(c, sp.x), sp.y)
	var q := a.lerp(b, sq.x).lerp(d.lerp(c, sq.x), sq.y)
	var normal := (b - a).cross(d - a)
	var centroid := (a + b + c + d) / 4.0
	if normal.dot(Vector3(centroid.x - middle.x, 0.0, centroid.z - middle.z)) < 0.0:
		normal = -normal
	var inward := -normal.normalized() * depth
	p += inward
	q += inward
	for t in [[a, b, p], [b, q, p], [b, c, q], [a, p, d], [p, q, d], [q, c, d]]:
		_outward_tri(tris, t[0], t[1], t[2], middle)


static func _fan_cap(tris: PackedVector3Array, ring: PackedVector3Array, up: Vector3) -> void:
	var centre := Vector3.ZERO
	for p in ring:
		centre += p / ring.size()
	for i in ring.size():
		_oriented_tri(tris, centre, ring[i], ring[(i + 1) % ring.size()], up)


# Flat-shaded mesh from a triangle soup, indexed.
static func _solid(tris: PackedVector3Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for p in tris:
		st.add_vertex(p)
	st.generate_normals()
	st.index()
	return st.commit()


# The crown records: where each crown stands and how tall it is over the sampled solid crest.
# `crest` is h0, the highest terrain under the final footprint (boundary included), `root` how far
# the base reaches below h0: down to 5 m under the lowest terrain of that footprint.
static func rim_plan(map: RefCounted) -> Array:
	var plan := []
	for side in [-1, 1]:
		var orders: Array = RIM_WEST_ORDER if side < 0 else RIM_EAST_ORDER
		for f in 3:
			var z := RIM_START_Z + f * RIM_FAMILY_PITCH
			for v in orders[f]:
				var width: float = RIM_WIDTH[v]
				var cx: float = RIM_WEST_X if side < 0 else RIM_EAST_X[v]
				var entry := {"side": side, "variant": v, "family": f, "width": width, "depth": RIM_DEPTH[v], "add": RIM_ADD[v],
					"x": cx, "z": z + width * 0.5, "yaw": 0.0 if side < 0 else PI}
				var hi := -INF
				var lo := INF
				for xi in footprint_steps(RIM_DEPTH[v]):
					for zi in footprint_steps(width):
						var h: float = map.sample(cx + xi, entry["z"] + zi)[0]
						hi = maxf(hi, h)
						lo = minf(lo, h)
				entry["crest"] = hi
				entry["root"] = hi - lo + 5.0
				plan.append(entry)
				z += width + RIM_GULLY
	return plan


# Offsets from the centre at 2 m spacing over [-length/2, length/2], boundary points included.
static func footprint_steps(length: float) -> Array:
	var steps := []
	var at := -length * 0.5
	while at < length * 0.5 - 0.001:
		steps.append(at)
		at += 2.0
	steps.append(length * 0.5)
	return steps


static func crown_transform(crown: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, crown["yaw"]), Vector3(crown["x"], crown["crest"], crown["z"]))


static func crest_rise(variant: int, u: float) -> float:
	var keys: Array = RIM_CREST[variant]
	u = clampf(u, 0.0, 1.0)
	for i in keys.size() - 1:
		var a: Vector2 = keys[i]
		var b: Vector2 = keys[i + 1]
		if u <= b.x:
			return lerpf(a.y, b.y, (u - a.x) / (b.x - a.x))
	return keys[keys.size() - 1].y


# Station u values in perimeter order: the face list ascending, then the back list descending.
static func crown_stations(variant: int) -> Array:
	var stations := []
	for u in RIM_FACE_U[variant]:
		stations.append({"u": u, "face": true})
	var back: Array = RIM_CREST[variant].map(func(k): return k.x)
	back.reverse()
	for u in back:
		stations.append({"u": u, "face": false})
	return stations


# Crown-local rings: origin at h0, +x toward the arena, z along the crest (mirrored under the east
# yaw so u always runs along increasing world Z). Five rings of 12 stations.
static func crown_rings(crown: Dictionary) -> Array[PackedVector3Array]:
	var v: int = crown["variant"]
	var stations := crown_stations(v)
	var zsign := 1.0 if crown["side"] < 0 else -1.0
	var rings: Array[PackedVector3Array] = []
	for k in 5:
		var ring := PackedVector3Array()
		for s in stations:
			var u: float = s["u"]
			var z: float = zsign * (u - 0.5) * crown["width"]
			if k == 4 and (u <= 0.0 or u >= 1.0):
				z -= zsign * (u - 0.5) * 2.0 * RIM_END_TRIM
			var x: float = crown["depth"] * 0.5 * RIM_RING_DEPTH[k] * (1.0 if s["face"] else -1.0)
			var y: float = -crown["root"] if k == 0 else crest_rise(v, u) * RIM_RING_Y[k]
			ring.append(Vector3(x, y, z))
		rings.append(ring)
	return rings


# The groove row of band k on face segment i for a variant, or empty.
static func _fold_band(variant: int, k: int, i: int) -> Array:
	if not (i in RIM_FOLDS[variant]):
		return []
	for row in RIM_FOLD_BANDS[variant]:
		if row[0] == k:
			return row
	return []


# A closed solid: four bands of 12 quads, zipped caps, and a local fold on each listed face segment.
static func crown_mesh(crown: Dictionary) -> ArrayMesh:
	var v: int = crown["variant"]
	var rings := crown_rings(crown)
	var n := rings[0].size()
	var tris := PackedVector3Array()
	var middle := Vector3.ZERO
	var rising: bool = crown["family"] != 1
	for k in 4:
		for i in n:
			var j := (i + 1) % n
			var a := rings[k][i]
			var b := rings[k][j]
			var c := rings[k + 1][j]
			var d := rings[k + 1][i]
			var chain := _fold_band(v, k, i)
			if not chain.is_empty():
				# Corners in perimeter order; the groove runs low to high along world Z.
				var p := Vector2(chain[1], chain[2])
				var q := Vector2(chain[3], chain[4])
				if rising:
					_fold_quad(tris, a, b, c, d, p, q, RIM_FOLD_DEPTH, middle)
				else:
					_fold_quad(tris, d, a, b, c, Vector2(1.0 - p.y, 1.0 - p.x), Vector2(1.0 - q.y, 1.0 - q.x), RIM_FOLD_DEPTH, middle)
			else:
				_quad(tris, a, b, c, d, middle)
	_zip_cap(tris, rings[4], v, Vector3.UP)
	_zip_cap(tris, rings[0], v, Vector3.DOWN)
	return _solid(tris)


# Triangulates a ring as a strip between its face and back stations, so no radial fan shows.
static func _zip_cap(tris: PackedVector3Array, ring: PackedVector3Array, variant: int, up: Vector3) -> void:
	var faces: int = RIM_FACE_U[variant].size()
	var face_idx := range(faces)
	var back_idx := range(ring.size() - 1, faces - 1, -1)
	var fi := 0
	var bi := 0
	var stations := crown_stations(variant)
	while fi < face_idx.size() - 1 or bi < back_idx.size() - 1:
		var next_f: float = stations[face_idx[fi + 1]]["u"] if fi < face_idx.size() - 1 else INF
		var next_b: float = stations[back_idx[bi + 1]]["u"] if bi < back_idx.size() - 1 else INF
		if next_f <= next_b:
			_oriented_tri(tris, ring[face_idx[fi]], ring[face_idx[fi + 1]], ring[back_idx[bi]], up)
			fi += 1
		else:
			_oriented_tri(tris, ring[face_idx[fi]], ring[back_idx[bi + 1]], ring[back_idx[bi]], up)
			bi += 1
