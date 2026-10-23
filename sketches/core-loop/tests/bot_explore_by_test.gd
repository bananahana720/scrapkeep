extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const T := preload("res://tests/support/t.gd")

# The pacing lab's switch (bot_run --explore-by=<s>, scripts/pacing-check.mjs).
# (a) the setting parses a number above ENGAGE_BY, reads an absent flag as 0, and rejects the rest;
# (b) without it the driver keeps ENGAGE_BY and the stall cap it had on every
#     stage, before and after a Warden break, the Mind's crown included;
# (c) with it the cap stretches by exactly (s - ENGAGE_BY).

const EXPECTED_CHECKS := 16

var _t := T.new("bot_explore_by_test")


class SpyRun extends RefCounted:
	var stage := 1


class SpyGame extends RefCounted:
	var bot_driven := false
	var run := SpyRun.new()


func _initialize() -> void:
	_parser()
	_caps()
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	quit(_t.verdict())


func _parser() -> void:
	_t.eq("an absent flag is 0", BotOptions.explore_by({}), 0.0)
	_t.eq("520 parses", BotOptions.explore_by({"explore-by": "520"}), 520.0)
	_t.eq("a fraction parses", BotOptions.explore_by({"explore-by": "300.5"}), 300.5)
	_t.eq("ENGAGE_BY itself is rejected", BotOptions.explore_by({"explore-by": str(BotDriver.ENGAGE_BY)}), -1.0)
	_t.eq("10 is rejected", BotOptions.explore_by({"explore-by": "10"}), -1.0)
	_t.eq("a non-number is rejected", BotOptions.explore_by({"explore-by": "long"}), -1.0)


func _caps() -> void:
	var spy := SpyGame.new()
	var driver := BotDriver.new(spy, "completionist", 3)
	_t.eq("engage_by defaults to ENGAGE_BY", driver.engage_by, BotDriver.ENGAGE_BY)
	# The caps the driver had before the switch, written out from its constants.
	_t.eq("default cap, park stage", driver._stage_cap(), BotDriver.STAGE_LIMIT)
	spy.run.stage = 6
	_t.eq("default cap, the Mind's crown", driver._stage_cap(), BotDriver.PARK_MIND_LIMIT)
	driver._note["warden_broken_s"] = 100.0
	_t.eq("default cap after a break on the crown", driver._stage_cap(), maxf(BotDriver.STAGE_LIMIT, 100.0 + BotDriver.GATE_LIMIT))
	spy.run.stage = 1
	driver._note["warden_broken_s"] = 200.0
	_t.eq("default cap after a late break", driver._stage_cap(), 200.0 + BotDriver.GATE_LIMIT)
	driver._note.erase("warden_broken_s")
	driver.engage_by = 520.0
	var stretch := 520.0 - BotDriver.ENGAGE_BY
	_t.eq("explore cap, park stage", driver._stage_cap(), BotDriver.STAGE_LIMIT + stretch)
	driver._note["warden_broken_s"] = 500.0
	_t.eq("explore cap after a break", driver._stage_cap(), 500.0 + BotDriver.GATE_LIMIT + stretch)
	driver.stage_limit = 900.0
	_t.eq("a sweep's own stage_limit still wins", driver._stage_cap(), 900.0)
	_t.check("the explore cap clears the 600 s park band", BotDriver.STAGE_LIMIT + stretch > 600.0)
