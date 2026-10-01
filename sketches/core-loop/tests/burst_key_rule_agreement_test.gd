extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Whether C is the in-play burst key is decided in two places: the keyboard's routing in
# intent.gd and the death screen's C guard in game.gd. Over every harpoon mode and key
# layout, a C the keyboard reads as the burst must be the C the death screen swallows, and
# no other C may be.

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
		_game.flow.press_start()
		_game.flow.choose_class(1)
		return false
	_ticks += 1
	if _ticks < 30:
		return false
	_run_checks()
	print("burst_key_rule_agreement_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _keyboard_reads_c_as_burst() -> bool:
	var keyboard := Intent.Keyboard.new()
	keyboard.tuning = _game.tuning
	var out := Intent.new()
	Input.action_press("cl_dash")
	keyboard.poll(out)
	Input.action_release("cl_dash")
	return out.movement_held


func _death_screen_swallows_c() -> bool:
	var flow = _game.flow
	flow.choose_class(1)
	_game.run.damage(9999.0, "test")
	if flow.state_name() != "dead":
		return false
	_game.dead_guard_left = 1.0
	_game._screen_key(KEY_C)
	var swallowed: bool = flow.state_name() == "dead"
	_game.dead_guard_left = 0.0
	return swallowed


func _run_checks() -> void:
	for harpoon in ["off", "shot", "lock"]:
		for keys in ["shift", "keep"]:
			_game.tuning.set_option("harpoon", harpoon)
			_game.tuning.set_option("harpoon_keys", keys)
			var burst := _keyboard_reads_c_as_burst()
			var swallowed := _death_screen_swallows_c()
			var label := "harpoon %s keys %s" % [harpoon, keys]
			_report(label, burst == swallowed, "intent reads C as burst %s, death screen swallows it %s" % [burst, swallowed])
			_report(label + " expected", burst == (harpoon != "off" and keys == "keep"),
				"burst %s" % burst)
