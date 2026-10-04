extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Ctx := preload("res://src/core/context.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Flow := preload("res://src/core/flow.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# An earned pilot unlock is heard: achievement_earned plays achievement_chime once, and
# several unlocks in one frame play it once. The row is no longer a quiet grammar signal.

# Counts the cues the director starts.
class CountingAudio extends "res://src/presentation/audio.gd":
	var started: Array = []

	func _start(_kind: String, sound: String, _stream: AudioStream, _volume: float, _pitch: float, _bus: String) -> void:
		started.append(sound)

var _t := T.new("audio_achievement_test")


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
	_t.check("row is not a quiet grammar signal", not EventKinds.GRAMMAR_SIGNALS.has("achievement_earned"), str(EventKinds.GRAMMAR_SIGNALS))
	_t.eq("row names the chime", EventKinds.ROWS["achievement_earned"]["sound"], "achievement_chime")
	_t.check("row priority is at least 1", int(EventKinds.ROWS["achievement_earned"]["priority"]) >= 1, "")
	events.achievement_earned.emit("first_win")
	_t.eq("one emit plays the chime once", audio.started.count("achievement_chime"), 1)
	audio.started.clear()
	audio._last_start.clear()
	events.achievement_earned.emit("first_win")
	events.achievement_earned.emit("first_event")
	events.achievement_earned.emit("full_rack")
	_t.eq("three emits in one frame play it once", audio.started.count("achievement_chime"), 1)
	audio.free()
	events.free()
	ctx.flow.free()
	quit(_t.verdict())
