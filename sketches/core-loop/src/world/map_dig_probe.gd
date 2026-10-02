extends "res://src/world/stage_map.gd"

# Unit P1, a throwaway terrain probe for the Dig (never merged; its findings are). The
# heightmap is the lower gallery's floor (y 0). An upper deck, a south landing deck and a
# ramp are mesh pieces with their own colliders, because a heightmap has one height per point.
#
#   z -90 .. 40   upper deck, top y 14, 12 m clear above the gallery floor; spawn on a pad at its north end
#   (0,-40)       the breach plate: 6 m square, level with the deck. A slam whose strength is
#                 at or above SLAM_BREAK breaks it (dig_plate.gd); it reads slate until a slam
#                 pressed now would break it, then mint (the same colour roles as event_kinds.gd)
#   z -46 .. 46   the gallery channel (walls at x +-9) with a lit seam along x = 0
#   z 4 .. 44     a roofed stretch of the channel, 40 m, underside at y 3.5, so the chase camera (about 3.5 m above the ball) meets a ceiling
#   z 44 .. 78    the one ramp back up, 14 m in 34 m, onto the south deck (z 78 .. 108, top y 14)

const EventKinds := preload("res://src/core/event_kinds.gd")
const Plate := preload("res://src/world/dig_plate.gd")

const SPAWN := Vector2(0.0, -84.0)
const DECK_TOP := 14.0
const DECK_THICK := 2.0
const PLATE_AT := Vector2(0.0, -40.0)
const PLATE_SIZE := 10.0
# A slam at 30 m/s of fall speed is strength 1.0 (PlayerBall.slam_strength).
const SLAM_BREAK := 1.0
const CHANNEL_HALF := 9.0
const CHANNEL_FROM := -46.0
const CHANNEL_TO := 46.0
const ROOF_FROM := 4.0
const ROOF_TO := 44.0
const ROOF_UNDER := 3.5
const RAMP_FROM := 44.0
const RAMP_TO := 78.0
const RAMP_HALF := 7.0
const PAD_HALF := 7.0

# The plate's size is a probe knob: --plate=<metres> on the command line (default PLATE_SIZE).
var plate_size := PLATE_SIZE


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plate="):
			plate_size = float(arg.trim_prefix("--plate="))
	title = "Dig probe"
	spawn = SPAWN
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = Vector2(0.0, 100.0)
	vault = Vector2(0.0, 100.0)
	beacon_floor = DECK_TOP
	play_rect = Rect2(-100.0, -100.0, 200.0, 200.0)


# The gallery floor, with a column under the spawn pad so the ball can start on the deck.
func sample(x: float, z: float) -> Array:
	var dx := absf(x - SPAWN.x)
	var dz := absf(z - SPAWN.y)
	var column := (1.0 - smoothstep(PAD_HALF, PAD_HALF + 2.0, dx)) * (1.0 - smoothstep(PAD_HALF, PAD_HALF + 2.0, dz))
	return [DECK_TOP * column, Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.25)]


func material_at(_x: float, _z: float) -> String:
	return "sand"


