extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const SwingArc := preload("res://src/combat/swing_arc.gd")
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
# `along` side (+z by default), the rope the straight distance, so side 0 hangs and side > 0 swings.
func _latch(height: float, lift: float, side: float, along := Vector3(0.0, 0.0, 1.0)) -> void:
	var at := ball + Vector3(0.0, height, 0.0) + along * side
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
func _until_spent(enemy, parked: bool, release := false, budget := 900) -> Dictionary:
	var out := {"warned": false, "aerial": false, "reach": 0.0, "warn": 0.0, "hits": []}
	for frame in budget:
		if not is_instance_valid(enemy):
			out["died"] = true
			break
		out["dives"] = enemy.get("dives")
		out["batted"] = enemy.get("batted")
		out["hurls"] = enemy.get("hurls")
		out["slams"] = enemy.get("slams")
		# Every source that hit the ball in the window, so a later hazard hit (a silt boil under the parked ball) cannot hide the enemy's.
		var source: String = game.combat.last_player_hit.get("source", "")
		if source != "" and not out.hits.has(source):
			out.hits.append(source)
		if parked:
			game.player.reset_to(ball)
		if enemy.phase == enemy.Phase.WARN and not out.warned:
			var tele = enemy.telegraph()
			out.warned = tele != null
			if tele != null:
				out.aerial = tele.aerial
				out.reach = tele.reach_up
				out["desc"] = tele.descriptor()
				out["flight"] = tele.has_flight
				if release:
					game.player.cut_line("let_go")
		if enemy.phase == enemy.Phase.LIVE:
			out.warn = enemy.last_warn
			out["miss"] = _miss(enemy.telegraph())
			if enemy.get("_t") != null and enemy._t > 0.6 and enemy.telegraph() != null:
				var tele2 = enemy.telegraph()
				var goal: Vector3 = tele2.center + Vector3.UP * (tele2.reach_up * 0.5 if tele2.aerial else 0.5)
				out["goal_off"] = enemy.global_position.distance_to(goal)
				out["goal_ball"] = goal.distance_to(game.player.ball_position())
				out["ball_gap"] = enemy.global_position.distance_to(game.player.ball_position())
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


