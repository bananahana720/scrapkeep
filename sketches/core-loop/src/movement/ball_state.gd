extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")
# Tuning.MAX_SLOPE_DOT; tuning.gd preloads nothing from here, but a copy keeps this file a leaf.
const MAX_SLOPE_DOT := 0.45

var velocity := Vector3.ZERO
var grounded := false
var contact_normal := Vector3.UP
var air_actions := 1
var coyote := 0.0
var jump_buffer := 0.0
var boost_cooldown := 0.0
# Seconds a boost pressed during its cooldown waits to fire (Tuning.BOOST_BUFFER).
var boost_buffer := 0.0
var impact := 0.0
var tier := 0
# Rivet's sprint raises the drive's cruise target by this factor while it runs.
var cruise_boost := 1.0
# Seconds of grip left: refilled at the fast tier, run down below it (Tuning.GRIP_PEEL_S).
var grip_hold := 0.0
# Riding a surface steeper than 25 degrees at grip speed: the wall lane. Floor threats read
# this as "not on the floor" (Andrew's "Commit", 2026-10-17). Set whatever the grip toggle.
var carving := false


# On a floor or a bank, not riding a gripped wall. Threats that live on the floor or in the
# air read this, so a carving ball meets them exactly as the airborne ball it was before grip.
func on_floor() -> bool:
	return grounded and contact_normal.y > MAX_SLOPE_DOT


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
