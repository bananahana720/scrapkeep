extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# Regression test for W46-FIX2: Brindle's Phase 3 Scuttle charge hit (and Furnace slag / crane
# tug) must never impart a 100+ m/s kinematic/impulse explosion or launch the ball over the Slag
# Bowl's rim wall, including across Engine.time_scale transitions (hit-stop ending on the frame
# after a hit, which previously divided dv by 0.05/90 and integrated it over 1/90 for a ~20x
# ~478 m/s sky launch), near the bowl bank/rim, or with the ball leaning on the hull flank
# through brace, turn, and live charge run.
#
# Evidence limit: scripted unsteered ball on real RigidBody3D physics and real Slag Bowl geometry;
# proves bounded post-hit kinematics, bowl containment, damage, lateral shove, CC immunity gating,
# and collision exception clearance.

const HIT_STOP_SCALE := 0.05
const HIT_STOP_DELTA_MAX := 0.005
const NORMAL_DELTA_MIN := 0.008
const MAX_SPEED := 45.0
const MAX_Y_REL := 20.0
const MAX_R := Arena.BANK_R + 1.5
const PRESS := 25.0

var _t := T.new("brindle_rim_throw_test")
var _game
var _boss
var _hits: Array = []
var _cc_ignored: Array = []
# Armed by a test case before a hit so the player_hit signal callback flips Engine.time_scale
# synchronously inside _charge_hit() / _slag_hit() (before the next tick's _integrate_forces).
var _on_hit_source := ""
var _on_hit_ts_next := -1.0
var _on_hit_delta := -1.0
var _on_hit_armed := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _reset_fight(phase: int) -> void:
	Engine.time_scale = 1.0
	_hits.clear()
	_cc_ignored.clear()
	_on_hit_source = ""
	_on_hit_ts_next = -1.0
	_on_hit_delta = -1.0
	_on_hit_armed = false
	_game.flow.retry_stage()
	_game.run.heal(1000.0)
	_game.ctx.calm = false
	_boss.jump_to_phase(phase)


func _arm_hit_flip(source: String, ts_next: float) -> void:
	_on_hit_source = source
	_on_hit_ts_next = ts_next
	_on_hit_delta = -1.0
	_on_hit_armed = true


func _on_player_hit(amount: float, source: String) -> void:
	_hits.append({"amount": amount, "source": source})
	if _on_hit_armed and source == _on_hit_source:
		_on_hit_armed = false
		_on_hit_delta = float(_boss._delta)
		if _on_hit_ts_next > 0.0:
			Engine.time_scale = _on_hit_ts_next


func _wait_for_scale(scale: float) -> float:
	Engine.time_scale = scale
	for _i in 30:
		await process_frame
		var d: float = float(_boss._delta)
		if (scale < 0.5 and d < HIT_STOP_DELTA_MAX) or (scale >= 0.5 and d >= NORMAL_DELTA_MIN):
			return d
	return float(_boss._delta)


# Advances past the phase transition and commits a Phase 3 charge aimed from `ship_pos` along `dir`.
func _stage_charge(ship_pos: Vector3, dir: Vector3, bait_dist: float) -> Node3D:
	var arena = _boss.arena
	var ship = _boss.ship
	var bait: Vector3 = ship_pos + dir * bait_dist
	bait.y = arena.ground(bait) + Tuning.RADIUS + 0.05
	for _i in int((FightPhases.TRANSITION_SECONDS + 0.15) * 90):
		ship.move_to(ship_pos, dir)
		Harness.put_ball(_game, bait + Vector3.UP * 25.0)
		await physics_frame
	for _i in 90 * 5:
		var st: String = _boss._charge.get("state", "")
		if st == _boss.CHARGE_REST:
			ship.move_to(ship_pos, dir)
			Harness.put_ball(_game, bait)
		elif st == _boss.CHARGE_BRACE:
			return _boss._charge["hazard"]
		await physics_frame
	return null


