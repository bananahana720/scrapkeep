extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")

# The fight's shape through the real flow: the run leaves stage 3 into the arena, the
# arena publishes its facts on time, the clash threshold sits at 150, set pieces hold
# the fight to 75 s even against infinite damage, the win hangs the crest on the ball
# and leads to victory and the summary, and the death screen's T and R both work.
# Driven tick by tick. Repointed 2026-10-04 (F2a fix round): Brindle is a posture body,
# so the fight is driven by staggers and contacts, not by gun damage on an HP pool.

const DT := 1.0 / 90.0
const MIN_FIGHT := 75.0
const LIMIT := 200.0

# The legacy final-stage rule runs on a three-stage double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _double
var _boss
var _failures := 0
var _started := false
var _log: Array = []
var _phases: Array = []
var _states: Array[String] = []
var _slag_hits: Array = []


func _initialize() -> void:
	_game = LegacyGame.new()
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
	events.boss_arena_entered.connect(func(): _log.append("arena_entered"))
	events.boss_phase_changed.connect(_on_phase)
	events.boss_defeated.connect(func(): _log.append("defeated@%.2f" % _boss.clock))
	events.flow_changed.connect(func(s: String): _states.append(s))
	events.player_hit.connect(_on_hit)
	_run_all()
	return false


