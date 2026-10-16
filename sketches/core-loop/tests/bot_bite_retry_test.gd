extends SceneTree

const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# The harpoon hand's bite in bot_driver.gd _harpoon_hand (FINAL-STALL item 3). A press that
# took no line is pressed again no sooner than a player's re-click, never once a tick: pressed every
# tick against a refusal, Rivet sat at a fixed velocity in the stage-6 boss (seed 1, late offer taken)
# and the run slowed past its wall cap. The kit refuses every press here; the line skill, the casts and the
# chain hand are stubbed out. A line that does hook is held, and the bite after it ends is not delayed.

const TARGET := Vector3(0.0, 1.0, 0.0)
const STEP := 1.0 / 90.0
# A fast player's re-click rate: at most this many presses a second.
const CLICKS_PER_SECOND := 5


class FakeGauge:
	var charging := false


class FakeKit:
	var hooked := false
	var on_body := false
	var anchor_body: Node3D = null
	var line_state := 0
	var rewind_left := 0.0
	var aim := {}
	var slingshot := FakeGauge.new()


class FakeState:
	var grounded := true


class FakeAbilities:
	func id_of(_row: String) -> String:
		return "line_drive"

	func gauge(_row: String):
		return null


class FakePlayer:
	var at := Vector3(6.0, 1.0, 0.0)
	var kit := FakeKit.new()
	var state := FakeState.new()
	var abilities := FakeAbilities.new()
	var _brake_was_held := false

	func ball_position() -> Vector3:
		return at

	func frozen() -> bool:
		return false


class FakeGame:
	var bot_driven := false
	var player := FakePlayer.new()


class Probe extends BotDriver:
	var counts := {}

	func _init(game_ref) -> void:
		super(game_ref, "skipper", 1)

	func _cast(_slot: int, _hold_seconds := 0.0) -> bool:
		return false

	func _count(key: String, by: float = 1.0) -> void:
		counts[key] = counts.get(key, 0) + by


var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var t := T.new("bot_bite_retry_test")
	var target := Node3D.new()
	root.add_child(target)
	target.global_position = TARGET

	var game := FakeGame.new()
	game.player.kit.aim = {"body": target}
	var probe := Probe.new(game)
	probe.chain_hand_enabled = false
	probe._off_line = BotDriver.DROP_MEMORY + 1.0
	var presses := _second(probe, target)
	t.check("refused bites: at most a re-click rate", presses <= CLICKS_PER_SECOND, "%d presses in one second" % presses)
	t.check("refused bites: still pressed again", presses >= 2, "%d presses in one second" % presses)

	# Control: a line that hooks is held, not pressed again.
	var hgame := FakeGame.new()
	hgame.player.kit.aim = {"body": target}
	hgame.player.kit.hooked = true
	hgame.player.kit.on_body = true
	hgame.player.kit.anchor_body = target
	var held := Probe.new(hgame)
	held.chain_hand_enabled = false
	held._off_line = BotDriver.DROP_MEMORY + 1.0
	t.eq("hooked line: no new press", _second(held, target), 0)
	t.eq("hooked line: the harpoon is held", held._harpoon_held, true)

	# Control: a press whose line stands for a few ticks and then ends is followed at once.
	var lgame := FakeGame.new()
	lgame.player.kit.aim = {"body": target}
	var relined := Probe.new(lgame)
	relined.chain_hand_enabled = false
	relined._off_line = BotDriver.DROP_MEMORY + 1.0
	_tick(relined, target)
	lgame.player.kit.hooked = true
	lgame.player.kit.on_body = true
	lgame.player.kit.anchor_body = target
	for i in 5:
		_tick(relined, target)
	lgame.player.kit.hooked = false
	lgame.player.kit.on_body = false
	lgame.player.kit.anchor_body = null
	t.eq("ended line: the next bite is pressed at once", _tick(relined, target), true)

	target.free()
	quit(t.verdict())
	return false


# One second of hand ticks. tick() counts the retry wait down before the hand runs; the probe does
# the same through get/set, so a driver without the wait runs unchanged. Returns the presses made.
func _second(probe: Probe, target: Node3D) -> int:
	var presses := 0
	for i in 90:
		if _tick(probe, target):
			presses += 1
	return presses


# One hand tick; true when it pressed the harpoon.
func _tick(probe: Probe, target: Node3D) -> bool:
	var wait = probe.get("_bite_wait")
	if wait != null:
		probe.set("_bite_wait", float(wait) - STEP)
	probe.ticks += 1
	probe.source.press.clear()
	probe._harpoon_hand(target, STEP)
	return probe.source.press.get("harpoon_pressed", false)
