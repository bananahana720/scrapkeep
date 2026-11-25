extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")
const LocalMesh := preload("res://src/world/local_mesh.gd")


const ANCIENT := Palette.ANCIENT
const SPAWN := Vector2(0.0, -160.0)
const BEACON := Vector2(0.0, 118.0)
const BEACON_FLOOR := -8.0
const LIP_Z := -100.0
const TROUGH_HALF := 38.0
const TROUGH_WIDE := 90.0
const WALL := 12.0
const SKY_Y := 40.0
const UNDER_Y := 14.0

const TOWER := Vector3(-88.0, 0.0, 14.0)
const TOWER_RADIUS := 8.0
const TOWER_HEIGHT := 92.0
const SATELLITES := [
	{"at": Vector2(-104.0, -2.0), "radius": 5.0, "height": 70.0},
	{"at": Vector2(-102.0, 34.0), "radius": 5.0, "height": 62.0},
	{"at": Vector2(-72.0, -16.0), "radius": 4.0, "height": 56.0},
]
const DISH := Vector3(-60.0, 70.0, 14.0)
const DISH_RADIUS := 16.0
const DISH_FLAT := 6.0
const DISH_RIM := 4.8
const DISH_EXIT := PI * 0.5

const MARBLE := [Vector2(-94.0, -122.0), Vector2(-120.0, -98.0), Vector2(-122.0, -72.0), Vector2(-100.0, -54.0),
	Vector2(-78.0, -44.0), Vector2(-66.0, -30.0)]
const MARBLE_HALF := 5.0
const MARBLE_WALL := 4.0

const TUNNELS := {
	"w1": [Vector2(-58.0, -10.0), Vector2(-24.0, 20.0)],
	"w2": [Vector2(-58.0, 44.0), Vector2(-24.0, 74.0)],
	"e1": [Vector2(58.0, -4.0), Vector2(22.0, 26.0)],
	"e2": [Vector2(58.0, -74.0), Vector2(22.0, -44.0)],
}
const TUNNEL_HALF := 4.5
const TUNNEL_WALL := 3.0

const SKYLIGHT_X := 74.0
const SKYLIGHT_Z := Vector2(24.0, 96.0)
const SKYLIGHT_DEPTH := 6.0

const BRIDGES := [Vector2(30.0, 38.0), Vector2(46.0, 54.0)]

const IMPACT := Vector2(112.0, 0.0)
const CRATER_FLOOR := 3.0
const CRATER_RIM := 16.0
const CRATER_OUT := 22.0
const CRATER_HEIGHT := 5.5
const RUBBLE_RADIUS := 7.0
const RUBBLE_HEIGHT := 11.0
const VAULT := Vector2(120.0, -76.0)
const PLINTH := {"top": 6.0, "foot": 20.0, "height": 3.0}
const PUMP_HOUSE := Vector2(118.0, 58.0)
const REACTOR_VENT := Vector2(76.0, -78.0)
const REACTOR_RING := 6.0

var landmark := Vector3.ZERO
var contraptions: Array = []
var terrain_sites := {}
var swaps := {}
var start_overlays: Array[String] = ["cave_in_before"]
var marble_path: Array = []


func _init() -> void:
	title = "The Cable Reach"
	spawn = SPAWN
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = BEACON
	beacon_floor = BEACON_FLOOR
	vault = VAULT
	play_rect = Rect2(-150.0, -176.0, 300.0, 336.0)
	basin = {"centre": Vector2(0.0, 24.0), "radius": 30.0, "depth": 5.0,
		"plane_size": Vector2(56.0, 64.0), "plane_centre": Vector2(0.0, 24.0)}
	scrap_lines = [
		[Vector2(0.0, -150.0), Vector2(0.0, -112.0)],
		[Vector2(0.0, -80.0), Vector2(0.0, -30.0)],
		[Vector2(-4.0, -10.0), Vector2(-4.0, 50.0)],
		[Vector2(-8.0, -96.0), Vector2(-22.0, -64.0)],
		[Vector2(8.0, -40.0), Vector2(22.0, -24.0)],
	]
	sites = {
		"surge_run": {
			"ring": Vector2(-44.0, -164.0),
			"route": PackedVector2Array([
				Vector2(-50.0, -160.0), Vector2(-66.0, -156.0), Vector2(-82.0, -148.0), Vector2(-92.0, -138.0), Vector2(-94.0, -124.0),
			]),
		},
	}
	landmark = Vector3(TOWER.x, flank(TOWER.z) + TOWER_HEIGHT + 3.0, TOWER.z)
	marble_path = _marble_points()
	_specs()
	terrain_sites = {
		"cave_in": {"lead": 3.0, "first": Vector2(30.0, 45.0),
			"footprint": [{"centre": _tunnel_mid("w1"), "radius": RUBBLE_RADIUS}],
			"ride": {"centre": _tunnel_mid("w2"), "radius": RUBBLE_RADIUS + 1.0, "inner": 0.0}},
		"impact": {"lead": 4.0, "first": Vector2(55.0, 75.0),
			"footprint": [{"centre": IMPACT, "radius": CRATER_OUT}],
			"ride": {"centre": IMPACT, "radius": CRATER_RIM, "inner": CRATER_FLOOR + 1.0}},
	}


