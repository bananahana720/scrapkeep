extends SceneTree

const Game := preload("res://src/game.gd")
const Device := preload("res://src/world/device.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const T := preload("res://tests/support/t.gd")

# A device's key prompt draws the cap Interact is bound to on the device in use: E on the
# keyboard by default, Y on the pad, and the new key once Interact is rebound. The prompt
# is rebuilt every frame the device is live, so a change shows on the next frame.

var _t := T.new("interact_prompt_binding_test")
var _game
var _wait := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	if _wait < 4:
		return false
	_prompts()
	quit(_t.verdict())
	return true


func _prompts() -> void:
	var device := Device.new()
	_game.add_child(device)
	device.setup(null, null, {"id": "probe"})
	Glyphs.device = "kbm"
	device.show_prompt(true)
	_t.eq("keyboard with the default binding asks for E", device.prompt.keycap, "key_e")
	Glyphs.device = "pad"
	device.show_prompt(true)
	_t.eq("a controller asks for the pad glyph", device.prompt.keycap, "pad_y")
	Glyphs.device = "kbm"
	var old: Array = InputMap.action_get_events("cl_interact")
	for event in old:
		if event is InputEventKey:
			InputMap.action_erase_event("cl_interact", event)
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	InputMap.action_add_event("cl_interact", g)
	device.show_prompt(true)
	_t.eq("a rebinding to G asks for G", device.prompt.keycap, "key_g")
	InputMap.action_erase_event("cl_interact", g)
	for event in old:
		if event is InputEventKey:
			InputMap.action_add_event("cl_interact", event)
	device.show_prompt(true)
	_t.eq("restored, E again", device.prompt.keycap, "key_e")
	device.show_prompt(false)
	_t.eq("an untargeted device draws no cap", device.prompt.keycap, "")
	# The sign's text is built in a function that needs a whole site; trade_pockets_test builds
	# one and reads the sign, so this reads the format string the sign is made from.
	var source := FileAccess.get_file_as_string("res://src/world/activities.gd")
	_t.check("the trade door sign names no fixed key", source.contains("TradePrices") and not source.contains("E at a device"),
		"the sign line still says E")