# Runs a real Phase 3 Scuttle charge into a ball placed in its lane, switching Engine.time_scale
# to `ts_hit` right before the bow reaches the ball and to `ts_next` on the tick after `_charge_hit`.
func _run_charge_case(label: String, ship_r: float, ball_dist: float, ball_lat: float,
		incoming_speed: float, ts_hit: float, ts_next: float, immune := false) -> Dictionary:
	_reset_fight(3)
	var arena = _boss.arena
	var ship = _boss.ship
	# 20 deg is an open radial corridor clear of the 0/180 deck ramps, 45/135/225/315 masts, and 90/270 kickers.
	var angle := deg_to_rad(20.0)
	var dir := Arena.dir(angle)
	var ship_pos: Vector3 = arena.point_at(angle, ship_r)
	var lane := await _stage_charge(ship_pos, dir, ball_dist)
	if lane == null:
		return {"ok": false, "reason": "no lane committed"}
	# Wait until the tell is almost done so the ship is square in the lane.
	for _i in 90 * 3:
		if not is_instance_valid(lane) or lane.age >= lane.warn_seconds - 0.02:
			break
		Harness.put_ball(_game, ship_pos + dir * 20.0 + Vector3.UP * 30.0)
		await physics_frame
	var hdg: Vector3 = lane.heading
	var sd: Vector3 = lane.side()
	var at: Vector3 = ship.global_position + hdg * ball_dist + sd * ball_lat
	at.y = arena.ground(at) + Tuning.RADIUS + 0.02
	Harness.put_ball(_game, at, -hdg * incoming_speed)
	if immune:
		_game.player.grant_immunity(2.0)

	var body: RigidBody3D = _game.player.body()
	var hit_tick := -1
	var hit_delta := -1.0
	var exc_on_hit := false
	var exc_cleared := false
	var max_spd := 0.0
	var max_y_rel := 0.0
	var max_r := 0.0
	var escaped := false
	var post_lat_v := 0.0
	var post_up_v := -INF
	var away_dir: Vector3 = sd * (1.0 if ball_lat >= 0.0 else -1.0)
	var lane_centre: Vector3 = lane.centre
	var lane_half: float = lane.half_width
	var scale_set := false
	_arm_hit_flip("brindle_charge", ts_next)

	for tick in 90 * 6:
		if hit_tick < 0 and not scale_set and is_instance_valid(lane) and lane.is_live():
			var along: float = lane.lane_along(_game.player.ball_position())
			# Arm ts_hit early enough that Main::iteration() reads it at least one frame before impact.
			if along <= lane.lane_front + 2.5:
				Engine.time_scale = ts_hit
				scale_set = true
		await process_frame
		if hit_tick < 0 and _hits.any(func(h): return h["source"] == "brindle_charge"):
			hit_tick = tick
			hit_delta = _on_hit_delta
			exc_on_hit = ship.hull.get_collision_exceptions().has(body)
		elif hit_tick >= 0 and tick == hit_tick + 3:
			# After the transition tick has integrated, restore normal scale so the flight plays out.
			Engine.time_scale = 1.0
		if hit_tick >= 0:
			var pos: Vector3 = _game.player.ball_position()
			var v: Vector3 = _game.player.state.velocity
			max_spd = maxf(max_spd, v.length())
			max_y_rel = maxf(max_y_rel, pos.y - arena.global_position.y)
			max_r = maxf(max_r, arena.radius_of(pos))
			if not arena.contains(pos):
				escaped = true
			if tick - hit_tick <= 6:
				post_lat_v = maxf(post_lat_v, v.dot(away_dir))
				post_up_v = maxf(post_up_v, v.y)
			if exc_on_hit and not exc_cleared and not ship.hull.get_collision_exceptions().has(body):
				exc_cleared = true
			if tick - hit_tick >= int((Rules.CHARGE_GRACE + 0.6) * 90) and (exc_cleared or not exc_on_hit):
				break

	Engine.time_scale = 1.0
	var end_pos: Vector3 = _game.player.ball_position()
	var end_lat: float = absf(Vector3(end_pos.x - lane_centre.x, 0.0, end_pos.z - lane_centre.z).dot(sd))
	var dmg := 0.0
	for h in _hits:
		if h["source"] == "brindle_charge":
			dmg += float(h["amount"])
	var delta_ok := (hit_delta > 0.0 and hit_delta < HIT_STOP_DELTA_MAX) if ts_hit < 0.5 else (hit_delta >= NORMAL_DELTA_MIN)
	return {
		"ok": hit_tick >= 0,
		"label": label,
		"hit_delta": hit_delta,
		"delta_ok": delta_ok,
		"dmg": dmg,
		"exc_on_hit": exc_on_hit,
		"exc_cleared": exc_cleared,
		"max_spd": max_spd,
		"max_y_rel": max_y_rel,
		"max_r": max_r,
		"escaped": escaped,
		"post_lat_v": post_lat_v,
		"post_up_v": post_up_v,
		"end_lat": end_lat,
		"lane_half": lane_half,
		"cc_ignored": _cc_ignored.duplicate(),
	}