static func flank(z: float) -> float:
	if z < -102.0:
		return Features.descent(z, -166.0, -102.0, 58.0, 44.0)
	if z < -66.0:
		return Features.descent(z, -102.0, -66.0, 44.0, 32.0)
	if z < 58.0:
		return Features.descent(z, -66.0, 58.0, 32.0, 24.0)
	if z < 104.0:
		return Features.descent(z, 58.0, 104.0, 24.0, 0.0)
	return 0.0


static func trough_floor(z: float) -> float:
	if z < -52.0:
		return Features.descent(z, -100.0, -52.0, 14.0, 5.0)
	return Features.descent(z, -52.0, 100.0, 5.0, 0.0)


static func trough_half(z: float) -> float:
	return lerpf(TROUGH_HALF, TROUGH_WIDE, smoothstep(56.0, 100.0, z))


static func gorge(x: float, z: float) -> float:
	var f := flank(z)
	if z < LIP_Z:
		return f
	var w := trough_half(z)
	var inner := w - WALL
	var ax := absf(x)
	var t := trough_floor(z)
	if ax < inner:
		return t - 1.2 * (1.0 - pow(ax / inner, 2.0))
	if ax < w:
		var s := (ax - inner) / WALL
		return t + (f - t) * (1.0 - sqrt(maxf(0.0, 1.0 - s * s)))
	return f


func sample(x: float, z: float) -> Array:
	var base := gorge(x, z)
	var ride := 0.0
	var ch := _polyline_channel(x, z, marble_path, MARBLE_HALF, MARBLE_WALL)
	if ch[1] > 0.0:
		base = lerpf(base, ch[0], ch[1])
		ride = maxf(ride, ch[1])
	for id in TUNNELS:
		var tu := _polyline_channel(x, z, _tunnel_points(id), TUNNEL_HALF, TUNNEL_WALL)
		if tu[1] > 0.0 and tu[0] < base:
			base = lerpf(base, tu[0], tu[1])
			ride = maxf(ride, tu[1])
	var sky := Features.halfpipe(x, z, SKYLIGHT_X, SKYLIGHT_Z.x, SKYLIGHT_Z.y, flank, SKYLIGHT_DEPTH, 16.0)
	if sky < base:
		ride = maxf(ride, clampf((base - sky) / 1.5, 0.0, 1.0))
		base = sky
	var deck := smoothstep(-170.0, -150.0, z) * (1.0 - smoothstep(-110.0, -100.0, z))
	var calm := maxf(ride, deck)
	base += Features.ripple(x, z) * 0.5 * (1.0 - calm) * (1.0 if absf(x) > trough_half(z) or z < LIP_Z else 0.4)
	base += Features.mesa(x, z, VAULT, PLINTH["top"], PLINTH["foot"], PLINTH["height"])
	base = Features.beacon_bowl(x, z, BEACON, BEACON_FLOOR, base)
	base += Features.rim(x, z)
	return [base, _tint(x, z, base, ride)]


