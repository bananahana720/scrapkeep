# smoke: solo timeout=360s (fixed-physics 5 minute Game trace in a child process)
extends SceneTree

const Music := preload("res://src/presentation/music_engine.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_test")
var input := {"threat": 0.0, "approach": 0.0, "armour": 1.0}


class ThreatEnemy extends Node3D:
	var dead := false
	func is_dead() -> bool:
		return dead


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var enemy := ThreatEnemy.new()
	root.add_child(enemy)
	enemy.position = Vector3.FORWARD * 12.0
	var front := Audio.run_threat(Vector3.ZERO, Vector3.FORWARD, [enemy])
	var back := Audio.run_threat(Vector3.ZERO, Vector3.BACK, [enemy])
	t.check("threat includes facing with proximity dominant", front > back and back > front * 0.5)
	enemy.position = Vector3.FORWARD * 36.0
	t.check("threat falls with distance", Audio.run_threat(Vector3.ZERO, Vector3.FORWARD, [enemy]) < front)
	enemy.dead = true
	t.near("dead enemies contribute no threat", Audio.run_threat(Vector3.ZERO, Vector3.FORWARD, [enemy]), 0.0)
	enemy.free()
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
	t.check("phrase admits threat", engine.layer_target(Music.LEAD) > before[Music.LEAD])
	t.near("sampled threat feeds set_pressure", engine.pressure, 1.0)
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
	engine.park_cue("drop_industrial", 0, engine.clock)
	engine.render(1)
	t.check("danger-immediate targets open at the cue", engine.layer_target(Music.LEAD) > 0.0 and engine.get("parameter_layer_log").back().danger == "drop_industrial")
	t.check("danger flag defaults false", not Rows.new().call("danger", "riser_natural"))
	for id in ["drop_flood", "drop_industrial", "drop_ancient", "drop_fleet", "stinger_lightning"]:
		t.check("hostile land flag " + id, Rows.new().call("danger", id))
	var hitch := Music.new()
	hitch.call("set_parameter_source", func(): return {"threat": 0.4})
	hitch.schedule_restart(0, Music.PLAY, 0)
	hitch.render(1)
	var hitch_end := Harmony.BAR + roundi(Harmony.RATE * 0.1)
	_advance(hitch, Harmony.BAR - roundi(Harmony.RATE * 0.1))
	hitch.render(hitch_end - hitch.clock)
	var expected := ceili(float(hitch_end) / (Harmony.BAR / 4))
	t.eq("ordinary grid survives a 200 ms hitch", hitch.get("parameter_sample_count"), expected)
	# A short bar makes one hitch cross several sample deadlines, exposing lost catch-up.
	var fast_hitch := Music.new()
	fast_hitch.set_parameter_source(func(): return {"threat": 0.4})
	fast_hitch._set_grid(1000)
	fast_hitch.render(1)
	var fast_bar := 1000 * Harmony.STEPS_PER_BAR
	var fast_end := fast_bar + roundi(Harmony.RATE * 0.1)
	_advance(fast_hitch, fast_bar - roundi(Harmony.RATE * 0.1))
	var hitch_frames := fast_end - fast_hitch.clock
	fast_hitch.render(hitch_frames)
	t.eq("hitch is exactly 200 ms", hitch_frames, roundi(Harmony.RATE * 0.2))
	t.eq("hitch advances the transport without a stall", fast_hitch.clock, fast_end)
	t.eq("200 ms hitch skips no transport samples", fast_hitch.parameter_sample_count, ceili(float(fast_end) / (fast_bar / 4)))
	var bounded := Music.new()
	bounded.call("set_parameter_source", func(): return {"threat": 1.5, "approach": -0.2, "armour": 0.5})
	bounded.render(1)
	t.eq("sampler counts out-of-range inputs", bounded.get("parameter_clamps"), 2)
	t.eq("sampler clamps at its boundary", bounded.get("parameters"), {"threat": 1.0, "approach": 0.0, "armour": 0.5})
	input = {"threat": 0.0, "armour": 1.0}
	var pivot := Music.new()
	pivot.set_parameter_source(func(): return input.duplicate())
	pivot.schedule_restart(0, Music.PLAY, 0)
	_advance(pivot, Harmony.BAR * 3 + 1)
	pivot.force_track("warden", 0, "build", true)
	pivot.render(1)
	var pivot_origin := pivot.bar_origin
	var pivot_targets := pivot._targets.duplicate()
	input.threat = 1.0
	_advance(pivot, pivot_origin + pivot.bar_len() * 5 + 1)
	t.eq("track pivot preserves actual phrase timing", pivot._targets, pivot_targets)
	_advance(pivot, pivot_origin + pivot.bar_len() * Harmony.PHRASE_BARS + 1)
	t.check("pivot phrase admits pending layers", pivot.layer_target(Music.LEAD) > pivot_targets[Music.LEAD])
	_landmark_hum_fixture()
	_fleet_fixture(true)
	_fleet_fixture(false)
	for pilot in Harmony.CLASS_MOTIFS:
		_ultimate_fixture(pilot)
	_stopped_ultimate_fixture()
	_handback_hum_fixture()
	if OS.get_environment("KE10_UNIT_ONLY") == "1":
		quit(t.verdict())
		return
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/music_params_trace_game_test.gd", "--", "--ke10-fixed-trace"], output, true)
	for line in output:
		print(line)
	t.eq("recorded five-minute Game fixture", code, 0)
	quit(t.verdict())


