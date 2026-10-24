extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const CodexEntries := preload("res://src/boss/codex_entries.gd")

# Momentum in the arena, on the real rigid ball and physics: the entry keeps its speed,
# a ball thrown off the edge is back on the ring within a second at the same speed, a
# slag hit damages and bounces the ball out of the channel, a charge into the rim shoves
# the ball out of its lane instead of pinning it, and the eject scooter is caught by a
# ram and by a stomp at cruise.

const TOLERANCE := 0.15
const ENTRY_SPEED := 18.0
const THROW_SPEED := 15.0

var _game
var _double
var _boss
var _failures := 0
var _hits: Array = []
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _ticks(n: int) -> void:
	for _i in n:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_double = Harness.install(_game)
	_boss = _game.boss
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.events.player_hit.connect(func(amount: float, source: String): _hits.append({"amount": amount, "source": source, "at": _game.player.ball_position(), "clock": _boss.clock}))
	_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _f: float): if enemy == _boss.scooter: _struck.append(kind))
	Harness.start_run(_game)
	await _entry_check()
	await _rescue_check()
	await _slag_check()
	await _charge_check()
	await _mid_lane_check()
	await _ramp_bounce_check()
	await _scooter_check("ram")
	await _scooter_check("stomp")
	print("boss_momentum_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


func _entry_check() -> void:
	Harness.enter(_game, Vector3(ENTRY_SPEED, 2.0, 0.0))
	var lowest := INF
	for i in 90:
		await physics_frame
		if i >= 30:
			lowest = minf(lowest, Harness.planar(_game))
	var after := Harness.planar(_game)
	_report("arena entry momentum", (ENTRY_SPEED - after) / ENTRY_SPEED <= TOLERANCE and (ENTRY_SPEED - lowest) / ENTRY_SPEED <= TOLERANCE,
		"entered at %.2f m/s horizontal; %.2f m/s after 1 s on the bowl, never below %.2f after landing (loss within %d%%)"
			% [ENTRY_SPEED, after, lowest, int(TOLERANCE * 100.0)])


func _rescue_check() -> void:
	var lowest_rescue := INF
	for k in 16:
		var probe: Vector3 = _boss.arena.point_at(TAU * k / 16.0, 70.0, -20.0)
		lowest_rescue = minf(lowest_rescue, _boss.rescue_point(probe).y - _boss.floor_y())
	_report("rescue above floor", lowest_rescue >= 2.0,
		"rescue_point() sits at least %.1f m above floor_y() at 16 bearings, so a rescue never re-triggers" % lowest_rescue)
	var out := Arena.dir(0.0)
	var at: Vector3 = _boss.arena.global_position + out * 64.0 + Vector3.UP * (Arena.BANK_H + Arena.WALL_H + 1.0)
	Harness.put_ball(_game, at, out * THROW_SPEED)
	var back := -1.0
	for i in 90:
		await physics_frame
		var ball: Vector3 = _game.player.ball_position()
		if back < 0.0 and _boss.arena.radius_of(ball) <= Arena.BANK_R and ball.y >= _boss.floor_y():
			back = (i + 1) / 90.0
			await physics_frame
			break
	var speed := Harness.planar(_game)
	var ball: Vector3 = _game.player.ball_position()
	var drop: Vector3 = _boss.arena.point_at(2.0, 30.0) + Vector3.DOWN * 11.0
	Harness.put_ball(_game, drop, Arena.tangent(2.0) * THROW_SPEED + Vector3.DOWN * 5.0)
	var caught := -1.0
	for i in 90:
		await physics_frame
		var now: Vector3 = _game.player.ball_position()
		if now.y >= _boss.floor_y() and _boss.arena.radius_of(now) >= Arena.FLOOR_R:
			caught = (i + 1) / 90.0
			break
	_report("flow fall rescue", caught >= 0.0 and caught <= 1.0 and (THROW_SPEED - Harness.planar(_game)) / THROW_SPEED <= TOLERANCE,
		"a ball dropped through the floor was put on the ring by flow through rescue_point() after %.2f s at %.2f m/s horizontal"
			% [caught, Harness.planar(_game)])
	_report("fall rescue", back >= 0.0 and back <= 1.0 and (THROW_SPEED - speed) / THROW_SPEED <= TOLERANCE and _boss.arena.radius_of(ball) >= Arena.FLOOR_R,
		"thrown off the rim at %.1f m/s: back on the banked ring (r %.1f m) after %.2f s at %.2f m/s horizontal"
			% [THROW_SPEED, _boss.arena.radius_of(ball), back, speed])


func _slag_check() -> void:
	_game.ctx.calm = false
	_game.flow.retry_stage()
	_boss.jump_to_phase(2)
	var mid := (Arena.RING_A.x + Arena.RING_A.y) * 0.5
	var spot: Vector3 = _boss.arena.point_at(PI, mid, 1.0)
	var hp_before: float = _game.run.hp
	_hits.clear()
	var first := -1
	var in_band_live := 0
	var worst_stay := 0
	for i in int(9.0 * 90):
		if first < 0:
			Harness.put_ball(_game, spot)
		await physics_frame
		var slag := _hits.filter(func(h): return h["source"] == "brindle_slag")
		if first < 0 and not slag.is_empty():
			first = i
		if first >= 0:
			var ball: Vector3 = _game.player.ball_position()
			var r: float = _boss.arena.radius_of(ball)
			var low: bool = ball.y - _boss.arena.ground(ball) <= Rules.SLAG_REACH
			if low and r >= Arena.RING_A.x and r <= Arena.RING_A.y:
				in_band_live += 1
				worst_stay = maxi(worst_stay, in_band_live)
			else:
				in_band_live = 0
			if i - first >= int(1.5 * 90):
				break
	var ball: Vector3 = _game.player.ball_position()
	var r: float = _boss.arena.radius_of(ball)
	var slag_hits := _hits.filter(func(h): return h["source"] == "brindle_slag").size()
	_report("slag bounces, never traps", first >= 0 and slag_hits == 1 and hp_before - _game.run.hp >= Rules.SLAG_DAMAGE - 0.01
			and (r < Arena.RING_A.x or r > Arena.RING_A.y) and worst_stay <= int(0.5 * 90),
		"a ball resting in live slag took %d hit(s) for %.0f HP, spent at most %.2f s in the channel after it, and sat %.1f m out 1.5 s later (channel %.0f to %.0f m)"
			% [slag_hits, hp_before - _game.run.hp, worst_stay / 90.0, r, Arena.RING_A.x, Arena.RING_A.y])
	_game.run.heal(1000.0)


func _charge_check() -> void:
	_game.flow.retry_stage()
	_boss.jump_to_phase(3)
	var bearing: float = _boss.arena.angle_of(_boss.ship.global_position)
	var spot: Vector3 = _boss.arena.point_at(bearing, 54.0, 1.2)
	Harness.put_ball(_game, spot)
	_hits.clear()
	var hit_tick := -1
	var lane = null
	var lane_geo := {}
	var fastest := 0.0
	# Scuttle opens with the transition beat (fight_phases.gd), so the first charge comes that much later.
	for i in int((6.0 + FightPhases.TRANSITION_SECONDS) * 90):
		# The ball rests at the rim until the charge commits, through the beat too.
		if _boss._charge.get("state", "") == "rest":
			Harness.put_ball(_game, spot)
		await physics_frame
		if _boss._charge.has("hazard") and is_instance_valid(_boss._charge["hazard"]):
			lane = _boss._charge["hazard"]
			# The lane's committed numbers, kept past the hazard's free after a wall stun.
			lane_geo = {"centre": lane.centre, "side": lane.side(), "half": lane.half_width, "reach": lane.reach}
		if hit_tick < 0 and _hits.any(func(h): return h["source"] == "brindle_charge"):
			hit_tick = i
		if hit_tick >= 0:
			fastest = maxf(fastest, _game.player.state.velocity.length())
			if i - hit_tick >= int(1.5 * 90):
				break
	var ball: Vector3 = _game.player.ball_position()
	var local: Vector3 = _boss.ship.hull.to_local(ball)
	var half := Requisition.HULL * 0.5
	var inside_hull: bool = absf(local.x) < half.x + 0.9 and absf(local.y) < half.y + 0.9 and absf(local.z) < half.z + 0.9
	var lateral: float = absf(Vector3(ball.x - lane_geo["centre"].x, 0.0, ball.z - lane_geo["centre"].z).dot(lane_geo["side"])) if not lane_geo.is_empty() else -1.0
	var out_of_lane: bool = not lane_geo.is_empty() and (lateral > lane_geo["half"] or ball.y - _boss.arena.ground(ball) > lane_geo["reach"])
	_report("charge never pins", hit_tick >= 0 and not inside_hull and out_of_lane and fastest > 6.0 and _boss.stunned() and _game.codex.known(CodexEntries.WALL_BAIT),
		"a ball resting at the rim in the lane was hit, shoved to %.1f m/s, and 1.5 s later sat %.1f m off the lane centre (half width %.1f), clear of the hull %s; the ship hit the wall and is stunned %s (codex %s)"
			% [fastest, lateral, lane_geo.get("half", -1.0), not inside_hull, _boss.stunned(), _game.codex.known(CodexEntries.WALL_BAIT)])
	_game.run.heal(1000.0)


func _scooter_check(kind: String) -> void:
	_game.ctx.calm = true
	Harness.enter(_game, Vector3(ENTRY_SPEED, 0.0, 0.0))
	_boss.jump_to_phase(4)
	_struck.clear()
	while not _boss.scooter_landed():
		await physics_frame
	await physics_frame
	var angle: float = _boss._eject["angle"]
	var dir: float = _boss._eject["dir"]
	var cruise: float = _game.tuning.f("cruise")
	var at: Vector3 = _boss.scooter.global_position
	var along: Vector3 = Arena.tangent(angle) * dir
	if kind == "ram":
		var ahead: Vector3 = _boss.arena.point_at(angle + dir * 7.0 / Rules.SCOOTER_RING, Rules.SCOOTER_RING, 1.2)
		Harness.put_ball(_game, ahead, -along * cruise)
	else:
		Harness.put_ball(_game, at + Vector3.UP * 3.0, along * Rules.SCOOTER_SPEED + Vector3.DOWN * 8.0)
	var won_at := -1.0
	for i in 90:
		await physics_frame
		if _boss.state_name() == "defeated":
			won_at = (i + 1) / 90.0
			break
	# A landing reaches combat as whatever kind the spine reports; the boss reads a
	# contact from above as the stomp, so the landing is what this checks.
	var how: bool = _struck.has("ram") if kind == "ram" else _game.codex.known(CodexEntries.SCOOTER_STOMP)
	_report("scooter caught by %s" % kind, won_at >= 0.0 and not _struck.is_empty() and how,
		"a %s caught Brindle's scooter %.2f s after the ball was placed; the spine reported %s; %s"
			% ["ram at cruise %.0f m/s" % cruise if kind == "ram" else "landing on top at its pace", won_at, str(_struck),
				"codex Boarding Party %s" % _game.codex.known(CodexEntries.SCOOTER_STOMP) if kind == "stomp" else "caught by the ram"])


# A ball resting mid-floor in a charge lane is shoved sideways; the hull's bow must not
# carry it down the lane.
func _mid_lane_check() -> void:
	_game.ctx.calm = false
	_game.flow.retry_stage()
	_boss.jump_to_phase(3)
	var ship: Vector3 = _boss.ship.global_position
	var toward: Vector3 = (_boss.arena.global_position - ship)
	toward = Vector3(toward.x, 0.0, toward.z).normalized()
	var spot: Vector3 = ship + toward * 16.0
	spot = Vector3(spot.x, _boss.arena.ground(spot) + 1.0, spot.z)
	_hits.clear()
	var lane = null
	var hit_tick := -1
	var carried := 0.0
	for i in int(6.0 * 90):
		if lane == null:
			Harness.put_ball(_game, spot)
		await physics_frame
		if lane == null and _boss._charge.has("hazard"):
			lane = _boss._charge["hazard"]
		if hit_tick < 0 and _hits.any(func(h): return h["source"] == "brindle_charge"):
			hit_tick = i
		if hit_tick >= 0:
			carried = maxf(carried, _game.player.state.velocity.dot(lane.heading))
			if i - hit_tick >= int(0.8 * 90):
				break
	var ball: Vector3 = _game.player.ball_position()
	var off: float = absf(lane.lane_lateral(ball)) if lane != null else -1.0
	_report("charge shoves, never carries", hit_tick >= 0 and carried < 8.0 and off > lane.half_width,
		"a ball resting mid-lane was hit and moved at most %.1f m/s along the lane (the hull runs %.0f), and sat %.1f m off the lane centre 0.8 s later"
			% [carried, Rules.CHARGE_SPEED, off])
	_game.run.heal(1000.0)


# A slag bounce at a deck ramp's bearing must not end against the ramp's end face.
func _ramp_bounce_check() -> void:
	_game.flow.retry_stage()
	_boss.jump_to_phase(2)
	var bearing := deg_to_rad(Arena.RAMP_ANGLES[0])
	var spot: Vector3 = _boss.arena.point_at(bearing, 20.0, 1.0)
	_hits.clear()
	var hit_tick := -1
	var slowest := INF
	var reached := 0.0
	for i in int(9.0 * 90):
		if hit_tick < 0:
			Harness.put_ball(_game, spot)
		await physics_frame
		if hit_tick < 0 and _hits.any(func(h): return h["source"] == "brindle_slag"):
			hit_tick = i
		if hit_tick >= 0:
			var ball: Vector3 = _game.player.ball_position()
			reached = maxf(reached, _boss.arena.radius_of(ball))
			if i - hit_tick >= 10 and i - hit_tick <= int(1.0 * 90):
				slowest = minf(slowest, _game.player.state.velocity.length())
			if i - hit_tick >= int(1.3 * 90):
				break
	var face := Arena.RAMP_TO - 1.2
	_report("slag bounce clears the ramp", hit_tick >= 0 and (reached < face or slowest > 4.0),
		"a slag hit at the ramp bearing, 20 m out: the ball reached r %.1f (ramp face at %.0f) and never slowed below %.1f m/s in flight" % [reached, Arena.RAMP_TO, slowest])
	_game.run.heal(1000.0)
