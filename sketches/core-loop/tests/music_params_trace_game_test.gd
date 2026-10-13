extends SceneTree

const Game := preload("res://src/game.gd")
const Bot := preload("res://tools/bot_driver.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_trace_game_test")
var engaged := false
var broke := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
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
	var samples: Array = engine.parameter_sample_log
	var changes: Array = engine.parameter_layer_log
	var record := {"schema": "scrapkeep-music-parameters/1", "stage": "park_dam", "physics_hz": 60,
		"physics_frames": 18000, "seconds": 300, "policy": "skipper", "seed": 5,
		"engaged": engaged, "broke": broke, "sample_count": engine.parameter_sample_count,
		"clamps": engine.parameter_clamps, "samples": samples, "layer_changes": changes}
	var trace_path := OS.get_environment("TMPDIR").path_join("ke10-park-dam-trace.json")
	var file := FileAccess.open(trace_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(record))
	file.close()
	t.check("five-minute trace is recorded", FileAccess.file_exists(trace_path) and not samples.is_empty(), trace_path)
	t.eq("trace sampler clamps zero values", engine.parameter_clamps, 0)
	t.check("trace values stay in range", samples.all(func(s): return s.values.values().all(func(v): return v >= 0.0 and v <= 1.0)))
	t.check("trace has no unflagged mid-phrase changes", changes.all(func(c): return c.phrase or c.danger != ""), str(changes.size()))
	t.check("trace bot engages the dam Warden", engaged, "engaged=%s broke=%s" % [engaged, broke])
	print("KE10_TRACE %s samples=%d changes=%d engaged=%s broke=%s" % [trace_path, samples.size(), changes.size(), engaged, broke])
	game.queue_free()
	await process_frame
	await _release_fixture()
	await _absence_fixture()
	quit(t.verdict())


func _release_fixture() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	var engine = audio.engine
	engine.begin_boss("warden")
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
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
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
