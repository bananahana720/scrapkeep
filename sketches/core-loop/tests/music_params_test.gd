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
	var expected := ceili(float(hitch_end) / (Harmony.BAR / Music.PARAMETER_SAMPLES_PER_BAR))
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
	t.eq("200 ms hitch skips no transport samples", fast_hitch.parameter_sample_count, ceili(float(fast_end) / (fast_bar / Music.PARAMETER_SAMPLES_PER_BAR)))
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
	_candidate_cues_fixture()
	_fleet_fixture(true)
	_fleet_fixture(false)
	for pilot in Harmony.CLASS_MOTIFS:
		_ultimate_fixture(pilot)
		_heft_fixture(pilot)
	_warden_snapshot_fixture()
	_ace_contract_fixture()
	_ace_legacy_ultimate_fixture()
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


func _candidate_cues_fixture() -> void:
	# Candidate afbd8e6 owns these musical records; only danger metadata may change.
	var expected := {
		"drop_collapse": {"family": "natural", "rise": false, "voice": "stage", "notes": [57, 50, 45], "accent": "crash", "trim_sound": "smash_crack"},
		"drop_cave_in": {"family": "natural", "rise": false, "voice": "stage", "notes": [50, 45, 38], "accent": "kick", "trim_sound": "land_thud"},
		"drop_drain": {"family": "natural", "rise": false, "voice": "stage", "notes": [62, 57, 50, 45], "trim_sound": "stage_fade"},
		"drop_impact": {"family": "natural", "rise": false, "voice": "stage", "notes": [38, 50], "accent": "kick", "trim_sound": "slam_boom"},
		"drop_lightning": {"alias": "stinger_lightning"},
		"drop_natural": {"alias": "drop_flood"},
	}
	var alias_records := {
		"stinger_lightning": {"family": "natural", "rise": false, "voice": "stage", "notes": [74, 62, 50], "accent": "crash", "trim_sound": "slam_boom"},
		"drop_flood": {"family": "natural", "rise": false, "voice": "stage", "notes": [50, 62, 57], "accent": "kick", "trim_sound": "slam_boom"},
	}
	for id in expected:
		var raw: Dictionary = Rows.CUES.get(id, {}).duplicate(true)
		raw.erase("danger")
		t.eq("candidate cue fields preserved " + id, raw, expected[id])
		for theme in Rows.STAGE_VOICES.size():
			var resolved: Dictionary = alias_records[expected[id].alias].duplicate(true) if expected[id].has("alias") else expected[id].duplicate(true)
			resolved.voice = Rows.STAGE_VOICES[theme]
			var got := Rows.cue(id, {"theme": theme})
			got.erase("danger")
			t.eq("candidate cue resolves theme %d %s" % [theme, id], got, resolved)
		var engine := Music.new()
		engine.set_parameter_source(func(): return {"threat": 0.0, "approach": 0.0, "armour": 1.0})
		engine.schedule_restart(0, Music.PLAY, 0)
		_advance(engine, Harmony.BAR + 1)
		var at := engine.clock
		var before := engine._targets.duplicate()
		var log_count := engine.parameter_layer_log.size()
		t.eq("candidate cue books " + id, engine.park_cue(id, 0, at), at)
		engine.render(1)
		t.check("candidate cue sounds " + id, engine.park_cue_log.any(func(c): return c.id == id and c.at == at))
		if id == "drop_drain":
			t.check("nonhostile drain keeps default false", not Rows.danger(id))
			t.eq("nonhostile drain keeps phrase targets", engine._targets, before)
		else:
			t.check("hostile candidate land danger " + id, Rows.danger(id))
			t.check("candidate danger opens at cue without phrase " + id, engine.layer_target(Music.LEAD) > before[Music.LEAD]
				and engine.parameter_layer_log.size() > log_count
				and engine.parameter_layer_log.back().at == at
				and engine.parameter_layer_log.back().danger == id
				and not engine.parameter_layer_log.back().phrase)


func _ultimate_fixture(pilot: String) -> void:
	var lift := Music.new()
	input = {"threat": 0.3, "approach": 0.0, "armour": 1.0}
	var committed_threat: float = input.threat
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
	var curve: Array = Music.CURVES[Music.ARP]
	var x := clampf((minf(1.0, committed_threat + Music.HEFT_STEP) - float(curve[1])) / (float(curve[2]) - float(curve[1])), 0.0, 1.0)
	var expected := float(curve[0]) + (1.0 - float(curve[0])) * x * x * (3.0 - 2.0 * x)
	t.near("ultimate rises at next bar " + pilot, lift.layer_target(Music.ARP), expected)
	t.eq("ultimate admits no pending threat " + pilot, lift.layer_target(Music.LEAD), 0.0)
	t.eq("ultimate admits no pending approach " + pilot, lift.layer_target(Music.LANDMARK_HUM), 0.0)
	t.check("ultimate admits no pending armour " + pilot, lift.layer_target(Music.KEYS) > 0.0)
	lift.set_ultimate_lift(false)
	_advance(lift, Harmony.BAR * 3)
	t.near("spent lift waits for next bar " + pilot, lift.layer_target(Music.ARP), expected)
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


