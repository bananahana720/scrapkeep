extends SceneTree

# World 1 unit 9: the Slag Bowl's Fleet yard plays the fight's phase turns (PR #391's fight_phase_changed) and never
# feeds the fight. Arrival cheers once; each turn cheers across the transition beat, heats the melt and rounds the
# ledger up; a weak-point hit hops; another fight's turn is ignored; the rout cools the melt; idle, it stops working.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")
const FightPhases := preload("res://src/combat/fight_phases.gd")
const T := preload("res://tests/support/t.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Palette := preload("res://src/core/palette.gd")

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
	for row: Dictionary in Yard.MELT:
		var hue: float = row.color.h * 360.0
		t.check("melt keeps off the slag and klaxon hues: %s" % row.color.to_html(false), hue >= Yard.MELT_MIN_HUE
			and hue - Hazard.MOLTEN.h * 360.0 >= 10.0 and hue - Palette.HAZARD.h * 360.0 >= 10.0, "%.1f deg" % hue)
	_settle(yard)
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
	_step(yard, beat * 0.5)
	t.eq("the cheer holds through the transition beat", yard.cheering(), "phase")
	game.events.boss_weak_point_hit.emit("hatch")
	await process_frame
	t.eq("a small hop never cuts a phase cheer short", yard.cheering(), "phase")
	_settle(yard)
	var hot: float = yard.melt_material.emission_energy_multiplier
	t.check("phase two melt runs hotter", is_equal_approx(hot, Yard.MELT[2].emission) and hot > cool, "%.3f" % hot)
	t.check("the melt glows by its own emission, no runtime light", yard.find_children("*", "Light3D", true, false).is_empty())

	game.events.boss_weak_point_hit.emit("hatch")
	await process_frame
	t.eq("a weak-point hit gets its own hop", yard.cheering(), "weak_point")

	# A turn that lands mid-blend starts from the heat on show: no pop (a short transition_mult can do this).
	yard._on_fight_phase("brindle", 1, 3)
	_step(yard, 0.5)
	var shown: float = yard.melt_material.emission_energy_multiplier
	game.boss.jump_to_phase(3)
	yard._process(1.0 / 600.0)
	t.check("a turn mid-blend never pops the glow", absf(yard.melt_material.emission_energy_multiplier - shown) < 0.05,
		"%.3f -> %.3f" % [shown, yard.melt_material.emission_energy_multiplier])
	await process_frame
	t.eq("phase three: all of them", yard.ledger_line.text, Yard.LEDGER[3])
	_settle(yard)
	t.check("phase three melt is white-gold", is_equal_approx(yard.melt_material.emission_energy_multiplier, Yard.MELT[3].emission))

	game.events.boss_defeated.emit()
	await process_frame
	t.eq("the rout cheers longest", yard.cheering(), "rout")
	t.eq("the ledger never balances", yard.ledger_line.text, Yard.LEDGER[0])
	_settle(yard)
	t.check("the rout's cheer and cooling end", not yard.is_processing())
	t.check("the rout cools the melt to embers", is_equal_approx(yard.melt_material.emission_energy_multiplier, Yard.MELT[0].emission))
	_finish()


# The yard is stepped by hand on a fixed 60 Hz clock, never by waiting: no frame runs in between, so no wall clock
# leaks in, and the rout's hand-off to the next world never gets a frame to start.
func _step(yard, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		yard._process(1.0 / 60.0)


func _settle(yard) -> void:
	for i in 600:
		if not yard.is_processing():
			return
		yard._process(1.0 / 60.0)


func _finish() -> void:
	game.free()
	quit(t.verdict())