# The fight to the end waits physics frames (the posture rule keys a contact to its
# frame), so the checks run as a coroutine and the verdict follows them.
func _run_all() -> void:
	await _run_checks()
	print("boss_flow_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _on_phase(phase: int, phase_name: String) -> void:
	_log.append("phase_%d" % phase)
	var spilled := 0
	for p in _boss.pickups_left():
		spilled += p["value"]
	_phases.append({"phase": phase, "name": phase_name, "clock": _boss.clock, "live_phase": _boss.phase, "phase_clock": _boss.phase_clock, "spilled": spilled})


func _on_hit(amount: float, source: String) -> void:
	if source != "brindle_slag":
		return
	var ball: Vector3 = _game.player.ball_position()
	var inside := false
	for h in _boss.active_hazards():
		if h.attack_id.begins_with("slag") and h.is_live() and h.age >= 1.0 and h.contains(ball):
			inside = true
	_slag_hits.append({"amount": amount, "inside": inside})


func _run_checks() -> void:
	Harness.start_run(_game)
	_run_to_boss()
	var flow = _game.flow
	_report("arena entry", flow.state_name() == "boss" and _log.slice(0, 2) == ["arena_entered", "phase_1"] and _phases[0]["name"] == "Requisition"
			# Re-pinned 2026-10-15 (BRINDLE-SCUTTLE): hull plating 120 to 110 in boss_rules.gd.
			and flow.boss_active and flow.boss_plating == 110.0 and _boss.phase == 1 and _boss.arena != null,
		"stage 3's end entered %s; published %s; boss_active %s, boss_plating %.0f" % [flow.state_name(), str(_log), flow.boss_active, flow.boss_plating])
	var kept: Vector3 = _game.run.snapshot_value("entry_position")
	var placed: Vector3 = _boss.arena.entry_point()
	_report("entry pose recorded", kept.distance_to(placed) < 0.01 and _game.player.ball_position().distance_to(placed) < 0.01,
		"flow's arena-entry checkpoint holds %s, the arena's entry point %s (the ball is placed at once, not by a pending teleport)" % [kept, placed])
	var entries: Array = _game.codex.entries(CodexEntries.CATEGORY).filter(func(e): return e["id"].begins_with("brindle_"))
	_report("codex entries", entries.size() == 4 and entries.all(func(e): return e["hint"] != "" and e["clue"] != "" and e["category"] == "enemy"),
		"%d brindle entries declared in the enemy category: %s" % [entries.size(), str(entries.map(func(e): return e["id"]))])

	_clash_checks()
	_quench_checks()
	_death_checks()
	await _fight_to_the_end()


# Stage 3 is entered and its launch flight finished, the way a run reaches the arena.
func _run_to_boss() -> void:
	var flow = _game.flow
	flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
	flow._finish_stage()


func _clash_checks() -> void:
	_boss.jump_to_phase(3)
	var hull = _boss.ship.hull
	var spot: Vector3 = _boss.arena.point_at(0.3, 30.0, 1.0)
	Harness.put_ball(_game, spot)
	for _tick in int(6.0 / DT):
		if _boss.charging():
			break
		_boss.advance(DT)
	var plating_charging: float = _double.plating_of(hull)
	_double.strike(hull, "ram", _double.force_for("ram", 149.0))
	var held_149: bool = _boss.charging() and _boss.clashes == 0
	_double.strike(hull, "ram", _double.force_for("ram", 151.0))
	var stunned_151: bool = _boss.stunned() and _boss.clashes == 1
	var plating_stunned: float = _double.plating_of(hull)
	for _tick in int(1.9 / DT):
		_boss.advance(DT)
	var still: bool = _boss.stunned()
	for _tick in int(0.2 / DT) + 1:
		_boss.advance(DT)
	_report("clash threshold", plating_charging == 150.0 and held_149 and stunned_151 and plating_stunned < 1.0 and still and not _boss.stunned(),
		"charging bow plating %.0f; punch 149 kept the charge (%s), punch 151 stunned it (%s) with plating %.0f, stunned at 1.9 s %s, free at 2.1 s %s"
			% [plating_charging, held_149, stunned_151, plating_stunned, still, not _boss.stunned()])


func _quench_checks() -> void:
	_boss.jump_to_phase(2)
	var ring = null
	for _tick in int(8.0 / DT):
		for h in _boss.active_hazards():
			if h.attack_id == "slag_ring_a":
				ring = h
		if ring != null:
			break
		_boss.advance(DT)
	var vent_angle := deg_to_rad(Arena.VENT_ANGLES[0])
	Harness.put_ball(_game, _boss.arena.point_at(vent_angle, Arena.VENT_R, 1.0))
	_boss.advance(DT)
	var mid := (Arena.RING_A.x + Arena.RING_A.y) * 0.5
	Harness.put_ball(_game, _boss.arena.point_at(vent_angle, mid, 1.0))
	for _tick in int(4.0 / DT):
		_boss.advance(DT)
	var drone_at: Vector3 = _boss.arena.point_at(1.0, 30.0, 1.0)
	var before_kill: Array = _boss.pickups_left()
	_game.run.record_kill("lobber", drone_at, 4)
	var dropped: Array = _boss.pickups_left().filter(func(p): return p["at"].distance_to(drone_at) < 1.0 and p["value"] == 4)
	_report("drone kill pays", _boss.pickups_left().size() == before_kill.size() + 1 and dropped.size() == 1,
		"a lobber drone killed in the arena dropped a pickup worth %d where it died" % (dropped[0]["value"] if dropped.size() > 0 else 0))
	var hits_on_crust := _slag_hits.size()
	var rode: bool = _game.codex.known(CodexEntries.QUENCH_RIDE)
	Harness.put_ball(_game, _boss.arena.point_at(PI, mid, 1.0))
	for _tick in int(0.2 / DT):
		_boss.advance(DT)
	_report("quench ride", ring != null and ring.is_live() and hits_on_crust == 0 and rode and _slag_hits.size() == 1 and _slag_hits[0]["inside"],
		"a rim vent quenched ring A under the ball: %d slag hits on the crust, codex %s; off the crust it hit %d time(s), inside the live ring drawn 1 s ahead: %s"
			% [hits_on_crust, rode, _slag_hits.size(), _slag_hits[0]["inside"] if _slag_hits.size() > 0 else false])


func _death_checks() -> void:
	var flow = _game.flow
	_game.run.damage(99999.0, "test")
	var dead: String = flow.state_name()
	var can_t: bool = flow.can_replay_final_stage()
	var old_arena = _boss.arena
	flow.retry_stage()
	var retried: bool = flow.state_name() == "boss" and _boss.phase == 1 and _boss.hp == Rules.MAX_HP and _boss.arena != null and _boss.arena != old_arena
	_game.run.damage(99999.0, "test")
	var replayed: bool = flow.replay_stage(3)
	_report("death screen", dead == "dead" and can_t and retried and replayed and flow.state_name() == "stage" and _game.run.stage == 3 and _boss.state_name() == "idle" and _boss.arena == null,
		"death in the arena reads %s with T offered %s; R rebuilt the fight at full HP %s; T replayed stage 3 (%s, boss %s, arena freed %s)"
			% [dead, can_t, retried, flow.state_name(), _boss.state_name(), _boss.arena == null])
	_run_to_boss()


func _fight_to_the_end() -> void:
	_phases.clear()
	_log.clear()
	_states.clear()
	var flow = _game.flow
	flow.retry_stage()
	_states.append(flow.state_name())
	var defeated_at := -1.0
	var rammed := -1
	var hull = _boss.ship.hull
	while _boss.clock < LIMIT:
		Harness.put_ball(_game, _above_cockpit())
		for target in _boss.ship.magnets + _boss.ship.caps:
			if not target.is_dead():
				_double.strike(target, "arc", 1.0e9)
		# Guns press the bar to a stagger; one ram per opening, a frame after it opened,
		# cracks the chunk and the ram in the next opening shatters it.
		if not hull.is_dead():
			if not _boss.staggered():
				_double.strike(hull, "arc", 1.0e9)
			elif _boss._posture.staggers != rammed:
				rammed = _boss._posture.staggers
				await physics_frame
				Harness.put_ball(_game, _above_cockpit())
				_double.strike(hull, "ram", 150.0)
		if _boss.scooter_landed():
			Harness.put_ball(_game, _boss.scooter.global_position + Vector3.UP * 1.8)
			_double.strike(_boss.scooter, "ram", 20.0)
		_boss.advance(DT)
		if _boss.state_name() == "defeated":
			defeated_at = _boss.clock
			break
	var order: Array = _phases.map(func(p): return p["phase"])
	var on_tick: bool = _phases.all(func(p): return p["live_phase"] == p["phase"] and p["phase_clock"] == 0.0)
	_report("fight lasts 75 s", defeated_at >= MIN_FIGHT and order == [1, 2, 3, 4] and on_tick and _phases[3]["name"] == "chase",
		"with infinite damage every tick boss_defeated came %.1f s after arena entry; phases %s at %s s, each published on the tick it began: %s"
			% [defeated_at, str(order), str(_phases.map(func(p): return snappedf(p["clock"], 0.1))), on_tick])
	var breaks: Array = _phases.slice(1).map(func(p): return p["spilled"])
	_report("phase breaks pay scrap", breaks.size() == 3 and breaks.all(func(v): return v >= Rules.BREAK_SPILL),
		"each phase break spilled scrap to roll up around the ship: %s (at least %d each)" % [str(breaks), Rules.BREAK_SPILL])
	var crest: Node3D = _boss.crest()
	_report("crest", crest != null and crest.get_parent() == _game.player.roll_node() and _game.run.parts.has(Rules.CREST_PART),
		"the admiral's crest rides on the ball's roll node (%s) and the run holds %s" % [crest != null and crest.get_parent() == _game.player.roll_node(), Rules.CREST_PART])
	_report("scooter pace", _boss.scooter_speed() < _game.tuning.f("cruise"),
		"the scooter runs the ring at %.1f m/s, under cruise %.1f, so a ball at cruise closes on it" % [Rules.SCOOTER_SPEED, _game.tuning.f("cruise")])
	for _tick in int(3.0 / DT):
		flow.physics_step(DT)
	var tail: Array[String] = []
	for s in _states:
		if tail.is_empty() or tail[-1] != s:
			tail.append(s)
	_report("victory then summary", tail.slice(-3) == ["boss", "victory", "summary"] and _boss.arena == null,
		"flow went %s after boss_defeated; arena freed on the summary %s" % [str(tail), _boss.arena == null])


# 2026-10-17 BRINDLE-HULL: the bodies follow the ship now, so the ball stands above the
# cockpit end of the moving hull, clear of every vent cap (a ram over a cap is a cap hit
# and never reaches the cockpit). It used to hover above the arena centre, which only
# worked while the bodies stayed behind there.
func _above_cockpit() -> Vector3:
	return _boss.ship.to_global(Vector3(0.0, 40.0, 4.8))
