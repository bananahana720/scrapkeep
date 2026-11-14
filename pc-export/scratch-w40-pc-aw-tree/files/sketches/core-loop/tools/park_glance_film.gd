extends SceneTree
# SCRATCH ONLY (PC lane job AW, 14 Nov 2026), not for any game branch.
# Parks the ball in the running game with the play camera in its chase spot, hides the HUD, and
# lets it sit PARK seconds so the pilot's glance fires (3 s still, 1.2 s hold, every 7 s). Run
# with --fixed-fps 30 --write-movie; prints PARK_START at the first parked frame and the glance's
# turn each frame so the hold can be found in the movie.
#   <godot> --fixed-fps 30 --write-movie x.avi --path sketches/core-loop --ball-look=cutaway \
#     --script res://tools/park_glance_film.gd -- --pilot=<class id>
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const PARK := 12.0
var pilot := "runner_gunner"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pilot="):
			pilot = arg.trim_prefix("--pilot=")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _run() -> void:
	seed(280928)
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	var index := -1
	for i in game.flow.classes.size():
		if String(game.flow.classes[i].id) == pilot:
			index = i
	print("PARK pilot ", pilot, " index ", index)
	game.flow.choose_class(index)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 900:
		await process_frame
		if game.ctx.terrain.is_ready(1) and game.flow.in_play() and i > 240:
			break
	game.presentation.hide_ui()
	var glance: Node = game.player.find_child("PilotGlance", true, false)
	print("PARK_START frame ", Engine.get_process_frames(), " glance ", glance != null, " look ", game.tuning.option("ball_look"))
	var n := int(PARK * 30.0)
	for f in n:
		await process_frame
		for c in root.find_children("*", "CanvasLayer", true, false):
			c.visible = false
		var v: Vector3 = game.player.linear_velocity if "linear_velocity" in game.player else Vector3.ZERO
		print("PARK f ", f, " turn ", snappedf(glance.turn if glance else 0.0, 0.001), " speed ", snappedf(v.length(), 0.01))
	quit(0)
