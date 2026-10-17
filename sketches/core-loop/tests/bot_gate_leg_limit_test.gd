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


class FakeGame:
	var bot_driven := false


var _t := T.new("bot_gate_leg_limit_test")


func _initialize() -> void:
	var driver = BotDriver.new(FakeGame.new(), "completionist", 35118)
	driver._note = {"warden_broken_s": null}
	_t.near("before a break the limit is the stage limit", driver._stage_limit_now(), BotDriver.STAGE_LIMIT)
	driver._note["warden_broken_s"] = 230.67
	_t.near("a late break gets the gate leg", driver._stage_limit_now(), 230.67 + BotDriver.GATE_LIMIT)
	driver._note["warden_broken_s"] = 40.0
	_t.near("an early break keeps the stage limit", driver._stage_limit_now(), BotDriver.STAGE_LIMIT)
	driver.stage_limit = 600.0
	driver._note["warden_broken_s"] = 230.67
	_t.near("a sweep's longer stage limit still wins", driver._stage_limit_now(), 600.0)
	quit(_t.verdict())