func _tint(x: float, z: float, h: float, ride: float) -> Color:
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, 0.4)
	if h > SKY_Y:
		tint = tint.lerp(Palette.SANDSTONE.lerp(Palette.AMBER, 0.2), 0.5)
	elif h < UNDER_Y:
		tint = tint.lerp(Palette.VERDIGRIS.lerp(Palette.SANDSTONE, 0.5), 0.6)
	var d := Vector2(x, z).distance_to(BEACON)
	var bowl := clampf((d - Features.BOWL_FLAT) / 16.0, 0.0, 1.0) * (1.0 - smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, d))
	tint = tint.lerp(Palette.AMBER.lerp(Palette.SANDSTONE, 0.35), bowl * 0.8)
	return tint.lerp(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.45), ride * 0.9)


func material_at(x: float, z: float) -> String:
	if _polyline_channel(x, z, marble_path, MARBLE_HALF, MARBLE_WALL)[1] > 0.5:
		return "concrete"
	if absf(x - SKYLIGHT_X) < SKYLIGHT_DEPTH and z > SKYLIGHT_Z.x and z < SKYLIGHT_Z.y:
		return "concrete"
	return "sand"


static func layer_at(p: Vector3) -> String:
	if p.y > SKY_Y:
		return "sky"
	if p.y < UNDER_Y:
		return "undercroft"
	return "shelf"


static func _polyline_channel(x: float, z: float, pts: Array, half: float, wall: float) -> Array:
	var p := Vector2(x, z)
	var best := INF
	var floor_h := 0.0
	for i in pts.size() - 1:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var q := Geometry2D.get_closest_point_to_segment(p, a2, b2)
		var d := p.distance_to(q)
		if d < best:
			best = d
			var seg := a2.distance_to(b2)
			var f := a2.distance_to(q) / seg if seg > 0.0 else 0.0
			floor_h = lerpf(a.y, b.y, f)
	if best > half + 8.0:
		return [0.0, 0.0]
	var h := floor_h + wall * pow(minf(best, half) / half, 2.2)
	var weight := 1.0 - smoothstep(half, half + 8.0, best)
	return [h, weight]


func _marble_points() -> Array:
	var pts := []
	var total := 0.0
	var lengths := [0.0]
	for i in range(1, MARBLE.size()):
		total += (MARBLE[i] as Vector2).distance_to(MARBLE[i - 1])
		lengths.append(total)
	var top := flank(MARBLE[0].y)
	var bottom := flank(MARBLE[-1].y) - 0.3
	for i in MARBLE.size():
		var m: Vector2 = MARBLE[i]
		pts.append(Vector3(m.x, lerpf(top, bottom, lengths[i] / total), m.y))
	return pts


func _tunnel_points(id: String) -> Array:
	var ends: Array = TUNNELS[id]
	var a: Vector2 = ends[0]
	var b: Vector2 = ends[1]
	return [Vector3(a.x, flank(a.y) - 0.2, a.y), Vector3(b.x, trough_floor(b.y) - 0.6, b.y)]


func _tunnel_mid(id: String) -> Vector2:
	var ends: Array = TUNNELS[id]
	return (ends[0] as Vector2).lerp(ends[1], 0.45)


func overlay_height(id: String, x: float, z: float, ground: float) -> float:
	match id:
		"cave_in_before":
			return _mound(x, z, _tunnel_mid("w2"), ground)
		"cave_in_after":
			return _mound(x, z, _tunnel_mid("w1"), ground)
		"impact_after":
			var r := Vector2(x, z).distance_to(IMPACT)
			if r > CRATER_OUT:
				return -INF
			return ground + crater_profile(r)
	return -INF


static func _mound(x: float, z: float, centre: Vector2, ground: float) -> float:
	var r := Vector2(x, z).distance_to(centre)
	if r > RUBBLE_RADIUS:
		return -INF
	return ground + rubble_profile(r)


static func rubble_profile(r: float) -> float:
	return RUBBLE_HEIGHT * (1.0 - pow(clampf(r / RUBBLE_RADIUS, 0.0, 1.0), 2.0))


static func crater_profile(r: float) -> float:
	if r <= CRATER_FLOOR:
		return 0.0
	if r <= CRATER_RIM:
		return CRATER_HEIGHT * pow((r - CRATER_FLOOR) / (CRATER_RIM - CRATER_FLOOR), 2.0)
	return CRATER_HEIGHT * (1.0 - smoothstep(CRATER_RIM, CRATER_OUT, r))


