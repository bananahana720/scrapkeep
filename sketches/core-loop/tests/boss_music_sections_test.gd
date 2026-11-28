extends SceneTree

const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicPrebake := preload("res://src/presentation/music_prebake.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Ctx := preload("res://src/core/context.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Flow := preload("res://src/core/flow.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")

# Independent expectations: key offset above D, then samples per sixteenth.
const EXPECTED := {
	"brindle": [[0, 5128], [1, 5128], [2, 4410], [0, 3846]],
	"waking": [[0, 5128], [0, 4410], [1, 3846], [0, 4410]],
	"mind": [[2, 4410], [1, 5128], [0, 4410], [2, 3846]],
}

class BossDouble extends Node:
	var id := ""
	var phase := 1
	var held := false

	func music_state() -> Dictionary:
		return {"id": id, "phase": phase, "in_phase": 1.0 if held else 0.0,
			"held": held, "phase_seconds": 0.4}


class CountingAudio extends "res://src/presentation/audio.gd":
	var changes := 0

	func _follow_brindle() -> void:
		var before := _boss_phase
		super()
		if _boss_phase != before:
			changes += 1


var _t := T.new("boss_music_sections_test")


func _initialize() -> void:
	MusicPrebake.prepare()
	for track in EXPECTED:
		_engine_checks(track)
		_director_checks(track)
	_brindle_compatibility()
	quit(_t.verdict())


func _land(engine: MusicEngine, at: int) -> bool:
	var asked := engine.clock
	var beat := engine.beat_len()
	var expected := engine.next_beat()
	engine.render(maxi(at - asked, 0) + 64)
	return at == expected and at >= asked and at - asked <= beat and engine.in_drop()


func _section(label: String, engine: MusicEngine, track: String, index: int) -> void:
	var name: String = ["1", "2", "3", "victory"][index]
	_t.eq(label + " track", engine.track, track)
	_t.eq(label + " section", engine.section, name)
	_t.eq(label + " key", engine.key, EXPECTED[track][index][0])
	_t.eq(label + " step", engine.step_len, EXPECTED[track][index][1])


func _engine_checks(track: String) -> void:
	var engine := MusicEngine.new()
	engine.force_track(track, 0, "1", true)
	_section(track + " engine start", engine, track, 0)
	_t.eq(track + " repeated start", engine.set_boss_state(track + ":1"), -1)
	_t.eq(track + " unknown boss", engine.set_boss_state("unknown:2"), -1)
	_t.eq(track + " wrong boss", engine.set_boss_state("mind:2" if track != "mind" else "waking:2"), -1)
	_t.eq(track + " unknown section", engine.set_boss_state(track + ":nope"), -1)
	_t.eq(track + " malformed state", engine.set_boss_state(track + ":2:3"), -1)
	for index in range(1, 4):
		var name: String = ["1", "2", "3", "victory"][index]
		var state := track + ":" + name
		var at := engine.set_boss_state(state)
		_t.eq(state + " repeated before landing", engine.set_boss_state(state), -1)
		_t.check(state + " drop on next beat", _land(engine, at))
		_section(state + " engine", engine, track, index)
		_t.eq(state + " repeated after landing", engine.set_boss_state(state), -1)
	if track != "brindle":
		_t.eq(track + " has no chase", engine.set_boss_state(track + ":chase"), -1)


func _director_checks(track: String) -> void:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Ctx.new()
	ctx.events = events
	ctx.run = RunState.new(events)
	ctx.run.stage = StageDefs.last_of(["brindle", "waking", "mind"].find(track) + 1)
	ctx.tuning = Tuning.new()
	ctx.tuning.set_option("music", "synth")
	ctx.stages = StageDefs
	ctx.flow = Flow.new()
	var boss := BossDouble.new()
	boss.id = track
	ctx.boss = boss
	var audio := CountingAudio.new()
	root.add_child(audio)
	audio.set_process(false)
	# Wire the real director and event handlers without starting device output or ACE.
	audio.ctx = ctx
	audio.engine = MusicEngine.new()
	audio.sound_ready = true
	audio._connect_all(events)
	_t.eq(track + " default table track", audio._boss_track(), track)
	events.boss_arena_entered.emit()
	audio.engine.render(audio.engine.bar_len() * 3 + 64)
	_section(track + " director start", audio.engine, track, 0)
	for phase in range(1, 4):
		boss.phase = phase
		var before := audio.changes
		if track == "brindle" and phase > 1:
			events.boss_phase_changed.emit(phase, "test")
		audio._follow_escalation()
		audio._follow_escalation()
		var want := 1 if track != "brindle" and phase > 1 else 0
		_t.eq("%s phase %d two ticks change once" % [track, phase], audio.changes - before, want)
		var drops := _drops(audio.engine)
		audio.engine.render(audio.engine.beat_len() + 64)
		_t.eq("%s phase %d drop count" % [track, phase], _drops(audio.engine) - drops, 1 if phase > 1 else 0)
		_section("%s director phase %d" % [track, phase], audio.engine, track, phase - 1)
	# A stale query cannot put a later fight phase back into phase 2.
	boss.phase = 2
	audio._follow_escalation()
	audio.engine.render(audio.engine.beat_len() + 64)
	_t.eq(track + " phase never goes back", audio.engine.section, "3")
	events.boss_defeated.emit()
	audio.engine.render(audio.engine.beat_len() + 64)
	_section(track + " director victory", audio.engine, track, 3)
	boss.phase = 1
	events.boss_arena_entered.emit()
	audio.engine.render(audio.engine.beat_len() + 64)
	_t.eq(track + " retry resets director phase", audio._boss_phase, 1)
	_section(track + " retry", audio.engine, track, 0)
	if track != "brindle":
		boss.held = true
		audio._follow_escalation()
		_t.check(track + " held phase builds", audio.engine.building())
	audio.free()
	boss.free()
	ctx.flow.free()
	events.free()


func _drops(engine: MusicEngine) -> int:
	return engine.events_log.filter(func(event: Array): return event[0] == "drop").size()


func _brindle_compatibility() -> void:
	var engine := MusicEngine.new()
	engine.force_track("brindle", 0, "1", true)
	_t.check("Brindle phase 2 legacy entry lands", _land(engine, engine.set_brindle_phase(2)))
	_t.eq("Brindle phase 2 legacy key", engine.key, MusicEngine.BRINDLE_KEY["2"])
	engine.boss_pivot = false
	engine.force_track("brindle", 0, "1", false)
	_land(engine, engine.set_brindle_phase(2))
	_t.eq("Brindle unpivoted phase 2 preserves step", engine.step_len, Harmony.STEP)
	_land(engine, engine.set_brindle_phase(3))
	_t.eq("Brindle phase 3 step", engine.step_len, MusicEngine.PHASE3_STEP)
	_land(engine, engine.set_brindle_phase(4))
	_t.eq("Brindle chase step", engine.step_len, Harmony.STEP)
	_t.eq("Brindle chase key", engine.key, MusicEngine.BRINDLE_KEY["chase"])
