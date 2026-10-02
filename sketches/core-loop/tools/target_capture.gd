extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Cams := preload("res://tools/capture_cameras.gd")
const SEED := 280928
const SAMPLE_FRAMES := 240
const WARMUP_FRAMES := 180
var game
var out := ""
var preset := "high"
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
	if out.is_empty() or DisplayServer.get_name() == "headless" or not Preset.PRESETS.has(preset):
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
	# Measure the live scene, including simulation and presentation. Discard initial
	# shader/GI warmup; intervals between presented draws are throughput, not GPU-only time.
	for i in WARMUP_FRAMES:
		await RenderingServer.frame_post_draw
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	var sorted := samples.duplicate()
	sorted.sort()
	timing = {"frames": SAMPLE_FRAMES, "warmup_frames": WARMUP_FRAMES,
		"median_ms": (sorted[119] + sorted[120]) * 0.5, "p95_ms": sorted[227],
		"samples_ms": samples, "vsync": "disabled", "max_fps": 0,
		"method": "wall-clock intervals between frame_post_draw signals; live simulation, fixed play camera; not GPU-only time"}
	# FPS changes how far simulation advances during measurement. Rebuild from the same
	# seed and physics count, so the three stills compare identical staged scene state.
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
		"staged_physics_frames": 120, "table": "default", "preset": preset,
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
	game.table = "default"
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
	var xz: Vector2 = play.ball_xz
	play_ball = game.ctx.terrain.drop_point(xz.x, xz.y, play.clearance)
	game.player.reset_to(play_ball)
	game.player._visual_root.global_position = play_ball
	for spot in play.enemies_xz:
		game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(spot.x, spot.y, 1.2))
	game.flow.warden._look._badge.visible = false
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	for label in root.find_children("*", "Label3D", true, false):
		label.visible = false
	camera = Camera3D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.add_child(camera)
	camera.current = true
	camera.far = Cams.FAR
	play_view = {"eye": play_ball + play.eye_offset, "target": play_ball + play.target_offset, "fov": play.fov}

func _shot(id: String, view: Dictionary) -> bool:
	Cams.aim(camera, view.eye, view.target, view.fov)
	# SDFGI and volumetric temporal history must settle after a camera jump while the
	# simulation remains frozen. No animation or physics frames advance between stills.
	for i in WARMUP_FRAMES:
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

func _hashes() -> Dictionary:
	var result := {}
	for path in ["src/world/terrain.gd", "src/core/palette.gd", "src/presentation/hero_assets.gd",
		"src/presentation/spillway_scenery.gd", "src/presentation/graphics_preset.gd",
		"tools/capture_cameras.gd", "tools/target_capture.gd", "project.godot"]:
		result[path] = FileAccess.get_sha256("res://" + path)
	return result
