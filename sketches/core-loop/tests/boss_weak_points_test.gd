extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Mind := preload("res://src/boss/mind.gd")
const Waking := preload("res://src/boss/waking.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The weak-point rule wired into the Waking (world 2) and the Mind (world 3) behind <boss>.weak_points (#241 steps 1, 2a).
# Dial 0 is the identity: the rule is off, no part stands, a judged result is the same object, the Warden's posture row
# is the stage's own, the families and the objective text are today's. Dial 1: a bore jam or lip drop opens a hatch,
# a plate opens a lens seat, a reel hit on the open point pays full and wears its seal, any other hit pays a chip, a
# break removes a family, an open point re-seals and holds at least WeakPoints.OPEN_MIN, the Warden's contact gain row is
# off. Then the bot's weak_point_go truth table. The parts, contacts and the Mind's seats and hands are
# boss_weak_parts_test.gd.
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
	_same_without_removal()
	await _waking()
	await _jam_guard()
	await _jam_renewed()
	await _hook()
	await _hold()
	await _mind()
	_open_min()
	_bare()
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
	var booted = await _boot(world, {"%s.weak_points" % boss: 0.0})
	var game = booted[0]
	var mod = booted[1]
	var reel := {"gain": 10.0, "punch": 500.0, "reel": true}
	_t.check("%s dial 0: the rule is off" % boss, not mod.weak.active() and mod.weak_open().is_empty(), "")
	_t.check("%s dial 0: the judge hands back the same result" % boss, is_same(mod._weak_judge(reel), reel) and is_same(mod._weak_judge(reel, "hatch_1", "ram"), reel)
			and reel["gain"] == 10.0, "")
	var row: Dictionary = mod.ctx.spawner.warden_spec(mod.ctx.run.stage).get("posture", {})
	var want_scale := float(row.get("contact_gain_scale", 0.0))
	_t.check("%s dial 0: the Warden's contact gain row is the stage's own (%s)" % [boss, want_scale], mod.warden._posture.contact_gain_scale == want_scale
			and (boss != "waking" or want_scale > 0.0), str(mod.warden._posture.contact_gain_scale))
	_t.check("%s dial 0: no part, no listener on the ball, no judge-all flag" % boss, mod._part_nodes.is_empty() and get_nodes_in_group("weak_part").is_empty()
			and not mod.warden.spec.has("weak_judge_all")
			and mod.ctx.player.struck.get_connections().filter(func(c): return c["callable"] == Callable(mod, "_on_player_struck")).is_empty(), "")
	if boss == "mind":
		_t.check("mind dial 0: the hand cap is the constant", mod._hand_cap() == Mind.HAND_CAP and mod._hand_slots.is_empty(), "")
	var before: String = mod.objective_text()
	mod._open_weak("hatch_1")
	mod._open_weak("seat_0")
	_t.check("%s dial 0: nothing can open" % boss, mod.weak_open().is_empty() and mod.objective_text() == before, mod.objective_text())
	var fam_ok: bool = mod._removed_families().is_empty()
	var waking_pins := [["burrow"], ["burrow", "cave_in"], ["burrow", "cave_in", "bore"], ["burrow", "cave_in", "bore"]]
	var mind_pins := [["lane"], ["lane", "split_lane"], ["lane", "split_lane", "rush"], ["lane", "split_lane", "rush", "plate"]]
	for n in 4:
		fam_ok = fam_ok and WakingAttacks.exposed(n + 1, mod._removed_families()) == waking_pins[n] \
				and MindAttacks.exposed(n + 1, mod._removed_families()) == mind_pins[n]
	_t.check("%s dial 0: no family is removed, every phase against pinned lists" % boss, fam_ok, "")
	_t.check("%s dial 0: the Warden carries the hook and the pit spray is whole" % boss, mod.warden.spec["weak_judge"] is Callable
			and WakingAttacks.bore(5, Vector3(10, 0, 0), Vector3.ZERO, 4, 36.0, mod._removed_families()).size() == 4, "")
	game.free()
	await physics_frame


# The families and the picks without a removal, against literals pinned from the unchanged base (a63a8ba2). The first
# check also pins that an empty removed list is the no-argument call.
const PIN_WAKING_CHOOSE := [["burrow", "cave_in", "bore", "bore"], ["burrow", "burrow", "burrow", "burrow"],
		["burrow", "cave_in", "bore", "bore"], ["burrow", "cave_in", "cave_in", "cave_in"]]
const PIN_MIND_CHOOSE := [["lane", "split_lane", "rush", "plate"], ["lane", "lane", "lane", "lane"],
		["lane", "split_lane", "rush", "plate"], ["lane", "split_lane", "split_lane", "split_lane"]]
const PIN_WAKING_SAFE := [["burrow", 1, "first", ["waking_burrow_0"]], ["burrow", 3, "first", ["waking_burrow_0", "waking_burrow_1"]],
		["burrow", 4, "first", ["waking_burrow_0", "waking_burrow_1"]], ["cave_in", 1, "first", ["waking_cave_in_0", "waking_cave_in_1", "waking_cave_in_2"]],
		["cave_in", 3, "first", ["waking_cave_in_0", "waking_cave_in_1", "waking_cave_in_2"]], ["cave_in", 4, "first", ["waking_cave_in_0", "waking_cave_in_1", "waking_cave_in_2"]],
		["bore", 1, "first", ["waking_bore_0"]], ["bore", 3, "first", ["waking_bore_0"]],
		["bore", 4, "first", ["waking_bore_0", "waking_bore_spray_0", "waking_bore_spray_1", "waking_bore_spray_2"]]]
const PIN_MIND_SAFE := [[1, "first", ["mind_lane_0"]], [2, "first", ["mind_split_lane_0", "mind_split_lane_1"]], [3, "first", ["mind_rush_0"]],
		[4, "first", ["mind_split_lane_0", "mind_split_lane_1"]]]


func _same_without_removal() -> void:
	var waking := []
	var mind := []
	var empty_equal := true
	for seed in [0, 3, 7, 11]:
		var w := []
		var m := []
		for phase in range(1, 5):
			w.append(WakingAttacks.choose(seed, phase, []))
			m.append(MindAttacks.choose(seed, phase, []))
			empty_equal = empty_equal and WakingAttacks.choose(seed, phase, []) == WakingAttacks.choose(seed, phase) \
					and MindAttacks.choose(seed, phase, []) == MindAttacks.choose(seed, phase)
		waking.append(w)
		mind.append(m)
	_t.check("choose with nothing removed matches the pinned picks, seeds 0 3 7 11, every phase", waking == PIN_WAKING_CHOOSE and mind == PIN_MIND_CHOOSE
			and empty_equal, str(waking))
	var ball := Vector3(8.0, 0.0, 5.0)
	var safe := []
	for family in WakingAttacks.FAMILIES:
		for phase in [1, 3, 4]:
			var r := WakingAttacks.commit_safe(family, 5, ball, Vector3.RIGHT * 5.0, Vector3.ZERO, phase, 8.0, 36.0, [])
			safe.append([family, phase, r["path"], r["descriptors"].map(func(d): return d["id"])])
	var safe_mind := []
	for phase in range(1, 5):
		var r := MindAttacks.commit_safe("", 5, ball, Vector3.ZERO, phase, 8.0, 36.0, [])
		safe_mind.append([phase, r["path"], r["descriptors"].map(func(d): return d["id"])])
	_t.check("commit_safe with nothing removed matches the pinned sets and paths", safe == PIN_WAKING_SAFE and safe_mind == PIN_MIND_SAFE, str(safe))


func _bore(mod, phase: int) -> void:
	var d: Dictionary = WakingAttacks.bore(1, mod.ctx.player.ball_position(), Vector3(mod._center.x, mod._top(), mod._center.z), phase, mod.PAD_RADIUS)[0]
	var h = Hazard.from_def(d)
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


func _empty_bar(mod) -> void:
	mod.warden._posture.posture = 0.0
	mod.warden._posture.idle = 0.0
	mod.warden._posture.staggered = false


# Floors 1..n gone the way a drop leaves them: body freed, hatch freed with it.
func _drop_floors(mod, n: int) -> void:
	for k in range(1, n + 1):
		mod._free_part("hatch_%d" % k)
		mod._free_body(mod._floor_bodies.get(k))
		mod._floor_bodies.erase(k)


func _place_ball(mod, at: Vector3) -> void:
	mod.ctx.player.reset_to(at)
	mod.ctx.player.body().global_position = at


func _waking() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var row: Dictionary = mod.ctx.spawner.warden_spec(mod.ctx.run.stage).get("posture", {})
	_t.check("waking dial 1: three hatches and the override, all shut", mod.weak.active() and mod.weak_open().is_empty()
			and mod.weak.state("hatch_3") == WeakPoints.SHUT and mod.weak.state("override") == WeakPoints.SHUT, "")
	_t.check("waking dial 1: the Warden's contact gain row is off, the rest of the row is kept", mod.warden._posture.contact_gain_scale == 0.0
			and float(row.get("contact_gain_scale", 0.0)) > 0.0 and mod.warden._posture.hit_cap == Waking_HIT_CAP()
			and mod.warden.spec.get("weak_judge_all", false), str(mod.warden._posture.contact_gain_scale))
	var chip: Dictionary = mod._weak_judge(HIT.duplicate())
	_t.near("waking: a hit with no point open pays the chip", chip["gain"], 3.0)
	# The lip drop: a ball in the air that was carving opens the CURRENT floor's hatch (the one it can reach), once per
	# drop. The floor below is buried under it, so hatch_phase + 1 stays shut.
	mod._lip_seen = false
	mod._carved_at = mod.clock
	mod.ctx.player.state.grounded = false
	mod.phase = 1
	mod._open_by_lip()
	_t.check("waking: a lip drop in phase 1 opens hatch_1", mod.weak_open() == ["hatch_1"], str(mod.weak_open()))
	_t.check("waking: and not the buried hatch_2", mod.weak.state("hatch_2") == WeakPoints.SHUT, "")
	mod.weak.step(mod.clock + WeakPoints.OPEN_SECONDS + 0.1)
	mod._open_by_lip()
	_t.check("waking: an open point re-seals, and the same drop does not reopen it", mod.weak_open().is_empty() and mod.weak.state("hatch_1") == WeakPoints.SHUT, "")
	mod._lip_seen = false
	mod._open_by_lip()
	_t.check("waking: a second drop opens it again", mod.weak_open() == ["hatch_1"], str(mod.weak_open()))
	mod.weak.step(mod.clock + 100.0)
	_drop_floors(mod, 2)
	# Phase 3, floors 1 and 2 gone, hatch_3 standing and shut: a lip drop opens it (the positive control for the
	# last-floor check below, which runs with hatch_3 already broken and so cannot fail).
	mod.phase = 3
	var grounded_before: bool = mod.ctx.player.state.grounded
	var lip_seen_before: bool = mod._lip_seen
	mod._lip_seen = false
	mod._carved_at = mod.clock
	mod.ctx.player.state.grounded = false
	_t.check("waking: hatch_3 stands shut before the phase 3 lip", mod.weak.state("hatch_3") == WeakPoints.SHUT and mod.part_reachable("hatch_3"), "")
	mod._open_by_lip()
	_t.check("waking: a lip drop in phase 3 opens hatch_3", mod.weak_open() == ["hatch_3"], str(mod.weak_open()))
	mod.ctx.player.state.grounded = grounded_before
	mod._lip_seen = lip_seen_before
	mod.weak.step(mod.clock + 100.0)
	# The bore: hatch_3 off the pit, the override in it.
	_bore(mod, 3)
	_t.check("waking: a bore jam opens the third hatch", mod.weak_open() == ["hatch_3"], str(mod.weak_open()))
	_t.check("waking: the objective names the open hatch", mod.objective_text().contains("hatch is open: hook it and haul in"), mod.objective_text())
	await physics_frame
	var body: Dictionary = mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": true})
	_t.near("waking: a reel hit that names no part is the body: chip", body["gain"], 3.0)
	var plain: Dictionary = mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false}, "hatch_3", "ram")
	_t.near("waking: a non-reel hit on the open hatch pays the chip", plain["gain"], 3.0)
	_t.near("waking: and leaves its seal alone", mod.weak.seal_hp("hatch_3"), Waking_SEAL())
	await physics_frame
	var wear: Dictionary = mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": true}, "hatch_3", "ram")
	_t.near("waking: a reel hit on the open hatch pays full", wear["gain"], 10.0)
	_t.near("waking: and wears its seal by the punch", mod.weak.seal_hp("hatch_3"), Waking_SEAL() - 20.0)
	await physics_frame
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "hatch_3", "ram")
	_t.check("waking: enough punch breaks it and bore is gone", mod.weak.state("hatch_3") == WeakPoints.BROKEN
			and mod._removed_families() == ["bore"] and WakingAttacks.exposed(3, mod._removed_families()) == ["burrow", "cave_in"], str(mod._removed_families()))
	_t.check("waking: a family is never removed to nothing", WakingAttacks.exposed(1, mod._removed_families()) == ["burrow"], "")
	_t.check("waking: a broken hatch stays out of the way", mod.weak_open().is_empty() and not mod.objective_text().contains("is open"), "")
	await physics_frame
	_t.near("waking: after a break the body stands bare and pays full", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false})["gain"], 10.0)
	# The pit: the override, once the last floor is gone.
	_drop_floors(mod, 3)
	_bore(mod, 4)
	_t.check("waking: a bore jam in the pit opens the override", mod.weak_open() == ["override"], str(mod.weak_open()))
	_t.check("waking: the objective names the override button", mod.objective_text().contains("override button is open"), mod.objective_text())
	await physics_frame
	_t.near("waking: the next open covers it again: the body pays the chip", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false})["gain"], 3.0)
	var center := Vector3.ZERO
	var full := WakingAttacks.bore(5, Vector3(10, 0, 0), center, 4, 36.0, mod._removed_families())
	_t.check("waking: with the override whole the pit sprays three lanes", full.size() == 4, str(full.size()))
	await physics_frame
	mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "override", "ram")
	var sprayless := WakingAttacks.bore(5, Vector3(10, 0, 0), center, 4, 36.0, mod._removed_families())
	_t.check("waking: breaking the override ends the spray", sprayless.size() == 1 and mod._removed_families() == ["bore", "pit_spray"], str(mod._removed_families()))
	# Last floor: a lip drop opens nothing, with every point shut first (phase 3's hatch is broken, the pit has none).
	mod.weak.step(mod.clock + 100.0)
	for last in [3, 4]:
		mod.phase = last
		mod._lip_seen = false
		mod.ctx.player.state.grounded = false
		mod._carved_at = mod.clock
		mod._open_by_lip()
		_t.check("waking: a lip drop on phase %d opens nothing" % last, mod.weak_open().is_empty(), str(mod.weak_open()))
	game.free()
	await physics_frame


