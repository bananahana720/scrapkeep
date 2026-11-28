extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Habits := preload("res://src/combat/habits.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Warden := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The Mind's fight on the default table, world three, with a seeded 'ram' habit. The
# module conforms to both BossContract surfaces; it is fought with paced TARGET hits that
# start after IDLE_FRAMES and come every HIT_EVERY frames, so the fight outlasts the intro
# plus two attack periods and reaches phase 2. Every attack that lands was announced on
# boss_attack_telegraphed at least 90% of its warn earlier, and at least one landed; every
# weak point is the choir Warden's lens; the first stagger braces the top habit's kinds
# (a braced kind meets plating * CHOIR_BRACE_MULT on the body, an unbraced one the plating);
# the Mind remembered the habit; every hand it sent is a mind_hand roster enemy, never a
# boss piece. Victory reaches the summary with one run_ended(true).
#
# Evidence limit: hits are TARGET calls, not ball contacts; the ball is the test-mode bot,
# so which attacks land depends on its path; the world is entered through flow's seams.

const FIGHT_CAP := 90 * 90
const IDLE_FRAMES := 90 * 5
const HIT_EVERY := 90
const STATE_FRAMES := 90 * 10
const TICKS := 90.0

var _t := T.new("mind_fight_test")
var _game
var _telegraphs: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _walk()
	_game.free()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	# The Mind's win opens the Q16 ending (fly-over, victory lap, credits); victory_lap_test owns it. This test ends on the summary.
	flow.victory_lap = false
	var seen = Harness.counter(game)
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, warn: float):
		_telegraphs.append({"id": id, "warn": warn, "frame": Engine.get_physics_frames()}))
	Harness.boot(game)
	var fleet = game.ctx.spawner.fleet
	fleet.habits.add("ram", 5.0)
	var memory_before: int = fleet.mind_memory.size()
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	var path: String = mod.get_script().resource_path if mod != null else "none"
	if not _t.check("world 3 module is mind.gd and ctx.boss", path.ends_with("mind.gd") and game.ctx.boss == mod,
			"module %s, ctx.boss is it %s" % [path, game.ctx.boss == mod]):
		return
	var shape: Dictionary = Harness.conforms(mod)
	_t.eq("module conforms to MODULE", shape["module"], [])
	_t.eq("target conforms to TARGET", shape["target"], [])
	var warden = Harness.target(mod)
	_t.check("the Warden is a MIND choir Warden with the fleet", warden.family == Roster.MIND and warden.variant == "choir"
			and warden.fleet == fleet, "family %s, variant %s, fleet %s" % [warden.family, warden.variant, warden.fleet == fleet])

	_check_movement_pressure(game, mod)

	var points_before: int = seen.points.size()
	var defeated_before: int = seen.defeated
	var hands := {}
	var braced_checked := false
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if frames >= IDLE_FRAMES and (frames - IDLE_FRAMES) % HIT_EVERY == 0:
			Harness.hit(mod)
			if not braced_checked and is_instance_valid(warden) and warden.staggered():
				braced_checked = true
				_brace(warden, fleet)
		for hand in mod.hands:
			if is_instance_valid(hand):
				hands[hand.get_instance_id()] = String(hand.kind)
		frames += 1
		await physics_frame
	var defeated: bool = seen.defeated > defeated_before and not Harness._alive(Harness.target(mod))
	print("mind fight: %d frame(s), %d attack(s), %d landing(s), %d hand(s), phase %d" % [frames, mod.attack_count,
		mod.landings.size(), hands.size(), mod.phase])
	_t.check("defeated within the cap", defeated, "%d of %d frames" % [frames, FIGHT_CAP])
	_t.check("the fight outlasted the intro and two attack periods", frames > (Rules.INTRO_SECONDS + 2.0 * mod.ATTACK_PERIOD) * TICKS
			and mod.attack_count >= 2, "%d frames, %d attacks" % [frames, mod.attack_count])
	_t.check("the first stagger was seen", braced_checked, "braced_checked %s" % braced_checked)
	_landings(mod.landings)

	var points: Array = seen.points.slice(points_before)
	_t.check("every weak point is the lens, at least one per chunk", points.size() >= BossPosture.CHUNKS
			and points.all(func(id): return id == "lens"), "points %s" % [points])
	_t.check("the Mind remembered the habit", fleet.mind_memory.size() > memory_before,
		"mind_memory %d -> %d" % [memory_before, fleet.mind_memory.size()])
	_t.check("the Mind sent at least one hand", hands.size() >= 1, "%d hand(s)" % hands.size())
	var kinds: Array = hands.values()
	_t.check("every hand is a mind_hand roster enemy, never a boss piece",
			kinds.all(func(k): return k == "mind_hand" and not Roster.is_boss_piece(k)), "kinds %s" % [kinds])

	_t.eq("boss_defeated once", seen.defeated - defeated_before, 1)
	await _until(func(): return flow.state_name() == "summary")
	for _i in 30:
		await physics_frame
	_t.check("victory leads to the summary", flow.state_name() == "summary" and flow.run_won,
		"state %s, run_won %s" % [flow.state_name(), flow.run_won])
	_t.eq("run_ended(true) once", seen.won, [true])
	_t.check("leaving the arena freed the hands", mod.hands.is_empty() and mod.attacks.is_empty(),
		"%d hand(s), %d attack(s) held" % [mod.hands.size(), mod.attacks.size()])


