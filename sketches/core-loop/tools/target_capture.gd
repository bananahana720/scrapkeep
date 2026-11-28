extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Cams := preload("res://tools/capture_cameras.gd")
const AppShell := preload("res://src/core/app_shell.gd")
const SEED := 280928
const SAMPLE_FRAMES := 240
const WARMUP_FRAMES := 180
var game
var out := ""
var preset := "high"
var table := "default"
var ball_arg = null
var face_arg = null
var camera: Camera3D
var records := []
var timing := {}
var play_ball := Vector3.ZERO
var play_view := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		if arg.begins_with("--preset="):
			preset = arg.trim_prefix("--preset=")
		if arg.begins_with("--table="):
			table = arg.trim_prefix("--table=")
		if arg.begins_with("--ball="):
			ball_arg = _pair(arg.trim_prefix("--ball="))
		if arg.begins_with("--face="):
			face_arg = _pair(arg.trim_prefix("--face="))
	if out.is_empty() or AppShell.headless() or not Preset.PRESETS.has(preset):
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	root.size = Cams.SIZE
	root.content_scale_size = Cams.SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_run.call_deferred()

func _run() -> void:
	await _stage()
	Cams.aim(camera, play_view.eye, play_view.target, play_view.fov)
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	for i in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var gpu_samples: Array[float] = []
	var cpu_samples: Array[float] = []
	var setup_samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		setup_samples.append(RenderingServer.get_frame_setup_time_cpu())
	var wall := _summary(samples)
	timing = {"frames": SAMPLE_FRAMES, "warmup_frames": WARMUP_FRAMES,
		"median_ms": wall.median_ms, "p95_ms": wall.p95_ms,
		"gpu_render": _summary(gpu_samples), "cpu_render": _summary(cpu_samples),
		"cpu_frame_setup": _summary(setup_samples),
		"samples_ms": samples, "vsync": "disabled", "max_fps": 0,
		"method": "wall-clock intervals between frame_post_draw signals; live simulation, fixed play camera; engine viewport GPU/CPU timestamps in milliseconds; CPU setup separate; asynchronous GPU timestamps can lag wall samples"}
	game.free()
	await process_frame
	await _stage()
	paused = true
	game.player.body().freeze = true
	if not await _shot("play", play_view):
		return
	var at: Vector3 = game.flow.warden.global_position
	var site: Dictionary = Cams.TARGET.site
	if not await _shot("site", {"eye": at + site.eye_offset, "target": at + site.target_offset, "fov": site.fov}):
		return
	if not await _shot("wide", Cams.TARGET.wide):
		return
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify({"schema": "scrapkeep-target-capture/1", "seed": SEED,
		"staged_physics_frames": 120, "table": table, "preset": preset,
		"ball_xz": [play_ball.x, play_ball.z], "clutter_instances": _clutter_instances(),
		"preset_values": Preset.PRESETS[preset], "size": [1920, 1080],
		"adapter": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"engine": Engine.get_version_info(), "timing": timing, "frames": records,
		"source_sha256": _hashes(),
		"limits": "Fixed camera live-scene timing; reseeded frozen stills. Play ball and two enemies staged on sampled Spillway ground. Visibility, color hierarchy and GPU budget need review on hardware."}, "\t"))
	file.close()
	quit()

func _stage() -> void:
	paused = false
	seed(SEED)
	Preset.apply(preset)
	game = Game.new()
	game.table = table
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
	var play: Dictionary = Cams.TARGET.play
	if table == "slice":
		play = Cams.TARGET_REACH
	var xz: Vector2 = ball_arg if ball_arg != null else play.ball_xz
	play_ball = game.ctx.terrain.drop_point(xz.x, xz.y, play.clearance)
	game.player.reset_to(play_ball)
	game.player._visual_root.global_position = play_ball
	for spot in play.enemies_xz:
		game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(spot.x, spot.y, 1.2))
	game.flow.warden._look._badge.visible = false
	_hide_labels()
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.add_child(camera)
	camera.current = true
	camera.far = Cams.FAR
	var face = face_arg if face_arg != null else play.get("face_xz")
	if face == null:
		play_view = {"eye": play_ball + play.eye_offset, "target": play_ball + play.target_offset, "fov": play.fov}
	else:
		var heading: Vector2 = (face - xz).normalized()
		var ahead := Vector3(heading.x, 0.0, heading.y)
		play_view = {"eye": play_ball - ahead * 8.0 + Vector3.UP * 3.0, "target": play_ball + ahead * 24.0 + Vector3.UP, "fov": play.fov}

func _shot(id: String, view: Dictionary) -> bool:
	Cams.aim(camera, view.eye, view.target, view.fov)
	if is_instance_valid(game.presentation.set_dressing):
		game.presentation.set_dressing.sync_camera(camera)
	for i in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	_hide_labels()
	await RenderingServer.frame_post_draw
	var still := root.get_texture().get_image()
	var path := out.path_join(id + ".png")
	if still.get_size() != Cams.SIZE or still.save_png(path) != OK:
		quit(3)
		return false
	var eye: Vector3 = view.eye
	var target: Vector3 = view.target
	records.append({"id": id, "eye": [eye.x, eye.y, eye.z],
		"target": [target.x, target.y, target.z], "fov": view.fov,
		"ball": [play_ball.x, play_ball.y, play_ball.z], "sha256": FileAccess.get_sha256(path)})
	return true

func _clutter_instances() -> int:
	var count := 0
	if is_instance_valid(game) and is_instance_valid(game.presentation.set_dressing):
		for batch: MultiMeshInstance3D in game.presentation.set_dressing.batches:
			if batch.has_meta("clutter"):
				count += batch.multimesh.instance_count
	return count


static func _pair(text: String) -> Vector2:
	var parts := text.split(",")
	return Vector2(float(parts[0]), float(parts[1])) if parts.size() == 2 else Vector2.ZERO


func _hashes() -> Dictionary:
	var result := {}
	for path in ["src/world/terrain.gd", "src/core/palette.gd", "src/presentation/palette_materials.gd", "src/presentation/hero_assets.gd",
		"src/presentation/spillway_scenery.gd", "src/presentation/graphics_preset.gd",
		"tools/capture_cameras.gd", "tools/target_capture.gd", "project.godot",
		"assets/shaders/target_dam.gdshader", "assets/shaders/target_surface.gdshaderinc",
		"src/presentation/presentation.gd", "src/presentation/set_dressing.gd",
		"assets/shaders/target_dressing.gdshader", "assets/shaders/target_air.gdshader",
		"assets/shaders/target_protection.gdshaderinc", "src/presentation/clutter.gdshader",
		"src/world/reach_routes.json"]:
		result[path] = FileAccess.get_sha256("res://" + path) if FileAccess.file_exists("res://" + path) else "missing"
	return result


func _hide_labels() -> void:
	hide_labels(root)


static func hide_labels(scene: Node) -> void:
	for node in scene.find_children("*", "CanvasLayer", true, false):
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scene.find_children("*", "CanvasItem", true, false):
		node.visible = false
	for node in scene.find_children("*", "Label3D", true, false):
		node.visible = false


static func _summary(samples: Array[float]) -> Dictionary:
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	var median: float = sorted[middle] if sorted.size() % 2 else (sorted[middle - 1] + sorted[middle]) * 0.5
	var p95: float = sorted[maxi(0, ceili(sorted.size() * 0.95) - 1)]
	return {"median_ms": median, "p95_ms": p95, "samples_ms": samples,
		"available": sorted.front() > 0.0, "sample_count": sorted.size()}
