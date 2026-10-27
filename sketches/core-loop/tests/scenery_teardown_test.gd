extends SceneTree

# Rule (scrapkeep#494, run_save_interrupt exit leak): the scenery hooks' build-ahead handlers on the
# terrain's stage_built do not keep the game's context alive. The context owns the terrain, a
# RefCounted, so a handler bound to the context made a cycle that outlived every freed game and kept
# the scenery scripts' statics (thousands of graphics-preset WeakRefs) to exit. A run restart and a
# return to the title keep one handler a hook; a park pass begun ahead stops when its stage is freed
# and is gone with the game; a freed game frees its context and terrain. Fixture: a live game on the
# park table; no check here is timed.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")

var _t := T.new("scenery_teardown_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 5:
		await physics_frame
	var terrain = game.ctx.terrain
	var handlers: int = terrain.stage_built.get_connections().size()
	game.flow.new_run()
	for i in 5:
		await physics_frame
	game.flow.show_title()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 5:
		await physics_frame
	_t.check("a restart and a return to the title keep the terrain's handlers", terrain.stage_built.get_connections().size() == handlers,
		"%d then %d" % [handlers, terrain.stage_built.get_connections().size()])

	# A pass begun ahead on a stage the Reaper then takes stops stepping.
	var reaped := _begin_pass(game, terrain)
	Terrain.Reaper.take(reaped.root)
	var phase: int = reaped.pass_._phase
	for i in 3:
		await process_frame
	_t.check("a pass begun ahead stops when its stage is freed", reaped.pass_._phase == phase, "phase %d then %d" % [phase, reaped.pass_._phase])
	reaped.root.free()

	var running := _begin_pass(game, terrain)
	var pass_ref: WeakRef = weakref(running.pass_)
	running.clear()
	var ctx_ref: WeakRef = weakref(game.ctx)
	var terrain_ref: WeakRef = weakref(terrain)
	terrain = null
	game.free()
	await process_frame
	_t.check("a pass begun ahead is gone with the game", pass_ref.get_ref() == null)
	_t.check("a freed game frees its context", ctx_ref.get_ref() == null)
	_t.check("a freed game frees its terrain", terrain_ref.get_ref() == null)
	quit(_t.verdict())


# A park pass begun ahead (ParkBuild) on a stage root of the game's stage-1 map, left running.
func _begin_pass(game, terrain) -> Dictionary:
	var stage_root := Node3D.new()
	game.add_child(stage_root)
	var pass_ = Scenery.ParkPass.new(stage_root, terrain.map_for(1), terrain.ground_callable(1), 1)
	var step := Scenery.ParkBuild.new()
	step.name = "ParkBuild"
	step.pass_ = pass_
	pass_.scenery.add_child(step)
	return {"root": stage_root, "pass_": pass_}
