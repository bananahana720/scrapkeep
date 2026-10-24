# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Music := preload("res://src/presentation/music_engine.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

var t := T.new("music_params_ace_game_test")

class ThreatEnemy extends Node3D:
	func is_dead() -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Without the gitignored Oggs (a cloud checkout), the stub stem tree stands in so the ACE
	# parameter path still runs.
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
		print("ACE stems: stub tone tree (no Oggs in this checkout)")
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
	audio._flush_flow()
	var engine = audio.engine
	if not Rows.pack_on_disk(audio.ace_manifest):
		t.check("absent ACE stems retain audible synth fallback", not audio.ace_playing() and not engine.band_muted)
		_pump_to(audio, engine.clock + Harmony.BAR)
		t.check("fallback pump produces music", Array(audio.out_music).any(func(v): return v.length_squared() > 0.0))
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	t.check("existing ACE stems perform in real Game", audio.ace_playing())
	_crossfade_fixture(audio.ace_manifest)
	_ultimate_section_fixture(audio.ace_manifest)
	_warden_state_fixture(audio.ace_manifest)
	_warden_state_fixture(audio.ace_manifest, true)
	var ace = audio.ace
	_pump_to(audio, engine.clock + Harmony.BAR * 2)
	t.eq("source-enabled restart aligns step and phrase origins", engine.grid_origin, engine.bar_origin)
	t.check("normal pump hands over and mutes synth", engine.band_muted and ace.active())
	t.check("normal handover produces ACE PCM", Array(audio.out_music).any(func(v): return v.length_squared() > 0.0))
	var before := _other_target(ace)
	var step_origin: int = engine.grid_origin + ceili(float(engine.bar_origin - engine.grid_origin) / engine.step_len) * engine.step_len
	var lift_boundary: int = step_origin + (floori(float(engine.clock - step_origin) / engine.bar_len()) + 1) * engine.bar_len()
	audio._set_ult_lift(true)
	_pump_to(audio, lift_boundary - 4096)
	t.eq("performing ACE ultimate waits for next bar", _other_target(ace), before)
	_pump_to(audio, lift_boundary + 4096)
	t.near("performing ACE ultimate adds existing pressure step at next bar", _other_target(ace), _profile_other(ace) * Ace.ULTIMATE_STEP)
	t.check("performing ACE ultimate logs its next-bar commit", ace.parameter_layer_log.back().ultimate and ace.parameter_layer_log.back().at == lift_boundary)
	audio._set_ult_lift(false)
	_pump_to(audio, lift_boundary + engine.bar_len() + 4096)
	t.near("performing ACE spent meter releases at next bar", _other_target(ace), before)
	var enemy := ThreatEnemy.new()
	root.add_child(enemy)
	enemy.add_to_group("enemy")
	enemy.global_position = game.player.ball_position() + game.ctx.aim_forward() * 0.1
	var phrase: int = engine.bar_len() * Harmony.PHRASE_BARS
	# A same-tempo restart can reset the phrase between steps without moving the step grid.
	var origin: int = engine.grid_origin + ceili(float(engine.bar_origin - engine.grid_origin) / engine.step_len) * engine.step_len
	var boundary: int = origin + (floori(float(engine.clock - origin) / phrase) + 1) * phrase
	_pump_to(audio, boundary - 8192)
	t.near("ACE threat waits for phrase", _other_target(ace), before)
	audio._on_pressure(0.0)
	_pump_to(audio, boundary + 8192)
	var expected: float = 1.0 - 0.1 / audio.parameter_threat_range
	t.near("sampled threat reaches performing ACE band", ace.pressure, expected, 0.0001)
	t.check("audible ACE layer opens after threat", _other_target(ace) > before)
	if not t.check("performing ACE band records committed parameters", ace.get("parameter_layer_log") is Array):
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	var change: Dictionary = ace.parameter_layer_log.back()
	t.eq("audible ACE threat change commits on phrase", int(change.at), boundary)
	t.near("ACE other stem keeps profile level at sampled gain", _other_target(ace), _profile_other(ace) * expected, 0.0001)
	t.check("ACE committed change reaches actual gain and PCM", ace.voices.any(func(v): return v.stem == "other" and v.gain > 0.0) and Array(audio.out_music).any(func(v): return v.length_squared() > 0.0))
	ace.solo = ["other"]
	var other_peak := 0.0
	var other_end: int = boundary + engine.bar_len() * 2
	while engine.clock < other_end:
		audio._pump(mini(4096, other_end - engine.clock))
		for sample in audio.out_music:
			other_peak = maxf(other_peak, sample.length_squared())
	t.check("isolated performing ACE other stem has audible PCM", engine.band_muted and other_peak > 0.0, str(other_peak))
	ace.solo = []
	var graph = audio._parameter_graph
	game.player.reset_to(graph.position(graph.beacon_node))
	enemy.global_position = game.player.ball_position() + game.ctx.aim_forward() * 0.1
	_pump_to(audio, boundary + phrase + 8192)
	# Full approach is the dam's reach: its landmark tune replaces the stage pack.
	t.check("committed approach swaps in the landmark package on the transport clock", audio.ace != ace and audio._ace_from.contains("landmark_spillway_dam") and audio.ace.clock == engine.clock)
	ace = audio.ace
	t.eq("ACE approach uses committed graph feed", float(ace.parameters.get("approach", -1.0)), 1.0)
	t.check("record-selected landmark hum survives handover", engine.band_muted and engine.landmark_hum_sound == String(EventKinds.world_row("landmark_hum").sound) and Array(engine.out_landmark).any(func(v): return v.length_squared() > 0.0))
	t.check("audible handover mix includes landmark hum", _hum_in_mix(audio))
	var hum_voices: Array = engine._voices.filter(func(v): return v.layer == engine.LANDMARK_HUM)
	engine._voices = [hum_voices.back()]
	engine.solo = [engine.LANDMARK_HUM]
	engine._lp.fill(0.0)
	engine._lp_on = false
	audio._unmute_band()
	audio._render_music(4096, true)
	t.check("handback ramp preserves audible landmark hum", _hum_in_mix(audio))
	engine.solo = []
	audio._hand_over_band()
	game.run.mass = 20.0
	_pump_to(audio, boundary + phrase * 2 - 8192)
	t.check("ACE armour waits for phrase", _other_target(ace) > 0.0)
	# Drums ride rolling speed (the frozen ball's is 0), so armour is judged by what it moves.
	var kit := _targets(ace, ["drums", "bass"])
	_pump_to(audio, boundary + phrase * 2 + 8192)
	t.eq("low armour strips ACE other stem", _other_target(ace), 0.0)
	t.check("low armour retains recorded drums and bass", _targets(ace, ["drums", "bass"]) == kit and kit[1].all(func(g): return g > 0.0), str(kit))
	t.eq("low armour releases audible landmark hum", engine.layer_target(engine.LANDMARK_HUM), 0.0)
	game.run.mass = 100.0
	_pump_to(audio, boundary + phrase * 3 + 8192)
	t.check("regained armour restores ACE other stem", _other_target(ace) > 0.0)
	game.run.mass = 20.0
	_pump_to(audio, boundary + phrase * 4 + 8192)
	game.run.mass = 100.0
	_pump_to(audio, boundary + phrase * 4 + engine.bar_len())
	var danger_at: int = engine.clock
	engine.parameter_danger("drop_industrial")
	_pump_to(audio, danger_at + 8192)
	t.check("danger admits sampled regained armour immediately in ACE", _other_target(ace) > 0.0 and ace.parameter_layer_log.back().at == danger_at and Rows.danger(ace.parameter_layer_log.back().danger))
	game.flow._unseal()
	audio._flush_flow()
	_pump_to(audio, boundary + phrase * 5 + 8192)
	t.eq("scripted Warden break releases performing ACE within phrase", _other_target(ace), 0.0)
	t.eq("Warden release clears audible landmark hum", engine.layer_target(engine.LANDMARK_HUM), 0.0)
	game.flow.enter_stage(3, Vector3.ZERO, false)
	audio._flush_flow()
	var replacement = audio.ace
	var fresh: Array = replacement.pending.get("voices", replacement.voices)
	t.check("replacement ACE package starts from committed release", replacement != ace and fresh.any(func(v): return v.stem == "other") and fresh.filter(func(v): return v.stem == "other").all(func(v): return v.target == 0.0))
	var file := FileAccess.open("user://ke10-ace-commits.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": "scrapkeep-ace-parameters/1", "commits": ace.parameter_layer_log, "samples": engine.parameter_sample_log, "band_muted": engine.band_muted, "isolated_other_peak": other_peak, "misses": ace.misses, "short_reads": ace.short_reads}))
	file.close()
	t.check("ACE recorded parameter commits obey chosen boundaries", ace.parameter_layer_log.all(func(c): return c.timing.is_empty() or (c.timing.phrase and c.timing.phrase_step % (Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS) == 0) or Rows.danger(c.danger) or (c.ultimate and c.timing.phrase_step % Harmony.STEPS_PER_BAR == 0)))
	print("KE10_ACE_TRACE ", ProjectSettings.globalize_path("user://ke10-ace-commits.json"))
	enemy.free()
	game.queue_free()
	await process_frame
	quit(t.verdict())