func _curve_expected(layer: int, intensity: float) -> float:
	var curve: Array = Music.CURVES[layer]
	var x := clampf((intensity - float(curve[1])) / (float(curve[2]) - float(curve[1])), 0.0, 1.0)
	return float(curve[0]) + (1.0 - float(curve[0])) * x * x * (3.0 - 2.0 * x)


func _heft_fixture(pilot: String) -> void:
	var engine := Music.new()
	var committed := {"threat": 0.3, "approach": 0.0, "armour": 1.0}
	var feed := committed.duplicate()
	engine.set_parameter_source(func(): return feed.duplicate())
	engine.set_class_motif(pilot)
	engine.schedule_restart(0, Music.PLAY, 0)
	_advance(engine, Harmony.BAR + 1)
	feed.threat = 1.0
	feed.approach = 1.0
	feed.armour = 0.2
	for steps in [1, 0]:
		var boundary := (floori(float(engine.clock) / Harmony.BAR) + 1) * Harmony.BAR
		var before := engine._targets.duplicate()
		engine.set_heft_lift(steps)
		_advance(engine, boundary)
		t.eq("heft waits for next bar %s %d" % [pilot, steps], engine._targets, before)
		engine.render(1)
		for layer in [Music.KEYS, Music.ARP, Music.LEAD]:
			var intensity := minf(1.0, float(committed.threat) + Music.HEFT_STEP * steps)
			t.near("heft next-bar gain %s %d layer %d" % [pilot, steps, layer], engine.layer_target(layer), _curve_expected(layer, intensity))
		t.eq("heft admits no pending approach %s %d" % [pilot, steps], engine.layer_target(Music.LANDMARK_HUM), 0.0)
		t.eq("heft retains committed snapshot %s %d" % [pilot, steps], engine.parameter_committed_values, committed)
	_advance(engine, Harmony.BAR * Harmony.PHRASE_BARS)
	t.eq("heft pending snapshot waits for phrase " + pilot, engine.parameter_committed_values, committed)
	engine.render(1)
	t.eq("heft pending snapshot commits on phrase " + pilot, engine.parameter_committed_values, feed)
	t.eq("heft pending armour strips on phrase " + pilot, engine.layer_target(Music.KEYS), 0.0)


func _warden_snapshot_fixture() -> void:
	var engine := Music.new()
	var committed := {"threat": 0.3, "approach": 0.0, "armour": 1.0}
	var feed := committed.duplicate()
	engine.set_parameter_source(func(): return feed.duplicate())
	engine.schedule_restart(0, Music.PLAY, 0)
	engine.render(1)
	engine.force_track("warden", 0, "build", true)
	engine.render(1)
	var origin := engine.bar_origin
	var phrase := origin + engine.bar_len() * Harmony.PHRASE_BARS
	_advance(engine, origin + engine.bar_len() + 1)
	feed.threat = 1.0
	feed.approach = 1.0
	feed.armour = 0.2
	_advance(engine, engine.clock + engine.beat_len())
	var asked := engine.clock
	t.eq("Warden open keeps immediate synth contract", engine.warden_section("open"), asked)
	for layer in [Music.KEYS, Music.ARP, Music.LEAD]:
		t.near("Warden open gains use committed armour layer %d" % layer, engine.layer_target(layer), float(Music.OPEN_GAINS[layer]))
	t.eq("Warden open admits no pending snapshot", engine.parameter_committed_values, committed)
	t.eq("Warden close keeps immediate synth contract", engine.warden_section("build"), asked)
	t.eq("Warden close admits no pending snapshot", engine.parameter_committed_values, committed)
	_advance(engine, phrase)
	t.eq("Warden pending snapshot waits for phrase", engine.parameter_committed_values, committed)
	engine.render(1)
	t.eq("Warden pending snapshot commits on phrase", engine.parameter_committed_values, feed)


# Scheduling uses the shipped manifest in both configurations; PCM is checked by the Game fixture.
func _manifest_scheduler():
	var seq := Ace.new("")
	seq.manifest = JSON.parse_string(FileAccess.get_file_as_string(Rows.ROWS["1-1"].ace_manifest))
	seq.clips = seq.manifest.clips
	seq.sections = seq.manifest.sections
	seq.breath = seq.manifest.breath_default
	seq.stems = []
	seq.parameter_enabled = true
	return seq


