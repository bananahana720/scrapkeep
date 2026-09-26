extends Node3D

const Terrain := preload("res://src/world/terrain.gd")
const Palette := preload("res://src/core/palette.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")

const DRAG := 2.6
const CURRENT := 6.0
const LIFT := 12.0
const WET_DEPTH := 2.5

var cycle := FloodCycle.new()

var _floor_y := 0.0
var _plane: MeshInstance3D
var _lamp: OmniLight3D
var _lamp_mesh: MeshInstance3D
var _lamp_material: StandardMaterial3D


func setup() -> void:
	_floor_y = Terrain.ground(Terrain.BASIN_CENTRE.x, Terrain.BASIN_CENTRE.y)

	_plane = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	# Sized to stay inside the terrain: a plane that overhangs the map edge is
	# visible from anywhere as a floating slab.
	quad.size = Vector2(300.0, 130.0)
	_plane.mesh = quad
	_plane.material_override = Palette.water(Palette.VERDIGRIS.lerp(Palette.ARC, 0.35))
	_plane.position = Vector3(0.0, _floor_y, Terrain.BASIN_CENTRE.y + 10.0)
	add_child(_plane)

	var mast := Terrain.at(Terrain.HATCH + Vector2(18.0, -10.0), 0.0)
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.7
	cyl.height = 16.0
	pole.mesh = cyl
	pole.material_override = Palette.solid(Palette.RUST)
	pole.position = mast + Vector3.UP * 8.0
	add_child(pole)

	_lamp_material = Palette.solid(Palette.AMBER, 1.0)
	_lamp_mesh = MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 1.5
	bulb.height = 3.0
	_lamp_mesh.mesh = bulb
	_lamp_mesh.material_override = _lamp_material
	_lamp_mesh.position = mast + Vector3.UP * 17.0
	add_child(_lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = Palette.AMBER
	_lamp.omni_range = 70.0
	_lamp.light_energy = 0.0
	_lamp.position = _lamp_mesh.position
	add_child(_lamp)


func surface_y() -> float:
	return _floor_y + cycle.depth(Terrain.FLOOD_DEPTH)


func step(delta: float) -> void:
	cycle.advance(delta)
	var y := surface_y()
	_plane.position.y = y
	var pulse := 0.0
	if cycle.klaxon():
		pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.009)
	_lamp.light_energy = pulse * 9.0
	_lamp_material.emission_energy_multiplier = 0.4 + pulse * 5.0


func submersion(point: Vector3) -> float:
	if not Terrain.in_basin(point):
		return 0.0
	return clampf((surface_y() - point.y) / WET_DEPTH, 0.0, 1.0)


# Drag plus an inward current: the water is a speed tax that also sweeps you
# toward the middle of the basin, which is where the hatch is.
func external_accel(point: Vector3, velocity: Vector3) -> Vector3:
	var wet := submersion(point)
	if wet <= 0.0:
		return Vector3.ZERO
	var to_centre := Vector3(Terrain.BASIN_CENTRE.x, point.y, Terrain.BASIN_CENTRE.y) - point
	to_centre.y = 0.0
	var current := to_centre.normalized() if to_centre.length() > 1.0 else Vector3.ZERO
	return -velocity * DRAG * wet + current * CURRENT * wet + Vector3.UP * LIFT * wet
