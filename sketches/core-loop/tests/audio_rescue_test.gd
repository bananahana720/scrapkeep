extends SceneTree

const Ctx := preload("res://src/core/context.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Flow := preload("res://src/core/flow.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RescueSite := preload("res://src/world/rescue_site.gd")
const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# A finished rescue is heard: RescueSite.complete (once per quest) emits rescue_completed
# and the director plays rescue_fanfare once. The row is no longer a quiet grammar signal.

# Counts the cues the director starts.
class CountingAudio extends "res://src/presentation/audio.gd":
	var started: Array = []

	func _start(_kind: String, sound: String, _stream: AudioStream, _volume: float, _pitch: float, _bus: String) -> void:
		started.append(sound)

var _t := T.new("audio_rescue_test")


func _initialize() -> void:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Ctx.new()
	ctx.events = events
	ctx.run = RunState.new(events)
	ctx.tuning = Tuning.new()
	ctx.stages = StageDefs
	ctx.flow = Flow.new()
	var audio := CountingAudio.new()
	root.add_child(audio)
	audio.setup(ctx)
	audio.sound_ready = true
	var site := RescueSite.new()
	root.add_child(site)
	site.setup(ctx, null)
	_t.check("row is not a quiet grammar signal", not EventKinds.GRAMMAR_SIGNALS.has("rescue_completed"), str(EventKinds.GRAMMAR_SIGNALS))
	_t.eq("row names the fanfare", EventKinds.ROWS["rescue_completed"]["sound"], "rescue_fanfare")
	_t.check("row priority is at least 2", int(EventKinds.ROWS["rescue_completed"]["priority"]) >= 2, "")
	var emitted := [0]
	events.rescue_completed.connect(func(_q): emitted[0] += 1)
	site.complete("rivet")
	site.complete("rivet")
	_t.eq("two completions of one quest emit rescue_completed once", emitted[0], 1)
	_t.eq("two completions of one quest request the fanfare once", audio.started.count("rescue_fanfare"), 1)
	audio.free()
	site.free()
	events.free()
	ctx.flow.free()
	quit(_t.verdict())
