extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Profile := preload("res://src/core/profile.gd")
const T := preload("res://tests/support/t.gd")

# Meta-progression (decision row 177): the pieces found and the assembly carry across runs.
# With --companion-stub on, a run assembles two pieces on the dead screen and ends; the next
# run in the same Game starts with them, and a fresh Profile read from disk holds the same
# dictionary. No clock.

var _t := T.new("companion_persist_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _doc(owned: Array, seated: Array) -> Dictionary:
	var m := Companion.new()
	for id in owned:
		m.acquire(id)
	if not seated.is_empty():
		m.assemble(seated)
	return m.to_dict()


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	var flow = _game.flow
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.tuning.set_option("companion_stub", "on")
	flow.press_start()
	flow.choose_class(1)
	await _frames(20)
	var stub := ["primer_coil", "ram_prow", "escape_vent"]
	var want := _doc(stub, ["primer_coil", "ram_prow"])
	# Two pieces assembled on the dead screen, as the panel writes them.
	_game.run.damage(99999.0, "test")
	await _frames(12)
	_t.eq("dead", flow.state_name(), "dead")
	_game.run.companion = want
	# The run ends (flow's own end, as the second death in a world reaches it).
	flow._end_run(false)
	await _frames(2)
	_t.eq("run ended", flow.state_name(), "summary")
	_t.eq("profile took the companion", _game.ctx.profile.companion(), want)
	var disk := Profile.new(_game.ctx.profile.path)
	disk.load_profile()
	_t.eq("a fresh profile from disk holds it", disk.companion(), want)
	# The next run starts with the owned pieces and the assembly.
	flow.new_run()
	await _frames(5)
	_t.eq("new run carries the pieces and the assembly", _game.run.companion, want)
	_game.queue_free()
	quit(_t.verdict())
