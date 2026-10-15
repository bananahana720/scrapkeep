# smoke: solo timeout=360s
extends SceneTree

const Game := preload("res://src/game.gd")
const Bot := preload("res://tools/bot_driver.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_trace_game_test")
var engaged := false
var broke := false


class ThreatEnemy extends Node3D:
	func is_dead() -> bool:
		return false


class PhysicsProbe extends Node:
	var frames := 0
	var seconds := 0.0
	var wrong_step := 0
	func _physics_process(delta: float) -> void:
		frames += 1
		seconds += delta
		if absf(delta - 1.0 / 60.0) > 0.000001:
			wrong_step += 1


func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	_run.call_deferred()


func _run() -> void:
	_output_fixture()
	if OS.get_environment("KE10_OUTPUT_ONLY") == "1":
		quit(t.verdict())
		return
	if OS.get_environment("KE10_ABSENCE_ONLY") == "1":
		await _absence_fixture()
		quit(t.verdict())
		return
	if OS.get_environment("KE10_RELEASE_ONLY") == "1":
		await _release_fixture()
		quit(t.verdict())
		return
	if not OS.get_cmdline_user_args().has("--ke10-fixed-trace"):
		var output := []
		var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/music_params_trace_game_test.gd", "--", "--ke10-fixed-trace"], output, true)
		for line in output:
			print(line)
		quit(code)
		return
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.presentation.juice.hit_stop_sink = Callable()
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	if not t.check("Game parameter feed exists", audio.has_method("sample_run_parameters")):
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	var bot := Bot.new(game, "skipper", 5)
	game.events.warden_engaged.connect(func(_stage): engaged = true)
	game.events.beacon_unsealed.connect(func(_stage): broke = true)
	bot.start()
	var physics := PhysicsProbe.new()
	root.add_child(physics)
	var engine = audio.engine
	for frame in 18000:
		bot.tick(1.0 / 60.0)
		await physics_frame
		audio._flush_flow()
		audio._follow_warden()
		audio._follow_escalation()
		audio._pump(Harmony.RATE / 60)
		if frame % 1800 == 0:
			var progress := FileAccess.open(_trace_path("ke10-trace-progress.txt"), FileAccess.WRITE)
			progress.store_string("frame=%d clock=%d engaged=%s broke=%s clamps=%d" % [frame, engine.clock, engaged, broke, engine.parameter_clamps])
			progress.close()
	await process_frame
	var samples: Array = engine.parameter_sample_log
	var changes: Array = engine.parameter_layer_log
	var record := {"schema": "scrapkeep-music-parameters/1", "stage": "park_dam", "physics_hz": 60,
		"physics_frames": physics.frames, "seconds": physics.seconds, "wrong_physics_steps": physics.wrong_step,
		"hit_stop": false, "policy": "skipper", "seed": 5,
		"engaged": engaged, "broke": broke, "sample_count": engine.parameter_sample_count,
		"transport_samples": engine.clock, "transport_steps": engine._parameter_step,
		"run_seconds": game.run.run_time, "bot_outcome": bot.outcome,
		"clamps": engine.parameter_clamps, "samples": samples, "layer_changes": changes,
		"ace_manifest": audio.ace.manifest_source if audio.ace != null else "",
		"ace_layer_changes": audio.ace.parameter_layer_log if audio.ace != null else [], "band_muted": engine.band_muted}
	var trace_path := _trace_path("ke10-park-dam-trace.json")
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	t.eq("trace runs 18000 actual physics steps", physics.frames, 18000)
	t.eq("trace has no scaled physics steps", physics.wrong_step, 0)
	t.near("trace covers 300 simulation seconds", physics.seconds, 300.0, 0.000001)
	t.check("five-minute trace is recorded", FileAccess.file_exists(trace_path) and not samples.is_empty(), trace_path)
	t.eq("trace sampler clamps zero values", engine.parameter_clamps, 0)
	t.eq("trace records every transport sample", samples.size(), ceili(float(engine._parameter_step) / (Harmony.STEPS_PER_BAR / Music.PARAMETER_SAMPLES_PER_BAR)))
	t.check("trace values stay in range", samples.all(func(s): return s.values.values().all(func(v): return v >= 0.0 and v <= 1.0)))
	t.check("trace has no unflagged mid-phrase changes", changes.all(func(c): return (c.phrase and c.phrase_step % (Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR) == 0) or MusicRows.danger(c.danger) or (c.get("ultimate", false) and c.phrase_step % Harmony.STEPS_PER_BAR == 0)), str(changes.size()))
	t.check("trace bot engages the dam Warden", engaged, "engaged=%s broke=%s" % [engaged, broke])
	var performing: Array = record.ace_layer_changes
	t.check("performing ACE changes obey phrase danger or ultimate boundary", performing.all(func(c): return c.timing.is_empty() or (c.timing.phrase and c.timing.phrase_step % (Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR) == 0) or MusicRows.danger(c.danger) or (c.ultimate and c.timing.phrase_step % Harmony.STEPS_PER_BAR == 0)), str(performing.size()))
	print("KE10_TRACE %s samples=%d changes=%d engaged=%s broke=%s" % [trace_path, samples.size(), changes.size(), engaged, broke])
	physics.queue_free()
	game.queue_free()
	await process_frame
	await _release_fixture()
	await _absence_fixture()
	quit(t.verdict())


