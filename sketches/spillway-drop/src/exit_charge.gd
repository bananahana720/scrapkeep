extends RefCounted

# The exit is three states and one number. Distance is passed in rather than
# looked up, so the charge can be stepped in a test without a camera or a clock.
enum { IDLE, CHARGING, READY }

const DURATION := 60.0
const RADIUS := 30.0

var phase := IDLE
var progress := 0.0


func begin() -> bool:
	if phase != IDLE:
		return false
	phase = CHARGING
	return true


func in_zone(distance: float) -> bool:
	return distance <= RADIUS


func advance(delta: float, distance: float) -> void:
	if phase != CHARGING or not in_zone(distance):
		return
	progress = minf(DURATION, progress + delta)
	if progress >= DURATION:
		phase = READY


func fraction() -> float:
	return progress / DURATION
