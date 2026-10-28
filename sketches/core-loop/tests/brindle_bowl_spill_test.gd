extends SceneTree

# Ruling aw (Brindle stall tail, park seed 16 and cannon seed 1): in the bowl an armour hit's
# spill was destroyed, cranes only steal in phase 1, and a stripped ball at heft 1.0 could
# never rebuild mass for a break. An armour hit in the fight now spills the way a stage hit
# does: the 75% spill share lands as shed piles ahead of the ball, inside the floor, paying
# back through recover_mass like a stage cluster (mass only: no wallet scrap, no cogs, no
# fresh scrap), and an unreached pile counts as expired, so hit loss still balances into
# destroyed + recovered + expired. With no fight on, the spill is destroyed as before.
# smoke: timeout=150s

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Arena := preload("res://src/boss/arena.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const RunState := preload("res://src/core/run_state.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("brindle_bowl_spill_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	_game.ctx.calm = true
	var flow = _game.flow
	flow.enter_stage(_game.ctx.stages.last_of(1), Vector3.ZERO, false)
	flow.enter_boss(Vector3.ZERO)
	await physics_frame
	var boss = _game.ctx.boss
	var run = _game.ctx.run
	_t.check("the fight is on", boss.active() and not flow.in_stage(), "boss %s" % boss.state_name())
	run.grant_start_mass(300.0)
	var held: int = boss._pickups.size()
	var mass_pre: float = run.mass
	var destroyed_pre: float = run.metrics["destroyed"]
	var arena_pre: float = run.metrics["arena_destroyed"]
	var cogs_pre: int = run.cogs
	var wallet_pre: int = run.scrap
	var fresh_pre: float = run.metrics["fresh"]
	var recovered_pre: float = run.metrics["recovered"]
	var expired_pre: float = run.metrics["expired"]
	run.damage(10.0, "brindle_charge")
	var lost: float = mass_pre - run.mass
	var spill := int(round(lost * RunState.SPILL_SHARE))
	var landed: Array = boss._pickups.slice(held)
	var total := 0
	for p in landed:
		total += int(p["value"])
	_t.check("an arena hit spills its share as returned piles", lost > 0.0 and landed.size() == mini(Rules.SPILL_PILES, spill)
			and landed.all(func(p): return p["source"] == "shed") and total == spill,
		"lost %.0f, spill %d, %d piles worth %d" % [lost, spill, landed.size(), total])
	_t.eq("none of the spill share is destroyed", run.metrics["arena_destroyed"] - arena_pre, 0.0)
	_t.check("only the unspilled quarter is destroyed", is_equal_approx(run.metrics["destroyed"] - destroyed_pre, lost - spill),
		"destroyed +%.1f of %.1f lost" % [run.metrics["destroyed"] - destroyed_pre, lost])
	var centre: Vector3 = boss.arena.global_position
	_t.check("every pile lands on the floor", landed.all(func(p): return Vector2(p["at"].x - centre.x, p["at"].z - centre.z).length() <= Arena.FLOOR_R - 3.9),
		str(landed.map(func(p): return p["at"])))
	var mass_mid: float = run.mass
	for p in landed:
		boss._step_trail(p["at"])
	_t.check("rolling the piles up pays the mass back", is_equal_approx(run.mass - mass_mid, float(total)) and boss._pickups.size() == held,
		"mass +%.0f of %d" % [run.mass - mass_mid, total])
	_t.eq("shed piles never mint cogs", run.cogs, cogs_pre)
	_t.eq("shed piles never fill the wallet", run.scrap, wallet_pre)
	_t.eq("shed piles count as recovered, not fresh", [run.metrics["recovered"] - recovered_pre, run.metrics["fresh"] - fresh_pre], [float(total), 0.0])
	# A pile nobody reaches in PICKUP_LIFE is gone, and counts as expired.
	boss.take_spill(centre, Vector3.FORWARD, 5)
	var waits := 0
	while boss._pickups.size() > held and waits < 4000:
		boss._step_trail(centre + Vector3(0.0, 200.0, 0.0))
		waits += 1
	_t.eq("an unreached shed pile expires into the ledger", run.metrics["expired"] - expired_pre, 5.0)
	# Edge: a ball already at the wall throws its fan back inside the floor.
	boss.take_spill(centre + Vector3(Arena.FLOOR_R - 1.0, 0.0, 0.0), Vector3.RIGHT, 6)
	var walled: Array = boss._pickups.slice(held)
	_t.check("a hit at the wall keeps its piles on the floor", walled.size() == 6
			and walled.all(func(p): return Vector2(p["at"].x - centre.x, p["at"].z - centre.z).length() <= Arena.FLOOR_R - 3.9),
		str(walled.map(func(p): return p["at"])))
	# No fight on: the spill has nowhere to land and is destroyed, as before the ruling.
	boss.state = boss.DEFEATED
	var count: int = boss._pickups.size()
	arena_pre = run.metrics["arena_destroyed"]
	mass_pre = run.mass
	run.damage(10.0, "test")
	lost = mass_pre - run.mass
	_t.check("with no fight on the spill is destroyed", lost > 0.0 and boss._pickups.size() == count
			and is_equal_approx(run.metrics["arena_destroyed"] - arena_pre, round(lost * RunState.SPILL_SHARE)),
		"lost %.0f, arena destroyed +%.0f, piles %d" % [lost, run.metrics["arena_destroyed"] - arena_pre, boss._pickups.size() - count])
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())
