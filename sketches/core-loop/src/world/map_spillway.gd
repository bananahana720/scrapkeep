extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")

# Stage 1, the Spillway's top shelf: the wave-1 map, unchanged in shape. Shelves step
# down through chutes to a flooding basin, with a dry bypass deck on the east side.
# Its own event is the Scrap Stampede: a hauler bolts from the pump house, down the
# east chute and into the basin, and you run it down.

const TOP_H := 30.0
const MID_H := 15.0
const BASIN_H := 0.0
const RISER_TOP := Vector2(-57.0, -47.0)
const RISER_MID := Vector2(41.0, 51.0)
const BASIN_CENTRE := Vector2(0.0, 110.0)
const BASIN_BOWL := 3.5

const CHUTE_R := 13.0
const CHUTE_OUTER := 24.0
const CHUTE_BOWL := 17.0
const CHUTE_SINK := 3.0
const CHUTES := [
	{"x": -62.0, "z0": -78.0, "z1": -24.0, "h0": TOP_H, "h1": MID_H},
	{"x": 54.0, "z0": -78.0, "z1": -24.0, "h0": TOP_H, "h1": MID_H},
	{"x": -18.0, "z0": 20.0, "z1": 76.0, "h0": MID_H, "h1": BASIN_H},
	{"x": 96.0, "z0": 20.0, "z1": 76.0, "h0": MID_H, "h1": BASIN_H},
]

const BYPASS_X := 140.0
const BYPASS_FLAT := 9.0
const BYPASS_OUTER := 22.0
const PUMP_HOUSE := Vector2(34.0, -148.0)


func _init() -> void:
	title = "Spillway: the top shelf"
	spawn = Vector2(-62.0, -96.0)
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = Vector2(-30.0, 2.0)
	play_rect = Rect2(-105.0, -178.0, 257.0, 356.0)
	basin = {"centre": BASIN_CENTRE, "radius": 95.0, "depth": 7.0,
		"plane_size": Vector2(300.0, 130.0), "plane_centre": Vector2(0.0, 120.0)}
	scrap_lines = [
		[Vector2(-62.0, -82.0), Vector2(-62.0, -10.0)],
		[Vector2(54.0, -82.0), Vector2(54.0, -10.0)],
		[Vector2(-18.0, 16.0), Vector2(-18.0, 90.0)],
		[Vector2(96.0, 16.0), Vector2(96.0, 90.0)],
		[Vector2(140.0, 110.0), Vector2(140.0, -92.0)],
		[Vector2(-56.0, -104.0), Vector2(30.0, -142.0)],
		[Vector2(-88.0, -4.0), Vector2(86.0, 2.0)],
		[Vector2(-96.0, 88.0), Vector2(-20.0, 140.0)],
		[Vector2(30.0, 142.0), Vector2(100.0, 120.0)],
	]
	sites = {
		"scrap_stampede": {
			"ring": Vector2(14.0, -112.0),
			"route": PackedVector2Array([
				Vector2(24.0, -104.0), Vector2(46.0, -94.0), Vector2(54.0, -80.0), Vector2(54.0, -24.0),
				Vector2(62.0, -12.0), Vector2(90.0, -12.0), Vector2(96.0, 14.0), Vector2(96.0, 78.0),
				Vector2(78.0, 104.0), Vector2(40.0, 128.0), Vector2(6.0, 140.0),
			]),
		},
	}
	unique_events = ["scrap_stampede"]


func sample(x: float, z: float) -> Array:
	var h := _shelf(z) + _bowl(x, z)
	var by := _bypass(x, z)
	h = lerpf(h, by[0], by[1])
	var ch := _chutes(x, z)
	h = lerpf(h, ch[0], ch[1])
	h += Features.ripple(x, z) * (1.0 - maxf(by[1], ch[1]))
	h += maxf(Features.rim(x, z), 78.0 * (1.0 - smoothstep(-158.0, -116.0, x)))
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.35)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), ch[1] * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), by[1] * 0.85)
	return [h, tint]


func material_at(x: float, z: float) -> String:
	return "concrete" if _chutes(x, z)[1] > 0.5 or _bypass(x, z)[1] > 0.5 else "sand"


