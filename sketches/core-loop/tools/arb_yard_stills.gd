extends SceneTree


const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")
const AppShell := preload("res://src/core/app_shell.gd")

const VIEWS := [
	["floor_to_stand_a", [120.0, 20.0, 5.0], [300.0, 72.0, 20.0]],
	["floor_to_ledger", [0.0, 24.0, 6.0], [180.0, 76.0, 23.0]],
	["floor_to_stand_b", [270.0, 22.0, 5.0], [95.0, 72.0, 19.0]],
	["bank_to_furnace", [320.0, 52.0, 9.0], [140.0, 84.0, 26.0]],
	["mast_high", [45.0, 27.0, 22.0], [225.0, 60.0, 8.0]],
	["bank_to_stand_a", [262.0, 57.0, 16.0], [300.0, 73.0, 22.0]],
	["ladle_close", [345.0, 55.0, 19.0], [15.0, 75.0, 21.0]],
]
const PLAY_BEARINGS := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
const PLAY_BALL_R := 26.0
const PLAY_ARM := 12.0

var game
var out := ""
var hold := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--hold":
			hold = true
	if out.is_empty() or AppShell.headless():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	Harness.enter(game, Vector3(18, 0, 0))
	if hold:
		game.boss.set_process(false)
		game.boss.set_physics_process(false)
	for i in 30:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 900.0
	root.add_child(camera)
	camera.make_current()
	for phase in [1, 2, 3]:
		if phase >= 2:
			game.boss.jump_to_phase(phase)
		var yard = game.boss.arena.get_node("ArenaBowlDress/FleetYard")
		for i in (40 if phase >= 2 else 150):
			await process_frame
		for view in VIEWS:
			if phase != 1 and not view[0] in ["floor_to_stand_a", "bank_to_furnace", "ladle_close"]:
				continue
			camera.global_position = _at(view[1])
			camera.look_at(_at(view[2]))
			await process_frame
			await process_frame
			var image := root.get_texture().get_image()
			var label := "p%d" % phase
			image.save_png(out.path_join("%s_%s.png" % [label, view[0]]))
			print("STILL %s %s cheering=%s" % [label, view[0], yard.cheering()])
		if phase == 1:
			camera.fov = 65.0
			for bearing in PLAY_BEARINGS:
				camera.global_position = _at([bearing, PLAY_BALL_R + PLAY_ARM, 4.5])
				camera.look_at(_at([bearing, 0.0, 3.0]))
				await process_frame
				await process_frame
				root.get_texture().get_image().save_png(out.path_join("p1_play_%03d.png" % int(bearing)))
				print("STILL p1 play_%03d" % int(bearing))
			camera.fov = 62.0
	quit(0)


func _at(spot: Array) -> Vector3:
	var arena = game.boss.arena
	return arena.global_position + arena.dir(deg_to_rad(spot[0])) * spot[1] + Vector3.UP * spot[2]
