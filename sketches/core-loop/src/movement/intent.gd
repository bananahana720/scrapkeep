extends RefCounted

# One tick of what the player asked for. Input fills it; nothing else reads a key.
# Combat reads fire and special from here, so a scripted source drives weapons too.
# The grammar is the same for every class (design-v3/LEGIBILITY.md section 3): LMB weapon,
# RMB the harpoon, F the hold-gauge-release special, Ctrl the haul, Space jump, Shift the
# pilot's go verb.
# A held key's release is its own one-tick field. A scripted press with no hold reads
# as a tap.

var move := Vector2.ZERO
var jump_pressed := false
var jump_held := false
var boost_pressed := false
var brake_held := false
var mount_pressed := false
# E is interact everywhere (LOOP-REDESIGN section 9). mount_held is E held; the player
# turns a press an interactable claims into interact_pressed, so mount_pressed is left
# only for Sable's pylon.
var mount_held := false
var interact_pressed := false
var fire_pressed := false
var fire_held := false
var fire_released := false
var special_pressed := false
var special_held := false
var special_released := false
var movement_pressed := false
var movement_held := false
var movement_released := false
# The harpoon's own key, right mouse, for every pilot. Shift is the pilot's one go verb: the
# keyboard fills shift_*, and the player turns it into boost_pressed for Sable or movement_*
# (the class burst) for Rivet and Kest. A scripted source may fill boost_* and movement_*
# directly.
var shift_pressed := false
var shift_held := false
var shift_released := false
var harpoon_pressed := false
var harpoon_held := false
var harpoon_released := false
# Drops whatever gauge is charging, spending nothing. The player turns an RMB press made
# during a charge into this (the League convention: right click cancels a cast).
var cancel_pressed := false
# The card bay a key picked this tick (0, 1 or 2), or -1. Only a card weapon reads it.
var bay_pick := -1


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
	bay_pick = -1


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
	# Unused: no key layout reads it; the game still sets it.
	var tuning

	func poll(out) -> void:
		out.clear()
		if not enabled:
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
		out.special_pressed = Input.is_action_just_pressed("cl_special")
		out.special_held = Input.is_action_pressed("cl_special")
		out.special_released = Input.is_action_just_released("cl_special")
		out.harpoon_pressed = Input.is_action_just_pressed("cl_harpoon")
		out.harpoon_held = Input.is_action_pressed("cl_harpoon")
		out.harpoon_released = Input.is_action_just_released("cl_harpoon")
		var bays := ["cl_bay_1", "cl_bay_2", "cl_bay_3"]
		for i in bays.size():
			if Input.is_action_just_pressed(bays[i]):
				out.bay_pick = i
