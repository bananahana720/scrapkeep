extends RefCounted

const Route := preload("res://src/world/route.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")

# The laps mode's course (LOOP-REDESIGN section 1, Option C): the map's loop as five
# checkpoint rings, taken in order, bowl to bowl. Rolling into the Warden's ring rings
# the bell and lights the course; each full pass of the rings is a lap. World steps it
# and publishes what it returns; flow counts the laps against the Warden's sleep.
#
# The rings sit on the map's own loop fields (stage_map.gd, L1): the approach to the
# return lift in the bowl, the lift's landing on the top shelf, the fast drop line's
# start and first bend, and its kicker lip, which aims the lap's last ring at the mast.
# A ring is roll-through: a ball within RING_REACH of it, and no higher over its ground
# than RING_CEILING, has passed it, at any speed.
#
# Facts: {"kind": "bell", "at": Vector3}
#        {"kind": "ring", "index", "count", "at": Vector3}
#        {"kind": "lap", "lap", "required", "seconds", "at": Vector3}

const RING_REACH := 9.0
const RING_CEILING := 16.0
# The first ring stands this far short of the lift's mouth, on the way in from the mast,
# so it frames the lift instead of standing in its piston.
const LIFT_APPROACH := 9.0
# The second ring stands this far past the lift's landing on the ride's own heading
# (ride_rail.gd lets go along the arc with the banked speed returned), so the ball lands
# and rolls straight through it on that speed rather than dropping onto its rim.
const LANDING_ROLL := 8.0

var route
var rings: Array[Vector3] = []
var bell := Vector3.ZERO
var bell_radius := 30.0
var required := LoopMode.LAPS_REQUIRED
var bell_rung := false
var next_ring := 0
var laps := 0
var lap_times: Array[float] = []

var _since_lap := 0.0


# map is the stage map (its return_at, return_to and drop_lines), beacon the Warden's
# point, radius the beacon ring's, height the terrain's height(x, z).
func _init(map, beacon: Vector3, radius: float, height: Callable) -> void:
	bell = beacon
	bell_radius = radius
	var line: Dictionary = map.drop_lines[0]
	var mast := Vector2(beacon.x, beacon.z)
	var lift: Vector2 = map.return_at
	var landing: Vector2 = map.return_to
	var points: Array[Vector2] = [
		lift + (mast - lift).normalized() * LIFT_APPROACH,
		landing + (landing - lift).normalized() * LANDING_ROLL,
		line["start"],
		(line["via"] as Array)[0],
		line["at"],
	]
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	route = Route.new(closed)
	for p in points:
		rings.append(Vector3(p.x, height.call(p.x, p.y), p.y))


func count() -> int:
	return rings.size()


func awake() -> bool:
	return laps >= required


# The ring a lapper should roll for now: the bell until it rings, then the next ring.
func target() -> Vector3:
	return bell if not bell_rung else rings[next_ring]


# Which way a ring faces: along the lap, toward the next ring.
func facing(index: int) -> Vector2:
	var p := Vector2(rings[index].x, rings[index].z)
	return route.tangent(route.project(p).x + 0.5)


func step(delta: float, ball: Vector3) -> Array:
	var facts := []
	_since_lap += delta
	if not bell_rung:
		if Vector2(ball.x - bell.x, ball.z - bell.z).length() <= bell_radius:
			bell_rung = true
			_since_lap = 0.0
			facts.append({"kind": "bell", "at": bell})
		return facts
	var ring := rings[next_ring]
	if Vector2(ball.x - ring.x, ball.z - ring.z).length() > RING_REACH or ball.y - ring.y > RING_CEILING:
		return facts
	facts.append({"kind": "ring", "index": next_ring, "count": rings.size(), "at": ring})
	next_ring = (next_ring + 1) % rings.size()
	if next_ring == 0:
		laps += 1
		lap_times.append(_since_lap)
		facts.append({"kind": "lap", "lap": laps, "required": required, "seconds": _since_lap, "at": ring})
		_since_lap = 0.0
	return facts