# In the first stagger, with the ball's top habit 'ram': the brace takes its kinds, a braced
# kind meets plating * CHOIR_BRACE_MULT on the body, an unbraced kind the plating, and the
# open lens no plating.
func _brace(warden, fleet) -> void:
	var top: String = fleet.habits.top()
	_t.eq("the top habit is ram at the first stagger", top, "ram")
	_t.eq("the brace targets the top habit", warden.braced_kinds, Habits.BRACES["ram"]["kinds"])
	_t.near("a braced kind meets plating * CHOIR_BRACE_MULT", warden.plating_for("ram", ""), warden.plating * Warden.CHOIR_BRACE_MULT)
	_t.near("an unbraced kind meets the plating", warden.plating_for("stomp", ""), warden.plating)
	_t.near("the open lens meets no plating", warden.plating_for("ram", "lens"), 0.0)


func _landings(landings: Array) -> void:
	_t.check("at least one attack landed", landings.size() >= 1, "%d landing(s)" % landings.size())
	var late: Array = []
	for landing in landings:
		var told = null
		for tel in _telegraphs:
			if tel["id"] == landing["id"] and int(tel["frame"]) <= int(landing["frame"]):
				told = tel
		if told == null or int(landing["frame"]) - int(told["frame"]) < float(told["warn"]) * TICKS * 0.9:
			late.append(landing)
	_t.check("every landing was telegraphed at least 90% of its warn earlier", late.is_empty(),
		"%d of %d landing(s) untold or early: %s" % [late.size(), landings.size(), late])


func _check_movement_pressure(game, mod) -> void:
	var cruise := float(game.ctx.tuning.f("cruise"))
	var center: Vector3 = mod.pad.global_position if is_instance_valid(mod.pad) else mod.warden.global_position
	var ball: Vector3 = game.player.ball_position()
	var saved_vel: Vector3 = game.player.state.velocity
	game.player.body().linear_velocity = Vector3.FORWARD * cruise
	game.player.state.velocity = Vector3.FORWARD * cruise
	mod._step_movement_pressure(0.2)
	_t.check("rolling at >= cruise preserves ATTACK_PERIOD and zero stall pressure",
		not mod.ball_slow_or_camping() and is_zero_approx(mod.stall_pressure())
		and is_equal_approx(mod.effective_attack_period(), mod.ATTACK_PERIOD),
		"period=%.3f pressure=%.3f" % [mod.effective_attack_period(), mod.stall_pressure()])
	var safe_roll := MindAttacks.commit_safe("", 17, ball, center, 2, cruise, mod.PAD_RADIUS, [], mod.effective_warn_scale())
	_t.check("rolling escape corridor stays intact",
		not safe_roll["descriptors"].is_empty()
		and BossAttacks.escape_point(safe_roll["descriptors"], ball, cruise, center, mod.PAD_RADIUS) != null,
		"path=%s" % safe_roll["path"])
	game.player.body().linear_velocity = Vector3.FORWARD * (0.4 * cruise)
	game.player.state.velocity = Vector3.FORWARD * (0.4 * cruise)
	for _i in 20:
		mod._step_movement_pressure(0.1)
	_t.check("slowing < 0.75 * cruise tightens attack period toward 2.4 s",
		mod.ball_slow_or_camping() and mod.effective_attack_period() < mod.ATTACK_PERIOD
		and mod.effective_attack_period() <= 2.55 and mod.effective_attack_period() >= 2.39,
		"period=%.3f pressure=%.3f" % [mod.effective_attack_period(), mod.stall_pressure()])
	var safe_stall := MindAttacks.commit_safe("", 17, ball, center, 3, cruise, mod.PAD_RADIUS, [], mod.effective_warn_scale())
	var warn_ok: bool = (safe_stall["descriptors"] as Array).all(func(d): return float(d["warn"]) >= MindAttacks.WARN_FLOOR)
	_t.check("stalled warns stay >= WARN_FLOOR and keep escape corridor at cruise",
		warn_ok and BossAttacks.escape_point(safe_stall["descriptors"], ball, cruise, center, mod.PAD_RADIUS) != null,
		"warn_ok=%s path=%s" % [warn_ok, safe_stall["path"]])
	game.player.body().linear_velocity = saved_vel
	game.player.state.velocity = saved_vel
	mod._step_movement_pressure(0.1)


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame
