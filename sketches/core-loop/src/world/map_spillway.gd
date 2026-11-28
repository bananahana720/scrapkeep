extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")


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
const SPAWN := Vector2(-62.0, -160.0)
const BEACON := Vector2(-46.0, -12.0)
const DECK := {"top": 10.0, "foot": 44.0, "height": 10.0}
const PLINTH := {"top": 6.0, "foot": 20.0, "height": 3.0}
const STAMPEDE_RING := Vector2(14.0, -112.0)
const PIPE_X := -62.0
const PIPE_Z := Vector2(-128.0, -82.0)
const PIPE_DEPTH := 12.0
const PIPE_FADE := 40.0
const PIPE_HEAD_FADE := 32.0
const RELAY := Vector2(10.0, -84.0)
const MESA_TOP := 18.0
const MESA_FOOT := 40.0
const MESA_H := 10.0
const CAUSEWAY_X := -94.0
const CAUSEWAY_Z := Vector2(-132.0, -18.0)
const CAUSEWAY_H := 6.0

var rescue_sites: Array = []


func _init() -> void:
	title = "Spillway: the top shelf"
	spawn = SPAWN
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = BEACON
	beacon_floor = MID_H
	vault = Vector2(-5.0, -130.0)
	play_rect = Rect2(-105.0, -178.0, 257.0, 356.0)
	scatter["relief"] = {"sub": 2, "amp": 0.12, "period": 3.0, "shade": 0.35, "seed": "relief_spillway"}
	scatter["kit"] = [
		{"kind": "rock", "density": 0.3, "scale": Vector2(0.9, 1.9), "slope": 0.8, "bury": 0.4, "seed": "scatter_spillway_boulder", "mesh": "kit:rubble", "slot": "stone"},
		{"kind": "rock", "density": 0.5, "scale": Vector2(0.4, 0.9), "slope": 0.8, "bury": 0.35, "seed": "scatter_spillway_rock", "mesh": "kit:rubble", "slot": "stone"},
		{"kind": "scrap", "density": 0.06, "scale": Vector2(0.5, 0.9), "slope": 0.85, "bury": 0.3, "seed": "scatter_spillway_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
		{"kind": "cable", "density": 0.08, "scale": Vector2(0.8, 1.3), "slope": 0.9, "bury": 0.4, "seed": "scatter_spillway_cable", "mesh": "prim:coil", "slot": "cable"},
	]
	basin = {"centre": BASIN_CENTRE, "radius": 95.0, "depth": 7.0,
		"plane_size": Vector2(300.0, 130.0), "plane_centre": Vector2(0.0, 120.0)}
	scrap_lines = [
		[Vector2(-60.0, -142.0), Vector2(-57.0, -104.0)],
		[Vector2(-62.0, -78.0), Vector2(-60.0, -36.0)],
		[Vector2(-42.0, -122.0), Vector2(-40.0, -84.0)],
		[Vector2(-72.0, -112.0), Vector2(-70.0, -74.0)],
	]
	sites = {
		"hold_the_relay": {"ring": RELAY, "relay": RELAY},
		"scrap_stampede": {
			"ring": STAMPEDE_RING,
			"route": PackedVector2Array([
				Vector2(24.0, -104.0), Vector2(46.0, -94.0), Vector2(54.0, -80.0), Vector2(54.0, -24.0),
				Vector2(62.0, -12.0), Vector2(90.0, -12.0), Vector2(96.0, 14.0), Vector2(96.0, 78.0),
				Vector2(78.0, 104.0), Vector2(40.0, 128.0), Vector2(6.0, 140.0),
			]),
		},
	}
	unique_events = ["scrap_stampede", "hold_the_relay"]
	activity_sites = [{"id": "enemy_camp", "at": Vector2(96.0, -120.0), "pack": ["chaser", "chaser", "chaser"], "pay": {"named": "hot_rivets"}}]
	rescue_sites = [{"id": "rivet_cage", "quest": "rivet", "prompt": "free the runner", "at": Vector2(60.0, -150.0), "face": Vector2(-1.0, 0.0)}]


func sample(x: float, z: float) -> Array:
	var h := _shelf(z) + _bowl(x, z)
	var by := _bypass(x, z)
	h = lerpf(h, by[0], by[1])
	var ch := _chutes(x, z)
	h = lerpf(h, ch[0], ch[1])
	var cw := _causeway(x, z)
	h = lerpf(h, _bypass_deck(z) + CAUSEWAY_H, cw)
	var pipe := _halfpipe(x, z)
	var pipe_weight := 0.0
	if pipe < h:
		pipe_weight = clampf((h - pipe) / 1.5, 0.0, 1.0)
		h = pipe
	h += Features.ripple(x, z) * (1.0 - maxf(maxf(by[1], ch[1]), maxf(cw, pipe_weight)))
	var deck := Features.mesa(x, z, SPAWN, DECK["top"], DECK["foot"], DECK["height"])
	h += deck
	var mesa := Features.mesa(x, z, RELAY, MESA_TOP, MESA_FOOT, MESA_H)
	h += mesa
	for spot in [vault, STAMPEDE_RING]:
		h += Features.mesa(x, z, spot, PLINTH["top"], PLINTH["foot"], PLINTH["height"])
	h = Features.beacon_bowl(x, z, BEACON, beacon_floor, h)
	h += maxf(Features.rim(x, z), 78.0 * (1.0 - smoothstep(-158.0, -116.0, x)))
	var bank := clampf((Vector2(x, z).distance_to(BEACON) - Features.BOWL_FLAT) / 16.0, 0.0, 1.0) \
		* (1.0 - smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, Vector2(x, z).distance_to(BEACON)))
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.35)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), maxf(ch[1], pipe_weight) * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), maxf(by[1], cw) * 0.85)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.25), clampf(deck / 4.0, 0.0, 0.7))
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), clampf(mesa / MESA_H, 0.0, 1.0) * 0.7)
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), bank * 0.8)
	return [h, tint]


