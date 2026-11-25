extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Arena := preload("res://src/boss/arena.gd")
const Palette := preload("res://src/core/palette.gd")

# The fix wave's rules, tick by tick: pieces that cannot die are never crushable; the
# rim rescue keeps the ball's direction round the ring; drones arrive on a marked pad
# clear of the ball and aim at the arena's ground; the crust draws under telegraphs and
# the slag leaves the quenched span open; a landing needs the ball on top; the chase
# pays drone scrap; the clash preview counts ram punch only; and the boss publishes a
# live objective and plating for the HUD. Repointed 2026-10-04 (F2a fix round): Brindle
# is a posture body, so a cap landing and a stunned hull are measured as posture gain
# on the hull's bar, not as HP lost from a pool.

const DT := 1.0 / 90.0
const DRONE_CLEAR := 8.0

var _game
var _double
var _boss
var _failures := 0
var _started := false
var _spawns: Array = []


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
	_game.ctx.calm = false
	_game.player.source = Intent.Scripted.new()
	_game.events.enemy_spawned.connect(func(e: Node3D, kind: String): _spawns.append({"enemy": e, "kind": kind, "clock": _boss.clock, "ball": _game.player.ball_position()}))
	Harness.start_run(_game)
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_live_objective_checks(1)
	_rescue_direction()
	_furnace_checks()
	_charge_checks()
	_ground_checks()
	_chase_checks()
	_retry_checks()
	print("boss_fixwave_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


func _has(name: String) -> bool:
	return _boss.has_method(name)


func _advance(seconds: float, ball = null) -> void:
	for _i in int(seconds / DT):
		if ball is Vector3:
			Harness.put_ball(_game, ball)
		_boss.advance(DT)
		_game.run.heal(1000.0)


func _live_objective_checks(expected_phase: int) -> void:
	var text: String = _boss.objective_text() if _has("objective_text") else ""
	var plating: float = _boss.live_plating() if _has("live_plating") else -1.0
	# Re-pinned 2026-10-15 (BRINDLE-SCUTTLE): hull plating 120 to 110 in boss_rules.gd.
	_report("objective phase %d" % expected_phase, text.contains("crane magnets") and text.contains("plating 110") and plating == Rules.HULL_PLATING and _game.flow.boss_plating == Rules.HULL_PLATING,
		"objective \"%s\", live plating %.0f, flow.boss_plating %.0f" % [text, plating, _game.flow.boss_plating])


func _rescue_direction() -> void:
	var angle := 1.0
	var at: Vector3 = _boss.arena.point_at(angle, 67.0, 12.0)
	var clockwise: Vector3 = -Arena.tangent(angle) * 15.0
	Harness.put_ball(_game, at, clockwise)
	_boss.advance(DT)
	var ball: Vector3 = _game.player.ball_position()
	var v: Vector3 = _game.player.state.velocity
	var along: float = v.dot(Arena.tangent(_boss.arena.angle_of(ball)))
	_report("rim rescue keeps direction", _boss.arena.radius_of(ball) < 60.0 and along < -14.0,
		"a ball leaving over the rim clockwise at 15 m/s came back at r %.1f moving %.1f m/s along the counter-clockwise tangent" % [_boss.arena.radius_of(ball), along])


func _furnace_checks() -> void:
	_boss.jump_to_phase(2)
	var text: String = _boss.objective_text() if _has("objective_text") else ""
	_report("objective phase 2", text.contains("vent caps"), "objective \"%s\"" % text)

	var hull_side: Vector3 = _boss.ship.hull.to_global(Vector3(5.6, 0.0, 0.0))
	var pad := Vector3(hull_side.x, _boss.arena.ground(hull_side) + 1.0, hull_side.z)
	var marked := -1.0
	var pending: Array = []
	for _i in int(9.0 / DT):
		Harness.put_ball(_game, pad)
		_boss.advance(DT)
		pending = _boss.pending_drones() if _has("pending_drones") else []
		if marked < 0.0 and not pending.is_empty():
			marked = _boss.clock
		if not _spawns.is_empty():
			break
	var first: Dictionary = _spawns[0] if not _spawns.is_empty() else {}
	var lead: float = first.get("clock", -1.0) - marked
	var clear: float = (first["enemy"] as Node3D).global_position.distance_to(first["ball"]) if not first.is_empty() else -1.0
	var hull_gap: float = absf(_boss.ship.hull.to_local(first["enemy"].global_position).x) if not first.is_empty() else -1.0
	_report("drone arrival", marked >= 0.0 and lead >= 0.999 and clear >= DRONE_CLEAR and hull_gap >= 7.0,
		"a drone pad was marked %.2f s before the drone arrived, %.1f m from the ball (at least %.0f) and %.1f m off the hull's centre line"
			% [lead, clear, DRONE_CLEAR, hull_gap])
	var drone = first.get("enemy")
	var aim_ok := false
	if drone != null and drone.get("terrain") != null:
		var p: Vector3 = _boss.arena.point_at(0.5, 30.0)
		aim_ok = absf(drone.terrain.height(p.x, p.z) - _boss.arena.ground(p)) < 0.01
	_report("drone aims at the arena", aim_ok, "the drone's ground query answers the arena floor, not the parked stage 30 m below: %s" % aim_ok)

	var ring = null
	for _i in int(8.0 / DT):
		for h in _boss.active_hazards():
			if h.attack_id == "slag_ring_a" and h.is_live():
				ring = h
		if ring != null:
			break
		_boss.advance(DT)
	var vent := deg_to_rad(Arena.VENT_ANGLES[0])
	Harness.put_ball(_game, _boss.arena.point_at(vent, Arena.VENT_R, 1.0))
	_boss.advance(DT)
	var mid := (Arena.RING_A.x + Arena.RING_A.y) * 0.5
	var quenched: Vector3 = _boss.arena.point_at(vent, mid)
	var open: Vector3 = _boss.arena.point_at(PI, mid)
	_boss.advance(DT)
	var crust: Node = _boss.arena.get_node_or_null("Crust_0")
	var crust_priority: int = (crust.material_override as Material).render_priority if crust != null else 99
	var gap: bool = ring != null and ring.has_method("draws") and not ring.draws(quenched) and ring.draws(open)
	_report("crust under telegraphs", crust_priority < 40 and gap,
		"the crust draws at priority %d (telegraphs 40) and the live slag leaves the quenched span open: %s" % [crust_priority, gap])

	var cap = _boss.ship.caps[0]
	var beside: Vector3 = _boss.ship.hull.to_global(Vector3(5.6, -2.0, 0.0))
	Harness.put_ball(_game, Vector3(beside.x, _boss.arena.ground(beside) + 1.0, beside.z))
	var chunks: int = _boss.chunks_left()
	var before: float = _boss.posture()
	_double.strike(cap, "slam", 40.0)
	var from_floor: float = _boss.posture() - before
	Harness.put_ball(_game, cap.global_position + Vector3.UP * 1.6)
	before = _boss.posture()
	_double.strike(cap, "slam", 40.0)
	var on_top: float = _boss.posture() - before
	before = _boss.posture()
	_double.strike(cap, "synergy", 48.0)
	var synergy_on_top: float = _boss.posture() - before
	# A landing meets the open cap: the rule's slam base at its top ratio.
	var landing_gain: float = BossPosture.BASE["slam"] * pow(float(Rules.POSTURE.get("mult_max", BossPosture.MULT_MAX)), float(Rules.POSTURE["curve"]))
	_report("synergy is not a landing", synergy_on_top == 0.0 and _boss.chunks_left() == chunks,
		"a synergy strike of 48 on a cap with the ball on top, short of the hull's plating, moved the bar %.1f" % synergy_on_top)
	_report("landing needs the ball on top", from_floor == 0.0 and is_equal_approx(on_top, landing_gain) and _boss.chunks_left() == chunks,
		"a slam-kind strike on a cap with the ball on the floor beside the hull moved the bar %.1f; with the ball on the cap %.1f (want %.1f); chunks %d"
			% [from_floor, on_top, landing_gain, _boss.chunks_left()])


func _charge_checks() -> void:
	_boss.jump_to_phase(3)
	var hull = _boss.ship.hull
	Harness.put_ball(_game, _boss.arena.point_at(0.3, 30.0, 1.0))
	for _i in int(6.0 / DT):
		if _boss.charging():
			break
		_boss.advance(DT)
	var verb_charging: String = hull.tint_verb() if hull.has_method("tint_verb") else "?"
	_double.punch_override = 160.0
	hull.set_tint("amber")
	var shown: String = hull.tint_state
	_boss.advance(DT)
	var readout: String = _boss.ship.plate.text
	var plate_colour: Color = _boss.ship.plate.get_theme_color("font_color")
	var text: String = _boss.objective_text() if _has("objective_text") else ""
	var plating: float = _boss.live_plating() if _has("live_plating") else -1.0
	_double.punch_override = -1.0
	_report("clash preview is ram only", shown == "slate" and readout.contains("bow plating 150") and plate_colour != Palette.AMBER and plating == Rules.CLASH_PUNCH and text.contains("Ram 0 / bow plating 150"),
		"charging, with a 160 weapon and a standing ball: tint %s, readout \"%s\", objective \"%s\", live plating %.0f" % [shown, readout, text, plating])
	_report("ship plate stays off prompts band", _boss.ship.plate.owner_placed and not _boss.ship.plate.visible,
		"PF-54: owner_placed %s, visible %s" % [_boss.ship.plate.owner_placed, _boss.ship.plate.visible])
	_double.strike(hull, "ram", _double.force_for("ram", 151.0))
	var verb_stunned: String = hull.tint_verb() if hull.has_method("tint_verb") else "?"
	_report("tint verb", verb_charging == "ram" and verb_stunned == "",
		"the hull's tint_verb() reads \"%s\" while charging and \"%s\" once stunned" % [verb_charging, verb_stunned])
	var stunned: bool = _boss.stunned()
	var crushable: bool = hull.crushable() if hull.has_method("crushable") else true
	var would: bool = _double.would_crush(hull, "ram", 500.0)
	var before: float = _boss.posture()
	_double.strike(hull, "arc", 5.0)
	var open_hit: float = _boss.posture() - before
	var open_gain: float = BossPosture.OTHER_BASE * pow(float(Rules.POSTURE.get("mult_max", BossPosture.MULT_MAX)), float(Rules.POSTURE["curve"]))
	var live: float = _boss.live_plating() if _has("live_plating") else -1.0
	_report("stunned hull uncrushable", stunned and not crushable and not would and is_equal_approx(open_hit, open_gain) and live < 1.0,
		"stunned %s: crushable() %s, would_crush on a 500 ram %s, a 5 shot pressed the bar %.3f at the top ratio (want %.3f), live plating %.2f"
			% [stunned, crushable, would, open_hit, open_gain, live])


func _ground_checks() -> void:
	var worst := 0.0
	for k in 12:
		for r in [0.0, 20.0, 44.0, 52.0, 59.0]:
			var p: Vector3 = _boss.arena.point_at(TAU * k / 12.0, r)
			worst = maxf(worst, absf(_boss.ground_height_at(p + Vector3.UP * 7.0) - p.y))
	var below: float = _game.ctx.terrain.height(_boss.arena.global_position.x, _boss.arena.global_position.z)
	_report("arena ground seam", worst < 0.01 and _boss.arena.global_position.y - below >= 29.0,
		"ground_height_at() matches the bowl's floor and bank within %.3f m at 60 points; the parked stage lies %.0f m below" % [worst, _boss.arena.global_position.y - below])


func _chase_checks() -> void:
	_boss.jump_to_phase(4)
	_advance(Rules.EJECT_FLIGHT + 0.2)
	var text: String = _boss.objective_text() if _has("objective_text") else ""
	var plating: float = _boss.live_plating() if _has("live_plating") else -1.0
	_report("objective chase", text.contains("scooter") and plating == 0.0 and _game.flow.boss_plating == 0.0,
		"objective \"%s\", live plating %.0f, flow.boss_plating %.0f" % [text, plating, _game.flow.boss_plating])
	var drop_at: Vector3 = _boss.arena.point_at(2.0, 30.0, 1.0)
	var count: int = _boss.pickups_left().size()
	_game.run.record_kill("lobber", drop_at, 4)
	_report("chase drones pay", _boss.pickups_left().size() == count + 1, "a drone killed during the chase dropped %d pickup(s)" % (_boss.pickups_left().size() - count))
	var scooter = _boss.scooter
	Harness.put_ball(_game, scooter.global_position + Arena.tangent(_boss.arena.angle_of(scooter.global_position)) * 7.0)
	_double.strike(scooter, "slam", 10.0)
	var after_far: String = _boss.state_name()
	Harness.put_ball(_game, scooter.global_position + Vector3.UP * 1.8)
	_double.strike(scooter, "synergy", 10.0)
	var after_synergy: String = _boss.state_name()
	_report("synergy is not a catch", after_synergy == "eject", "a synergy strike with the ball on the scooter left the boss %s" % after_synergy)
	_double.strike(scooter, "slam", 10.0)
	_report("catch needs contact", after_far == "eject" and _boss.state_name() == "defeated",
		"a slam-kind strike with the ball 7 m away left the boss %s; with the ball on the scooter it was %s" % [after_far, _boss.state_name()])


# R on the boss death screen publishes stage_content_cleared("arena_retry") and enters
# again: the fight must start fresh, with nothing carried from the attempt that died.
func _retry_checks() -> void:
	var reasons: Array = []
	_game.events.stage_content_cleared.connect(func(reason: String): reasons.append(reason))
	Harness.enter(_game, Vector3(18.0, 0.0, 0.0))
	_boss.jump_to_phase(2)
	_advance(12.0)
	var busy: bool = not _boss.active_hazards().is_empty() or not _boss.pickups_left().is_empty()
	_game.run.damage(99999.0, "test")
	_game.flow.retry_stage()
	_report("arena retry is fresh", reasons.slice(-1) == ["arena_retry"] and busy and _boss.phase == 1 and _boss.hp == Rules.MAX_HP
			and _boss.active_hazards().is_empty() and _boss.pickups_left().is_empty() and _boss.pending_drones().is_empty() and _boss.clock == 0.0,
		"after %s the fight restarted at phase %d, hp %.0f, with %d hazards, %d pickups and %d drone pads left over (the dead attempt had some: %s)"
			% [str(reasons.slice(-1)), _boss.phase, _boss.hp, _boss.active_hazards().size(), _boss.pickups_left().size(), _boss.pending_drones().size(), busy])
