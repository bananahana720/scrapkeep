extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")

const SHAPES := {"common": "bar", "rare": "diamond", "relic": "star", "evolved": "crown"}
const CROWN_POINTS := 5


static func shape_of(rarity: String) -> String:
	var id := ItemGen.resolve_rarity(rarity)
	return SHAPES[id if id != "" else "common"]


static func mark(rarity: String, mat: Material, size := 1.0) -> Node3D:
	var shape := shape_of(rarity)
	var body := _sculpted(mat)
	var ink := _bezel()
	var root := Node3D.new()
	root.name = "Tier_" + shape
	match shape:
		"bar":
			_add(root, _box(Vector3(1.1, 0.3, 0.3) * size), body)
			for side in [-1.0, 1.0]:
				_add(root, _box(Vector3(0.11, 0.34, 0.34) * size), ink, Vector3(side * 0.51 * size, 0.0, 0.0))
		"diamond":
			_add(root, _rhombus(0.45 * size, 0.9 * size), body)
			_add(root, _torus(0.42 * size, 0.045 * size), ink)
		"star":
			_add(root, _rhombus(0.24 * size, 1.5 * size), body)
			_add(root, _rhombus(0.62 * size, 0.24 * size), body)
			_add(root, _torus(0.32 * size, 0.045 * size), ink)
			_add(root, _sphere(0.3 * size), Palette.solid(Palette.ARC, 1.0))
		"crown":
			_crown(root, 0.42 * size, 0.6 * size, 0.07 * size, body, Vector3.UP * -0.2 * size)
			_add(root, _torus(0.42 * size, 0.085 * size), ink, Vector3.UP * -0.28 * size)
	return root


static func foot(rarity: String, mat: Material, size := 1.0) -> Node3D:
	var shape := shape_of(rarity)
	if shape == "bar":
		return null
	var body := _sculpted(mat)
	var ink := _bezel()
	var root := Node3D.new()
	root.name = "Foot_" + shape
	match shape:
		"diamond":
			_add(root, _plate(0.46 * size, 0.07 * size), body)
			_add(root, _plate(0.51 * size, 0.04 * size), ink, Vector3.DOWN * 0.02 * size)
		"star":
			for yaw in [0.0, PI * 0.5]:
				var arm := _add(root, _plate(0.56 * size, 0.06 * size), body)
				arm.scale = Vector3(1.0, 1.0, 0.3)
				arm.rotation.y = yaw
				var rim := _add(root, _plate(0.61 * size, 0.035 * size), ink, Vector3.DOWN * 0.02 * size)
				rim.scale = Vector3(1.0, 1.0, 0.36)
				rim.rotation.y = yaw
			var bolt := Palette.solid(Palette.ARC, 1.35)
			for k in 4:
				var a := PI * 0.25 + PI * 0.5 * k
				_add(root, _sphere(0.07 * size), bolt, Vector3(cos(a), 0.4, sin(a)) * 0.24 * size)
		"crown":
			_crown(root, 0.36 * size, 0.26 * size, 0.04 * size, body, Vector3.ZERO)
			_add(root, _torus(0.36 * size, 0.055 * size), ink, Vector3.DOWN * 0.025 * size)
	for node: MeshInstance3D in root.get_children():
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _sculpted(mat: Material) -> Material:
	if not mat is StandardMaterial3D:
		return mat
	var sculpted := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
	sculpted.roughness = 0.36
	sculpted.metallic = 0.32
	sculpted.rim_enabled = true
	sculpted.rim = 0.5
	sculpted.rim_tint = 0.35
	if sculpted.emission_enabled:
		sculpted.emission_energy_multiplier = minf(sculpted.emission_energy_multiplier, 0.65)
	return sculpted


static func _bezel() -> StandardMaterial3D:
	var ink := Palette.solid(Palette.CHARCOAL, 0.0, false)
	ink.roughness = 0.65
	ink.metallic = 0.25
	return ink


static func _torus(radius: float, band: float) -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.01, radius - band)
	torus.outer_radius = radius + band
	torus.rings = 24
	torus.ring_segments = 10
	return torus
static func _crown(root: Node3D, radius: float, tall: float, band: float, mat: Material, base: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - band
	torus.outer_radius = radius + band
	torus.rings = 24
	torus.ring_segments = 10
	_add(root, torus, mat, base)
	for k in CROWN_POINTS:
		var a := TAU * k / CROWN_POINTS
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = band * 2.2
		cone.height = tall
		cone.radial_segments = 6
		_add(root, cone, mat, base + Vector3(cos(a) * radius, tall * 0.5, sin(a) * radius))


static func _add(root: Node3D, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	root.add_child(node)
	return node


static func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


static func _rhombus(radius: float, height: float) -> SphereMesh:
	var gem := SphereMesh.new()
	gem.radius = radius
	gem.height = height
	gem.radial_segments = 4
	gem.rings = 2
	return gem


static func _sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _plate(radius: float, thick: float) -> CylinderMesh:
	var plate := CylinderMesh.new()
	plate.top_radius = radius
	plate.bottom_radius = radius
	plate.height = thick
	plate.radial_segments = 4
	return plate
