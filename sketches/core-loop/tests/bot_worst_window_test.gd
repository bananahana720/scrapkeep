extends SceneTree

# The bot record's worst 60 s window (bot_driver.gd note_worst_window, W1-31): the sums over the hits still inside the
# window, the peak kept, the max hull noted when the hull peak rises, and old hits leaving as the clock moves on.
# Record maths only, no game: the clearing on stage and boss entry is two plain assignments in the driver.

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED_CHECKS := 10

var _t := T.new("bot_worst_window_test")


func _initialize() -> void:
	var hits: Array = []
	var into := {}
	BotDriver.note_worst_window(hits, into, 0.0, 12.0, 10.0, 120.0)
	BotDriver.note_worst_window(hits, into, 30.0, 20.0, 20.0, 120.0)
	BotDriver.note_worst_window(hits, into, 59.9, 5.0, 5.0, 130.0)
	_t.eq("three hits in 60 s sum their hull", into["worst_60s_hull"], 35.0)
	_t.eq("and their whole hits", into["worst_60s_hp"], 37.0)
	_t.eq("max hull noted at the hull peak", into["worst_60s_max_hp"], 130.0)
	BotDriver.note_worst_window(hits, into, 60.0, 1.0, 1.0, 140.0)
	_t.eq("the hit at 0 s leaves at 60 s", hits.size(), 3)
	_t.eq("a lower window keeps the peak", into["worst_60s_hull"], 35.0)
	_t.eq("and keeps the peak's max hull", into["worst_60s_max_hp"], 130.0)
	BotDriver.note_worst_window(hits, into, 200.0, 50.0, 50.0, 150.0)
	_t.eq("a hit after a long gap stands alone", hits.size(), 1)
	_t.eq("and sets a new peak", into["worst_60s_hull"], 50.0)
	_t.eq("with the max hull of that moment", into["worst_60s_max_hp"], 150.0)
	_t.eq("check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())
