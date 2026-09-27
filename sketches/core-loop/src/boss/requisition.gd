extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Target := preload("res://src/boss/boss_target.gd")

# The Requisition: a rolling furnace-fortress several times the ball's height, with
# Brindle's glass cockpit on its stern. This node is its body and its pieces, and it
# decides nothing: boss.gd moves it, swings its cranes and asks its pieces what they
# are. Its hull is kinematic, so it shoves the ball with weight and is never pushed.

const HULL := Vector3(9.0, 5.0, 14.0)
const DECK := 5.0
const CAP_SPOTS := [Vector3(0.0, 5.4, -4.5), Vector3(-2.6, 5.4, 0.8), Vector3(2.6, 5.4, 0.8)]
const CRANE_PIVOTS := [Vector3(-4.5, 7.5, -2.0), Vector3(4.5, 7.5, 2.0)]
const MAGNET_REST := 6.0
const MAGNET_HANG := 4.5
const CAP_SIZE := Vector3(2.2, 0.8, 2.2)

var hull
var magnets: Array = []
var caps: Array = []
var heading := Vector3.FORWARD
var readout: Label3D

var _cables: Array = []
var _magnet_mats: Array = []
var _cap_meshes: Array = []
var _plates: Array = []
var _cockpit: MeshInstance3D


func build(boss) -> void:
	name = "Requisition"
	hull = Target.new()
	hull.setup(boss, "hull", "hull", HULL, Vector2(6.0, 3.0))
	hull.position = Vector3.UP * HULL.y * 0.5
	add_child(hull)
	_box(hull, HULL, Palette.solid(Palette.RUST), Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for z in [-3.5, 3.5]:
			var plate_mat := Palette.solid(Color("5d6b78"))
			hull.tint_with(plate_mat)
			_plates.append(_box(hull, Vector3(0.4, 3.2, 6.0), plate_mat, Vector3(side * (HULL.x * 0.5 + 0.2), 0.3, z)))
	_cockpit = _box(self, Vector3(3.0, 2.2, 3.0), Palette.water(Palette.ARC), Vector3(0.0, DECK + 1.1, 4.8))
	_box(self, Vector3(1.2, 1.0, 1.0), Palette.solid(Palette.AMBER, 0.4), Vector3(0.0, DECK + 1.0, 4.8))
	for i in CAP_SPOTS.size():
		var cap = Target.new()
		cap.setup(boss, "cap", "cap_%d" % (i + 1), CAP_SIZE, Vector2(1.2, 1.2))
		cap.position = CAP_SPOTS[i]
		add_child(cap)
		var mat := Palette.solid(Palette.CHARCOAL)
		cap.tint_with(mat)
		_cap_meshes.append(_cylinder(cap, 1.1, CAP_SIZE.y, mat))
		caps.append(cap)
	for i in CRANE_PIVOTS.size():
		_box(self, Vector3(0.8, 3.0, 0.8), Palette.solid(Palette.COPPER), CRANE_PIVOTS[i] - Vector3.UP * 1.5)
		var magnet = Target.new()
		magnet.setup(boss, "magnet", "magnet_%s" % ["port", "starboard"][i], Vector3.ZERO, Vector2(1.5, 1.5))
		add_child(magnet)
		var mat := Palette.solid(Palette.VERDIGRIS)
		_magnet_mats.append(mat)
		_cylinder(magnet, 1.4, 0.9, mat)
		magnets.append(magnet)
		var cable := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.25, 1.0)
		cable.mesh = box
		cable.material_override = Palette.solid(Palette.CHARCOAL)
		add_child(cable)
		_cables.append(cable)
	readout = Label3D.new()
	readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	readout.font_size = 72
	readout.pixel_size = 0.025
	readout.outline_size = 18
	readout.position = Vector3.UP * (DECK + 5.5)
	add_child(readout)


# Places the ship with its bow along `dir`, on whatever ground is under it.
func move_to(at: Vector3, dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.01:
		heading = flat.normalized()
	global_transform = Transform3D(Basis.looking_at(heading, Vector3.UP), at)


func pivot(i: int) -> Vector3:
	return to_global(CRANE_PIVOTS[i])


# Where a magnet hangs when its crane is idle: out past the side of the hull.
func magnet_rest(i: int) -> Vector3:
	var p: Vector3 = CRANE_PIVOTS[i]
	var out := Vector3(signf(p.x) * MAGNET_REST, -MAGNET_HANG + 2.0, p.z)
	return to_global(out)


func set_magnet(i: int, at: Vector3, glow: float) -> void:
	magnets[i].global_position = at
	var mat: StandardMaterial3D = _magnet_mats[i]
	mat.emission_enabled = glow > 0.0
	mat.emission = Palette.HAZARD
	mat.emission_energy_multiplier = 2.5 * glow
	var from := pivot(i)
	var cable: MeshInstance3D = _cables[i]
	var span := at - from
	if span.length() < 0.1:
		cable.visible = false
		return
	cable.visible = true
	cable.global_transform = Transform3D(Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.99 else Vector3.RIGHT)
		.scaled(Vector3(1.0, 1.0, span.length())), from + span * 0.5)


func show_cranes(on: bool) -> void:
	for i in magnets.size():
		magnets[i].visible = on
		_cables[i].visible = on


func open_caps(open: bool) -> void:
	for mesh in _cap_meshes:
		(mesh as MeshInstance3D).position.y = 0.25 if open else 0.0
		((mesh as MeshInstance3D).material_override as StandardMaterial3D).emission_enabled = open
		((mesh as MeshInstance3D).material_override as StandardMaterial3D).emission = Palette.HAZARD
		((mesh as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 1.2


func shed_armour() -> void:
	for plate in _plates:
		(plate as MeshInstance3D).visible = false


func cockpit_open(open: bool) -> void:
	_cockpit.visible = not open


func set_readout(text: String, color: Color) -> void:
	readout.text = text
	readout.modulate = color


func _box(parent: Node3D, size: Vector3, mat: Material, at: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func _cylinder(parent: Node3D, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = h
	mesh.mesh = cyl
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh
