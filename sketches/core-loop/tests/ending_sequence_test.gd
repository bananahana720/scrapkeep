# smoke: solo (sequence construction wall-clock budget)
extends SceneTree
# 2026-10-11 (PC-CANNON): keep the existing ending checks and add the quiet-gun answer.

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Sequence := preload("res://src/ui/ending_sequence.gd")
const Profile := preload("res://src/core/profile.gd")
const RunStore := preload("res://src/core/run_store.gd")
const RunLog := preload("res://src/core/run_log.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")
const AppShell := preload("res://src/core/app_shell.gd")

var _t := T.new("ending_sequence_test")
var _game
var _ended := 0
var _earned: Array[String] = []
var _saved_before_sequence := false
var _ending_cannon_answer := -1.0
var _ending_gun_visible := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if OS.get_environment("SCRAPKEEP_END_CAPTURE_DIR") != "":
		root.size = Vector2i(1920, 1080)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "default"
	var folder := "user://ending-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(folder)
	_game.run_store_path = folder.path_join("run.json")
	root.add_child(_game)
	await _frames(5)
	_game.bot_driven = false
	_game.ctx.calm = true
	# The fly-over is the ending when the crater lap cannot place (flow._begin_ending); victory_lap_test owns the lap.
	_game.flow.victory_lap = false
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_game.events.run_ended.connect(_before_sequence)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(3)
	# Visit the dressed worlds through the real entry handlers. No ending builds at boot.
	for world in StageDefs.worlds():
		_game.flow.enter_stage(StageDefs.first_of(world), Vector3.ZERO, false)
	_game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(3)
	_force_win()
	var seq = _game.screens.ending_sequence
	if not _t.check("END-1 final victory starts sequence", is_instance_valid(seq) and seq.active):
		_finish()
		return
	_t.eq("END-1 starts with fly-over", seq.phase, "flyover")
	_t.eq("END-1 three worlds in order", seq.stages.map(func(stage): return StageDefs.world_of(stage)), [1, 2, 3])
	_t.check("END-1 load under two seconds", seq.prepare_usec < 2000000, "%d usec" % seq.prepare_usec)
	_t.check("END-1 duration under ninety seconds", Sequence.TOTAL_SECONDS < 90.0, str(Sequence.TOTAL_SECONDS))
	_t.check("END-3 run-end listeners finish before sequence", _saved_before_sequence)
	_t.eq("END-3 first_win announced once", _earned.count("first_win"), 1)
	_t.eq("END-3 Mind announced once", _earned.count("mind_quieted"), 1)
	_t.check("visuals have no bodies, areas or collision shapes", _physics_free(seq.viewport))
	# KC10 (2026-10-12): the crater_ending bowl is the credits' set, in the ending's own viewport, never a stage.
	var crater_start = seq.get("crater")
	_t.check("KC10 crater set is built in the ending viewport", crater_start != null and seq.viewport.is_ancestor_of(crater_start))
	var crater_outside_stages := crater_start != null
	for stage in seq.stages:
		crater_outside_stages = crater_outside_stages and not _game.ctx.terrain.geometry_root(stage).is_ancestor_of(crater_start)
	_t.check("KC10 crater set is never inside a stage", crater_outside_stages)
	_t.eq("KC10 total stays 54 seconds", Sequence.TOTAL_SECONDS, 54.0)
	_t.check("pilot shell has real model", not seq.shell.find_children("HeroCore", "Node3D", true, false).is_empty())
	_t.check("SPIL-9 has meshes", not seq.companion.find_children("*", "MeshInstance3D", true, false).is_empty())
	if await _capture(seq):
		_finish()
		return
	var summary: Dictionary = _game.run.summary().duplicate(true)
	var source_roots := []
	for stage in seq.stages:
		var holder: Node3D = _game.ctx.terrain.geometry_root(stage)
		source_roots.append([holder, holder.transform, holder.visible])
	# Run the real _process clock faster after the run has ended; no manual phase jumps.
	seq.set_process(true)
	Engine.time_scale = 12.0
	var seen_worlds := []
	var seen_phases := []
	var seen_lines := []
	var positions := {}
	var crew_visible := [true, true, true]
	var camera_moves := [false, false, false]
	var crater_seen := false
	var crater_placed_seen := false
	var crater_meshes := 0
	var crater_physics_free := true
	var worlds_hidden := true
	var bowl_in_frame := false
	var credit_heights := []
	var frames := 0
	while is_instance_valid(_game.screens.ending_sequence) and frames < 1800:
		frames += 1
		seq = _game.screens.ending_sequence
		if not seen_worlds.has(seq.world_index):
			seen_worlds.append(seq.world_index)
		if not seen_phases.has(seq.phase):
			seen_phases.append(seq.phase)
		if seq.phase == "copy" and not seen_lines.has(seq._copy.text):
			seen_lines.append(seq._copy.text)
		if seq.world_index == 2 and seq.phase != "credits":
			_ending_gun_visible = _ending_gun_visible or (is_instance_valid(seq.quiet_gun) and seq.quiet_gun.visible)
			if seq.cannon_answered:
				_ending_cannon_answer = seq.cannon_answer_at
		if seq.phase != "credits":
			crew_visible[seq.world_index] = crew_visible[seq.world_index] and \
				_in_frame(seq.camera, seq.shell.global_position) and _in_frame(seq.camera, seq.companion.global_position)
			if positions.has(seq.world_index) and positions[seq.world_index].distance_to(seq.camera.position) > 0.01:
				camera_moves[seq.world_index] = true
			positions[seq.world_index] = seq.camera.position
		else:
			var crater = seq.get("crater")
			crater_seen = crater_seen or (crater != null and crater.visible)
			# KC10 fix round: the bowl must hold real geometry once placed, and stay collider free after placement.
			if crater != null and seq._crater_placed:
				crater_placed_seen = true
				crater_meshes = maxi(crater_meshes, crater.find_children("*", "MeshInstance3D", true, false).size())
				crater_physics_free = crater_physics_free and _physics_free(seq.viewport)
			worlds_hidden = worlds_hidden and seq.worlds.all(func(w): return not w.visible)
			bowl_in_frame = bowl_in_frame or _in_frame(seq.camera, Vector3.ZERO)
			credit_heights.append(seq.camera.position.y)
		await process_frame
	Engine.time_scale = 1.0
	_t.check("KC10 crater set shows in the credits", crater_seen)
	_t.check("KC10 crater placed before the credits ended", crater_placed_seen)
	_t.check("KC10 crater bowl geometry renders in the credits", crater_meshes > 0, "%d mesh nodes" % crater_meshes)
	_t.check("KC10 crater set stays physics free after placement", crater_physics_free)
	_t.check("KC10 credits hide the Highdraft worlds", worlds_hidden)
	_t.check("KC10 credits camera has the bowl centre in frame", bowl_in_frame)
	_t.check("KC10 camera drops over the rim through the credits", credit_heights.size() > 1 and credit_heights[0] > credit_heights.back(), str(credit_heights.slice(0, 3)))
	_t.eq("END-1 all fly-overs play automatically", seen_worlds, [0, 1, 2])
	_t.eq("END-1 phases play automatically", seen_phases, ["flyover", "copy", "credits"])
	var lines: Array = []
	for world in Worlds.ROWS:
		lines.append_array(Worlds.ENDING.log[int(world.id)])
	_t.eq("END-1 ending copy appears line by line", seen_lines, lines)
	_t.eq("crew stays in frame in all three worlds", crew_visible, [true, true, true])
	_t.eq("camera moves in all three worlds", camera_moves, [true, true, true])
	_t.check("END-1 automatic completion reaches summary", not _game.screens.ending_open() and _game.screens._actions.visible)
	_t.eq("END-1 summary state", _game.flow.state_name(), "summary")
	_t.eq("END-3 bookkeeping emitted once", _ended, 1)
	_t.eq("END-3 summary data unchanged", _game.run.summary(), summary)
	for row in source_roots:
		_t.check("live terrain remains parked", row[0].transform == row[1] and row[0].visible == row[2])
	_t.check("quiet gun appears in the Highdraft", _ending_gun_visible)
	_t.check("quiet gun answers at eight seconds", absf(_ending_cannon_answer - 8.0) <= 60.0 / 172.0, str(_ending_cannon_answer))
	_t.eq("ending answers only once", _game.presentation.audio.cannon_log.filter(func(row): return row["kind"] == "ending_cannon").size(), 1)
	_crater_release_checks()
	_skip_checks()
	await _resume_world_check()
	_finish()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _set_space(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _force_win() -> void:
	_game.flow._set_state(_game.flow.BOSS)
	_game.events.boss_defeated.emit()
	_game.flow.physics_step(_game.flow.VICTORY_SECONDS + 0.01)


func _before_sequence(won: bool) -> void:
	_ended += 1
	var reloaded := Profile.new(_game.ctx.profile.path)
	var disk_ok := reloaded.load_profile() and reloaded.earned("first_win") and reloaded.earned("mind_quieted")
	var tombstone = JSON.parse_string(FileAccess.get_file_as_string(_game.flow.store.path))
	var log_path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var logs := FileAccess.get_file_as_string(log_path).strip_edges().split("\n", false)
	var line = JSON.parse_string(logs[-1]) if not logs.is_empty() else {}
	_saved_before_sequence = won and disk_ok and reloaded.has_pilot("remembered_cannon") \
		and reloaded.has_cosmetic("paint_kest_dusk") and tombstone.get("ended", false) \
		and line.get("outcome") == "won" and _game.run.over \
		and not is_instance_valid(_game.screens.ending_sequence)


func _crater_release_checks() -> void:
	for action in ["free", "skip", "cancel"]:
		var seq := Sequence.new()
		_game.screens.add_child(seq)
		seq.start(_game)
		seq.set_process(false)
		var paths: Array = seq._crater_paths()
		var requests = seq.get("_crater_requests")
		_t.check("KC10 %s fixture requests crater loads before credits" % action,
			not paths.is_empty() and seq.phase == "flyover")
		if action == "free":
			seq.free()
		else:
			seq.call(action)
		_t.check("KC10 %s before credits clears tracked requests" % action,
			requests is Array and requests.is_empty())
		for path in paths:
			var status := ResourceLoader.load_threaded_get_status(path)
			_t.eq("KC10 %s leaves no threaded task for %s" % [action, path],
				status, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
		if action != "free":
			seq.free()


func _skip_checks() -> void:
	# A second final win skips at elapsed zero with a real Space press (a confirm key).
	_game.flow.new_run()
	_game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	_force_win()
	# Exercise game._input too, so its summary keys cannot steal or duplicate a skip.
	_game.test_mode = false
	_t.check("END-1 second run starts", _game.screens.ending_open())
	# The skip is a real Space press through Input, so Input reports it held. Since cb67c62d the
	# summary's latch, not a 0.75 s time lock, keeps the held skip press from starting a run; the
	# release reopens it for a fresh press (the input latch design, wave 19).
	_set_space(true)
	_t.check("END-1 confirm skips immediately", not _game.screens.ending_open() and _game.screens._actions.visible)
	_t.eq("END-1 confirm leaves summary", _game.flow.state_name(), "summary")
	_game._screen_key(KEY_SPACE)
	_t.eq("skip press cannot start another run", _game.flow.state_name(), "summary")
	_set_space(false)
	_game.step_summary_latch()
	_t.check("skip release opens the summary latch", not _game.summary_latched)
	for time in [0.0, 4.0, Sequence.WORLD_SECONDS * 3.0 + 2.0]:
		_force_win()
		_game.screens.ending_sequence.advance(time)
		Push.key(root, KEY_ESCAPE)
		_t.check("back skips at %.1f seconds" % time, not _game.screens.ending_open())
	_force_win()
	_game.screens.ending_sequence.advance(15.0)
	Push.pad(root, JOY_BUTTON_A)
	_t.check("pad confirm skips copy", not _game.screens.ending_open())
	_force_win()
	_game.screens.ending_sequence.advance(38.0)
	Push.pad(root, JOY_BUTTON_B)
	_t.check("pad back skips credits", not _game.screens.ending_open())
	_t.check("credits name creator and tools", Sequence.CREDITS.contains("Andrew") \
		and Sequence.CREDITS.contains("Godot") and Sequence.CREDITS.contains("Blender") \
		and Sequence.CREDITS.contains("ACE-Step") and Sequence.CREDITS.contains("Claude") and Sequence.CREDITS.contains("Codex"))


func _resume_world_check() -> void:
	_game.free()
	_game = Game.new()
	_game.test_mode = true
	_game.table = "default"
	root.add_child(_game)
	await _frames(5)
	_game.bot_driven = false
	_game.ctx.calm = true
	_game.flow.victory_lap = false
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(2)
	_game.flow.enter_stage(StageDefs.COUNT, Vector3.ZERO, false)
	await _frames(2)
	_t.check("resumed fixture has no Dig geometry", not _game.ctx.terrain.is_built(StageDefs.first_of(2)))
	_force_win()
	var seq = _game.screens.ending_sequence
	_t.check("resumed ending builds Dig visuals without live terrain", not _game.ctx.terrain.is_built(StageDefs.first_of(2)))
	_t.check("resumed ending has dressed Dig", seq.worlds[1].has_node("DigScenery"))
	_t.check("resumed ending remains physics free", _physics_free(seq.viewport))
	_t.check("resumed ending load under two seconds", seq.prepare_usec < 2000000, "%d usec" % seq.prepare_usec)
	seq.skip()


func _physics_free(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D:
		return false
	for child in node.get_children():
		if not _physics_free(child):
			return false
	return true


func _capture(seq) -> bool:
	var folder := OS.get_environment("SCRAPKEEP_END_CAPTURE_DIR")
	if folder == "":
		return false
	if not _t.check("capture requires rendered display", not AppShell.headless()):
		return true
	DirAccess.make_dir_recursive_absolute(folder)
	seq.set_process(false)
	var shots := []
	var labels := ["spillway", "dig", "highdraft"]
	for i in 3:
		seq.advance((4.0 if i == 0 else Sequence.WORLD_SECONDS))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var file: String = folder.path_join("END-%s.png" % labels[i])
		_t.eq("capture %s saved" % labels[i], root.get_texture().get_image().save_png(file), OK)
		shots.append({"file": file, "world": i + 1, "stage": seq.stages[i], "seconds": seq.elapsed,
			"camera": var_to_str(seq.camera.transform), "fov": seq.camera.fov,
			"shell": var_to_str(seq.shell.transform), "spil9": var_to_str(seq.companion.transform)})
	var metadata := {"godot": Engine.get_version_info(), "method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "prepare_usec": seq.prepare_usec, "shots": shots}
	var file := FileAccess.open(folder.path_join("END-capture.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metadata, "\t"))
	seq.skip()
	return true


func _in_frame(cam: Camera3D, at: Vector3) -> bool:
	return not cam.is_position_behind(at) and Rect2(Vector2.ZERO, Vector2(cam.get_viewport().size)).has_point(cam.unproject_position(at))


func _finish() -> void:
	Engine.time_scale = 1.0
	_game.free()
	quit(_t.verdict())
