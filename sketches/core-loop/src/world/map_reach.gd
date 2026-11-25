extends "res://src/world/map_gorge.gd"

const CodexWorld := preload("res://src/world/codex_world.gd")


const SWEEP_CENTRE := Vector2(-32.3, -78.0)
const SWEEP_LINE := 68.0
const SWEEP_ARC := 58.0
const SWEEP_WIDTH := 12.0
const SWEEP_BANK := 10.0
const SWEEP_FROM := 131.4
const SWEEP_TO := 245.0
const SWEEP_START := -135.0
const SWEEP_END := -228.6
const SWEEP_STEP := 5.0
const MOUTH := Vector2(-58.0, -10.0)

const DIVE_DIR := Vector2(0.74986, 0.66161)
const DIVE_FROM := -45.0
const DIVE_TO := 60.0
const DIVE_EASE_IN := 40.0
const DIVE_EASE_OUT := 35.0
const DIVE_FADE := 12.0
const DIVE_HALF := 6.0
const DIVE_SIDE := 8.0
const DIVE_OUT := 10.0
const DROPPED_SATELLITE := Vector2(-72.0, -16.0)
const SECRET_CACHE := Vector2(-100.0, 64.0)
const SECRET_VALVE := Vector2(-100.0, 54.0)

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

const LAUNCH_DROP := 3.5
const LAUNCH_FROM := -158.0
const LAUNCH_TO := -135.0
const LAUNCH_BACK_FROM := -125.0
const LAUNCH_BACK_TO := -100.0

const OPEN_TUNNELS := ["w1", "e1"]

const POST_HEIGHT := 16.0
const PILLAR_HEIGHT := 20.0
const POSTS := [
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
	{"at": Vector2(-64.0, -105.0), "length": 22.0, "height": 8.0, "turn": 0.0},
	{"at": Vector2(52.0, 80.0), "length": 22.0, "height": 8.0, "turn": -0.4},
]


var _dive_floor := PackedFloat32Array()
var relic_spot := SECRET_CACHE + Vector2(0.0, 48.0)


func _init() -> void:
	super()
	_build_dive()
	basin = {}
	start_overlays.clear()
	terrain_sites = {}
	scrap_lines = [
		[Vector2(-40.0, -120.0), Vector2(-56.0, -120.0)],
		[Vector2(-62.0, -120.0), Vector2(-76.0, -121.0)],
		[Vector2(-90.0, -110.0), Vector2(-96.0, -96.0)],
		[Vector2(-97.0, -76.0), Vector2(-95.0, -60.0)],
		[Vector2(-70.0, -20.0), Vector2(-62.0, -12.0)],
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
		{"id": "enemy_camp", "at": Vector2(-80.0, 40.0), "pack": ["lobber", "lobber", "lobber"], "pay": {"named": "loose_trigger"}},
		{"id": "ambush_altar", "at": Vector2(-16.0, 44.0)},
		{"id": "cracked_cache", "at": Vector2(68.0, -4.0)},
		{"id": "hauler_bounty", "at": Vector2(0.0, -88.0)},
	]
	_reach_specs()


func sample(x: float, z: float) -> Array:
	var kept := marble_path
	marble_path = []
	var s := super.sample(x, z)
	marble_path = kept
	var h: float = s[0]
	h += Features.banked_arc(x, z, SWEEP_CENTRE, SWEEP_ARC, SWEEP_WIDTH, SWEEP_BANK, SWEEP_FROM, SWEEP_TO)
	var bowl := smoothstep(Features.BOWL_RIM, Features.BOWL_OUT, Vector2(x, z).distance_to(BEACON))
	h += Features.banked_arc(x, z, BERM_CENTRE, BERM_RADIUS, BERM_WIDTH, BERM_BANK, BERM_FROM, BERM_TO) * bowl
	h = _dive(x, z, h)
	h -= LAUNCH_DROP * smoothstep(LAUNCH_FROM, LAUNCH_TO, z) * (1.0 - smoothstep(LAUNCH_BACK_FROM, LAUNCH_BACK_TO, z))
	h += Features.kicker(x, z, KICKER_AT, KICKER_DIR, KICKER_LENGTH, KICKER_WIDTH, KICKER_LIP)
	return [h, s[1]]


func _build_dive() -> void:
	var length := DIVE_TO - DIVE_FROM
	var count := int(length) + 1
	var top := flank(MOUTH.y + DIVE_DIR.y * DIVE_FROM)
	var end := MOUTH + DIVE_DIR * DIVE_TO
	var bottom := gorge(end.x, end.y)
	var fallen := PackedFloat32Array()
	var total := 0.0
	for i in count:
		fallen.append(total)
		total += smoothstep(0.0, DIVE_EASE_IN, float(i)) * (1.0 - smoothstep(length - DIVE_EASE_OUT, length, float(i)))
	_dive_floor = PackedFloat32Array()
	for i in count:
		_dive_floor.append(top - (top - bottom) * fallen[i] / total)


