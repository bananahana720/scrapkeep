extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const TuneMoments := preload("res://src/presentation/tune_moments.gd")

# The lead melody stays present (ruling bt). On a level's shelf the recorded band's lead stem
# never falls below about half level; threat, the approach to a landmark and the chain lift it
# from there to full. A Warden break's release strips it through the break's held breath only:
# the kill cadence (the return section) brings it back whole, and it stays back on the shelf
# after it. Low armour still strips it, and a fight's lead is still the fight floor's.
#
# The Oggs are gitignored, so a cloud checkout plays the stub tone tree (tests/support/ace_stub.gd):
# this proves levels and timing, never how it sounds.

var t := T.new("ace_lead_floor_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_table()
	await _through_the_break()
	quit(t.verdict())


func _table() -> void:
	var seq := Ace.new("res://assets/music_ace/title/manifest.json")
	seq.parameter_enabled = true
	seq.mode = "level"
	seq.parameters = {"threat": 0.0, "armour": 1.0, "speed": 0.0, "chain": 0.0}
	t.near("calm roaming keeps the lead at its floor", seq.parameter_gain("other"), Ace.LEAD_FLOOR, 0.001)
	t.check("the floor is about half level", Ace.LEAD_FLOOR >= 0.4 and Ace.LEAD_FLOOR <= 0.6, "%.2f" % Ace.LEAD_FLOOR)
	seq.parameters.chain = Audio.chain_fader(2)
	t.near("a chain of two lifts it a third of the way", seq.parameter_gain("other"), lerpf(Ace.LEAD_FLOOR, 1.0, 1.0 / 3.0), 0.001)
	seq.parameters.chain = Audio.chain_fader(4)
	t.eq("a chain of four is the full lead", seq.parameter_gain("other"), 1.0)
	seq.parameters.chain = 0.0
	seq.pressure = 0.5
	t.near("half threat lifts it halfway", seq.parameter_gain("other"), lerpf(Ace.LEAD_FLOOR, 1.0, 0.5), 0.001)
	seq.pressure = 1.0
	t.eq("full threat is the full lead", seq.parameter_gain("other"), 1.0)
	seq.pressure = 0.0
	seq.parameters.approach = TuneMoments.LANDMARK_IN
	t.eq("a landmark in reach is the full lead", seq.parameter_gain("other"), 1.0)
	seq.parameters.approach = TuneMoments.LANDMARK_IN / 2.0
	t.near("halfway to it lifts the lead halfway", seq.parameter_gain("other"), lerpf(Ace.LEAD_FLOOR, 1.0, 0.5), 0.001)
	seq.parameters.approach = 0.0
	seq.parameters.armour = 0.2
	t.eq("low armour still strips it", seq.parameter_gain("other"), 0.0)
	seq.parameters.armour = 1.0
	seq.mode = "warden"
	t.eq("a calm fight has no shelf floor", seq.parameter_gain("other"), 0.0)
	seq.mode = "piece"
	seq.parameter_released = true
	seq.section = "break"
	t.eq("the break's breath is stripped", seq.parameter_gain("other"), 0.0)
	t.eq("a voice joining for the kill cadence is whole", seq.parameter_gain("other", "return"), 1.0)
	t.eq("and for the walk home", seq.parameter_gain("other", "home"), 1.0)
	seq.parameters.armour = 0.2
	t.eq("low armour strips the cadence too", seq.parameter_gain("other", "return"), 0.0)
	seq.parameters.armour = 1.0
	seq.lead_returned = true
	seq.mode = "level"
	seq.section = "calm"
	t.near("after the cadence the release no longer strips the shelf", seq.parameter_gain("other"), Ace.LEAD_FLOOR, 0.001)


# Through the real game on the Spillway pack: roam, break the Warden, and follow the directed
# piece (break, return, home) back to the shelf.
func _through_the_break() -> void:
	if not Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg")):
		AceStub.install()
		print("ACE stems: stub tone tree (no Oggs in this checkout)")
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	# Full armour: a fresh test run reads under the strip line.
	game.run.mass = 100.0
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	var engine = audio.engine
	if not t.check("the recorded band plays the level", Rows.pack_on_disk(audio.ace_manifest) and audio.ace_playing()):
		game.queue_free()
		await process_frame
		return
	var ace: Ace = audio.ace
	var phrase: int = engine.step_len * Harmony.STEPS_PER_BAR * Harmony.PHRASE_BARS
	_pump(audio, phrase * 2 + 1)
	var shelf := _lead(ace)
	t.check("roaming calm: the lead stem sounds at its floor", ace.mode == "level" and ace.parameter_enabled and absf(ace.parameter_gain("other") - Ace.LEAD_FLOOR) < 0.001 and shelf > 0.0,
		"mode %s, section %s, lead gain %.2f, live lead target %.3f" % [ace.mode, ace.section, ace.parameter_gain("other"), shelf])

	game.flow._unseal()
	audio._flush_flow()
	t.check("the Warden breaks: the directed piece takes the band", ace.mode == "piece", "mode %s" % ace.mode)
	var entered_break := _pump_until(audio, func() -> bool: return ace.section == "break" and ace.parameter_released, phrase * 3)
	t.check("the break's held breath strips the lead", entered_break and ace.parameter_gain("other") == 0.0 and _lead(ace) == 0.0,
		"section %s, released %s, lead gain %.2f, live lead target %.3f" % [ace.section, ace.parameter_released, ace.parameter_gain("other"), _lead(ace)])
	var entered_return := _pump_until(audio, func() -> bool: return ace.section == "return", phrase * 4)
	t.check("the kill cadence brings the lead back whole", entered_return and ace.parameter_released and ace.lead_returned and ace.parameter_gain("other") == 1.0 and _lead(ace) > shelf,
		"section %s, released %s, returned %s, lead gain %.2f, live lead target %.3f (shelf %.3f)" % [ace.section, ace.parameter_released, ace.lead_returned, ace.parameter_gain("other"), _lead(ace), shelf])
	var entered_home := _pump_until(audio, func() -> bool: return ace.section == "home", phrase * 4)
	t.check("the walk home keeps it whole", entered_home and ace.parameter_gain("other") == 1.0 and _lead(ace) > shelf,
		"section %s, lead gain %.2f, live lead target %.3f" % [ace.section, ace.parameter_gain("other"), _lead(ace)])
	var back := _pump_until(audio, func() -> bool: return ace.mode == "level" and ace.section in ["calm", "travel"], phrase * 6)
	t.check("back on the shelf the lead stays, the release still set", back and ace.parameter_released and ace.parameter_gain("other") >= Ace.LEAD_FLOOR - 0.001 and _lead(ace) > 0.0,
		"mode %s, section %s, released %s, lead gain %.2f, live lead target %.3f" % [ace.mode, ace.section, ace.parameter_released, ace.parameter_gain("other"), _lead(ace)])
	game.queue_free()
	await process_frame


# The live lead voice's target level, 0.0 when none sounds.
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
