extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")

# Stage 3, the Weir: you land running east down a hill onto the north shelf. The weir
# itself is a long halfpipe cut south through the middle, steep enough at its lips
# for a pylon, which empties into a flooding bowl. East of it a mesa carries the
# relay with pylon walls around its top and a banked berm round its foot; west of it
# a raised causeway runs dry the whole way down. Its events are the Surge Run down
# the weir and Hold the Relay on the mesa, where a miniboss arrives mid-hold.

const DECK_H := 70.0
const NORTH_H := 40.0
const SOUTH_H := 12.0
const PIPE_X := 0.0
const PIPE_Z := Vector2(-86.0, 112.0)
const PIPE_DEPTH := 12.0
const RELAY := Vector2(92.0, -8.0)
const MESA_TOP := 18.0
const MESA_FOOT := 40.0
const MESA_H := 10.0
const BASIN_CENTRE := Vector2(0.0, 136.0)
const BASIN_IN := 22.0
const BASIN_OUT := 56.0
const CAUSEWAY_X := -122.0
const BERM := {"centre": RELAY, "radius": 46.0, "from": -70.0, "to": 70.0}
const BERM_WIDTH := 14.0
const BERM_BANK := 8.0
const KICKERS := [
	{"at": Vector2(-62.0, -24.0), "dir": Vector2(0.0, 1.0), "length": 14.0, "width": 14.0, "lip": 3.5},
	{"at": Vector2(-62.0, 44.0), "dir": Vector2(0.0, 1.0), "length": 12.0, "width": 12.0, "lip": 3.0},
	{"at": Vector2(52.0, -8.0), "dir": Vector2(1.0, 0.0), "length": 12.0, "width": 12.0, "lip": 2.5},
	{"at": Vector2(-40.0, -104.0), "dir": Vector2(1.0, 0.0), "length": 12.0, "width": 14.0, "lip": 3.0},
]


func _init() -> void:
	title = "The Weir"
	spawn = Vector2(-150.0, -110.0)
	heading = Vector3(1.0, 0.0, 0.0)
	beacon = Vector2(-72.0, 76.0)
	play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
	basin = {"centre": BASIN_CENTRE, "radius": BASIN_OUT, "depth": 7.0,
		"plane_size": Vector2(BASIN_OUT * 2.0, BASIN_OUT * 2.0), "plane_centre": BASIN_CENTRE}
	scrap_lines = [
		[Vector2(-138.0, -110.0), Vector2(-80.0, -110.0)],
		[Vector2(-70.0, -110.0), Vector2(60.0, -110.0)],
		[Vector2(0.0, -80.0), Vector2(0.0, 108.0)],
		[Vector2(40.0, -30.0), Vector2(74.0, -10.0)],
		[Vector2(CAUSEWAY_X, -60.0), Vector2(CAUSEWAY_X, 140.0)],
		[Vector2(-62.0, -40.0), Vector2(-62.0, 60.0)],
		[Vector2(132.0, -40.0), Vector2(132.0, 30.0)],
	]
	sites = {
		"surge_run": {
			"ring": Vector2(0.0, -100.0),
			"sway": 5.0,
			"route": PackedVector2Array([
				Vector2(0.0, -92.0), Vector2(-5.0, -56.0), Vector2(5.0, -20.0), Vector2(-5.0, 16.0),
				Vector2(5.0, 52.0), Vector2(0.0, 90.0), Vector2(0.0, 124.0), Vector2(-20.0, 150.0),
			]),
		},
		"hold_the_relay": {"ring": RELAY, "relay": RELAY},
	}


func _wings(z: float) -> float:
	return Features.descent(z, -70.0, 100.0, NORTH_H, SOUTH_H)


func _base(x: float, z: float) -> float:
	var hill := Features.descent(x, -142.0, -80.0, DECK_H, NORTH_H)
	return lerpf(hill, _wings(z), smoothstep(-100.0, -66.0, z))


func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -SOUTH_H * (1.0 - smoothstep(BASIN_IN, BASIN_OUT, d))


func _causeway(x: float, z: float) -> float:
	var adx := absf(x - CAUSEWAY_X)
	return (1.0 - smoothstep(7.0, 12.0, adx)) * smoothstep(-80.0, -56.0, z) * (1.0 - smoothstep(150.0, 170.0, z))


func sample(x: float, z: float) -> Array:
	var h := _base(x, z) + _bowl(x, z)
	var cw := _causeway(x, z)
	h += 6.0 * cw
	h += Features.mesa(x, z, RELAY, MESA_TOP, MESA_FOOT, MESA_H)
	var momentum := 0.0
	var bank := Features.banked_arc(x, z, BERM["centre"], BERM["radius"], BERM_WIDTH, BERM_BANK, BERM["from"], BERM["to"])
	h += bank
	momentum = clampf(bank / 3.0, 0.0, 1.0)
	for k in KICKERS:
		var rise := Features.kicker(x, z, k["at"], k["dir"], k["length"], k["width"], k["lip"])
		h += rise
		momentum = maxf(momentum, clampf(rise, 0.0, 1.0))
	var pipe := 0.0
	var floor_h := Features.halfpipe(x, z, PIPE_X, PIPE_Z.x, PIPE_Z.y, _wings, PIPE_DEPTH, 20.0)
	if floor_h < h:
		pipe = clampf((h - floor_h) / 1.5, 0.0, 1.0)
		h = floor_h
	var hill := (1.0 - smoothstep(-84.0, -76.0, x)) * (1.0 - smoothstep(-96.0, -86.0, z)) * smoothstep(-146.0, -140.0, x)
	h += Features.ripple(x, z) * 0.6 * (1.0 - maxf(pipe, maxf(cw, hill)))
	h += Features.rim(x, z)
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.5)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.25), hill * 0.7)
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), momentum * 0.8)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), pipe * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), cw * 0.85)
	return [h, tint]


func material_at(x: float, z: float) -> String:
	if absf(x - PIPE_X) < PIPE_DEPTH and z > PIPE_Z.x and z < PIPE_Z.y:
		return "concrete"
	return "concrete" if _causeway(x, z) > 0.5 else "sand"


func build_props(parent: Node3D, ground: Callable) -> void:
	box(parent, Vector3(10.0, 1.0, 18.0), ground.call(spawn.x - 4.0, spawn.y, -0.3), Palette.striped(Palette.AMBER, Palette.CHARCOAL))
	# Grapple posts along the weir's lips, alternating sides, so you can swing across it.
	var z := -60.0
	var side := 1.0
	while z < 100.0:
		grapple_post(parent, ground.call(PIPE_X + side * (PIPE_DEPTH + 5.0), z, -0.5), 20.0)
		side = -side
		z += 36.0
	# Four walls round the relay's top, tangent to its ring so circling slides along
	# them rather than into them, each a turret spot for the engineer.
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var at := RELAY + Vector2(cos(angle), sin(angle)) * (MESA_TOP + 2.0)
		pylon_wall(parent, ground.call(at.x, at.y, 0.0), 12.0, 6.0, -angle + PI * 0.5)
	pylon_wall(parent, ground.call(-96.0, 20.0, 0.0), 24.0, 9.0, PI * 0.5)
	pylon_wall(parent, ground.call(40.0, 70.0, 0.0), 20.0, 8.0, 0.3)
