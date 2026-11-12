extends SceneTree

const Game := preload("res://src/game.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# W1-60 (Andrew 12 Nov 22:06Z): in the sitting launch, beating world 1's boss ends the run won,
# with its summary, the first win and HARD rung 1, instead of rolling on into the Dig. Without
# the launch option the run goes on into world 2 as before, which is what bots and bands measure.
# Driven through the victory card's real timeout (flow.physics_step) on a two-world double, so
# the check holds for any table whose world 1 is not its last.

const DT := 1.0 / 90.0


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd")


var _t := T.new("sitting_world_end_test")
var _game
var _started := false
var _ended: Array = []


func _initialize() -> void:
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	# The achievement listener joins the bus on the game's first physics frame (game.gd).
	if _game.flow == null or not _game._progress_ready or _started:
		return false
	_started = true
	_game.ctx.calm = true
	_game.events.run_ended.connect(func(won: bool): _ended.append(won))
	_run()
	_game.queue_free()
	quit(_t.verdict())
	return true


func _start_run() -> void:
	_game.flow.show_title()
	_game.flow.open_class_select()
	_game.flow.choose_class(0)


# World 1's boss falls: the victory card shows, then its timer runs out.
func _beat_world_one_boss() -> void:
	var flow = _game.flow
	_game.ctx.run.stage = _game.ctx.stages.last_of(1)
	flow._set_state(flow.VICTORY)
	flow._victory_left = 0.0
	flow.physics_step(DT)


func _run() -> void:
	var flow = _game.flow
	var stages = _game.ctx.stages
	_t.check("the double has a world after world 1", stages.worlds().size() == 2 and not stages.is_run_last(stages.last_of(1)),
		str(stages.worlds()))

	var sitting := Tuning.new()
	sitting.apply_args(PackedStringArray(["--profile=sitting"]))
	_t.eq("the sitting launch names world 1 as final", sitting.final_world(), 1)
	_t.eq("a plain launch names none", Tuning.new().final_world(), 0)

	# Flag off: today's run into world 2.
	_t.check("flag off: world 1's end does not end the run", not flow.run_ends_after(stages.last_of(1)), "")
	_t.check("flag off: the table's last stage still does", flow.run_ends_after(stages.COUNT), "")
	_start_run()
	_beat_world_one_boss()
	_t.eq("flag off: the run goes on into world 2", stages.world_of(_game.ctx.run.stage), 2)
	_t.check("flag off: no summary", flow.state != flow.SUMMARY and _ended.is_empty(), "state %d, ended %s" % [flow.state, _ended])

	# Flag on: the sitting's run ends won at world 1's boss.
	_game.tuning.set_option("final_world", "1")
	_t.check("flag on: world 1's end ends the run", flow.run_ends_after(stages.last_of(1)), "")
	_t.check("flag on: a stage before world 1's end does not", not flow.run_ends_after(stages.last_of(1) - 1), "")
	_t.check("profile has no first win yet", not RunTier.unlocked(_game.ctx.profile), "")
	_start_run()
	_ended.clear()
	_beat_world_one_boss()
	_t.eq("flag on: the run stays in world 1", stages.world_of(_game.ctx.run.stage), 1)
	_t.eq("flag on: the summary opens", flow.state, flow.SUMMARY)
	_t.check("flag on: the run is won", flow.run_won and _ended == [true], str(_ended))
	_t.check("flag on: no all-worlds ending page", not flow.won_final(), "")
	_t.check("flag on: the win opens HARD rung 1", RunTier.unlocked(_game.ctx.profile, RunTier.HARD), "")
	_t.check("flag on: the run is over for good", _game.ctx.run.over, "")
	_game.tuning.set_option("final_world", "last")
