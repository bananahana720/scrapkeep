extends Node3D

const Materials := preload("res://src/materials.gd")

const RADIUS := 6.0
const BASE_COST := 25
const COST_STEP := 15

signal used(node: Node3D)

var secret := false
var opened := false
var revealed := true
var cost := BASE_COST

var _lid: MeshInstance3D
var _glow: OmniLight3D
var _material: StandardMaterial3D


func setup(at: Vector3, is_secret: bool, price: int) -> void:
	secret = is_secret
	cost = price
	revealed = not is_secret
	position = at

	_material = Materials.solid(Materials.ARC if secret else Materials.AMBER, 1.2)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3.2, 2.0, 3.2)
	body.mesh = box
	body.material_override = Materials.striped(Materials.COPPER, Materials.CHARCOAL)
	body.position = Vector3.UP * 1.0
	add_child(body)

	_lid = MeshInstance3D.new()
	var lid := BoxMesh.new()
	lid.size = Vector3(3.6, 0.5, 3.6)
	_lid.mesh = lid
	_lid.material_override = _material
	_lid.position = Vector3.UP * 2.2
	add_child(_lid)

	_glow = OmniLight3D.new()
	_glow.light_color = Materials.ARC if secret else Materials.AMBER
	_glow.omni_range = 18.0
	_glow.light_energy = 2.2
	_glow.position = Vector3.UP * 3.0
	add_child(_glow)

	_apply_visibility()


func reveal() -> void:
	if revealed:
		return
	revealed = true
	_apply_visibility()


func interact_point() -> Vector3:
	return global_position


func interact_radius() -> float:
	return RADIUS


func prompt(run_state) -> String:
	if opened or not revealed:
		return ""
	var title := "maintenance hatch cache" if secret else "loot cache"
	if run_state.scrap < cost:
		return "%s: needs %d scrap (you have %d)" % [title, cost, run_state.scrap]
	return "E  open %s for %d scrap" % [title, cost]


func interact(run_state) -> void:
	if opened or not revealed or not run_state.spend(cost):
		return
	opened = true
	_material.albedo_color = Materials.VERDIGRIS
	_material.emission_energy_multiplier = 0.2
	_glow.light_energy = 0.3
	_lid.position = Vector3(1.9, 2.4, 0.0)
	_lid.rotation_degrees = Vector3(0.0, 0.0, -62.0)
	used.emit(self)


func _apply_visibility() -> void:
	visible = revealed
	_glow.visible = revealed
