extends RefCounted

const Bindings := preload("res://src/core/bindings.gd")


static var device := "kbm"

const PAD_BUTTONS := {
	JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y",
	JOY_BUTTON_LEFT_SHOULDER: "pad_lb", JOY_BUTTON_RIGHT_SHOULDER: "pad_rb", JOY_BUTTON_START: "pad_start",
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
	for event in InputMap.action_get_events(action):
		var id := _pad_id(event) if is_pad() else _desk_id(event)
		if id != "":
			return id
	return fallback


static func _pad_id(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return PAD_BUTTONS.get(event.button_index, "")
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
	return ""