static func dish_profile(r: float, angle: float) -> float:
	if r <= DISH_FLAT:
		return 0.0
	var rim := DISH_RIM * pow((r - DISH_FLAT) / (DISH_RADIUS - DISH_FLAT), 2.0)
	var off := absf(wrapf(angle - DISH_EXIT, -PI, PI))
	return rim * smoothstep(deg_to_rad(12.0), deg_to_rad(26.0), off)


func _specs() -> void:
	var lip := flank(LIP_Z)
	contraptions = [
		{"kind": "barge", "id": "barge_west", "a": Vector3(-12.0, lip - 0.6, -92.0), "b": Vector3(-30.0, flank(-40.0) - 0.6, -40.0),
			"size": Vector3(14.0, 1.2, 14.0), "travel": 9.0, "dwell": 3.0, "offset": 0.0},
		{"kind": "barge", "id": "barge_east", "a": Vector3(12.0, lip - 0.6, -92.0), "b": Vector3(30.0, flank(-40.0) - 0.6, -40.0),
			"size": Vector3(14.0, 1.2, 14.0), "travel": 9.0, "dwell": 3.0, "offset": 12.0},
		{"kind": "lift", "id": "lift_west", "at": Vector2(-24.0, -56.0), "radius": 4.5, "rise": 13.0, "charge": 3.2, "offset": 0.0},
		{"kind": "lift", "id": "lift_east", "at": Vector2(24.0, -18.0), "radius": 4.5, "rise": 13.0, "charge": 3.2, "offset": 1.6},
		{"kind": "launcher", "id": "cannon", "style": "cannon", "at": MARBLE[-1], "radius": 4.0,
			"target": Vector3(72.0, flank(4.0), 4.0), "floor": 34.0, "min_flight": 2.6, "charge": 2.5},
		{"kind": "launcher", "id": "trebuchet", "style": "trebuchet", "at": Vector2(96.0, 44.0), "radius": 3.5,
			"target": DISH + Vector3.UP * 0.8, "floor": 30.0, "min_flight": 3.2, "charge": 4.0},
		{"kind": "launcher", "id": "geyser", "style": "geyser", "at": Vector2(-22.0, 30.0), "radius": 3.5,
			"target": DISH + Vector3.UP * 0.8, "floor": 16.0, "min_flight": 2.2, "charge": 3.0},
		{"kind": "cable", "id": "grapple_line", "from": Vector3(44.0, flank(-103.0) + 3.2, -103.0),
			"to": Vector3(100.0, flank(-40.0) + 2.4, -40.0), "radius": 3.4, "floor": 18.0},
		{"kind": "valve", "id": "skylight_valve", "at": Vector2(86.0, 16.0), "door": {"at": Vector2(SKYLIGHT_X, 23.0),
			"size": Vector3(15.0, 5.0, 1.0), "turn": 0.0}, "vent": null},
		{"kind": "valve", "id": "vent_valve", "at": Vector2(66.0, -86.0), "door": {"at": _tunnel_door("e2"),
			"size": Vector3(10.0, 5.0, 1.0), "turn": _tunnel_turn("e2")}, "vent": {"at": REACTOR_VENT, "radius": REACTOR_RING}},
		{"kind": "cracked_wall", "id": "cracked_wall", "at": _tunnel_door("e1"), "size": Vector3(10.0, 6.0, 1.4),
			"turn": _tunnel_turn("e1")},
		{"kind": "thermal", "id": "thermal_a", "at": Vector2(-8.0, -78.0), "radius": 5.0, "height": 62.0},
		{"kind": "thermal", "id": "thermal_b", "at": Vector2(14.0, -60.0), "radius": 5.0, "height": 62.0},
		{"kind": "thermal", "id": "thermal_c", "at": Vector2(-10.0, -38.0), "radius": 5.0, "height": 60.0},
	]


func _tunnel_door(id: String) -> Vector2:
	var ends: Array = TUNNELS[id]
	return (ends[0] as Vector2).lerp(ends[1], 0.16)


func _tunnel_turn(id: String) -> float:
	var ends: Array = TUNNELS[id]
	var d: Vector2 = (ends[1] as Vector2) - (ends[0] as Vector2)
	return -atan2(d.y, d.x) + PI * 0.5


