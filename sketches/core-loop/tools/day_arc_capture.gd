extends SceneTree
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SIZE := Vector2i(1280, 720)
var out := ""
var table := "park"
var game
var cam: Camera3D
var recs: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--table="):
			table = a.trim_prefix("--table=")
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
	game.table = table
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
	var n := 0
	var last_world: int = game.ctx.stages.world_of(game.ctx.stages.COUNT)
	for stage in range(1, game.ctx.stages.COUNT + 1):
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		await _frames(40)
		game.player.body().freeze = true
		n += 1
		await _snap("%d-stage%d-%s" % [n, stage, WorldLook.time_id(stage)], stage, game.player.ball_position())
		var world: int = game.ctx.stages.world_of(stage)
		if game.ctx.stages.is_world_last(stage) and world != last_world:
			var boss_id := String(game.flow.boss_row(world).get("kind", "boss"))
			game.flow.enter_boss(Vector3.ZERO)
			await _frames(90)
			game.player.body().freeze = true
			var rot = WorldLook.arena_look(boss_id).get("sun_rotation")
			n += 1
			var mod = game.flow._boss_module()
			var centre = mod.get("pad") if mod.get("pad") != null else mod.get("arena")
			var at: Vector3 = centre.global_position + Vector3.UP if centre != null else game.player.ball_position()
			await _snap("%d-arena-%s" % [n, boss_id], stage, at, rot, 14.0, 18.0)
			game.flow._boss_module().exit_arena()
			game.flow.in_arena = false
			game.flow.boss_active = false
			game.player.body().freeze = false
	game.flow.enter_boss(Vector3.ZERO)
	await _frames(90)
	game.player.body().freeze = true
	var pad: Vector3 = game.flow._boss_module().pad.global_position + Vector3.UP
	await _snap("%d-mind-crown-dusk" % (n + 1), 0, pad, WorldLook.ARENAS.mind.sun_rotation)
	cam.current = false
	game.player.body().freeze = false
	for k in 3:
		await _frames(150 + k * 60)
		await _shot("%d-mind-fight-hud-%d" % [n + 2 + k, k])
	var f := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "day_arc_capture.gd", "table": table, "adapter": RenderingServer.get_video_adapter_name(), "frames": recs}, "\t"))
	f.close()
	quit(0)


func _snap(id: String, stage: int, at: Vector3, sun_rotation = null, back := 34.0, up := 14.0) -> void:
	var r: Vector3 = sun_rotation if sun_rotation != null else WorldLook.time_row(stage).get("sun_rotation", Vector3(-45, 0, 0))
	var toward_sun := Basis.from_euler(Vector3(0.0, deg_to_rad(r.y), 0.0)).z
	var look := toward_sun.rotated(Vector3.UP, deg_to_rad(40.0))
	cam.global_position = at - look * back + Vector3.UP * up
	cam.look_at(at + look * 60.0 + Vector3.UP * 10.0, Vector3.UP)
	cam.fov = 68.0
	cam.current = true
	paused = true
	var shown: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.visible)
	for n in shown:
		n.visible = false
	for i in 12:
		await RenderingServer.frame_post_draw
	var png := out.path_join(id + ".png")
	root.get_texture().get_image().save_png(png)
	var env: Environment = game.ctx.terrain.environment
	recs.append({"id": id, "stage": stage, "ambient": env.ambient_light_color.to_html(false),
		"ambient_energy": env.ambient_light_energy, "fog": env.fog_light_color.to_html(false)})
	for n in shown:
		n.visible = true
	paused = false
	print("snap ", id)


func _shot(id: String) -> void:
	for i in 6:
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(id + ".png"))
	recs.append({"id": id, "stage": 0})
	print("snap ", id)
