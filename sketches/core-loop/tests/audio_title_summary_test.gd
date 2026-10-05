extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const Audio := preload("res://src/presentation/audio.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

# Wave 13 title and summary music: the title plays its own theme over the IDLE bed and
# keeps it through class select; the summary has a won variant with the victory line
# and a quieter lost one on the DEAD bed. Engine state after the bus fires, stepped in
# fixed sample blocks, never wall time.

class FakeCtx:
	extends RefCounted
	var events: Node
	var player = null
	var run = RefCounted.new()
	var flow = null
	var spawner = null
	var calm = false

var t


func _initialize() -> void:
	t = T.new("audio_title_summary_test")
	var first := _title_then_won()
	_lost_then_stage()
	var second := _title_then_won()
	t.check("two runs with the same inputs log the same events", first == second,
		"%d and %d events" % [first.size(), second.size()])
	quit(t.verdict())


# A bare Audio node on its own bus, sound marked ready without a bake. Not added to the
# tree: the test flushes the flow queue itself.
func _rig() -> Dictionary:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	audio.sound_ready = true
	var engine: MusicEngine = audio.engine
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.render(1)
	return {"events": events, "engine": engine, "audio": audio}


func _step(audio, bars: int) -> void:
	audio._flush_flow()
	for i in bars * 4:
		audio.engine.render(Harmony.BEAT)


func _menu_logs(engine: MusicEngine, name: String) -> int:
	return engine.events_log.filter(func(e: Array): return e[0] == "menu" and e[2] == name).size()


func _title_then_won() -> Array:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	var audio = rig["audio"]
	events.flow_changed.emit("title")
	_step(audio, 2)
	t.check("title plays its own track in IDLE", engine.track == "title" and engine.mode == MusicEngine.IDLE
		and engine.layer_target(MusicEngine.LEAD) > 0.0 and engine.layer_target(MusicEngine.KICK) == 0.0,
		"track %s mode %d lead %.2f kick %.2f" % [engine.track, engine.mode, engine.layer_target(MusicEngine.LEAD), engine.layer_target(MusicEngine.KICK)])
	events.flow_changed.emit("class_select")
	_step(audio, 2)
	t.check("class select keeps the title phrase", _menu_logs(engine, "title") == 1 and engine.track == "title",
		"%d title menu logs, track %s" % [_menu_logs(engine, "title"), engine.track])
	events.run_ended.emit(true)
	_step(audio, 6)
	t.check("a won run ends on the won summary with its lead",
		engine.track == "summary" and engine.section == "won" and engine.layer_target(MusicEngine.LEAD) > 0.0,
		"track %s:%s lead %.2f" % [engine.track, engine.section, engine.layer_target(MusicEngine.LEAD)])
	var log: Array = engine.events_log.duplicate(true)
	(audio as Node).free()
	(events as Node).free()
	return log


func _lost_then_stage() -> void:
	var rig := _rig()
	var events = rig["events"]
	var engine: MusicEngine = rig["engine"]
	var audio = rig["audio"]
	events.run_ended.emit(false)
	_step(audio, 2)
	t.check("a lost run ends on the quiet lost summary", engine.track == "summary" and engine.section == "lost"
		and engine.layer_target(MusicEngine.LEAD) == 0.0 and engine.layer_target(MusicEngine.KICK) == 0.0
		and engine.layer_target(MusicEngine.KEYS) > 0.0,
		"track %s:%s lead %.2f kick %.2f keys %.2f" % [engine.track, engine.section, engine.layer_target(MusicEngine.LEAD),
			engine.layer_target(MusicEngine.KICK), engine.layer_target(MusicEngine.KEYS)])
	events.stage_entered.emit(1, false)
	_step(audio, 2)
	t.check("a stage start leaves the menu track", engine.track == "level" and engine.mode == MusicEngine.PLAY,
		"track %s mode %d" % [engine.track, engine.mode])
	(audio as Node).free()
	(events as Node).free()
