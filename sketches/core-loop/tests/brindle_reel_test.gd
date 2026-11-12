extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const UltimateMeter := preload("res://src/core/ultimate_meter.gd")

# The reel (W1-61). A chunk broken before its phase floor holds the phase (ruling bs), and for
# the rest of that floor Brindle reels: he commits no new attack, and each hull hit, at most one
# per Rules.REEL_GAP and Rules.REEL_HITS a reel, sheds Rules.REEL_SCRAP as pickups that pay scrap
# and cogs, and fills the ultimate through boss_reeled. An open phase sheds nothing, and the
# floors (Rules.PHASE_MIN_SECONDS) still turn the phase.
#
# The fight runs through the game's own combat module, as brindle_held_bank_test does: strikes
# are a physics frame apart and time is stepped with advance(DT).
#
# Evidence limit: combat.strike() stands in for the ball's contacts; the meter is read from its
# own record, not from the HUD; the reel's look is the effects thread's.

const DT := 1.0 / 90.0
const RAM_FORCE := 150.0

var _game
var _boss
var _combat
var _failures := 0
var _reels := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _above() -> void:
	Harness.put_ball(_game, _boss.arena.global_position + Vector3.UP * 40.0)


func _hit(target, kind: String, force: float) -> void:
	_above()
	_combat.strike(target, kind, force)
	await physics_frame


func _advance(seconds: float) -> void:
	for _i in int(ceil(seconds / DT)):
		_above()
		_boss.advance(DT)


func _stagger_by_rams(hull) -> int:
	var rams := 0
	while not _boss.staggered() and rams < 8:
		await _hit(hull, "ram", RAM_FORCE)
		rams += 1
	return rams


# Breaks the live phase's chunk: a crack in one opening, the shatter in the next.
func _break_chunk(hull) -> void:
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)
	_advance(BossPosture.STAGGER_SECONDS + 0.1)
	await _stagger_by_rams(hull)
	await _hit(hull, "ram", RAM_FORCE)


func _reel_pickups() -> Array:
	return _boss.pickups_left().filter(func(p): return p["source"] == "reel")


func _reel_value() -> int:
	var total := 0
	for p in _reel_pickups():
		total += int(p["value"])
	return total


func _reel_points() -> float:
	return float(_game.player.abilities.meter.sources.get("reel", 0.0))


