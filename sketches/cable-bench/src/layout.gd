extends RefCounted

# One declarative description of Cable Bench. The height field, the props, the loot
# spots, the cableways and the tests all read this table, so moving a bench or a
# kicker moves everything that depends on it instead of drifting out of sync.

const HALF := 200.0
const STEP := 2.0

# Benches climb from the south (high z, ground level) to the forging apron in the
# north. Between two benches is an unclimbable rock face, cut by exactly one road
# corridor, and the corridor alternates sides: that is the switchback.
const LEVELS := [0.0, 13.0, 26.0, 39.0, 52.0, 62.0]
const CLIFF_Z := [112.0, 46.0, -20.0, -86.0, -140.0]
const ROAD_X := [-130.0, 130.0, -130.0, 130.0, 0.0]
const ROAD_HALF := 18.0
const ROAD_FLARE := 34.0
const CLIFF_HALF := 3.0
const ROAD_RUN := 34.0

# A rail siding is a shallow trough running the full width of a bench: the
# straightaway between two switchback turns.
const SIDING_Z := [152.0, 80.0, 14.0, -52.0, -114.0]
const SIDING_HALF := 8.0
const SIDING_DEPTH := 1.7

const MESA_RADIUS := 14.0
const MESA_EXTRA := 7.0
const MESA_WALL := 2.6
const MESA_CHUTE := 26.0
# name, centre, the compass direction the roll-down chute faces, and the side the
# kicker approaches from (-1 approaches travelling +x, +1 travelling -x).
const MESAS := [
	{"name": "east ledge", "centre": Vector2(60.0, 80.0), "chute": Vector2(1.0, 0.35), "approach": -1.0},
	{"name": "drill shelf", "centre": Vector2(-60.0, 14.0), "chute": Vector2(-1.0, 0.35), "approach": 1.0},
	{"name": "tank roost", "centre": Vector2(50.0, -52.0), "chute": Vector2(1.0, -0.35), "approach": -1.0},
]

# Kicker geometry, solved once here: the ramp's high lip sits just above its mesa
# top and KICKER_GAP short of the wall, so the gate is carrying speed up the ramp
# and across the gap rather than any vertical launch.
const KICKER_SIZE := Vector3(13.0, 1.8, 30.0)
const KICKER_DEGREES := 18.0
const KICKER_GAP := 3.5
const KICKER_LIP_ABOVE_TOP := 0.4

const RIM_START := 176.0
const RIM_END := 198.0
const RIM_HEIGHT := 30.0

const SPAWN := Vector2(46.0, 154.0)
const FIRST_LINE := Vector2(-130.0, 120.0)
const FORGE := Vector2(0.0, -168.0)
const FORGE_RADIUS := 30.0
const SECRET := Vector2(-150.0, 30.0)

const CABLEWAYS := [
	{"from": Vector2(-172.0, 98.0), "to": Vector2(172.0, 62.0), "speed": 30.0, "phase": 0.0},
	{"from": Vector2(172.0, 32.0), "to": Vector2(-172.0, -2.0), "speed": 26.0, "phase": 4.0},
	{"from": Vector2(-172.0, -34.0), "to": Vector2(172.0, -70.0), "speed": 34.0, "phase": 2.0},
	{"from": Vector2(172.0, -100.0), "to": Vector2(-172.0, -126.0), "speed": 28.0, "phase": 6.0},
]

# Ground-level caches: cheap to reach, so their draw is the tier clock, not the line.
const GROUND_CACHES := [
	Vector2(-120.0, 150.0),
	Vector2(118.0, -44.0),
	Vector2(-104.0, -112.0),
	Vector2(34.0, -160.0),
]


static func level_of(z: float) -> int:
	var level := 0
	for k in CLIFF_Z.size():
		if z < CLIFF_Z[k]:
			level = k + 1
	return level


static func mesa_top(index: int) -> float:
	var centre: Vector2 = MESAS[index]["centre"]
	return _ground(centre.x, centre.y) + MESA_EXTRA


# Ground before mesas are blended in, so a mesa can be defined relative to it
# without the height function recursing.
static func _ground(x: float, z: float) -> float:
	return terrace(x, z) + relief(x, z) + siding(x, z)


static func terrace(x: float, z: float) -> float:
	var h := 0.0
	for k in CLIFF_Z.size():
		var rise: float = LEVELS[k + 1] - LEVELS[k]
		var cliff_z: float = CLIFF_Z[k]
		var cliff := 1.0 - smoothstep(cliff_z - CLIFF_HALF, cliff_z + CLIFF_HALF, z)
		var road := 1.0 - smoothstep(cliff_z - CLIFF_HALF, cliff_z + ROAD_RUN, z)
		var weight := 1.0 - smoothstep(ROAD_HALF, ROAD_FLARE, absf(x - ROAD_X[k]))
		h += rise * lerpf(cliff, road, weight)
	return h


