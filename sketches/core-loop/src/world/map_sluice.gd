extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")

# Stage 2, the Sluice: you land on a long hill that turns the launch's fall into
# speed, carve the mid shelf between two banked berms with a kicker on the straight
# line, then drop down two sluice chutes into a real bowl the flood fills. A causeway
# on the east side stays dry above the water. Its own event is the Surge Run down the
# west sluice and around the basin.

const DECK_H := 64.0
const SHELF_TOP := 34.0
const SHELF_LOW := 26.0
const LOW_H := 10.0
const BASIN_CENTRE := Vector2(0.0, 112.0)
const BASIN_IN := 30.0
const BASIN_OUT := 72.0
const CHUTE_XS := [-50.0, 50.0]
const CHUTE_Z := Vector2(-10.0, 46.0)
const CHUTE_DEPTH := 6.0
const CAUSEWAY_X := 128.0
const CAUSEWAY_H := 16.0
const BERMS := [
	{"centre": Vector2(-34.0, -38.0), "radius": 40.0, "from": 100.0, "to": 260.0},
	{"centre": Vector2(34.0, -38.0), "radius": 40.0, "from": -80.0, "to": 80.0},
]
const BERM_WIDTH := 16.0
const BERM_BANK := 10.0
const KICKERS := [
	{"at": Vector2(0.0, -34.0), "dir": Vector2(0.0, 1.0), "length": 14.0, "width": 14.0, "lip": 3.5},
	{"at": Vector2(18.0, 4.0), "dir": Vector2(0.0, 1.0), "length": 12.0, "width": 12.0, "lip": 3.0},
	{"at": Vector2(0.0, 112.0), "dir": Vector2(1.0, 0.0), "length": 12.0, "width": 12.0, "lip": 3.0},
]


func _init() -> void:
	title = "The Sluice"
	spawn = Vector2(0.0, -150.0)
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = Vector2(-62.0, 96.0)
	play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
	basin = {"centre": BASIN_CENTRE, "radius": BASIN_OUT, "depth": 7.0,
		"plane_size": Vector2(BASIN_OUT * 2.0, BASIN_OUT * 2.0), "plane_centre": BASIN_CENTRE}
	scrap_lines = [
		[Vector2(0.0, -138.0), Vector2(0.0, -76.0)],
		[Vector2(-70.0, -60.0), Vector2(-78.0, -14.0)],
		[Vector2(70.0, -60.0), Vector2(78.0, -14.0)],
		[Vector2(-50.0, -8.0), Vector2(-50.0, 44.0)],
		[Vector2(50.0, -8.0), Vector2(50.0, 44.0)],
		[Vector2(-40.0, 150.0), Vector2(40.0, 150.0)],
		[Vector2(CAUSEWAY_X, -60.0), Vector2(CAUSEWAY_X, 140.0)],
		[Vector2(-60.0, 112.0), Vector2(60.0, 112.0)],
	]
	sites = {
		"surge_run": {
			"ring": Vector2(-50.0, -22.0),
			"route": PackedVector2Array([
				Vector2(-50.0, -16.0), Vector2(-50.0, 44.0), Vector2(-36.0, 78.0), Vector2(-8.0, 100.0),
				Vector2(26.0, 108.0), Vector2(52.0, 128.0), Vector2(40.0, 158.0),
			]),
		},
	}


func _profile(z: float) -> float:
	if z < -72.0:
		return Features.descent(z, -142.0, -72.0, DECK_H, SHELF_TOP)
	if z < -4.0:
		return Features.descent(z, -72.0, -4.0, SHELF_TOP, SHELF_LOW)
	return Features.descent(z, -4.0, 44.0, SHELF_LOW, LOW_H)


func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -LOW_H * (1.0 - smoothstep(BASIN_IN, BASIN_OUT, d)) * smoothstep(30.0, 60.0, z)


func _causeway(x: float, z: float) -> float:
	var adx := absf(x - CAUSEWAY_X)
	var w := 1.0 - smoothstep(9.0, 15.0, adx)
	w *= smoothstep(-90.0, -60.0, z) * (1.0 - smoothstep(150.0, 170.0, z))
	return w


func sample(x: float, z: float) -> Array:
	var base := _profile(z) + _bowl(x, z)
	var cw := _causeway(x, z)
	base = lerpf(base, maxf(base, CAUSEWAY_H), cw)
	var momentum := 0.0
	for b in BERMS:
		var bank := Features.banked_arc(x, z, b["centre"], b["radius"], BERM_WIDTH, BERM_BANK, b["from"], b["to"])
		base += bank
		momentum = maxf(momentum, clampf(bank / 3.0, 0.0, 1.0))
	for k in KICKERS:
		var rise := Features.kicker(x, z, k["at"], k["dir"], k["length"], k["width"], k["lip"])
		base += rise
		momentum = maxf(momentum, clampf(rise / 1.0, 0.0, 1.0))
	var chute := 0.0
	for cx in CHUTE_XS:
		var floor_h := Features.halfpipe(x, z, cx, CHUTE_Z.x, CHUTE_Z.y, _profile, CHUTE_DEPTH, 14.0)
		if floor_h < base:
			chute = maxf(chute, clampf((base - floor_h) / 1.5, 0.0, 1.0))
			base = floor_h
	var hill := smoothstep(-146.0, -138.0, z) * (1.0 - smoothstep(-80.0, -70.0, z))
	base += Features.ripple(x, z) * 0.6 * (1.0 - maxf(chute, maxf(cw, hill)))
	base += Features.rim(x, z)
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.4)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.25), hill * 0.7)
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), momentum * 0.8)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), chute * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), cw * 0.85)
	return [base, tint]


func material_at(x: float, z: float) -> String:
	for cx in CHUTE_XS:
		if absf(x - cx) < CHUTE_DEPTH and z > CHUTE_Z.x and z < CHUTE_Z.y:
			return "concrete"
	return "concrete" if _causeway(x, z) > 0.5 else "sand"


func build_props(parent: Node3D, ground: Callable) -> void:
	var rust := Palette.solid(Palette.RUST)
	# The launch deck the next stage drops you onto: a lit apron so the landing reads.
	box(parent, Vector3(18.0, 1.0, 10.0), ground.call(spawn.x, spawn.y - 6.0, -0.3), Palette.striped(Palette.AMBER, Palette.CHARCOAL))
	for x in [-30.0, 30.0]:
		grapple_post(parent, ground.call(x, -66.0, -0.5), 18.0)
	for x in [-45.0, -15.0, 15.0, 45.0]:
		grapple_post(parent, ground.call(x, 112.0, -0.5), 24.0)
	# Retaining walls down each sluice's outer lip: sheer faces for a pylon.
	for cx in CHUTE_XS:
		var side: float = signf(cx)
		pylon_wall(parent, ground.call(cx + side * (CHUTE_DEPTH + 3.0), 20.0, 0.0), 30.0, 7.0, PI * 0.5)
	pylon_wall(parent, ground.call(-92.0, 80.0, 0.0), 22.0, 8.0, 0.6)
	pylon_wall(parent, ground.call(-30.0, 60.0, 0.0), 18.0, 6.0, -0.4)
	# Kerbs on the causeway's ends mark it as the dry way down.
	for z in [-70.0, 150.0]:
		box(parent, Vector3(2.0, 2.4, 10.0), ground.call(CAUSEWAY_X - 10.0, z, 0.4), rust)
		box(parent, Vector3(2.0, 2.4, 10.0), ground.call(CAUSEWAY_X + 10.0, z, 0.4), rust)
