extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")

# W1-43: the recorded band keeps its lead line when a run starts. A Warden's break leaves the
# music engine's release set to the next stage, and a death at low armour leaves the last
# armour reading in the engine's committed values; a new run's first stage must not read either.
# The Oggs are gitignored, so a cloud checkout plays the stub tone tree: this proves levels and
# timing, never how the lead sounds.

var t := T.new("band_lead_run_start_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _run_start_after("break")
	await _run_start_after("low_armour")
	quit(t.verdict())


func _run_start_after(left_behind: String) -> void:
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	game.run.mass = 100.0
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	var engine = audio.engine
	if not t.check("%s: the recorded band plays the level" % left_behind, Rows.pack_on_disk(audio.ace_manifest) and audio.ace_playing()):
		game.queue_free()
		await process_frame
		return
	var ace: Ace = audio.ace
	var phrase: int = engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS
	_pump(audio, phrase * 2 + 1)
	if left_behind == "break":
		game.flow._unseal()
		audio._flush_flow()
		_pump_until(audio, func() -> bool: return ace.section == "return", phrase * 8)
		_pump(audio, phrase * 3)
		t.check("%s: the run before left the engine's release set" % left_behind, engine.parameters_released(), "released %s" % engine.parameters_released())
	else:
		game.run.mass = 5.0
		_pump(audio, phrase * 2 + 1)
		t.check("%s: the run before left a low armour reading" % left_behind, float(engine.parameter_committed_values.get("armour", 1.0)) < 0.3, str(engine.parameter_committed_values))
	game.run.mass = 100.0
	var class_id: String = String(game.run.class_def.id) if game.run.get("class_def") != null else "sable"
	game.ctx.events.run_started.emit(class_id)
	audio._flush_flow()
	var now := ace.parameter_gain("other")
	t.check("%s: the lead's gain is up the moment the new run starts" % left_behind, ace.mode == "level" and now >= Ace.LEAD_FLOOR - 0.001, "mode %s, gain %.2f, released %s, armour %s" % [ace.mode, now, ace.parameter_released, ace.parameters.get("armour")])
	_pump(audio, phrase * 2 + 1)
	t.check("%s: the band is up on the new run's first stage" % left_behind, ace.mode == "level" and ace.parameter_enabled, "mode %s" % ace.mode)
	var gain := ace.parameter_gain("other")
	var live := _lead(ace)
	t.check("%s: the lead layer is up right after a run starts" % left_behind, gain >= Ace.LEAD_FLOOR - 0.001 and live > 0.0,
		"released %s, armour %s, lead gain %.2f, live lead target %.3f" % [ace.parameter_released, ace.parameters.get("armour"), gain, live])
	game.queue_free()
	await process_frame


func _lead(ace: Ace) -> float:
	var level := 0.0
	for v in ace.voices:
		if v.stem == "other":
			level = maxf(level, v.target)
	return level


func _pump(audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _pump_until(audio, done: Callable, limit: int) -> bool:
	var until: int = audio.engine.clock + limit
	while audio.engine.clock < until and not done.call():
		audio._pump(1024)
	return done.call()
