extends SceneTree

# World 1 unit 9: the Slag Bowl's Fleet yard plays the fight's phase turns (PR #391's fight_phase_changed) and never
# feeds the fight. Arrival cheers once; each turn cheers across the transition beat, heats the melt and rounds the
# ledger up; a weak-point hit hops; another fight's turn is ignored; the rout cools the melt; idle, it stops working.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")
const FightPhases := preload("res://src/combat/fight_phases.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("dress_arb_yard_test")
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	Harness.enter(game, Vector3(18, 0, 0))
	await physics_frame
	var yard = game.boss.arena.get_node_or_null("ArenaBowlDress/FleetYard")
	t.check("the bowl has its Fleet yard", yard != null)
	if yard == null:
		_finish()
		return
	t.eq("arrival: the stands cheer as the ball lands", yard.cheering(), "arrival")
	t.eq("phase one on the ledger", yard.ledger_line.text, Yard.LEDGER[1])
	await _settle(yard)
	t.check("idle, the yard does no per-frame work", not yard.is_processing())
	var cool: float = yard.melt_material.emission_energy_multiplier
	t.check("phase one melt is an ember", is_equal_approx(cool, Yard.MELT[1].emission), "%.3f" % cool)

	game.events.fight_phase_changed.emit("rogue_crane", 2, 2)
	await process_frame
	t.eq("another fight's turn is ignored", yard.phase, 1)

	game.boss.jump_to_phase(2)
	await process_frame
	t.eq("the turn into phase two cheers", yard.cheering(), "phase")
	t.eq("the ledger rounds up", yard.ledger_line.text, Yard.LEDGER[2])
	var beat := FightPhases.boss("brindle").transition()
	await create_timer(beat * 0.5).timeout
	t.eq("the cheer holds through the transition beat", yard.cheering(), "phase")
	game.events.boss_weak_point_hit.emit("hatch")
	await process_frame
	t.eq("a small hop never cuts a phase cheer short", yard.cheering(), "phase")
	await _settle(yard)
	var hot: float = yard.melt_material.emission_energy_multiplier
	t.check("phase two melt runs hotter", is_equal_approx(hot, Yard.MELT[2].emission) and hot > cool, "%.3f" % hot)
	t.check("the ladle lights follow the melt", yard.lights.all(func(l): return is_equal_approx(l.light_energy, Yard.MELT[2].light)))

	game.events.boss_weak_point_hit.emit("hatch")
	await process_frame
	t.eq("a weak-point hit gets its own hop", yard.cheering(), "weak_point")

	game.boss.jump_to_phase(3)
	await process_frame
	t.eq("phase three: all of them", yard.ledger_line.text, Yard.LEDGER[3])
	await _settle(yard)
	t.check("phase three melt is white-gold", is_equal_approx(yard.melt_material.emission_energy_multiplier, Yard.MELT[3].emission))

	game.events.boss_defeated.emit()
	await process_frame
	t.eq("the rout cheers longest", yard.cheering(), "rout")
	t.eq("the ledger never balances", yard.ledger_line.text, Yard.LEDGER[0])
	# The rout hands the run on to the next world, so the yard is stepped by hand from here, not by waiting.
	for i in 60:
		yard._process(0.1)
	t.check("the rout's cheer and cooling end", not yard.is_processing())
	t.check("the rout cools the melt to embers", is_equal_approx(yard.melt_material.emission_energy_multiplier, Yard.MELT[0].emission))
	_finish()


func _settle(yard) -> void:
	var waited := 0.0
	while yard.is_processing() and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1


func _finish() -> void:
	game.free()
	quit(t.verdict())