func build_props(parent: Node3D, ground: Callable) -> void:
	var rust := Palette.solid(Palette.RUST)
	var copper := Palette.solid(Palette.COPPER)
	var enamel := Palette.solid(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.15))
	var light := Palette.solid(ANCIENT, 2.4)
	var concrete := Palette.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	box(parent, Vector3(18.0, 1.0, 10.0), ground.call(spawn.x, spawn.y - 6.0, -0.3), Palette.striped(Palette.AMBER, Palette.CHARCOAL))
	_landmark(parent, ground, enamel, light, copper, rust)
	_dish(parent, ground, enamel, copper)
	_bridges(parent, concrete)
	_tunnel_roofs(parent, ground, concrete)
	_skylight_roof(parent, ground, concrete)
	_cable_tower(parent, ground)
	var start: Vector3 = marble_path[0]
	for side in [-1.0, 1.0]:
		box(parent, Vector3(2.0, 2.2, 8.0), Vector3(start.x + side * (MARBLE_HALF + 2.0), start.y + 0.8, start.z - 4.0), rust, 0.75)
	for x in [-60.0, 60.0]:
		grapple_post(parent, ground.call(x, -96.0, -0.5), 20.0)
	grapple_post(parent, ground.call(-46.0, 60.0, -0.5), 22.0)
	grapple_post(parent, ground.call(46.0, 60.0, -0.5), 22.0)
	pylon_wall(parent, ground.call(-52.0, -80.0, 0.0), 22.0, 8.0, 0.2)
	pylon_wall(parent, ground.call(52.0, 80.0, 0.0), 22.0, 8.0, -0.4)
	var house: Vector3 = ground.call(PUMP_HOUSE.x, PUMP_HOUSE.y, 0.0)
	box(parent, Vector3(18.0, 10.0, 12.0), house + Vector3.UP * 4.5, concrete)
	var windows := MeshInstance3D.new()
	var glow := BoxMesh.new()
	glow.size = Vector3(18.4, 1.6, 12.4)
	windows.mesh = glow
	windows.material_override = Palette.solid(Palette.AMBER, 1.6)
	windows.position = house + Vector3.UP * 6.5
	parent.add_child(windows)
	_reactor_vent(parent, ground, enamel, light)
	_swaps(parent, ground)


func _landmark(parent: Node3D, ground: Callable, enamel: Material, light: Material, copper: Material, rust: Material) -> void:
	var foot: Vector3 = ground.call(TOWER.x, TOWER.z, 0.0)
	cylinder(parent, TOWER_RADIUS, TOWER_HEIGHT, foot + Vector3.UP * TOWER_HEIGHT * 0.5, enamel)
	_seams(parent, foot, TOWER_RADIUS, TOWER_HEIGHT, light)
	for s in SATELLITES:
		var at: Vector2 = s["at"]
		var f: Vector3 = ground.call(at.x, at.y, 0.0)
		cylinder(parent, s["radius"], s["height"], f + Vector3.UP * float(s["height"]) * 0.5, enamel)
		_seams(parent, f, s["radius"], s["height"], light)
		_visual_cylinder(parent, 0.7, float(s["height"]) * 0.8, f + Vector3(float(s["radius"]) + 0.6, float(s["height"]) * 0.4, 0.0), copper)
		_ring(parent, f + Vector3.UP * float(s["height"]) * 0.6, float(s["radius"]) + 1.4, rust)
	for k in 3:
		_ring(parent, foot + Vector3.UP * (24.0 + k * 22.0), TOWER_RADIUS + 1.6, rust)
		_visual_cylinder(parent, 0.9, TOWER_HEIGHT * 0.7, foot + Vector3(cos(k * 2.1) * (TOWER_RADIUS + 0.8), TOWER_HEIGHT * 0.35,
			sin(k * 2.1) * (TOWER_RADIUS + 0.8)), copper)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 3.2
	bulb.height = 6.4
	lamp.mesh = bulb
	lamp.material_override = light
	lamp.position = landmark
	parent.add_child(lamp)
	var omni := OmniLight3D.new()
	omni.light_color = ANCIENT
	omni.light_energy = 3.0
	omni.omni_range = 60.0
	omni.position = landmark
	parent.add_child(omni)


