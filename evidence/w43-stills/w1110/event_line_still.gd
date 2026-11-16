extends SceneTree

# Stills for W1-110 (an event warning line read as the cause of an unrelated hit): the park dam with the
# HUD, "Dome Lightning incoming" announced 9 s out, off to the ball's right. 1 just after the
# announcement, 2 five seconds on, 3 just after the event starts. Run on the base and on the fix.
#   gpu-run.sh <worktree> eventline --path sketches/core-loop --script res://tools/event_line_still.gd -- --out=/abs/dir

const Game := preload("res://src/game.gd")

var game
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _shot(id: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(out.path_join("%s.png" % id)) != OK:
		push_error("event_line_still: could not save %s" % id)
		quit(4)


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(60)
	game.world.activities.set_physics_process(false)
	var cage = game.world.rescue.cage("rivet")
	if cage != null:
		cage.fire()
		await _frames(int(ceil(1.5 * Engine.physics_ticks_per_second)) + 60)
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	game.hud._engaged = false
	# Let any stage-entry toast run out so the frame holds only the announcement.
	await _frames(int(4.0 * Engine.physics_ticks_per_second))
	var ball: Vector3 = game.player.shown_position()
	var right: Vector3 = game.get_viewport().get_camera_3d().global_transform.basis.x
	game.events.event_announced.emit("dome_lightning", 9.0, ball + right * 70.0)
	await _frames(int(0.6 * Engine.physics_ticks_per_second))
	await _shot("1_announced")
	await _frames(int(4.4 * Engine.physics_ticks_per_second))
	await _shot("2_five_s")
	game.events.event_started.emit("dome_lightning")
	await _frames(int(0.6 * Engine.physics_ticks_per_second))
	await _shot("3_started")
	quit(0)
