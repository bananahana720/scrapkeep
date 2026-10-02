extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# On the slice table each heft class the run reaches for the first time opens one upgrade
# tree pick, once the ball is on the ground and no Warden fight is live. The run keeps the
# highest class rewarded: a drop and a re-rise open nothing, a new run resets it and a retry
# keeps it, as it keeps the tree. The default table opens none on a rise. Mass is set through
# the real run state (scrap pickups and thefts), so the class moves by the real heft rule:
# 225 mass is class II, 540 class III, 990 class IV. The workshop screen is not under test;
# the tree's own pick allowance is. The tree stops at four depths, or two under the
# world-one build flag, which defaults on; the climb checks turn it off so four are
# reachable, and the last slice check leaves it on to show the two-depth cap holds.

const II := 225
const III := 540
const IV := 990


# A Warden that is awake and standing, as far as the fight test reads it.
class FightWarden extends Node3D:
	func is_dead() -> bool:
		return false


var _t := T.new("class_step_pick_test")
var _game
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.tuning.apply_args(PackedStringArray(["--world-one-builds=off"]), "launch")
	_slice()
	_game.ctx.tuning.apply_args(PackedStringArray(["--world-one-builds=on"]), "launch")
	_world_one_cap()
	_game.ctx.tuning.apply_args(PackedStringArray(["--world-one-builds=off"]), "launch")
	_default()
	_game.free()
	quit(_t.verdict())
	return true


func _allowed() -> int:
	return _game.player.tree.allowed


func _run() -> Object:
	return _game.ctx.run


func _new_run() -> void:
	_game.flow.new_run()
	_game.flow.sealed = false
	_game.flow.warden = null
	_game.player.state.grounded = true
	_game.player.tree.picks.clear()


func _to(mass: int) -> void:
	var now: int = int(_run().mass)
	if mass > now:
		_run().add_scrap(mass - now, Vector3.ZERO)
	elif mass < now:
		_run().lose_scrap(now - mass, Vector3.ZERO, "test")


func _slice() -> void:
	_t.check("the game runs the slice table", _game.ctx.stages.PICK_ON_CLASS_UP, "PICK_ON_CLASS_UP %s" % [_game.ctx.stages.PICK_ON_CLASS_UP])
	_new_run()
	_t.eq("a new run holds the start pick and class I", [_allowed(), _run().class_rewarded, _run().heft_class()], [1, 1, 1])
	_to(II)
	_t.eq("class II opens one pick", [_allowed(), _run().class_rewarded], [2, 2])
	_new_run()
	_to(III)
	_t.eq("class I to III opens two picks, one per new class", [_allowed(), _run().class_rewarded], [3, 3])
	_to(0)
	_t.eq("a drop opens none and keeps the rewarded class", [_allowed(), _run().heft_class(), _run().class_rewarded], [3, 1, 3])
	_to(III)
	_t.eq("a re-rise to a rewarded class opens none", [_allowed(), _run().class_rewarded], [3, 3])
	_to(II)
	_to(III)
	_t.eq("rising through II again opens none", _allowed(), 3)

	_new_run()
	_game.player.state.grounded = false
	_to(II)
	_t.eq("a rise in the air opens nothing yet", _allowed(), 1)
	_game.player.state.grounded = true
	_game.world._deliver_class_picks()
	_t.eq("it opens after landing", _allowed(), 2)
	_game.world._deliver_class_picks()
	_t.eq("and only once", _allowed(), 2)

	_new_run()
	var warden := FightWarden.new()
	_game.add_child(warden)
	_game.flow.sealed = true
	_game.flow.warden = warden
	_game.flow._engaged = true
	_to(II)
	_game.world._deliver_class_picks()
	_t.eq("a rise in a live Warden fight opens nothing yet", _allowed(), 1)
	_game.flow.sealed = false
	_game.world._deliver_class_picks()
	_t.eq("it opens after the fight", _allowed(), 2)
	warden.free()

	_new_run()
	_to(III)
	_game.flow.retry_stage()
	_t.eq("a retry keeps the run's rewarded class, as it keeps the tree", [_run().class_rewarded, _run().heft_class()], [3, 1])
	var before := _allowed()
	_game.player.state.grounded = true
	_to(II)
	_game.world._deliver_class_picks()
	_t.eq("so the climb after a retry opens nothing new", _allowed(), before)

	_new_run()
	_to(IV)
	_t.eq("class IV is the cap: the start pick and three class picks", _allowed(), 4)


func _world_one_cap() -> void:
	_new_run()
	_to(IV)
	_t.eq("under world-one the two-depth cap holds", [_allowed(), _game.player.tree.max_depth], [2, 2])


func _default() -> void:
	_game.free()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_t.check("the default table has no class pick", not _game.ctx.stages.PICK_ON_CLASS_UP, "PICK_ON_CLASS_UP %s" % [_game.ctx.stages.PICK_ON_CLASS_UP])
	_game.player.state.grounded = true
	var before := _allowed()
	_to(III)
	_t.eq("on the default table a class rise opens no pick", [_allowed(), _run().heft_class()], [before, 3])
