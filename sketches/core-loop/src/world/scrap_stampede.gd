extends RefCounted

const Route := preload("res://src/world/route.gd")


const HITS := 3
const CATCH := 3.6
const CATCH_UP := 3.5
const HIT_COOLDOWN := 1.0
const KNOCK_AHEAD := 6.0
const PANIC := 1.08
const SPEED := 1.0
const SCRAP_PER_HIT := 8
const RIDE := 1.4

var id := "scrap_stampede"
var ring := Vector2.ZERO
var ring_radius := 9.0
var route
var hauler := 0.0
var speed := 15.0
var hits := 0
var miniboss_at := -1.0

var _base_speed := 15.0
var _cooldown := 0.0
var _height: Callable
var _facts: Array = []


func _init(site: Dictionary, cruise: float, height: Callable) -> void:
	ring = site["ring"]
	route = Route.new(site["route"])
	_base_speed = cruise * SPEED
	_height = height


func begin() -> void:
	hauler = 0.0
	hits = 0
	speed = _base_speed
	_cooldown = 0.0
	_facts.clear()


func hauler_position() -> Vector3:
	var p: Vector2 = route.at(hauler)
	return Vector3(p.x, float(_height.call(p.x, p.y)) + RIDE, p.y)


func step(delta: float, ball: Vector3, _velocity: Vector3) -> String:
	hauler += speed * delta
	_cooldown -= delta
	var at := hauler_position()
	var flat := Vector2(ball.x - at.x, ball.z - at.z).length()
	if _cooldown <= 0.0 and flat <= CATCH and absf(ball.y - at.y) <= CATCH_UP:
		hits += 1
		_cooldown = HIT_COOLDOWN
		_facts.append({"kind": "scrap", "amount": SCRAP_PER_HIT, "at": at})
		hauler += KNOCK_AHEAD
		speed *= PANIC
		if hits >= HITS:
			return "won"
	if hauler >= route.total:
		return "lost"
	return ""


func push(_ball: Vector3, _velocity: Vector3) -> Vector3:
	return Vector3.ZERO


func progress() -> float:
	return float(hits) / float(HITS)


func spike() -> bool:
	return false


func status() -> String:
	return "Rammed %d/%d. Run it down!" % [hits, HITS]


func miniboss_zone() -> Array:
	return [route.at(route.total * 0.6), Vector2(14.0, 28.0)]


func take_facts() -> Array:
	var out := _facts
	_facts = []
	return out
