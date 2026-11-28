extends RefCounted

const SpeedTier := preload("res://src/core/speed_tier.gd")
const Tuning := preload("res://src/movement/tuning.gd")

var velocity := Vector3.ZERO
var grounded := false
var contact_normal := Vector3.UP
var air_actions := 1
var coyote := 0.0
var jump_buffer := 0.0
var boost_cooldown := 0.0
var boost_buffer := 0.0
var impact := 0.0
var tier := 0
var cruise_boost := 1.0
var grip_hold := 0.0
var carving := false


func on_floor() -> bool:
	return grounded and contact_normal.y > Tuning.MAX_SLOPE_DOT


func speed() -> float:
	return velocity.length()


func planar_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func refresh_tier(cruise: float) -> void:
	tier = SpeedTier.of(velocity.length(), cruise)


func tick_timers(delta: float) -> void:
	coyote = maxf(0.0, coyote - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	boost_cooldown = maxf(0.0, boost_cooldown - delta)
	boost_buffer = maxf(0.0, boost_buffer - delta)
	impact = maxf(0.0, impact - delta * 18.0)


func reset() -> void:
	velocity = Vector3.ZERO
	grounded = false
	contact_normal = Vector3.UP
	air_actions = 1
	coyote = 0.0
	jump_buffer = 0.0
	boost_cooldown = 0.0
	boost_buffer = 0.0
	impact = 0.0
	tier = 0
	cruise_boost = 1.0
	grip_hold = 0.0
	carving = false
