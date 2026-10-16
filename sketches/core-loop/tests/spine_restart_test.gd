# smoke: solo (verdict reads wall time: retry and replay must take under one second)
extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# Retry puts the stage-start checkpoint back: scrap, health, parts, position and entry
# speed, in one call well inside a second. It works from play (the hold-R path) and
# from the death screen, and a later stage's checkpoint keeps what earlier stages won.

const SECOND_USEC := 1_000_000
const POSITION_TOLERANCE := 0.5

# Legacy final-stage carry and plating use a three-stage double.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _ticks := 0
var _started := false
var _states: Array[String] = []


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.flow_changed.connect(func(s: String): _states.append(s))
		_game.flow.press_start()
		_game.flow.choose_class(1)
		return false
	_ticks += 1
	if _ticks < 30:
		return false
	_run_checks()
	print("spine_restart_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _spoil(scrap: int, hurt: float, part: String) -> void:
	var run = _game.run
	run.add_scrap(scrap, Vector3.ZERO)
	run.damage(hurt, "test")
	run.add_part(part, "test")
	var away: Vector3 = _game.ctx.terrain.drop_point(40.0, -120.0, 2.0)
	_game.player.reset_to(away, Vector3(9.0, 0.0, 3.0))
	_game.player.body().global_position = away


# Retries and returns how long the call took and how far the ball ended from the entry.
func _retry() -> Dictionary:
	var begin := Time.get_ticks_usec()
	_game.flow.retry_stage()
	var took := Time.get_ticks_usec() - begin
	var entry: Vector3 = _game.run.snapshot_value("entry_position")
	return {
		"usec": took,
		"gap": _game.player.ball_position().distance_to(entry),
		"speed_gap": (_game.player.state.velocity - (_game.run.snapshot_value("entry_velocity") as Vector3)).length(),
	}


# The boss death screen: the gap line names plating, and T replays stage 3 from the
# start the run kept. Wave 4 adds the boss state; here its seam is set by hand.
func _final_stage_checks() -> void:
	var run = _game.run
	var flow = _game.flow
	var double := SpawnerDouble.new()
	_game.add_child(double)
	double.setup(_game.ctx)
	_game.ctx.spawner = double
	flow.force_warden = true
	flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	var start := {"mass": run.mass, "parts": run.parts.duplicate(), "hp": run.hp}
	run.add_scrap(40, Vector3.ZERO)
	run.add_part("boost_coil", "test")
	run.damage(20.0, "test")
	run.damage(9999.0, "test")
	var warden_text: String = _game.screens.body_text()
	flow.retry_stage()
	flow.boss_active = true
	run.add_scrap(25, Vector3.ZERO)
	run.damage(9999.0, "test")
	var boss_text: String = _game.screens.body_text()
	var offered: bool = flow.can_replay_final_stage()
	var begin := Time.get_ticks_usec()
	var replayed: bool = flow.replay_stage(3)
	var took := Time.get_ticks_usec() - begin
	# Re-pinned 2026-10-15 (BRINDLE-SCUTTLE merge): hull plating 120 to 110 in boss_rules.gd.
	_report("death gap line", warden_text.contains("plating %d" % int(StageDefs.of(3)["warden_plating"])) and boss_text.contains("plating 110") and boss_text.contains("T   replay stage 3"),
		"warden death reads \"%s\"; boss death offers T %s" % [warden_text.get_slice("\n", 0), boss_text.contains("T   replay")])
	_report("replay stage 3", offered and replayed and flow.state_name() == "stage" and run.stage == 3 and run.mass == start["mass"]
			and run.parts == start["parts"] and is_equal_approx(run.hp, start["hp"]) and took < SECOND_USEC,
		"T replayed stage %d in %.1f ms: mass %.0f (start %.0f), parts %s, hp %.0f, flow %s"
			% [run.stage, took / 1000.0, run.mass, start["mass"], run.parts, run.hp, flow.state_name()])
	flow.force_warden = false


# The checkpoint is taken before stage_entered: scrap a module grants inside its handler
# is play inside the stage, so a retry takes it back.
func _handler_grant_checks() -> void:
	var run = _game.run
	var grant := func(_stage: int, retry: bool):
		if not retry:
			run.add_scrap(50, Vector3.ZERO)
	_game.events.stage_entered.connect(grant)
	var before: int = run.scrap
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	_game.events.stage_entered.disconnect(grant)
	var kept: int = run.snapshot_value("scrap")
	var entry: Vector3 = run.snapshot_value("entry_position")
	_game.flow.retry_stage()
	_report("checkpoint before handlers", kept == before and run.scrap == before and entry != Vector3.ZERO,
		"a 50-scrap grant inside stage_entered: checkpoint holds %d (before %d), retry left %d, entry pose filled %s" % [kept, before, run.scrap, entry != Vector3.ZERO])


func _run_checks() -> void:
	var run = _game.run
	var start := {"scrap": run.scrap, "hp": run.hp, "parts": run.parts.duplicate()}

	_spoil(12, 30.0, "boost_coil")
	var spoiled := "scrap %d, hp %.0f, parts %s" % [run.scrap, run.hp, run.parts]
	var r := _retry()
	_report("retry in play", run.scrap == start["scrap"] and is_equal_approx(run.hp, start["hp"]) and run.parts == start["parts"]
			and r["gap"] < POSITION_TOLERANCE and r["speed_gap"] < 0.01 and r["usec"] < SECOND_USEC and _game.flow.state_name() == "stage",
		"after %s, retry restored scrap %d, hp %.0f, parts %s, ball %.3f m from the entry with its entry speed, in %.1f ms"
			% [spoiled, run.scrap, run.hp, run.parts, r["gap"], r["usec"] / 1000.0])

	run.damage(9999.0, "test")
	var dead: bool = _game.flow.state_name() == "dead" and _game.player.frozen()
	r = _retry()
	_report("retry from death", dead and _game.flow.state_name() == "stage" and is_equal_approx(run.hp, start["hp"])
			and not _game.player.frozen() and r["gap"] < POSITION_TOLERANCE and r["usec"] < SECOND_USEC,
		"death screen reached %s, R put the ball back %.3f m from the entry at hp %.0f in %.1f ms, flow %s"
			% [dead, r["gap"], run.hp, r["usec"] / 1000.0, _game.flow.state_name()])

	run.add_part("dash_vane", "gate")
	run.add_scrap(5, Vector3.ZERO)
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 18.0), false)
	var stage_two := {"scrap": run.scrap, "parts": run.parts.duplicate(), "hp": run.hp}
	_spoil(7, 40.0, "tread_plating")
	r = _retry()
	_report("stage 2 checkpoint", run.stage == 2 and run.scrap == stage_two["scrap"] and run.parts == stage_two["parts"]
			and is_equal_approx(run.hp, stage_two["hp"]) and r["gap"] < POSITION_TOLERANCE,
		"retry in stage %d kept the stage 1 gate part: scrap %d, parts %s, hp %.0f, ball %.3f m from the entry"
			% [run.stage, run.scrap, run.parts, run.hp, r["gap"]])

	_report("retry count", run.retries == 3, "summary counts %d retries" % run.retries)
	_handler_grant_checks()
	_final_stage_checks()
	run.damage(9999.0, "test")
	_game.flow.new_run()
	_report("new run", _game.flow.state_name() == "stage" and run.stage == 1 and run.parts.is_empty() and run.scrap == 0
			and run.class_id() == "runner_gunner",
		"N from the death screen started stage %d as %s with %d parts and %d scrap"
			% [run.stage, run.class_id(), run.parts.size(), run.scrap])
