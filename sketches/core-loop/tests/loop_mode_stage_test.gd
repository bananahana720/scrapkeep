extends SceneTree

const Game := preload("res://src/game.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")

# The loop mode is one value per stage. Every reader (the drop lips' aim, the combat
# ledger, the ACE drop-line commit, the hit-stop budget) sees the mode the stage entered
# with, so a panel edit under "hold R to apply" takes effect at the next stage entry or
# retry and never half-applies mid-stage.

var _game
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.tuning.set_option("loop_mode", "drop")
	_game.flow.press_start()
	_game.flow.choose_class(1)
	for i in 20:
		await physics_frame
	var m = _game.ctx.terrain.map()
	var line: Dictionary = m.drop_lines[0]
	var at: Vector2 = line["at"]
	var dir: Vector2 = line["dir"]
	var p2 := at - dir * 1.0
	var ball: Vector3 = _game.ctx.terrain.drop_point(p2.x, p2.y, 0.5)
	var launch := Vector3(dir.x, 0.3, dir.y) * 26.0
	var audio = _game.presentation.get("audio")
	audio.ace = AceSequencer.new()
	_game.tuning.set_option("loop_mode", "laps")

	_game.player.reset_to(ball, launch)
	_check("aim", _game.world._aim_drop(ball), "lips keep aiming in a drop stage after a flip to laps")
	_game.ctx.events.beacon_unsealed.emit(1)
	var ledger = _game.combat._ledger["drops_to_break"].get("1")
	_check("ledger", ledger != null, "drops_to_break for the drop stage is %s, not null, after the flip" % [ledger])
	audio.ace.mode = "level"
	audio._follow_drop_line()
	_check("ace", audio.ace.mode == "warden", "the ACE band commits on the drop line after the flip: mode %s" % audio.ace.mode)
	_game.tuning.set_option("loop_mode", "v2")
	var spent: float = _game.hit_stop_spent
	_game.hit_stop(0.04)
	_game._end_hit_stop()
	_check("hit stop", _game.hit_stop_spent > spent, "the drop stage's hit-stop budget still counts after a flip to v2")

	_game.tuning.set_option("loop_mode", "laps")
	_game.flow.retry_stage()
	for i in 3:
		await physics_frame
	_game.player.reset_to(ball, launch)
	_check("retry aim", not _game.world._aim_drop(ball), "after the retry the stage runs laps: no aim")
	_check("retry laps", _game.flow.laps_required > 0, "the Warden sleeps for laps after the retry: %d" % _game.flow.laps_required)
	_game.free()
	print("loop_mode_stage_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