func _dive(x: float, z: float, h: float) -> float:
	var rel := Vector2(x, z) - MOUTH
	var along := rel.dot(DIVE_DIR)
	if along <= DIVE_FROM or along >= DIVE_TO + DIVE_OUT:
		return h
	var across := absf(rel.dot(Vector2(-DIVE_DIR.y, DIVE_DIR.x)))
	if across >= DIVE_HALF + DIVE_SIDE:
		return h
	var at := clampf(along - DIVE_FROM, 0.0, float(_dive_floor.size() - 1))
	var i := mini(int(at), _dive_floor.size() - 2)
	var floor_h := lerpf(_dive_floor[i], _dive_floor[i + 1], at - float(i))
	var weight := (1.0 - smoothstep(DIVE_HALF, DIVE_HALF + DIVE_SIDE, across)) * smoothstep(DIVE_FROM, DIVE_FROM + DIVE_FADE, along) \
		* (1.0 - smoothstep(DIVE_TO, DIVE_TO + DIVE_OUT, along))
	return lerpf(h, floor_h, weight)


func overlay_height(_id: String, _x: float, _z: float, _ground: float) -> float:
	return -INF


func _marble_points() -> Array:
	var pts := []
	var steps := int(absf(SWEEP_END - SWEEP_START) / SWEEP_STEP)
	for i in steps + 1:
		var a := deg_to_rad(SWEEP_START + (SWEEP_END - SWEEP_START) * float(i) / float(steps))
		var p := SWEEP_CENTRE + Vector2(cos(a), sin(a)) * SWEEP_LINE
		pts.append(Vector3(p.x, flank(p.y), p.y))
	pts.append(Vector3(MOUTH.x, flank(MOUTH.y), MOUTH.y))
	return pts


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
		{"kind": "valve", "id": "reach_cache_valve", "at": SECRET_VALVE,
			"door": {"at": SECRET_CACHE, "size": Vector3(12.0, 6.0, 1.0), "turn": 0.0},
			"cache": {"at": SECRET_CACHE},
			"codex": CodexWorld.entry("reach_pressure_cache")},
	]


func build_props(parent: Node3D, ground: Callable) -> void:
	var rust := Palette.solid(Palette.RUST)
	var copper := Palette.solid(Palette.COPPER)
	var enamel := Palette.solid(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.15))
	var light := Palette.solid(ANCIENT, 2.4)
	var concrete := Palette.striped(Palette.CHARCOAL, Palette.VERDIGRIS)
	var spawn_deck: Vector3 = ground.call(spawn.x, spawn.y - 6.0, -0.3)
	var spawn_pad_material := StandardMaterial3D.new()
	spawn_pad_material.albedo_color = Palette.VERDIGRIS
	spawn_pad_material.roughness = 0.72
	var spawn_seam_material := StandardMaterial3D.new()
	spawn_seam_material.albedo_color = ANCIENT
	spawn_seam_material.roughness = 0.72
	spawn_seam_material.emission_enabled = true
	spawn_seam_material.emission = ANCIENT
	spawn_seam_material.emission_energy_multiplier = 0.7
	var spawn_pad: StaticBody3D = box(parent, Vector3(18.0, 1.0, 10.0), spawn_deck, spawn_pad_material)
	var spawn_seam := MeshInstance3D.new()
	var spawn_seam_mesh := BoxMesh.new()
	spawn_seam_mesh.size = Vector3(0.18, 0.06, 8.0)
	spawn_seam.mesh = spawn_seam_mesh
	spawn_seam.material_override = spawn_seam_material
	spawn_seam.position = Vector3.UP * 0.53
	spawn_pad.add_child(spawn_seam)
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
	load("res://src/presentation/spillway_scenery.gd").dress_props(parent)
	var spawn_pad_view: MeshInstance3D
	for child in spawn_pad.get_children():
		if child is MeshInstance3D:
			spawn_pad_view = child
			break
	spawn_pad_view.material_override = spawn_pad_material
	spawn_seam.material_override = spawn_seam_material


func _landmark(parent: Node3D, ground: Callable, enamel: Material, light: Material, copper: Material, rust: Material) -> void:
	var foot: Vector3 = ground.call(TOWER.x, TOWER.z, 0.0)
	cylinder(parent, TOWER_RADIUS, TOWER_HEIGHT, foot + Vector3.UP * TOWER_HEIGHT * 0.5, enamel)
	_seams(parent, foot, TOWER_RADIUS, TOWER_HEIGHT, light)
	for sat in SATELLITES:
		var at: Vector2 = sat["at"]
		if at.is_equal_approx(DROPPED_SATELLITE):
			continue
		var f: Vector3 = ground.call(at.x, at.y, 0.0)
		cylinder(parent, sat["radius"], sat["height"], f + Vector3.UP * float(sat["height"]) * 0.5, enamel)
		_seams(parent, f, sat["radius"], sat["height"], light)
		_visual_cylinder(parent, 0.7, float(sat["height"]) * 0.8, f + Vector3(float(sat["radius"]) + 0.6, float(sat["height"]) * 0.4, 0.0), copper)
		_ring(parent, f + Vector3.UP * float(sat["height"]) * 0.6, float(sat["radius"]) + 1.4, rust)
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


func _tunnel_roofs(parent: Node3D, ground: Callable, mat: Material) -> void:
	for id in TUNNELS:
		if id in OPEN_TUNNELS:
			continue
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
