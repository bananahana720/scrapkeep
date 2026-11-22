extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const Accretion := preload("res://src/build/accretion.gd")

# The ball's accreted shell after an arena retry (FIXWAVE, build side). A crane steals
# mass in the fight and the shell drops a class; the player dies and presses R, and
# the run restores the stolen mass silently. The shell must show the restored class and
# chunk count at once, not the robbed ones.

# The legacy final-stage rule runs on a three-stage double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	if _phase != "boot":
		return false
	_phase = "done"
	var boss = BossDouble.new()
	_game.add_child(boss)
	boss.setup(_game.ctx)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var flow = _game.flow
	var run = _game.run
	var shell = _game.ctx.build.accretion
	flow.press_start()
	flow.choose_class(0)
	flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	# 480 mass is class 2 at 1 + mass/450; losing 450 drops it to class 1.
	run.add_scrap(480, _game.player.ball_position())
	flow.enter_boss(Vector3(15.0, 0.0, 0.0))
	var entry_class: int = run.heft_class()
	run.lose_scrap(450, _game.player.ball_position(), "crane")
	var robbed_class: int = shell.shell_class()
	run.damage(1.0e9, "test")
	flow.retry_stage()
	var want_chunks := Accretion.chunks_for(run.mass)
	_report("shell after arena retry", entry_class > robbed_class and run.heft_class() == entry_class
			and shell.shell_class() == run.heft_class() and shell.chunk_count() == want_chunks
			and is_equal_approx(shell.scale.x, Accretion.shell_scale(run.heft_class(), shell.lattice)),
		"entered the arena at class %d, a crane theft drew the shell at class %d; after R the run is class %d with mass %.0f and the shell shows class %d, %d chunks (want %d), scale %.2f"
			% [entry_class, robbed_class, run.heft_class(), run.mass, shell.shell_class(), shell.chunk_count(), want_chunks, shell.scale.x])
	print("build_arena_retry_shell_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
