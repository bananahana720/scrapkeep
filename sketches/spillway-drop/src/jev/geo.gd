extends RefCounted

# Spillway Drop's layout as the Jev Lab reads it (JL-27): the three shelves, the four
# chutes, the bypass ramp, where the full flood reaches and where it does not, and the
# two ways between shelves. Everything is derived from terrain.gd's constants and height
# field; nothing here builds or moves anything. Static only, so the state view, the
# agent, the scenarios and the telemetry share one reading without preloading each
# other.

const Terrain := preload("res://src/terrain.gd")

enum { BASIN, MID, TOP }

const SHELF_NAMES := ["lower basin", "mid shelf", "top shelf"]
const SHELF_H := [Terrain.BASIN_H, Terrain.MID_H, Terrain.TOP_H]
const CHUTE_NAMES := ["west sluice", "east sluice", "west basin chute", "east basin chute"]
# The ball's centre stands this far above the ground it rolls on.
const BALL_CLEARANCE := 1.0

# Corridor half-widths for attributing a climb: a chute's channel is CHUTE_R wide plus
# its bank; the bypass deck is BYPASS_FLAT plus the raised lip beside it.
const CHUTE_HALF := Terrain.CHUTE_R + 4.0
const BYPASS_HALF := Terrain.BYPASS_FLAT + 5.0
# Where the ground route joins and leaves the bypass deck on each shelf: on the flat
# stretch of that shelf's deck (terrain.gd bypass_deck). The mid-shelf exit is north of
# the east basin chute's top and of the east bench, the one clear line west from the
# ramp: that chute's channel cuts the shelf from z 4 to the riser, and the bench (a 3 m
# box the height field does not hold) stands against its top end.
const BYPASS_ENTRY_Z := [118.0, 10.0, -100.0]
const BYPASS_EXIT_Z := [118.0, -8.0, -95.0]
# The chute route starts this far out from the chute's near end, on the axis, and
# leaves it this far past the far end: the channel's banks blend out 16 m past each
# end (terrain.gd _chute), and a ball turning inside that stretch rides up a bank.
const CHUTE_RUNUP := 14.0
const CHUTE_OUT := 26.0

# Points the full flood never reaches, and that a ball can roll to from the basin floor:
# the basin's west and east edge just outside the flood circle, and each basin chute
# part way up its floor. The test checks every one against the full water.
const REFUGES := [Vector2(-100.0, 106.0), Vector2(100.0, 106.0), Vector2(-18.0, 38.0), Vector2(96.0, 38.0)]

# PROTOCOL.md's anomaly thresholds.
const OVERSPEED := 80.0
const TUNNEL_DEPTH := 0.5


# The shelf a point stands over, by z: the middle of each riser divides them. A chute
# belongs to its upper shelf until its foot.
static func shelf_at(z: float) -> int:
	if z < (Terrain.RISER_TOP.x + Terrain.RISER_TOP.y) * 0.5:
		return TOP
	if z < (Terrain.RISER_MID.x + Terrain.RISER_MID.y) * 0.5:
		return MID
	return BASIN


# On the named shelf proper, not in a channel below it: the ball's centre within 1.5 m
# of the shelf's own height or above.
static func on_shelf(at: Vector3, shelf: int) -> bool:
	return shelf_at(at.z) == shelf and at.y >= SHELF_H[shelf] - 1.5


# "chute:<index>", "bypass" or "open".
static func corridor_at(at: Vector3) -> String:
	for i in Terrain.CHUTES.size():
		var c: Dictionary = Terrain.CHUTES[i]
		if absf(at.x - c["x"]) <= CHUTE_HALF and at.z >= c["z0"] - 2.0 and at.z <= c["z1"] + 2.0:
			return "chute:%d" % i
	if absf(at.x - Terrain.BYPASS_X) <= BYPASS_HALF:
		return "bypass"
	return "open"


static func route_kind(corridor: String) -> String:
	if corridor.begins_with("chute:"):
		return "chute"
	return corridor


static func location(at: Vector3) -> String:
	var corridor := corridor_at(at)
	if corridor == "bypass":
		return "bypass ramp"
	if corridor.begins_with("chute:"):
		return CHUTE_NAMES[int(corridor.trim_prefix("chute:"))]
	if Vector2(at.x, at.z).distance_to(Terrain.PUMP_HOUSE) <= 30.0:
		return "top shelf by pump house"
	return SHELF_NAMES[shelf_at(at.z)]


# --- the flood ----------------------------------------------------------------------

static func full_surface() -> float:
	return Terrain.height(Terrain.BASIN_CENTRE.x, Terrain.BASIN_CENTRE.y) + Terrain.FLOOD_DEPTH


