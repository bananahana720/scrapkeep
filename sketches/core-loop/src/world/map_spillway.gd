extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")
const LocalMesh := preload("res://src/world/local_mesh.gd")

# Stage 1, the Spillway's top shelf: the wave-1 shelves, chutes, flooding basin and
# dry east bypass, laid on a fall line. You drop onto a deck on the top shelf, roll
# down the west chute and meet the Warden in a banked bowl at the foot of the riser.
# Its own event is the Scrap Stampede: a hauler bolts from the pump house, down the
# east chute and into the basin, and you run it down. The vault sits on a plinth on
# the top shelf, east of the line.

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
# The fall line: a drop deck on the top shelf, down the west chute, into the beacon
# bowl at the foot of the riser.
const SPAWN := Vector2(-62.0, -160.0)
const BEACON := Vector2(-46.0, -12.0)
const DECK := {"top": 10.0, "foot": 44.0, "height": 10.0}
const PLINTH := {"top": 6.0, "foot": 20.0, "height": 3.0}
const STAMPEDE_RING := Vector2(14.0, -112.0)

# The v3 loop (LOOP-REDESIGN section 3, stage 1), live only in a loop mode (loop_mode.gd).
# Two drop lines come down off the top shelf into the Warden's bowl from the north, each
# ending in an amber kicker lip on the bowl floor aimed at the mast: the west chute
# (fast) and the long line past the stampede ring down the riser (long, a higher lip).
# The return is a steam lift on the bowl's south bank that throws the ball back over the
# Warden to the top shelf's east landing beside the vault plinth. Gravity is 26 m/s^2,
# so a lip can only reach the mast from close in: the lips stand on the bowl floor and
# the shelf's height is what brings the speed.
const LIP_REACH := 19.0
const RETURN_AT := Vector2(-46.0, 22.0)
const RETURN_TO := Vector2(-24.0, -104.0)
const RETURN_FLOOR := 30.0
const LOOP_LINES := [
	{"id": "west_chute", "kind": "fast", "start": Vector2(-62.0, -92.0), "via": [Vector2(-62.0, -66.0), Vector2(-57.0, -46.0)],
		"width": 9.0, "length": 10.0, "lip": 2.5},
	{"id": "east_riser", "kind": "long", "start": Vector2(10.0, -100.0), "via": [Vector2(-4.0, -72.0), Vector2(-22.0, -48.0)],
		"width": 9.0, "length": 11.0, "lip": 3.2},
]


func _init() -> void:
	title = "Spillway: the top shelf"
	spawn = SPAWN
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = BEACON
	beacon_floor = MID_H
	vault = Vector2(-5.0, -130.0)
	play_rect = Rect2(-105.0, -178.0, 257.0, 356.0)
	basin = {"centre": BASIN_CENTRE, "radius": 95.0, "depth": 7.0,
		"plane_size": Vector2(300.0, 130.0), "plane_centre": Vector2(0.0, 120.0)}
	# Every line runs along the fall line from the drop deck down the west chute.
	scrap_lines = [
		[Vector2(-60.0, -142.0), Vector2(-57.0, -104.0)],
		[Vector2(-62.0, -78.0), Vector2(-60.0, -36.0)],
		[Vector2(-42.0, -122.0), Vector2(-40.0, -84.0)],
		[Vector2(-72.0, -112.0), Vector2(-70.0, -74.0)],
	]
	sites = {
		"scrap_stampede": {
			"ring": STAMPEDE_RING,
			"route": PackedVector2Array([
				Vector2(24.0, -104.0), Vector2(46.0, -94.0), Vector2(54.0, -80.0), Vector2(54.0, -24.0),
				Vector2(62.0, -12.0), Vector2(90.0, -12.0), Vector2(96.0, 14.0), Vector2(96.0, 78.0),
				Vector2(78.0, 104.0), Vector2(40.0, 128.0), Vector2(6.0, 140.0),
			]),
		},
	}
	unique_events = ["scrap_stampede"]
	_loop_specs()


# Contraption specs (contraptions.gd), live only in a loop mode.
var contraptions: Array = []
var contraptions_need_loop := true
# The loop's lips as pre-built colliders, parked until a loop mode is on.
var swaps := {}