func _pump_to(audio, until: int) -> void:
	while audio.engine.clock < until:
		var n := mini(4096, until - audio.engine.clock)
		audio._pump(n)

func _other_target(ace) -> float:
	for voice in ace.voices:
		if voice.stem == "other":
			return voice.target
	return -1.0

func _targets(ace, stems: Array) -> Array:
	return stems.map(func(stem): return ace.voices.filter(func(v): return v.stem == stem).map(func(v): return v.target))


func _profile_other(ace) -> float:
	var row: Dictionary = ace.manifest.profiles[ace.sections[ace.section].profile].other
	return db_to_linear(float(row.volume_db))

func _hum_in_mix(audio) -> bool:
	for i in audio.out_music.size():
		if (audio.out_music[i] - audio.ace.out[i] - audio.engine.out_landmark[i]).length_squared() > 0.00000001:
			return false
	return true


func _crossfade_fixture(manifest_path: String) -> void:
	var transport := Music.new()
	var seq := Ace.new(manifest_path)
	var feed := {"threat": 0.1, "armour": 1.0}
	transport.set_parameter_source(func(): return feed.duplicate())
	transport.parameter_commit.connect(func(at, values, released, lift, reason):
		seq.commit_parameters(at, values, released, lift, reason))
	seq.parameter_enabled = true
	seq.parameters = feed.duplicate()
	seq.start_level(0)
	transport.schedule_restart(0, Music.PLAY, 0)
	_pair_to(transport, seq, Harmony.BAR + 1)
	for incoming in ["travel", "calm"]:
		var outgoing: String = seq.section
		var old: Array = seq.voices.duplicate()
		var starts := old.map(func(v): return v.gain)
		var boundary: int = (floori(float(transport.clock) / (Harmony.BAR * Harmony.PHRASE_BARS)) + 1) * Harmony.BAR * Harmony.PHRASE_BARS
		feed.threat = 0.7 if incoming == "travel" else 0.1
		var ms: float = seq.manifest.join_ms
		var breath_row: Dictionary = seq.manifest.breath[seq.breath]
		if seq.sections[incoming].profile == "breath":
			ms = maxf(ms, float(breath_row.ramp_in_ms))
		if seq.sections[outgoing].profile == "breath":
			ms = maxf(ms, float(breath_row.ramp_out_ms))
		var duration: int = mini(maxi(1, roundi(ms * Harmony.RATE / 1000.0)), int(seq.manifest.pre_roll))
		t.check("manifest gives nonzero join " + incoming, duration > 1)
		_pair_to(transport, seq, boundary)
		t.eq("join applies no pending threat before phrase " + incoming, seq.pressure, 0.1 if incoming == "travel" else 0.7)
		t.check("old voices stay at full committed gains before phrase " + incoming, old.all(func(v): return v.gain == starts[old.find(v)]))
		for elapsed in [1, floori(duration / 2.0), duration]:
			_pair_to(transport, seq, boundary + elapsed)
			t.eq("section enters on authorized phrase " + incoming, seq.events_log.filter(func(e): return e[0] == "enter").back()[1], boundary)
			for i in old.size():
				var v = old[i]
				t.near("outgoing join %s %s at %d" % [outgoing, v.stem, elapsed], v.gain, float(starts[i]) * (1.0 - float(elapsed) / duration))
			for v in seq.voices:
				var row: Dictionary = seq.manifest.profiles[seq.sections[incoming].profile][v.stem]
				var target: float = db_to_linear(float(row.volume_db)) * (float(feed.threat) if v.stem == "other" else 1.0)
				t.near("incoming join %s %s at %d" % [incoming, v.stem, elapsed], v.gain, target * float(elapsed) / duration)
		t.check("completed join removes outgoing voices " + incoming, old.all(func(v): return not seq.fading.has(v)))


