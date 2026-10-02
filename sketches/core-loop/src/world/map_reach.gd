extends "res://src/world/map_gorge.gd"

const REACH_MARBLE := [Vector2(-94.0, -122.0), Vector2(-120.0, -98.0), Vector2(-122.0, -72.0), Vector2(-100.0, -54.0),
	Vector2(-78.0, -44.0), Vector2(-66.0, -30.0), Vector2(-58.0, -10.0)]
const POSTS := [
	Vector3(-80.0, 16.0, -124.0),
	Vector3(-136.0, 16.0, -86.0),
	Vector3(46.0, 16.0, -143.0),
	Vector3(100.0, 32.0, -110.0),
	Vector3(101.0, 16.0, -70.0),
	Vector3(92.0, 12.0, -36.0),
	Vector3(86.0, 18.0, -4.0),
	Vector3(25.5, 20.0, 92.5),
	Vector3(-25.5, 20.0, 92.5),
	Vector3(36.0, 20.0, 118.0),
	Vector3(-36.0, 20.0, 118.0),
	Vector3(-62.0, 22.0, 66.0),
	Vector3(60.0, 20.0, -96.0),
	Vector3(-60.0, 20.0, -96.0),
	Vector3(46.0, 22.0, 60.0),
]


func _init() -> void:
	super()
	basin = {}
	start_overlays.clear()
	terrain_sites = {}
	marble_path = _reach_marble_points()
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
	kickers = [{"at": Vector2(0.0, 86.0), "dir": Vector2(0.0, 1.0), "width": 10.0}]
	contraptions = [
		{"kind": "cable", "id": "grapple_line", "from": Vector3(96.0, flank(-104.0) + 2.6, -104.0),
			"to": Vector3(84.0, flank(-34.0) + 2.4, -34.0), "radius": 4.5, "floor": 18.0},
		{"kind": "cracked_wall", "id": "cracked_wall", "at": _tunnel_door("e1"), "size": Vector3(10.0, 6.0, 1.4),
			"turn": _tunnel_turn("e1"), "break_at_cruise": true},
		{"kind": "thermal", "id": "thermal_a", "at": Vector2(80.0, -12.0), "radius": 5.0, "height": 40.0},
		{"kind": "thermal", "id": "thermal_b", "at": Vector2(44.0, 132.0), "radius": 5.0, "height": 40.0},
	]
	gate_slots = [
		{"at": Vector2(-14.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
		{"at": Vector2(0.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
		{"at": Vector2(14.0, 134.0), "facing": Vector3(0.0, 0.0, 1.0)},
	]
	activity_sites = {"ambush_altar": Vector2(-16.0, 44.0), "cracked_cache": Vector2(70.0, -4.0),
		"hauler_bounty": Vector2(0.0, -88.0)}


func _reach_marble_points() -> Array:
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


func sample(x: float, z: float) -> Array:
	var value := super.sample(x, z)
	value[0] += Features.banked_arc(x, z, Vector2(29.0, 90.0), 40.0, 12.0, 10.0, -15.0, 100.0) \
		* smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, Vector2(x, z).distance_to(BEACON))
	value[0] += Features.kicker(x, z, Vector2(0.0, 86.0), Vector2(0.0, 1.0), 12.0, 10.0, 4.5)
	return value


func overlay_height(_id: String, _x: float, _z: float, _ground: float) -> float:
	return -INF


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
		grapple_post(parent, ground.call(post.x, post.z, -0.5), post.y)
	pylon_wall(parent, ground.call(-58.0, -133.0, 0.0), 22.0, 8.0, 0.0)
	pylon_wall(parent, ground.call(52.0, 80.0, 0.0), 22.0, 8.0, -0.4)
