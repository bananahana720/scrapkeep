extends "res://src/world/stage_map.gd"

const Features := preload("res://src/world/features.gd")

# The Dig, greybox: two flat tiers split by a cliff along z = 0 and joined by one ramp
# down the middle. The upper tier holds the spawn and the vault; the lower tier holds
# the beacon and Kest's cage. Breach plates sit on the upper tier: each is a pit cut
# into the ground (sample() returns its drop_to) covered by a finished box at the upper
# tier, live as an overlay height until the plate breaks. Breaking one erases its id
# from the overlays and parks its box (apply_swap), so the floor drops with the ball
# on it and no stage is rebuilt (the map_gorge.gd cave-in way).

const UPPER_H := 12.0
const LOWER_H := 0.0
# The cliff between the tiers, and the ramp down it: 60 m for 12 m, a 0.2 grade,
# under the bot's CLIMB_SLOPE 0.5 (bot_driver.gd), so the ground route needs no slam.
const CLIFF_Z := 0.0
const CLIFF_HALF := 2.0
const RAMP_Z := Vector2(-30.0, 30.0)
const RAMP_HALF := 12.0
const RAMP_BLEND := 6.0
const SWAP_PARK := 400.0
# The pit wall's width inside a plate rect: one terrain grid STEP (terrain.gd), so the
# wall falls under the plate's box and the drop_to floor is flat.
const PIT_WALL := 2.0

# Upper tier. Each rect is at least 8 m a side and clear of the route down the ramp.
const BREACH_PLATES := [
	{"id": "plate_east", "rect": Rect2(34.0, -106.0, 12.0, 12.0), "drop_to": 4.0},
	{"id": "plate_west", "rect": Rect2(-56.0, -66.0, 12.0, 12.0), "drop_to": 4.0},
	{"id": "plate_rim", "rect": Rect2(44.0, -46.0, 14.0, 10.0), "drop_to": 2.0},
]

# The plates whose cover is live at stage start; every plate starts covered.
var start_overlays: Array[String] = []
# id -> {"before": [Node3D], "after": [Node3D]}, the map_gorge.gd shape.
var swaps := {}
# Contraption specs for contraptions.gd. None in the greybox.
var contraptions: Array = []
# Where a world rescue stands, each {"id", "quest", "at", "face"} (rescue_site.gd).
var rescue_sites: Array = []
# [{id: String, rect: Rect2, drop_to: float}]: the breakable floors.
var breach_plates: Array = []


func _init() -> void:
	title = "Dig: the upper bench"
	# Upper tier: the drop-in spot, north of the ramp head.
	spawn = Vector2(0.0, -120.0)
	heading = Vector3(0.0, 0.0, 1.0)
	# Lower tier: the beacon, south-east of the ramp foot.
	beacon = Vector2(20.0, 90.0)
	beacon_floor = LOWER_H
	# Upper tier: west of the spawn, off the route.
	vault = Vector2(-40.0, -120.0)
	play_rect = Rect2(-150.0, -150.0, 300.0, 300.0)
	scrap_lines = [
		[Vector2(0.0, -110.0), Vector2(0.0, -40.0)],
		[Vector2(0.0, -20.0), Vector2(0.0, 25.0)],
		[Vector2(4.0, 40.0), Vector2(16.0, 76.0)],
	]
	# Lower tier: the reward gates stand east of the beacon.
	gate_slots = [{"at": Vector2(50.0, 110.0), "facing": Vector3(0.0, 0.0, 1.0)}]
	# Upper tier: the camp sits in the north-east, away from the plates and the route.
	# World-one kinds only; the Dig's own kinds are not built yet.
	activity_sites = [{"id": "enemy_camp", "at": Vector2(80.0, -130.0), "pack": ["chaser", "chaser", "lobber"]}]
	# Lower tier: Kest's cage on flat ground west of the beacon, clear of the plates and the route.
	rescue_sites = [{"id": "kest_cage", "quest": "dig", "at": Vector2(-60.0, 90.0), "face": Vector2(1.0, 0.0)}]
	breach_plates = BREACH_PLATES.duplicate(true)
	for plate in breach_plates:
		# 2026-10-04: id + "_before" is the pre-break overlay, as map_gorge.gd and world._swap use it.
		start_overlays.append(plate["id"] + "_before")


# The two tiers, the ramp, the pits under the plates, and the shared rim walls.
func sample(x: float, z: float) -> Array:
	var cliff := lerpf(UPPER_H, LOWER_H, smoothstep(CLIFF_Z - CLIFF_HALF, CLIFF_Z + CLIFF_HALF, z))
	var ramp := lerpf(UPPER_H, LOWER_H, clampf((z - RAMP_Z.x) / (RAMP_Z.y - RAMP_Z.x), 0.0, 1.0))
	var on_ramp := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + RAMP_BLEND, absf(x))
	var h := lerpf(cliff, ramp, on_ramp)
	var tint: Color = Palette.SAND.lerp(Palette.SANDSTONE, clampf(h / UPPER_H, 0.0, 1.0) * 0.6)
	var plate = _plate_at(x, z)
	if plate != null:
		var r: Rect2 = plate["rect"]
		var inset := minf(minf(x - r.position.x, r.end.x - x), minf(z - r.position.y, r.end.y - z))
		h = lerpf(h, float(plate["drop_to"]), clampf(inset / PIT_WALL, 0.0, 1.0))
		tint = Palette.CHARCOAL.lerp(Palette.RUST, 0.4)
	h += Features.rim(x, z)
	return [h, tint]


func material_at(x: float, z: float) -> String:
	return "concrete" if _plate_at(x, z) != null else "sand"


# A plate's cover reads as the upper tier over its whole rect while its id is live.
func overlay_height(id: String, x: float, z: float, _ground: float) -> float:
	for plate in breach_plates:
		if plate["id"] + "_before" == id and _inside(plate["rect"], x, z):
			return UPPER_H
	return -INF


func build_props(parent: Node3D, _ground: Callable) -> void:
	swaps = {}
	for plate in breach_plates:
		var r: Rect2 = plate["rect"]
		var drop_to: float = plate["drop_to"]
		var c := r.get_center()
		var cover := box(parent, Vector3(r.size.x, UPPER_H - drop_to, r.size.y),
			Vector3(c.x, (UPPER_H + drop_to) * 0.5, c.y), Palette.striped(Palette.RUST, Palette.CHARCOAL))
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
