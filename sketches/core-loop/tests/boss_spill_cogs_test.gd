extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")

# Brindle's arena pickups and the wallet: a phase-break spill and a drone kill pay one cog
# per scrap unit on top of the mass, while the crane's returned trail (the ball's own stolen
# mass rolling back) pays mass only. Each source is forced through its own spawner: the spill
# through _spill_break, the kill through the bus's enemy_killed (a "lobber" in the arena),
# the returned trail through _drip on a crane holding a one-pickup trail. The ball is then put
# on the pickup and the fight advanced one step, so _step_trail collects it.
#
# Evidence limit: the spawners are called directly; this does not break a phase, kill a
# drone or get caught by a crane in play.

const DT := 1.0 / 90.0

var _game
var _boss
var _failures := 0
var _cogs_heard: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# Rolls the ball onto the newest pickup and returns [value, scrap delta, cogs delta, pickups taken].
func _roll_over_last() -> Array:
	var left: Array = _boss.pickups_left()
	var p: Dictionary = left[left.size() - 1]
	var run = _game.run
	var scrap_before: int = run.scrap
	var cogs_before: int = run.cogs
	Harness.put_ball(_game, p["at"])
	_boss.advance(DT)
	return [p["value"], run.scrap - scrap_before, run.cogs - cogs_before, left.size() - _boss.pickups_left().size()]


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.cogs_collected.connect(func(amount: int, total: int): _cogs_heard.append([amount, total]))
	Harness.install(_game)
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	_boss = _game.boss
	_report("in the arena", _boss.active() and _game.flow.state_name() == "boss",
		"boss active %s, flow %s" % [_boss.active(), _game.flow.state_name()])

	# Spill: the phase-break ring; the ball takes one of its pickups.
	_boss._spill_break()
	var spill: Array = _roll_over_last()
	_report("spill pays mass and cogs", spill[3] == 1 and spill[1] == spill[0] and spill[2] == spill[0],
		"value %d: scrap +%d, cogs +%d, %d taken" % spill)

	# Kill: a lobber dies in the arena and drops its scrap where it died, across the bowl from the ship, so the
	# spill ring the ship just dropped is out of the ball's reach wherever the entry puts the ship.
	var spot: Vector3 = Harness.ground_spot(_boss, _boss._ship_angle + PI, 14.0)
	_game.events.enemy_killed.emit("lobber", spot, 5)
	var kill: Array = _roll_over_last()
	_report("kill pays mass and cogs", kill[3] == 1 and kill[0] == 5 and kill[1] == 5 and kill[2] == 5,
		"value %d: scrap +%d, cogs +%d, %d taken" % kill)

	# Returned: a crane drips the scrap it stole back onto the ground as a trail.
	_boss._cranes[0] = {"hazard": null, "caught": true, "held": 6, "trail": [Harness.ground_spot(_boss, 2.5, 14.0)],
		"values": [6], "dripped": 0, "drip": 0.0}
	_boss._drip(_boss._cranes[0])
	var heard_before: int = _cogs_heard.size()
	var returned: Array = _roll_over_last()
	_report("trail pays mass only", returned[3] == 1 and returned[0] == 6 and returned[1] == 6 and returned[2] == 0
			and _cogs_heard.size() == heard_before,
		"value %d: scrap +%d, cogs +%d, %d taken; cogs_collected heard %d time(s)" % (returned + [_cogs_heard.size() - heard_before]))

	# The wallet the HUD and the summary read is run.cogs, and the bus announced each payment.
	var cogs: int = _game.run.cogs
	var summary: Dictionary = _game.run.summary()
	var announced: bool = _cogs_heard.size() == 2 and _cogs_heard[0][0] == spill[0] and _cogs_heard[1] == [5, cogs]
	_report("wallet is run.cogs", summary["cogs"] == cogs and cogs >= spill[2] + kill[2] and announced,
		"run.cogs %d, summary cogs %d, cogs_collected %s" % [cogs, summary["cogs"], _cogs_heard])

	print("boss_spill_cogs_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
