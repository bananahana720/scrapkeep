extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const RunStore := preload("res://src/core/run_store.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

# SA-F1 (systems audit pass F): a quit after the Warden breaks, with the gates open, used to
# Continue at the start of the stage just cleared and lose its cogs and parts. Now the gates move
# the saved run to the next stage's entrance with what the cleared stage earned.

const DIR := "user://run_resume_cleared_test/"
const PATH := DIR + "run.json"


class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld


var _game
var _failures := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	_run.call_deferred()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := TwoWorldGame.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	_game = _boot()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	var entered: Dictionary = RunStore.new(PATH).load()
	_game.run.add_part("boost_coil", "test")
	_game.run.add_cogs(321)
	var earned := {"cogs": _game.run.cogs, "parts": Array(_game.run.parts)}
	var warden = _game.flow.warden
	_report("stage 1 holds a Warden", _game.flow.sealed and is_instance_valid(warden), "sealed %s" % _game.flow.sealed)
	if is_instance_valid(warden):
		warden.queue_free()
	await _frames(4)
	var on_disk: Dictionary = RunStore.new(PATH).load()
	_report("the break saves the next entrance", _game.flow.state_name() == "gates" and int(entered.get("stage", 0)) == 1
		and int(on_disk.get("stage", 0)) == 2 and int(on_disk.get("cogs", -1)) == earned["cogs"],
		"flow %s; entered stage %s; on disk stage %s cogs %s, earned %s" % [_game.flow.state_name(), entered.get("stage"), on_disk.get("stage"), on_disk.get("cogs"), earned])
	_game.free()

	_game = _boot()
	await _frames(2)
	var resumed: bool = _game.flow.resume_run()
	await _frames(2)
	_report("continue lands at stage 2 with the cleared stage's earnings", resumed and _game.run.stage == 2
		and _game.run.cogs == earned["cogs"] and Array(_game.run.parts) == earned["parts"] and _game.flow.state_name() == "stage",
		"resumed %s at stage %d, flow %s, cogs %d parts %s; earned %s" % [resumed, _game.run.stage, _game.flow.state_name(), _game.run.cogs, Array(_game.run.parts), earned])
	_game.free()
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)
	print("run_resume_cleared_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
