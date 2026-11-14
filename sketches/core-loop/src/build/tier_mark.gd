extends RefCounted

const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")

# A rarity's shape, so colour never carries a tier alone (VISUAL-LANGUAGE sections 2 and 5).
# The rungs follow the reward gate's toppers (tools/blender/reward_gate.py) and the shop's
# frames: each rung up adds a feature, and no two rungs share a silhouette.
#
#   common   bar      a plain slab; on a ball piece, no foot at all (copper hardware)
#   rare     diamond  one bold rhombus
#   relic    star     four points and the gauge bezel's mint bolt heads (a mint heart upright)
#   evolved  crown    a ring of points, the ancients' seam pattern standing up
#
# mark() is the upright one on a pedestal; foot() is the flat one a part piece stands on.
const SHAPES := {"common": "bar", "rare": "diamond", "relic": "star", "evolved": "crown"}
const CROWN_POINTS := 5


static func shape_of(rarity: String) -> String:
	var id := ItemGen.resolve_rarity(rarity)
	return SHAPES[id if id != "" else "common"]


# The upright mark, about size metres tall, centred on its origin.
static func mark(rarity: String, mat: Material, size := 1.0) -> Node3D:
	var shape := shape_of(rarity)
	var root := Node3D.new()
	root.name = "Tier_" + shape
	match shape:
		"bar":
			_add(root, _box(Vector3(1.1, 0.3, 0.3) * size), mat)
		"diamond":
			_add(root, _rhombus(0.45 * size, 0.9 * size), mat)
		"star":
			_add(root, _rhombus(0.24 * size, 1.5 * size), mat)
			_add(root, _rhombus(0.62 * size, 0.24 * size), mat)
			_add(root, _sphere(0.3 * size), Palette.solid(Palette.ARC, 3.0))
		"crown":
			_crown(root, 0.42 * size, 0.6 * size, 0.07 * size, mat, Vector3.UP * -0.2 * size)
	return root


# The flat foot under a ball piece, its +Y out of the shell. Common has none.
static func foot(rarity: String, mat: Material, size := 1.0) -> Node3D:
	var shape := shape_of(rarity)
	if shape == "bar":
		return null
	var root := Node3D.new()
	root.name = "Foot_" + shape
	match shape:
		"diamond":
			_add(root, _plate(0.46 * size, 0.07 * size), mat)
		"star":
			for yaw in [0.0, PI * 0.5]:
				var arm := _add(root, _plate(0.56 * size, 0.06 * size), mat)
				arm.scale = Vector3(1.0, 1.0, 0.3)
				arm.rotation.y = yaw
			# The bezel's bolt heads at 45 degrees, in the relic's mint heart colour.
			var bolt := Palette.solid(Palette.ARC, 3.0)
			for k in 4:
				var a := PI * 0.25 + PI * 0.5 * k
				_add(root, _sphere(0.07 * size), bolt, Vector3(cos(a), 0.4, sin(a)) * 0.24 * size)
		"crown":
			_crown(root, 0.36 * size, 0.26 * size, 0.04 * size, mat, Vector3.ZERO)
	return root


# A ring with CROWN_POINTS cones standing on it.
static func _crown(root: Node3D, radius: float, tall: float, band: float, mat: Material, base: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = radius - band
	torus.outer_radius = radius + band
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


# An octahedron: four sides around, a point top and bottom.
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


# A flat four-sided plate, corners on the axes.
static func _plate(radius: float, thick: float) -> CylinderMesh:
	var plate := CylinderMesh.new()
	plate.top_radius = radius
	plate.bottom_radius = radius
	plate.height = thick
	plate.radial_segments = 4
	return plate