func _scheduler_to(seq, until: int) -> void:
	while seq.clock < until:
		seq.render(mini(4096, until - seq.clock))


func _scheduler_join(seq, outgoing: String, incoming: String) -> int:
	var ms: float = seq.manifest.join_ms
	var breath: Dictionary = seq.manifest.breath[seq.breath]
	if seq.manifest.sections[incoming].profile == "breath":
		ms = maxf(ms, float(breath.ramp_in_ms))
	if outgoing != "" and seq.manifest.sections[outgoing].profile == "breath":
		ms = maxf(ms, float(breath.ramp_out_ms))
	return mini(maxi(1, roundi(ms * Harmony.RATE / 1000.0)), int(seq.manifest.pre_roll))


func _ace_contract_fixture() -> void:
	var seq = _manifest_scheduler()
	var committed := {"threat": 0.7, "approach": 0.0, "armour": 1.0}
	var pending_values := {"threat": 1.0, "approach": 1.0, "armour": 0.2}
	seq.parameters = committed.duplicate()
	seq.pressure = committed.threat
	seq.start_boss(0)
	var pivot_at := _scheduler_join(seq, "", "pivot")
	var build_at: int = pivot_at + int(seq.manifest.clips.pivot.bar)
	var clip: Dictionary = seq.manifest.clips[seq.manifest.sections.build.clip]
	_scheduler_to(seq, build_at + int(clip.bar) + 1234)
	var parameter_at: int = build_at + int(clip.bar) * Harmony.PHRASE_BARS
	seq.commit_parameters(parameter_at, pending_values, false, false, "")
	for state in ["telegraph", "open", "closed"]:
		var incoming: String = "build" if state == "closed" else state
		var outgoing: String = seq.section
		var join := _scheduler_join(seq, outgoing, incoming)
		var unit: int = clip.beat if seq.manifest.sections[incoming].enter == "beat" else clip.bar
		var boundary: int = build_at + ceili(float(seq.clock + join - build_at) / unit) * unit
		seq.set_warden_state(state)
		t.eq("manifest scheduler Warden landing " + state, seq.pending.get("at", -1), boundary)
		t.eq("manifest scheduler Warden join " + state, seq.pending.get("begin", -1), boundary - join)
		_scheduler_to(seq, boundary + 1)
		t.eq("manifest scheduler Warden enters " + state, seq.section, incoming)
		t.eq("manifest scheduler Warden retains snapshot " + state, seq.parameters, committed)
		_scheduler_to(seq, boundary + int(clip.beat) + 1234)
	_scheduler_to(seq, parameter_at)
	t.eq("manifest scheduler Warden snapshot waits", seq.parameters, committed)
	_scheduler_to(seq, parameter_at + 1)
	t.eq("manifest scheduler Warden snapshot commits", seq.parameters, pending_values)


func _ace_legacy_ultimate_fixture() -> void:
	var seq = _manifest_scheduler()
	var committed := {"threat": 0.0, "approach": 0.0, "armour": 1.0}
	var pending_values := {"threat": 1.0, "approach": 1.0, "armour": 0.2}
	seq.parameters = committed.duplicate()
	seq.start_level(0)
	_scheduler_to(seq, int(seq.manifest.clips[seq.manifest.sections.calm.clip].bar) + 1234)
	var parameter_at: int = seq.origin + seq.grid_bar * Harmony.PHRASE_BARS
	seq.commit_parameters(parameter_at, pending_values, false, false, "")
	for on in [true, false]:
		var incoming: String = "travel" if on else "calm"
		var join := _scheduler_join(seq, seq.section, incoming)
		var boundary: int = seq.origin + ceili(float(seq.clock + join - seq.origin) / seq.grid_bar) * seq.grid_bar
		seq.set_ultimate_lift(on)
		t.eq("shared ACE ultimate keeps manifest landing " + incoming, seq.pending.get("at", -1), boundary)
		_scheduler_to(seq, boundary + 1)
		t.eq("shared ACE ultimate enters " + incoming, seq.section, incoming)
		t.eq("shared ACE ultimate retains snapshot " + incoming, seq.parameters, committed)
	_scheduler_to(seq, parameter_at)
	t.eq("shared ACE ultimate snapshot waits", seq.parameters, committed)
	_scheduler_to(seq, parameter_at + 1)
	t.eq("shared ACE ultimate snapshot commits", seq.parameters, pending_values)
