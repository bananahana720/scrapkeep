extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const T := preload("res://tests/support/t.gd")

# Run-found companion pieces (ALPHA-PLAN:68): the first activity finished in a stage entry adds
# the next Companion.DROP_ORDER piece to the run, acquired and never seated; a retry does not
# re-arm it, a new stage entry does, and the run's end writes the pieces to the profile.
# Calling activities._finish and activities._on_stage_entered directly is the accepted test seam.
# No clock; waits are in frames.

var _t := T.new("companion_drop_test")
var _game


func _initialize() -> void:
	_pure()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _pure() -> void:
	_t.eq("an empty doc drops the escape vent first", Companion.next_drop({}), "escape_vent")
	var one := Companion.with_piece({}, "escape_vent")
	_t.eq("with_piece on an empty doc owns only that piece", one["owned"], ["escape_vent"])
	_t.eq("with_piece seats nothing", one["sockets"], [])
	var all := {}
	for id in Companion.DROP_ORDER:
		all = Companion.with_piece(all, id)
	_t.eq("a doc owning all six drops nothing", Companion.next_drop(all), "")
	var bad := {"chassis": "x"}
	_t.eq("a malformed doc comes back unchanged", Companion.with_piece(bad, "ram_prow"), bad)
	_t.eq("a malformed doc drops nothing", Companion.next_drop(bad), "")
	_t.eq("the piece table and drop order validate", Companion.validate(), [])


func _owned() -> Array:
	return _game.run.companion.get("owned", [])


func _finish_first() -> void:
	var acts = _game.world.activities
	var s = acts.sites[0]
	acts._finish(s, s.global_position)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	flow.press_start()
	flow.choose_class(1)
	await _frames(20)
	var acts = _game.world.activities
	_t.check("the stage builds at least one activity", acts.sites.size() >= 1, "got %d" % acts.sites.size())
	_t.eq("a fresh profile starts the run owning nothing", _owned(), [])
	_finish_first()
	_t.eq("the first finished activity pays the escape vent", _owned(), ["escape_vent"])
	if acts.sites.size() >= 2:
		acts._finish(acts.sites[1], acts.sites[1].global_position)
	_finish_first()
	_t.eq("a second finish in the same entry pays nothing", _owned(), ["escape_vent"])
	acts._on_stage_entered(_game.run.stage, true)
	await _frames(2)
	_finish_first()
	_t.eq("a retry pays nothing", _owned(), ["escape_vent"])
	acts._on_stage_entered(_game.run.stage, false)
	await _frames(2)
	_finish_first()
	_t.eq("a new stage entry pays the ram prow", _owned(), ["escape_vent", "ram_prow"])
	_t.eq("no piece is seated", _game.run.companion["sockets"], [])
	flow._end_run(false)
	await _frames(2)
	_t.eq("the profile holds both pieces", _game.ctx.profile.companion().get("owned", []), ["escape_vent", "ram_prow"])
	_game.queue_free()
	quit(_t.verdict())
