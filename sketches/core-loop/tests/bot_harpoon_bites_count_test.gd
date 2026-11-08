extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# The bot's 'harpoon_bites' note counts bites, not presses. The player discards a harpoon
# press while the special or slingshot charges (it becomes a cancel) and while frozen, so
# a press under those conditions must neither be sent nor counted. A control with the gate
# open and nothing swallowing it must still press and count.
#
# Evidence limit: this checks the hand's press and count against the player's discard
# rule; it does not play a fight.

const TICKS := 10

var _game
var _driver
var _target: Node3D
var _warm := 0
var _done := false
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _bites(swallow: String) -> int:
	var player = _game.player
	_driver._note = {"stage": 1}
	_driver._off_line = 99.0
	_game.player.set_frozen(false)
	player.kit.slingshot.charging = false
	var special = player.abilities.gauge(AbilityState.SPECIAL)
	if special != null:
		special.charging = false
	match swallow:
		"special":
			special.charging = true
		"slingshot":
			player.kit.slingshot.charging = true
		"frozen":
			player.set_frozen(true)
	# Outside the passing radius: the hand waits on a body the ball already sits inside.
	_target.global_position = player.ball_position() + Vector3.RIGHT * 10.0
	player.kit.aim = {"body": _target}
	player.kit.rewind_left = 0.0
	player.state.grounded = true
	for i in TICKS:
		_driver._harpoon_hand(_target, 0.01)
	if special != null:
		special.charging = false
	player.kit.slingshot.charging = false
	player.set_frozen(false)
	return int(_driver._note.get("harpoon_bites", 0))


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", 3)
		_driver.start()
		_target = Node3D.new()
		root.add_child(_target)
		return false
	if not _game.flow.in_stage():
		return false
	_warm += 1
	if _warm < 5:
		return false
	_report("open gate bites", _bites("") >= 1, "a press with nothing swallowing it is counted")
	_report("charging special", _bites("special") == 0, "no bite counted while the special charges")
	_report("charging slingshot", _bites("slingshot") == 0, "no bite counted while the slingshot charges")
	_report("frozen", _bites("frozen") == 0, "no bite counted while the player is frozen")
	_done = true
	print("bot_harpoon_bites_count_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