func _seams(parent: Node3D, foot: Vector3, radius: float, height_m: float, light: Material) -> void:
	for k in 4:
		var a := k * PI * 0.5 + 0.4
		var at := foot + Vector3(cos(a) * radius, height_m * 0.5, sin(a) * radius)
		var groove := MeshInstance3D.new()
		var g := BoxMesh.new()
		g.size = Vector3(0.9, height_m * 0.86, 0.9)
		groove.mesh = g
		groove.material_override = Palette.solid(Palette.CHARCOAL)
		groove.position = at
		parent.add_child(groove)
		var seam := MeshInstance3D.new()
		var s := BoxMesh.new()
		s.size = Vector3(0.35, height_m * 0.84, 0.35)
		seam.mesh = s
		seam.material_override = light
		seam.position = at + Vector3(cos(a), 0.0, sin(a)) * 0.35
		parent.add_child(seam)


func _dish(parent: Node3D, _ground: Callable, enamel: Material, copper: Material) -> void:
	var height := func(r: float, a: float) -> float: return dish_profile(r, a)
	var base := func(_x: float, _z: float) -> float: return DISH.y
	LocalMesh.polar(parent, "CrownDish", DISH, 0.4, DISH_RADIUS, 16, 48, height, base, Palette.SANDSTONE.lerp(Palette.AMBER, 0.3))
	var cone := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = DISH_RADIUS
	c.bottom_radius = 3.0
	c.height = 7.0
	cone.mesh = c
	cone.material_override = enamel
	cone.position = DISH + Vector3.DOWN * 3.7
	parent.add_child(cone)
	var strut_len := DISH.x - TOWER.x - TOWER_RADIUS
	box(parent, Vector3(strut_len, 2.0, 3.0), Vector3(TOWER.x + TOWER_RADIUS + strut_len * 0.5, DISH.y - 4.0, DISH.z), copper)


func _bridges(parent: Node3D, mat: Material) -> void:
	for span in BRIDGES:
		var z0: float = span.x
		var z1: float = span.y
		var zc := (z0 + z1) * 0.5
		var top := flank(zc) - 0.05
		var length := (TROUGH_HALF + 2.0) * 2.0
		box(parent, Vector3(length, 1.4, z1 - z0), Vector3(0.0, top - 0.7, zc), mat)
		for x in [-TROUGH_HALF + WALL + 2.0, 0.0, TROUGH_HALF - WALL - 2.0]:
			var foot := trough_floor(zc)
			_visual_box(parent, Vector3(2.4, top - foot, 2.4), Vector3(x, (top + foot) * 0.5, zc), mat)


const ROOF_SIDE := 8.5
const ROOF_SINK := 0.3


func _tunnel_roofs(parent: Node3D, ground: Callable, mat: Material) -> void:
	for id in TUNNELS:
		var ends: Array = TUNNELS[id]
		var a: Vector2 = (ends[0] as Vector2).lerp(ends[1], 0.28)
		var b: Vector2 = (ends[0] as Vector2).lerp(ends[1], 0.62)
		var d := ((ends[1] as Vector2) - (ends[0] as Vector2)).normalized()
		var side := Vector2(-d.y, d.x) * ROOF_SIDE
		var top := func(p: Vector2) -> float:
			return maxf((ground.call(p.x + side.x, p.y + side.y, 0.0) as Vector3).y,
				(ground.call(p.x - side.x, p.y - side.y, 0.0) as Vector3).y) - ROOF_SINK
		var pa := Vector3(a.x, top.call(a), a.y)
		var pb := Vector3(b.x, top.call(b), b.y)
		var mid := (pa + pb) * 0.5
		var along := pb - pa
		var body := box(parent, Vector3(TUNNEL_HALF * 2.0 + 3.0, 1.2, along.length()), mid + Vector3.DOWN * 0.6, mat)
		body.name = "TunnelRoof_" + id
		body.basis = Basis.looking_at(along.normalized(), Vector3.UP)


const SKYLIGHT_ROOFS := [40.0, 52.0]


