extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# Walk frames for the crew gait (enemy_gait.gd): the real game, one crew kind at a time beside a
# still ball, filmed every `--every` seconds from a camera that follows it at a fixed offset while it closes,
# circles and attacks. `--gait=off` drops the gait so the same seed films the old walk for a
# side-by-side. Display server needed:
#   xvfb-run -s "-screen 0 1280x800x24" <godot> --path sketches/core-loop --rendering-driver opengl3 \
#     --script res://tools/gait_strip.gd -- --out=/abs/dir [--kinds=hooker,swatter] [--gait=off] [--seconds=6] [--every=0.1]

const SIZE := Vector2i(640, 400)

var game
var out := ""
var kinds: Array = ["hooker", "swatter", "mag_trapper"]
var gait := true
var seconds := 6.0
var every := 0.1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
		elif arg == "--gait=off":
			gait = false
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--every="):
			every = float(arg.trim_prefix("--every="))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	seed(280928)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 60:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.fov = 50.0
	var terrain = game.ctx.terrain
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	game.player.reset_to(base)
	var frames := []
	for kind in kinds:
		for enemy in root.get_tree().get_nodes_in_group("enemy"):
			enemy.queue_free()
		await physics_frame
		var ball: Vector3 = game.player.ball_position()
		var enemy = game.ctx.spawner.spawn_enemy(kind, terrain.drop_point(ball.x + 16.0, ball.z + 6.0, 1.2))
		enemy.hp = 100000.0
		enemy._rest = 2.5
		await physics_frame
		if not gait:
			enemy._gait = null
		var clock := 0.0
		var shot := 0
		while clock < seconds:
			await physics_frame
			clock += 1.0 / Engine.physics_ticks_per_second
			if clock >= shot * every:
				for node in root.find_children("*", "CanvasLayer", true, false):
					node.visible = false
				# A fixed offset that follows the crew, so its turn and walk read against the ground.
				var at: Vector3 = enemy.global_position if is_instance_valid(enemy) else ball
				camera.look_at_from_position(at + Vector3(-3.0, 4.0, 7.0), at + Vector3.UP * 0.6)
				await RenderingServer.frame_post_draw
				var path := out.path_join("%s_%03d.png" % [kind, shot])
				root.get_texture().get_image().save_png(path)
				frames.append({"kind": kind, "shot": shot, "t": clock, "state": enemy.state_name() if is_instance_valid(enemy) else "gone"})
				shot += 1
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"gait": gait, "every": every, "frames": frames}, "\t"))
	quit()
