extends Node3D

const Palette := preload("res://src/core/palette.gd")
const SIREN_MAST := preload("res://assets/models/world_one/poi_siren_mast.glb")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# The water a stage's basin fills with. Its shape comes from the map's basin record,
# so each stage floods its own bowl, and the push, the plane you see and the "water"
# material all read the one surface height.

const DRAG := 2.6
const CURRENT := 6.0
const LIFT := 12.0
const WET_DEPTH := 2.5

# The director's clock for this stage; null when the stage has no flood.
var cycle: FloodCycle
var basin := {}

var _floor_y := 0.0
var _plane: MeshInstance3D
var _quad: PlaneMesh
var _mast: Node3D
var _lamp: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _lamp_material: StandardMaterial3D


func setup() -> void:
	# The title has no basin. configure() sets the first map position and visibility together.
	visible = false
	_plane = MeshInstance3D.new()
	_quad = PlaneMesh.new()
	_plane.name = "WaterSurface"
	_plane.mesh = _quad
	_plane.material_override = Palette.water(Palette.water_tone())
	add_child(_plane)

	# The muster siren's model is six metres high with its origin at the foot.
	_mast = SIREN_MAST.instantiate()
	_mast.name = "KlaxonMast"
	_mast.scale = Vector3.ONE * (16.0 / 6.0)
	add_child(_mast)

	_lamp_material = Palette.solid(Palette.AMBER, 1.0)
	_lamp_mesh = MeshInstance3D.new()
	_lamp_mesh.name = "KlaxonBulb"
	var bulb := SphereMesh.new()
	bulb.radius = 1.5
	bulb.height = 3.0
	_lamp_mesh.mesh = bulb
	_lamp_mesh.material_override = _lamp_material
	add_child(_lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Palette.AMBER
	_lamp.omni_range = 70.0
	_lamp.light_energy = 0.0
	add_child(_lamp)


# A new stage's bowl. floor_y is the basin floor under its centre; mast is the klaxon's
# foot on dry ground at the rim.
func configure(basin_record: Dictionary, floor_y: float, mast: Vector3) -> void:
	basin = basin_record
	_floor_y = floor_y
	visible = not basin.is_empty() and cycle != null
	if not visible:
		return
	# Sized to the bowl: a plane that overhangs the map is visible from anywhere as
	# a floating slab.
	_quad.size = basin["plane_size"]
	var centre: Vector2 = basin["plane_centre"]
	_plane.position = Vector3(centre.x, _floor_y, centre.y)
	_mast.position = mast
	_lamp_mesh.position = mast + Vector3.UP * 17.0
	_lamp.position = _lamp_mesh.position


func surface_y() -> float:
	if basin.is_empty() or cycle == null:
		return -INF
	return _floor_y + cycle.depth(basin["depth"])


# Draws the committed water level; the director advances the clock.
func render() -> void:
	if not visible:
		return
	_plane.position.y = surface_y()
	var pulse := 0.0
	if cycle.klaxon():
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	_lamp.light_energy = FlashGuard.spike(0.0, pulse * 9.0)
	_lamp_material.emission_energy_multiplier = FlashGuard.spike(0.4, 0.4 + pulse * 5.0)


func in_basin(point: Vector3) -> bool:
	if basin.is_empty() or cycle == null:
		return false
	return Vector2(point.x, point.z).distance_to(basin["centre"]) < basin["radius"]


func submersion(point: Vector3) -> float:
	if not in_basin(point):
		return 0.0
	return clampf((surface_y() - point.y) / WET_DEPTH, 0.0, 1.0)


# Drag plus an inward current: the water is a speed tax that also sweeps you
# toward the middle of the basin.
func external_accel(point: Vector3, velocity: Vector3) -> Vector3:
	var wet := submersion(point)
	if wet <= 0.0:
		return Vector3.ZERO
	var centre: Vector2 = basin["centre"]
	var to_centre := Vector3(centre.x - point.x, 0.0, centre.y - point.z)
	var current := to_centre.normalized() if to_centre.length() > 1.0 else Vector3.ZERO
	return -velocity * DRAG * wet + current * CURRENT * wet + Vector3.UP * LIFT * wet
