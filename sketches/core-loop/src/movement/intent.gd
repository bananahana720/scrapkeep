extends RefCounted


var move := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var boost_pressed := false
var brake_held := false
var mount_pressed := false
var mount_held := false
var interact_pressed := false
var fire_pressed := false
var fire_held := false
var fire_released := false
var special_pressed := false
var special_held := false
var special_released := false
var line_pressed := false
var line_held := false
var line_released := false
var movement_pressed := false
var movement_held := false
var movement_released := false
var shift_pressed := false
var shift_held := false
var shift_released := false
var harpoon_pressed := false
var harpoon_held := false
var harpoon_released := false
var cancel_pressed := false
var slot_pick := -1
var ultimate_pressed := false
var active_pressed := false


func clear() -> void:
	move = Vector2.ZERO
	jump_pressed = false
	jump_held = false
	boost_pressed = false
	brake_held = false
	mount_pressed = false
	mount_held = false
	interact_pressed = false
	fire_pressed = false
	fire_held = false
	fire_released = false
	special_pressed = false
	special_held = false
	special_released = false
	line_pressed = false
	line_held = false
	line_released = false
	movement_pressed = false
	movement_held = false
	movement_released = false
	harpoon_pressed = false
	harpoon_held = false
	harpoon_released = false
	cancel_pressed = false
	shift_pressed = false
	shift_held = false
	shift_released = false
	slot_pick = -1
	ultimate_pressed = false
	active_pressed = false


class Source:
	extends RefCounted

	func poll(out) -> void:
		out.clear()


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
	var held := false
	var walk := false
	var tuning

	func poll(out) -> void:
		out.clear()
		if not enabled or held:
			return
		out.move = Input.get_vector("cl_left", "cl_right", "cl_back", "cl_forward")
		out.jump_pressed = Input.is_action_just_pressed("cl_jump")
		out.jump_held = Input.is_action_pressed("cl_jump")
		out.shift_pressed = Input.is_action_just_pressed("cl_boost")
		out.shift_held = Input.is_action_pressed("cl_boost")
		out.shift_released = Input.is_action_just_released("cl_boost")
		out.brake_held = Input.is_action_pressed("cl_haul")
		out.mount_pressed = Input.is_action_just_pressed("cl_interact")
		out.mount_held = Input.is_action_pressed("cl_interact")
		out.fire_pressed = Input.is_action_just_pressed("cl_fire")
		out.fire_held = Input.is_action_pressed("cl_fire")
		out.fire_released = Input.is_action_just_released("cl_fire")
		out.harpoon_pressed = Input.is_action_just_pressed("cl_harpoon")
		out.harpoon_held = Input.is_action_pressed("cl_harpoon")
		out.harpoon_released = Input.is_action_just_released("cl_harpoon")
		out.ultimate_pressed = Input.is_action_just_pressed("cl_ultimate")
		out.active_pressed = Input.is_action_just_pressed("cl_active")
		var picks := ["cl_bay_1", "cl_bay_2", "cl_bay_3"]
		for i in picks.size():
			if Input.is_action_just_pressed(picks[i]):
				out.slot_pick = i
		if walk:
			out.mount_pressed = false
			out.mount_held = false
			out.fire_pressed = false
			out.fire_held = false
			out.fire_released = false
			out.harpoon_pressed = false
			out.harpoon_held = false
			out.harpoon_released = false
			out.ultimate_pressed = false
			out.slot_pick = -1
