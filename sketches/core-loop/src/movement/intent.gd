extends RefCounted

# One tick of what the player asked for. Input fills it; nothing else reads a key.
# Combat reads fire, special and line from here, so a scripted source drives weapons too.
# The grammar is the same for every class (design-v3/LEGIBILITY.md section 3 and
# SKILL-BAR.md section 6): keys 1, 2, 3 pick the bar slot, LMB casts the picked slot, RMB the
# harpoon, Ctrl the haul, Space jump, Shift the pilot's go verb, Q the ultimate.
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
# The router's outputs (player_ball._route_slots): left click on a picked slot 2 or 3 is ORed
# in here. No key fills them; a module test may set them directly, a bot never does.
var special_pressed := false
var special_held := false
var special_released := false
var line_pressed := false
var line_held := false
var line_released := false
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
# The bar slot a key picked this tick (0, 1 or 2 for slots 1, 2, 3), or -1.
var slot_pick := -1
# Q this tick.
var ultimate_pressed := false
# F this tick: fire the racked active.
var active_pressed := false
# The off line (twin_lines.gd), a prototype behind --twin-lines=on: middle mouse or the right
# stick click. The keyboard fills it only while that flag has bound the action.
var twin_pressed := false
var twin_held := false
var twin_released := false


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
	twin_pressed = false
	twin_held = false
	twin_released = false


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
	# The camp walk (camp_hub.gd): the ball only rolls, jumps, boosts and brakes; no weapon, hook or ability fires.
	var walk := false
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
		out.harpoon_pressed = Input.is_action_just_pressed("cl_harpoon")
		out.harpoon_held = Input.is_action_pressed("cl_harpoon")
		out.harpoon_released = Input.is_action_just_released("cl_harpoon")
		out.ultimate_pressed = Input.is_action_just_pressed("cl_ultimate")
		out.active_pressed = Input.is_action_just_pressed("cl_active")
		if InputMap.has_action("cl_twin"):
			out.twin_pressed = Input.is_action_just_pressed("cl_twin")
			out.twin_held = Input.is_action_pressed("cl_twin")
			out.twin_released = Input.is_action_just_released("cl_twin")
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
			out.twin_pressed = false
			out.twin_held = false
			out.twin_released = false
			out.ultimate_pressed = false
			out.slot_pick = -1
