extends RefCounted

# Real input for the workshop tests: mouse motion and clicks at a control's centre, and
# key presses, pushed into the viewport the way a player's would arrive.


static func hover(root: Window, control: Control) -> void:
	if control == null:
		return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	motion.global_position = motion.position
	root.push_input(motion, true)


static func click(root: Window, control: Control) -> void:
	if control == null:
		return
	hover(root, control)
	var at := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.position = at
		button.global_position = at
		root.push_input(button, true)


static func key(root: Window, code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)


# A pad button press and release, pushed into the viewport as a real pad would send it.
static func pad(root: Window, button: int) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)
