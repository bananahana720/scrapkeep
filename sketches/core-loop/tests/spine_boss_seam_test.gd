extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# The arena is not a stage: entering it (and each arena retry) publishes
# stage_content_cleared so stage modules stand down, in_stage() goes false, and a ball
# that leaves the arena is rescued with its horizontal speed. Not calm, so the stage
# modules are live when the fight starts. A boss module without floor_y() and
# rescue_point() falls back to the arena-entry checkpoint.

const RESCUE_WINDOW := 90
const DROP_VELOCITY := Vector3(12.0, 0.0, 5.0)


class BareBoss:
	extends Node

	var ctx

	func setup(ctx_ref) -> void:
		ctx = ctx_ref
		ctx.boss = self

	func enter_arena(entry_velocity: Vector3) -> void:
		var at: Vector3 = ctx.terrain.drop_point(0.0, 0.0, 14.0)
		ctx.player.reset_to(at, entry_velocity)
		ctx.player.body().global_position = at


# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _boss
var _failures := 0
var _ticks := 0
var _phase := "start"
var _cleared: Array[String] = []
var _rescue := {}


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _drop_below(ball_owner) -> void:
	var off: Vector3 = _game.ctx.terrain.drop_point(0.0, 0.0, 0.0) + Vector3(0.0, -200.0, 0.0)
	_game.player.reset_to(off, DROP_VELOCITY)
	_game.player.body().global_position = off
	_rescue = {"owner": ball_owner, "ticks": 0, "done": false}


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	var flow = _game.flow
	match _phase:
		"start":
			_boss = BossDouble.new()
			_game.add_child(_boss)
			_boss.setup(_game.ctx)
			_game.player.source = Intent.Scripted.new()
			_game.events.stage_content_cleared.connect(func(reason: String): _cleared.append(reason))
			flow.press_start()
			flow.choose_class(0)
			flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
			var in_stage_before: bool = flow.in_stage()
			flow.enter_boss(Vector3(15.0, 2.0, 0.0))
			_report("arena entry", in_stage_before and _cleared == ["arena"] and not flow.in_stage() and flow.in_play() and flow.state_name() == "boss",
				"stage 3 in_stage %s; entering the arena published stage_content_cleared %s, in_stage %s, in_play %s"
					% [in_stage_before, _cleared, flow.in_stage(), flow.in_play()])
			_drop_below("boss")
			_phase = "rescue"
		"rescue", "fallback":
			_rescue["ticks"] += 1
			var ball: Vector3 = _game.player.ball_position()
			if not _rescue["done"] and ball.y > -100.0:
				_rescue["done"] = true
				_rescue["at_tick"] = _rescue["ticks"]
				_rescue["speed"] = _game.player.planar_velocity().length()
				_rescue["y"] = ball.y
			if _rescue["ticks"] >= RESCUE_WINDOW:
				_finish_rescue(flow)
	return false


func _finish_rescue(flow) -> void:
	var wanted := Vector2(DROP_VELOCITY.x, DROP_VELOCITY.z).length()
	var ok: bool = _rescue["done"] and _rescue["at_tick"] <= RESCUE_WINDOW and absf(_rescue["speed"] - wanted) < 0.05
	if _phase == "rescue":
		var landing_ok: bool = ok and _rescue["y"] >= _boss.floor_y()
		_report("arena rescue", landing_ok,
			"a ball 200 m under the arena was back above the boss floor after %d tick(s) at %.2f m/s horizontal (was %.2f)"
				% [_rescue.get("at_tick", -1), _rescue.get("speed", -1.0), wanted])
		_game.run.damage(99999.0, "test")
		flow.retry_stage()
		_report("arena retry", _cleared == ["arena", "arena_retry"] and flow.state_name() == "boss" and not flow.in_stage(),
			"R in the arena republished stage_content_cleared %s, state %s" % [_cleared, flow.state_name()])
		var bare := BareBoss.new()
		_game.add_child(bare)
		bare.setup(_game.ctx)
		flow.retry_stage()
		_drop_below("bare")
		_phase = "fallback"
		return
	var entry: Vector3 = _game.run.snapshot_value("entry_position")
	_report("fallback rescue", ok and absf(_rescue["y"] - entry.y) < 1.0,
		"a boss module without floor_y() put the ball back at the arena entry (%.1f m, entry %.1f m) after %d tick(s) at %.2f m/s"
			% [_rescue.get("y", -1.0), entry.y, _rescue.get("at_tick", -1), _rescue.get("speed", -1.0)])
	print("spine_boss_seam_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
