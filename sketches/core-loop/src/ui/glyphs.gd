extends RefCounted

const Bindings := preload("res://src/core/bindings.gd")


static var device := "kbm"

const PAD_BUTTONS := {
	JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y",
	JOY_BUTTON_LEFT_SHOULDER: "pad_lb", JOY_BUTTON_RIGHT_SHOULDER: "pad_rb", JOY_BUTTON_START: "pad_start",
	JOY_BUTTON_BACK: "pad_back", JOY_BUTTON_LEFT_STICK: "key_l3", JOY_BUTTON_RIGHT_STICK: "key_r3",
	JOY_BUTTON_DPAD_LEFT: "pad_dl", JOY_BUTTON_DPAD_UP: "pad_du", JOY_BUTTON_DPAD_RIGHT: "pad_dr",
	JOY_BUTTON_DPAD_DOWN: "pad_dd",
}
const PAD_TRIGGERS := {JOY_AXIS_TRIGGER_LEFT: "pad_lt", JOY_AXIS_TRIGGER_RIGHT: "pad_rt"}
const PAD_STICKS := {"roll": "pad_ls", "look": "pad_rs"}


static func is_pad() -> bool:
	return device == "pad"


static func of(verb: String) -> String:
	if not Bindings.VERBS.has(verb):
		return ""
	var table: String = Bindings.glyph(verb)
	if PAD_STICKS.has(verb):
		return PAD_STICKS[verb] if is_pad() else table
	var actions: Dictionary = Bindings.VERBS[verb]["actions"]
	return of_action(actions.keys()[0], table)


static func of_action(action: String, fallback: String) -> String:
	if not InputMap.has_action(action):
		return fallback
	var saw_device := false
	for event in InputMap.action_get_events(action):
		if is_pad():
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				saw_device = true
			var pid := _pad_id(event)
			if pid != "":
				return pid
		else:
			if event is InputEventKey or event is InputEventMouseButton:
				saw_device = true
			var did := _desk_id(event)
			if did != "":
				return did
	if saw_device:
		return "pad_btn" if is_pad() else "key_bind"
	return fallback


static func _pad_id(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return PAD_BUTTONS.get(event.button_index, "pad_b%d" % event.button_index if event.button_index >= 0 else "")
	if event is InputEventJoypadMotion:
		return PAD_TRIGGERS.get(event.axis, "")
	return ""


static func _desk_id(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code == KEY_NONE:
			return ""
		return "key_" + OS.get_keycode_string(code).to_lower().replace(" ", "_")
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			return "key_lmb"
		if event.button_index == MOUSE_BUTTON_RIGHT:
			return "key_rmb"
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			return "key_mmb"
		if event.button_index == MOUSE_BUTTON_XBUTTON1:
			return "key_mb4"
		if event.button_index == MOUSE_BUTTON_XBUTTON2:
			return "key_mb5"
		if event.button_index > 0:
			return "key_m%d" % event.button_index
	return ""
