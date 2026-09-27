extends SceneTree

const Game := preload("res://src/game.gd")
const Swarm := preload("res://src/combat/swarm.gd")

# The swarm remnant (DESIGN-V2 section 10, C11):
# - one spawn brings a whole rack of six identical drones, one pack_arrived for the swarm;
# - the rack locks and draws its dive lane before any dive can hurt;
# - a ball bowling through the rack at speed scatters it (swarm_scattered), and for 2 s
#   the drones follow the ball with their blue seams dark, then fall silent and re-form
#   with their seams back.

# Past the rack's scatter speed and under cruise, so the pass scatters without crushing.
const BOWL_SPEED := 12.0

var _game
var _fleet
var _failures := 0
var _step := 0
var _clock := 0.0
var _lead: Node3D
var _swarm
var _lane_at := -1.0
var _rack := 0
var _hit_at := -1.0
var _scattered := 0
var _packs: Array = []
var _mark := 0.0
var _toward := 0
var _samples := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_clock += delta
	match _step:
		0:
			_setup()
			_step = 1
		1:
			if _swarm.lane() != null and _lane_at < 0.0:
				_lane_at = _clock
				_rack = _swarm.alive().size()
			if _swarm.dives > 0 and _swarm.state == Swarm.State.FORMING and _swarm.t > 0.2:
				_report("one spawn, one rack", _rack == 6 and _packs.size() == 1 and _packs[0][0] == "swarm",
					"%d drones in the rack when it locked; packs %s" % [_rack, _packs])
				_report("locks before it dives", _lane_at >= 0.0 and (_hit_at < 0.0 or _hit_at - _lane_at >= Swarm.LOCK_WARN - 0.05),
					"lane drawn at %.2f s, first sting %s" % [_lane_at, "none" if _hit_at < 0.0 else "%.2f s" % _hit_at])
				_step = 2
			elif _clock > 15.0:
				_report("locks before it dives", false, "no dive in 15 s (state %d, locks %d)" % [_swarm.state, _swarm.locks])
				return _finish()
		2:
			if _swarm.state == Swarm.State.FORMING and _swarm.t > 0.4:
				var through: Vector3 = _swarm.centre + _swarm.facing * 5.0
				through.y = _game.ctx.terrain.height(through.x, through.z) + 1.05
				_game.player.reset_to(through, -_swarm.facing * BOWL_SPEED)
				_mark = _clock
				_step = 3
		3:
			if _swarm.state == Swarm.State.SCATTERED:
				var dark := true
				for d in _swarm.alive():
					dark = dark and not d.get("_seam").visible
				_report("bowl-through scatters", _scattered == 1 and dark,
					"%d swarm_scattered after bowling through at %.0f m/s; every follower's seam dark %s" % [_scattered, BOWL_SPEED, dark])
				_mark = _clock
				_step = 4
			elif _clock - _mark > 1.0:
				_report("bowl-through scatters", false, "the rack held after a bowl-through (state %d)" % _swarm.state)
				return _finish()
		4:
			var ball: Vector3 = _game.player.ball_position()
			if _clock - _mark >= 0.6 and _swarm.state == Swarm.State.SCATTERED:
				for d in _swarm.alive():
					var to: Vector3 = ball - d.global_position
					to.y = 0.0
					_samples += 1
					if to.length() <= 3.5 or Vector3(d.velocity.x, 0.0, d.velocity.z).dot(to) > 0.0:
						_toward += 1
			if _swarm.state == Swarm.State.FORMING:
				var lit := true
				for d in _swarm.alive():
					lit = lit and d.get("_seam").visible
				_report("followers follow", _samples > 0 and float(_toward) / _samples >= 0.9,
					"%d of %d follower samples closing on the ball or at its heels" % [_toward, _samples])
				_report("then re-form", absf(_clock - _mark - Swarm.FOLLOW) <= 0.1 and lit,
					"re-formed %.2f s after the scatter with seams lit %s" % [_clock - _mark, lit])
				return _finish()
			if _clock - _mark > 4.0:
				_report("then re-form", false, "still scattered after 4 s with %d drones alive" % _swarm.alive().size())
				return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_fleet = ctx.spawner.fleet
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(ball)
	_game.events.swarm_scattered.connect(func(_at: Vector3, _n: int): _scattered += 1)
	_game.events.pack_arrived.connect(func(faction: String, _at: Vector3, kinds: Array): _packs.append([faction, kinds.size()]))
	_game.events.player_hit.connect(func(_amount: float, source: String):
		if source == "swarm_remnant" and _hit_at < 0.0:
			_hit_at = _clock)
	var at: Vector3 = ball + Vector3(24.0, 0.0, 6.0)
	_lead = ctx.spawner.spawn_enemy("swarm_remnant", ctx.terrain.drop_point(at.x, at.z, 1.4))
	_swarm = _lead.swarm
	_clock = 0.0


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_swarm_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
