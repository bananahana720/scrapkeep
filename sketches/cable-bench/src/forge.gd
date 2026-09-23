extends Node3D

const Layout := preload("res://src/layout.gd")
const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Rules := preload("res://src/rules.gd")
const RunState := preload("res://src/run_state.gd")

const EXIT_REACH := 7.0

var run

var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _lamp: OmniLight3D


func setup(run_ref) -> void:
	run = run_ref
	global_position = Layout.forge_point()

	var base := MeshInstance3D.new()
	var plinth := CylinderMesh.new()
	plinth.top_radius = 7.0
	plinth.bottom_radius = 9.0
	plinth.height = 2.0
	base.mesh = plinth
	base.material_override = Materials.striped(Palette.CHARCOAL, Palette.COPPER)
	base.position = Vector3(0.0, 1.0, 0.0)
	add_child(base)

	for i in 4:
		var angle := TAU * i / 4.0 + PI * 0.25
		var leg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.8, 18.0, 1.8)
		leg.mesh = box
		leg.material_override = Materials.striped(Palette.RUST, Palette.CHARCOAL)
		leg.position = Vector3(cos(angle) * 6.0, 9.0, sin(angle) * 6.0)
		add_child(leg)

	var hood := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 2.0
	cone.bottom_radius = 8.0
	cone.height = 6.0
	hood.mesh = cone
	hood.material_override = Materials.solid(Palette.COPPER)
	hood.position = Vector3(0.0, 20.0, 0.0)
	add_child(hood)

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.2
	torus.outer_radius = 5.2
	_ring.mesh = torus
	_ring_material = Materials.solid(Palette.ARC, 0.4)
	_ring.material_override = _ring_material
	_ring.position = Vector3(0.0, 3.0, 0.0)
	add_child(_ring)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Palette.ARC
	_lamp.omni_range = 34.0
	_lamp.light_energy = 1.0
	_lamp.position = Vector3(0.0, 6.0, 0.0)
	add_child(_lamp)

	# The charge radius drawn on the ground: staying inside it is the whole ask.
	var zone := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Rules.CHARGE_RADIUS
	disc.bottom_radius = Rules.CHARGE_RADIUS
	disc.height = 0.08
	zone.mesh = disc
	var mat := Materials.solid(Palette.VERDIGRIS, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.22
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zone.material_override = mat
	zone.position = Vector3(0.0, 0.3, 0.0)
	add_child(zone)


func in_zone(at: Vector3) -> bool:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() < Rules.CHARGE_RADIUS


func at_exit(at: Vector3) -> bool:
	return Vector2(at.x - global_position.x, at.z - global_position.z).length() < EXIT_REACH


func _process(delta: float) -> void:
	if run == null:
		return
	var lit: float = run.charge_fraction()
	_ring_material.emission_energy_multiplier = lerpf(0.4, 6.0, lit)
	_lamp.light_energy = lerpf(1.0, 6.0, lit)
	if run.phase == RunState.Phase.READY:
		_ring.rotate_y(delta * 2.0)