func material_at(x: float, z: float) -> String:
	return "concrete" if _chutes(x, z)[1] > 0.5 or _bypass(x, z)[1] > 0.5 \
		or _causeway(x, z) > 0.5 or _halfpipe(x, z) < _shelf(z) - 0.5 else "sand"


static func _halfpipe(x: float, z: float) -> float:
	var floor_h := Features.halfpipe(x, z, PIPE_X, PIPE_Z.x, PIPE_Z.y, _shelf, PIPE_DEPTH, PIPE_FADE)
	if floor_h == INF:
		return INF
	return lerpf(_shelf(z), floor_h, smoothstep(PIPE_Z.x - PIPE_DEPTH, PIPE_Z.x - PIPE_DEPTH + PIPE_HEAD_FADE, z))


static func _causeway(x: float, z: float) -> float:
	return (1.0 - smoothstep(7.0, 12.0, absf(x - CAUSEWAY_X))) \
		* smoothstep(CAUSEWAY_Z.x, CAUSEWAY_Z.x + 32.0, z) \
		* (1.0 - smoothstep(CAUSEWAY_Z.y - 24.0, CAUSEWAY_Z.y, z))


static func _shelf(z: float) -> float:
	var h := lerpf(TOP_H, MID_H, smoothstep(RISER_TOP.x, RISER_TOP.y, z))
	return lerpf(h, BASIN_H, smoothstep(RISER_MID.x, RISER_MID.y, z))


static func _bowl(x: float, z: float) -> float:
	var d := Vector2(x, z).distance_to(BASIN_CENTRE)
	return -BASIN_BOWL * (1.0 - smoothstep(25.0, 85.0, d)) * smoothstep(52.0, 70.0, z)


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
	var deck: float = lerpf(c["h0"], c["h1"], lerpf(t, smoothstep(0.0, 1.0, t), 0.3)) - CHUTE_SINK
	var arc: float = minf(adx, CHUTE_R)
	var cross: float = CHUTE_BOWL - sqrt(CHUTE_BOWL * CHUTE_BOWL - arc * arc)
	if adx > CHUTE_R:
		cross += (adx - CHUTE_R) * 1.1
	return [deck + cross, w]


func build_props(parent: Node3D, ground: Callable) -> void:
	var concrete := PaletteMaterials.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	var copper := PaletteMaterials.solid(Palette.COPPER)
	var rust := PaletteMaterials.solid(Palette.RUST)

	var house: Vector3 = ground.call(PUMP_HOUSE.x, PUMP_HOUSE.y, 0.0)
	box(parent, Vector3(22.0, 11.0, 15.0), house + Vector3.UP * 5.0, concrete)
	box(parent, Vector3(24.0, 1.2, 17.0), house + Vector3.UP * 11.2, PaletteMaterials.solid(Palette.VERDIGRIS))
	for dx in [-7.0, 7.0]:
		cylinder(parent, 1.9, 9.0, house + Vector3(dx, 16.0, -4.0), copper)

	for c in CHUTES:
		var mouth_z: float = c["z0"] - 3.0
		for side in [-1.0, 1.0]:
			var kx: float = c["x"] + side * (CHUTE_R + 3.0)
			box(parent, Vector3(2.0, 2.4, 16.0), ground.call(kx, mouth_z, 0.4), rust)

	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(24.0, 22.0, 0.6), concrete)
	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(66.0, 2.0, 0.6), concrete)

	for i in 4:
		var angle := PI * 0.25 + i * PI * 0.5
		var at := RELAY + Vector2(cos(angle), sin(angle)) * (MESA_TOP + 2.0)
		pylon_wall(parent, ground.call(at.x, at.y, 0.0), 12.0, 6.0, -angle + PI * 0.5)
	load("res://src/presentation/spillway_scenery.gd").dress_props(parent)