# True where the full flood would drag a ball centred at `at`: flood.gd submerges only
# inside the basin circle and below the water plane.
static func wet_at_full(at: Vector3) -> bool:
	return Terrain.in_basin(at) and at.y < full_surface()


# Waypoints to the refuge with the shortest route. A refuge up a chute is entered at
# the chute's foot: the chute's banks stand metres above the basin floor, and a ball
# heading straight for the refuge rides up the bank and falls back (JL-27 probe).
static func refuge_route(from: Vector3) -> Array:
	var best := []
	var best_length := INF
	for spot in REFUGES:
		var points := []
		var chute := -1
		for i in Terrain.CHUTES.size():
			if in_channel(Terrain.at(spot, BALL_CLEARANCE), i):
				chute = i
		if chute >= 0 and not in_channel(from, chute):
			points.append(Terrain.at(near_end(chute, true), BALL_CLEARANCE))
		points.append(Terrain.at(spot, BALL_CLEARANCE))
		var length := 0.0
		var previous := Vector2(from.x, from.z)
		for p in points:
			length += previous.distance_to(Vector2(p.x, p.z))
			previous = Vector2(p.x, p.z)
		if length < best_length:
			best_length = length
			best = points
	return best


static func nearest_refuge(at: Vector3) -> Vector3:
	return refuge_route(at).back()


# --- the two ways between shelves ---------------------------------------------------

static func deck_point(z: float) -> Vector3:
	return Vector3(Terrain.BYPASS_X, Terrain.bypass_deck(z) + BALL_CLEARANCE, z)


# push_objective's waypoints: the guaranteed ground route. On one shelf or going down it
# is the straight line, since a riser can be dropped anywhere; going up it is the bypass
# ramp, the one climb every shelf has (README, "The stage").
static func ground_route(from: Vector3, to: Vector3) -> Array:
	var up_from := shelf_at(from.z)
	var up_to := shelf_at(to.z)
	if up_to <= up_from:
		return [to]
	var out := []
	if absf(from.x - Terrain.BYPASS_X) > Terrain.BYPASS_FLAT:
		out.append(deck_point(BYPASS_ENTRY_Z[up_from]))
	out.append(deck_point(BYPASS_EXIT_Z[up_to]))
	out.append(to)
	return out


# The chute between `from`'s shelf and the next shelf toward `to`'s, nearest by its near
# end (the foot going up, the mouth going down), or -1 when both are on one shelf.
static func chute_for(from: Vector3, to: Vector3) -> int:
	var here := shelf_at(from.z)
	var there := shelf_at(to.z)
	if here == there:
		return -1
	var going_up := there > here
	var next := here + (1 if going_up else -1)
	var best := -1
	var best_d := INF
	for i in Terrain.CHUTES.size():
		var c: Dictionary = Terrain.CHUTES[i]
		var upper := TOP if is_equal_approx(c["h0"], Terrain.TOP_H) else MID
		var lower := upper - 1
		if (going_up and (lower != here or upper != next)) or (not going_up and (upper != here or lower != next)):
			continue
		var d := Vector2(from.x, from.z).distance_to(near_end(i, going_up))
		if d < best_d:
			best_d = d
			best = i
	return best


# The foot's run-up point going up, the mouth's approach going down.
static func near_end(i: int, going_up: bool) -> Vector2:
	var c: Dictionary = Terrain.CHUTES[i]
	if going_up:
		return Vector2(c["x"], c["z1"] + CHUTE_RUNUP)
	return Vector2(c["x"], c["z0"] - CHUTE_RUNUP)


static func in_channel(at: Vector3, i: int) -> bool:
	var c: Dictionary = Terrain.CHUTES[i]
	return absf(at.x - c["x"]) <= Terrain.CHUTE_R and at.z >= c["z0"] - 2.0 and at.z <= c["z1"] + 4.0


# hit_kicker's waypoints: commit to chute_for's chute. Up: its foot on the axis, then
# out over its top onto the upper shelf, then `to`. Down: its mouth, out of its foot,
# then `to`. A ball already in the channel skips the approach. [] with no chute.
static func chute_route(from: Vector3, to: Vector3) -> Array:
	var i := chute_for(from, to)
	if i < 0:
		return []
	var c: Dictionary = Terrain.CHUTES[i]
	var going_up := shelf_at(to.z) > shelf_at(from.z)
	var start := near_end(i, going_up)
	var finish := Vector2(c["x"], c["z0"] - CHUTE_OUT) if going_up else Vector2(c["x"], c["z1"] + CHUTE_OUT)
	var out := []
	if not in_channel(from, i):
		out.append(Terrain.at(start, BALL_CLEARANCE))
	out.append(Terrain.at(finish, BALL_CLEARANCE))
	out.append(to)
	return out
