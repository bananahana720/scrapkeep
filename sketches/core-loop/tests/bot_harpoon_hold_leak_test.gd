extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The bot's harpoon hand holds RMB and Ctrl only on the ticks a ram lap runs it. A tick
# that reaches _drive by another branch (the walk to the Warden, the caps loop, the
# lapper's phases) must not inherit the last ram-lap tick's hold: a Ctrl held without a
# break keeps player._ctrl_claimed set, which strips the bot's own brakes.
#
# Evidence limit: this checks the hold the bot hands the player on a non-fight tick; it
# says nothing about how the fight plays.

const WARMUP_TICKS := 30

var _game
var _driver
var _ticks := 0
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", 3)
		_driver.start()
		return false
	if not _game.flow.in_stage():
		return false
	_ticks += 1
	if _ticks < WARMUP_TICKS:
		_driver.tick(delta)
		return false
	_game.flow.warden.lesson = "caps"
	_driver._punch_seen = 0.0
	_driver._harpoon_held = true
	_driver._harpoon_commit = true
	_driver.tick(delta)
	var hold: Dictionary = _driver.source.hold
	var goal: String = _driver._goal
	var ram: bool = not goal.begins_with("caps")
	var leaked: bool = hold.has("harpoon_held") or hold.has("brake_held")
	var ok: bool = not ram and not leaked
	print("[no hold leak off the ram lap] goal '%s', hold %s -> %s" % [goal, hold, "PASS" if ok else "FAIL"])
	_done = true
	print("bot_harpoon_hold_leak_test: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
	return true
