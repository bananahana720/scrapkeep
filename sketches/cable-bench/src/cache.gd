extends Node3D

const Materials := preload("res://src/materials.gd")
const Palette := preload("res://src/palette.gd")
const Rules := preload("res://src/rules.gd")

const REACH := 6.0

var label := "cache"
var opened := false

var run
var loadout
var rng: RandomNumberGenerator

var _lid: MeshInstance3D
var _beacon: MeshInstance3D
var _lamp: OmniLight3D


func setup(spot_name: String, at: Vector3, run_ref, loadout_ref, rng_ref) -> void:
	label = spot_name
	run = run_ref
	loadout = loadout_ref
	rng = rng_ref
	global_position = at
	add_to_group("cache")

	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.0, 2.0, 3.0)
	crate.mesh = box
	crate.material_override = Materials.striped(Palette.COPPER, Palette.CHARCOAL)
	crate.position = Vector3(0.0, 1.0, 0.0)
	add_child(crate)

	_lid = MeshInstance3D.new()
	var lid := BoxMesh.new()
	lid.size = Vector3(3.2, 0.4, 3.2)
	_lid.mesh = lid
	_lid.material_override = Materials.solid(Palette.VERDIGRIS)
	_lid.position = Vector3(0.0, 2.2, 0.0)
	add_child(_lid)

	# A tall thin beacon is how you spot a cache from the next bench down.
	_beacon = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.18
	beam.bottom_radius = 0.5
	beam.height = 26.0
	_beacon.mesh = beam
	var mat := Materials.solid(Palette.ARC, 2.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.35
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = mat
	_beacon.position = Vector3(0.0, 14.0, 0.0)
	add_child(_beacon)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Palette.ARC
	_lamp.light_energy = 2.4
	_lamp.omni_range = 12.0
	_lamp.position = Vector3(0.0, 3.0, 0.0)
	add_child(_lamp)


func cost() -> int:
	return Rules.cache_cost(run.tier())


func in_reach(from: Vector3) -> bool:
	return not opened and from.distance_to(global_position) < REACH


func affordable() -> bool:
	return run.scrap >= cost()


func open() -> Dictionary:
	if opened or not run.spend(cost()):
		return {}
	opened = true
	run.caches_opened += 1
	_lid.position = Vector3(1.6, 2.6, 0.0)
	_lid.rotation_degrees = Vector3(0.0, 0.0, 62.0)
	_beacon.visible = false
	_lamp.light_color = Palette.AMBER
	_lamp.light_energy = 1.2
	return loadout.grant_random(rng)