func _trace_path(filename: String) -> String:
	return ProjectSettings.globalize_path("user://".path_join(filename))


func _output_fixture() -> void:
	var user_dir := ProjectSettings.globalize_path("user://")
	for filename in ["ke10-park-dam-trace.json", "ke10-trace-progress.txt"]:
		var path := _trace_path(filename)
		t.check("trace output stays under user data: %s" % filename, path.is_absolute_path() and path.begins_with(user_dir), path)


func _release_fixture() -> void:
	Engine.time_scale = 1.0
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.mass = 100.0
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	var engine = audio.engine
	engine.bot_skip_samples = true
	var initial: Vector3 = game.player.ball_position()
	t.near("park approach starts at zero", float(audio.sample_run_parameters().get("approach", -1.0)), 0.0)
	var graph = audio._parameter_graph
	game.player.reset_to(graph.position(graph.beacon_node))
	t.near("landmark approach reaches one", float(audio.sample_run_parameters().get("approach", -1.0)), 1.0)
	game.player.reset_to(initial)
	t.near("Game armour fraction uses the run peak", float(audio.sample_run_parameters().get("armour", -1.0)), 1.0)
	game.run.mass = 20.0
	t.near("Game armour fraction follows lost scrap", float(audio.sample_run_parameters().get("armour", -1.0)), 0.2)
	game.run.mass = 100.0
	audio._flush_flow()
	game.events.warden_engaged.emit(1)
	var commit_deadline: int = engine.clock + Harmony.RATE * 10
	while engine.track != "warden" and engine.clock < commit_deadline:
		engine.render(1)
	t.eq("busy horizon uses committed Warden track", engine.track, "warden")
	t.eq("busy horizon uses committed play mode", engine.mode, Music.PLAY)
	t.eq("busy horizon uses committed boss step", engine.step_len, Harmony.BOSS_STEP)
	var track_commits: Array = engine.events_log.filter(func(event): return event[0] == "track" and event[2] == "warden:build")
	t.check("boss commit resets phrase origin", not track_commits.is_empty() and engine.bar_origin == int(track_commits.back()[1]) and engine._bar_step <= 1)
	engine.set_overcharge(2)
	engine.set_fleet_ticks(3)
	engine.parameter_danger("warden_engaged")
	game.player.reset_to(graph.position(graph.beacon_node))
	var initial_enemy := ThreatEnemy.new()
	root.add_child(initial_enemy)
	initial_enemy.add_to_group("enemy")
	initial_enemy.global_position = game.player.ball_position() + game.ctx.aim_forward() * 0.1
	var busy_deadline: int = engine.clock + engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS
	while engine.clock <= busy_deadline:
		engine.render(mini(4096, busy_deadline + 1 - engine.clock))
	t.check("release fixture starts with busy layers", [Music.KEYS, Music.LEAD, Music.WARM, Music.FLEET, Music.LANDMARK_HUM].all(func(layer): return engine.layer_target(layer) > 0.0) and engine.fleet_ticks == 3,
		"targets=%s mode=%d track=%s section=%s clock=%d phrase_step=%d feeds=%s fleet=%d pending=%d" % [engine._targets, engine.mode, engine.track, engine.section, engine.clock, engine._bar_step, audio.sample_run_parameters(), engine.fleet_ticks, engine._parameter_fleet_pending])

	game.flow._unseal()
	audio._flush_flow()
	var deadline: int = engine.clock + engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS
	while engine.clock <= deadline:
		engine.render(mini(4096, deadline + 1 - engine.clock))
	t.check("scripted Warden break releases within one phrase", Music.MELODIC.all(func(layer): return engine.layer_target(layer) == 0.0) and [Music.KEYS, Music.WARM, Music.WOB, Music.FLEET, Music.LANDMARK_HUM].all(func(layer): return engine.layer_target(layer) == 0.0))
	print("KE10_RELEASE scripted Game beacon_unsealed clock=%d deadline=%d" % [engine.clock, deadline])
	initial_enemy.free()
	game.events.launched.emit(Vector3.FORWARD * 30.0)
	t.check("scripted launch arms stage transition", audio._launch_armed)
	game.flow._finish_stage()
	audio._flush_flow()
	t.eq("launch enters next real Game stage", game.run.stage, 2)
	t.check("launch arrival preserves release until phrase", engine.layer_target(Music.LEAD) == 0.0)
	game.run.mass = 100.0
	game.player.set_frozen(true)
	audio.sample_run_parameters()
	# 2026-10-14 coordinator: KD2 (c81cec4a) made the flume a full park stage with its own graph, so
	# the flume now supplies one; the graphless case stays covered by _absence_fixture.
	t.check("flume supplies its own graph", audio._parameter_graph != null)
	game.events.landed.emit(12.0)
	var flume_deadline: int = engine.clock + engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS * 2
	engine.set_overcharge(2)
	engine.set_pressure(1.0)
	# The absent approach feed is preserved on the flume; recovery is checked again below with a graph.
	while engine.clock <= flume_deadline:
		engine.render(mini(4096, flume_deadline + 1 - engine.clock))
	t.check("launch into flume resets release state", not engine._parameter_released)
	game.flow._unseal()
	audio._flush_flow()
	game.events.launched.emit(Vector3.FORWARD * 30.0)
	# The world boss is outside this music fixture. Enter the next authored graph-bearing stage directly.
	game.flow.enter_stage(3, Vector3.FORWARD * 30.0, false)
	audio._flush_flow()
	audio.sample_run_parameters()
	graph = audio._parameter_graph
	if not t.check("next graph-bearing stage supplies a graph", graph != null):
		game.queue_free()
		await process_frame
		return
	game.player.set_frozen(true)
	game.player.reset_to(graph.position(graph.beacon_node))
	game.events.landed.emit(12.0)
	t.check("next stage landing schedules its drop", not audio.drop_log.is_empty() and not audio._launch_armed)
	engine.set_overcharge(2)
	engine.set_fleet_ticks(3)
	var enemy := ThreatEnemy.new()
	root.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = game.player.ball_position() + game.ctx.aim_forward() * 0.1
	var restored: Dictionary = audio.sample_run_parameters()
	t.check("next stage fixture has regained armour and positive feeds", restored.get("armour", 0.0) == 1.0 and restored.get("approach", 0.0) == 1.0 and restored.get("threat", 0.0) > 0.8, str(restored))
	var recovery_deadline: int = engine.clock + engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS * 2
	while engine.clock <= recovery_deadline:
		engine.render(mini(4096, recovery_deadline + 1 - engine.clock))
	t.check("next stage restores eligible layers after landing", [Music.KEYS, Music.LEAD, Music.ARP, Music.WARM, Music.PAD, Music.CHOIR, Music.ECHO, Music.COUNTER, Music.FLEET, Music.LANDMARK_HUM].all(func(layer): return engine.layer_target(layer) > 0.0), str(engine._targets))
	enemy.free()
	game.flow.retry_stage()
	audio._flush_flow()
	t.check("retry resets stage release state", not engine._parameter_released)

	game.queue_free()
	await process_frame


func _absence_fixture() -> void:
	Engine.time_scale = 1.0
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.armor_mode = false
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	audio.engine.render(1)
	var values: Dictionary = audio.sample_run_parameters()
	t.check("no graph means no approach feed", not values.has("approach"), str(values))
	t.check("armour off means no armour feed", not values.has("armour"), str(values))
	t.check("absent Game feeds have no layer reader", not audio.engine.parameter_layer_reads.has("approach") and not audio.engine.parameter_layer_reads.has("armour") and audio.engine.layer_target(Music.LANDMARK_HUM) == 0.0 and audio.engine.layer_starts[Music.LANDMARK_HUM] == 0)
	game.queue_free()
	await process_frame
