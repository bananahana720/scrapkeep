extends RefCounted

const Interactables := preload("res://src/world/interactables.gd")


var mouth := Vector3.ZERO
var heading := Vector3.FORWARD
var length := Interactables.LANE_LENGTH
var half_width := 5.0
var mouth_radius := 3.0
var rise := 6.0
var armed := false


func _init(mouth_at := Vector3.ZERO, ride_heading := Vector3.FORWARD, lane_half_width := 5.0, mouth_half_width := 3.0) -> void:
	mouth = mouth_at
	heading = Vector3(ride_heading.x, 0.0, ride_heading.z).normalized()
	half_width = lane_half_width
	mouth_radius = mouth_half_width


func along(p: Vector3) -> float:
	return Vector2(p.x - mouth.x, p.z - mouth.z).dot(Vector2(heading.x, heading.z))


func across(p: Vector3) -> float:
	return Vector2(p.x - mouth.x, p.z - mouth.z).dot(Vector2(-heading.z, heading.x))


func in_lane(p: Vector3) -> bool:
	var u := along(p)
	return u >= -length and u <= 0.5 and absf(across(p)) <= half_width and absf(p.y - mouth.y) <= rise


func arm() -> void:
	armed = true


func step(from: Vector3, to: Vector3) -> bool:
	if not armed or from == Vector3.INF:
		return false
	var u0 := along(from)
	var u1 := along(to)
	if u0 < 0.0 and u1 >= 0.0:
		armed = false
		var cross := from.lerp(to, -u0 / (u1 - u0))
		return absf(across(cross)) <= mouth_radius and absf(cross.y - mouth.y) <= rise
	if not in_lane(to):
		armed = false
	return false
