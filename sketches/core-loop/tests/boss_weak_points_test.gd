extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Mind := preload("res://src/boss/mind.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The weak-point rule wired into the Waking (world 2) and the Mind (world 3) behind <boss>.weak_points (#241 step 1).
# Dial 0 is the identity: the rule is off, a judged result is the same object, the families and the objective text are
# today's. Dial 1: a bore jam or lip drop opens a hatch, a plate opens a lens seat, a reel hit on the open point pays
# full and wears its seal, any other hit pays a chip, a break removes a family, an open point re-seals. Then the
# bot's weak_point_go truth table.
#
# Evidence limit: hits are judged results handed to the module's judge, not ball contacts; the bore and the plate are
# committed by calling the module's own steps, not waited for.

var _t := T.new("boss_weak_points_test")
const HIT := {"gain": 10.0, "punch": 20.0}


func _initialize() -> void:
	_run()


func _run() -> void:
	await _off("waking", 2)
	await _off("mind", 3)
	await _waking()
	await _mind()
	_go_table()
	ChallengeDials.reset()
	quit(_t.verdict())


func _boot(world: int, overrides: Dictionary):
	ChallengeDials.reset()
	var dials := {"waking.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0], "mind.phase_min_by_phase": [0.0, 0.0, 0.0, 0.0]}
	dials.merge(overrides)
	ChallengeDials.set_overrides(dials)
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	Harness.boot(game)
	Harness.enter_world(game, world)
	for i in 3:
		await physics_frame
	return [game, Harness.module(game, world)]


func _off(boss: String, world: int) -> void:
	var booted = await _boot(world, {})
	var game = booted[0]
	var mod = booted[1]
	var reel := {"gain": 10.0, "punch": 500.0, "reel": true}
	_t.check("%s dial 0: the rule is off" % boss, not mod.weak.active() and mod.weak_open().is_empty(), "")
	_t.check("%s dial 0: the judge hands back the same result" % boss, is_same(mod._weak_judge(reel), reel) and reel["gain"] == 10.0, "")
	var before: String = mod.objective_text()
	mod._open_weak("hatch_1")
	mod._open_weak("seat_0")
	_t.check("%s dial 0: nothing can open" % boss, mod.weak_open().is_empty() and mod.objective_text() == before, mod.objective_text())
	_t.check("%s dial 0: no family is removed" % boss, mod._removed_families().is_empty()
			and WakingAttacks.exposed(3, mod._removed_families()) == WakingAttacks.exposed(3)
			and MindAttacks.exposed(4, mod._removed_families()) == MindAttacks.exposed(4), "")
	_t.check("%s dial 0: the Warden carries the hook and the pit spray is whole" % boss, mod.warden.spec["weak_judge"] is Callable
			and WakingAttacks.bore(5, Vector3(10, 0, 0), Vector3.ZERO, 4, 36.0, mod._removed_families()).size() == 4, "")
	game.free()
	await physics_frame


func _bore(mod, phase: int) -> void:
	var d: Dictionary = WakingAttacks.bore(1, mod.ctx.player.ball_position(), Vector3(mod._center.x, mod._top(), mod._center.z), phase, mod.PAD_RADIUS)[0]
	var h = MindAttacks.build(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.add_child(h)
	for i in 400:
		if h.is_live():
			break
		h.step(0.01)
	mod.attacks.append({"hazards": [h], "family": "bore", "landed": false, "descs": [d]})
	mod._jammed_until = -INF
	mod.phase = phase
	mod._step_attacks(0.0)


func _waking() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	_t.check("waking dial 1: three hatches and the override, all shut", mod.weak.active() and mod.weak_open().is_empty()
			and mod.weak.state("hatch_3") == WeakPoints.SHUT and mod.weak.state("override") == WeakPoints.SHUT, "")
	var chip: Dictionary = mod._weak_judge(HIT.duplicate())
	_t.near("waking: a hit with no point open pays the chip", chip["gain"], 3.0)
	_bore(mod, 1)
	_t.check("waking: a bore jam opens this floor's hatch", mod.weak_open() == ["hatch_1"], str(mod.weak_open()))
	_t.check("waking: the objective names the open hatch", mod.objective_text().contains("hatch is open: winch in and ram it"), mod.objective_text())
	var body: Dictionary = mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false})
	_t.near("waking: a non-reel hit on the open hatch pays the chip", body["gain"], 3.0)
	_t.near("waking: and leaves its seal alone", mod.weak.seal_hp("hatch_1"), Waking_SEAL())
	var wear: Dictionary = mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": true})
	_t.near("waking: a reel hit on the open hatch pays full", wear["gain"], 10.0)
	_t.near("waking: and wears its seal by the punch", mod.weak.seal_hp("hatch_1"), Waking_SEAL() - 20.0)
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true})
	_t.check("waking: enough punch breaks it and burrow is gone", mod.weak.state("hatch_1") == WeakPoints.BROKEN
			and mod._removed_families() == ["burrow"] and WakingAttacks.exposed(3, mod._removed_families()) == ["cave_in", "bore"], str(mod._removed_families()))
	_t.check("waking: a family is never removed to nothing", WakingAttacks.exposed(1, mod._removed_families()) == ["burrow"], "")
	_t.check("waking: a broken hatch stays out of the way", mod.weak_open().is_empty() and not mod.objective_text().contains("is open"), "")
	# The lip drop: a ball in the air that was carving opens the hatch below, once per drop.
	mod._lip_seen = false
	mod._carved_at = mod.clock
	mod.ctx.player.state.grounded = false
	mod._open_by_lip()
	_t.check("waking: a lip drop opens the floor below's hatch", mod.weak_open() == ["hatch_2"], str(mod.weak_open()))
	mod.weak.step(mod.clock + WeakPoints.OPEN_SECONDS + 0.1)
	mod._open_by_lip()
	_t.check("waking: an open point re-seals, and the same drop does not reopen it", mod.weak_open().is_empty() and mod.weak.state("hatch_2") == WeakPoints.SHUT, "")
	# The pit: the override.
	_bore(mod, 4)
	_t.check("waking: a bore jam in the pit opens the override", mod.weak_open() == ["override"], str(mod.weak_open()))
	_t.check("waking: the objective names the override button", mod.objective_text().contains("override button is open"), mod.objective_text())
	var center := Vector3.ZERO
	var full := WakingAttacks.bore(5, Vector3(10, 0, 0), center, 4, 36.0, mod._removed_families())
	_t.check("waking: with the override whole the pit sprays three lanes", full.size() == 4, str(full.size()))
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true})
	var sprayless := WakingAttacks.bore(5, Vector3(10, 0, 0), center, 4, 36.0, mod._removed_families())
	_t.check("waking: breaking the override ends the spray", sprayless.size() == 1 and mod._removed_families() == ["burrow", "pit_spray"], str(mod._removed_families()))
	# The Warden's hook.
	var called := [false]
	mod.warden.spec["weak_judge"] = func(r: Dictionary) -> Dictionary:
		called[0] = true
		return r
	mod.warden.on_struck("slam", "", mod.warden.judge_hit("slam", 1.0, false, 0))
	_t.check("waking: the Warden asks the judge on a struck hit", called[0], "")
	game.free()
	await physics_frame


