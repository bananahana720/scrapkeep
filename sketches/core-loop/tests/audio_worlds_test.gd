extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const Ctx := preload("res://src/core/context.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Flow := preload("res://src/core/flow.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# Music comes from the stage row and the world's boss row, not from stage numbers and the
# literal "brindle" (src/presentation/audio.gd), so every row in today's game sounds as it
# did and a later world can name its own. Checked on the director's own picks, no audio
# output needed:
#   - the default table, the slice and the two-world double pick their themes and ACE
#     package from the row;
#   - a row naming an ACE package the module cannot load plays synth and warns once;
#   - a world whose boss row names a track the engine lacks plays Brindle's and warns once;
#   - Brindle's music_state() gives the numbers the reflection gave, at three points of a
#     real fight.

# Counts the warnings the director would push.
class CountingAudio extends "res://src/presentation/audio.gd":
	var warnings: Array = []

	func _emit_music_warning(message: String) -> void:
		warnings.append(message)

var _t := T.new("audio_worlds_test")
var _game
var _started := false
var _made: Array = []


func _initialize() -> void:
	_row_checks()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_fight_checks()
	_game.free()
	for node in _made:
		if is_instance_valid(node):
			node.free()
	quit(_t.verdict())
	return false


func _director(table, stage := 1) -> CountingAudio:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Ctx.new()
	ctx.events = events
	ctx.run = RunState.new(events)
	ctx.run.stage = stage
	ctx.tuning = Tuning.new()
	ctx.stages = table
	ctx.flow = Flow.new()
	_made.append_array([events, ctx.flow])
	var audio := CountingAudio.new()
	root.add_child(audio)
	audio.setup(ctx)
	_made.append(audio)
	return audio


func _row_checks() -> void:
	var picks := func(audio, stages: Array) -> Array:
		return stages.map(func(s: int): return [audio._stage_theme(s), audio._ace_package_for(s)])
	var base := _director(StageDefs)
	_t.eq("W5-1 default table: themes and ACE by stage", picks.call(base, [1, 2, 3]), [[0, "spillway"], [1, ""], [2, ""]])
	var slice := _director(SliceDefs)
	_t.eq("W5-1 slice: stage 1 runs ACE with theme 0", picks.call(slice, [1]), [[0, "spillway"]])
	var two := _director(TwoWorld, 4)
	_t.eq("W5-2 two-world double: stages 4 to 6", picks.call(two, [4, 5, 6]), [[0, "spillway"], [1, ""], [2, ""]])
	_t.eq("W5-2 no warning for known packages and synth rows", base.warnings.size() + two.warnings.size(), 0)

	var odd := _director(StageDefs)
	odd.ctx.stages = _NopeTable.new()
	var first: String = odd._ace_package_for(1)
	var second: String = odd._ace_package_for(2)
	_t.check("W5-3 unknown package plays synth", first == "" and second == "", "got '%s' and '%s'" % [first, second])
	_t.eq("W5-3 one warning for two stages naming the same id", odd.warnings.size(), 1)

	var arena := _director(TwoWorld, 3)
	_t.eq("W5-4 world one's arena starts brindle", arena._boss_track(), "brindle")
	_t.eq("W5-4 no warning for brindle", arena.warnings.size(), 0)
	arena.ctx.run.stage = 6
	arena.ctx.flow.boss_row_override[2] = {"music": "mind", "built": true}
	_t.eq("W5-4 a boss row naming mind plays brindle", arena._boss_track(), "brindle")
	arena._boss_track()
	_t.eq("W5-4 one warning for that id", arena.warnings.size(), 1)


# A stage table whose rows name packages the module does not have.
class _NopeTable extends RefCounted:
	func of(stage: int) -> Dictionary:
		return {"music": {"theme": 0, "ace": "nope"}} if stage <= 2 else {}


func _fight_checks() -> void:
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	_game.flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()
	var boss = _game.boss
	var rules: Dictionary = Audio._boss_rules(boss)
	_t.check("W5-5 the boss has the rules the reflection needs", not rules.is_empty(), "no Rules constants")
	_compare("phase 1 start", boss, rules)
	boss.jump_to_phase(2)
	boss.hp = boss.max_hp * 0.5
	boss.phase_clock = 9.0
	_compare("mid phase 2", boss, rules)
	boss.hp = boss.max_hp * float(rules["PHASE_FLOORS"][1])
	boss.phase_clock = 31.0
	_compare("after a hold", boss, rules)


# The numbers the reflection computed in audio.gd before music_state existed.
func _compare(label: String, boss, rules: Dictionary) -> void:
	var phase := int(Audio._num(boss, "phase", 0.0))
	var floors: Array = rules["PHASE_FLOORS"]
	var mins: Array = rules["PHASE_MIN_SECONDS"]
	var hp: float = Audio._num(boss, "hp", 1.0) / maxf(Audio._num(boss, "max_hp", 1.0), 1.0)
	var top := 1.0 if phase == 1 else float(floors[phase - 2])
	var floor_hp := float(floors[phase - 1])
	var want := {
		"in_phase": clampf((top - hp) / maxf(top - floor_hp, 0.01), 0.0, 1.0),
		"held": hp <= floor_hp + 0.001,
		"phase_seconds": Audio._num(boss, "phase_clock", 0.0) / maxf(float(mins[phase - 1]), 1.0),
	}
	var got: Dictionary = boss.music_state()
	_t.check("W5-5 %s: music_state matches the reflection" % label,
		is_equal_approx(float(got["in_phase"]), float(want["in_phase"])) and got["held"] == want["held"]
		and is_equal_approx(float(got["phase_seconds"]), float(want["phase_seconds"])),
		"got %s, want %s" % [got, want])