# A bore attack that is live now, not yet stepped, and the guard left as it is.
func _bore_attack(mod, phase: int) -> Dictionary:
	var d: Dictionary = WakingAttacks.bore(1, mod.ctx.player.ball_position(), Vector3(mod._center.x, mod._top(), mod._center.z), phase, mod.PAD_RADIUS)[0]
	var h = Hazard.from_def(d)
	h.ground = Callable(mod, "ground_height_at")
	mod.add_child(h)
	for i in 400:
		if h.is_live():
			break
		h.step(0.01)
	var attack := {"hazards": [h], "family": "bore", "landed": false, "descs": [d]}
	mod.attacks.append(attack)
	return attack


# The open is apart from the punish guard: a jam renewed while the part was buried must not hold the next bore off.
func _jam_renewed() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	_drop_floors(mod, 3)
	mod._dropping = 3
	mod.phase = 4
	var first: Dictionary = _bore_attack(mod, 4)
	mod._step_attacks(0.0)
	_t.check("renewed jam: the buried bore opens nothing, arms the guard and leaves its attack free to retry",
			mod.weak_open().is_empty() and mod._jammed_until > mod.clock and not first.get("opened", false), str(mod._jammed_until))
	mod._dropping = 0
	mod._clear_attacks()
	var second: Dictionary = _bore_attack(mod, 4)
	_t.check("renewed jam: the guard is still up when the next bore goes live", mod._jammed_until > mod.clock, "")
	mod._step_attacks(0.0)
	_t.check("renewed jam: the first reachable bore opens the override under the armed guard", mod.weak_open() == ["override"] and second.get("opened", false), str(mod.weak_open()))
	var again: float = mod._jammed_until
	mod._step_attacks(0.0)
	_t.check("renewed jam: one open per bore, the guard keeps renewing", mod._weak_opened.count("override") == 1 and mod._jammed_until >= again, "")
	game.free()
	await physics_frame
	# The same attack retries: buried on its first live frame, open on a later one.
	var retry = await _boot(2, {"waking.weak_points": 1.0})
	var mod2 = retry[1]
	_drop_floors(mod2, 3)
	mod2._dropping = 3
	mod2.phase = 4
	var attack: Dictionary = _bore_attack(mod2, 4)
	mod2._step_attacks(0.0)
	var buried: bool = mod2.weak_open().is_empty()
	mod2._dropping = 0
	mod2._step_attacks(0.0)
	_t.check("renewed jam: a buried first frame retries on a later live frame of the same bore", buried and mod2.weak_open() == ["override"], str(mod2.weak_open()))
	retry[0].free()
	await physics_frame


