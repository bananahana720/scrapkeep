extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const BossPosture := preload("res://src/core/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

# The module harness drives the default table's stub-family bosses to victory through
# flow's own seams: world two's Waking (waking.gd) and world three's Mind (mind.gd). Each
# module is the one flow names for its world and is ctx.boss in its arena, answers both
# BossContract surfaces, enters its arena once, and falls to TARGET hits within the cap with
# one weak point per chunk (the stub's Warden is REACTOR, so every point is "core"). Victory
# follows; world two's lands on world three's first stage, world three's on the summary with
# one run_ended(true).
#
# Evidence limit: hits are TARGET calls, not ball contacts; the worlds are entered through
# flow.enter_stage and flow.enter_boss, not walked to.

# Caps in physics frames at the project's 90 ticks per second.
const FRAME_CAP := 180 * 90
const FIGHT_CAP := 90 * 30
const STATE_FRAMES := 90 * 10

var _t := T.new("stub_boss_phase_test")
var _game
var _began := 0


func _initialize() -> void:
	# These tests pin mechanics with a smash-per-frame TARGET hit, not the fight's length: the PHASE_MIN_SECONDS
	# hold (waking.gd, mind.gd; tests/boss_phase_hold_test.gd) is multiplied out.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0], "mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	_began = Engine.get_physics_frames()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _walk()
	var frames: int = Engine.get_physics_frames() - _began
	_t.check("within the cap", frames < FRAME_CAP, "%d physics frames, %.1f s simulated" % [frames, frames / 90.0])
	_game.free()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	flow.victory_lap = false
	var stages = game.ctx.stages
	_t.check("bot driven", game.bot_driven, "bot_driven %s" % game.bot_driven)
	var seen = Harness.counter(game)
	Harness.boot(game)
	var expect := {2: "waking.gd", 3: "mind.gd"}
	for w in [2, 3]:
		var arenas_before: int = seen.arenas
		var posture_before: int = seen.posture_changed
		var defeated_before: int = seen.defeated
		Harness.enter_world(game, w)
		var mod = Harness.module(game, w)
		var path: String = mod.get_script().resource_path if mod != null else "none"
		if not _t.check("world %d module is %s and ctx.boss" % [w, expect[w]], path.ends_with(expect[w]) and game.ctx.boss == mod,
				"module %s, ctx.boss is it %s" % [path, game.ctx.boss == mod]):
			return
		var shape: Dictionary = Harness.conforms(mod)
		_t.eq("world %d module conforms to MODULE" % w, shape["module"], [])
		_t.eq("world %d target conforms to TARGET" % w, shape["target"], [])
		_t.eq("world %d arena entered once" % w, seen.arenas - arenas_before, 1)
		var fought: Dictionary = await Harness.fight(game, mod, FIGHT_CAP, seen)
		print("world %d boss %s: %d hit(s) in %d frame(s), %s" % [w, path.get_file(), fought["hits"], fought["frames"], fought["victory_state"]])
		_t.check("world %d defeated within the cap" % w, fought["defeated"], "%d hits in %d of %d frames" % [fought["hits"], fought["frames"], FIGHT_CAP])
		var point: String = "core" if w == 2 else "lens"
		_t.check("world %d at least one %s point per chunk" % [w, point], fought["points"].size() >= BossPosture.CHUNKS
				and fought["points"].all(func(id): return id == point), "points %s" % [fought["points"]])
		_t.check("world %d posture published" % w, seen.posture_changed > posture_before, "%d posture_changed" % (seen.posture_changed - posture_before))
		_t.eq("world %d boss_defeated once" % w, seen.defeated - defeated_before, 1)
		await _until(func(): return flow.state_name() != "boss")
		if not _t.eq("world %d victory" % w, flow.state_name(), "victory"):
			return
		if w == 2:
			var next: int = stages.first_of(3)
			await _until(func(): return flow.state_name() == "stage")
			_t.check("world 2 victory lands on world 3's first stage %d" % next, flow.state_name() == "stage" and game.run.stage == next,
				"state %s on stage %d" % [flow.state_name(), game.run.stage])
		else:
			await _until(func(): return flow.state_name() == "summary")
			for _i in 30:
				await physics_frame
			_t.check("world 3 victory leads to the summary", flow.state_name() == "summary" and flow.run_won,
				"state %s, run_won %s" % [flow.state_name(), flow.run_won])
			_t.eq("run_ended(true) once", seen.won, [true])


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame
