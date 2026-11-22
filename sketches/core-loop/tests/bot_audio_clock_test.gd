extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("bot_audio_clock_test")
	SimClock.ticks = true
	var audio := Audio.new()
	audio.live_output = false
	audio.engine = Audio.MusicEngine.new()
	audio.engine.bot_skip_samples = true
	root.add_child(audio)
	audio.set_process(false)
	audio._on_ready()
	audio._pump()
	var before: int = audio.engine.clock
	var transport := audio.park_transport(10.0)
	ChildRuns.elapse_wall(40)
	audio._pump()
	t.eq("wall time between pumps cannot advance a bot's music clock", audio.engine.clock, before)
	t.eq("wall time cannot change a park event's downbeat", audio.park_transport(10.0), transport)
	await physics_frame
	audio._pump()
	t.check("a physics tick advances the bot's music clock", audio.engine.clock > before)
	before = audio.engine.clock
	ChildRuns.elapse_wall(40)
	audio._pump()
	t.eq("a second pump in the same physics tick spends no samples", audio.engine.clock, before)
	audio.free()
	SimClock.ticks = false
	audio = Audio.new()
	audio.live_output = false
	audio.engine = Audio.MusicEngine.new()
	audio.engine.bot_skip_samples = true
	root.add_child(audio)
	audio.set_process(false)
	audio._on_ready()
	before = audio.engine.clock
	ChildRuns.elapse_wall(40)
	audio._pump()
	t.check("ordinary headless audio still advances with wall time", audio.engine.clock > before)
	audio.free()
	quit(t.verdict())
