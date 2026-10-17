extends SceneTree
# One day per run: a still of every stage in run order, then the Mind's crown, each at the time of
# day its stage enters at (world_look.gd STAGE_TIME). The camera sits behind and above the ball and
# looks a quarter turn off the day's sun, so the graded sky, its glow and the lit ground share a
# frame. Needs a display (Xvfb works; llvmpipe GL draws without volumetric air):
#   godot --path sketches/core-loop --resolution 1280x720 --script res://tools/day_arc_capture.gd -- --out=<dir>
# Writes <out>/<n>-stage<stage>-<time>.png and frames.json. Evidence limit: colour and composition
# only; frame times come from the 4080.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SIZE := Vector2i(1280, 720)
var out := ""
var game
var cam: Camera3D
var recs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(171022)
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	cam = Camera3D.new()
	cam.far = 1800.0
	game.add_child(cam)
	DirAccess.make_dir_recursive_absolute(out)
	for stage in range(1, game.ctx.stages.COUNT + 1):
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(40)
		game.player.body().freeze = true
		await _snap("%d-stage%d-%s" % [stage, stage, WorldLook.time_id(stage)], stage, game.player.ball_position())
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	game.player.body().freeze = true
	var pad: Vector3 = game.flow._boss_module().pad.global_position + Vector3.UP
	await _snap("7-mind-crown-dusk", 0, pad, WorldLook.ARENAS.mind.sun_rotation)
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "day_arc_capture.gd", "adapter": RenderingServer.get_video_adapter_name(), "frames": recs}, "\t"))
	f.close()
	quit(0)


func _snap(id: String, stage: int, at: Vector3, sun_rotation = null) -> void:
	var r: Vector3 = sun_rotation if sun_rotation != null else WorldLook.time_row(stage).get("sun_rotation", Vector3(-45, 0, 0))
	var toward_sun := Basis.from_euler(Vector3(0.0, deg_to_rad(r.y), 0.0)).z
	var look := toward_sun.rotated(Vector3.UP, deg_to_rad(40.0))
	cam.global_position = at - look * 34.0 + Vector3.UP * 14.0
	cam.look_at(at + look * 60.0 + Vector3.UP * 10.0, Vector3.UP)
	cam.fov = 68.0
	cam.current = true
	paused = true
	for n in root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for i in 12:
		await RenderingServer.frame_post_draw
	var png := out.path_join(id + ".png")
	root.get_texture().get_image().save_png(png)
	var env: Environment = game.ctx.terrain.environment
	recs.append({"id": id, "stage": stage, "ambient": env.ambient_light_color.to_html(false),
		"ambient_energy": env.ambient_light_energy, "fog": env.fog_light_color.to_html(false)})
	paused = false
	print("snap ", id)