func _advance(engine, until: int) -> void:
	while engine.clock < until:
		engine.render(mini(4096, until - engine.clock))


func _ultimate_fixture(pilot: String) -> void:
	var lift := Music.new()
	input = {"threat": 0.3, "approach": 0.0, "armour": 1.0}
	lift.set_parameter_source(func(): return input.duplicate())
	lift.set_class_motif(pilot)
	lift.schedule_restart(0, Music.PLAY, 0)
	_advance(lift, Harmony.BAR + 1)
	var before: float = lift.layer_target(Music.ARP)
	lift.set_ultimate_lift(true)
	input = {"threat": 1.0, "approach": 1.0, "armour": 0.2}
	_advance(lift, Harmony.BAR * 2)
	t.near("ultimate waits for next bar " + pilot, lift.layer_target(Music.ARP), before)
	lift.render(1)
	# ARP's existing curve spans 0.3..0.5; the lift adds 0.12 to committed 0.3.
	var x := (0.42 - 0.3) / (0.5 - 0.3)
	t.near("ultimate rises at next bar " + pilot, lift.layer_target(Music.ARP), x * x * (3.0 - 2.0 * x))
	t.eq("ultimate admits no pending threat " + pilot, lift.layer_target(Music.LEAD), 0.0)
	t.eq("ultimate admits no pending approach " + pilot, lift.layer_target(Music.LANDMARK_HUM), 0.0)
	t.check("ultimate admits no pending armour " + pilot, lift.layer_target(Music.KEYS) > 0.0)
	lift.set_ultimate_lift(false)
	_advance(lift, Harmony.BAR * 3)
	t.near("spent lift waits for next bar " + pilot, lift.layer_target(Music.ARP), x * x * (3.0 - 2.0 * x))
	lift.render(1)
	t.eq("spent lift releases at next bar " + pilot, lift.layer_target(Music.ARP), 0.0)
	t.check("spent lift retains committed armour " + pilot, lift.layer_target(Music.KEYS) > 0.0)
	_advance(lift, Harmony.BAR * Harmony.PHRASE_BARS + 1)
	t.eq("pending armour still commits at phrase " + pilot, lift.layer_target(Music.KEYS), 0.0)


func _stopped_ultimate_fixture() -> void:
	var audio := Audio.new()
	audio.engine = Music.new()
	audio.engine.set_parameter_source(func(): return {"threat": 0.0})
	audio.ace = Ace.new("")
	audio.ace.parameter_enabled = true
	audio._set_ult_lift(true)
	t.check("stopped ACE sequencer retains requested lift", audio.ace.ultimate_lift)
	audio.ace.ultimate_lift = true
	audio._set_ult_lift(false)
	t.check("stopped ACE sequencer clears spent lift", not audio.ace.ultimate_lift)
	audio.free()


func _handback_hum_fixture() -> void:
	var audio := Audio.new()
	audio.engine = Music.new()
	audio.engine.out_landmark = PackedVector2Array([Vector2(0.25, 0.25)])
	audio.engine.out_music = PackedVector2Array([Vector2(0.25, 0.25)])
	audio._unmute_at = 0
	audio._fade_in_band(0, 1, audio.engine.out_landmark)
	t.eq("handback first frame retains landmark hum", audio.engine.out_music[0], Vector2(0.25, 0.25))
	audio.engine.out_music = PackedVector2Array([Vector2(0.75, 0.75)])
	var half_sample := floori(audio.UNMUTE_RAMP / 2)
	audio._fade_in_band(half_sample, 1, audio.engine.out_landmark)
	var expected := 0.25 + 0.5 * half_sample / audio.UNMUTE_RAMP
	t.eq("handback fades only the synth contribution", audio.engine.out_music[0], Vector2(expected, expected))
	audio.free()