func Waking_SEAL() -> float:
	return load("res://src/boss/waking.gd").SEAL_HP


func _mind() -> void:
	var booted = await _boot(3, {"mind.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	_t.check("mind dial 1: three seats, all shut", mod.weak.active() and mod.weak_open().is_empty(), "")
	_t.eq("a plate bearing 0 is seat 0", Mind.nearest_seat(0.0), 0)
	_t.eq("a plate bearing -2.1 is seat 1", Mind.nearest_seat(-2.1), 1)
	_t.eq("a plate bearing 2.1 is seat 2", Mind.nearest_seat(2.1), 2)
	var agree := true
	for k in 3:
		mod.warden.open_lens = k
		var off: Vector3 = mod.warden.family_point_at() - mod.warden.global_position
		agree = agree and Mind.nearest_seat(atan2(off.z, off.x)) == k
	_t.check("the seat bearings match the warden's lens point", agree, "")
	mod.warden.open_lens = 0
	mod._commit_attack("plate")
	_t.check("a plate commit opens the nearest seat (the ball sits at bearing pi/2: seat 2)", mod.weak_open() == ["seat_2"], str(mod.weak_open()))
	_t.check("the objective names the open lens seat", mod.objective_text().contains("lens seat is open: winch in and ram it"), mod.objective_text())
	_t.near("mind: a non-reel hit pays the chip", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false})["gain"], 3.0)
	_t.near("mind: a reel hit on the open seat pays full", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": true})["gain"], 10.0)
	_t.near("mind: and wears the seal", mod.weak.seal_hp("seat_2"), Mind.SEAL_HP - 20.0)
	var expect := [["split_lane"], ["split_lane", "rush"], ["split_lane", "rush"]]
	var ok := true
	for k in 3:
		mod._open_weak("seat_%d" % k) if mod.weak.state("seat_%d" % k) == WeakPoints.SHUT else null
		mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true})
		ok = ok and mod._removed_families() == expect[k] and mod.weak.state("seat_%d" % k) == WeakPoints.BROKEN
	_t.check("mind: seats break in turn: split_lane, then rush, then nothing", ok, str(mod._removed_families()))
	_t.check("mind: the plate and the lane remain", MindAttacks.exposed(4, mod._removed_families()) == ["lane", "plate"], str(MindAttacks.exposed(4, mod._removed_families())))
	game.free()
	await physics_frame


func _go_table() -> void:
	_t.check("go: expert always", BotDriver.weak_point_go("expert", 0.0, 0.99), "")
	_t.check("go: learner needs 0.6 s and a roll under 0.5", BotDriver.weak_point_go("learner", 0.6, 0.49)
			and not BotDriver.weak_point_go("learner", 0.59, 0.1) and not BotDriver.weak_point_go("learner", 2.0, 0.5), "")
	_t.check("go: novice never", not BotDriver.weak_point_go("novice", 9.0, 0.0), "")
