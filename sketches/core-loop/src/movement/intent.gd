extends RefCounted

# One tick of what the player asked for. Input fills it; nothing else reads a key.
# Combat reads fire and special from here, so a scripted source drives weapons too.

var move := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var boost_pressed := false
var brake_held := false
var mount_pressed := false
var reel_held := false
var fire_pressed := false
var fire_held := false
var special_pressed := false


func clear() -> void:
	move = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	boost_pressed = false
	brake_held = false
	mount_pressed = false
	reel_held = false
	fire_pressed = false
	fire_held = false
	special_pressed = false


# A source lets the headless test drive the same player with no input at all.
class Source:
	extends RefCounted

	func poll(out) -> void:
		out.clear()


# Holds a set of fields every tick and fires one-shot presses once. The spine tests use
# it, and a module test can too.
class Scripted:
	extends Source

	var hold := {}
	var press := {}

	func poll(out) -> void:
		out.clear()
		for key in hold:
			out.set(key, hold[key])
		for key in press:
			out.set(key, press[key])
		press = {}


class Keyboard:
	extends Source

	var enabled := true

	func poll(out) -> void:
		out.clear()
		if not enabled:
			return
		out.move = Input.get_vector("cl_left", "cl_right", "cl_back", "cl_forward")
		out.jump_pressed = Input.is_action_just_pressed("cl_jump")
		out.jump_held = Input.is_action_pressed("cl_jump")
		out.boost_pressed = Input.is_action_just_pressed("cl_boost")
		out.brake_held = Input.is_action_pressed("cl_brake")
		out.mount_pressed = Input.is_action_just_pressed("cl_mount")
		out.reel_held = Input.is_action_pressed("cl_reel")
		out.fire_pressed = Input.is_action_just_pressed("cl_fire")
		out.fire_held = Input.is_action_pressed("cl_fire")
		out.special_pressed = Input.is_action_just_pressed("cl_special")
