extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const T := preload("res://tests/support/t.gd")

# Aerial reach: a pilot latched on a line, well off the ground, is hit by the kite drone's dive
# (an aerial mark at the swing arc's forecast) and by the plated brute's hurl, while a grounded
# ball's dive and slam are the ground marks they always were.

var game
var t := T.new("aerial_reach_test")
var ball := Vector3.ZERO
var facts := []


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


# Latches the ball `height` m above the ground: the anchor `lift` m over it and `side` m to the
# +z side, the rope the straight distance, so side 0 hangs and side > 0 swings.
func _latch(height: float, lift: float, side: float) -> void:
	var at := ball + Vector3(0.0, height, side)
	game.player.reset_to(at)
	game.player.immune_left = 0.0
	var anchor := ball + Vector3(0.0, height + lift, 0.0)
	Augments.attach(game.player.kit, at, anchor)


func _spawn(kind: String, offset: Vector3, height: float):
	var at := Vector3(ball.x + offset.x, 0.0, ball.z + offset.z)
	at.y = game.ctx.terrain.height(at.x, at.z) + height
	var enemy = game.combat.spawn_enemy(kind, at)
	enemy._strafe = 1.0
	enemy._rest = 0.0
	enemy.hp = 100000.0
	facts = []
	enemy.attack_phase.connect(func(f: Dictionary): facts.append(f))
	return enemy


# Frames until the enemy has dived or struck and is back to ROAM, the pilot left to physics when
# latched and parked when not. Returns the first hit and the telegraph seen while it warned.
func _until_spent(enemy, parked: bool, budget := 900) -> Dictionary:
	var out := {"warned": false, "aerial": false, "reach": 0.0, "warn": 0.0}
	for frame in budget:
		if parked:
			game.player.reset_to(ball)
		if enemy.phase == enemy.Phase.WARN and not out.warned:
			var tele = enemy.telegraph()
			out.warned = tele != null
			if tele != null:
				out.aerial = tele.aerial
				out.reach = tele.reach_up
		if enemy.phase == enemy.Phase.LIVE:
			out.warn = enemy.last_warn
			out["miss"] = _miss(enemy.telegraph())
			out["covered"] = _covers(enemy.telegraph())
		if out.warned and enemy.phase == enemy.Phase.ROAM:
			break
		await physics_frame
	return out


func _covers(tele) -> bool:
	return tele != null and tele.contains(game.player.ball_position())


# How far the ball is from the committed mark: flat metres, and metres outside its height band.
func _miss(tele) -> String:
	if tele == null:
		return "no mark"
	var b: Vector3 = game.player.ball_position()
	var flat := Vector2(b.x - tele.center.x, b.z - tele.center.z).length()
	return "flat %.1f of %.1f, y %.1f in [%.1f, %.1f]" % [flat, tele.radius, b.y, tele.center.y, tele.center.y + tele.reach_up]


func _hit_by(source: String) -> bool:
	return game.combat.last_player_hit.get("source", "") == source


func _run() -> void:
	await _boot()

	# 1: planted control. Hung at 15 m on a line, the pilot does not move; the dive reaches it.
	_latch(15.0, 8.0, 0.0)
	await _frames(20)
	var hung: Vector3 = game.player.ball_position()
	game.combat.last_player_hit = {}
	var drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 15.0)
	var seen: Dictionary = await _until_spent(drone, false)
	t.check("AR-1 planted control", game.player.kit.hooked and hung.y - game.ctx.terrain.height(hung.x, hung.z) >= 14.0 \
		and drone.dives == 1 and _hit_by("kite_drone"),
		"hooked %s, hung %.1f m up, dives %d, hit '%s'" % [game.player.kit.hooked, hung.y - game.ctx.terrain.height(hung.x, hung.z), drone.dives, game.combat.last_player_hit.get("source", "")])
	t.check("AR-4 telegraph floor", seen.aerial and seen.warn >= 0.6 and seen.reach > 2.0,
		"aerial %s, band %.1f m, warned %.2f s" % [seen.aerial, seen.reach, seen.warn])
	drone.free()

	# 2: swinging pilots. The ball falls through the arc on its rope; the lead follows the arc.
	# A ball at cruise or faster meets the diving drone and bats it (the standing rule), so the
	# two slower swings must be hit, and the fast one must have the mark on it when it lands.
	var swing_hits := 0
	var swing_dives := 0
	var lines := []
	for lean in [3.0, 6.0]:
		_latch(16.0, 7.0, lean)
		await _frames(10)
		game.combat.last_player_hit = {}
		drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 15.0)
		seen = await _until_spent(drone, false)
		swing_dives += drone.dives
		swing_hits += 1 if _hit_by("kite_drone") else 0
		lines.append("lean %.0f: %s, tier %d" % [lean, seen.get("miss", ""), game.player.speed_tier()])
		drone.free()
	t.check("AR-2 swinging pilot", swing_dives == 2 and swing_hits == 2,
		"%d of %d swinging dives hit (%s)" % [swing_hits, swing_dives, "; ".join(lines)])
	_latch(16.0, 7.0, 9.0)
	await _frames(10)
	drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 15.0)
	seen = await _until_spent(drone, false)
	t.check("AR-2b fast swing covered", drone.dives == 1 and (seen.get("covered", false) or drone.batted == 1),
		"%s, batted %d" % [seen.get("miss", ""), drone.batted])
	drone.free()

	# 3: a grounded pilot's dive is the ground mark it was, and still lands.
	game.player.reset_to(ball)
	game.player.immune_left = 0.0
	await _frames(10)
	game.combat.last_player_hit = {}
	drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 6.0)
	seen = await _until_spent(drone, true)
	t.check("AR-3 grounded dive", seen.warned and not seen.aerial and is_equal_approx(seen.reach, drone.MARK_REACH) \
		and drone.dives == 1 and _hit_by("kite_drone"),
		"aerial %s, reach %.1f, dives %d, hit '%s'" % [seen.aerial, seen.reach, drone.dives, game.combat.last_player_hit.get("source", "")])
	drone.free()

	# 5: the plated brute hurls at a hung pilot, and still slams a grounded one.
	_latch(15.0, 8.0, 0.0)
	await _frames(20)
	game.combat.last_player_hit = {}
	var brute = _spawn("plated_brute", Vector3(10.0, 0.0, 0.0), 1.0)
	seen = await _until_spent(brute, false)
	t.check("AR-5 brute hurl", game.player.kit.hooked and brute.hurls == 1 and brute.slams == 0 and seen.aerial and seen.warn >= 0.6 \
		and _hit_by("plated_brute"),
		"hurls %d, slams %d, aerial %s, warned %.2f s, hit '%s'" % [brute.hurls, brute.slams, seen.aerial, seen.warn, game.combat.last_player_hit.get("source", "")])
	brute.free()
	game.player.reset_to(ball)
	game.player.immune_left = 0.0
	await _frames(10)
	game.combat.last_player_hit = {}
	brute = _spawn("plated_brute", Vector3(3.0, 0.0, 0.0), 1.0)
	seen = await _until_spent(brute, true)
	t.check("AR-6 brute slam unchanged", brute.slams == 1 and brute.hurls == 0 and not seen.aerial and _hit_by("plated_brute"),
		"slams %d, hurls %d, aerial %s, hit '%s'" % [brute.slams, brute.hurls, seen.aerial, game.combat.last_player_hit.get("source", "")])
	brute.free()
	quit(t.verdict())
