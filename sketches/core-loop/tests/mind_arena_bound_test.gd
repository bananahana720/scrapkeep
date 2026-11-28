extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const StubBoss := preload("res://src/boss/stub_boss.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# The Mind's hazards and escape points stay on the stub pad, not the 44 m arena floor.
# Static: the families' seed and phase sweep with the bound radius PAD_RADIUS and the ball
# inside PAD_RADIUS - CLEAR keeps every region within PAD_RADIUS, and escape_point is never
# null and lands within PAD_RADIUS - CLEAR. Live: the default table, world three, paced
# TARGET hits as mind_fight_test does; every frame every live hazard of every attack is
# measured against the pad centre. Hands are freed with the Warden's death.
#
# Evidence limit: geometry of committed hazards only; hits are TARGET calls and the ball is
# the test-mode bot, so which families appear depends on its path.

const COMMITS := 200
const CENTER := Vector3(3.0, 0.0, -2.0)
const PAD_R := StubBoss.PAD_RADIUS
const SLACK := 0.01
const FIGHT_CAP := 90 * 90
const IDLE_FRAMES := 90 * 5
const HIT_EVERY := 180
const STATE_FRAMES := 90 * 10

var _t := T.new("mind_arena_bound_test")
var _game


func _initialize() -> void:
	_static()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await _live()
	_game.free()
	quit(_t.verdict())


func _static() -> void:
	var cruise := Tuning.new().f("cruise")
	var off := 0
	var nulls := 0
	var far_escape := 0
	var regions := 0
	var worst := 0.0
	for s in COMMITS:
		var phase := s % MindAttacks.phase_cap() + 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 7919 * s + 11
		var r := sqrt(rng.randf()) * (PAD_R - MindAttacks.CLEAR)
		var a := rng.randf() * TAU
		var ball := CENTER + Vector3(cos(a) * r, 0.0, sin(a) * r)
		for family in MindAttacks.FAMILIES:
			var descs := MindAttacks.commit(family, s, ball, CENTER, phase, PAD_R)
			for d in descs:
				regions += 1
				var reach := _reach(d)
				worst = maxf(worst, reach)
				if reach > PAD_R + SLACK:
					off += 1
			var escape = BossAttacks.escape_point(descs, ball, cruise, CENTER, PAD_R)
			if escape == null:
				nulls += 1
			elif _flat(escape - CENTER).length() > PAD_R - MindAttacks.CLEAR + SLACK:
				far_escape += 1
	_t.check("every family's region stays within PAD_RADIUS", off == 0 and regions > 0,
			"%d of %d off the pad, widest %.2f m of %.1f" % [off, regions, worst, PAD_R])
	_t.check("escape_point is never null on the pad", nulls == 0, "%d null" % nulls)
	_t.check("escape_point stays within PAD_RADIUS - CLEAR", far_escape == 0, "%d beyond" % far_escape)


# The farthest a descriptor reaches from CENTER: lane far corners, or the band's outer radius.
func _reach(d: Dictionary) -> float:
	var far := 0.0
	match d["shape"]:
		"lane":
			var dir: Vector3 = d["dir"]
			var side := Vector3.UP.cross(dir).normalized()
			for along in [-float(d["behind"]), float(d["ahead"])]:
				for lat in [-float(d["half"]), float(d["half"])]:
					far = maxf(far, _flat(d["from"] + dir * along + side * lat - CENTER).length())
		_:
			far = _flat(d["at"] - CENTER).length() + float(d["band"].y)
	return far


func _live() -> void:
	var game = _game
	var seen = Harness.counter(game)
	Harness.boot(game)
	_t.check("bot driven", game.bot_driven, "bot_driven %s" % game.bot_driven)
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	var path: String = mod.get_script().resource_path if mod != null else "none"
	if not _t.check("world 3 module is mind.gd", path.ends_with("mind.gd"), "module %s" % path):
		return
	var defeated_before: int = seen.defeated
	var families := {}
	var over := 0
	var measured := 0
	var widest := 0.0
	var hands_after := -1
	var frames := 0
	var defeat_frame := -1
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if frames >= IDLE_FRAMES and (frames - IDLE_FRAMES) % HIT_EVERY == 0:
			Harness.hit(mod)
		var centre: Vector3 = mod.pad.global_position if is_instance_valid(mod.pad) else Vector3.ZERO
		for attack in mod.attacks:
			families[String(attack["family"])] = true
			for h in attack["hazards"]:
				if not is_instance_valid(h):
					continue
				var reach := _hazard_reach(h, centre)
				measured += 1
				widest = maxf(widest, reach)
				if reach > PAD_R + SLACK:
					over += 1
		frames += 1
		await physics_frame
	var defeated: bool = seen.defeated > defeated_before and not Harness._alive(Harness.target(mod))
	defeat_frame = frames
	await physics_frame
	hands_after = mod.hands.filter(func(hand): return is_instance_valid(hand)).size()
	print("mind arena bound: %d frame(s), %d attack(s), %d hazard-frame(s), families %s, widest %.2f m of %.1f" % [frames,
			mod.attack_count, measured, families.keys(), widest, PAD_R])
	_t.check("the fight was won within the cap", defeated, "%d of %d frames" % [defeat_frame, FIGHT_CAP])
	_t.check("at least 4 attacks committed", mod.attack_count >= 4, "%d attack(s)" % mod.attack_count)
	_t.check("every hazard stays within PAD_RADIUS of the pad centre", over == 0 and measured > 0,
			"%d of %d hazard-frame(s) over, widest %.2f m" % [over, measured, widest])
	_t.check("no hand is alive one frame after boss_defeated", hands_after == 0, "%d alive" % hands_after)
	await _until(func(): return game.flow.state_name() == "summary")


func _hazard_reach(h, centre: Vector3) -> float:
	if h.shape == Hazard.Shape.LANE:
		var side := Vector3.UP.cross(h.heading).normalized()
		var far := 0.0
		for lat in [-h.half_width, h.half_width]:
			far = maxf(far, _flat(h.centre + h.heading * h.length + side * lat - centre).length())
		return far
	return h.r_out + _flat(h.centre - centre).length()


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