func _hazard_ids() -> Array:
	return _boss.active_hazards().map(func(h): return h.get_instance_id())


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_combat = _game.combat
	_game.ctx.spawner = _combat
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.boss_reeled.connect(func(_at: Vector3, _scrap: int): _reels += 1)
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	var hull = _boss.ship.hull
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)

	# An open phase: hull hits shed nothing and pay no reel.
	await _hit(hull, "ram", RAM_FORCE)
	_advance(Rules.REEL_GAP + 0.1)
	await _hit(hull, "ram", RAM_FORCE)
	_report("an open phase does not reel", not _boss.reeling() and _reel_pickups().is_empty() and _reels == 0 and _reel_points() == 0.0,
		"reeling %s, %d reel pickups, %d reel events, %.1f reel points" % [_boss.reeling(), _reel_pickups().size(), _reels, _reel_points()])

	# Break the Requisition's chunk early: the phase holds and the reel starts.
	await _break_chunk(hull)
	var broke_at: float = _boss.phase_clock
	_report("an early chunk starts the reel", _boss.phase == 1 and _boss.chunks_left() == 3 and broke_at < Rules.PHASE_MIN_SECONDS[0]
			and _boss.reeling(),
		"chunk broken %.1f s into a %.0f s floor; reeling %s" % [broke_at, Rules.PHASE_MIN_SECONDS[0], _boss.reeling()])

	# No new attack while he reels: no hazard committed after the break, over two crane periods.
	var before := _hazard_ids()
	var fresh := 0
	for _i in int(ceil(2.0 * Rules.CRANE_PERIOD / DT)):
		_above()
		_boss.advance(DT)
		for id in _hazard_ids():
			if not id in before:
				fresh += 1
				before.append(id)
	_report("the reel commits no new attack", fresh == 0 and _boss.reeling(),
		"%d hazards committed over %.1f s of reel" % [fresh, 2.0 * Rules.CRANE_PERIOD])

	# A burst of hits inside one gap pays one reel hit; a hit after the gap pays the next.
	var meter_before: float = _reel_points()
	for _i in 4:
		await _hit(hull, "ram", RAM_FORCE)
	var burst_pickups := _reel_pickups()
	var burst_scrap := 0
	for p in burst_pickups:
		burst_scrap += int(p["value"])
	var burst_reels := _reels
	_advance(Rules.REEL_GAP + 0.05)
	await _hit(hull, "arc", 1.0e6)
	_report("each gapped hull hit sheds scrap and fills the ultimate", burst_reels == 1 and burst_pickups.size() == Rules.REEL_PICKUPS
			and burst_scrap == Rules.REEL_SCRAP and _reels == 2 and _reel_pickups().size() == 2 * Rules.REEL_PICKUPS
			and is_equal_approx(_reel_points() - meter_before, 2.0 * float(UltimateMeter.WEIGHTS["reel"])),
		"four hits in one gap: %d reel event, %d pickups worth %d; a shot after the gap made %d events; meter paid %.1f"
			% [burst_reels, burst_pickups.size(), burst_scrap, _reels, _reel_points() - meter_before])

	# The pickups lie between the hull and the ball, on the floor, and pay scrap and cogs.
	var p0: Dictionary = _reel_pickups()[0]
	var ship_at: Vector3 = _boss.ship.global_position
	var from_hull := Vector2(p0["at"].x - ship_at.x, p0["at"].z - ship_at.z).length()
	var cogs_before: int = _game.run.cogs
	var scrap_before: int = _reel_value()
	Harness.put_ball(_game, p0["at"])
	_boss.advance(DT)
	var taken: int = scrap_before - _reel_value()
	_report("reel pickups pay scrap and cogs", from_hull > Rules.REEL_REACH - Rules.REEL_SPREAD - 0.5
			and taken >= int(p0["value"]) and _game.run.cogs - cogs_before == taken,
		"pickup %.1f m from the hull centre; rolling over it took %d scrap of reel pickups and paid %d cogs"
			% [from_hull, taken, _game.run.cogs - cogs_before])

	# The reel caps its hits.
	for _i in Rules.REEL_HITS + 3:
		_advance(Rules.REEL_GAP + 0.02)
		await _hit(hull, "ram", RAM_FORCE)
	_report("a reel pays at most REEL_HITS hits", _reels == Rules.REEL_HITS and _boss.phase == 1,
		"%d reel events after %d gapped hits (cap %d)" % [_reels, Rules.REEL_HITS + 5, Rules.REEL_HITS])

	# The floor still turns the phase, and the next phase opens unreeled and attacking.
	_advance(Rules.PHASE_MIN_SECONDS[0] - _boss.phase_clock - 0.5)
	var still_one: bool = _boss.phase == 1
	_advance(1.0)
	_advance(FightPhases.TRANSITION_SECONDS + 3.0)
	_report("the floor is unchanged and the next phase attacks", still_one and _boss.phase == 2 and not _boss.reeling()
			and not _boss.active_hazards().is_empty(),
		"phase 1 at %.1f s %s; phase %d reeling %s with %d hazards drawn"
			% [Rules.PHASE_MIN_SECONDS[0] - 0.5, still_one, _boss.phase, _boss.reeling(), _boss.active_hazards().size()])

	# The Scuttle reels too: no charge commits while its chunk is broken and the floor runs.
	_boss.jump_to_phase(3)
	_advance(FightPhases.TRANSITION_SECONDS + 0.05)
	await _break_chunk(hull)
	var scuttle_reel: bool = _boss.phase == 3 and _boss.chunks_left() == 1 and _boss.reeling()
	_advance(minf(6.0, Rules.PHASE_MIN_SECONDS[2] - _boss.phase_clock - 0.5))
	var charge_state: String = _boss._charge.get("state", "")
	var charge_live: bool = _boss._charge.has("hazard") and is_instance_valid(_boss._charge["hazard"]) and not _boss._charge["hazard"].is_done()
	_report("the Scuttle's reel commits no charge", scuttle_reel and not charge_live and charge_state in ["rest", "recover", "stun"],
		"reeling %s; charge %s, live lane %s" % [scuttle_reel, charge_state, charge_live])

	print("brindle_reel_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
