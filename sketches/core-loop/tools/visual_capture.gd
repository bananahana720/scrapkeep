extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

var game
var settings := {}
var out := ""
var source := Intent.Scripted.new()
var ticks := 0
var frames := 0
var last_usec := 0
var timings: Array[float] = []
var counts: Array[int] = []
var warmup := 180
var samples := 1800
var finished := false
var metadata := {}
var started_usec := 0
var inspection_camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("visual_capture requires a rendered display and -- --out=<absolute directory> [--class=0|1|2] [--mode=dense|pilots] [--samples=1800] [--azimuth=35]")
		quit(2)
		return
	started_usec = Time.get_ticks_usec()
	out = settings["out"]
	DirAccess.make_dir_recursive_absolute(out)
	samples = clampi(int(settings.get("samples", "1800")), 60, 18000)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(270927)
	var identity := []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], identity)
	metadata = {"schema": "scrapkeep-render-capture/1", "git_head": "".join(identity).strip_edges(),
		"godot": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"viewport": [root.size.x, root.size.y], "seed": 270927, "settings": settings,
		"measurement": "wall-clock intervals between frame_post_draw signals, milliseconds; not GPU execution time",
		"source_sha256": {}}
	_hash_sources("res://src")
	_hash_sources("res://assets/models")
	metadata.source_sha256["res://tools/visual_capture.gd"] = FileAccess.get_sha256("res://tools/visual_capture.gd")
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_frame_drawn)


func _process(_delta: float) -> bool:
	if inspection_camera != null and not finished:
		_place_inspection_camera()
	if started_usec > 0 and not finished and Time.get_ticks_usec() - started_usec > 90_000_000:
		metadata["timed_out"] = true
		_finish()
	return false


func _hash_sources(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd") or file.ends_with(".glb"):
			var full := path.path_join(file)
			metadata.source_sha256[full] = FileAccess.get_sha256(full)
	for directory in DirAccess.get_directories_at(path):
		_hash_sources(path.path_join(directory))


func _physics_process(_delta: float) -> bool:
	if game == null or game.flow == null or finished:
		return false
	ticks += 1
	if ticks == 1:
		game.ctx.calm = true
		game.flow.press_start()
		game.flow.choose_class(clampi(int(settings.get("class", "0")), 0, 2))
		game.run.set_max_hp(999999.0)
		game.player.source = source
		if settings.get("mode", "dense") == "pilots":
			inspection_camera = Camera3D.new()
			game.add_child(inspection_camera)
			inspection_camera.fov = 42.0
			inspection_camera.current = true
			_place_inspection_camera()
			game.hud.visible = false
			game.player.body().freeze = true
		return false
	if settings.get("mode", "dense") == "dense":
		source.hold = {"fire_held": true, "move": Vector2(sin(ticks / 180.0) * 0.65, 0.2)}
		if ticks % 90 == 2:
			var n := get_nodes_in_group("enemy").size()
			for i in maxi(0, 48 - n):
				var angle := float(i) * 2.399963 + ticks * 0.001
				var at: Vector3 = game.player.ball_position() + Vector3(cos(angle), 0, sin(angle)) * (12.0 + i % 4 * 3.0)
				game.ctx.spawner.spawn_enemy("lobber" if i % 3 == 0 else "chaser", game.ctx.terrain.drop_point(at.x, at.z, 1.2))
	return false


func _place_inspection_camera() -> void:
	var fitted: Dictionary = game.presentation.hero_assets.shell_of(game.player)
	var pod := fitted.get("pod") as Node3D
	if pod == null:
		return
	var azimuth := deg_to_rad(float(settings.get("azimuth", "35")))
	var offset := Vector3(sin(azimuth) * 4.0, 1.2, -cos(azimuth) * 4.0)
	var at: Vector3 = game.player.shown_position()
	inspection_camera.global_position = at + pod.global_basis * offset
	inspection_camera.look_at(at + Vector3(0, 0.05, 0))


func _frame_drawn() -> void:
	if finished or ticks < 3:
		return
	frames += 1
	var now := Time.get_ticks_usec()
	if frames == warmup:
		var error := root.get_texture().get_image().save_png(out.path_join("scene.png"))
		if error != OK:
			printerr("screenshot failed: %s" % error)
			finished = true
			quit(3)
			return
		# Exclude the screenshot's readback and encoding and the following interval.
		last_usec = 0
		return
	if frames > warmup and last_usec > 0:
		timings.append(float(now - last_usec) / 1000.0)
		counts.append(get_nodes_in_group("enemy").size())
	last_usec = now
	if timings.size() >= samples:
		_finish()


func _finish() -> void:
	finished = true
	var sorted := timings.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.99) - 1)] if not sorted.is_empty() else -1.0
	var adapter: String = metadata.adapter.to_lower()
	var hardware := not adapter.is_empty() and not ("llvmpipe" in adapter or "lavapipe" in adapter or "software" in adapter)
	var qualified: bool = hardware and settings.get("mode", "dense") == "dense" and timings.size() >= 1800 and counts.min() >= 30 and root.size == Vector2i(1920, 1080)
	metadata.merge({"frame_intervals_ms": timings, "enemy_counts": counts, "physics_ticks": ticks,
		"rendered_frames": frames, "requested_samples": samples, "warmup_frames": warmup, "p99_ms": p99, "hardware_candidate": hardware,
		"eligible_dense_sample": qualified, "target_ms": 16.7,
		"target_met": qualified and p99 <= 16.7,
		"limits": "Synthetic seeded dense encounter, inflated player HP, calm mode suppresses ambient arrivals and hit shove, ordinary chase camera. Timing includes CPU, GPU pacing, OS scheduling and presentation. Human acceptance and representative full-run performance remain open."})
	var file := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		printerr("capture.json could not be written")
		quit(3)
		return
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("visual_capture: %d rendered samples, p99 %.3f ms; eligible dense sample: %s" % [timings.size(), p99, qualified])
	quit(0)
