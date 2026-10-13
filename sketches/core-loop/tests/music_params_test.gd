extends SceneTree

const Music := preload("res://src/presentation/music_engine.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Audio := preload("res://src/presentation/audio.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_test")
var input := {"threat": 0.0, "approach": 0.0, "armour": 1.0}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var engine := Music.new()
	if not t.check("transport sampler exists", engine.has_method("set_parameter_source")):
		quit(t.verdict())
		return
	engine.call("set_parameter_source", func(): return input.duplicate())
	engine.schedule_restart(0, Music.PLAY, 0)
	engine.render(1)
	var before := engine._targets.duplicate()
	input = {"threat": 1.0, "approach": 1.0, "armour": 1.0}
	_advance(engine, Harmony.BAR * 2 + 1)
	t.eq("mid-phrase targets stay committed", engine._targets, before)
	_advance(engine, Harmony.BAR * Harmony.PHRASE_BARS + 1)
	t.check("phrase admits threat and landmark hum", engine.layer_target(Music.LEAD) > before[Music.LEAD] and engine.layer_target(Music.PAD) > before[Music.PAD])
	input.armour = 0.2
	_advance(engine, Harmony.BAR * Harmony.PHRASE_BARS * 2 + 1)
	t.check("low armour strips melodic layers", Music.MELODIC.all(func(layer): return engine.layer_target(layer) == 0.0))
	t.check("low armour retains drums and bass", engine.layer_target(Music.KICK) > 0.0 and engine.layer_target(Music.SUB) > 0.0)
	input.armour = 1.0
	_advance(engine, Harmony.BAR * Harmony.PHRASE_BARS * 3 + 1)
	t.check("regained scrap restores melody", engine.layer_target(Music.LEAD) > 0.0)
	input = {"threat": 0.0}
	_advance(engine, Harmony.BAR * Harmony.PHRASE_BARS * 4 + 1)
	t.check("absent parameters are not read by layers", not engine.get("parameter_layer_reads").has("approach") and not engine.get("parameter_layer_reads").has("armour"))
	input = {"threat": 0.1}
	_advance(engine, engine.clock + engine.beat_len())
	engine.park_cue("drop_industrial", 0, engine.clock, {}, 0.0, "test-danger")
	engine.render(1)
	t.check("danger-immediate targets open at the cue", engine.layer_target(Music.LEAD) > 0.0 and engine.get("parameter_layer_log").back().danger == "drop_industrial")
	t.check("danger flag defaults false", not Rows.new().call("danger", "riser_natural"))
	for id in ["drop_flood", "drop_industrial", "drop_ancient", "drop_fleet", "stinger_lightning"]:
		t.check("hostile land flag " + id, Rows.new().call("danger", id))
	var hitch := Music.new()
	hitch.call("set_parameter_source", func(): return {"threat": 0.4})
	hitch.schedule_restart(0, Music.PLAY, 0)
	hitch.render(1)
	var hitch_end := Harmony.BAR + roundi(Harmony.RATE * 0.2)
	_advance(hitch, Harmony.BAR - roundi(Harmony.RATE * 0.1))
	hitch.render(hitch_end - hitch.clock)
	var expected := ceili(float(hitch_end) / (Harmony.BAR / 4))
	t.eq("200 ms hitch skips no transport samples", hitch.get("parameter_sample_count"), expected)
	var bounded := Music.new()
	bounded.call("set_parameter_source", func(): return {"threat": 1.5, "approach": -0.2, "armour": 0.5})
	bounded.render(1)
	t.eq("sampler counts out-of-range inputs", bounded.get("parameter_clamps"), 2)
	t.eq("sampler clamps at its boundary", bounded.get("parameters"), {"threat": 1.0, "approach": 0.0, "armour": 0.5})
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/music_params_trace_game_test.gd"], output, true)
	for line in output:
		print(line)
	t.eq("recorded five-minute Game fixture", code, 0)
	quit(t.verdict())


func _advance(engine, until: int) -> void:
	while engine.clock < until:
		engine.render(mini(4096, until - engine.clock))