# One open per jam: the jam guard, with the point fresh (not broken) so a reopen would show.
func _jam_guard() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	# Phase 4 the frame chunk 3 shatters: floor 3 is in its drop warning with its body already gone, so only the warning buries the override.
	_drop_floors(mod, 3)
	mod._dropping = 3
	mod._drop_left = 1.0
	_bore(mod, 4)
	_t.check("jam: a bore jam during floor 3's drop warning opens nothing", mod.weak_open().is_empty() and mod._weak_opened.is_empty()
			and mod.weak.state("override") == WeakPoints.SHUT and mod.weak.state("hatch_3") == WeakPoints.SHUT, str(mod.weak_open()))
	mod._dropping = 0
	_drop_floors(mod, 3)
	mod._clear_attacks()
	_bore(mod, 4)
	_t.check("jam: the pit's jam opens the override", mod.weak_open() == ["override"], str(mod.weak_open()))
	var opened: int = mod._weak_opened.size()
	mod.weak.step(mod.clock + WeakPoints.OPEN_SECONDS + 0.1)
	_t.eq("jam: the override re-sealed with its seal whole", mod.weak.state("override"), WeakPoints.SHUT)
	mod._step_attacks(0.0)
	mod._step_attacks(0.0)
	_t.check("jam: a re-sealed point is not reopened while the same jam runs", mod.weak_open().is_empty() and mod._weak_opened.size() == opened
			and mod.weak.seal_hp("override") == Waking_SEAL(), str(mod._weak_opened))
	mod._open_weak("override")
	_t.check("jam: reopening a point leaves one entry, newest last", mod._weak_opened.count("override") == 1 and mod.weak_open()[-1] == "override", str(mod._weak_opened))
	game.free()
	await physics_frame


