# smoke: solo (a 6 s siren runs at wall pace)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")

# The Stocktake muster on the flume (BACKLOG W1-101): the survival count as an event that comes to the ball.
# (a) with the launch flag on it is called on about one run seed in three, and on no seed with the flag off;
# (b) a called run builds one muster site, shown nowhere until it lands;
# (c) away from its row nothing happens; near it the siren announces it once and nothing starts for siren_s;
# (d) when the siren ends the ring lands on the ground under the ball, shows, and count 1 begins;
# (e) the ring then travels: it leaves the landing point and stays on the rule's loop;
# (f) with the floor clear the gate opens, and rolling out of the travelling ring from inside banks pay(1);
# (g) a run seed that is not called builds no muster.

const SEED := 23
const EXPECTED_CHECKS := 9

var _game
var _t := preload("res://tests/support/t.gd").new("stocktake_muster_test")
var _source := Intent.Scripted.new()
var _announced := []
var _ended := []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _acts():
	return _game.world.activities


func _site():
	return _acts().site("stocktake_muster")


func _hold(at: Vector3) -> void:
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await physics_frame


func _over(x: float, z: float) -> Vector3:
	return _game.ctx.terrain.drop_point(x, z, 1.05)


func _called(map) -> bool:
	return not _acts().survival_spec(map, "stocktake_muster").is_empty()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_game.events.event_announced.connect(func(id: String, seconds: float, _at: Vector3): if id == "stocktake_muster": _announced.append(seconds))
	_game.events.event_ended.connect(func(id: String, outcome: String): if id == "stocktake_muster": _ended.append(outcome))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	var map = _game.ctx.terrain.map()
	var off := 0
	for run_seed in 60:
		_game.run.run_seed = run_seed
		off += int(_called(map))
	_game.ctx.tuning.set_option("stocktake", "on")
	var on := []
	var quiet := -1
	for run_seed in 60:
		_game.run.run_seed = run_seed
		if _called(map):
			on.append(run_seed)
		elif quiet < 0:
			quiet = run_seed
	_t.check("called on about one run seed in three with the flag on, none with it off", off == 0 and on.size() >= 12 and on.size() <= 28, "off %d, on %d of 60" % [off, on.size()])
	_game.run.run_seed = on[0]
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	await _muster()
	_game.run.run_seed = quiet
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(4)
	_t.check("a run seed that is not called builds no muster", _site() == null, "seed %d" % quiet)
	_t.eq("expected check count", _t.checks + 1, EXPECTED_CHECKS)
	_game.free()
	await _frames(2)
	quit(_t.verdict())


func _muster() -> void:
	var s = _site()
	_t.check("a called run builds one muster, shown nowhere until it lands", s != null and s.yard != null and not s.visible
		and not _game.hud.edge_markers.unfinished_sites().has(s) if s != null else false, "no site" if s == null else "visible %s" % s.visible)
	if s == null:
		return
	var row := Vector2(s.global_position.x, s.global_position.z)
	var call_m := float(s.rule["call_m"])
	for frame in 30:
		await _hold(_over(row.x - call_m - 40.0, row.y))
	var far_quiet: bool = _announced.is_empty() and not s.started
	var near: Vector3 = _over(row.x - call_m + 20.0, row.y)
	var siren := float(s.rule["siren_s"])
	for frame in int((siren - 0.5) * Engine.physics_ticks_per_second):
		await _hold(near)
	_t.check("away from its row nothing happens; near it the siren announces it once and nothing starts yet",
		far_quiet and _announced == [siren] and not s.started and not s.visible, "far quiet %s announced %s started %s" % [far_quiet, _announced, s.started])
	for frame in Engine.physics_ticks_per_second:
		await _hold(near)
	var landed := Vector2(near.x, near.z)
	_t.check("when the siren ends the ring lands under the ball, shows, and count 1 begins", s.started and s.visible and s.yard.count == 1
		and _announced.size() == 1, "started %s visible %s count %d" % [s.started, s.visible, s.yard.count])
	# The ball rides with the ring, felling what arrives, and the ring travels the loop.
	var loop: Dictionary = SurvivalCount.MOVES["loop"]
	var furthest := 0.0
	var on_loop := true
	var opened := false
	for frame in 6 * Engine.physics_ticks_per_second:
		await _hold(_over(s.global_position.x, s.global_position.z))
		var at := Vector2(s.global_position.x, s.global_position.z)
		furthest = maxf(furthest, at.distance_to(landed))
		on_loop = on_loop and at.distance_to(landed) <= 2.0 * float(loop["radius_m"]) + 0.5
		for enemy in s.pack:
			if is_instance_valid(enemy):
				enemy.take_damage(100000.0)
		if s.yard.gate_open and s.yard_owed.is_empty():
			opened = true
			break
	_t.check("the ring leaves its landing point and stays on the loop", furthest > 5.0 and on_loop, "furthest %.1f m" % furthest)
	_t.check("a clear floor opens the gate on the travelling ring", opened and s.yard.cleared == 1, "opened %s cleared %d" % [opened, s.yard.cleared])
	await _hold(_over(s.global_position.x, s.global_position.z))
	var scrap_before: int = _game.run.scrap
	await _hold(_over(s.global_position.x + float(s.rule["ring"]) + 6.0, s.global_position.z))
	var pay: Dictionary = SurvivalCount.new().pay(1)
	_t.check("rolling out of the ring from inside banks pay(1)", _ended == ["won"] and s.done and _game.run.scrap - scrap_before == int(pay["scrap"]),
		"ended %s scrap %d of %d" % [_ended, _game.run.scrap - scrap_before, pay["scrap"]])
