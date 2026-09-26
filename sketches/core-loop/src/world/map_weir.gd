extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")

# Stage 3, the Weir: the fall line is the weir itself. You land on a hill that drops
# you into the head of a long halfpipe cut south through the middle, steep enough at
# its lips for a pylon, and pump down it to the Warden in a banked bowl two-thirds of
# the way down; past the bowl the weir empties into a flooding basin. West of the weir
# the Surge Run rides the wing over two kickers; east of it a mesa carries the relay,
# with pylon walls round its top and a berm round its foot, and the vault sits on a
# plinth up the west wing. A raised causeway runs dry down the far west.

const DECK_H := 70.0
const WING_TOP := 44.0
const SOUTH_H := 12.0
const SPAWN := Vector2(30.0, -150.0)
const BEACON := Vector2(30.0, 40.0)
const BEACON_FLOOR := 10.0
const VAULT := Vector2(-40.0, -90.0)
const PIPE_X := 30.0
const PIPE_Z := Vector2(-92.0, 130.0)
const PIPE_DEPTH := 12.0
const RELAY := Vector2(92.0, -8.0)
const MESA_TOP := 18.0
const MESA_FOOT := 40.0
const MESA_H := 10.0
const BASIN_CENTRE := Vector2(30.0, 156.0)
const BASIN_IN := 18.0
const BASIN_OUT := 44.0
const CAUSEWAY_X := -122.0
const BERM := {"centre": RELAY, "radius": 46.0, "from": -70.0, "to": 70.0}
const BERM_WIDTH := 14.0
const BERM_BANK := 8.0
const KICKERS := [
	{"at": Vector2(-62.0, -24.0), "dir": Vector2(0.0, 1.0), "length": 14.0, "width": 14.0, "lip": 3.5},
	{"at": Vector2(-62.0, 44.0), "dir": Vector2(0.0, 1.0), "length": 12.0, "width": 12.0, "lip": 3.0},
	{"at": Vector2(52.0, -8.0), "dir": Vector2(1.0, 0.0), "length": 12.0, "width": 12.0, "lip": 2.5},
]
const PLINTH := {"top": 6.0, "foot": 20.0, "height": 3.0}


func _init() -> void:
	title = "The Weir"
	spawn = SPAWN
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = BEACON
	beacon_floor = BEACON_FLOOR
	vault = VAULT
	play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
	basin = {"centre": BASIN_CENTRE, "radius": BASIN_OUT, "depth": 7.0,
		"plane_size": Vector2(BASIN_OUT * 2.0, BASIN_OUT * 2.0), "plane_centre": BASIN_CENTRE}
	for k in KICKERS:
		kickers.append({"at": k["at"], "dir": k["dir"], "width": k["width"]})
	# Every line runs along the fall line: the landing hill, then down the weir.
	scrap_lines = [
		[Vector2(30.0, -138.0), Vector2(30.0, -104.0)],
		[Vector2(30.0, -86.0), Vector2(30.0, -40.0)],
		[Vector2(22.0, -70.0), Vector2(22.0, -20.0)],
		[Vector2(38.0, -60.0), Vector2(38.0, -10.0)],
	]
	sites = {
		"surge_run": {
			"ring": Vector2(-62.0, -62.0),
			"route": PackedVector2Array([
				Vector2(-62.0, -56.0), Vector2(-62.0, -10.0), Vector2(-62.0, 50.0), Vector2(-58.0, 90.0),
				Vector2(-30.0, 124.0), Vector2(8.0, 152.0),
			]),
		},
		"hold_the_relay": {"ring": RELAY, "relay": RELAY},
	}


func _profile(z: float) -> float:
	if z < -96.0:
		return Features.descent(z, -142.0, -96.0, DECK_H, WING_TOP)
	return Features.descent(z, -96.0, 110.0, WING_TOP, SOUTH_H)


func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -SOUTH_H * (1.0 - smoothstep(BASIN_IN, BASIN_OUT, d))


func _causeway(x: float, z: float) -> float:
	var adx := absf(x - CAUSEWAY_X)
	return (1.0 - smoothstep(7.0, 12.0, adx)) * smoothstep(-80.0, -56.0, z) * (1.0 - smoothstep(150.0, 170.0, z))


func sample(x: float, z: float) -> Array:
	var h := _profile(z) + _bowl(x, z)
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
	var floor_h := Features.halfpipe(x, z, PIPE_X, PIPE_Z.x, PIPE_Z.y, _profile, PIPE_DEPTH, 20.0)
	if floor_h < h:
		pipe = clampf((h - floor_h) / 1.5, 0.0, 1.0)
		h = floor_h
	var hill := smoothstep(-146.0, -138.0, z) * (1.0 - smoothstep(-100.0, -92.0, z))
	h += Features.ripple(x, z) * 0.6 * (1.0 - maxf(pipe, maxf(cw, hill)))
	h += Features.mesa(x, z, VAULT, PLINTH["top"], PLINTH["foot"], PLINTH["height"])
	h = Features.beacon_bowl(x, z, BEACON, BEACON_FLOOR, h)
	h += Features.rim(x, z)
	var d := Vector2(x, z).distance_to(BEACON)
	var bowl := clampf((d - Features.BOWL_FLAT) / 16.0, 0.0, 1.0) * (1.0 - smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, d))
	pipe *= smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, d)
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.5)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.25), hill * 0.7)
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), maxf(momentum, bowl) * 0.8)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), pipe * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), cw * 0.85)
	return [h, tint]


func material_at(x: float, z: float) -> String:
	if absf(x - PIPE_X) < PIPE_DEPTH and z > PIPE_Z.x and z < PIPE_Z.y and Vector2(x, z).distance_to(BEACON) > Features.BOWL_RIM:
		return "concrete"
	return "concrete" if _causeway(x, z) > 0.5 else "sand"


func build_props(parent: Node3D, ground: Callable) -> void:
	box(parent, Vector3(18.0, 1.0, 10.0), ground.call(spawn.x, spawn.y - 6.0, -0.3), Palette.striped(Palette.AMBER, Palette.CHARCOAL))
	# Grapple posts along the weir's lips, alternating sides, so you can swing across
	# it; none stands in the Warden's bowl.
	var z := -60.0
	var side := 1.0
	while z < 130.0:
		var foot := Vector2(PIPE_X + side * (PIPE_DEPTH + 5.0), z)
		if foot.distance_to(BEACON) > Features.BOWL_OUT:
			grapple_post(parent, ground.call(foot.x, foot.y, -0.5), 20.0)
		side = -side
		z += 36.0
	# Four walls round the relay's top, tangent to its ring so circling slides along
	# them rather than into them, each a turret spot for the engineer.
	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var at := RELAY + Vector2(cos(angle), sin(angle)) * (MESA_TOP + 2.0)
		pylon_wall(parent, ground.call(at.x, at.y, 0.0), 12.0, 6.0, -angle + PI * 0.5)
	pylon_wall(parent, ground.call(-96.0, 20.0, 0.0), 24.0, 9.0, PI * 0.5)
	pylon_wall(parent, ground.call(76.0, 72.0, 0.0), 20.0, 8.0, 0.3)
