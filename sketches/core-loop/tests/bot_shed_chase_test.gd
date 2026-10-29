extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The bot's pickup choice in the bowl (bot_driver.gd _nearest_pickup) after ruling aw. Armour shed
# by a hit lands 9 to 10 m ahead of the ball: the bot takes a shed pile only within SHED_CHASE of
# the ball, and other pickups keep the full chase radius.
#
# Evidence limit: a fake boss lists the piles; the choice alone is checked, not a fight. The fight
# outcomes (park seed 16 rebuilds for a break, park seed 0 from mass 0 stops circling the Furnace)
# come from bot sweeps recorded on the PR.
# smoke: timeout=60s


class FakeGame:
	var bot_driven := false


class FakeBoss:
	var piles: Array = []

	func pickups_left() -> Array:
		return piles


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_shed_chase_test")
	var bot := BotDriver.new(FakeGame.new(), "skipper", 1)
	var boss := FakeBoss.new()
	var ball := Vector3.ZERO
	var near := BotDriver.SHED_CHASE - 1.0
	var far := BotDriver.SHED_CHASE + 4.0
	t.check("the shed radius is well inside the chase radius", BotDriver.SHED_CHASE > 0.0 and BotDriver.SHED_CHASE < BotDriver.PICKUP_CHASE * 0.5,
		"%.1f of %.1f" % [BotDriver.SHED_CHASE, BotDriver.PICKUP_CHASE])
	boss.piles = [{"at": Vector3(far, 0.0, 0.0), "value": 5, "source": "shed"}]
	t.eq("a far shed pile is left", bot._nearest_pickup(boss, ball), Vector3.INF)
	boss.piles.append({"at": Vector3(0.0, 0.0, near), "value": 5, "source": "shed"})
	t.eq("a shed pile within the radius is taken", bot._nearest_pickup(boss, ball), Vector3(0.0, 0.0, near))
	boss.piles = [{"at": Vector3(BotDriver.SHED_CHASE, 0.0, 0.0), "value": 5, "source": "shed"}]
	t.eq("a shed pile on the radius is taken", bot._nearest_pickup(boss, ball), Vector3(BotDriver.SHED_CHASE, 0.0, 0.0))
	boss.piles = [{"at": Vector3(BotDriver.SHED_CHASE + 0.1, 0.0, 0.0), "value": 5, "source": "shed"}]
	t.eq("a shed pile just past the radius is left", bot._nearest_pickup(boss, ball), Vector3.INF)
	boss.piles = [{"at": Vector3(0.0, 0.0, near), "value": 5, "source": "shed"}, {"at": Vector3(0.0, 0.0, -near + 1.0), "value": 5, "source": "returned"}]
	t.eq("a nearer pickup still wins over a shed pile", bot._nearest_pickup(boss, ball), Vector3(0.0, 0.0, -near + 1.0))
	boss.piles = [{"at": Vector3(far, 0.0, 0.0), "value": 5, "source": "shed"}, {"at": Vector3(0.0, 0.0, far + 6.0), "value": 5, "source": "returned"}]
	t.eq("other pickups keep the full chase", bot._nearest_pickup(boss, ball), Vector3(0.0, 0.0, far + 6.0))
	boss.piles = [{"at": Vector3(BotDriver.PICKUP_CHASE + 1.0, 0.0, 0.0), "value": 5}]
	t.eq("nothing past the chase radius", bot._nearest_pickup(boss, ball), Vector3.INF)
	quit(t.verdict())
	return true
