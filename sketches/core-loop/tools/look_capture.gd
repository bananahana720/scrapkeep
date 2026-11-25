extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Cams := preload("res://tools/capture_cameras.gd")
var game
var out := ""
var camera: Camera3D
var records := []

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
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 120:
		await physics_frame
	paused = true
	game.player.body().freeze = true
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.far = 1800.0
	var terrain = game.ctx.terrain
	var overview: Dictionary = Cams.LOOK["overview"]
	await _shot("overview", overview["eye"], overview["target"], overview["fov"])
	var warden = game.flow.warden
	warden._look._badge.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	var target: Vector3 = warden.global_position
	var ball: Vector3 = terrain.drop_point(-53.85, -39.07, 3.0)
	_pose(ball)
	await _shot("launch", ball + Vector3(-2.2, 1.5, -4.2), ball + Vector3(0, 1.0, 7), Cams.LOOK["launch"]["fov"])
	_pose(target + Vector3(-9, 2, -12))
	for i in 5:
		var p: Vector3 = target + Vector3(cos(i * 1.3) * 17, 0, sin(i * 1.3) * 17)
		game.ctx.spawner.spawn_enemy("chaser", terrain.drop_point(p.x, p.z, 1.2))
	await _shot("warden", target + Vector3(-12, 7, -17), target + Vector3(0, 3, 0), Cams.LOOK["warden"]["fov"])
	var bay = game.world.bay
	bay.visible = true
	bay._barge.visible = true
	bay._barge.position = Vector3(50, 65, -90)
	var bay_at: Vector3 = bay._barge.global_position
	_pose(bay_at + Vector3(0, 2, 0))
	await _shot("moss", bay_at + Vector3(-2, 6, 12), bay_at + Vector3(-14, 2.8, 0), Cams.LOOK["moss"]["fov"])
	bay.visible = false
	ball = terrain.drop_point(-65, -130, 1.2)
	_pose(ball)
	var fitted: Dictionary = game.presentation.hero_assets.shell_of(game.player)
	var pod: Node3D = fitted["pod"]
	await _shot("pilot", ball + pod.global_basis * Vector3(2.9, 1.5, -3.8), ball + Vector3(0, 0.2, 0), Cams.LOOK["pilot"]["fov"])
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed": 280928, "size": [1920, 1080], "adapter": RenderingServer.get_video_adapter_name(), "frames": records, "source_sha256": _hashes(), "limits": "Staged fixed cameras, paused real scene, real drop lip and Warden; launch is an airborne pose, not a timed traversal. Bay uses authored barge placed for inspection; no gameplay changes."}, "\t"))
	quit()

func _shot(id: String, eye: Vector3, target: Vector3, fov: float) -> void:
	Cams.aim(camera, eye, target, fov)
	for i in 12:
		await RenderingServer.frame_post_draw
	for node in root.find_children("*", "CanvasItem", true, false):
		node.visible = false
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(out.path_join(id + ".png")) != OK:
		quit(3)
	records.append({"id": id, "eye": [eye.x, eye.y, eye.z], "target": [target.x, target.y, target.z], "fov": fov, "sha256": FileAccess.get_sha256(out.path_join(id + ".png"))})

func _pose(at: Vector3) -> void:
	game.player.reset_to(at)
	game.player._visual_root.global_position = at

func _hashes() -> Dictionary:
	var result := {}
	for path in ["src/world/terrain.gd", "src/core/palette.gd", "src/presentation/hero_assets.gd", "src/presentation/spillway_scenery.gd", "src/presentation/graphics_preset.gd", "tools/look_capture.gd"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