func _loop_specs() -> void:
	var mast := BEACON
	for spec in LOOP_LINES:
		var line: Dictionary = spec.duplicate(true)
		var from: Vector2 = (spec["via"] as Array)[-1]
		var dir := (mast - from).normalized()
		line["dir"] = dir
		line["at"] = mast - dir * LIP_REACH
		line["target"] = mast
		drop_lines.append(line)
	return_at = RETURN_AT
	return_to = RETURN_TO
	loop = PackedVector2Array([RETURN_TO, drop_lines[0]["start"]] + drop_lines[0]["via"] + [drop_lines[0]["at"], mast, RETURN_AT, RETURN_TO])
	contraptions = [
		{"kind": "launcher", "id": "return_lift", "style": "steam_lift", "at": RETURN_AT, "radius": 5.0,
			"target": Vector3(RETURN_TO.x, sample(RETURN_TO.x, RETURN_TO.y)[0] + 1.0, RETURN_TO.y), "floor": RETURN_FLOOR,
			"min_flight": 0.5, "charge": 1.2},
	]


func apply_swap(id: String, changed: bool) -> void:
	move_swap(swaps, id, changed)


func overlay_height(id: String, x: float, z: float, ground: float) -> float:
	if id != LOOP_SWAP + "_after":
		return -INF
	var lip := drop_lip_height(x, z)
	return ground + lip if lip > 0.0 else -INF


func sample(x: float, z: float) -> Array:
	var h := _shelf(z) + _bowl(x, z)
	var by := _bypass(x, z)
	h = lerpf(h, by[0], by[1])
	var ch := _chutes(x, z)
	h = lerpf(h, ch[0], ch[1])
	h += Features.ripple(x, z) * (1.0 - maxf(by[1], ch[1]))
	var deck := Features.mesa(x, z, SPAWN, DECK["top"], DECK["foot"], DECK["height"])
	h += deck
	for spot in [vault, STAMPEDE_RING]:
		h += Features.mesa(x, z, spot, PLINTH["top"], PLINTH["foot"], PLINTH["height"])
	h = Features.beacon_bowl(x, z, BEACON, beacon_floor, h)
	h += maxf(Features.rim(x, z), 78.0 * (1.0 - smoothstep(-158.0, -116.0, x)))
	var bank := clampf((Vector2(x, z).distance_to(BEACON) - Features.BOWL_FLAT) / 16.0, 0.0, 1.0) \
		* (1.0 - smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, Vector2(x, z).distance_to(BEACON)))
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.35)
	tint = tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), ch[1] * 0.9)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.RUST, 0.3), by[1] * 0.85)
	tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.25), clampf(deck / 4.0, 0.0, 0.7))
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), bank * 0.8)
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

	# Two mid-shelf benches, clear of the beacon bowl: low lips to launch off.
	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(24.0, 22.0, 0.6), concrete)
	box(parent, Vector3(26.0, 3.0, 9.0), ground.call(66.0, 2.0, 0.6), concrete)
	_build_lips(parent, ground)


# Each drop line's lip as one trimesh over the ground (local_mesh.gd), amber where it
# rises (writer D's movement colour, never HAZARD), parked until a loop mode swaps it in.
func _build_lips(parent: Node3D, ground: Callable) -> void:
	var lips: Array = []
	for line in drop_lines:
		var at: Vector2 = line["at"]
		var dir: Vector2 = line["dir"]
		var side := Vector2(-dir.y, dir.x)
		var half_w: float = float(line["width"]) * 0.5 + 4.0
		var box_min := Vector2.INF
		var box_max := -Vector2.INF
		for u in [-float(line["length"]), 5.0]:
			for w in [-half_w, half_w]:
				var corner: Vector2 = at + dir * u + side * w
				box_min = Vector2(minf(box_min.x, corner.x), minf(box_min.y, corner.y))
				box_max = Vector2(maxf(box_max.x, corner.x), maxf(box_max.y, corner.y))
		var centre := (box_min + box_max) * 0.5
		var holder := Node3D.new()
		holder.name = "DropLip_" + String(line["id"])
		holder.position = Vector3(centre.x, 0.0, centre.y)
		parent.add_child(holder)
		var rise := func(u: float, v: float) -> float:
			return Features.kicker(centre.x + u, centre.y + v, at, dir, line["length"], line["width"], line["lip"])
		var height := func(u: float, v: float) -> float:
			return (ground.call(centre.x + u, centre.y + v, 0.0) as Vector3).y + rise.call(u, v) + 0.03
		var tint := func(u: float, v: float) -> Color:
			var floor_tint: Color = sample(centre.x + u, centre.y + v)[1]
			return floor_tint.lerp(Palette.AMBER, clampf(rise.call(u, v) * 2.0, 0.0, 1.0))
		LocalMesh.grid(holder, "Lip", box_max - box_min, 1.0, height, tint)
		holder.set_meta("home", holder.position)
		lips.append(holder)
	swaps = {LOOP_SWAP: {"before": [], "after": lips}}
	apply_swap(LOOP_SWAP, false)