func _skylight_roof(parent: Node3D, ground: Callable, mat: Material) -> void:
	for z in SKYLIGHT_ROOFS:
		var at: Vector3 = ground.call(SKYLIGHT_X + SKYLIGHT_DEPTH + 3.0, z, 0.0)
		var top := at.y - 0.05
		for side in [-1.0, 1.0]:
			box(parent, Vector3(SKYLIGHT_DEPTH + 1.0, 1.2, 12.0), Vector3(SKYLIGHT_X + side * (SKYLIGHT_DEPTH * 0.5 + 1.0), top - 0.6, z), mat)
	var grate := Palette.striped(Palette.CHARCOAL, Palette.SAND)
	for z in SKYLIGHT_ROOFS:
		var at: Vector3 = ground.call(SKYLIGHT_X + SKYLIGHT_DEPTH + 3.0, z, 0.0)
		_visual_box(parent, Vector3(2.0, 0.2, 12.0), Vector3(SKYLIGHT_X, at.y - 0.3, z), grate)


func _cable_tower(parent: Node3D, ground: Callable) -> void:
	var foot: Vector3 = ground.call(48.0, -108.0, -0.5)
	grapple_post(parent, foot, 32.0)
	grapple_post(parent, ground.call(106.0, -46.0, -0.5), 12.0)


func _reactor_vent(parent: Node3D, ground: Callable, enamel: Material, light: Material) -> void:
	var at: Vector3 = ground.call(REACTOR_VENT.x, REACTOR_VENT.y, 0.0)
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 3.0
	s.height = 3.4
	dome.mesh = s
	dome.material_override = enamel
	dome.position = at + Vector3.UP * 0.6
	parent.add_child(dome)
	var seam := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 2.6
	t.outer_radius = 2.9
	seam.mesh = t
	seam.material_override = light
	seam.position = at + Vector3.UP * 1.4
	parent.add_child(seam)


func _swaps(parent: Node3D, ground: Callable) -> void:
	var base := func(x: float, z: float) -> float: return (ground.call(x, z, 0.0) as Vector3).y
	var rubble_tint := Palette.SANDSTONE.lerp(Palette.RUST, 0.35)
	var mound := func(r: float, _a: float) -> float: return rubble_profile(r)
	var w1 := _tunnel_mid("w1")
	var w2 := _tunnel_mid("w2")
	var seal := LocalMesh.polar(parent, "CaveInSeal", Vector3(w1.x, 0.0, w1.y), 0.4, RUBBLE_RADIUS, 6, 24, mound, base, rubble_tint)
	var plug := LocalMesh.polar(parent, "CaveInPlug", Vector3(w2.x, 0.0, w2.y), 0.4, RUBBLE_RADIUS, 6, 24, mound, base, rubble_tint)
	var crater_fn := func(r: float, _a: float) -> float: return crater_profile(r)
	var crater := LocalMesh.polar(parent, "ImpactCrater", Vector3(IMPACT.x, 0.0, IMPACT.y), 0.4, CRATER_OUT, 14, 48, crater_fn, base,
		Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.25))
	var chunk_at: Vector3 = ground.call(IMPACT.x - 3.0, IMPACT.y - CRATER_OUT - 3.0, 0.0)
	var chunk := box(parent, Vector3(5.0, 4.0, 4.0), chunk_at + Vector3.UP * 1.2, Palette.solid(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.2)), 0.5)
	chunk.name = "ImpactChunk"
	var seam := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(5.1, 0.25, 0.3)
	seam.mesh = sb
	seam.material_override = Palette.solid(ANCIENT, 2.4)
	chunk.add_child(seam)
	swaps = {
		"cave_in": {"before": [plug], "after": [seal]},
		"impact": {"before": [], "after": [crater, chunk]},
	}
	for id in swaps:
		for node in swaps[id]["after"]:
			node.set_meta("home", node.position)
		for node in swaps[id]["before"]:
			node.set_meta("home", node.position)
		apply_swap(id, false)


const SWAP_PARK := 400.0


func apply_swap(id: String, changed: bool) -> void:
	if not swaps.has(id):
		return
	for node in swaps[id]["after"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home if changed else home + Vector3.DOWN * SWAP_PARK
		node.visible = changed
	for node in swaps[id]["before"]:
		var home: Vector3 = node.get_meta("home")
		node.position = home + Vector3.DOWN * SWAP_PARK if changed else home
		node.visible = not changed


static func _visual_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mesh.mesh = b
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh


static func _visual_cylinder(parent: Node3D, radius: float, height_m: float, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height_m
	mesh.mesh = c
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh


static func _ring(parent: Node3D, at: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.6
	t.outer_radius = radius
	mesh.mesh = t
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)
	return mesh
