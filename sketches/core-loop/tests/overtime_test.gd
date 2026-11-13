extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const Overtime := preload("res://src/world/overtime.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Reservoir on the dam yard (src/world/overtime.gd, docs/design/loops.md Spec 2), on the real
# park_dam: the flag is off by default and a won yard then offers nothing; with --overtime=on a won
# yard (stage_locks.gd _unlock) offers the bell, the pot and the sluice; each ring lands the row's
# last wave plus a plated brute as yard crew, three at most; a ram at speed rings the bell and a
# slow touch does not; the pot pays by rings and ends the overtime; the sluice warns, floods for its
# rung length, soaks the machines (wet armour) and carries the ball along the flow; an arc hit on a
# soaked machine jumps once to the soaked machines near it; leaving the stage clears it all.
# Evidence limit: the rules and the wiring, not a played yard; whether the gamble pulls a player
# back is the sitting's question.

var _t := T.new("overtime_test")
var _facts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(3)
	_rows()
	await _off()
	await _on()
	quit(_t.verdict())


func _game(flags: PackedStringArray):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.player.tuning.apply_args(flags)
	_facts = []
	game.events.world_fact.connect(func(kind: String, at: Vector3): _facts.append(kind))
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	game.ctx.calm = true
	return game


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _count(kind: String) -> int:
	return _facts.count(kind)


func _rows() -> void:
	for kind in ["overtime_offered", "overtime_rung", "overtime_paid", "sluice_warning", "sluice_open"]:
		_t.check("%s has a WORLD_ROWS row" % kind, not EventKinds.world_row(kind).is_empty())
	_t.check("the dam's lock names a flow", (LockRows.row("park_dam")["lock"]["overtime"]["flow"] as Array).size() == 3)
	_t.eq("the pot by rings", [Overtime.pot_for(0), Overtime.pot_for(1), Overtime.pot_for(2), Overtime.pot_for(3)], [
		{"panels": 0, "rares": 0, "cores": 0}, {"panels": 1, "rares": 0, "cores": 0},
		{"panels": 1, "rares": 1, "cores": 0}, {"panels": 1, "rares": 2, "cores": 1}])


# Wins the dam yard for real: the ball grounds inside the lock circle, the yard shuts, and each
# wave is struck down as it lands until the last crew down opens it (stage_locks.gd).
func _win_yard(game) -> void:
	var locks = game.flow.gate
	var row: Dictionary = LockRows.row("park_dam")["lock"]
	var beacon: Vector3 = game.flow.beacon.global_position
	var spot := beacon + Vector3(0.0, 0.0, -float(row["within_m"]) + 20.0)
	game.player.reset_to(game.ctx.terrain.drop_point(spot.x, spot.z, 1.0), Vector3.ZERO)
	var ticks := 0
	while locks.lock_state != "spent" and ticks < 60 * Engine.physics_ticks_per_second:
		for enemy in locks.crew_alive():
			game.ctx.spawner.strike(enemy, "ram", 1000000.0)
		await physics_frame
		ticks += 1
	_t.check("the yard is won for real", locks.lock_state == "spent" and locks.lock_won, "%s after %d ticks" % [locks.lock_state, ticks])


func _off() -> void:
	var game = await _game(PackedStringArray())
	_t.eq("flag off by default", game.player.tuning.option("overtime"), "off")
	await _win_yard(game)
	_t.eq("a won yard offers nothing with the flag off", game.flow.gate.overtime.state, "")
	_t.eq("and says nothing", _count("overtime_offered"), 0)
	game.queue_free()
	await process_frame


func _on() -> void:
	var game = await _game(PackedStringArray(["--overtime=on"]))
	var ot = game.flow.gate.overtime
	await _win_yard(game)
	_t.eq("a won yard offers overtime", ot.state, "offered")
	_t.eq("the offer is heard", _count("overtime_offered"), 1)
	_t.check("the bell, the pot and the sluice stand",
		[ot.prop_at("bell"), ot.prop_at("pot"), ot.prop_at("sluice")].all(func(p: Vector3): return p != Vector3.INF))
	_t.check("an empty pot has nothing to cash", not ot.cash() and ot.state == "offered")

	# A slow touch does not ring the bell; a ram at speed does.
	var at: Vector3 = ot.prop_at("bell")
	game.player.reset_to(at + Vector3.UP * 0.5, Vector3(2.0, 0.0, 0.0))
	await _sim(0.1)
	_t.eq("a slow touch leaves the bell alone", ot.rings, 0)
	var speed: float = game.player.tuning.tier_cruise() * 1.3
	game.player.reset_to(at + Vector3(-1.0, 0.5, 0.0), Vector3(speed, 0.0, 0.0))
	await _sim(0.1)
	_t.eq("a ram rings it", ot.rings, 1)
	var last: Array = LockRows.row("park_dam")["lock"]["waves"].back()
	var crew: Array = ot.crew_alive()
	_t.eq("one ring lands the last wave and a brute", crew.size(), last.size() + 1)
	_t.check("the overtime crew is yard crew", crew.all(func(e): return e.has_meta("yard_crew")))
	_t.eq("a brute among them", crew.filter(func(e): return e.kind == Overtime.ELITE_KIND).size(), 1)
	ot.ring()
	ot.ring()
	_t.check("three rings at most", not ot.ring() and ot.rings == Overtime.MAX_RINGS, "rings %d" % ot.rings)
	_t.eq("each ring is heard", _count("overtime_rung"), 3)

	# The sluice: warning, then a flood as long as the third rung, soaking the yard.
	game.player.reset_to(ot.centre + Vector3.UP * 0.5, Vector3.ZERO)
	_t.check("the sluice opens", ot.open_sluice() and ot.sluice == "warning")
	_t.check("one sluice a yard", not ot.open_sluice())
	_t.eq("the warning shows the sheet's circle", ot.water_shown(), "warning")
	await _sim(Overtime.SLUICE_WARN_S - 0.2)
	_t.eq("it whistles first", ot.sluice, "warning")
	await _sim(0.4)
	_t.eq("then it runs", ot.sluice, "flooding")
	_t.near("for the third rung's length", ot.flood_left, Overtime.FLOOD_S[3], 0.3)
	_t.eq("the sheet shows full", ot.water_shown(), "flooding")
	await _sim(0.6)
	var soaked: Array = ot.crew_alive().filter(func(e): return e.wet())
	_t.eq("the crew is soaked", soaked.size(), ot.crew_alive().size())
	var lobbers: Array = soaked.filter(func(e): return e.kind == "lobber")
	_t.check("a soaked lobber reads wet", not lobbers.is_empty() and lobbers[0].armour_class() == "wet")
	var carried := await _along(game, ot)

	# Arc on a soaked machine jumps once to the soaked machines near it. Pick two the crew still
	# has: the harder crew can lose a member to the ball while it rolls along the flow.
	var standing: Array = soaked.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	_t.check("two soaked machines still stand", standing.size() >= 2, "%d standing" % standing.size())
	if standing.size() < 2:
		game.queue_free()
		await process_frame
		return
	var a = standing[0]
	var b = standing[1]
	for e in [a, b]:
		e.live = Callable(self, "_never")
		e.hp = 100000.0
		e.max_hp = 100000.0
		e.plating = 0.0
	b.global_position = a.global_position + Vector3(3.0, 0.0, 0.0)
	var b_before: float = b.hp
	game.ctx.spawner.strike(a, "arc", 20.0)
	_t.check("arc jumps to a soaked neighbour", b.hp < b_before, "neighbour lost %.1f" % (b_before - b.hp))

	# The pot pays by rings and ends the overtime.
	var parts: int = game.ctx.run.parts.size()
	var cores: int = game.ctx.run.bonus_cores
	_t.check("the pot pays", ot.cash() and ot.state == "spent")
	_t.eq("three rings pay two rare parts", game.ctx.run.parts.size() - parts, 2)
	_t.eq("and a core", game.ctx.run.bonus_cores - cores, 1)
	_t.check("no ring after the pot", not ot.ring())

	await _sim(Overtime.FLOOD_S[3])
	_t.eq("the flood runs dry", ot.sluice, "spent")
	var rolled := await _along(game, ot)
	_t.check("the sheet carries the ball down the flow", carried > rolled + 1.0,
		"from rest, 0.25 s: %.1f m/s along in the flood, %.1f dry" % [carried, rolled])
	var still: Array = soaked.filter(func(e): return is_instance_valid(e) and not e.is_dead())
	ot.clear()
	await _sim(Overtime.WET_S)
	_t.check("soaked machines dry on their own once the yard is gone", not still.is_empty()
			and still.all(func(e): return not is_instance_valid(e) or not e.wet()), "%d machines" % still.size())
	ot.offer(ot.centre, 0.0, LockRows.row("park_dam")["lock"])
	game.events.flow_changed.emit("gates")
	_t.check("leaving clears it", ot.state == "" and ot.prop_at("bell") == Vector3.INF and ot.water_shown() == "")
	game.queue_free()
	await process_frame


# Along-flow speed a ball dropped at rest in the yard's centre has after a quarter second.
func _along(game, ot) -> float:
	game.player.reset_to(ot.centre + Vector3.UP * 0.5, Vector3.ZERO)
	await _sim(0.25)
	return game.player.planar_velocity().dot(ot.flow_dir)


func _never() -> bool:
	return false