func _ultimate_section_fixture(manifest_path: String) -> void:
	var transport := Music.new()
	var seq := Ace.new(manifest_path)
	var committed := {"threat": 0.0, "approach": 0.0, "armour": 1.0}
	var feed := committed.duplicate()
	transport.set_parameter_source(func(): return feed.duplicate())
	transport.parameter_commit.connect(func(at, values, released, lift, reason):
		seq.commit_parameters(at, values, released, lift, reason))
	seq.parameter_enabled = true
	seq.parameters = committed.duplicate()
	seq.start_level(0)
	transport.schedule_restart(0, Music.PLAY, 0)
	_pair_to(transport, seq, Harmony.BAR + 1)
	t.eq("ultimate section fixture starts calm at zero threat", seq.section, "calm")
	t.check("ultimate section fixture has no hold or protected pending entry", seq.hold_until <= seq.clock and seq.pending.is_empty())
	t.check("ultimate step crosses travel up at rest", Ace.ULTIMATE_STEP >= Ace.TRAVEL_UP)
	t.check("spent rest pressure crosses travel down", float(committed.threat) < Ace.TRAVEL_DOWN)
	feed.threat = Ace.TRAVEL_UP + Ace.TRAVEL_DOWN
	feed.approach = 1.0
	feed.armour = 0.2
	for lifted in [true, false]:
		var effective: float = committed.threat + (Ace.ULTIMATE_STEP if lifted else 0.0)
		var incoming := "travel" if effective >= Ace.TRAVEL_UP else "calm"
		var outgoing: String = seq.section
		var old: Array = seq.voices.duplicate()
		var starts := old.map(func(v): return v.gain)
		var boundary: int = (floori(float(transport.clock) / Harmony.BAR) + 1) * Harmony.BAR
		var ms: float = seq.manifest.join_ms
		var breath_row: Dictionary = seq.manifest.breath[seq.breath]
		if seq.sections[incoming].profile == "breath":
			ms = maxf(ms, float(breath_row.ramp_in_ms))
		if seq.sections[outgoing].profile == "breath":
			ms = maxf(ms, float(breath_row.ramp_out_ms))
		var duration: int = mini(maxi(1, roundi(ms * Harmony.RATE / 1000.0)), int(seq.manifest.pre_roll))
		transport.set_ultimate_lift(lifted)
		_pair_to(transport, seq, boundary)
		t.eq("ultimate section waits until next bar " + incoming, seq.section, outgoing)
		t.eq("ultimate join keeps outgoing gains before bar " + incoming, old.map(func(v): return v.gain), starts)
		for elapsed in [1, floori(duration / 2.0), duration]:
			_pair_to(transport, seq, boundary + elapsed)
			t.eq("ultimate selects section at next bar " + incoming, seq.section, incoming)
			var entries: Array = seq.events_log.filter(func(e): return e[0] == "enter" and e[2] == incoming)
			t.check("ultimate section entry timestamp " + incoming, not entries.is_empty() and entries.back()[1] == boundary)
			t.eq("ultimate section uses manifest grid " + incoming, seq.grid_bar, int(seq.manifest.clips[seq.sections[incoming].clip].bar))
			t.eq("ultimate commits no pending threat approach armour " + incoming, seq.parameters, committed)
			t.near("ultimate retains committed threat " + incoming, seq.pressure, float(committed.threat))
			for i in old.size():
				var v = old[i]
				t.near("ultimate outgoing join %s %s at %d" % [outgoing, v.stem, elapsed], v.gain, float(starts[i]) * (1.0 - float(elapsed) / duration))
			for v in seq.voices:
				var row: Dictionary = seq.manifest.profiles[seq.sections[incoming].profile][v.stem]
				var target := db_to_linear(float(row.volume_db)) * (clampf(effective, 0.0, 1.0) if v.stem == "other" else 1.0)
				t.near("ultimate incoming join %s %s at %d" % [incoming, v.stem, elapsed], v.gain, target * float(elapsed) / duration)
		t.check("ultimate completed join removes outgoing voices " + incoming, old.all(func(v): return not seq.fading.has(v)))
		t.check("ultimate transition logs authorized bar " + incoming, seq.parameter_layer_log.back().ultimate and seq.parameter_layer_log.back().at == boundary)
	var phrase := Harmony.BAR * Harmony.PHRASE_BARS
	_pair_to(transport, seq, phrase)
	t.eq("pending parameters wait until phrase after ultimate", seq.parameters, committed)
	_pair_to(transport, seq, phrase + 1)
	t.eq("pending parameters commit on their phrase after ultimate", seq.parameters, feed)
	t.eq("pending parameters record phrase boundary after ultimate", seq.parameter_layer_log.back().at, phrase)


