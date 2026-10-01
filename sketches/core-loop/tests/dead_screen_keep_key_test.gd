extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Under --harpoon=shot --harpoon-keys=keep, C is Rivet's burst key in play. A C pressed as the
# ball dies must not open class select from the death screen and cost the run its retry; a C
# pressed after the guard has run out still does.

var _game
var _failures := 0
var _started := false
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.tuning.set_option("harpoon", "shot")
		_game.tuning.set_option("harpoon_keys", "keep")
		_game.flow.press_start()
		_game.flow.choose_class(1)
		return false
	_ticks += 1
	if _ticks < 30:
		return false
	_run_checks()
	print("dead_screen_keep_key_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _run_checks() -> void:
	var run = _game.run
	var flow = _game.flow
	var scrap: int = run.snapshot_value("scrap")
	run.add_scrap(12, Vector3.ZERO)
	run.damage(9999.0, "test")
	var dead: bool = flow.state_name() == "dead"
	_game._screen_key(KEY_C)
	_report("reflex C after death", dead and flow.state_name() == "dead",
		"died %s, a C on the death screen left the flow at %s" % [dead, flow.state_name()])
	_game._screen_key(KEY_R)
	_report("retry still available", flow.state_name() == "stage" and run.scrap == scrap,
		"R after the reflex C reached %s with scrap %d (checkpoint %d)" % [flow.state_name(), run.scrap, scrap])
	run.damage(9999.0, "test")
	_game._process(1.0)
	_game._screen_key(KEY_C)
	_report("deliberate C", flow.state_name() == "class_select",
		"C after the guard ran out reached %s" % flow.state_name())

	_game.tuning.set_option("harpoon_keys", "shift")
	flow.choose_class(1)
	run.damage(9999.0, "test")
	var dead_default: bool = flow.state_name() == "dead"
	_game._screen_key(KEY_C)
	_report("default layout C", dead_default and flow.state_name() == "class_select",
		"died %s, C at once on the death screen under the default layout reached %s" % [dead_default, flow.state_name()])
	_game.tuning.set_option("harpoon_keys", "keep")
	_game.tuning.set_option("harpoon", "off")
	flow.choose_class(1)
	run.damage(9999.0, "test")
	var dead_off: bool = flow.state_name() == "dead"
	_game._screen_key(KEY_C)
	_report("harpoon off C", dead_off and flow.state_name() == "class_select",
		"died %s, C at once with the harpoon off reached %s" % [dead_off, flow.state_name()])
