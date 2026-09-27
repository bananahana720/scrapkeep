extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Roster := preload("res://src/combat/roster.gd")
const Icons := preload("res://src/ui/icons.gd")

# The family kit on the Warden's shared clamp (DESIGN-V2 section 11, VISUAL-LANGUAGE
# section 11), visual only: nothing here collides. The clamp is one base; the kit says
# which cause of the collapse woke under this stage. Enamel stays dull petrol and only
# the Cherenkov seams glow; a weak point opening is its seam blazing.
#
# - reactor: three vent stacks round the deck and the core dome on top. The dome's seam
#   blazes while the core is vented open after a pulse.
# - swarm: a crown of hive cells and the queen cell in the middle, dark behind its
#   shutters until the guard swarm scatters, then lit and swollen.
# - mind: a jointed arm rising from the deck to a lens cluster that always follows the
#   ball, showing the trigger icon it read, and opening wide while it braces.

const DECK := 2.2
const SEAM_DIM := 0.8
const SEAM_OPEN := 5.0

var warden
var family := ""
var _seam_material: StandardMaterial3D
var _open_node: Node3D
var _lens: Node3D
var _icon: Sprite3D


func build(owner_warden, fam: String) -> void:
	warden = owner_warden
	family = fam
	name = "WardenKit"
	_seam_material = Palette.solid(Roster.ANCIENT_LIGHT, SEAM_DIM)
	match family:
		Roster.REACTOR:
			_build_reactor()
		Roster.SWARM:
			_build_hive()
		Roster.MIND:
			_build_mind()


func _enamel() -> StandardMaterial3D:
	var mat := Palette.solid(Roster.ANCIENT_ENAMEL)
	mat.roughness = 0.35
	return mat


func _mesh(mesh: Mesh, material: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node


func _build_reactor() -> void:
	for i in 3:
		var angle := TAU * (i + 0.25) / 3.0
		var tube := CylinderMesh.new()
		tube.top_radius = 0.45
		tube.bottom_radius = 0.55
		tube.height = 2.4
		var at := Vector3(cos(angle) * 1.9, DECK + 1.2, sin(angle) * 1.9)
		_mesh(tube, _enamel(), at)
		var band := TorusMesh.new()
		band.inner_radius = 0.45
		band.outer_radius = 0.58
		_mesh(band, _seam_material, at + Vector3.UP * 1.0)
	var dome := SphereMesh.new()
	dome.radius = 1.3
	dome.height = 1.6
	_open_node = _mesh(dome, _enamel(), Vector3.UP * (DECK + 3.0))
	var seam := TorusMesh.new()
	seam.inner_radius = 1.15
	seam.outer_radius = 1.32
	_mesh(seam, _seam_material, Vector3.UP * (DECK + 3.0))


func _build_hive() -> void:
	for i in 6:
		var angle := TAU * i / 6.0
		var cell := CylinderMesh.new()
		cell.radial_segments = 6
		cell.top_radius = 0.6
		cell.bottom_radius = 0.6
		cell.height = 1.1 + 0.3 * (i % 2)
		_mesh(cell, _enamel(), Vector3(cos(angle) * 1.5, DECK + 2.5, sin(angle) * 1.5))
	var queen := CylinderMesh.new()
	queen.radial_segments = 6
	queen.top_radius = 0.8
	queen.bottom_radius = 0.9
	queen.height = 1.6
	_open_node = _mesh(queen, _seam_material, Vector3.UP * (DECK + 2.9))


func _build_mind() -> void:
	var rod := CylinderMesh.new()
	rod.top_radius = 0.18
	rod.bottom_radius = 0.26
	rod.height = 3.0
	var arm := _mesh(rod, _enamel(), Vector3(0.6, DECK + 3.2, 0.0))
	arm.rotation.z = 0.25
	var joint := SphereMesh.new()
	joint.radius = 0.32
	joint.height = 0.64
	_mesh(joint, _seam_material, Vector3(0.2, DECK + 4.7, 0.0))
	_lens = Node3D.new()
	_lens.position = Vector3(0.0, DECK + 5.4, 0.0)
	add_child(_lens)
	var glass := SphereMesh.new()
	glass.radius = 0.9
	glass.height = 1.8
	_open_node = _mesh(glass, _seam_material, Vector3.ZERO, _lens)
	_icon = Sprite3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.no_depth_test = true
	_icon.pixel_size = 0.03
	_icon.position = Vector3.UP * 1.8
	_icon.modulate = Palette.HAZARD
	_icon.visible = false
	_lens.add_child(_icon)


# Where the kit's weak point sits, relative to the Warden.
func point_offset() -> Vector3:
	match family:
		Roster.REACTOR:
			return Vector3.UP * (DECK + 3.0)
		Roster.SWARM:
			return Vector3.UP * (DECK + 2.9)
		Roster.MIND:
			return Vector3.UP * (DECK + 5.4)
	return Vector3.UP * DECK


func show_icon(id: String) -> void:
	if _icon == null:
		return
	_icon.visible = id != ""
	if id != "":
		_icon.texture = Icons.texture(id)


func update(_delta: float) -> void:
	if warden == null:
		return
	var open: bool = warden.family_open()
	_seam_material.emission_energy_multiplier = SEAM_OPEN if open else SEAM_DIM
	if _open_node != null:
		_open_node.scale = Vector3.ONE * (1.3 if open else 1.0)
	if _lens != null:
		var to: Vector3 = warden.flat_to_ball() + Vector3.UP * -(DECK + 4.4)
		if to.length() > 0.5:
			var dir := to.normalized()
			_lens.basis = Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.FORWARD)
