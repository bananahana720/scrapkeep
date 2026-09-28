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
var mode := "dense"
var seconds := 0.0
var measurement_start := 0
var shot_saved := false
var settled_ticks := 0
var physics_seconds := 0.0
var shots := 0
var boss_attacks := 0
var hazard_peak := 0
var measured_physics_start := 0.0
var distance_travelled := 0.0
var previous_position := Vector3.ZERO
var boss_phase_counts := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	if DisplayServer.get_name() == "headless" or not settings.has("out"):
		printerr("visual_capture requires a rendered display and -- --out=<absolute directory> [--class=0|1|2] [--mode=traversal|dense|boss|pilots] [--samples=1800|--seconds=120] [--growth=600] [--azimuth=35]")
		quit(2)
		return
	started_usec = Time.get_ticks_usec()
	out = settings["out"]
	DirAccess.make_dir_recursive_absolute(out)
	samples = clampi(int(settings.get("samples", "1800")), 60, 18000)
	mode = settings.get("mode", "dense")
	if mode not in ["pilots", "traversal", "dense", "boss"]:
		quit(2)
		return
	seconds = clampf(float(settings.get("seconds", "0")), 0.0, 120.0)
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	seed(270927)
	var identity := []
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], identity)
	metadata = {"schema": "scrapkeep-render-capture/1", "git_head": "".join(identity).strip_edges(),
		"godot": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"mode": mode, "requested_render_size": [1920, 1080], "seed": 270927, "settings": settings,
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
	if started_usec > 0 and not finished and Time.get_ticks_usec() - started_usec > int((60.0 + maxf(seconds, 90.0)) * 1000000.0):
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


func _physics_process(delta: float) -> bool:
	if game == null or game.flow == null or finished:
		return false
	ticks += 1
	physics_seconds += delta
	if ticks == 1:
		game.ctx.calm = mode != "boss"
		game.flow.press_start()
		game.flow.choose_class(clampi(int(settings.get("class", "0")), 0, 2))
		game.run.set_max_hp(999999.0)
		game.player.source = source
		game.events.shot_fired.connect(func(_id, _from, _to): shots += 1)
		game.events.boss_attack_telegraphed.connect(func(_id, _seconds): boss_attacks += 1)
		var growth := clampi(int(settings.get("growth", "0")), 0, 5000)
		game.run.add_scrap(growth, game.player.ball_position())
		metadata["growth_scrap_added"] = growth
		if mode == "boss":
			game.flow.enter_boss(Vector3(18, 0, 0))
			game.boss.jump_to_phase(3)
			metadata["boss_setup"] = "real flow.enter_boss, dev jump_to_phase(3); real spawner and hazards"
		else:
			var bowl: Vector3 = game.ctx.terrain.beacon_point(1) + Vector3(10, 0, 8)
			game.player.reset_to(game.ctx.terrain.drop_point(bowl.x, bowl.z, 1.2))
			metadata["stage_position"] = [bowl.x, bowl.y, bowl.z]
		if mode == "pilots":
			source.hold = {"brake_held": true}
			inspection_camera = Camera3D.new()
			game.add_child(inspection_camera)
			inspection_camera.fov = 42.0
			inspection_camera.current = true
			game.hud.visible = false
		return false
	var position: Vector3 = game.player.ball_position()
	if ticks > 2:
		distance_travelled += position.distance_to(previous_position)
	previous_position = position
	if mode == "boss":
		boss_phase_counts[str(game.boss.phase)] = int(boss_phase_counts.get(str(game.boss.phase), 0)) + 1
	if mode == "pilots" and not game.player.body().freeze:
		if game.player.state.grounded and game.player.body().linear_velocity.length() < 0.1:
			settled_ticks += 1
		else:
			settled_ticks = 0
		if settled_ticks >= 30:
			game.player.body().freeze = true
			metadata["settled_tick"] = ticks
			metadata["settled_ground_clearance"] = game.player.ball_position().y - game.ctx.terrain.height(game.player.ball_position().x, game.player.ball_position().z)
	elif mode == "dense":
		source.hold = {"fire_held": true, "brake_held": true}
		if ticks % 90 == 2:
			var n := get_nodes_in_group("enemy").size()
			for i in maxi(0, 48 - n):
				var angle := float(i) * 2.399963 + ticks * 0.001
				var at: Vector3 = game.player.ball_position() + Vector3(cos(angle), 0, sin(angle)) * (12.0 + i % 4 * 3.0)
				game.ctx.spawner.spawn_enemy("lobber" if i % 3 == 0 else "chaser", game.ctx.terrain.drop_point(at.x, at.z, 1.2))
	elif mode == "traversal":
		source.hold = {"move": Vector2(sin(ticks / 180.0), cos(ticks / 180.0))}
	elif mode == "boss":
		source.hold = {"move": Vector2(sin(ticks / 180.0), cos(ticks / 180.0)), "fire_held": true}
		hazard_peak = maxi(hazard_peak, game.boss.active_hazards().size())
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
	if not shot_saved:
		if frames < warmup or ticks < 450 or (mode == "pilots" and not game.player.body().freeze) or (mode == "dense" and shots == 0) or (mode == "boss" and boss_attacks == 0):
			return
		var capture := root.get_texture().get_image()
		metadata["screenshot_dimensions"] = [capture.get_width(), capture.get_height()]
		metadata["screenshot_tick"] = ticks
		metadata["screenshot_monitors"] = _monitor_snapshot()
		metadata["growth_actual"] = {"mass": game.run.mass, "heft_class": game.run.heft_class(), "chunks": game.build.accretion.chunk_count(), "shell_scale": game.build.accretion.scale.x}
		metadata["screenshot_shots_fired"] = shots
		metadata["screenshot_boss_attacks"] = boss_attacks
		var error := capture.save_png(out.path_join("scene.png"))
		if error != OK:
			quit(3)
			return
		shot_saved = true
		last_usec = 0
		return
	if last_usec > 0:
		timings.append(float(now - last_usec) / 1000.0)
		counts.append(get_nodes_in_group("enemy").size())
	else:
		measurement_start = now
		measured_physics_start = physics_seconds
	last_usec = now
	if (seconds > 0.0 and float(now - measurement_start) / 1000000.0 >= seconds) or (seconds == 0.0 and timings.size() >= samples):
		_finish()


func _monitor_snapshot() -> Dictionary:
	return {"visible_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"texture_memory_bytes": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED),
		"buffer_memory_bytes": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)}