func _drop(enemy) -> void:
	if is_instance_valid(enemy):
		enemy.free()


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
		and seen.dives == 1 and _hit_by("kite_drone"),
		"hooked %s, hung %.1f m up, dives %d, hit '%s'" % [game.player.kit.hooked, hung.y - game.ctx.terrain.height(hung.x, hung.z), seen.dives, game.combat.last_player_hit.get("source", "")])
	t.check("AR-4 telegraph floor", seen.aerial and seen.warn >= 0.6 and seen.reach > 2.0 \
		and seen.desc.get("aerial", false) and is_equal_approx(seen.desc["reach"], seen.reach),
		"aerial %s, band %.1f m, warned %.2f s, descriptor aerial %s" % [seen.aerial, seen.reach, seen.warn, seen.desc.get("aerial", false)])
	# A dive never ends inside the ball (a stacked dive's depenetration launched it past 90 m/s):
	# at the band middle when the ball is clear of it, at contact distance (ball 1.0 + drone 0.8) when the ball occupies it.
	var goal_clear: bool = seen.get("goal_ball", 0.0) > 1.9
	var goal_ok: bool = seen.get("goal_off", 99.0) <= 0.6 if goal_clear else absf(seen.get("ball_gap", 99.0) - 1.8) <= 0.1
	t.check("AR-1b dive goal", goal_ok, "drone %.2f m from the middle of the band, %.2f m from the ball (goal %.2f m from the ball, %s) near the end of the dive" % [seen.get("goal_off", 99.0), seen.get("ball_gap", 99.0), seen.get("goal_ball", 99.0), "clear" if goal_clear else "occupied"])
	_drop(drone)

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
		swing_dives += seen.dives
		swing_hits += 1 if _hit_by("kite_drone") else 0
		lines.append("lean %.0f: %s, tier %d" % [lean, seen.get("miss", ""), game.player.speed_tier()])
		_drop(drone)
	t.check("AR-2 swinging pilot", swing_dives == 2 and swing_hits == 2,
		"%d of %d swinging dives hit (%s)" % [swing_hits, swing_dives, "; ".join(lines)])
	# 2b: the bat needs the ball to meet the diving drone. The ball swings along x toward the side the
	# drone dives from, so its line of travel runs through the drone at the landing.
	var meets := []
	for lean in [9.0, 3.0]:
		_latch(16.0, 7.0, lean, Vector3.RIGHT)
		await _frames(10)
		drone = _spawn("kite_drone", Vector3(-9.0, 0.0, 3.0), 15.0)
		game.combat.last_player_hit = {}
		seen = await _until_spent(drone, false)
		meets.append({"batted": seen.batted, "dives": seen.dives, "tier": game.player.speed_tier(), "hit": _hit_by("kite_drone"), "gap": seen.get("ball_gap", 99.0)})
		_drop(drone)
	t.check("AR-2b air bat (meet at cruise)", meets[0].dives == 1 and meets[0].batted == 1 and not meets[0].hit,
		"batted %d (the drone itself requires cruise or faster), dives %d, hit %s" % [meets[0].batted, meets[0].dives, meets[0].hit])
	t.check("AR-2b meet below cruise", meets[1].dives == 1 and meets[1].batted == 0,
		"batted %d, dives %d, tier %d, hit %s" % [meets[1].batted, meets[1].dives, meets[1].tier, meets[1].hit])
	# The old skim: the ball swings across the dive, 1.6 m beside the landing, and never touches the drone. Base
	# batted it only because the dive teleported the drone into the ball (the stacked-dive launch's cause).
	_latch(16.0, 7.0, 9.0)
	await _frames(10)
	drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 15.0)
	game.combat.last_player_hit = {}
	seen = await _until_spent(drone, false)
	# The ring decides the hit, not contact: a ball inside the ring takes the dive even at cruise.
	t.check("AR-2b skim is no meeting", seen.dives == 1 and seen.batted == 0 and game.player.speed_tier() >= 1 \
		and _hit_by("kite_drone") == seen.get("covered", false),
		"batted %d, dives %d, tier %d, hit %s, ring covered %s, drone %.2f m from the ball" % [seen.batted, seen.dives, game.player.speed_tier(), _hit_by("kite_drone"), seen.get("covered", false), seen.get("ball_gap", 99.0)])
	_drop(drone)

	# 3: a grounded pilot's dive is the ground mark it was, and still lands.
	game.player.reset_to(ball)
	game.player.immune_left = 0.0
	await _frames(10)
	game.combat.last_player_hit = {}
	drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 6.0)
	seen = await _until_spent(drone, true)
	t.check("AR-3 grounded dive", seen.warned and not seen.aerial and is_equal_approx(seen.reach, 2.0) \
		and seen.dives == 1 and _hit_by("kite_drone"),
		"aerial %s, reach %.1f, dives %d, hit '%s'" % [seen.aerial, seen.reach, seen.dives, game.combat.last_player_hit.get("source", "")])
	_drop(drone)

	# 7: a pilot who lets go when the mark appears falls out of its band and is missed.
	_latch(16.0, 8.0, 0.0)
	await _frames(20)
	game.combat.last_player_hit = {}
	drone = _spawn("kite_drone", Vector3(9.0, 0.0, 3.0), 15.0)
	seen = await _until_spent(drone, false, true)
	t.check("AR-7 escape the dive", seen.aerial and not game.player.kit.hooked and seen.dives == 1 and not _hit_by("kite_drone"),
		"aerial %s, hooked %s, dives %d, hit '%s', %s" % [seen.aerial, game.player.kit.hooked, seen.dives, game.combat.last_player_hit.get("source", ""), seen.get("miss", "")])
	_drop(drone)

	# 8: the forecast against the real ball: 1.5 s ahead, three swing phases, then a fast swing.
	var worst := 0.0
	for lean in [4.0, 6.0, 8.0]:
		_latch(16.0, 7.0, lean)
		await _frames(10)
		for phase in 3:
			await _frames(37 + phase * 11)
			var guess: Vector3 = SwingArc.forecast(game.player, 1.5)
			await _frames(135)
			worst = maxf(worst, guess.distance_to(game.player.ball_position()))
	t.check("AR-8 forecast", worst <= 0.05, "worst error %.4f m over 9 swings at 1.5 s" % worst)
	_latch(24.0, 1.0, 14.0)
	await _frames(10)
	var peak := 0.0
	var fast_worst := 0.0
	for phase in 4:
		await _frames(30)
		peak = maxf(peak, game.player.state.velocity.length())
		var guess2: Vector3 = SwingArc.forecast(game.player, 1.5)
		await _frames(135)
		fast_worst = maxf(fast_worst, guess2.distance_to(game.player.ball_position()))
	t.check("AR-8b fast forecast", peak > 1.15 * game.player.tuning.f("cruise") and fast_worst <= 0.05,
		"peak speed %.1f m/s (over-speed drag above %.1f), worst error %.3f m" % [peak, 1.15 * game.player.tuning.f("cruise"), fast_worst])

	# 5: the plated brute hurls at a hung pilot, and still slams a grounded one.
	_latch(15.0, 8.0, 0.0)
	await _frames(20)
	game.combat.last_player_hit = {}
	var brute = _spawn("plated_brute", Vector3(10.0, 0.0, 0.0), 1.0)
	seen = await _until_spent(brute, false)
	t.check("AR-5 brute hurl", game.player.kit.hooked and seen.hurls == 1 and seen.slams == 0 and seen.aerial and seen.flight and seen.warn >= 0.6 \
		and _hit_by("plated_brute"),
		"hurls %d, slams %d, aerial %s, warned %.2f s, hit '%s'" % [seen.hurls, seen.slams, seen.aerial, seen.warn, game.combat.last_player_hit.get("source", "")])
	_drop(brute)
	_latch(15.0, 8.0, 0.0)
	await _frames(20)
	game.combat.last_player_hit = {}
	brute = _spawn("plated_brute", Vector3(10.0, 0.0, 0.0), 1.0)
	seen = await _until_spent(brute, false, true)
	t.check("AR-9 escape the hurl", seen.aerial and seen.hurls == 1 and not _hit_by("plated_brute"),
		"aerial %s, hurls %d, hit '%s', %s" % [seen.aerial, seen.hurls, game.combat.last_player_hit.get("source", ""), seen.get("miss", "")])
	_drop(brute)
	_latch(40.0, 8.0, 0.0)
	await _frames(20)
	game.combat.last_player_hit = {}
	brute = _spawn("plated_brute", Vector3(10.0, 0.0, 0.0), 1.0)
	await _frames(300)
	t.check("AR-10 hurl cap", brute.hurls == 0 and not brute._can_hurl(Vector3(10.0, 0.0, 0.0)),
		"hurls %d with the ball %.0f m over the brute (cap %.0f)" % [brute.hurls, game.player.ball_position().y - brute.global_position.y, brute.HURL_MAX_UP])
	brute.free()
	game.player.reset_to(ball)
	game.player.immune_left = 0.0
	await _frames(10)
	game.combat.last_player_hit = {}
	brute = _spawn("plated_brute", Vector3(3.0, 0.0, 0.0), 1.0)
	seen = await _until_spent(brute, true)
	t.check("AR-6 brute slam unchanged", seen.slams == 1 and seen.hurls == 0 and not seen.aerial and seen.hits.has("plated_brute"),
		"slams %d, hurls %d, aerial %s, hits %s" % [seen.slams, seen.hurls, seen.aerial, seen.hits])
	_drop(brute)
	quit(t.verdict())
