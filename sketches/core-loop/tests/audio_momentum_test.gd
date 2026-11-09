# smoke: solo timeout=180s
extends SceneTree

const Game := preload("res://src/game.gd")
const Bot := preload("res://tools/bot_driver.gd")
const Ace := preload("res://src/presentation/ace_sequencer.gd")
const Audio := preload("res://src/presentation/audio.gd")
const T := preload("res://tests/support/t.gd")

# The music is a second controller output (INTEGRATION section 2): the drum stem follows
# rolling speed and the lead stem follows the kill chain. A bot run drives the real
# feed, and the same values drive the band's faders.

var t := T.new("audio_momentum_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_fader_table()
	await _bot_run()
	quit(t.verdict())


func _seq() -> Ace:
	var seq := Ace.new("res://assets/music_ace/title/manifest.json")
	seq.parameter_enabled = true
	seq.mode = "level"
	return seq


func _fader_table() -> void:
	var seq := _seq()
	seq.parameters = {"threat": 0.0, "armour": 1.0, "speed": 0.0, "chain": 0.0}
	t.eq("standing still silences the drums", seq.parameter_gain("drums"), 0.0)
	t.eq("standing still leaves the bass", seq.parameter_gain("bass"), 1.0)
	t.eq("no chain leaves the lead at its shelf floor", seq.parameter_gain("other"), Ace.LEAD_FLOOR)
	seq.parameters.speed = Ace.DRUMS_IN_SPEED
	t.eq("drums stay out at a quarter of top speed", seq.parameter_gain("drums"), 0.0)
	seq.parameters.speed = 0.375
	t.near("drums are half in between", seq.parameter_gain("drums"), 0.5, 0.001)
	seq.parameters.speed = Ace.DRUMS_FULL_SPEED
	t.eq("drums are full at half top speed", seq.parameter_gain("drums"), 1.0)
	seq.parameters.chain = Audio.chain_fader(2)
	t.near("the sax hook lifts a third of the way at chain 2", seq.parameter_gain("other"), lerpf(Ace.LEAD_FLOOR, 1.0, 1.0 / 3.0), 0.001)
	seq.parameters.chain = Audio.chain_fader(4)
	t.eq("the lead is full at chain 4", seq.parameter_gain("other"), 1.0)
	seq.parameters.chain = Audio.chain_fader(1)
	t.eq("a chain of one is no chain", seq.parameter_gain("other"), Ace.LEAD_FLOOR)
	seq.parameters.erase("speed")
	t.eq("a feed without speed leaves the drums alone", seq.parameter_gain("drums"), 1.0)
	seq.parameters.speed = 0.0
	seq.mode = "warden"
	t.eq("a boss keeps the full kit at speed zero", seq.parameter_gain("drums"), 1.0)


func _bot_run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	var bot := Bot.new(game, "skipper", 5)
	bot.start()
	var speeds: Array = []
	var matched := true
	var in_range := true
	for frame in 1500:
		bot.tick(1.0 / 60.0)
		await physics_frame
		if frame % 15 != 0:
			continue
		var values: Dictionary = audio.sample_run_parameters()
		if values.is_empty():
			continue
		speeds.append(float(values.speed))
		matched = matched and is_equal_approx(float(values.speed), game.player.speed_fraction())
		in_range = in_range and values.speed >= 0.0 and values.speed <= 1.0 and values.chain >= 0.0 and values.chain <= 1.0
	t.check("the bot run sampled the feed", speeds.size() > 20, str(speeds.size()))
	t.check("the speed value is the ball's own speed fraction", matched)
	t.check("speed and chain stay in range", in_range)
	var lo: float = speeds.min() if not speeds.is_empty() else 0.0
	var hi: float = speeds.max() if not speeds.is_empty() else 0.0
	t.check("the speed value changes during play", hi - lo > 0.15, "min %.3f max %.3f" % [lo, hi])
	# The same samples move the drum fader.
	var seq := _seq()
	seq.parameters = {"threat": 0.0, "speed": lo}
	var slow := seq.parameter_gain("drums")
	seq.parameters = {"threat": 0.0, "speed": hi}
	var fast := seq.parameter_gain("drums")
	t.check("the drum fader follows the sampled speeds", fast > slow, "slow %.3f fast %.3f" % [slow, fast])
	# The chain value follows the player's combo.
	game.player.chain.combo = 1
	var one: float = audio.sample_run_parameters().get("chain", -1.0)
	game.player.chain.combo = 4
	var four: float = audio.sample_run_parameters().get("chain", -1.0)
	t.eq("a chain of one feeds zero", one, 0.0)
	t.eq("a chain of four feeds one", four, 1.0)
	# The engine passes both through its sampler.
	audio.engine._sample_parameters()
	t.check("the engine keeps speed and chain", audio.engine.parameters.has("speed") and audio.engine.parameters.has("chain"))
	print("MOMENTUM speed min=%.3f max=%.3f samples=%d" % [lo, hi, speeds.size()])
	game.queue_free()
	await process_frame