static func _shelf(z: float) -> float:
	var h := lerpf(TOP_H, MID_H, smoothstep(RISER_TOP.x, RISER_TOP.y, z))
	return lerpf(h, BASIN_H, smoothstep(RISER_MID.x, RISER_MID.y, z))


static func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -BASIN_BOWL * (1.0 - smoothstep(25.0, 85.0, d)) * smoothstep(52.0, 70.0, z)


# The deck is flat on every shelf and inclined only across the risers, so the
# bypass never floats above the ground it is supposed to connect.
static func _bypass_deck(z: float) -> float:
	if z >= 105.0:
		return BASIN_H
	if z >= 35.0:
		return lerpf(MID_H, BASIN_H, (z - 35.0) / 70.0)
	if z >= -15.0:
		return MID_H
	if z >= -85.0:
		return lerpf(MID_H, TOP_H, (-15.0 - z) / 70.0)
	return TOP_H


static func _bypass(x: float, z: float) -> Array:
	var adx := absf(x - BYPASS_X)
	if adx > BYPASS_OUTER:
		return [0.0, 0.0]
	var w := 1.0 - smoothstep(BYPASS_FLAT + 5.0, BYPASS_OUTER, adx)
	w *= 1.0 - smoothstep(150.0, 178.0, z)
	w *= smoothstep(-162.0, -130.0, z)
	if w <= 0.0:
		return [0.0, 0.0]
	var lip := 0.0
	if adx > BYPASS_FLAT:
		lip = minf((adx - BYPASS_FLAT) * 1.3, 6.0)
	return [_bypass_deck(z) + lip, w]


static func _chutes(x: float, z: float) -> Array:
	var best := [0.0, 0.0]
	for c in CHUTES:
		var r := _chute(c, x, z)
		if r[1] > best[1]:
			best = r
	return best


static func _chute(c: Dictionary, x: float, z: float) -> Array:
	var adx: float = absf(x - c["x"])
	if adx > CHUTE_OUTER:
		return [0.0, 0.0]
	var w: float = 1.0 - smoothstep(CHUTE_R + 4.0, CHUTE_OUTER, adx)
	w *= smoothstep(c["z0"] - 16.0, c["z0"] - 2.0, z)
	w *= 1.0 - smoothstep(c["z1"] + 2.0, c["z1"] + 16.0, z)
	if w <= 0.0:
		return [0.0, 0.0]
	var t: float = clampf(inverse_lerp(c["z0"], c["z1"], z), 0.0, 1.0)
	# Mostly linear: a smoothstepped floor is flat at both ends, and a fast lane
	# that does not pitch over until its middle never gets the ball moving.
	var deck: float = lerpf(c["h0"], c["h1"], lerpf(t, smoothstep(0.0, 1.0, t), 0.3)) - CHUTE_SINK
	var arc: float = minf(adx, CHUTE_R)
	var cross: float = CHUTE_BOWL - sqrt(CHUTE_BOWL * CHUTE_BOWL - arc * arc)
	if adx > CHUTE_R:
		cross += (adx - CHUTE_R) * 1.1
	return [deck + cross, w]


func build_props(parent: Node3D, ground: Callable) -> void:
	var concrete := Palette.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	var copper := Palette.solid(Palette.COPPER)
	var rust := Palette.solid(Palette.RUST)

	var house: Vector3 = ground.call(PUMP_HOUSE.x, PUMP_HOUSE.y, 0.0)
	box(parent, Vector3(22.0, 11.0, 15.0), house + Vector3.UP * 5.0, concrete)
	box(parent, Vector3(24.0, 1.2, 17.0), house + Vector3.UP * 11.2, Palette.solid(Palette.VERDIGRIS))
	for dx in [-7.0, 7.0]:
		cylinder(parent, 1.9, 9.0, house + Vector3(dx, 16.0, -4.0), copper)

	# Kerbs flank each chute mouth so the fast lane reads as an entrance, not a dip.
	for c in CHUTES:
		var mouth_z: float = c["z0"] - 3.0
		for side in [-1.0, 1.0]:
			var kx: float = c["x"] + side * (CHUTE_R + 3.0)
			box(parent, Vector3(2.0, 2.4, 16.0), ground.call(kx, mouth_z, 0.4), rust)

	# Two mid-shelf benches: low lips to carry a scrap line and launch off.
	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(-58.0, -4.0, 0.6), concrete)
	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(66.0, 2.0, 0.6), concrete)
