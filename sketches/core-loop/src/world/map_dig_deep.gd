extends "res://src/world/map_dig.gd"


const DEEP_H := -12.0
const DEEP_CLIFF_Z := 70.0
const DEEP_RAMP_Z := Vector2(40.0, 100.0)
const DEEP_RAMP_X := 40.0

const MIDDLE_PLATES := [
	{"id": "plate_mid_west", "rect": Rect2(-76.0, 20.0, 12.0, 12.0), "drop_to": DEEP_H + 4.0},
	{"id": "plate_mid_east", "rect": Rect2(84.0, 24.0, 12.0, 12.0), "drop_to": DEEP_H + 4.0},
]


func _init() -> void:
	super()
	title = "Dig: the deep works"
	scatter["mix"] = {"long": 3, "scoop": 8, "rubble": 12, "strut": 2, "cart": 1, "shell": 6}
	scatter["relief"] = {"sub": 2, "amp": 0.14, "period": 2.6, "shade": 0.4, "seed": "relief_dig_deep"}
	scatter["kit"] = [
		{"kind": "rock", "density": 1.2, "scale": Vector2(0.3, 0.8), "slope": 0.8, "bury": 0.35, "seed": "scatter_dig_deep_rock", "mesh": "kit:rubble", "slot": "stone"},
		{"kind": "pebble", "density": 2.2, "scale": Vector2(0.1, 0.25), "slope": 0.8, "bury": 0.3, "seed": "scatter_dig_deep_pebble", "mesh": "kit:pebble", "slot": "stone"},
		{"kind": "scrap", "density": 0.2, "scale": Vector2(0.25, 0.45), "slope": 0.85, "bury": 0.3, "seed": "scatter_dig_deep_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
		{"kind": "cable", "density": 0.25, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_dig_deep_cable", "mesh": "prim:coil", "slot": "cable"},
	]
	spawn = Vector2(-24.0, -128.0)
	beacon = Vector2(40.0, 130.0)
	beacon_floor = DEEP_H
	vault = Vector2(40.0, -130.0)
	scrap_lines = [
		[Vector2(-20.0, -116.0), Vector2(-4.0, -50.0)],
		[Vector2(0.0, -20.0), Vector2(0.0, 25.0)],
		[Vector2(10.0, 32.0), Vector2(32.0, 38.0)],
		[Vector2(40.0, 50.0), Vector2(40.0, 96.0)],
	]
	gate_slots = [{"at": Vector2(80.0, 140.0), "facing": Vector3(0.0, 0.0, 1.0)}]
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(120.0, 50.0), "pack": ["burrower", "drill_crew", "lamp_swarm"],
			"pay": {"named": "pylon_capacitor"}},
		{"id": "ambush_altar", "at": Vector2(-110.0, 40.0)},
		{"id": "cracked_cache", "at": Vector2(-100.0, -100.0)},
		{"id": "hauler_bounty", "at": Vector2(46.0, 62.0)},
	]
	relic_spot = Vector2(-80.0, 120.0)
	breach_plates = BREACH_PLATES.duplicate(true) + MIDDLE_PLATES.duplicate(true)
	start_overlays.clear()
	for plate in breach_plates:
		start_overlays.append(plate["id"] + "_before")


func _tiers(x: float, z: float) -> float:
	var drop := DEEP_H - LOWER_H
	var cliff := drop * smoothstep(DEEP_CLIFF_Z - CLIFF_HALF, DEEP_CLIFF_Z + CLIFF_HALF, z)
	var ramp := drop * clampf((z - DEEP_RAMP_Z.x) / (DEEP_RAMP_Z.y - DEEP_RAMP_Z.x), 0.0, 1.0)
	var on_ramp := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + RAMP_BLEND, absf(x - DEEP_RAMP_X))
	return super._tiers(x, z) + lerpf(cliff, ramp, on_ramp)


func _cover_top(plate: Dictionary) -> float:
	var c: Vector2 = (plate["rect"] as Rect2).get_center()
	return _tiers(c.x, c.y)


func overlay_height(id: String, x: float, z: float, _ground: float) -> float:
	for plate in breach_plates:
		if plate["id"] + "_before" == id and _inside(plate["rect"], x, z):
			return _cover_top(plate)
	return -INF