func _pair_to(transport, seq, until: int) -> void:
	while transport.clock < until:
		var n := mini(4096, until - transport.clock)
		transport.render(n)
		seq.render(n)


func _warden_state_fixture(manifest_path: String, pending_parameters := false) -> void:
	var seq := Ace.new(manifest_path)
	var committed := {"threat": 0.7, "approach": 0.0, "armour": 1.0}
	seq.parameter_enabled = true
	seq.parameters = committed.duplicate()
	seq.start_boss(0)
	var pivot_at := _manifest_join(seq, "", "pivot")
	var build_at: int = pivot_at + int(seq.manifest.clips.pivot.bar)
	var build_clip: Dictionary = seq.manifest.clips[seq.sections.build.clip]
	var beat: int = build_clip.beat
	var bar: int = build_clip.bar
	_seq_to(seq, build_at + bar + 1234)
	t.eq("source-enabled Warden fixture starts in build", seq.section, "build")
	t.eq("Warden fixture has committed threat", seq.parameters, committed)
	var pending_values := {"threat": 1.0, "approach": 1.0, "armour": 0.2}
	var parameter_at := build_at + bar * Harmony.PHRASE_BARS
	if pending_parameters:
		seq.commit_parameters(parameter_at, pending_values, false, false, "")
		t.check("Warden fixture has a pending parameter commit", seq.actions.any(func(a): return a.type == "parameters"))
	else:
		t.check("Warden fixture has no pending parameter commit", seq.actions.all(func(a): return a.type != "parameters"))
	for state in ["telegraph", "open", "closed"]:
		var incoming: String = "build" if state == "closed" else state
		var outgoing: String = seq.section
		var asked: int = seq.clock
		var duration := _manifest_join(seq, outgoing, incoming)
		var unit: int = beat if seq.manifest.sections[incoming].enter == "beat" else bar
		var boundary: int = build_at + ceili(float(asked + duration - build_at) / unit) * unit
		var old: Array = seq.voices.duplicate()
		var starts := old.map(func(v): return v.gain)
		seq.set_warden_state(state)
		t.eq("Warden state keeps manifest landing " + state, int(seq.pending.get("at", -1)), boundary)
		t.eq("Warden state join ends on its edge " + state, int(seq.pending.get("begin", -1)), boundary - duration)
		_seq_to(seq, boundary - duration)
		t.eq("Warden section waits for its edge " + state, seq.section, outgoing)
		var half := floori(duration / 2.0)
		_seq_to(seq, boundary - duration + half)
		for i in old.size():
			t.near("Warden outgoing join " + state + " " + old[i].stem, old[i].gain, starts[i] * (1.0 - float(half) / duration))
		_seq_to(seq, boundary + 1)
		t.eq("Warden enters on manifest boundary " + state, seq.section, incoming)
		var entries: Array = seq.events_log.filter(func(e): return e[0] == "enter" and e[2] == incoming and e[1] >= asked)
		t.check("Warden entry timestamp " + state, entries.size() == 1 and entries[0][1] == boundary)
		var clip: Dictionary = seq.manifest.clips[seq.sections[incoming].clip]
		var entry: int = clip.entry
		if incoming == "build":
			entry += (int(seq.manifest.sections.build.reenter_bar) - 1) * int(clip.bar)
		else:
			entry += posmod((boundary - build_at) / beat, int(clip.beats_per_bar)) * int(clip.beat)
		t.eq("Warden retains manifest clip entry " + state, seq.voices[0].pos - 1, entry)
		t.eq("Warden state admits no new parameters " + state, seq.parameters, committed)
		_seq_to(seq, boundary + beat + 1234)
	if pending_parameters:
		_seq_to(seq, parameter_at)
		t.eq("Warden pending snapshot waits for phrase", seq.parameters, committed)
		_seq_to(seq, parameter_at + 1)
		t.eq("Warden pending snapshot commits at phrase", seq.parameters, pending_values)
	var held := Ace.new(manifest_path)
	held.parameter_enabled = true
	held.parameters = committed.duplicate()
	held.start_boss(0)
	held.set_warden_state("open")
	t.eq("Warden request preserves protected pivot entry", held.pending.section, "pivot")
	_seq_to(held, pivot_at + 1)
	var hold_end: int = pivot_at + int(held.manifest.sections.pivot.hold_bars) * int(held.manifest.clips.pivot.bar)
	t.eq("Warden pivot hold uses manifest duration", held.hold_until, hold_end)
	held.set_warden_state("telegraph")
	t.eq("Warden request during hold preserves scheduled build", held.pending.section, "build")
	_seq_to(held, hold_end)
	t.eq("Warden protected hold plays through", held.section, "pivot")
	_seq_to(held, hold_end + 1)
	t.eq("Warden hold completes into build", held.section, "build")
	var after_hold: int = build_at + ceili(float(hold_end + _manifest_join(held, "build", "telegraph") - build_at) / beat) * beat
	t.eq("Warden hold completion follows on next manifest beat", int(held.pending.get("at", -1)), after_hold)
	_seq_to(held, after_hold + 1)
	t.eq("Warden held request enters without parameter permission", held.section, "telegraph")
	t.eq("Warden held request keeps committed parameters", held.parameters, committed)


func _manifest_join(seq, outgoing: String, incoming: String) -> int:
	var ms: float = seq.manifest.join_ms
	var breath_row: Dictionary = seq.manifest.breath[seq.breath]
	if seq.manifest.sections[incoming].profile == "breath":
		ms = maxf(ms, float(breath_row.ramp_in_ms))
	if outgoing != "" and seq.manifest.sections[outgoing].profile == "breath":
		ms = maxf(ms, float(breath_row.ramp_out_ms))
	return mini(maxi(1, roundi(ms * Harmony.RATE / 1000.0)), int(seq.manifest.pre_roll))


func _seq_to(seq, until: int) -> void:
	while seq.clock < until:
		seq.render(mini(4096, until - seq.clock))


