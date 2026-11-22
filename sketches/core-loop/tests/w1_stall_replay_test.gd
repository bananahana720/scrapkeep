# smoke: solo timeout=180s (one fixed-90-fps child; replays PF-48 flume exit, PF-49 Brindle Scuttle, and hull-pickup/charge-brace stall invariants)
extends SceneTree

const Arena := preload("res://src/boss/arena.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const Game := preload("res://src/game.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const RunState := preload("res://src/core/run_state.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# World 1 stall replays (W46-01, PF-48, PF-49):
#   1. PF-48 (seed 40317, Learner rung 1, tarn): after breaking the Flume Warden in
#      head_house_drum, the leave beat climbs out and reaches launch/boss inside FLUME_CAP_S
#      instead of sitting in gates until the 600 s stage limit.
#   2. PF-49 (seed 40366, Learner rung 5, tally): Brindle phase 3 (Scuttle) turns to the
#      chase and ends in defeat inside SCUTTLE_CAP_S instead of hitting the 420 s boss cap.
#   3. Live boss.gd stall causes caught on stage 1266fec1:
#      - take_spill() and floor pickups overrun by Brindle's moving 9 m x 14 m solid hull
#        must never sit inside the hull's solid footprint (where PICKUP_REACH cannot reach
#        them for PICKUP_LIFE = 12 s) and must stay on the playable floor/bowl;
#      - CHARGE_BRACE must recover to CHARGE_REST if its lane hazard finishes or frees early
#        instead of hanging Scuttle forever.

const DT := 1.0 / 90.0
const FLUME_SEED := 40317
const FLUME_START := Vector3(240.0, -12.0, 472.0)
const FLUME_CAP_S := 40.0
const SCUTTLE_SEED := 40366
const SCUTTLE_CAP_S := 120.0
const SCUTTLE_HEFT := 2.5

var _t := T.new("w1_stall_replay_test")
var _stage := 0
var _game
var _driver
var _boss
var _ticks := 0
var _phase_s := 0.0
var _done := false


func _initialize() -> void:
	if not OS.get_cmdline_user_args().has("--child"):
		var results := ChildRuns.run([{"script": "res://tests/w1_stall_replay_test.gd", "args": ["--child"]}], 150.0)
		var result: Dictionary = results[0]
		print(result["log"])
		_t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
			"exit %s, timed out %s" % [result["code"], result["timed_out"]])
		quit(_t.verdict())
		return
	SimClock.ticks = true
	node_added.connect(func(node: Node):
		if node is Game:
			node.table = "park")
	_start_flume_replay()


