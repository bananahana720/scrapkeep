extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")

# Brindle does not scale: his four chunks are the same for a bare ball and a built one.
# The hull plate is the posture rule's plating (98 glances short of 110 and moves the bar
# less than 144; a gun never takes a chunk) and the arena says so at entry. A crane
# catch takes mass and heft, the spill trail pays it back, and a shot on a magnet that
# still holds scrap drops the rest and presses the hull's bar. Driven tick by tick.
# Repointed 2026-10-03 (F2a): HP floors gave way to the posture chunk count.
# Re-pinned 2026-10-15 (BRINDLE-SCUTTLE): hull plating 120 to 110 in boss_rules.gd; the
# readout and deflection pins read 110, and 98 and 144 still sit either side of it.

const DT := 1.0 / 90.0
const TRAIL_WINDOW := 8.0

var _game
var _double
var _boss
var _failures := 0
var _started := false
var _deflected: Array = []
var _lost: Array = []
var _weak: Array = []
var _telegraphs: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_double = Harness.install(_game)
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	var events = _game.events
	events.strike_deflected.connect(func(_e, _k, punch: float, plating: float): _deflected.append([punch, plating]))
	events.scrap_lost.connect(_on_lost)
	events.boss_weak_point_hit.connect(func(id: String): _weak.append(id))
	events.boss_attack_telegraphed.connect(func(id: String, s: float): _telegraphs.append([id, s]))
	_run_checks()
	print("boss_scaling_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


# Every crane theft must happen inside a live crane sector that was drawn at least 1 s.
func _on_lost(amount: int, _at: Vector3, _total: int, cause: String) -> void:
	var ball: Vector3 = _game.player.ball_position()
	var inside := false
	for h in _boss.active_hazards():
		if h.attack_id.begins_with("crane") and h.is_live() and h.age >= 1.0 and h.contains(ball):
			inside = true
	_lost.append({"amount": amount, "cause": cause, "inside": inside, "clock": _boss.clock})


func _run_checks() -> void:
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	var bare: float = _boss.max_hp
	_double.punch_override = 77.0
	_boss.advance(DT)
	var shown: String = _boss.ship.plate.text
	var objective: String = _boss.objective_text()
	_report("hull readout", shown == "BRINDLE · plating 110" and objective.contains("Punch 77 / hull plating 110") and _game.flow.boss_plating == 110.0 and _game.flow.boss_active,
		"at arena entry the plate reads \"%s\" and the objective \"%s\", flow.boss_plating %.0f" % [shown, objective, _game.flow.boss_plating])
	_double.punch_override = -1.0

	var hull = _boss.ship.hull
	var before: float = _boss.posture()
	_double.strike(hull, "arc", 98.0)
	var chip: float = _boss.posture() - before
	var deflected_98: bool = _deflected.size() == 1 and is_equal_approx(_deflected[0][0], 98.0) and _deflected[0][1] == 110.0
	before = _boss.posture()
	_double.strike(hull, "arc", 144.0)
	var full: float = _boss.posture() - before
	_report("hull plating 110", chip > 0.0 and full > chip and deflected_98 and _deflected.size() == 1 and _boss.chunks_left() == 4 and _boss.hp == bare,
		"punch 98 moved the bar %.2f (deflected against %s), punch 144 moved it %.2f; chunks left %d, hp %.0f"
			% [chip, str(_deflected[0]) if _deflected.size() > 0 else "none", full, _boss.chunks_left(), _boss.hp])

	_game.flow.new_run()
	for i in 12:
		_game.run.add_part("test_part_%d" % i, "test")
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_report("fixed hp", _boss.max_hp == bare and _boss.hp == bare and _game.run.parts.size() == 12,
		"max hp %.0f with 0 parts and %.0f with %d parts (heft %.2f)" % [bare, _boss.max_hp, _game.run.parts.size(), _game.run.heft()])

	_crane_checks()


func _crane_checks() -> void:
	_game.ctx.calm = false
	_game.flow.new_run()
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_game.run.add_scrap(150, Vector3.ZERO)
	var heft_before: float = _game.run.heft()
	var mass_before: float = _game.run.mass
	var caught: bool = _catch_with(0)
	if not caught:
		_report("crane catch", false, "crane 0 never caught a ball waiting in its sector")
		return
	var stolen: int = _lost[0]["amount"]
	var heft_after: float = _game.run.heft()
	var pull: Vector3 = _game.player.body().external_accel * DT
	_report("crane catch lowers heft", heft_after < heft_before and stolen == 30 and _lost[0]["cause"] == "crane" and _lost[0]["inside"],
		"heft %.2f -> %.2f; %d mass taken with cause \"%s\", inside a live sector drawn for %.1f s or more: %s"
			% [heft_before, heft_after, stolen, _lost[0]["cause"], 1.0, _lost[0]["inside"]])
	_report("crane never pins", Vector2(pull.x, pull.z).length() <= Rules.TUG_PULL + 0.01 and pull.y > 0.0,
		"the catch adds %.2f m/s sideways and %.2f m/s up; it never cancels velocity" % [Vector2(pull.x, pull.z).length(), pull.y])

	var t0: float = _boss.clock
	var mass_low: float = _game.run.mass
	while _boss.clock - t0 < TRAIL_WINDOW:
		var left: Array = _boss.pickups_left()
		if not left.is_empty():
			var ball: Vector3 = _game.player.ball_position()
			var nearest: Dictionary = left[0]
			for p in left:
				if ball.distance_to(p["at"]) < ball.distance_to(nearest["at"]):
					nearest = p
			var step: Vector3 = (nearest["at"] - ball).limit_length(18.0 * DT)
			Harness.put_ball(_game, ball + step)
		_boss.advance(DT)
		if _boss.pickups_left().is_empty() and _boss._cranes[0].get("held", 0) <= 0:
			break
	var restored: float = _game.run.mass - mass_low
	_report("trail pays back", restored >= 0.9 * stolen and _boss.clock - t0 <= TRAIL_WINDOW,
		"rolling the spill trail at 18 m/s took back %.0f of %d (%.0f%%) in %.1f s; mass %.0f of %.0f before the catch"
			% [restored, stolen, 100.0 * restored / maxf(1.0, stolen), _boss.clock - t0, _game.run.mass, mass_before])

	_weak.clear()
	var lost_count: int = _lost.size()
	if not _catch_with(1):
		_report("crane drop", false, "crane 1 never caught the ball")
		return
	var held: int = _boss._cranes[1]["held"]
	var hp_before: float = _boss.hp
	var posture_before: float = _boss.posture()
	_double.strike(_boss.ship.magnets[1], "arc", 12.0)
	var piled := 0
	for p in _boss.pickups_left():
		piled += p["value"]
	_report("crane drop", held > 0 and _boss._cranes[1]["held"] == 0 and _game.codex.known(CodexEntries.CRANE_DROP)
			and _weak == ["magnet_starboard"] and _boss.hp == hp_before and _boss.posture() > posture_before and _lost.size() > lost_count,
		"a 12-damage shot on the starboard magnet holding %d dropped it (pickups now %d), took %.0f chunks, pressed the bar %.2f, published %s, codex %s"
			% [held, piled, hp_before - _boss.hp, _boss.posture() - posture_before, str(_weak), _game.codex.known(CodexEntries.CRANE_DROP)])
	var crane_warns: Array = _telegraphs.filter(func(t): return t[0] == "crane_sweep")
	_report("crane telegraph", not crane_warns.is_empty() and crane_warns.all(func(t): return t[1] >= 1.0),
		"%d crane sweeps announced, each at least 1.0 s ahead: %s" % [crane_warns.size(), str(crane_warns.map(func(t): return snappedf(t[1], 0.01)))])


# Waits for crane i to commit with the ball 10 m out from its pivot, then holds the ball
# still in the sector until the sweep passes. Returns whether it caught the ball.
func _catch_with(i: int) -> bool:
	for _tick in int(20.0 / DT):
		var c: Dictionary = _boss._cranes[i]
		var h = c.get("hazard")
		if h == null or not is_instance_valid(h) or h.is_done():
			var pivot: Vector3 = _boss.ship.pivot(i)
			var out: Vector3 = (pivot - _boss.ship.global_position)
			out = Vector3(out.x, 0.0, out.z).normalized()
			var spot: Vector3 = pivot + out * 10.0
			Harness.put_ball(_game, Vector3(spot.x, _boss.arena.ground(spot) + 1.0, spot.z))
		if c.get("caught", false) and c.get("held", 0) > 0:
			return true
		_boss.advance(DT)
	return false
