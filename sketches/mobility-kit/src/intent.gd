extends RefCounted

var move := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var boost_pressed := false
var brake_held := false
var mount_pressed := false
var reel_held := false


func clear() -> void:
	move = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	boost_pressed = false
	brake_held = false
	mount_pressed = false
	reel_held = false


# A source lets the headless test drive the same player with no input at all.
class Source:
	extends RefCounted

	func poll(out) -> void:
		out.clear()


class Keyboard:
	extends Source

	var enabled := true

	func poll(out) -> void:
		out.clear()
		if not enabled:
			return
		out.move = Input.get_vector("lab_left", "lab_right", "lab_back", "lab_forward")
		out.jump_pressed = Input.is_action_just_pressed("lab_jump")
		out.jump_held = Input.is_action_pressed("lab_jump")
		out.boost_pressed = Input.is_action_just_pressed("lab_boost")
		out.brake_held = Input.is_action_pressed("lab_brake")
		out.mount_pressed = Input.is_action_just_pressed("lab_mount")
		out.reel_held = Input.is_action_pressed("lab_reel")
