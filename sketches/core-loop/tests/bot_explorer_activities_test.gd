extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The explorer (the completionist policy) on the slice table works the standing activities
# before the Warden (alpha unit EB). One seeded run, at most 60 game seconds: the bot's first
# target must be one of the map's activity sites (src/world/activities.gd), its goal must read
# "activity ...", and by the end it must have entered one site and finished at least one, with
# the Warden not yet engaged. Without the activity targeting the first goal is a scrap line or the
# Warden and the first check fails.
#
# Evidence limit: one seed of the headless bot; it says nothing about the 16-seed band or feel.

const SEED := 1
const TICK_LIMIT := 90 * 60

var _game
var _driver
var _t := T.new("bot_explorer_activities_test")
var _ticks := 0
var _first_target := ""
var _first_goal := ""
var _site_ids: Array = []
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	if _driver == null:
		_driver = BotDriver.new(_game, "completionist", SEED)
		_driver.start()
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	if _first_goal == "" and _driver._goal != "":
		_first_goal = _driver._goal
		_first_target = _driver._activity
		_site_ids.clear()
		if _game.world != null and _game.world.activities != null:
			for s in _game.world.activities.sites:
				_site_ids.append(s.id)
	var finished: Array = _driver._note.get("activities_finished", [])
	if over or _ticks > TICK_LIMIT or (_first_goal != "" and not finished.is_empty()):
		_finish(over)
		return true
	return false


func _finish(over: bool) -> void:
	_done = true
	# 2026-10-04: the alpha maps add an enemy_camp site beside the slice's three, so four.
	_t.check("the stage builds its four activity sites", _site_ids.size() == 4 and "enemy_camp" in _site_ids,
		"sites %s" % [_site_ids])
	_t.check("the first target is an activity site, not the Warden",
		_first_target in _site_ids and _first_goal.begins_with("activity "),
		"first target '%s', first goal '%s', sites %s" % [_first_target, _first_goal, _site_ids])
	var entered: Array = _driver._note.get("activities_entered", [])
	var finished: Array = _driver._note.get("activities_finished", [])
	_t.check("one activity entered and finished inside the budget", not entered.is_empty() and not finished.is_empty(),
		"entered %s, finished %s after %.1f s (outcome '%s')" % [entered, finished, float(_ticks) / 90.0, _driver.outcome])
	_t.check("the Warden is not engaged yet", _driver._note.get("warden_engaged_s") == null and not over,
		"engaged at %s" % [_driver._note.get("warden_engaged_s")])
	_game.free()
	quit(_t.verdict())