func _start_flume_replay() -> void:
	_stage = 1
	seed(FLUME_SEED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_driver = null
	_boss = null
	_ticks = 0
	_phase_s = 0.0


func _start_scuttle_replay() -> void:
	_stage = 2
	seed(SCUTTLE_SEED)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_driver = null
	_boss = null
	_ticks = 0
	_phase_s = 0.0


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _stage == 1:
		_step_flume(delta)
	elif _stage == 2:
		_step_scuttle(delta)
	return false


func _step_flume(delta: float) -> void:
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", FLUME_SEED)
		_driver.class_index = BotDriver.class_index_for(FLUME_SEED, "tarn")
		_driver.band = SkillBand.make("learner", 1, FLUME_SEED)
		_driver.start()
		_game.flow.enter_stage(2, Vector3.ZERO, false)
		return
	_ticks += 1
	if _ticks < 30:
		return
	if _ticks == 30:
		_game.ctx.calm = true
		_game.run.set_max_hp(99999.0)
		_game.run.hp = 99999.0
		_game.player.reset_to(FLUME_START, Vector3.ZERO)
		_game.flow._unseal()
		return
	_phase_s += delta
	_driver.tick(delta)
	var state: String = _game.flow.state_name()
	if state in ["launch", "boss"] or _phase_s >= FLUME_CAP_S:
		_t.check("PF-48 flume leave beat (40317 Learner1) exits gates inside %.0f s" % FLUME_CAP_S,
			state in ["launch", "boss"],
			"ended in state=%s at %.2f s, pos=%s, goal=%s" % [state, _phase_s, _game.player.ball_position(), _driver.get("_goal")])
		_game.free()
		_game = null
		_start_scuttle_replay()


func _step_scuttle(delta: float) -> void:
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", SCUTTLE_SEED)
		_driver.class_index = BotDriver.class_index_for(SCUTTLE_SEED, "tally")
		_driver.band = SkillBand.make("learner", 5, SCUTTLE_SEED)
		_driver.start()
		return
	if _boss == null:
		if _game.flow.state_name() == "stage" and _game.run.stage == 1:
			_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
			var mass_needed := maxf(0.0, (SCUTTLE_HEFT - 1.0) / RunState.HEFT_PER_MASS)
			_game.run.grant_start_mass(mass_needed)
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss = _game.ctx.boss
			_boss.jump_to_phase(3)
			_check_boss_invariants()
			# Re-enter a clean phase 3 on the arena entry point for the 40366 Scuttle replay.
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss = _game.ctx.boss
			_boss.jump_to_phase(3)
		else:
			_driver.tick(delta)
		return
	_phase_s += delta
	_driver.tick(delta)
	var state: String = _game.flow.state_name()
	var ended: bool = _boss.state == _boss.DEFEATED or state in ["victory", "summary", "dead"] or _phase_s >= SCUTTLE_CAP_S
	if ended:
		var won: bool = _boss.state == _boss.DEFEATED or state in ["victory", "summary"]
		_t.check("PF-49 Brindle Scuttle (40366 Learner5) ends in a result inside %.0f s" % SCUTTLE_CAP_S,
			won or state == "dead",
			"ended state=%s boss=%s phase=%d chunks=%d at %.2f s (stuns=%d, goal=%s)"
				% [state, _boss.state_name(), _boss.phase, _boss.chunks_left(), _phase_s, _boss.stuns, _driver.get("_goal")])
		_t.check("PF-49 Brindle Scuttle (40366 Learner5) turns past phase 3 to defeat",
			won,
			"state=%s boss=%s phase=%d chunks=%d at %.2f s" % [state, _boss.state_name(), _boss.phase, _boss.chunks_left(), _phase_s])
		_game.free()
		_game = null
		_done = true
		quit(_t.verdict())


func _inside_solid_hull(boss, at: Vector3) -> bool:
	var loc: Vector3 = boss.ship.to_local(at)
	var hx := Requisition.HULL.x * 0.5 + Tuning.RADIUS
	var hz := Requisition.HULL.z * 0.5 + Tuning.RADIUS
	return absf(loc.x) < hx and absf(loc.z) < hz


func _check_boss_invariants() -> void:
	var boss = _boss
	var centre: Vector3 = boss.arena.global_position
	var floor_lim := Arena.FLOOR_R - 3.9

	# 1. Armour spill aimed straight into Brindle's solid hull must land clear of the hull and on the floor.
	var ship_pos: Vector3 = boss.ship.global_position
	var toward := Vector3(1.0, 0.0, 0.0)
	var ball_from := ship_pos - toward * Rules.SPILL_AHEAD
	var before: int = boss._pickups.size()
	boss.take_spill(ball_from, toward, 60)
	var shed: Array = boss.pickups_left().slice(before)
	var trapped_shed := shed.filter(func(p): return _inside_solid_hull(boss, p["at"]))
	var floor_shed := shed.all(func(p): return Vector2(p["at"].x - centre.x, p["at"].z - centre.z).length() <= floor_lim)
	_t.check("take_spill aimed into Brindle's hull lands every shed pile clear of the hull",
		shed.size() == Rules.SPILL_PILES and trapped_shed.is_empty() and floor_shed,
		"%d/%d shed piles trapped inside hull; floor_ok=%s; locs=%s" % [
			trapped_shed.size(), shed.size(), str(floor_shed),
			str(shed.map(func(p): return boss.ship.to_local(p["at"])))])

	# 2. A Scuttle hull moving over existing floor pickups must push them clear instead of swallowing them.
	var ahead_spot: Vector3 = centre + Vector3(0.0, 0.0, 14.0)
	boss.ship.move_to(Vector3(centre.x, boss.arena.ground(centre), centre.z), Vector3.BACK)
	boss._spawn_pickup(Vector3(ahead_spot.x, boss.arena.ground(ahead_spot) + 0.9, ahead_spot.z), 10, "spill")
	boss._spawn_pickup(Vector3(ahead_spot.x + 1.0, boss.arena.ground(ahead_spot) + 0.9, ahead_spot.z), 10, "shed")
	boss.ship.move_to(Vector3(ahead_spot.x, boss.arena.ground(ahead_spot), ahead_spot.z), Vector3.BACK)
	boss._step_trail(centre + Vector3(0.0, 0.0, -30.0))
	var trapped_after: Array = boss.pickups_left().filter(func(p): return _inside_solid_hull(boss, p["at"]))
	_t.check("moving hull pushes overrun floor pickups clear of its solid box",
		trapped_after.is_empty(),
		"%d/%d pickups trapped inside hull after hull moved onto them" % [trapped_after.size(), boss.pickups_left().size()])

	# 3. Even when the hull is buried at the rim (CHARGE_STOP_R), shed/reel pickups pushed clear stay on the floor.
	var rim_pos: Vector3 = boss.arena.point_at(0.0, Rules.CHARGE_STOP_R)
	boss.ship.move_to(Vector3(rim_pos.x, boss.arena.ground(rim_pos), rim_pos.z), Vector3.RIGHT)
	var before_rim: int = boss._pickups.size()
	boss.take_spill(rim_pos - Vector3.RIGHT * Rules.SPILL_AHEAD, Vector3.RIGHT, 30)
	var rim_shed: Array = boss.pickups_left().slice(before_rim)
	var rim_trapped := rim_shed.filter(func(p): return _inside_solid_hull(boss, p["at"]))
	var rim_floor := rim_shed.all(func(p): return Vector2(p["at"].x - centre.x, p["at"].z - centre.z).length() <= floor_lim)
	_t.check("hull at rim keeps pushed shed piles both clear of hull and on the floor",
		rim_shed.size() == Rules.SPILL_PILES and rim_trapped.is_empty() and rim_floor,
		"%d/%d trapped; floor_ok=%s" % [rim_trapped.size(), rim_shed.size(), str(rim_floor)])

	# 4. CHARGE_BRACE recovers to CHARGE_REST if its hazard finishes before is_live() is seen.
	var done_h = Hazard.new()
	done_h.ground = boss.arena.ground
	done_h.commit_lane("charge", Hazard.Threat.Type.LANE, centre, Vector3.FORWARD, 7.0, 20.0, 5.5, 5.5, 1.0, 0.5)
	done_h.finish()
	boss._charge = {"state": boss.CHARGE_BRACE, "hazard": done_h, "from": centre, "heading": Vector3.FORWARD, "length": 13.0,
		"into_wall": false, "travelled": 0.0, "cued": false}
	boss._step_charges(DT, centre + Vector3(0.0, 0.0, -25.0))
	var recovered: bool = String(boss._charge.get("state", "")) == boss.CHARGE_REST
	done_h.free()
	_t.check("CHARGE_BRACE with a finished hazard recovers to CHARGE_REST instead of hanging",
		recovered,
		"charge state after step: %s" % str(boss._charge.get("state", "")))