# Warden.on_struck applies the judge's answer: a scaled gain is what reaches the bar, and the judge is told the part and the verb.
func _hook() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var asked := []
	mod.warden.spec["weak_judge"] = func(r: Dictionary, part: String, kind: String) -> Dictionary:
		asked.append([part, kind])
		var out := r.duplicate()
		out["gain"] = float(r["gain"]) * 0.5
		return out
	await physics_frame
	_empty_bar(mod)
	var raw: Dictionary = mod.warden.judge_hit("slam", 24.0, false, 0)
	mod.warden.on_struck("slam", "hatch_2", raw)
	_t.check("the Warden asks the judge on a struck hit, naming the part and the verb", asked == [["hatch_2", "slam"]], str(asked))
	_t.near("on_struck puts the judge's answer on the bar: half the raw gain", mod.warden.posture(), float(raw["gain"]) * 0.5, 0.0001)
	asked.clear()
	mod.warden._posture.staggered = true
	mod.warden.on_struck("slam", "", mod.warden.judge_hit("slam", 1.0, false, 0))
	mod.warden._posture.staggered = false
	_t.check("a staggered Warden does not ask the judge", asked.is_empty(), "")
	# A hit that skips on_struck (the ultimate's) is judged once by _apply_posture, and one through on_struck only once.
	await physics_frame
	_empty_bar(mod)
	var direct: Dictionary = mod.warden.judge_hit("ram", 24.0, false, 1)
	mod.warden._apply_posture(direct)
	_t.check("a hit straight into _apply_posture is judged once", asked == [["", ""]] and absf(mod.warden.posture() - float(direct["gain"]) * 0.5) < 0.0001, str(asked))
	asked.clear()
	await physics_frame
	mod.warden.on_struck("ram", "", mod.warden.judge_hit("ram", 24.0, false, 1))
	_t.eq("and a hit through on_struck is judged once, not again in _apply_posture", asked.size(), 1)
	game.free()
	await physics_frame


