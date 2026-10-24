extends RefCounted

const Route := preload("res://src/world/route.gd")

# Surge Run: roll into the ring and the sluice gates open behind you. A wall of water
# chases you down the route and the gates ahead must be taken in order before the
# front reaches each one. The front is the timer you can see, and riding just ahead
# of it pushes you on, so the surge is a threat and a tailwind in one body.

const GATE_COUNT := 6
const GATE_RADIUS := 7.5
const FRONT_START := -16.0
const FRONT_SPEED := 1.15
const PUSH := 14.0
const PUSH_BEHIND := 6.0
const PUSH_AHEAD := 14.0
const PUSH_WIDTH := 16.0
const GRACE := 2.0
# A park course's gates stand on a line's deck, so a ball on the ground under it takes none (activities.gd).
const GATE_HEIGHT := 8.0

var id := "surge_run"
var ring := Vector2.ZERO
var ring_radius := 9.0
var route
var gates: Array[Vector2] = []
var gate_distances: Array[float] = []
var next_gate := 0
var front := FRONT_START
# Where the front starts, behind the head (a park course starts it further back: surge_course.gd).
var front_start := FRONT_START
var front_speed := 16.0
var elapsed := 0.0
# Fraction of the run at which a miniboss arrives; below zero for none.
var miniboss_at := -1.0
# Each gate's deck height, or empty for the ground-level Reach, where only the plan counts.
var gate_heights: Array[float] = []


func _init(site: Dictionary, cruise: float) -> void:
	ring = site["ring"]
	route = Route.new(site["route"])
	front_speed = cruise * FRONT_SPEED
	var sway: float = site.get("sway", 0.0)
	var first := 28.0
	var last: float = route.total - 8.0
	for i in GATE_COUNT:
		var d := lerpf(first, last, float(i) / float(GATE_COUNT - 1))
		var side := Vector2(-route.tangent(d).y, route.tangent(d).x)
		gate_distances.append(d)
		gates.append(route.at(d) + side * sway * (1.0 if i % 2 == 0 else -1.0))


func begin() -> void:
	next_gate = 0
	front = front_start
	elapsed = 0.0


func step(delta: float, ball: Vector3, _velocity: Vector3) -> String:
	elapsed += delta
	front += front_speed * delta
	if next_gate < gates.size() and Vector2(ball.x, ball.z).distance_to(gates[next_gate]) <= GATE_RADIUS \
			and (gate_heights.is_empty() or absf(ball.y - gate_heights[next_gate]) <= GATE_HEIGHT):
		next_gate += 1
		if next_gate == gates.size():
			return "won"
	if next_gate < gates.size() and front >= gate_distances[next_gate] + GRACE:
		return "lost"
	return ""


# Riding the front: a push along the route while you are at the wall of water.
func push(ball: Vector3, velocity: Vector3) -> Vector3:
	var p: Vector2 = route.project(Vector2(ball.x, ball.z))
	if p.y > PUSH_WIDTH or p.x < front - PUSH_BEHIND or p.x > front + PUSH_AHEAD:
		return Vector3.ZERO
	if not gate_heights.is_empty() and absf(ball.y - deck_height(p.x)) > GATE_HEIGHT:
		return Vector3.ZERO
	var t: Vector2 = route.tangent(p.x)
	var along := Vector3(t.x, 0.0, t.y)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > front_speed * 1.6 and flat.normalized().dot(along) > 0.9:
		return Vector3.ZERO
	return along * PUSH


# The deck's height this far along, between the gates' heights (the first and last hold past the ends).
func deck_height(distance: float) -> float:
	if gate_heights.is_empty():
		return 0.0
	for i in range(1, gate_distances.size()):
		if distance <= gate_distances[i]:
			var span := gate_distances[i] - gate_distances[i - 1]
			var t := clampf((distance - gate_distances[i - 1]) / span, 0.0, 1.0) if span > 0.0 else 0.0
			return lerpf(gate_heights[i - 1], gate_heights[i], t)
	return gate_heights[gate_heights.size() - 1]


func progress() -> float:
	return float(next_gate) / float(gates.size())


func spike() -> bool:
	return false


func status() -> String:
	return "Gate %d/%d. Stay ahead of the surge." % [mini(next_gate + 1, gates.size()), gates.size()]


func front_point() -> Vector2:
	return route.at(maxf(front, 0.0))


func front_tangent() -> Vector2:
	return route.tangent(maxf(front, 0.0))


# Where a miniboss may arrive: somewhere ahead on the run, off to its side.
func miniboss_zone() -> Array:
	return [route.at(route.total * 0.75), Vector2(12.0, 26.0)]


func take_facts() -> Array:
	return []
