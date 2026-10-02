extends "res://src/world/map_gorge.gd"

# The slice table's Cable Reach: the gorge's own ground, towers, bridges and tunnels, with
# three authored lines of chained rides from the spawn to the Warden. Sable's marble run
# pours into tunnel w1; Rivet and Kest take the cable down the east shelf, and Rivet breaks
# the cracked wall into tunnel e1 while Kest runs the skylight halfpipe and a new berm onto
# the bowl's bank. Both low lines share one kicker on the bowl's north bank that throws the
# ball at the Warden. The Warden's site has four swing pillars, and the reward gates stand
# in a fixed row south of it where the workshop bay always docks. The barges, lifts, cannon,
# trebuchet, geyser, sky dish, valves and terrain events are not built here; the three-stage
# game's gorge is unchanged (map_gorge.gd).

const REACH_MARBLE := [Vector2(-94.0, -122.0), Vector2(-120.0, -98.0), Vector2(-122.0, -72.0), Vector2(-100.0, -54.0),
	Vector2(-78.0, -44.0), Vector2(-66.0, -30.0), Vector2(-58.0, -10.0)]

const BERM_CENTRE := Vector2(29.0, 90.0)
const BERM_RADIUS := 40.0
const BERM_WIDTH := 12.0
const BERM_BANK := 10.0
const BERM_FROM := -15.0
const BERM_TO := 100.0

const KICKER_AT := Vector2(0.0, 86.0)
const KICKER_DIR := Vector2(0.0, 1.0)
const KICKER_LENGTH := 12.0
const KICKER_WIDTH := 10.0
const KICKER_LIP := 4.5

const CABLE_FROM := Vector2(96.0, -104.0)
const CABLE_TO := Vector2(84.0, -34.0)
const CABLE_RADIUS := 4.5
const THERMAL_A := Vector2(80.0, -12.0)
const THERMAL_B := Vector2(44.0, 132.0)

const POST_HEIGHT := 16.0
const PILLAR_HEIGHT := 20.0
# Each {"at": Vector2, "height": float}: the posts this map adds or keeps, all footed at
# ground - 0.5 like every other post.
const POSTS := [
	{"at": Vector2(-80.0, -124.0), "height": POST_HEIGHT},
	{"at": Vector2(-136.0, -86.0), "height": POST_HEIGHT},
	{"at": Vector2(46.0, -143.0), "height": POST_HEIGHT},
	{"at": Vector2(100.0, -110.0), "height": 32.0},
	{"at": Vector2(101.0, -70.0), "height": POST_HEIGHT},
	{"at": Vector2(92.0, -36.0), "height": 12.0},
	{"at": Vector2(86.0, -4.0), "height": 18.0},
	{"at": Vector2(25.5, 92.5), "height": PILLAR_HEIGHT},
	{"at": Vector2(-25.5, 92.5), "height": PILLAR_HEIGHT},
	{"at": Vector2(36.0, 118.0), "height": PILLAR_HEIGHT},
	{"at": Vector2(-36.0, 118.0), "height": PILLAR_HEIGHT},
	{"at": Vector2(-62.0, 66.0), "height": 22.0},
	{"at": Vector2(60.0, -96.0), "height": 20.0},
	{"at": Vector2(-60.0, -96.0), "height": 20.0},
	{"at": Vector2(46.0, 60.0), "height": 22.0},
]
const WALLS := [
	{"at": Vector2(-58.0, -133.0), "length": 22.0, "height": 8.0, "turn": 0.0},
	{"at": Vector2(52.0, 80.0), "length": 22.0, "height": 8.0, "turn": -0.4},
]


