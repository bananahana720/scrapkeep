extends RefCounted


enum { WAITING, ANNOUNCED, HOLDING, CHANGED, DONE }
const PHASE_NAMES := ["waiting", "announced", "holding", "changed", "done"]
const RIDE_WINDOW := 90.0
const RIDE_SECONDS := 0.4
const RIDE_SPEED := 0.7
const RIDE_LIFT := 1.0

var id := ""
var lead := 3.0
var footprint: Array = []
var ride_zone := {}
var phase := WAITING
var timer := 0.0
var announced_at := -1.0
var swapped_at := -1.0
var held := 0.0
var ridden := 0.0
var cruise := 14.0
var clock := 0.0

var _height: Callable


func _init(event_id: String, site: Dictionary, first_at: float, cruise_speed: float, height: Callable) -> void:
	id = event_id
	lead = site.get("lead", 3.0)
	footprint = site.get("footprint", [])
	ride_zone = site.get("ride", {})
	timer = first_at
	cruise = cruise_speed
	_height = height


func phase_name() -> String:
	return PHASE_NAMES[phase]


func fill() -> float:
	match phase:
		ANNOUNCED:
			return clampf(1.0 - timer / lead, 0.0, 1.0)
		HOLDING:
			return 1.0
	return 0.0


func changed() -> bool:
	return phase == CHANGED or (phase == DONE and swapped_at >= 0.0)


func inside(ball: Vector3) -> bool:
	for f in footprint:
		if Vector2(ball.x, ball.z).distance_to(f["centre"]) <= float(f["radius"]) + 1.0:
			return true
	return false


func centre() -> Vector2:
	return footprint[0]["centre"] if not footprint.is_empty() else Vector2.ZERO


func advance(delta: float, ball: Vector3, velocity: Vector3) -> Array:
	clock += delta
	var facts := []
	match phase:
		WAITING:
			timer -= delta
			if timer <= 0.0:
				phase = ANNOUNCED
				timer = lead
				announced_at = clock
				facts.append({"kind": "announced", "id": id, "seconds": lead, "at": _at3()})
				facts.append({"kind": "world", "fact": "cave_in_crumble" if id == "cave_in" else "impact_incoming", "at": _at3()})
		ANNOUNCED:
			timer -= delta
			if timer <= 0.0:
				if inside(ball):
					phase = HOLDING
				else:
					_swap(facts)
		HOLDING:
			held += delta
			if not inside(ball):
				_swap(facts)
		CHANGED:
			timer -= delta
			if _riding(ball, velocity):
				ridden += delta
				if ridden >= RIDE_SECONDS:
					phase = DONE
					var zone: Vector2 = ride_zone.get("centre", centre())
					facts.append({"kind": "world", "fact": "crater_ride" if id == "impact" else "route_opened", "at": _at3(zone)})
					facts.append({"kind": "milestone", "id": id, "at": zone})
					facts.append({"kind": "ended", "id": id, "outcome": "won"})
					return facts
			if timer <= 0.0:
				phase = DONE
				facts.append({"kind": "ended", "id": id, "outcome": "passed"})
	return facts


func _swap(facts: Array) -> void:
	phase = CHANGED
	timer = RIDE_WINDOW
	swapped_at = clock
	facts.append({"kind": "terrain_swap", "id": id, "at": centre()})
	facts.append({"kind": "started", "id": id})
	facts.append({"kind": "world", "fact": "cave_in_swap" if id == "cave_in" else "impact_swap", "at": _at3()})
	if id == "cave_in":
		facts.append({"kind": "world", "fact": "route_opened", "at": _at3(ride_zone.get("centre", centre()))})


func _riding(ball: Vector3, velocity: Vector3) -> bool:
	if ride_zone.is_empty():
		return false
	var d := Vector2(ball.x, ball.z).distance_to(ride_zone["centre"])
	if d > float(ride_zone["radius"]) or d < float(ride_zone.get("inner", 0.0)):
		return false
	if Vector2(velocity.x, velocity.z).length() < cruise * RIDE_SPEED:
		return false
	if float(ride_zone.get("inner", 0.0)) > 0.0:
		return ball.y - float(_height.call(ball.x, ball.z)) >= -0.5 and ball.y - _floor_y() >= RIDE_LIFT
	return true


func _floor_y() -> float:
	var c: Vector2 = ride_zone["centre"]
	return float(_height.call(c.x, c.y)) + 1.0


func _at3(p := Vector2.INF) -> Vector3:
	var c := centre() if p == Vector2.INF else p
	return Vector3(c.x, float(_height.call(c.x, c.y)), c.y)
