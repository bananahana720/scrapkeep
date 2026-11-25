extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const Panels := preload("res://src/build/panels.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")


const MIXED := ["vent_louvre", "hull_tile", "winch_drum", "splash_skirt", "ram_bumper"]

var _out := ""
var _game
var _started := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
	if _out == "":
		push_error("phase_read_capture: --out=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _started:
		return false
	_started = true
	_run()
	return false


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var size := image.get_size()
	var path := "%s/%dx%d-%s.png" % [_out, size.x, size.y, name]
	image.save_png(path)
	print("phase_read_capture: wrote %s" % path)


func _run() -> void:
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	_game.run.set_max_hp(99999.0)
	_game.flow.enter_stage(StageDefs.last_of(1), Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()
	await _frames(30)
	var plate = _game.hud.boss_plate
	await _shot("phase1")
	_game.boss.jump_to_phase(2)
	await _frames(6)
	await _shot("phase2-crack")
	await _frames(60)
	await _shot("phase2")
	_game.boss.jump_to_phase(3)
	await _frames(90)
	await _shot("phase3")
	print("phase_read_capture: plate pips %s" % [plate.phase_pips() if plate != null else []])
	for id in MIXED:
		for n in 3:
			_game.run.panels.append(id)
	var menu = _game.get_node("PauseMenu")
	menu.open()
	await _frames(40)
	await _shot("pause-build")
	quit(0)
