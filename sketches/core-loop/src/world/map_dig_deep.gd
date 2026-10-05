extends "res://src/world/map_dig.gd"

# The Dig, second zone, greybox: the upper bench and its lower tier from map_dig.gd, then a
# second cliff along z = 70 down to a deep tier, joined by a second ramp east of the first.
# The spawn and vault stay on the upper tier, the beacon and its gates stand on the deep tier.
# Two more breach plates sit on the middle tier (map_dig's lower one) and drop into the deep;
# their covers top out at the middle tier, not the upper one (_cover_top).

const DEEP_H := -12.0
# The second cliff, and its ramp: 60 m for 12 m, the first ramp's 0.2 grade.
const DEEP_CLIFF_Z := 70.0
const DEEP_RAMP_Z := Vector2(40.0, 100.0)
const DEEP_RAMP_X := 40.0

# Middle tier. Each rect is at least 8 m a side, clear of both ramps and the route.
const MIDDLE_PLATES := [
	{"id": "plate_mid_west", "rect": Rect2(-76.0, 20.0, 12.0, 12.0), "drop_to": DEEP_H + 4.0},
	{"id": "plate_mid_east", "rect": Rect2(84.0, 24.0, 12.0, 12.0), "drop_to": DEEP_H + 4.0},
]


func _init() -> void:
	super()
	title = "Dig: the deep works"
	# Upper tier: the drop-in spot, west of the first map's.
	spawn = Vector2(-24.0, -128.0)
	# Deep tier: the beacon, south of the second ramp's foot.
	beacon = Vector2(40.0, 130.0)
	beacon_floor = DEEP_H
	# Upper tier: east of the spawn, north of plate_east.
	vault = Vector2(40.0, -130.0)
	scrap_lines = [
		[Vector2(-20.0, -116.0), Vector2(-4.0, -50.0)],
		[Vector2(0.0, -20.0), Vector2(0.0, 25.0)],
		[Vector2(10.0, 32.0), Vector2(32.0, 38.0)],
		[Vector2(40.0, 50.0), Vector2(40.0, 96.0)],
	]
	# Deep tier: the reward gates stand east of the beacon.
	gate_slots = [{"at": Vector2(80.0, 140.0), "facing": Vector3(0.0, 0.0, 1.0)}]
	# Upper tier: the cache. Middle tier: the camp, in the Dig's own kinds, and the ambush.
	activity_sites = [
		{"id": "enemy_camp", "at": Vector2(120.0, 50.0), "pack": ["burrower", "drill_crew", "lamp_swarm"],
			"pay": {"named": "pylon_capacitor"}},
		{"id": "ambush_altar", "at": Vector2(-110.0, 40.0)},
		{"id": "cracked_cache", "at": Vector2(-100.0, -100.0)},
	]
	# Deep tier, west of the beacon and south of Kest's cage: the relic cache.
	relic_spot = Vector2(-80.0, 120.0)
	breach_plates = BREACH_PLATES.duplicate(true) + MIDDLE_PLATES.duplicate(true)
	start_overlays.clear()
	for plate in breach_plates:
		start_overlays.append(plate["id"] + "_before")


# map_dig's tiers, then the second drop: zero north of z 40, DEEP_H - LOWER_H past the cliff.
func _tiers(x: float, z: float) -> float:
	var drop := DEEP_H - LOWER_H
	var cliff := drop * smoothstep(DEEP_CLIFF_Z - CLIFF_HALF, DEEP_CLIFF_Z + CLIFF_HALF, z)
	var ramp := drop * clampf((z - DEEP_RAMP_Z.x) / (DEEP_RAMP_Z.y - DEEP_RAMP_Z.x), 0.0, 1.0)
	var on_ramp := 1.0 - smoothstep(RAMP_HALF, RAMP_HALF + RAMP_BLEND, absf(x - DEEP_RAMP_X))
	return super._tiers(x, z) + lerpf(cliff, ramp, on_ramp)


# A plate's cover tops out at the tier it was cut into.
func _cover_top(plate: Dictionary) -> float:
	var c: Vector2 = (plate["rect"] as Rect2).get_center()
	return _tiers(c.x, c.y)


func overlay_height(id: String, x: float, z: float, _ground: float) -> float:
	for plate in breach_plates:
		if plate["id"] + "_before" == id and _inside(plate["rect"], x, z):
			return _cover_top(plate)
	return -INF
