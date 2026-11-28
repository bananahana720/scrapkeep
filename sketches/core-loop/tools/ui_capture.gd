extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AppShell := preload("res://src/core/app_shell.gd")


var _out := ""
var _game
var _steps: Array = []
var _wait := 0
var _size := Vector2i(1600, 900)


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if AppShell.headless() or not settings.has("out"):
		printerr("ui_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	var parts: PackedStringArray = String(settings.get("size", "1600x900")).split("x")
	_size = Vector2i(int(parts[0]), int(parts[1]))
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(_size)
	root.size = _size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	var s = func(): return _game.get_node("Screens")
	var menu = func(): return _game.get_node("PauseMenu")
	_steps = [
		[30, func(): s.call().prologue_enabled = false; s.call()._on_flow_changed("title")],
		[20, func(): _save("title")],
		[1, func(): s.call().toggle_settings()],
		[6, func(): _save("settings-display")],
		[1, func(): s.call().settings_page().focus("frame_smoothing")],
		[6, func(): _save("settings-display-focus")],
		[1, func(): s.call().settings_page().show_page(1)],
		[4, func(): _save("settings-controls")],
		[1, func(): s.call().settings_page().press("jump")],
		[6, func(): _save("settings-controls-waiting")],
		[1, func(): s.call().settings_page().handle(_key(KEY_SHIFT))],
		[6, func(): _save("settings-controls-refused")],
		[1, func(): s.call().settings_page().focus("interact")],
		[6, func(): _save("settings-controls-scrolled")],
		[1, func(): s.call().settings_page().show_page(2)],
		[4, func(): _save("settings-look")],
		[1, func(): s.call().settings_page().show_page(3)],
		[4, func(): _save("settings-feel")],
		[1, func(): s.call().settings_page().show_page(0); s.call().toggle_settings()],
		[2, func(): _game.flow.press_start()],
		[30, func(): _save("pilot-select")],
		[1, func(): _game.ctx.calm = true; _game.player.source = Intent.Scripted.new(); _game.flow.choose_class(0)],
		[150, func(): _save("play")],
		[1, func(): menu.call().open()],
		[6, func(): _save("pause")],
		[1, func(): menu.call().press("settings")],
		[6, func(): _save("pause-settings")],
		[1, func(): menu.call().close()],
		[4, func(): s.call().toggle_help()],
		[20, func(): _save("help")],
		[1, func(): quit(0)],
	]


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _steps.is_empty():
		return false
	_wait += 1
	if _wait >= int(_steps[0][0]):
		_wait = 0
		var step: Callable = _steps.pop_front()[1]
		step.call()
	return false


func _key(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.keycode = code
	key.pressed = true
	return key


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(_out.path_join("%dx%d-%s.png" % [_size.x, _size.y, name]))
	var lines := _audit()
	var file := FileAccess.open(_out.path_join("%dx%d-%s.audit.txt" % [_size.x, _size.y, name]), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	print("ui_capture: %s %s, %d audit rows" % [name, image.get_size(), lines.size()])


func _audit() -> Array:
	var out := []
	var screen := root.get_final_transform()
	var width := float(root.size.x)
	for node in _shown(root, []):
		var control := node as Control
		var rect := screen * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
		var target := control is BaseButton or (control.focus_mode == Control.FOCUS_ALL and control.mouse_filter == Control.MOUSE_FILTER_STOP)
		if target and (rect.size.x < 44.0 or rect.size.y < 44.0):
			out.append("small %s %s %.0fx%.0f" % [control.get_class(), _name(control), rect.size.x, rect.size.y])
		if target and control.focus_mode != Control.FOCUS_NONE and String(control.accessibility_name) == "" \
				and String(control.get("text") if control.get("text") != null else "") == "":
			out.append("unnamed %s %s" % [control.get_class(), _name(control)])
		var words := control is Label and String(control.text) != ""
		if (target or words) and (rect.position.x < -0.5 or rect.end.x > width + 0.5):
			out.append("off-edge %s %s x %.0f to %.0f of %.0f" % [control.get_class(), _name(control), rect.position.x, rect.end.x, width])
	return out


func _shown(node: Node, found: Array) -> Array:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return found
	if node is Control and node.size.x > 0.0 and node.size.y > 0.0:
		found.append(node)
	for child in node.get_children():
		_shown(child, found)
	return found


func _name(control: Control) -> String:
	var words := String(control.get("text")) if control.get("text") != null else ""
	if words == "" and control.get("action") != null:
		words = String(control.get("action"))
	return "%s '%s'" % [control.name, words.left(24)]
