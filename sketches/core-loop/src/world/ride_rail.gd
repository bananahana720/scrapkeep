extends RefCounted

const Launch := preload("res://src/world/launch.gd")

# One contraption ride on the stage launch's rail maths (launch.gd arc_point): the
# cannon, the trebuchet, the geyser, the bay's cradle and pad, and the grapple line.
# The ball is held to the drawn path every tick, so nothing it clips on the way can
# cost it speed, and it lets go just before the path meets its landing.
#
# Speed is banked and returned, like the pylon mount. The flight's own planar speed is
# chosen so the arc lands on the target (the ball's speed, raised to the ride's floor,
# capped so a very fast ball still comes down on the pad instead of over the horizon);
# on letting go the ball gets back its own planar speed, or the floor if that was
# higher. A ride can keep or gift speed and never cut it.

const ARC := "arc"
const LINE := "line"
const MIN_LIFT := 4.0
const MAX_LIFT := 95.0
const LET_GO := 0.04

var kind := ""
var mode := ARC
var origin := Vector3.ZERO
var target := Vector3.ZERO
# The velocity at t = 0 (arc) or the constant velocity (line).
var velocity := Vector3.ZERO
var gravity := 26.0
# Seconds from origin to the landing.
var flight := 0.0
var time := 0.0
# The planar speed the ball gets back on letting go, and the heading it goes out on.
var release_speed := 0.0
var heading := Vector3.FORWARD
var active := false
# A cable ride's cable ends (the grapple line), for the line view's hanger; unset on every other ride.
var cable_from := Vector3.ZERO
var cable_to := Vector3.ZERO


# An arc from origin down onto target. planar_in is the ball's own planar speed.
# opts: "flight_planar" flies the arc at that planar speed whatever the ball's, and
# "release_heading" sends the ball out along it instead of along the arc.
static func arc(kind_id: String, from: Vector3, to: Vector3, planar_in: float, floor_speed: float, min_flight: float,
		g: float, opts := {}) -> RefCounted:
	var ride = load("res://src/world/ride_rail.gd").new()
	ride.kind = kind_id
	ride.mode = ARC
	ride.origin = from
	ride.target = to
	ride.gravity = g
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var dist := flat.length()
	ride.heading = flat.normalized() if dist > 0.01 else Vector3.FORWARD
	ride.release_speed = maxf(planar_in, floor_speed)
	var planar := minf(ride.release_speed, dist / maxf(0.2, min_flight))
	if opts.has("flight_planar"):
		planar = float(opts["flight_planar"])
	var t := maxf(0.2, dist / maxf(0.5, planar))
	var vy := (to.y - from.y + 0.5 * g * t * t) / t
	if vy > MAX_LIFT:
		vy = MAX_LIFT
		t = _landing_time(from.y, vy, to.y, g)
		planar = dist / t
	elif vy < float(opts.get("min_lift", MIN_LIFT)) and to.y < from.y:
		vy = float(opts.get("min_lift", MIN_LIFT))
		t = _landing_time(from.y, vy, to.y, g)
		planar = dist / t
	ride.velocity = ride.heading * planar + Vector3.UP * vy
	ride.flight = t
	ride.active = true
	if opts.has("release_heading"):
		var h: Vector3 = opts["release_heading"]
		ride.heading = Vector3(h.x, 0.0, h.z).normalized()
	return ride


# A straight rail from origin to target (the grapple line): constant velocity along it,
# with its planar part equal to the ball's speed raised to the floor.
static func line(kind_id: String, from: Vector3, to: Vector3, planar_in: float, floor_speed: float) -> RefCounted:
	var ride = load("res://src/world/ride_rail.gd").new()
	ride.kind = kind_id
	ride.mode = LINE
	ride.origin = from
	ride.target = to
	var d := to - from
	var flat := Vector3(d.x, 0.0, d.z)
	ride.heading = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	ride.release_speed = maxf(planar_in, floor_speed)
	var along: float = ride.release_speed * d.length() / maxf(0.01, flat.length())
	ride.velocity = d.normalized() * along
	ride.flight = d.length() / maxf(0.5, along)
	ride.active = true
	return ride


static func _landing_time(y0: float, vy: float, y1: float, g: float) -> float:
	var disc := vy * vy + 2.0 * g * (y0 - y1)
	return (vy + sqrt(maxf(0.0, disc))) / g


func point_at(t: float) -> Vector3:
	if mode == LINE:
		return origin + velocity * t
	return Launch.arc_point(origin, velocity, gravity, t)


func velocity_at(t: float) -> Vector3:
	if mode == LINE:
		return velocity
	return velocity + Vector3.DOWN * gravity * t


# The velocity to hold the ball to this tick, or null on the tick it lets go.
func step(delta: float):
	if not active:
		return null
	time += delta
	if time >= flight - LET_GO:
		active = false
		return null
	return velocity_at(time)


# What the ball leaves with: its banked planar speed along the heading, and the arc's
# own fall capped at SET_DOWN, so the rail sets the ball down a moment above its
# landing instead of throwing it at the ground. A hard vertical touchdown turns planar
# speed into friction (measured: the bay's pad landed at 57 m/s down and kept 9 of 22
# m/s), which is a stop the player never chose.
const SET_DOWN := 10.0


func release_velocity() -> Vector3:
	var vy := maxf(velocity_at(minf(time, flight)).y, -SET_DOWN)
	return heading * release_speed + Vector3.UP * vy
