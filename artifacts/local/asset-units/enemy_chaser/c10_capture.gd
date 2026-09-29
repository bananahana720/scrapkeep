extends SceneTree
# C10 capture: one chaser, three poses, four asset cameras, lit then flat-black. Run with the same
# script at base and at head; frames.json records every eye and target.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
var game
var out := ""
var camera: Camera3D
var records := []
var chaser
var terrain

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
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
	terrain = game.ctx.terrain
	var spot := _flattest()
	print("C10 spot ", spot)
	game.player.reset_to(terrain.drop_point(spot.x, spot.y - 100.0, 1.2))
	chaser = game.ctx.spawner.spawn_enemy("chaser", terrain.drop_point(spot.x, spot.y, 1.2))
	for i in 90:
		await physics_frame
	paused = true
	game.player.body().freeze = true
	game.player._visual_root.visible = false
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.far = 1800.0
	var poses := {"idle": [0, 0.0], "windup": [1, 0.6], "lunge": [2, 0.2]}
	for lit in [true, false]:
		if not lit:
			_go_black()
		for pose in poses:
			chaser.state = poses[pose][0]
			chaser._clock = poses[pose][1]
			for i in 90:
				chaser._pose()
			await _views(pose, "lit" if lit else "black")
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 280928, "size": [1920, 1080], "adapter": RenderingServer.get_video_adapter_name(), "chaser_at": [chaser.global_position.x, chaser.global_position.y, chaser.global_position.z], "frames": records, "states": "state set directly (0 chase, 1 windup at clock 0.6 = full brace, 2 lunge at clock 0.2); no telegraph lane drawn"}, "\t"))
	quit()

# The spot whose ground stays within a metre of the anchor along the four 30 m camera rays.
func _flattest() -> Vector2:
	var best := Vector2(-65, -130)
	var best_score := 1e9
	for x in range(-140, 141, 10):
		for z in range(-200, -59, 10):
			var g0: float = terrain.drop_point(x, z, 0.0).y
			var score := 0.0
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0.7, -0.7)]:
				for r in [6.0, 12.0, 18.0, 24.0, 30.0]:
					var p: Vector2 = Vector2(x, z) + d * r
					score = maxf(score, absf(terrain.drop_point(p.x, p.y, 0.0).y - g0))
			if score < best_score:
				best_score = score
				best = Vector2(x, z)
	print("C10 flattest score ", best_score)
	return best

func _go_black() -> void:
	for env in root.find_children("*", "WorldEnvironment", true, false):
		var e: Environment = env.environment.duplicate()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.5, 0.5, 0.5)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.5, 0.5, 0.5)
		e.fog_enabled = false
		e.volumetric_fog_enabled = false
		e.glow_enabled = false
		e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.environment = e
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for node in root.find_children("*", "VisualInstance3D", true, false):
		if node == camera:
			continue
		if chaser.is_ancestor_of(node):
			if node is MeshInstance3D:
				(node as MeshInstance3D).material_override = black
				(node as MeshInstance3D).layers = 1
		elif not node.is_ancestor_of(chaser) and not (node is Light3D and false):
			node.visible = false

func _views(pose: String, mode: String) -> void:
	var at: Vector3 = chaser.global_position
	var f := Vector3(0, 0, -1)
	var right := Vector3(1, 0, 0)
	var views := {
		"front30": [f * 30.0, 3.0],
		"side30": [right * 30.0, 3.0],
		"rear30": [-f * 30.0, 3.0],
		"use6": [(f + right).normalized() * 6.0, 3.0],
	}
	for view in views:
		var d: Vector3 = views[view][0]
		var eye := Vector3(at.x + d.x, at.y - 1.5 + 3.0, at.z + d.z)
		await _shot("%s-%s-%s" % [view, pose, mode], eye, at, 65.0)

func _shot(id: String, eye: Vector3, target: Vector3, fov: float) -> void:
	camera.global_position = eye
	camera.look_at(target)
	camera.fov = fov
	for i in 8:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(out.path_join(id + ".png")) != OK:
		quit(3)
	records.append({"id": id, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z], "fov": fov})
