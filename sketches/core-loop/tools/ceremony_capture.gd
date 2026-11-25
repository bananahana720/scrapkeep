extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")


var _out := ""
var _game
var _ceremony
var _clock := 0.0
var _step := 0
var _pending: Array = []
var _shots: Array = []
var _class := 0


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("ceremony_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	_out = settings["out"]
	_class = int(settings.get("class", "0"))
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
			if shot.has("name"):
				_save(shot["name"])
			if shot.has("then"):
				(shot["then"] as Callable).call()
	match _step:
		0:
			if _clock > 1.0:
				_game.ctx.calm = true
				_game.player.source = Intent.Scripted.new()
				_game.flow.press_start()
				_game.flow.choose_class(_class)
				_ceremony = _game.presentation.ceremony
				_ceremony.started.connect(func(_part: String):
					_after(0.9, "ceremony-build-mid")
					_after(1.45, "ceremony-build-late"))
				_ceremony.revealed.connect(func(_part: String):
					_after(0.1, "ceremony-burst")
					_after(0.55, "ceremony-reveal")
					_after(1.3, "ceremony-hull-seated"))
				_ceremony.closed.connect(func(_part: String): _after(0.4, "", _payoff))
				_step = 1
				_clock = 0.0
		1:
			if _clock > 3.0:
				_ceremony._mark_seen("sunforged_core")
				_game.run.add_part("sunforged_core", "capture")
				_after(0.14, "rare-flare")
				_after(1.2, "", func():
					_game.run.add_part("tempest_core", "milestone")
					_after(0.7, "reveal-card"))
				_after(4.6, "", func():
					_game.run.add_part("chain_arc", "capture")
					_ceremony.view.card = {}
					_after(3.4, "", func():
						_game.run.add_part("cross_split", "capture")
						_after(0.75, "reveal-synergy")))
				_after(12.0, "", func():
					_ceremony.pause_armed = true
					_game.run.add_part("ram_plow", "vault"))
				_step = 2
		2:
			if _clock > 40.0:
				_finish("time")
	return false


func _after(seconds: float, name: String, then := Callable()) -> void:
	var shot := {"at": _clock + seconds}
	if name != "":
		shot["name"] = name
	if then.is_valid():
		shot["then"] = then
	_pending.append(shot)


func _payoff() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var cam: Camera3D = _game.camera.cam
	var ahead := -cam.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized() * 7.0
	var target: Node3D = _game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ball.x + ahead.x, ball.z + ahead.z, 1.0))
	_game.ctx.spawner.strike(target, "shell", 1.0)
	_after(0.18, "payoff")
	_after(1.5, "", func(): _finish("done"))


func _save(name: String) -> void:
	var image := root.get_texture().get_image()
	var file := "%02d-%s.png" % [_shots.size(), name]
	image.save_png(_out.path_join(file))
	_shots.append({"file": file, "clock": snappedf(_clock, 0.01), "paused": paused, "phase": _ceremony.phase() if _ceremony != null else ""})


func _finish(reason: String) -> void:
	var info := {"reason": reason, "class": _game.run.class_id() if _game.run != null else "",
		"adapter": RenderingServer.get_video_adapter_name(), "presented": _ceremony.presented if _ceremony != null else [],
		"payoffs": _ceremony.payoffs if _ceremony != null else [], "shots": _shots}
	var file := FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(info, "  "))
		file.close()
	print("ceremony_capture: %d stills in %s (%s)" % [_shots.size(), _out, reason])
	paused = false
	quit(0)