# With a hold active, a chipped or full gain still clamps at HOLD_CAP and the bar never staggers.
func _hold() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0, "waking.phase_min_by_phase": [1.0, 1.0, 1.0, 1.0]})
	var game = booted[0]
	var mod = booted[1]
	mod._phase_open_at = mod.clock + 1000.0
	var capped := true
	var calm := true
	for i in 60:
		await physics_frame
		mod._open_weak("hatch_1")
		mod.weak._parts["hatch_1"]["seal_hp"] = Waking_SEAL()
		var r: Dictionary = mod.warden.judge_hit("slam", 9999.0, true, 3)
		r["reel"] = i % 2 == 0
		mod.warden.on_struck("slam", "hatch_1", r)
		capped = capped and mod.warden.posture() <= load("res://src/combat/warden.gd").HOLD_CAP + 0.001
		calm = calm and not mod.warden.staggered()
	_t.check("hold with weak on: the bar stops at the cap and never staggers", mod.hold_active() and capped and calm and mod.warden.posture() > 0.0,
			"posture %.2f" % mod.warden.posture())
	game.free()
	await physics_frame


func Waking_SEAL() -> float:
	return load("res://src/boss/waking.gd").SEAL_HP


func Waking_HIT_CAP() -> float:
	return load("res://src/boss/waking.gd").HIT_CAP


