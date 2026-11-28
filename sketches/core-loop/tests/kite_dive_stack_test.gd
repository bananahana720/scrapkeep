extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Kite drones that dive onto one forecast must not be placed inside the ball. The solver's depenetration
# of a drone teleported into the ball launched it from 44 to 97 m/s in a tick (16.5 m/s one-tick change
# with one drone, 18.3 with two, on a stationary ball). The test runs with ctx.calm, so the dive's own
# knock (hit_player's shove, 6.7 m/s at most) never reaches the ball: combat.gd _on_player_hit returns
# before crowd_control when calm. Any one-tick change above BOUND is the dive pushing the ball physically.
# Only a stationary ball is driven: a rolling ball was tried and cannot discriminate (at cruise or faster
# it bats the unfixed drones away before they land).
# The bound allows 3 m/s for friction, gravity and the ball's own ground contact over the landing window;
# the fixed code measured 0.81 m/s.

const BOUND := 3.0

var game
var t := T.new("kite_dive_stack_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _spawn(offset: Vector3, height: float, rest := 0.0):
	var at := Vector3(ball.x + offset.x, 0.0, ball.z + offset.z)
	at.y = game.ctx.terrain.height(at.x, at.z) + height
	var drone = game.combat.spawn_enemy("kite_drone", at)
	drone._strafe = 1.0
	drone._rest = rest
	drone.hp = 100000.0
	return drone


func _speed() -> float:
	return game.player.body().linear_velocity.length()


# Drives `count` drones (0.2 m apart, same forecast) through one dive onto a ball rolling at `roll`
# m/s along x. The roll is below cruise, so a ball that reaches a drone takes the dive and does not
# bat it (a cruise-speed roll bats the unfixed drone away and never lands, which tests nothing here).
# The speed is held until the dive goes live, then the ball rolls free through the landing.
# Returns the largest one-tick speed change, the largest rise over the speed at the dive's start, the
# closest approach of any drone to the ball (centre to centre), and whether the dive's hit landed.
func _stack(count: int, roll: float) -> Dictionary:
	game.combat.last_player_hit = {}
	game.player.reset_to(ball, Vector3(roll, 0.0, 0.0))
	var drones := []
	for i in count:
		drones.append(_spawn(Vector3(9.0 + 0.2 * i, 0.0, 3.0), 6.0))
	var out := {"tick": 0.0, "rise": 0.0, "close": INF, "hit": false, "landed": 0, "base": 0.0}
	var live := false
	var committed := false
	for frame in 600:
		var all_live := true
		var all_down := true
		var all_warn := true
		for d in drones:
			all_live = all_live and d.phase == d.Phase.LIVE
			all_down = all_down and d._landed
			all_warn = all_warn and d.phase != d.Phase.ROAM
		committed = committed or all_warn
		if all_live and not live:
			live = true
			out.base = _speed()
		if not (committed if roll > 0.0 else live):
			game.player.reset_to(ball, Vector3(roll, 0.0, 0.0))
		elif roll > 0.0 and not live:
			game.player.set_velocity_now(Vector3(roll, 0.0, 0.0))
		var before := _speed()
		await physics_frame
		if live:
			var after := _speed()
			out.tick = maxf(out.tick, absf(after - before))
			out.rise = maxf(out.rise, after - out.base)
			for d in drones:
				out.close = minf(out.close, d.global_position.distance_to(game.player.ball_position()))
		out.landed = 0
		for d in drones:
			out.landed += 1 if d._landed else 0
		if live and all_down:
			for extra in 12:
				var b := _speed()
				await physics_frame
				out.tick = maxf(out.tick, absf(_speed() - b))
				out.rise = maxf(out.rise, _speed() - out.base)
			break
	out.hit = game.combat.last_player_hit.get("source", "") == "kite_drone"
	for d in drones:
		d.free()
	return out


func _run() -> void:
	await _boot()

	for roll in [0.0]:
		for count in [1, 2]:
			var r: Dictionary = await _stack(count, roll)
			var label := "KS-%d%s" % [count, "r" if roll > 0.0 else "s"]
			t.check(label, r.landed == count and r.hit and r.tick <= BOUND and r.rise <= BOUND and r.close >= 1.6,
				"%d drone(s), ball at %.0f m/s: landed %d, worst one-tick change %.2f, rise %.2f (bound %.1f), closest drone centre %.2f m (>= 1.6), dive hit %s" % [count, roll, r.landed, r.tick, r.rise, BOUND, r.close, r.hit])

	# The dive still damages a ball inside the ring.
	game.combat.last_player_hit = {}
	game.player.reset_to(ball)
	game.player.immune_left = 0.0
	var drone = _spawn(Vector3(9.0, 0.0, 3.0), 6.0)
	for frame in 600:
		game.player.reset_to(ball)
		await physics_frame
		if drone.dives > 0 and drone.phase == drone.Phase.ROAM:
			break
	var hit: Dictionary = game.combat.last_player_hit
	t.check("KS-damage", hit.get("source", "") == "kite_drone",
		"dives %d, landed %s, last_player_hit source '%s'" % [drone.dives, drone._landed, hit.get("source", "")])
	drone.free()

	# A cruise-speed ball meeting a diving drone still bats it: the clamp leaves it touchable.
	game.combat.last_player_hit = {}
	game.player.reset_to(ball)
	drone = _spawn(Vector3(9.0, 0.0, 3.0), 6.0)
	var live := false
	for frame in 400:
		if drone.phase == drone.Phase.LIVE and drone._t > 0.2:
			live = true
			break
		game.player.set_velocity_now(Vector3(1.2 * game.player.tuning.f("cruise"), 0.0, 0.0))
		await physics_frame
	game.player.set_velocity_now(Vector3(1.2 * game.player.tuning.f("cruise"), 0.0, 0.0))
	await physics_frame
	var near: bool = drone.global_position.distance_to(game.player.ball_position()) >= 1.6
	game.combat.deal_hit(drone, "ram", 1.0, Vector3.RIGHT, EventKinds.IMPACT["ram"]["knock"], "", "", "ram")
	t.check("KS-bat", live and near and drone.batted == 1,
		"live %s, drone not inside the ball %s, batted %d" % [live, near, drone.batted])
	drone.free()
	var code := t.verdict()
	game.free()
	quit(code)