func _init() -> void:
	super()
	basin = {}
	start_overlays.clear()
	terrain_sites = {}
	scrap_lines = [
		[Vector2(-10.0, -158.0), Vector2(-38.0, -152.4)],
		[Vector2(-46.0, -149.5), Vector2(-76.0, -137.2)],
		[Vector2(-120.0, -96.0), Vector2(-122.0, -74.0)],
		[Vector2(-98.0, -53.0), Vector2(-80.0, -45.0)],
		[Vector2(-64.5, -26.0), Vector2(-59.5, -13.5)],
		[Vector2(-20.0, 23.5), Vector2(-8.0, 38.5)],
		[Vector2(14.0, -151.8), Vector2(44.0, -134.3)],
		[Vector2(54.0, -128.5), Vector2(88.0, -108.7)],
		[Vector2(83.0, -28.0), Vector2(77.3, 8.0)],
		[Vector2(78.0, -27.0), Vector2(62.0, -8.6)],
		[Vector2(74.0, 30.0), Vector2(74.0, 76.0)],
		[Vector2(18.0, 30.5), Vector2(7.0, 43.0)],
		[Vector2(72.9, 97.5), Vector2(62.2, 120.4)],
	]
	kickers = [{"at": KICKER_AT, "dir": KICKER_DIR, "width": KICKER_WIDTH}]
	gate_slots = [
		{"at": Vector2(-14.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
		{"at": Vector2(0.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
		{"at": Vector2(14.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
	]
	activity_sites = [
		{"id": "ambush_altar", "at": Vector2(-16.0, 44.0)},
		{"id": "cracked_cache", "at": Vector2(70.0, -4.0)},
		{"id": "hauler_bounty", "at": Vector2(0.0, -88.0)},
	]
	_reach_specs()


# ---- The shape ----

func sample(x: float, z: float) -> Array:
	var s := super.sample(x, z)
	var h: float = s[0]
	var bowl := smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, Vector2(x, z).distance_to(BEACON))
	h += Features.banked_arc(x, z, BERM_CENTRE, BERM_RADIUS, BERM_WIDTH, BERM_BANK, BERM_FROM, BERM_TO) * bowl
	h += Features.kicker(x, z, KICKER_AT, KICKER_DIR, KICKER_LENGTH, KICKER_WIDTH, KICKER_LIP)
	return [h, s[1]]


func overlay_height(_id: String, _x: float, _z: float, _ground: float) -> float:
	return -INF


# The marble run with one more point, so it pours into tunnel w1 and has no end cup.
func _marble_points() -> Array:
	var pts := []
	var total := 0.0
	var lengths := [0.0]
	for i in range(1, REACH_MARBLE.size()):
		total += (REACH_MARBLE[i] as Vector2).distance_to(REACH_MARBLE[i - 1])
		lengths.append(total)
	var top := flank(REACH_MARBLE[0].y)
	var bottom := flank(REACH_MARBLE[-1].y) - 0.3
	for i in REACH_MARBLE.size():
		var m: Vector2 = REACH_MARBLE[i]
		pts.append(Vector3(m.x, lerpf(top, bottom, lengths[i] / total), m.y))
	return pts


# ---- Contraption specs ----

func _reach_specs() -> void:
	var wall := {}
	for spec in contraptions:
		if spec["id"] == "cracked_wall":
			wall = (spec as Dictionary).duplicate()
	wall["break_at_cruise"] = true
	contraptions = [
		{"kind": "cable", "id": "grapple_line", "from": Vector3(CABLE_FROM.x, flank(CABLE_FROM.y) + 2.6, CABLE_FROM.y),
			"to": Vector3(CABLE_TO.x, flank(CABLE_TO.y) + 2.4, CABLE_TO.y), "radius": CABLE_RADIUS, "floor": 18.0},
		wall,
		{"kind": "thermal", "id": "thermal_a", "at": THERMAL_A, "radius": 5.0, "height": 40.0},
		{"kind": "thermal", "id": "thermal_b", "at": THERMAL_B, "radius": 5.0, "height": 40.0},
	]


# ---- Props ----

func build_props(parent: Node3D, ground: Callable) -> void:
	var rust := Palette.solid(Palette.RUST)
	var copper := Palette.solid(Palette.COPPER)
	var enamel := Palette.solid(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.15))
	var light := Palette.solid(ANCIENT, 2.4)
	var concrete := Palette.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	box(parent, Vector3(18.0, 1.0, 10.0), ground.call(spawn.x, spawn.y - 6.0, -0.3), Palette.striped(Palette.AMBER, Palette.CHARCOAL))
	_landmark(parent, ground, enamel, light, copper, rust)
	_bridges(parent, concrete)
	_tunnel_roofs(parent, ground, concrete)
	_skylight_roof(parent, ground, concrete)
	for post in POSTS:
		var at: Vector2 = post["at"]
		grapple_post(parent, ground.call(at.x, at.y, -0.5), post["height"])
	for wall in WALLS:
		var at: Vector2 = wall["at"]
		pylon_wall(parent, ground.call(at.x, at.y, 0.0), wall["length"], wall["height"], wall["turn"])
