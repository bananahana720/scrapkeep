extends SceneTree

const TitleStage := preload("res://src/presentation/title_stage.gd")
const Audio := preload("res://src/presentation/audio.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const T := preload("res://tests/support/t.gd")

# W46-09: the title poster (its sun and wordmark) thumps on the bar line the player hears. The stage reads it from
# audio's bar_since_s(): seconds since the last bar line of the sounding grid (the recorded title pack's, about 127 BPM,
# when it plays), INF while no music sounds. The title plays its music in IDLE, not PLAY. Until audio.gd offers the
# call, the poster holds still and the live check is skipped by name.

class Host:
	extends Node
	var audio


# A bar clock the test sets: the sounding grid's seconds since its last bar line.
class BarClock:
	extends RefCounted
	var at := INF

	func bar_since_s() -> float:
		return at


class FakeCtx:
	extends RefCounted
	var events: Node
	var player = null
	var run = RefCounted.new()
	var flow = null
	var spawner = null
	var calm = false

# A recorded title pack's bar at 127.5 BPM, four beats.
const PACK_BAR := 4.0 * 60.0 / 127.5
const FRAME := 1.0 / 60.0

var _t


func _initialize() -> void:
	_t = T.new("title_thump_test")
	# Reduced motion is process-wide and a test earlier in the warm batch may leave it on.
	HighdraftFx.preferred = false
	var host := Host.new()
	var stage = TitleStage.new()
	host.add_child(stage)
	stage.active = true
	stage._flow_state = "title"
	_without_the_call(host, stage)
	_on_the_bar(host, stage)
	_live_idle(host, stage)
	host.free()
	quit(_t.verdict())


func _without_the_call(host: Host, stage) -> void:
	host.audio = null
	_t.eq("no audio, no thump", stage.thump(), 0.0)
	host.audio = RefCounted.new()
	_t.eq("an audio without bar_since_s holds the poster still", stage.thump(), 0.0)


# One bar of frames through a 127.5 BPM grid: the thump rises on the bar line and is gone by mid-bar.
func _on_the_bar(host: Host, stage) -> void:
	var clock := BarClock.new()
	host.audio = clock
	var peak := 0.0
	var first := INF
	var start := PACK_BAR * 0.5
	var at := start
	while at < start + PACK_BAR:
		clock.at = fmod(at, PACK_BAR)
		var k: float = stage.thump()
		if k > 0.0 and first == INF:
			first = at
		peak = maxf(peak, k)
		at += FRAME
	_t.check("from mid-bar, the thump rises on the next bar line", absf(first - PACK_BAR) < FRAME * 1.5 and peak > 0.8,
		"first %.3f s (bar line %.3f s), peak %.2f" % [first, PACK_BAR, peak])
	clock.at = PACK_BAR * 0.5
	_t.eq("and is gone by mid-bar", stage.thump(), 0.0)
	clock.at = INF
	_t.eq("no music sounding, no thump", stage.thump(), 0.0)
	clock.at = 0.0
	stage._flow_state = "class_select"
	_t.eq("pilot select holds the poster still", stage.thump(), 0.0)
	stage._flow_state = "title"
	HighdraftFx.preferred = true
	_t.eq("reduced motion holds the poster still", stage.thump(), 0.0)
	HighdraftFx.preferred = false
	_t.check("on the bar line, a full thump", stage.thump() > 0.99)


# The real Audio on the title: IDLE, and (once audio.gd offers the call) the poster thumps within one bar.
func _live_idle(host: Host, stage) -> void:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	audio.sound_ready = true
	var engine: MusicEngine = audio.engine
	engine.schedule_restart(0, MusicEngine.PLAY, 0)
	engine.render(1)
	events.flow_changed.emit("title")
	audio._flush_flow()
	engine.render(engine.bar_len() * 2)
	_t.check("the title's music plays in IDLE", engine.mode == MusicEngine.IDLE, "mode %d" % engine.mode)
	host.audio = audio
	if not audio.has_method("bar_since_s"):
		_t.eq("without audio.bar_since_s() the title holds still", stage.thump(), 0.0)
		_t.skip("the live title thumps within one bar in IDLE", "audio.gd has no bar_since_s() yet (the Sound thread's file)")
	else:
		var peak := 0.0
		var block := maxi(1, engine.bar_len() / 64)
		for i in 66:
			engine.render(block)
			peak = maxf(peak, stage.thump())
		_t.check("the live title thumps within one bar in IDLE", peak > 0.5, "peak %.2f" % peak)
	host.audio = null
	audio.free()
	events.free()
