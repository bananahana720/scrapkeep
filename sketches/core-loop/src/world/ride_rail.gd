extends RefCounted

const Launch := preload("res://src/world/launch.gd")


const ARC := "arc"
const LINE := "line"
const MIN_LIFT := 4.0
const MAX_LIFT := 95.0
const LET_GO := 0.04
const RIVET_GRIND_SPEED_MULT := 1.20
const RAIL_SNAP_RADIUS := 5.5
const RAIL_LIFT_M := 1.05

var kind := ""
var mode := ARC
var origin := Vector3.ZERO
var target := Vector3.ZERO
var velocity := Vector3.ZERO
var gravity := 26.0
var flight := 0.0
var time := 0.0
var release_speed := 0.0
var heading := Vector3.FORWARD
var active := false
var cable_from := Vector3.ZERO
var cable_to := Vector3.ZERO
var allow_fire := false
var rail_kind := ""
var rail_id := ""


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


func step(delta: float):
	if not active:
		return null
	time += delta
	if time >= flight - LET_GO:
		active = false
		return null
	return velocity_at(time)


const SET_DOWN := 10.0


func release_velocity() -> Vector3:
	var vy := maxf(velocity_at(minf(time, flight)).y, -SET_DOWN)
	return heading * release_speed + Vector3.UP * vy


static func extract_map_rails(map) -> Array:
	var out: Array = []
	if map == null:
		return out
	var contraptions_list = map.get("contraptions")
	if contraptions_list is Array:
		for c in contraptions_list:
			if not (c is Dictionary) or String(c.get("kind", "")) != "cable":
				continue
			var p0: Variant = c.get("from", null)
			var p1: Variant = c.get("to", null)
			var a := _to_vec3(p0)
			var b := _to_vec3(p1)
			if a == Vector3.INF or b == Vector3.INF or a.distance_to(b) < 2.0:
				continue
			out.append({
				"id": String(c.get("id", "zip")),
				"kind": "zip",
				"from": a,
				"to": b,
				"floor": float(c.get("floor", 18.0)),
				"width": maxf(2.5, float(c.get("radius", 4.0))),
			})
	var park_data = map.get("park")
	if park_data is Dictionary and park_data.has("park_rows"):
		for row in park_data["park_rows"]:
			if not (row is Dictionary):
				continue
			var elem := String(row.get("element", ""))
			var verb := String(row.get("verb", ""))
			var landform := String(row.get("landform", ""))
			var recipe := String(row.get("recipe", ""))
			if elem != "grind_line" and elem != "rail" and verb != "grind":
				continue
			if verb == "swing":
				continue
			var sz := _to_vec3(row.get("size", null))
			var at_raw = row.get("at", null)
			if sz == Vector3.INF or not (at_raw is Array) or at_raw.size() < 2:
				continue
			var span_len := maxf(absf(sz.x), absf(sz.z))
			var cross_w := minf(absf(sz.x), absf(sz.z))
			if span_len < 6.0 or sz.y > span_len:
				continue
			var cx := float(at_raw[0])
			var cz := float(at_raw[1])
			var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
			var facing := Vector2(sin(yaw), cos(yaw))
			var along2 := facing if absf(sz.x) >= absf(sz.z) else Vector2(facing.y, -facing.x)
			if along2.length_squared() < 0.0001:
				along2 = Vector2(0.0, 1.0)
			else:
				along2 = along2.normalized()
			var half_len := span_len * 0.5
			var p0_2 := Vector2(cx, cz) - along2 * half_len
			var p1_2 := Vector2(cx, cz) + along2 * half_len
			var y_raw = row.get("y", null)
			var y0 := 0.0
			var y1 := 0.0
			if y_raw != null:
				var base_y := float(y_raw) + sz.y * 0.5
				y0 = base_y
				y1 = base_y
			elif map.has_method("height"):
				y0 = float(map.height(p0_2.x, p0_2.y)) + sz.y * 0.5
				y1 = float(map.height(p1_2.x, p1_2.y)) + sz.y * 0.5
			var rail_kind := "rail"
			if landform == "pipeline" or "pipe" in recipe:
				rail_kind = "pipe"
			elif landform == "canal" or "canal_lip" in recipe:
				rail_kind = "canal_lip"
			elif landform == "flume" or "trestle" in recipe or "flume" in recipe:
				rail_kind = "trestle"
			out.append({
				"id": String(row.get("id", "rail")),
				"kind": rail_kind,
				"from": Vector3(p0_2.x, y0, p0_2.y),
				"to": Vector3(p1_2.x, y1, p1_2.y),
				"floor": 18.0,
				"width": maxf(2.5, cross_w * 0.5),
			})
	return out


static func _to_vec3(raw) -> Vector3:
	if raw is Vector3:
		return raw
	if raw is Array and raw.size() >= 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.INF


static func find_nearest_rail(rails: Array, point: Vector3, heading: Vector3, max_dist := RAIL_SNAP_RADIUS) -> Dictionary:
	var best := {}
	var best_d := max_dist
	var flat_head := Vector3(heading.x, 0.0, heading.z)
	if flat_head.length_squared() > 0.0001:
		flat_head = flat_head.normalized()
	for rail in rails:
		if not (rail is Dictionary):
			continue
		var a: Vector3 = rail.get("from", Vector3.ZERO)
		var b: Vector3 = rail.get("to", Vector3.ZERO)
		if a.distance_squared_to(b) < 4.0:
			continue
		var closest := Geometry3D.get_closest_point_to_segment(point, a, b)
		var reach := maxf(max_dist, float(rail.get("width", 0.0)) + 1.5)
		var d := point.distance_to(closest)
		if d > reach or d >= best_d:
			continue
		var ab := (b - a).normalized()
		var target := b
		var dir := ab
		if flat_head.length_squared() > 0.0001:
			var flat_ab := Vector3(ab.x, 0.0, ab.z)
			if flat_ab.length_squared() > 0.0001 and flat_ab.normalized().dot(flat_head) < 0.0:
				target = a
				dir = -ab
		if closest.distance_to(target) < 2.0:
			var alt := a if target == b else b
			if closest.distance_to(alt) >= 2.0:
				target = alt
				dir = (alt - closest).normalized()
			else:
				continue
		best_d = d
		best = {
			"rail": rail,
			"id": String(rail.get("id", "rail")),
			"kind": String(rail.get("kind", "rail")),
			"closest": closest,
			"target": target,
			"dir": dir,
			"dist": d,
		}
	return best


static func rivet_grind(rail_hit: Dictionary, ball: Vector3, planar_in: float, top_speed_base: float) -> RefCounted:
	var rail: Dictionary = rail_hit["rail"]
	var start: Vector3 = rail_hit["closest"] + Vector3.UP * RAIL_LIFT_M
	var end: Vector3 = rail_hit["target"] + Vector3.UP * RAIL_LIFT_M
	if String(rail_hit.get("kind", "")) == "zip":
		start = rail_hit["closest"] - Vector3.UP * 1.1
		end = rail_hit["target"] - Vector3.UP * 1.1
	var floor_speed := maxf(float(rail.get("floor", 18.0)), top_speed_base)
	var boost_speed := maxf(planar_in, floor_speed) * RIVET_GRIND_SPEED_MULT
	var ride = line("rivet_rail", start, end, boost_speed, boost_speed)
	ride.allow_fire = true
	ride.rail_kind = String(rail_hit.get("kind", "rail"))
	ride.rail_id = String(rail_hit.get("id", "rail"))
	if ride.rail_kind == "zip":
		ride.cable_from = rail.get("from", start)
		ride.cable_to = rail.get("to", end)
	return ride