func build_props(parent: Node3D, _ground: Callable) -> void:
	var slab_mat := Palette.solid(Palette.SANDSTONE)
	var wall_mat := Palette.solid(Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.35))
	var roof_mat := Palette.solid(Palette.VERDIGRIS)
	var seam_mat := Palette.solid(Palette.ANCIENT, 2.4)
	var cy := DECK_TOP - DECK_THICK * 0.5
	var h := plate_size * 0.5
	# The upper deck: four slabs round the breach hole.
	_slab(parent, Vector2(-50.0, -90.0), Vector2(50.0, PLATE_AT.y - h), cy, slab_mat)
	_slab(parent, Vector2(-50.0, PLATE_AT.y + h), Vector2(50.0, 40.0), cy, slab_mat)
	_slab(parent, Vector2(-50.0, PLATE_AT.y - h), Vector2(PLATE_AT.x - h, PLATE_AT.y + h), cy, slab_mat)
	_slab(parent, Vector2(PLATE_AT.x + h, PLATE_AT.y - h), Vector2(50.0, PLATE_AT.y + h), cy, slab_mat)
	# The rails: the deck's north, west and east edges.
	box(parent, Vector3(100.0, 2.0, 1.0), Vector3(0.0, DECK_TOP + 1.0, -89.5), wall_mat)
	box(parent, Vector3(1.0, 2.0, 130.0), Vector3(-49.5, DECK_TOP + 1.0, -25.0), wall_mat)
	box(parent, Vector3(1.0, 2.0, 130.0), Vector3(49.5, DECK_TOP + 1.0, -25.0), wall_mat)
	# The south landing deck.
	_slab(parent, Vector2(-20.0, RAMP_TO), Vector2(20.0, 108.0), cy, slab_mat)
	# The channel's walls: full height under the deck, then the tunnel's walls.
	_wall(parent, CHANNEL_FROM, ROOF_FROM, 12.0, wall_mat)
	_wall(parent, ROOF_FROM, CHANNEL_TO, ROOF_UNDER + 0.5, wall_mat)
	# The tunnel's roof.
	var roof_len := ROOF_TO - ROOF_FROM
	box(parent, Vector3(CHANNEL_HALF * 2.0 + 2.0, 1.0, roof_len), Vector3(0.0, ROOF_UNDER + 0.5, (ROOF_FROM + ROOF_TO) * 0.5), roof_mat)
	# The lit line: a thin seam on the floor along the channel's centre.
	var seam := MeshInstance3D.new()
	var seam_mesh := BoxMesh.new()
	seam_mesh.size = Vector3(0.6, 0.06, CHANNEL_TO - CHANNEL_FROM)
	seam.mesh = seam_mesh
	seam.material_override = seam_mat
	seam.position = Vector3(0.0, 0.04, (CHANNEL_TO + CHANNEL_FROM) * 0.5)
	parent.add_child(seam)
	# The ramp: its top surface runs from (z RAMP_FROM, y 0) to (z RAMP_TO, y DECK_TOP).
	var run := RAMP_TO - RAMP_FROM
	var length := sqrt(run * run + DECK_TOP * DECK_TOP)
	var angle := atan2(DECK_TOP, run)
	var thick := 3.0
	var ramp := box(parent, Vector3(RAMP_HALF * 2.0, thick, length), Vector3.ZERO, slab_mat)
	var mid := Vector3(0.0, DECK_TOP * 0.5, (RAMP_FROM + RAMP_TO) * 0.5)
	var normal := Vector3(0.0, cos(angle), -sin(angle))
	ramp.position = mid - normal * thick * 0.5
	ramp.basis = Basis(Vector3.RIGHT, -angle)
	# The breach plate.
	var plate := Plate.new()
	plate.name = "BreachPlate"
	plate.position = Vector3(PLATE_AT.x, DECK_TOP, PLATE_AT.y)
	plate.size = plate_size
	plate.thickness = DECK_THICK
	plate.threshold = SLAM_BREAK
	parent.add_child(plate)
	# One light in the channel so the roofed stretch is not black.
	var lamp := OmniLight3D.new()
	lamp.light_color = Palette.ANCIENT
	lamp.light_energy = 1.5
	lamp.omni_range = 40.0
	lamp.position = Vector3(0.0, 4.0, 24.0)
	parent.add_child(lamp)


func _slab(parent: Node3D, from: Vector2, to: Vector2, y: float, mat: Material) -> void:
	box(parent, Vector3(to.x - from.x, DECK_THICK, to.y - from.y), Vector3((from.x + to.x) * 0.5, y, (from.y + to.y) * 0.5), mat)


func _wall(parent: Node3D, z0: float, z1: float, height_m: float, mat: Material) -> void:
	for side in [-1.0, 1.0]:
		box(parent, Vector3(1.0, height_m, z1 - z0), Vector3(side * (CHANNEL_HALF + 0.5), height_m * 0.5, (z0 + z1) * 0.5), mat)
