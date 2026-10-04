extends SceneTree

const Game := preload("res://src/game.gd")
const BossContract := preload("res://src/boss/boss_contract.gd")
const Worlds := preload("res://src/core/worlds.gd")
const T := preload("res://tests/support/t.gd")

# The Waking and the Mind have their own module files (waking.gd, mind.gd), so flow's
# per-path module cache holds two distinct instances: flow._module_for(2) and (3) are not
# the same object, each conforms to BossContract.MODULE, and each, entered directly, names
# its plate, its objective and its music id from its own Worlds.BOSSES row.
#
# Evidence limit: the modules still run the stub's fight; this checks identity and the
# surface, not either boss's own fight.

const TICK_LIMIT := 60 * 10

var _t := T.new("world_boss_files_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	var ticks := 0
	while _game.flow == null and ticks < TICK_LIMIT:
		ticks += 1
		await physics_frame
	var flow = _game.flow
	_game.ctx.calm = true
	flow.press_start()
	flow.choose_class(0)
	await _frames(4)
	var waking = flow._module_for(2)
	var mind = flow._module_for(3)
	_t.check("both worlds have a module", waking != null and mind != null, "waking %s, mind %s" % [waking != null, mind != null])
	if waking == null or mind == null:
		_finish(true)
		return
	_t.check("the Waking and the Mind are distinct instances", waking != mind, "")
	_t.check("neither is the scene's boss", waking != _game.boss and mind != _game.boss, "")
	for pair in [[waking, Worlds.BOSSES["waking"], "waking"], [mind, Worlds.BOSSES["mind"], "mind"]]:
		var module = pair[0]
		var row: Dictionary = pair[1]
		var label: String = pair[2]
		var missing: Array = BossContract.conforms(module, BossContract.MODULE)
		_t.check("%s conforms to MODULE" % label, missing.is_empty(), "missing %s" % [missing])
		_t.eq("%s's script is its row's" % label, module.get_script().resource_path, String(row["script"]))
		module.enter_arena(Vector3.ZERO)
		await _frames(2)
		var warden = module.warden
		_t.eq("%s's plate name" % label, String(warden.get_meta("plate_name", "")) if is_instance_valid(warden) else "", String(row["name"]))
		var objective: String = module.objective_text()
		_t.check("%s's objective names it" % label, objective.contains(String(row["name"])), objective)
		_t.eq("%s's music id" % label, module.music_state().get("id", ""), String(row["music"]))
		module.exit_arena()
		await _frames(1)
	_finish()


func _finish(failed := false) -> void:
	_game.free()
	quit(1 if failed else _t.verdict())