func _finish() -> void:
	finished = true
	var sorted := timings.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(sorted.size() - 1, ceili(sorted.size() * 0.99) - 1)] if not sorted.is_empty() else -1.0
	var adapter: String = metadata.adapter.to_lower()
	var hardware := not adapter.is_empty() and not ("llvmpipe" in adapter or "lavapipe" in adapter or "software" in adapter)
	var duration := float(last_usec - measurement_start) / 1000000.0 if measurement_start > 0 else 0.0
	var render_size := root.get_texture().get_size()
	var window_size := DisplayServer.window_get_size()
	var resolution_ok: bool = render_size == Vector2(1920, 1080) and metadata.get("screenshot_dimensions", []) == [1920, 1080]
	var growth_actual: Dictionary = metadata.get("growth_actual", {})
	var grown: bool = growth_actual.get("heft_class", 1) > 1 and growth_actual.get("chunks", 0) > 0 and growth_actual.get("shell_scale", 1.0) > 1.0
	var growth_ok: bool = int(settings.get("growth", "0")) == 0 or grown
	var encounter_ok: bool = (mode == "dense" and not counts.is_empty() and counts.min() >= 30) or (mode == "traversal" and distance_travelled > 100.0) or (mode == "boss" and boss_attacks > 0 and hazard_peak > 0)
	var qualified: bool = hardware and resolution_ok and encounter_ok and growth_ok and seconds >= 120.0 and duration >= 120.0 and not metadata.get("timed_out", false)
	metadata.merge({"frame_intervals_ms": timings, "enemy_counts": counts, "physics_ticks": ticks,
		"final_monitors": _monitor_snapshot(), "grown_build_verified": grown, "growth_criteria_met": growth_ok,
		"scene_physics_seconds": physics_seconds, "measured_physics_seconds": physics_seconds - measured_physics_start,
		"measurement_wall_seconds": duration, "requested_seconds": seconds,
		"scene_wall_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0,
		"final_root_size": [root.size.x, root.size.y], "final_render_size": [render_size.x, render_size.y],
		"window_pixel_size": [window_size.x, window_size.y], "resolution_verified": resolution_ok,
		"distance_travelled": distance_travelled, "boss_phase_tick_counts": boss_phase_counts, "shots_fired": shots, "boss_attacks": boss_attacks, "boss_hazard_peak": hazard_peak,
		"rendered_frames": frames, "requested_samples": samples, "warmup_frames": warmup, "p99_ms": p99, "hardware_candidate": hardware,
		"scenario_criteria_met": encounter_ok, "eligible_scenario_sample": qualified, "eligible_dense_sample": qualified and mode == "dense", "target_ms": 16.7,
		"target_met": qualified and p99 <= 16.7,
		"limits": "Staged seeded scenario; inflated player HP; calm mode except boss. Dense replenishes 48 enemies on existing beacon bowl. Traversal uses scripted circular input. Boss enters real phase 3 via dev hook; no prior run progression. Timing includes CPU, GPU pacing, OS scheduling and presentation. Human acceptance and representative full-run performance remain open."})
	var file := FileAccess.open(out.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		printerr("capture.json could not be written")
		quit(3)
		return
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	print("visual_capture: %d rendered samples, p99 %.3f ms; eligible dense sample: %s" % [timings.size(), p99, qualified])
	quit(0)