func _mind() -> void:
	var booted = await _boot(3, {"mind.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	_t.check("mind dial 1: three seats and a button per hand, all shut", mod.weak.active() and mod.weak_open().is_empty(), "")
	_t.check("mind dial 1: the Warden's contact gain row is off", mod.warden._posture.contact_gain_scale == 0.0 and mod.warden.spec.get("weak_judge_all", false), "")
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
	_t.check("the objective names the open lens seat", mod.objective_text().contains("lens seat is open: hook it and haul in"), mod.objective_text())
	_place_ball(mod, mod.seat_position(2) + Vector3(1.0, 0.0, 0.0))
	await physics_frame
	_t.near("mind: a non-reel hit pays the chip", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": false}, "", "slam")["gain"], 3.0)
	_t.near("mind: a reel hit at the open seat pays full", mod._weak_judge({"gain": 10.0, "punch": 20.0, "reel": true}, "", "slam")["gain"], 10.0)
	_t.near("mind: and wears the seal", mod.weak.seal_hp("seat_2"), Mind.SEAL_HP - 20.0)
	var expect := [["split_lane"], ["split_lane", "rush"], ["split_lane", "rush"]]
	var ok := true
	for k in 3:
		await physics_frame
		mod.warden.open_lens = 0
		_place_ball(mod, mod.seat_position(k) + Vector3(0.5, 0.0, 0.0))
		mod._open_weak("seat_%d" % k) if mod.weak.state("seat_%d" % k) == WeakPoints.SHUT else null
		mod._weak_judge({"gain": 10.0, "punch": 500.0, "reel": true}, "", "slam")
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


# An opened point stays open at least OPEN_MIN, whatever closes it: the window running out or a crew fit.
# From a break until the next open the body stands bare: a re-seal by time or by the crew does not cover it.
func _bare() -> void:
	var rule := WeakPoints.new([{"id": "a", "seal_hp": 10.0, "removes": "x"}, {"id": "b", "seal_hp": 10.0, "removes": "y"}])
	_t.near("bare: before any break the body pays the chip", rule.judge({"punch": 5.0})["gain_scale"], WeakPoints.CHIP)
	rule.open("a", 1.0)
	rule.apply(rule.judge({"point": "a", "reel": true, "punch": 50.0}), 1.1)
	_t.check("bare: a break leaves the body bare", rule.state("a") == WeakPoints.BROKEN and rule.bare(), "")
	_t.near("bare: and every hit then pays full", rule.judge({"punch": 5.0})["gain_scale"], 1.0)
	rule.step(100.0)
	_t.check("bare: the clock alone does not cover it", rule.bare(), "")
	rule.open("b", 101.0)
	_t.check("bare: the next open does", not rule.bare() and is_equal_approx(rule.judge({"punch": 5.0})["gain_scale"], WeakPoints.CHIP), "")
	rule.step(200.0)
	_t.check("bare: a re-seal without a break keeps the chip", rule.state("b") == WeakPoints.SHUT and not rule.bare(), "")
	_t.check("bare: the off rule is never bare", not WeakPoints.off().bare(), "")


func _open_min() -> void:
	_t.near("OPEN_MIN is the tell floor", WeakPoints.OPEN_MIN, ChallengeDials.TELL_FLOOR)
	var parts := [{"id": "a", "seal_hp": 60.0, "removes": "x"}]
	var window := WeakPoints.new(parts, {"open_seconds": 0.1})
	window.open("a", 10.0)
	window.step(10.3)
	_t.check("a window shorter than OPEN_MIN still holds the point until OPEN_MIN", window.state("a") == WeakPoints.OPEN, "")
	window.step(10.0 + WeakPoints.OPEN_MIN + 0.01)
	_t.check("and then lets it re-seal", window.state("a") == WeakPoints.SHUT, "")
	var fit := WeakPoints.new(parts, {"fit_seconds": 0.1, "fit_min": 1})
	fit.begin_fit("a", 20.0)
	fit.open("a", 20.0)
	fit.step(20.3)
	_t.check("a fit that completes inside OPEN_MIN waits for it", fit.state("a") == WeakPoints.OPEN, "")
	fit.step(20.0 + WeakPoints.OPEN_MIN + 0.01)
	_t.check("and seals when it has passed", fit.state("a") == WeakPoints.SHUT, "")
	var hit := WeakPoints.new(parts, {"open_seconds": 0.1})
	hit.open("a", 30.0)
	hit.apply({"point": "a", "gain_scale": 1.0, "damage": 1.0, "broke": false}, 30.4)
	hit.step(30.5)
	_t.check("a hit restarts the window but not below OPEN_MIN from the first open", hit.state("a") == WeakPoints.OPEN, "")
	hit.step(30.75)
	_t.check("and the restarted window then runs out", hit.state("a") == WeakPoints.SHUT, "")