# Tests a ball leaning on the hull flank through brace, turn, AND the entire live charge run.
func _check_flank_lean_through_charge() -> void:
	_reset_fight(3)
	var arena = _boss.arena
	var ship = _boss.ship
	for _i in int((FightPhases.TRANSITION_SECONDS + 0.15) * 90):
		await physics_frame
	var placed := false
	var press := Vector3.ZERO
	var saw_brace := false
	var saw_run := false
	var max_spd := 0.0
	var max_y_rel := 0.0
	var max_r := 0.0
	var escaped := false
	for _tick in 90 * 6:
		var st: String = _boss._charge.get("state", "")
		if not placed and st == _boss.CHARGE_REST:
			var starboard: Vector3 = (ship.heading as Vector3).rotated(Vector3.UP, -PI * 0.5)
			var at: Vector3 = ship.global_position + ship.heading * 3.5 + starboard * 5.52
			at.y = arena.ground(at) + Tuning.RADIUS + 0.02
			Harness.put_ball(_game, at)
			press = -starboard * PRESS
			placed = true
		if placed:
			_game.player.add_external_accel(press)
		await physics_frame
		st = _boss._charge.get("state", "")
		if st == _boss.CHARGE_BRACE:
			saw_brace = true
		elif st == _boss.CHARGE_RUN:
			saw_run = true
		var pos: Vector3 = _game.player.ball_position()
		var v: Vector3 = _game.player.state.velocity
		max_spd = maxf(max_spd, v.length())
		max_y_rel = maxf(max_y_rel, pos.y - arena.global_position.y)
		max_r = maxf(max_r, arena.radius_of(pos))
		if not arena.contains(pos):
			escaped = true
		if saw_run and st != _boss.CHARGE_RUN:
			break
	var local: Vector3 = ship.hull.to_local(_game.player.ball_position())
	var half := Requisition.HULL * 0.5
	var inside: bool = absf(local.x) < half.x and absf(local.y) < half.y and absf(local.z) < half.z
	_t.check("flank-leaning ball through brace, turn, and live charge run stays bounded inside the bowl",
		saw_brace and saw_run and not inside and not escaped and max_spd <= MAX_SPEED and max_y_rel <= MAX_Y_REL and max_r <= MAX_R,
		"brace=%s run=%s inside=%s escaped=%s max_spd=%.1f max_y=%.1f max_r=%.1f"
			% [saw_brace, saw_run, inside, escaped, max_spd, max_y_rel, max_r])


# Tests Furnace slag hit across a hit-stop end transition (0.05 -> 1.0): bounded bounce, no rim throw.
func _check_slag_hitstop_end() -> void:
	_reset_fight(2)
	var arena = _boss.arena
	var mid := (Arena.RING_A.x + Arena.RING_A.y) * 0.5
	var spot: Vector3 = arena.point_at(deg_to_rad(200.0), mid, Tuning.RADIUS + 0.02)
	var hit_tick := -1
	var hit_delta := -1.0
	var max_spd := 0.0
	var max_y_rel := 0.0
	var escaped := false
	_arm_hit_flip("brindle_slag", 1.0)
	for tick in 90 * 12:
		if hit_tick < 0:
			Harness.put_ball(_game, spot)
			for h in _boss.active_hazards():
				if h.attack_id == "slag_ring_a" and h.age >= h.warn_seconds - 0.04:
					Engine.time_scale = HIT_STOP_SCALE
		await process_frame
		if hit_tick < 0 and _hits.any(func(h): return h["source"] == "brindle_slag"):
			hit_tick = tick
			hit_delta = _on_hit_delta
		if hit_tick >= 0:
			var pos: Vector3 = _game.player.ball_position()
			var v: Vector3 = _game.player.state.velocity
			max_spd = maxf(max_spd, v.length())
			max_y_rel = maxf(max_y_rel, pos.y - arena.global_position.y)
			if not arena.contains(pos):
				escaped = true
			if tick - hit_tick >= int(1.5 * 90):
				break
	Engine.time_scale = 1.0
	var r_end: float = arena.radius_of(_game.player.ball_position())
	var cleared_ring: bool = r_end < Arena.RING_A.x or r_end > Arena.RING_A.y
	var delta_ok := hit_delta > 0.0 and hit_delta < HIT_STOP_DELTA_MAX
	_t.check("Furnace slag hit across hit-stop end stays bounded and still clears the ring",
		hit_tick >= 0 and delta_ok and cleared_ring and not escaped and max_spd <= MAX_SPEED and max_y_rel <= MAX_Y_REL,
		"hit=%s hit_delta=%.5f (< %.3f) cleared_ring=%s (r=%.1f) escaped=%s max_spd=%.1f max_y=%.1f"
			% [hit_tick >= 0, hit_delta, HIT_STOP_DELTA_MAX, cleared_ring, r_end, escaped, max_spd, max_y_rel])