static func relief(x: float, z: float) -> float:
	return 1.1 * sin(x * 0.037) * cos(z * 0.031) + 0.7 * sin((x - z) * 0.021)


static func siding(x: float, z: float) -> float:
	var cut := 0.0
	for sz in SIDING_Z:
		var t: float = clampf(absf(z - sz) / SIDING_HALF, 0.0, 1.0)
		# Parabolic trough with a flat floor: it funnels a line without trapping.
		cut = minf(cut, -SIDING_DEPTH * (1.0 - t * t) * (1.0 - smoothstep(150.0, 176.0, absf(x))))
	return cut


static func height(x: float, z: float) -> float:
	var h := _ground(x, z)
	for i in MESAS.size():
		var m: Dictionary = MESAS[i]
		var centre: Vector2 = m["centre"]
		var offset := Vector2(x, z) - centre
		var d := offset.length()
		var chute: Vector2 = (m["chute"] as Vector2).normalized()
		var facing := 0.0 if d < 0.001 else offset.normalized().dot(chute)
		# The chute side gets a long shallow skirt; everywhere else is a wall.
		var skirt: float = lerpf(MESA_WALL, MESA_CHUTE, clampf((facing - 0.55) / 0.45, 0.0, 1.0))
		var weight := 1.0 - smoothstep(MESA_RADIUS, MESA_RADIUS + skirt, d)
		h = lerpf(h, mesa_top(i), weight)
	return h + rim(x, z)


static func rim(x: float, z: float) -> float:
	return RIM_HEIGHT * smoothstep(RIM_START, RIM_END, maxf(absf(x), absf(z)))


static func drop_point(x: float, z: float, clearance := 1.6) -> Vector3:
	return Vector3(x, height(x, z) + clearance, z)


static func drop_at(spot: Vector2, clearance := 1.6) -> Vector3:
	return drop_point(spot.x, spot.y, clearance)


# The kicker is a box tilted about its local X. Its top face's high lip is
# KICKER_LIP_ABOVE_TOP over the mesa top and KICKER_GAP short of the mesa wall.
static func kicker_transform(index: int) -> Transform3D:
	var m: Dictionary = MESAS[index]
	var centre: Vector2 = m["centre"]
	var approach: float = m["approach"]
	var radians := deg_to_rad(KICKER_DEGREES)
	var lip_rise := KICKER_SIZE.z * 0.5 * sin(radians) + KICKER_SIZE.y * 0.5 * cos(radians)
	var lip_reach := KICKER_SIZE.z * 0.5 * cos(radians) - KICKER_SIZE.y * 0.5 * sin(radians)
	var distance := MESA_RADIUS + KICKER_GAP + lip_reach
	var origin := Vector3(
		centre.x + approach * distance,
		mesa_top(index) + KICKER_LIP_ABOVE_TOP - lip_rise,
		centre.y)
	# approach -1 means the ball travels +x, so the ramp's +z end must point +x.
	var yaw := PI * 0.5 if approach < 0.0 else -PI * 0.5
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -radians)
	return Transform3D(basis, origin)


static func kicker_entry(index: int) -> Vector3:
	var xform := kicker_transform(index)
	var foot: Vector3 = xform.origin - xform.basis.z * (KICKER_SIZE.z * 0.5 + 6.0)
	return Vector3(foot.x, height(foot.x, foot.z) + 1.2, foot.z)


static func kicker_run_direction(index: int) -> Vector3:
	return kicker_transform(index).basis.z.normalized()


static func spawn_point() -> Vector3:
	return drop_at(SPAWN, 2.5)


static func spawn_yaw() -> float:
	var dir := (FIRST_LINE - SPAWN).normalized()
	return atan2(-dir.x, -dir.y)


static func forge_point() -> Vector3:
	return drop_at(FORGE, 0.0)


static func cache_spots() -> Array:
	var spots := []
	for i in MESAS.size():
		spots.append({"name": MESAS[i]["name"], "at": drop_point(MESAS[i]["centre"].x, MESAS[i]["centre"].y, 1.2)})
	for spot in GROUND_CACHES:
		spots.append({"name": "roadside", "at": drop_at(spot, 1.2)})
	spots.append({"name": "secret", "at": drop_at(SECRET, 1.2)})
	return spots
