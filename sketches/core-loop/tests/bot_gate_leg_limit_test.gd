extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# Red team w15 sweep b1, completionist seed 35118 (Pylon): the stage-6 Warden broke at 230.67 s
# and the run ended "stalled" at 240.01 s with stall_state "gates", on its way up to gate 1. The
# stage clock (STAGE_LIMIT) counted the gate leg against the Warden's time. Pins: before a break
# the limit is stage_limit; after one it is at least GATE_LIMIT past the break, so a gate the bot
# cannot reach still stalls.
#
# Evidence limit: the limit's arithmetic only; whether the bot then reaches the gate is the
# 35118 replay in redteam/w15/warden-stall/DIAGNOSIS.md.


class FakeRun:
	var stage := 1


class FakeGame:
	var bot_driven := false
	var run := FakeRun.new()


var _t := T.new("bot_gate_leg_limit_test")


func _initialize() -> void:
	var driver = BotDriver.new(FakeGame.new(), "completionist", 35118)
	driver._note = {"warden_broken_s": null}
	_t.near("before a break the limit is the stage limit", driver._stage_cap(), BotDriver.STAGE_LIMIT)
	driver._note["warden_broken_s"] = 230.67
	_t.near("a late break gets the gate leg", driver._stage_cap(), 230.67 + BotDriver.GATE_LIMIT)
	driver._note["warden_broken_s"] = 40.0
	_t.near("an early break keeps the stage limit", driver._stage_cap(), BotDriver.STAGE_LIMIT)
	driver.stage_limit = 600.0
	driver._note["warden_broken_s"] = 230.67
	_t.near("a sweep's longer stage limit still wins", driver._stage_cap(), 600.0)
	_t.near("GATE_LIMIT is 90 s (merge 2026-10-17: STAGE6 exits needed up to 26 s plus a run-up; PR 34 had 60)", BotDriver.GATE_LIMIT, 90.0)
	driver.stage_limit = BotDriver.STAGE_LIMIT
	driver._note["warden_broken_s"] = null
	driver.game.run.stage = 6
	_t.near("stage 6 before a break gets the Mind cap", driver._stage_cap(), BotDriver.PARK_MIND_LIMIT)
	quit(_t.verdict())
