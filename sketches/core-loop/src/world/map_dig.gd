extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")


const UPPER_H := 12.0
const LOWER_H := 0.0
const CLIFF_Z := 0.0
const CLIFF_HALF := 2.0
const RAMP_Z := Vector2(-30.0, 30.0)
const RAMP_HALF := 12.0
const RAMP_BLEND := 6.0
const SWAP_PARK := 400.0
const PIT_WALL := 2.0

const BREACH_PLATES := [
	{"id": "plate_east", "rect": Rect2(34.0, -106.0, 12.0, 12.0), "drop_to": 4.0},
	{"id": "plate_west", "rect": Rect2(-56.0, -66.0, 12.0, 12.0), "drop_to": 4.0},
	{"id": "plate_rim", "rect": Rect2(44.0, -46.0, 14.0, 10.0), "drop_to": 2.0},
]

var start_overlays: Array[String] = []
var swaps := {}
var contraptions: Array = []
var rescue_sites: Array = []
var breach_plates: Array = []
var relic_spot := Vector2(-100.0, -40.0)


func _init() -> void:
	title = "Dig: the upper bench"
	spawn = Vector2(0.0, -120.0)
	heading = Vector3(0.0, 0.0, 1.0)
	beacon = Vector2(20.0, 90.0)
	beacon_floor = LOWER_H
	vault = Vector2(-40.0, -120.0)
	play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
	scatter["mix"] = {"long": 8, "scoop": 3, "rubble": 12, "strut": 5, "cart": 2, "shell": 3}
	scatter["relief"] = {"sub": 2, "amp": 0.12, "period": 2.6, "shade": 0.35, "seed": "relief_dig"}
	scatter["kit"] = [
		{"kind": "rock", "density": 1.0, "scale": Vector2(0.3, 0.8), "slope": 0.8, "bury": 0.35, "seed": "scatter_dig_rock", "mesh": "kit:rubble", "slot": "stone"},
		{"kind": "pebble", "density": 2.0, "scale": Vector2(0.1, 0.25), "slope": 0.8, "bury": 0.3, "seed": "scatter_dig_pebble", "mesh": "kit:pebble", "slot": "stone"},
		{"kind": "scrap", "density": 0.18, "scale": Vector2(0.25, 0.45), "slope": 0.85, "bury": 0.3, "seed": "scatter_dig_scrap", "mesh": "glb:res://assets/models/dig_mechanical/strut_bent.glb", "slot": "steel"},
		{"kind": "cable", "density": 0.2, "scale": Vector2(0.7, 1.2), "slope": 0.9, "bury": 0.4, "seed": "scatter_dig_cable", "mesh": "prim:coil", "slot": "cable"},
	]
	scrap_lines = [
		[Vector2(0.0, -110.0), Vector2(0.0, -40.0)],
		[Vector2(0.0, -20.0), Vector2(0.0, 25.0)],
		[Vector2(4.0, 40.0), Vector2(16.0, 76.0)],
	]
	gate_slots = [{"at": Vector2(50.0, 110.0), "facing": Vector3(0.0, 0.0, 1.0)}]
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(80.0, -130.0), "pack": ["chaser", "chaser", "lobber"], "pay": {"named": "rivet_plating"}},
		{"id": "ambush_altar", "at": Vector2(-80.0, 40.0)},
		{"id": "cracked_cache", "at": Vector2(-100.0, -100.0)},
	]
	rescue_sites = [{"id": "kest_cage", "quest": "dig", "prompt": "free the digger", "at": Vector2(-60.0, 90.0), "face": Vector2(1.0, 0.0)}]
	breach_plates = BREACH_PLATES.duplicate(true)
	for plate in breach_plates:
		start_overlays.append(plate["id"] + "_before")


func sample(x: float, z: float) -> Array:
	var h := _tiers(x, z)
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, clampf(h / _upper(), 0.0, 1.0) * 0.6)
	var plate = _plate_at(x, z)
	if plate != null:
		var r: Rect2 = plate["rect"]
		var inset := minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
		h = lerpf(h, float(plate["drop_to"]), clampf(inset / PIT_WALL, 0.0, 1.0))
		tint = Palette.CHARCOAL.lerp(Palette.RUST, 0.4)
	h += Features.rim(x, z)
	return [h, tint]


func _tiers(x: float, z: float) -> float:
	var cliff := lerpf(UPPER_H, LOWER_H, smoothstep(CLIFF_Z - CLIFF_HALF, CLIFF_Z + CLIFF_HALF, z))
	var ramp := lerpf(UPPER_H, LOWER_H, clampf((z - RAMP_Z.x) / (RAMP_Z.y - RAMP_Z.x), 0.0, 1.0))
	var on_ramp := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + RAMP_BLEND, absf(x))
	return lerpf(cliff, ramp, on_ramp)


func _upper() -> float:
	return UPPER_H


func _cover_top(_plate: Dictionary) -> float:
	return _upper()


func material_at(x: float, z: float) -> String:
	return "concrete" if _plate_at(x, z) != null else "sand"


func overlay_height(id: String, x: float, z: float, _ground: float) -> float:
	for plate in breach_plates:
		if plate["id"] + "_before" == id and _inside(plate["rect"], x, z):
			return _upper()
	return -INF


func build_props(parent: Node3D, _ground: Callable) -> void:
	swaps = {}
	for plate in breach_plates:
		var r: Rect2 = plate["rect"]
		var drop_to: float = plate["drop_to"]
		var top := _cover_top(plate)
		var c := r.get_center()
		var cover := box(parent, Vector3(r.size.x, top - drop_to, r.size.y),
			Vector3(c.x, (top + drop_to) * 0.5, c.y), PaletteMaterials.striped(Palette.RUST, Palette.CHARCOAL))
		cover.name = "BreachPlate_%s" % plate["id"]
		cover.set_meta("home", cover.position)
		swaps[plate["id"]] = {"before": [cover], "after": []}


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


func _plate_at(x: float, z: float):
	for plate in breach_plates:
		if _inside(plate["rect"], x, z):
			return plate
	return null


static func _inside(r: Rect2, x: float, z: float) -> bool:
	return x >= r.position.x and x <= r.end.x and z >= r.position.y and z <= r.end.y
