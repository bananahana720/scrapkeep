extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

# All instances sit beyond the terrain footprint. The stage root owns visibility.
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
	for row in 18:
		for col in 18:
			var x := -126.0 + col * 14.0 + (3.0 if row % 2 else 0.0)
			_place(masonry, Vector3(x, 29.0 + row * 5.0, 235.0), Vector3(13.5, 4.6, 0.45))
	for x in [-90.0, 0.0, 90.0]:
		_place(banners, Vector3(x + 12, 106, 228), Vector3(7, 26, 0.25))
		_place(metal, Vector3(x + 12, 120, 228), Vector3(11, 0.7, 1.0))
		for floor_index in 3:
			_place(trim, Vector3(x, 132 + floor_index * 10, 229), Vector3(28, 1.0, 2.0))

	# Layered shoulders: broad rooted slabs, smaller offset crowns, no route dressing.
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := -155.0 + i * 79.0
			var h := 72.0 + 15.0 * sin(i * 1.8 + side)
			var x: float = side * (259.0 + 12.0 * sin(i * 2.1))
			_place(rocks, Vector3(x, h * 0.5, z), Vector3(40, h * 0.5, 50), i * 0.13)
			_place(rocks, Vector3(x + side * 9, h + 9, z + 4), Vector3(31, 12, 40), i * 0.13)
			_place(rocks, Vector3(x + side * 15, h + 26, z + 9), Vector3(23, 8, 30), i * 0.13)
			# Plant clusters on the top slab, with greener groups toward the basin.
			for j in (3 if i >= 2 else 1):
				var foot := Vector3(x + side * 15 + j * 6, h + 34, z + 2 + j * 7)
				_place(trunks, foot + Vector3(0, 4, 0), Vector3(0.8, 4, 0.8))
				_place(leaves, foot + Vector3(-2, 9, 0), Vector3(7, 6, 6))
				_place(leaves, foot + Vector3(3, 12, 2), Vector3(6, 7, 5))
				_place(leaves, foot + Vector3(5, 8, -2), Vector3(5, 5, 6))

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var rock := CylinderMesh.new()
	rock.top_radius = 0.82
	rock.bottom_radius = 1.0
	rock.height = 2.0
	rock.radial_segments = 7
	rock.rings = 1
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 2.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var canopy := SphereMesh.new()
	canopy.radius = 1.0
	canopy.height = 2.0
	canopy.radial_segments = 8
	canopy.rings = 4
	_batch(scenery, "Masonry", box, stone, Color("b79468"))
	_batch(scenery, "LimestoneCaps", box, trim, Color("d5b785"))
	_batch(scenery, "Recesses", box, recess, Color("454943"))
	_batch(scenery, "CopperValves", box, metal, Color("885e43"))
	_batch(scenery, "SandstoneShoulders", rock, rocks, Color("b37d50"))
	_batch(scenery, "CottonwoodTrunks", trunk, trunks, Color("766744"))
	_batch(scenery, "CottonwoodCrowns", canopy, leaves, Color("728249"))
	_batch(scenery, "BlockFaces", box, masonry, Color("bda078"))
	_batch(scenery, "ValvePennants", box, banners, Color("9b513a"))
	return scenery


static func _place(into: Array[Transform3D], at: Vector3, size: Vector3, turn := 0.0) -> void:
	into.append(Transform3D(Basis(Vector3.UP, turn).scaled(size), at))


static func _batch(parent: Node3D, label: String, mesh: Mesh, placements: Array[Transform3D], tint: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 1.0
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = Palette.painted_texture(128)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * 0.08
	var source := mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for placement in placements:
		var offset := vertices.size()
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
	var view := MeshInstance3D.new()
	view.name = label
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	importer.generate_lods(60.0, 0.0, [])
	view.mesh = importer.get_mesh()
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(view)
	GraphicsPreset.register_scenery(view)