func _fleet_fixture(armour: bool) -> void:
	var fleet := Music.new()
	fleet.set_parameter_source(func(): return {"threat": 0.0, "armour": 1.0} if armour else {"threat": 0.0})
	fleet.schedule_restart(0, Music.PLAY, 0)
	_advance(fleet, Harmony.BAR + 1)
	var starts := 0
	fleet.set_fleet_ticks(3)
	var boundary := Harmony.BAR * Harmony.PHRASE_BARS
	_advance(fleet, boundary)
	t.eq("Fleet entry waits for phrase armour=%s" % armour, fleet.layer_starts[Music.FLEET], starts)
	t.eq("Fleet density stays pending armour=%s" % armour, fleet.fleet_ticks, 0)
	fleet.render(1)
	t.eq("Fleet density commits on phrase armour=%s" % armour, fleet.fleet_ticks, 3)
	t.check("Fleet voice starts on phrase armour=%s" % armour, fleet.layer_starts[Music.FLEET] > starts)
	var logged: Array = fleet.parameter_layer_log.filter(func(c): return c.get("fleet_ticks", -1) == 3)
	t.check("Fleet density is traced on phrase armour=%s" % armour, not logged.is_empty() and logged.back().at == boundary and logged.back().phrase)
	fleet.set_fleet_ticks(1)
	_advance(fleet, boundary * 2)
	t.eq("Fleet density change waits for next phrase armour=%s" % armour, fleet.fleet_ticks, 3)
	fleet.render(1)
	t.eq("Fleet density change commits on next phrase armour=%s" % armour, fleet.fleet_ticks, 1)
	var legacy := Music.new()
	legacy.schedule_restart(0, Music.PLAY, 0)
	legacy.render(1)
	legacy.set_fleet_ticks(3)
	_advance(legacy, Harmony.BAR + 1)
	t.eq("legacy Fleet still enters next bar armour=%s" % armour, legacy.fleet_ticks, 3)


func _landmark_hum_fixture() -> void:
	var hum := Music.new()
	var layer: int = Music.LAYER_NAMES.find("landmark_hum")
	if not t.check("approach owns the distinct landmark hum layer", layer >= 0):
		return
	input = {"threat": 0.0, "approach": 0.0, "armour": 1.0}
	hum.set_parameter_source(func(): return input.duplicate())
	hum.schedule_restart(0, Music.PLAY, 0)
	hum.render(1)
	t.eq("zero approach contributes no landmark hum", hum.layer_target(layer), 0.0)
	input.approach = 1.0
	var boundary := Harmony.BAR * Harmony.PHRASE_BARS
	_advance(hum, boundary)
	t.eq("approach-only hum waits for phrase", hum.layer_starts[layer], 0)
	t.eq("approach-only gain waits for phrase", hum.layer_target(layer), 0.0)
	hum.render(1)
	t.near("approach-only opens landmark hum on phrase", hum.layer_target(layer), 1.0)
	t.eq("approach leaves generic pad alone", hum.layer_target(Music.PAD), 0.0)
	var voices: Array = hum._voices.filter(func(v): return v.layer == layer)
	t.check("record-selected beacon hum starts on phrase", not voices.is_empty())
	if not voices.is_empty():
		t.check("landmark hum uses record-selected existing samples", voices.back().buf == preload("res://src/presentation/sfx_bank.gd").samples("beacon_hum"))
		t.near("landmark hum uses shared sound trim", voices.back().gl, db_to_linear(preload("res://src/presentation/sfx_bank.gd").trim_db("beacon_hum")))
	input.armour = 0.2
	_advance(hum, boundary * 2 + 1)
	t.eq("low armour releases landmark hum", hum.layer_target(layer), 0.0)
	input.armour = 1.0
	_advance(hum, boundary * 3 + 1)
	t.eq("regained armour restores landmark hum", hum.layer_target(layer), 1.0)
	hum.parameters_warden_broken()
	_advance(hum, boundary * 4 + 1)
	t.eq("Warden break releases landmark hum", hum.layer_target(layer), 0.0)
	var absent := Music.new()
	absent.set_parameter_source(func(): return {"threat": 1.0})
	absent.schedule_restart(0, Music.PLAY, 0)
	_advance(absent, boundary + 1)
	t.check("no graph has no hum reader or contribution", not absent.parameter_layer_reads.has("approach") and absent.layer_target(layer) == 0.0 and absent.layer_starts[layer] == 0)
	input = {"threat": 0.0, "approach": 1.0}
	hum.parameters_stage_entered()
	_advance(hum, boundary * 5 + 1)
	t.check("absent armour has no reader and permits landmark hum", not hum.parameter_layer_reads.has("armour") and hum.layer_target(layer) == 1.0)
	input = {"threat": 0.0}
	_advance(hum, boundary * 6 + 1)
	t.check("graph removal clears hum contribution and reader", not hum.parameter_layer_reads.has("approach") and hum.layer_target(layer) == 0.0)
