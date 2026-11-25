extends RefCounted

const Palette := preload("res://src/core/palette.gd")

const CONCRETE := Color("bdb6a6")
const IRON := Color("2b2724")
const BASALT := Color("3b3532")
const PINE := Color("4a5a3a")
const CAPROCK := Color("4a3a33")

const BEAM_ROOT := {
	"dam": Vector3(0, 22, 30),
	"penstock_tower": Vector3(0, 90, 58.3),
	"sinkhole": Vector3(0, -99, 38),
	"sky_island": Vector3(0, 200, 0),
	"spire": Vector3(0, 342, 0),
}

static var _materials := {}


static func build(kind: String, node: Node3D, to_world: Transform3D, ground := Callable(), anchor_y := INF) -> int:
	var before := node.get_child_count()
	match kind:
		"dam":
			_dam(node)
		"penstock_tower":
			_tower(node)
		"headframe":
			_headframe(node, to_world, ground)
		"sinkhole":
			_sinkhole(node)
		"sky_island":
			_isle(node, anchor_y)
		"spire":
			_spire(node)
	return node.get_child_count() - before


static func _dam(node: Node3D) -> void:
	var segments := 12
	for i in segments:
		var a := lerpf(-1.0, 1.0, (i + 0.5) / segments)
		var x := a * 160.0
		var z := 5.0 - 25.0 * (1.0 - a * a)
		var part := _box(node, "Arch%d" % i, Vector3(320.0 / segments + 1.0, 91, 10), Vector3(x, 75.5, z), CONCRETE)
		part.rotation.y = -atan(50.0 * a / 160.0)
	for side in [-1.0, 1.0]:
		_box(node, "GateTower" + ("L" if side < 0 else "R"), Vector3(12, 20, 12), Vector3(18 * side, 131, -20), CONCRETE)
	_box(node, "Gantry", Vector3(48, 3, 4), Vector3(0, 139.5, -20), IRON)


static func _tower(node: Node3D) -> void:
	var at := Vector3(0, 0, 58.3)
	_cylinder(node, "SurgeTower", 9.0, 7.0, 82.0, at + Vector3(0, 41, 0), CONCRETE)
	_cylinder(node, "Bell", 7.0, 10.0, 8.0, at + Vector3(0, 86, 0), CONCRETE)
	_cylinder(node, "Gallery", 11.0, 11.0, 1.0, at + Vector3(0, 84, 0), IRON)


static func _headframe(node: Node3D, to_world: Transform3D, ground: Callable) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_leg(node, "FrontLeg", Vector3(12 * sx, 0, 10 * sz), Vector3(3 * sx, 110, 3 * sz), to_world, ground)
	for sz in [-1.0, 1.0]:
		_leg(node, "BackLeg", Vector3(72, 0, 40 + 12 * sz), Vector3(4, 110, 4 * sz), to_world, ground)
	_box(node, "SheaveDeck", Vector3(14, 3, 14), Vector3(0, 110, 0), IRON)
	for sz in [-1.0, 1.0]:
		var wheel := _cylinder(node, "Sheave", 7.0, 7.0, 1.2, Vector3(0, 117, 4 * sz), IRON)
		wheel.rotation.x = PI * 0.5


static func _sinkhole(node: Node3D) -> void:
	_ring(node, "RimCoping", 125.0, 3.0, 0.6, Vector3(0, 0.3, 0), BASALT)
	_ring(node, "CaissonLip", 40.0, 1.0, 1.0, Vector3(0, -100, 0), IRON)
	for i in 5:
		var a := lerpf(-0.9, 0.9, i / 4.0)
		_box(node, "NestCell%d" % i, Vector3(5, 6, 3), Vector3(sin(a) * 9.0, -99 + 6.0 * cos(a * 2.0), 38 + 9.0 + absf(a) * 2.0), BASALT)


static func _isle(node: Node3D, anchor_y: float) -> void:
	_cylinder(node, "Taper", 90.0, 3.0, 318.0, Vector3(0, 41, 0), Palette.SANDSTONE)
	_cylinder(node, "Deck", 90.0, 90.0, 4.0, Vector3(0, 202, 0), PINE)
	var tether := -118.0 - (anchor_y - node.position.y)
	if tether > 0.5:
		_cylinder(node, "Tether", 0.4, 0.4, tether, Vector3(0, -118.0 - tether * 0.5, 0), IRON)


static func _spire(node: Node3D) -> void:
	_cylinder(node, "LowerShaft", 15.0, 15.0, 60.0, Vector3(0, 30, 0), Palette.SANDSTONE)
	_cylinder(node, "Shoulder", 25.0, 15.0, 60.0, Vector3(0, 90, 0), Palette.SANDSTONE)
	_cylinder(node, "UpperShaft", 10.0, 25.0, 210.0, Vector3(0, 225, 0), Palette.RUST)
	_cylinder(node, "Caprock", 8.0, 10.0, 12.0, Vector3(0, 336, 0), CAPROCK)


static func _leg(node: Node3D, name: String, foot: Vector3, head: Vector3, to_world: Transform3D, ground: Callable) -> void:
	if ground.is_valid():
		var world := to_world * foot
		foot.y = float(ground.call(world.x, world.z)) - to_world.origin.y
	var span := head - foot
	var leg := _box(node, name, Vector3(2, span.length(), 2), (foot + head) * 0.5, IRON)
	leg.basis = Basis(Quaternion(Vector3.UP, span.normalized()))


static func _box(node: Node3D, name: String, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _view(node, name, mesh, at, color)


static func _cylinder(node: Node3D, name: String, top: float, bottom: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	return _view(node, name, mesh, at, color)


static func _ring(node: Node3D, name: String, radius: float, width: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - width * 0.5
	mesh.outer_radius = radius + width * 0.5
	mesh.rings = 64
	var view := _view(node, name, mesh, at, color)
	view.scale.y = height / width
	return view


static func _view(node: Node3D, name: String, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = name
	view.mesh = mesh
	view.material_override = _material(color)
	view.position = at
	node.add_child(view, true)
	return view


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key]
