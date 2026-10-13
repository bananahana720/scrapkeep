# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_ace_game_test")

class ThreatEnemy extends Node3D:
	func is_dead() -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
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
	var present: bool = Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg"))
	if not present:
		t.check("absent ACE stems retain audible synth fallback", not audio.ace_playing() and not engine.band_muted)
		_pump_to(audio, engine.clock + Harmony.BAR)
		t.check("fallback pump produces music", Array(audio.out_music).any(func(v): return v.length_squared() > 0.0))
		game.queue_free()
		await process_frame
		quit(t.verdict())
		return
	t.check("existing ACE stems perform in real Game", audio.ace_playing())
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
	t.near("performing ACE ultimate adds existing pressure step at next bar", _other_target(ace), _profile_other(ace) * 0.4)
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
	var expected := 1.0 - 0.1 / 48.0
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
	var graph = audio._parameter_graph
	game.player.reset_to(graph.position(graph.beacon_node))
	enemy.global_position = game.player.ball_position() + game.ctx.aim_forward() * 0.1
	_pump_to(audio, boundary + phrase + 8192)
	t.eq("ACE approach uses committed graph feed", float(ace.parameters.get("approach", -1.0)), 1.0)
	t.check("record-selected landmark hum survives handover", engine.band_muted and engine.landmark_hum_sound == String(EventKinds.world_row("landmark_hum").sound) and Array(engine.out_landmark).any(func(v): return v.length_squared() > 0.0))
	t.check("audible handover mix includes landmark hum", _hum_in_mix(audio))
	game.run.mass = 20.0
	_pump_to(audio, boundary + phrase * 2 - 8192)
	t.check("ACE armour waits for phrase", _other_target(ace) > 0.0)
	_pump_to(audio, boundary + phrase * 2 + 8192)
	t.eq("low armour strips ACE other stem", _other_target(ace), 0.0)
	t.check("low armour retains recorded drums and bass", ace.voices.filter(func(v): return v.stem in ["drums", "bass"]).all(func(v): return v.target > 0.0))
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
	file.store_string(JSON.stringify({"schema": "scrapkeep-ace-parameters/1", "commits": ace.parameter_layer_log, "samples": engine.parameter_sample_log, "band_muted": engine.band_muted, "misses": ace.misses, "short_reads": ace.short_reads}))
	file.close()
	t.check("ACE recorded parameter commits obey chosen boundaries", ace.parameter_layer_log.all(func(c): return c.timing.is_empty() or (c.timing.phrase and c.timing.phrase_step % 128 == 0) or Rows.danger(c.danger) or (c.ultimate and c.timing.phrase_step % 16 == 0)))
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

func _profile_other(ace) -> float:
	var row: Dictionary = ace.manifest.profiles[ace.sections[ace.section].profile].other
	return db_to_linear(float(row.volume_db))

func _hum_in_mix(audio) -> bool:
	for i in audio.out_music.size():
		if (audio.out_music[i] - audio.ace.out[i] - audio.engine.out_landmark[i]).length_squared() > 0.00000001:
			return false
	return true
