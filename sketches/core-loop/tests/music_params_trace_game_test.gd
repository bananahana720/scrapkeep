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
	_run.call_deferred()


func _run() -> void:
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	if OS.get_environment("KE10_ABSENCE_ONLY") == "1":
		await _absence_fixture()
		quit(t.verdict())
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
		audio._guard_park_bookings()
		var frames: int = audio._park_render_limit(Harmony.RATE / 60)
		if frames > 0:
			audio._render_music(frames, audio.ace != null and audio.ace.active())
		if frame % 1800 == 0:
			var progress := FileAccess.open(OS.get_environment("TMPDIR").path_join("ke10-trace-progress.txt"), FileAccess.WRITE)
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
		"clamps": engine.parameter_clamps, "samples": samples, "layer_changes": changes}
	var trace_path := OS.get_environment("TMPDIR").path_join("ke10-park-dam-trace.json")
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
	t.check("trace has no unflagged mid-phrase changes", changes.all(func(c): return (c.phrase and c.phrase_step % (Harmony.PHRASE_BARS * Harmony.STEPS_PER_BAR) == 0) or MusicRows.danger(c.danger)), str(changes.size()))
	t.check("trace bot engages the dam Warden", engaged, "engaged=%s broke=%s" % [engaged, broke])
	print("KE10_TRACE %s samples=%d changes=%d engaged=%s broke=%s" % [trace_path, samples.size(), changes.size(), engaged, broke])
	physics.queue_free()
	game.queue_free()
	await process_frame
	await _release_fixture()
	await _absence_fixture()
	quit(t.verdict())


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
	engine.render(1)
	engine.parameter_danger("warden_engaged")
	t.check("release fixture starts with busy layers", engine.layer_target(Music.LEAD) > 0.0)
	game.flow._unseal()
	audio._flush_flow()
	var deadline: int = engine.clock + engine.bar_len() * Harmony.PHRASE_BARS
	while engine.clock <= deadline:
		engine.render(mini(4096, deadline + 1 - engine.clock))
	t.check("scripted Warden break releases within one phrase", Music.MELODIC.all(func(layer): return engine.layer_target(layer) == 0.0) and engine.layer_target(Music.WOB) == 0.0)
	print("KE10_RELEASE scripted Game beacon_unsealed clock=%d deadline=%d" % [engine.clock, deadline])
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
	t.check("absent Game feeds have no layer reader", not audio.engine.parameter_layer_reads.has("approach") and not audio.engine.parameter_layer_reads.has("armour"))
	game.queue_free()
	await process_frame
