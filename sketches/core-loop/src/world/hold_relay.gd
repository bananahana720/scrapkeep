extends RefCounted

# Hold the Relay: roll into the relay's ring and it starts to transmit. It charges
# while you are inside the ring, circling, ramming or turreted on one of its walls,
# and pauses (never resets) while you are out. The director spikes spawns at it, and
# a miniboss arrives partway through. Fill it before the window closes.

const HOLD_SECONDS := 18.0
const WINDOW := 60.0
const RADIUS := 24.0
const REACH_UP := 14.0

var id := "hold_the_relay"
var ring := Vector2.ZERO
var ring_radius := RADIUS
var relay := Vector2.ZERO
var held := 0.0
var elapsed := 0.0
var inside := false
var miniboss_at := 0.35
var _relay_y := 0.0


func _init(site: Dictionary, relay_y: float) -> void:
	relay = site["relay"]
	ring = site["ring"]
	_relay_y = relay_y


func begin() -> void:
	held = 0.0
	elapsed = 0.0


func step(delta: float, ball: Vector3, _velocity: Vector3) -> String:
	elapsed += delta
	inside = Vector2(ball.x, ball.z).distance_to(relay) <= RADIUS and ball.y < _relay_y + REACH_UP
	if inside:
		held += delta
		if held >= HOLD_SECONDS:
			return "won"
	if elapsed >= WINDOW:
		return "lost"
	return ""


func push(_ball: Vector3, _velocity: Vector3) -> Vector3:
	return Vector3.ZERO


func progress() -> float:
	return clampf(held / HOLD_SECONDS, 0.0, 1.0)


func spike() -> bool:
	return true


func status() -> String:
	var line := "Relay %d%%. %d s left." % [int(progress() * 100.0), int(ceil(WINDOW - elapsed))]
	return line if inside else line + " Back in the ring!"


func miniboss_zone() -> Array:
	return [relay, Vector2(RADIUS + 8.0, RADIUS + 22.0)]


func take_facts() -> Array:
	return []
