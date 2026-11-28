extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Waking := preload("res://src/boss/waking.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const WakingFloors := preload("res://src/boss/waking_floors.gd")
const BossAttacks := preload("res://src/boss/boss_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const Warden := preload("res://src/combat/warden.gd")
const T := preload("res://tests/support/t.gd")

# The Waking fought floor by floor on the default table: world two's arena entered through
# flow's seams, its Warden struck through the module harness's TARGET hit, paced so each
# shattered chunk's floor drop finishes before the next hit. Each floor is telegraphed, then
# drops, highest first; the ground under the Warden falls a tier per drop and ends at the pit,
# the Warden is re-seated each time, the music's phase climbs, the objective names each
# floor, and the fourth chunk is the win.
#
# Evidence limit: hits are TARGET calls, not ball contacts, and the pacing is the test's own:
# it stops hitting for one floor drop after every shatter.

const FIGHT_CAP := 90 * 60
const STATE_FRAMES := 90 * 10
# Frames the test holds its hits after a shatter: the drop's warning plus a margin.
const REST_FRAMES := int(Waking.FLOOR_WARN * 90.0) + 30
const LEAD_FRAMES := Waking.FLOOR_WARN * 90.0 * 0.9

var _t := T.new("waking_fight_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	# This test pins the floor drops, not the fight's length. The fight's PHASE_MIN_SECONDS hold
	# (waking.gd, tests/boss_phase_hold_test.gd) stretches a smash-every-frame fight past the 90 s cap and
	# an idle pilot dies in it, so the hold is multiplied out here.
	ChallengeDials.set_overrides({"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]})
	while _game.flow == null:
		await physics_frame
	await _walk()
	_game.free()
	await _check_rim_and_stall()
	ChallengeDials.reset()
	quit(_t.verdict())


func _walk() -> void:
	var game = _game
	var flow = game.flow
	_t.check("bot driven", game.bot_driven, "bot_driven %s" % game.bot_driven)
	var seen = Harness.counter(game)
	Harness.boot(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	var path: String = mod.get_script().resource_path if mod != null else "none"
	if not _t.check("world 2 module is waking.gd and ctx.boss", path.ends_with("waking.gd") and game.ctx.boss == mod,
			"module %s, ctx.boss is it %s" % [path, game.ctx.boss == mod]):
		return
	var shape: Dictionary = Harness.conforms(mod)
	_t.eq("module conforms to MODULE", shape["module"], [])
	_t.eq("target conforms to TARGET", shape["target"], [])

	var telegraphs: Array = []
	game.ctx.events.boss_attack_telegraphed.connect(func(id: String, _seconds: float):
		telegraphs.append([id, Engine.get_physics_frames()]))

	var floors: WakingFloors = mod.floors
	var center: Vector3 = mod.pad.global_position
	var pit: float = center.y + Waking.PAD_THICK * 0.5
	var top_height: float = pit + floors.floor_height(1)
	_t.near("ground starts on floor 1", mod.ground_height_at(center), top_height)
	_t.check("ball enters on floor 1", game.ctx.player.ball_position().y >= top_height,
			"ball y %.2f, floor 1 top %.2f" % [game.ctx.player.ball_position().y, top_height])
	_t.near("Warden seated on floor 1", mod.warden.global_position.y, top_height + Warden.HALF_HEIGHT, 0.01)

	var changes: Array = []
	var phases: Array = []
	var objectives := {}
	var last_height: float = mod.ground_height_at(center)
	var chunks_before: int = mod.warden.chunks_left()
	var rest := 0
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if rest > 0:
			rest -= 1
		else:
			Harness.hit(mod)
		frames += 1
		await physics_frame
		if not mod.active():
			break
		var chunks: int = mod.warden.chunks_left() if is_instance_valid(mod.warden) else 0
		if chunks < chunks_before:
			rest = REST_FRAMES
		chunks_before = chunks
		var h: float = mod.ground_height_at(center)
		if h != last_height:
			changes.append({"frame": Engine.get_physics_frames(), "from": last_height, "to": h,
					"warden_y": mod.warden.global_position.y if is_instance_valid(mod.warden) else NAN})
			last_height = h
		var music: Dictionary = mod.music_state()
		if not music.is_empty() and (phases.is_empty() or phases[-1] != int(music["phase"])):
			phases.append(int(music["phase"]))
		objectives[mod.objective_text()] = true

	print("waking fight: %d frame(s), %d drop(s), telegraphs %s" % [frames, changes.size(), str(telegraphs)])
	_t.check("defeated within the cap", seen.defeated == 1 and not Harness._alive(Harness.target(mod)),
			"%d frames of %d, boss_defeated %d" % [frames, FIGHT_CAP, seen.defeated])

	# The Waking's own attacks telegraph on the same signal (waking_attacks.gd); the floors are these.
	telegraphs = telegraphs.filter(func(t): return String(t[0]).begins_with("waking_floor_"))
	var ids: Array = telegraphs.map(func(t): return t[0])
	_t.eq("floors dropped in order", ids, ["waking_floor_1", "waking_floor_2", "waking_floor_3"])
	_t.eq("three height changes", changes.size(), 3)
	for i in mini(changes.size(), telegraphs.size()):
		var c: Dictionary = changes[i]
		var lead: int = c["frame"] - telegraphs[i][1]
		_t.check("drop %d telegraphed %d frames ahead" % [i + 1, lead], lead >= LEAD_FRAMES, "need %.0f" % LEAD_FRAMES)
		_t.near("drop %d falls one tier" % (i + 1), c["from"] - c["to"], WakingFloors.SPACING)
		_t.near("drop %d Warden re-seated" % (i + 1), c["warden_y"], c["to"] + Warden.HALF_HEIGHT, 0.01)
	_t.near("ground ends at the pit", last_height, pit)
	_t.eq("music phase climbs 1, 2, 3", phases, [1, 2, 3])
	for n in Waking.FLOOR_NAMES:
		var named := false
		for text in objectives.keys():
			named = named or String(text).contains("%s floor" % n)
		_t.check("objective named the %s floor" % n, named, str(objectives.keys()))

	await _until(func(): return flow.state_name() != "boss")
	if not _t.eq("victory", flow.state_name(), "victory"):
		return
	var next: int = game.ctx.stages.first_of(3)
	await _until(func(): return flow.state_name() == "stage")
	_t.check("victory lands on world 3's first stage %d" % next, flow.state_name() == "stage" and game.run.stage == next,
			"state %s on stage %d" % [flow.state_name(), game.run.stage])


func _until(done: Callable) -> void:
	var frames := 0
	while not done.call() and frames < STATE_FRAMES:
		frames += 1
		await physics_frame


func _make_rim_hazard(mod, family: String, at: Vector3) -> Dictionary:
	var d := {"family": family, "family_index": 1, "id": "waking_rim_%s" % family, "shape": "annulus",
		"type": Threat.Type.INSTANT, "warn": 1.0, "live": 0.6, "height": WakingAttacks.HEIGHT,
		"at": at, "band": Vector2(0.0, 4.0), "delay": 0.0}
	var h = Hazard.from_def(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.ctx.root.add_child(h)
	var attack := {"hazards": [h], "family": family, "landed": false, "descs": [d]}
	mod.attacks.append(attack)
	return attack


func _check_rim_and_stall() -> void:
	ChallengeDials.reset()
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	Harness.boot(game)
	Harness.enter_world(game, 2)
	var mod = Harness.module(game, 2)
	mod.set_physics_process(false)
	mod._attack_clock = 1.0e9
	game.run.max_hp = 1000.0
	game.run.hp = 1000.0
	var hits: Array = []
	game.ctx.events.player_hit.connect(func(amount: float, source: String): hits.append([source, amount]))
	var player = game.ctx.player
	player.set_physics_process(false)
	var center := Vector3(mod._center.x, mod._top(), mod._center.z)
	var rim_xz := center + Vector3(34.5, 0.0, 0.0)
	var rim_y: float = mod.ground_height_at(rim_xz)
	_t.check("RimBank ground_height_at tracks bank slope elevation", rim_y > mod._top() + 1.0, "%.2f vs %.2f" % [rim_y, mod._top()])
	var rim_ball := Vector3(rim_xz.x, rim_y + 0.8, rim_xz.z)
	player.body().global_position = rim_ball
	player.body().linear_velocity = Vector3.ZERO
	player.state.velocity = Vector3.ZERO
	player.state.grounded = true
	player.state.carving = false
	player.state.tier = SpeedTier.WALK
	player.state.contact_normal = Vector3(-0.75, 0.66, 0.0).normalized()
	var parked_atk := _make_rim_hazard(mod, "burrow", Vector3(rim_xz.x, mod._top(), rim_xz.z))
	for _i in 3:
		mod._step_attacks(0.6)
	_t.check("parked slow ball on RimBank takes hazard damage", parked_atk["landed"] and hits.size() == 1 and hits[0][0] == "waking_burrow", str(hits))
	mod._clear_attacks()
	hits.clear()
	player.body().linear_velocity = Vector3(0.0, 0.0, -24.0)
	player.state.velocity = Vector3(0.0, 0.0, -24.0)
	player.state.grounded = true
	player.state.carving = true
	player.state.tier = SpeedTier.FAST
	var carve_atk := _make_rim_hazard(mod, "cave_in", Vector3(rim_xz.x, mod._top(), rim_xz.z))
	for _i in 3:
		mod._step_attacks(0.6)
	_t.check("fast carving ball on RimBank rides safely and awards _bank_ride", not carve_atk["landed"] and hits.is_empty() and mod._banked.has("cave_in"), str(hits))
	mod._clear_attacks()
	hits.clear()
	player.body().global_position = rim_xz + Vector3.UP * (WakingAttacks.HEIGHT + 1.5)
	player.body().linear_velocity = Vector3.ZERO
	player.state.grounded = false
	player.state.carving = false
	player.state.tier = SpeedTier.WALK
	var jump_atk := _make_rim_hazard(mod, "bore", Vector3(rim_xz.x, mod._top(), rim_xz.z))
	for _i in 3:
		mod._step_attacks(0.6)
	_t.check("airborne jump above HEIGHT clears RimBank hazard", not jump_atk["landed"] and hits.is_empty(), str(hits))
	mod._clear_attacks()
	var cruise := float(game.ctx.tuning.f("cruise"))
	mod.clock = BossRules.INTRO_SECONDS + 1.0
	mod._stall_clock_seen = mod.clock
	mod._stall_s = 0.0
	mod.phase = 1
	player.state.carving = false
	player.body().linear_velocity = Vector3(0.0, 0.0, -cruise)
	for _i in 40:
		mod.clock += 0.1
		mod._step_stall(0.1)
	var cruise_p1: float = mod.current_attack_period()
	mod.phase = WakingAttacks.PIT_PHASE
	var cruise_pit: float = mod.current_attack_period()
	_t.near("cruise-rolling ball keeps ATTACK_PERIOD 3.4s", cruise_p1, Waking.ATTACK_PERIOD, 0.001)
	_t.near("cruise-rolling ball keeps PIT_PERIOD 2.6s", cruise_pit, Waking.PIT_PERIOD, 0.001)
	player.body().linear_velocity = Vector3(0.0, 0.0, cruise * 0.4)
	for _i in 40:
		mod.clock += 0.1
		mod._step_stall(0.1)
	mod.phase = 1
	var stall_p1: float = mod.current_attack_period()
	mod.phase = WakingAttacks.PIT_PHASE
	var stall_pit: float = mod.current_attack_period()
	_t.check("stalled ball receives tighter Waking cadence in phases 1-3", stall_p1 < cruise_p1 and is_equal_approx(stall_p1, Waking.STALL_ATTACK_PERIOD), "%.2f vs %.2f" % [stall_p1, cruise_p1])
	_t.check("stalled ball receives tighter Waking cadence in pit phase", stall_pit < cruise_pit and is_equal_approx(stall_pit, Waking.STALL_PIT_PERIOD), "%.2f vs %.2f" % [stall_pit, cruise_pit])
	var min_warn := INF
	var escape_ok := true
	for p in range(1, WakingAttacks.PIT_PHASE + 1):
		for fam in WakingAttacks.exposed(p):
			var safe := WakingAttacks.commit_safe(fam, 101 + p, rim_ball, player.body().linear_velocity, center, p, cruise, Waking.PAD_RADIUS)
			var descs: Array = safe["descriptors"]
			if BossAttacks.escape_point(descs, rim_ball, cruise, center, Waking.PAD_RADIUS) == null:
				escape_ok = false
			for d in descs:
				var hz = Hazard.from_def(d)
				min_warn = minf(min_warn, hz.warn_seconds)
				hz.free()
	_t.check("commit_safe escape corridors stay valid and warn_seconds >= Hazard.MIN_WARN", escape_ok and min_warn >= Hazard.MIN_WARN - 1e-6, "escape=%s warn=%.2f" % [str(escape_ok), min_warn])
	player.body().linear_velocity = Vector3(0.0, 0.0, cruise)
	for _i in 30:
		mod.clock += 0.1
		mod._step_stall(0.1)
	mod.phase = 1
	_t.near("returning to cruise restores ATTACK_PERIOD 3.4s", mod.current_attack_period(), Waking.ATTACK_PERIOD, 0.001)
	game.free()
	await physics_frame
