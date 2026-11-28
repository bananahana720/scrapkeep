extends SceneTree

const MusicEngine := preload("res://src/presentation/music_engine.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Ctx := preload("res://src/core/context.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Flow := preload("res://src/core/flow.gd")
const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")

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

# The pending six-zone route: no legacy stage music overrides conceal missing rows.
class SixZones extends RefCounted:
	const COUNT := 6

	static func world_of(stage: int) -> int:
		return (stage - 1) / 2 + 1

	static func local(stage: int) -> int:
		return (stage - 1) % 2 + 1

	static func of(stage: int) -> Dictionary:
		return {"stage": stage, "world": world_of(stage)}


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
	_world_entry_checks()
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
	_t.eq("W5-1 default table: themes and ACE by stage", picks.call(base, [1, 2]), [[0, "spillway"], [1, "cable_reach"]])
	var slice := _director(SliceDefs)
	_t.eq("W5-1 slice: stage 1 runs ACE with theme 0", picks.call(slice, [1]), [[0, "spillway"]])
	var two := _director(TwoWorld, 4)
	_t.eq("W5-2 two-world double: stages 4 to 6", picks.call(two, [4, 5, 6]), [[0, "spillway"], [1, ""], [2, ""]])
	_t.eq("W5-2 no warning for known packages and synth rows", base.warnings.size() + two.warnings.size(), 0)

	var six := _director(SixZones)
	var route: Array = range(1, SixZones.COUNT + 1)
	_t.eq("six-zone route resolves every zone", picks.call(six, route), [[0, "spillway"], [1, "cable_reach"], [1, "dig_upper"], [1, "dig_deep"], [2, "highdraft"], [2, "highdraft_crown"]])
	_t.eq("six-zone route has no missing music warnings", six.warnings.size(), 0)

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
	for track in ["waking", "mind"]:
		arena.ctx.flow.boss_row_override[2] = {"music": track, "built": false}
		_t.eq("stub boss has no Brindle fallback " + track, arena._boss_track(), track)
		arena._boss_track()
		_t.eq("stub boss resolves without warning " + track, arena.warnings.size(), 0)
		var band := MusicEngine.new()
		band.force_track(track, 0, "1")
		_t.eq("variant keeps boss id " + track, band.track, track)
		_t.eq("variant reuses Brindle score " + track, band._progression(), MusicEngine.Harmony.BRINDLE)
		_t.eq("variant lead timbre " + track, band._lead_voice, "mallet" if track == "waking" else "talk")
		_t.check("variant phase resolves " + track, band.brindle_section("2") >= 0)
		if arena.sound_ready:
			arena.ctx.events.boss_arena_entered.emit()
			_t.eq("stub arena starts its own track " + track, arena.engine.track, track)
		else:
			print("[audio] sound is not ready headless; the arena start check -> SKIP")
	arena.ctx.flow.boss_row_override[2] = {"music": "genuinely_missing_track", "built": false}
	_t.eq("missing boss track plays Brindle", arena._boss_track(), "brindle")
	arena._boss_track()
	_t.eq("missing boss track warns once", arena.warnings.size(), 1)



# Crossing into a world plays its stinger on the beat, pitched by the bank's step table:
# one request per emit, a distinct sound per world, in the lane after the run's stinger
# and before the stage's, and still on a launch whose landing replaces the stage hit.
func _world_entry_checks() -> void:
	var row: Dictionary = EventKinds.ROWS["world_entered"]
	_t.eq("world row names the world stinger", row["sound"], SfxBank.WORLD_STINGER)
	_t.eq("world row priority", int(row["priority"]), 3)
	_t.check("world row is not a quiet grammar signal", not EventKinds.GRAMMAR_SIGNALS.has("world_entered"), str(EventKinds.GRAMMAR_SIGNALS))
	var audio := _director(StageDefs)
	audio.sound_ready = true
	var events = audio.ctx.events
	var asked := func() -> Array:
		return audio.cue_log.filter(func(cue: Array): return cue[0] == "world_entered")
	var counts: Array = []
	for world in [1, 2, 3]:
		events.world_entered.emit(world)
		audio._flush_flow()
		audio._flush_flow()
		counts.append(asked.call().size())
	var cues: Array = asked.call()
	_t.eq("one world request per emit", counts, [1, 2, 3])
	var sounds := {}
	for cue in cues:
		sounds[cue[1]] = true
	_t.eq("three distinct world requests", sounds.size(), 3)
	_t.check("world requests are on a beat", cues.all(func(cue: Array): return cue[2] == "beat" and int(cue[3]) >= 0), str(cues))
	_t.eq("world one requests the row sound", cues[0][1], row["sound"])
	_t.check("every world sound is a baked grid stinger", sounds.keys().all(func(id: String): return SfxBank.has_recipe(id) and SfxBank.STINGER_BEATS.has(id)), str(sounds.keys()))

	var starts := func(kind: String) -> Array:
		return audio.cue_log.filter(func(cue: Array): return cue[0] == kind and cue[2] == "beat").map(func(cue: Array): return int(cue[3]))
	audio.cue_log.clear()
	events.run_started.emit("sable")
	events.world_entered.emit(1)
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	var run: Array = starts.call("run_started")
	var at: Array = starts.call("world_entered")
	_t.check("run start: world stinger after the run's", run.size() == 1 and at.size() == 1 and at[0] > run[0], "run %s, world %s" % [run, at])
	audio.cue_log.clear()
	events.world_entered.emit(2)
	events.stage_entered.emit(3, false)
	audio._flush_flow()
	at = starts.call("world_entered")
	var stage: Array = starts.call("stage_entered")
	_t.check("new world: world stinger before the stage's", at.size() == 1 and stage.size() == 1 and at[0] < stage[0], "world %s, stage %s" % [at, stage])
	audio.cue_log.clear()
	audio._launch_armed = true
	events.world_entered.emit(3)
	events.stage_entered.emit(5, false)
	audio._flush_flow()
	_t.check("launch landing: world stinger sounds, stage hit left to the landing",
		starts.call("world_entered").size() == 1 and starts.call("stage_entered").is_empty(), str(audio.cue_log))
	audio._disarm_launch()


# A stage table whose rows name packages the module does not have.
class _NopeTable extends RefCounted:
	func of(stage: int) -> Dictionary:
		return {"music": {"theme": 0, "ace": "nope"}} if stage <= 2 else {}


func _fight_checks() -> void:
	Harness.install(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	Harness.start_run(_game)
	# World one's last stage, not COUNT: since 254db18 (six-stage table, 2026-10-04) the
	# run's last stage closes the Mind's world, and this check reads Brindle.
	_game.flow.enter_stage(StageDefs.last_of(1), Vector3(0.0, 0.0, 16.0), false)
	_game.flow._finish_stage()
	var boss = _game.boss
	# Repointed 2026-10-04 (F2a fix round): Brindle's health is posture chunks, so
	# music_state follows the posture bar and the held chunk, not HP floors.
	_t.check("W5-5 the boss has the rules music_state reads", BossRules.PHASE_MIN_SECONDS.size() == 3 and BossRules.POSTURE.has("curve"),
		"phase minimums %s, posture %s" % [BossRules.PHASE_MIN_SECONDS, BossRules.POSTURE])
	_compare("phase 1 start", boss)
	boss.jump_to_phase(2)
	boss._posture.posture = 50.0
	boss.phase_clock = 9.0
	_compare("mid phase 2", boss)
	boss._posture.chunks = BossPosture.CHUNKS - 2
	boss.phase_clock = 20.0
	_compare("after a hold", boss)


# What music_state must say: the bar's share toward this phase's stagger, 1 and held
# once the phase's chunk is broken, and the share of the phase's minimum time run.
func _compare(label: String, boss) -> void:
	var phase: int = boss.phase
	var held: bool = BossPosture.CHUNKS - boss.chunks_left() >= phase
	var want := {
		"in_phase": 1.0 if held else clampf(boss.posture() / BossPosture.FULL, 0.0, 1.0),
		"held": held,
		"phase_seconds": boss.phase_clock / float(BossRules.PHASE_MIN_SECONDS[phase - 1]),
	}
	var got: Dictionary = boss.music_state()
	_t.check("W5-5 %s: music_state matches the reflection" % label,
		is_equal_approx(float(got["in_phase"]), float(want["in_phase"])) and got["held"] == want["held"]
		and is_equal_approx(float(got["phase_seconds"]), float(want["phase_seconds"])),
		"got %s, want %s" % [got, want])
