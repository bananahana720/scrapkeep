extends RefCounted


const RAMP := 3.0
const WIND := 5.0
const FOG_MAX := 0.006

var id := "dust_squall"
var wind := Vector2(1.0, 0.0)
var active_seconds := 16.0
var elapsed := 0.0
var live := false


func _init(direction: Vector2) -> void:
	wind = direction.normalized()


func begin(seconds: float) -> void:
	active_seconds = seconds
	elapsed = 0.0
	live = true


func step(delta: float) -> bool:
	if not live:
		return false
	elapsed += delta
	if elapsed >= active_seconds:
		live = false
		return true
	return false


func intensity() -> float:
	if not live:
		return 0.0
	return clampf(minf(elapsed / RAMP, (active_seconds - elapsed) / RAMP), 0.0, 1.0)


func fog_density(base: float) -> float:
	return lerpf(base, FOG_MAX, intensity())


func accel() -> Vector3:
	return Vector3(wind.x, 0.0, wind.y) * WIND * intensity()
