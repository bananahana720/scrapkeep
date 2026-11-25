extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")


const FPS := 30.0
const PLAN := [
	[0.35, "arrival_0_35s", ""],
	[1.0, "arrival_1_0s", ""],
	[2.0, "arrival_2_0s", ""],
	[3.4, "", "phase2"],
	[3.9, "phase2_0_5s", ""],
	[5.6, "", "defeat"],
	[6.2, "rout_0_6s", ""],
	[6.9, "rout_1_3s", ""],
	[7.7, "rout_2_1s", ""],
	[8.6, "signon_0_6s_over_card", ""],
	[9.4, "signon_1_4s_over_card", ""],
]

var _out := ""
var _human := false
var _game
var _frames := 0
var _arena_frame := -1
var _step := 0
var _started := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--human="):
			_human = arg.trim_prefix("--human=") == "1"
	if DisplayServer.get_name() == "headless" or _out == "":
		printerr("brindle_beats_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frames += 1
	if not _started and _frames > 5:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.bot_driven = not _human
		_game.flow.press_start()
		_game.flow.choose_class(0)
		var last: int = _game.ctx.stages.STAGES.size() if "STAGES" in _game.ctx.stages else 2
		_game.flow.enter_stage(2, Vector3(0.0, 0.0, 16.0), false)
		_game.flow._finish_stage()
		_arena_frame = _frames
		print("brindle_beats_capture: arena %s, playing %s" % [_game.flow.state_name(), _game.presentation.flourish.id])
		return false
	if _arena_frame < 0:
		return false
	var t := (_frames - _arena_frame) / FPS
	while _step < PLAN.size() and t >= float(PLAN[_step][0]):
		var entry: Array = PLAN[_step]
		match String(entry[2]):
			"phase2":
				_game.boss.jump_to_phase(2)
			"defeat":
				_game.boss._defeat("ram", _game.player.ball_position())
		if String(entry[1]) != "":
			var image := root.get_texture().get_image()
			image.save_png(_out.path_join(String(entry[1]) + ".png"))
			print("brindle_beats_capture: %s (playing %s, flow %s)" % [entry[1], _game.presentation.flourish.id, _game.flow.state_name()])
		_step += 1
	if _step >= PLAN.size():
		_game.free()
		quit(0)
		return true
	return false
