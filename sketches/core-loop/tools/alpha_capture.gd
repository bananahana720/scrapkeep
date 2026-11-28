extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const EVERY := 9.0

var _out := ""
var _game
var _driver
var _step := 0
var _clock := 0.0
var _play_clock := 0.0
var _next_periodic := 4.0
var _limit := 150.0
var _pending: Array = []
var _shots: Array = []
var _paused_once := false
var _seed := 0
var _ui := false
var _notes_shot := false
var _policy := "skipper"


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if AppShell.headless() or not settings.has("out"):
		printerr("alpha_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	_seed = int(settings.get("seed", "0"))
	_limit = float(settings.get("seconds", "150"))
	_ui = settings.get("ui", "0") == "1"
	_policy = settings.get("policy", "skipper")
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(delta: float) -> bool:
	_clock += delta
	if _game == null or _game.flow == null:
		return false
	for shot in _pending.duplicate():
		if _clock >= shot["at"]:
			_pending.erase(shot)
			_save(shot["name"])
			if shot.has("then"):
				(shot["then"] as Callable).call()
	match _step:
		0:
			if _clock > 1.5:
				_save("title")
				_game.screens.toggle_help()
				_step = 1
				_clock = 0.0
		1:
			if _clock > 0.8:
				_save("help")
				_game.screens.toggle_help()
				_step = 2
				_clock = 0.0
				if _ui:
					_game.flow.press_start()
					var cards: Array = _game.screens.class_cards()
					_pending.append({"at": 1.0, "name": "class-select", "then": func(): cards[_seed % cards.size()].grab_focus()})
					_pending.append({"at": 2.6, "name": "class-open"})
					_step = 4
		4:
			if _clock > 2.9:
				_step = 2
				_clock = 0.0
		2:
			if _clock > 0.5:
				_start_run()
				_step = 3
		3:
			_play_clock += delta
			if _play_clock >= _next_periodic:
				_next_periodic += EVERY
				_save("play")
			if _ui and not _notes_shot and _play_clock > 8.0 and _pending.is_empty() and _game.flow.in_play():
				_notes_shot = true
				_game.hold_notes(true)
				_game.notes.show_page(0)
				_pending.append({"at": _clock + 0.5, "name": "notes-keys", "then": func(): _game.notes.show_page(1)})
				_pending.append({"at": _clock + 1.2, "name": "notes-hurts", "then": func(): _game.notes.show_page(2)})
				_pending.append({"at": _clock + 1.9, "name": "notes-grow", "then": func(): _game.hold_notes(false)})
			if not _paused_once and _play_clock > 24.0 and _pending.is_empty() and _game.flow.in_play() and not _game.get_meta("menu_held", false):
				_paused_once = true
				_press(KEY_P)
				_pending.append({"at": _clock + 0.6, "name": "pause", "then": func(): _press(KEY_P)})
			if _play_clock > _limit:
				_finish("time")
	return false


func _physics_process(delta: float) -> bool:
	if _driver != null and _step == 3:
		if _driver.tick(delta):
			_finish("run_over")
	return false


func _start_run() -> void:
	_driver = BotDriver.new(_game, _policy, _seed)
	_driver.tree_policy = ""
	_game.workshop().armed = true
	var events = _game.events
	events.tree_offered.connect(func(_c: String, depth: int, _choices: Array):
		_pending.append({"at": _clock + 0.7, "name": "pick-depth%d" % depth, "then": func(): _press(KEY_1)}))
	events.stage_entered.connect(func(stage: int, _retry: bool):
		_pending.append({"at": _clock + 3.0, "name": "stage%d-entry" % stage}))
	events.pack_arrived.connect(func(faction: String, _at: Vector3, _kinds: Array):
		_pending.append({"at": _clock + 1.2, "name": "pack-%s" % faction}))
	events.bay_entered.connect(func(_banked: float):
		_pending.append({"at": _clock + 2.0, "name": "bay"}))
	events.warden_engaged.connect(func(stage: int):
		_pending.append({"at": _clock + 2.5, "name": "warden%d" % stage}))
	_driver.start()


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var file := "%02d-%s.png" % [_shots.size(), name]
	image.save_png(_out.path_join(file))
	_shots.append({"file": file, "clock": snappedf(_play_clock, 0.1), "size": [image.get_width(), image.get_height()]})


func _finish(reason: String) -> void:
	var info := {"reason": reason, "seed": _seed, "class": _game.run.class_id() if _game.run != null else "",
		"adapter": RenderingServer.get_video_adapter_name(), "shots": _shots}
	var file := FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	print("alpha_capture: %d stills in %s (%s)" % [_shots.size(), _out, reason])
	quit(0)