# Tests Phase 1 crane tug across a hit-stop end transition (0.05 -> 1.0): bounded external_accel, no launch.
func _check_tug_hitstop_end() -> void:
	_reset_fight(1)
	var arena = _boss.arena
	var ball: Vector3 = arena.point_at(deg_to_rad(20.0), 20.0, Tuning.RADIUS + 0.02)
	Harness.put_ball(_game, ball)
	await process_frame
	# Wait until Main::iteration() has actually stepped boss._delta under HIT_STOP_SCALE.
	var tug_delta := await _wait_for_scale(HIT_STOP_SCALE)
	# At process_frame we sit between the hit-stop tick and the next frame's Main::iteration():
	# _tug() computes external_accel with _boss._delta == tug_delta, then Engine.time_scale = 1.0
	# makes the very next physics step integrate external_accel over 1/90.
	_boss._tug(ball, ball + Vector3(5.0, 3.0, 0.0))
	Engine.time_scale = 1.0
	var max_spd := 0.0
	var max_y_rel := 0.0
	for _i in 30:
		await process_frame
		var pos: Vector3 = _game.player.ball_position()
		max_spd = maxf(max_spd, _game.player.state.velocity.length())
		max_y_rel = maxf(max_y_rel, pos.y - arena.global_position.y)
	_t.check("Phase 1 crane tug across hit-stop end stays bounded and never launches",
		tug_delta > 0.0 and tug_delta < HIT_STOP_DELTA_MAX and max_spd <= 15.0 and max_y_rel <= 8.0,
		"tug_delta=%.5f (< %.3f) max_spd=%.1f (<= 15) max_y=%.1f (<= 8)"
			% [tug_delta, HIT_STOP_DELTA_MAX, max_spd, max_y_rel])


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.spawner = _game.combat
	_boss = _game.boss
	_game.player.source = Intent.Scripted.new()
	_game.events.player_hit.connect(_on_player_hit)
	_game.events.cc_ignored.connect(func(kind: String):
		_cc_ignored.append(kind))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	await physics_frame

	# 1. Exact seed-4 failure mode: head-on incoming ball hit by Scuttle charge on a hit-stop tick
	#    whose Engine.time_scale returns to 1.0 on the very next physics step. Negative lateral offset
	#    pushes counter-clockwise into open floor (away from the 0 deg deck ramp).
	var r_end := await _run_charge_case("hit-stop end (0.05 -> 1.0)", 16.0, 18.0, -1.5, 20.0, HIT_STOP_SCALE, 1.0)
	_t.check("charge hit across hit-stop end (0.05 -> 1.0) stays bounded and inside the bowl",
		r_end["ok"] and r_end["delta_ok"] and not r_end["escaped"] and r_end["max_spd"] <= MAX_SPEED
			and r_end["max_y_rel"] <= MAX_Y_REL and r_end["max_r"] <= MAX_R,
		"hit=%s hit_delta=%.5f max_spd=%.1f (<= %.0f) max_y=%.1f (<= %.0f) max_r=%.1f escaped=%s"
			% [r_end["ok"], r_end["hit_delta"], r_end["max_spd"], MAX_SPEED, r_end["max_y_rel"], MAX_Y_REL, r_end["max_r"], r_end["escaped"]])
	_t.check("charge hit across hit-stop end still deals full damage, shoves out of lane, and clears exception",
		r_end["ok"] and r_end["delta_ok"] and r_end["dmg"] >= Rules.CHARGE_DAMAGE - 0.01
			and r_end["post_lat_v"] >= Rules.CHARGE_SHOVE_SIDE * 0.75
			and r_end["post_up_v"] >= Rules.CHARGE_SHOVE_UP * 0.75 and r_end["end_lat"] > r_end["lane_half"]
			and r_end["exc_on_hit"] and r_end["exc_cleared"],
		"hit_delta=%.5f dmg=%.1f lat_v=%.1f up_v=%.1f end_lat=%.1f (> %.1f) exc=%s->cleared=%s"
			% [r_end["hit_delta"], r_end["dmg"], r_end["post_lat_v"], r_end["post_up_v"], r_end["end_lat"], r_end["lane_half"],
				r_end["exc_on_hit"], r_end["exc_cleared"]])

	# 2. Hit-stop sustained (0.05 -> 0.05) and hit-stop starting (1.0 -> 0.05): shove must stay full, not 0.05x.
	var r_cont := await _run_charge_case("hit-stop sustained (0.05 -> 0.05)", 16.0, 14.0, 1.0, 0.0, HIT_STOP_SCALE, HIT_STOP_SCALE)
	_t.check("charge hit during sustained hit-stop (0.05 -> 0.05) still delivers full crisp shove",
		r_cont["ok"] and r_cont["delta_ok"] and r_cont["post_lat_v"] >= Rules.CHARGE_SHOVE_SIDE * 0.75
			and r_cont["post_up_v"] >= Rules.CHARGE_SHOVE_UP * 0.75
			and r_cont["max_spd"] <= MAX_SPEED and r_cont["max_y_rel"] <= MAX_Y_REL and r_cont["exc_cleared"],
		"hit_delta=%.5f lat_v=%.1f up_v=%.1f max_spd=%.1f max_y=%.1f exc_cleared=%s"
			% [r_cont["hit_delta"], r_cont["post_lat_v"], r_cont["post_up_v"], r_cont["max_spd"], r_cont["max_y_rel"], r_cont["exc_cleared"]])

	var r_start := await _run_charge_case("hit-stop start (1.0 -> 0.05)", 16.0, 14.0, 1.0, 0.0, 1.0, HIT_STOP_SCALE)
	_t.check("charge hit into hit-stop start (1.0 -> 0.05) still delivers full crisp shove",
		r_start["ok"] and r_start["delta_ok"] and r_start["post_lat_v"] >= Rules.CHARGE_SHOVE_SIDE * 0.75
			and r_start["post_up_v"] >= Rules.CHARGE_SHOVE_UP * 0.75
			and r_start["max_spd"] <= MAX_SPEED and r_start["max_y_rel"] <= MAX_Y_REL and r_start["exc_cleared"],
		"hit_delta=%.5f lat_v=%.1f up_v=%.1f max_spd=%.1f max_y=%.1f exc_cleared=%s"
			% [r_start["hit_delta"], r_start["post_lat_v"], r_start["post_up_v"], r_start["max_spd"], r_start["max_y_rel"], r_start["exc_cleared"]])

	# 3. Direct nose/side hit near the bank/rim (r = 55 m) under hit-stop end transition.
	var r_rim := await _run_charge_case("near rim bank (r=55, 0.05 -> 1.0)", 38.0, 17.0, 0.5, 16.0, HIT_STOP_SCALE, 1.0)
	_t.check("direct nose hit near the Slag Bowl bank/rim stays inside the bowl and never throws over the rim",
		r_rim["ok"] and r_rim["delta_ok"] and not r_rim["escaped"] and r_rim["max_spd"] <= MAX_SPEED
			and r_rim["max_y_rel"] <= MAX_Y_REL and r_rim["max_r"] <= MAX_R and r_rim["exc_cleared"],
		"hit=%s hit_delta=%.5f max_spd=%.1f max_y=%.1f max_r=%.1f escaped=%s exc_cleared=%s"
			% [r_rim["ok"], r_rim["hit_delta"], r_rim["max_spd"], r_rim["max_y_rel"], r_rim["max_r"], r_rim["escaped"], r_rim["exc_cleared"]])

	# 4. CC-immune ball still honours crowd_control gate and ghosts past the hull.
	var r_imm := await _run_charge_case("cc-immune charge hit", 16.0, 14.0, 0.5, 0.0, 1.0, 1.0, true)
	_t.check("CC-immune ball refuses the shove impulse while still ghosting clear of the hull",
		r_imm["ok"] and r_imm["cc_ignored"].has("brindle_charge") and r_imm["post_lat_v"] < 3.0
			and r_imm["exc_on_hit"] and r_imm["exc_cleared"] and r_imm["max_spd"] <= MAX_SPEED,
		"cc_ignored=%s lat_v=%.1f exc=%s->cleared=%s max_spd=%.1f"
			% [str(r_imm["cc_ignored"]), r_imm["post_lat_v"], r_imm["exc_on_hit"], r_imm["exc_cleared"], r_imm["max_spd"]])

	# 5. Ball leaning on the hull flank through brace, turn, and live charge run.
	await _check_flank_lean_through_charge()

	# 6. Furnace slag hit and Phase 1 crane tug across hit-stop end transitions.
	await _check_slag_hitstop_end()
	await _check_tug_hitstop_end()

	Engine.time_scale = 1.0
	ChallengeDials.reset()
	_game.free()
	quit(_t.verdict())
