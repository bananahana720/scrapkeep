extends SceneTree
# smoke: timeout=300s (115-146 s in a gate chunk on the w31 and w32 boxes, 160 s alone on w30's, where the
# default 180 s cap killed it in the chunk)

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const T := preload("res://tests/support/t.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const WeakPart := preload("res://src/boss/weak_part.gd")
const WakingAttacks := preload("res://src/boss/waking_attacks.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const MindAttacks := preload("res://src/boss/mind_attacks.gd")
const Waking := preload("res://src/boss/waking.gd")
const Mind := preload("res://src/boss/mind.gd")
const Warden := preload("res://src/combat/warden.gd")
const Augments := preload("res://src/movement/augments.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")
const BotDriver := preload("res://tools/bot_driver.gd")

# The physical weak points of the Waking and the Mind's dial-1 judge (#241 step 2a). Hatch and override parts
# exist only at dial 1, are hookable only while open, stay out of every enemy count, and pay the Warden's bar
# once through combat; a contact on the Warden's body pays the chip; a Mind seat is judged by the ball's distance
# to it; a hand's button breaks on a reel impact; the ultimate's hits are judged; one landing counts once.
#
# Evidence limit: strikes are player.struck / spawner.strike calls shaped like the ball's own (a contact with
# smash_landing set), plus one run through the ball's real contact code (_on_enemy_touched). No human play, no
# camera aim: the harpoon's aim is a ray query against the physics space, not a pointer.

var _t := T.new("boss_weak_parts_test")
# Seal hp (60) is more than the 40 punch of a 20 m/s ram, so one ram wears and does not break.
const RAM := 20.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await _waking_parts()
	await _contacts()
	await _hookable()
	await _openers()
	await _reachable()
	await _breaks()
	await _lifecycle()
	await _mind_seats()
	await _mind_hands()
	await _mind_hand_reel()
	await _ultimate()
	await _bot()
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


# The gain a hit would be judged at on the Warden's own rule, before the weak rule scales it.
func _gain(mod, kind: String, force: float, smash: bool) -> float:
	var punch: float = mod.ctx.spawner.punch_of(kind, force)
	var tier: int = SpeedTier.of(force, mod.ctx.player.tuning.f("cruise")) if kind == "ram" else 0
	return float(mod.warden.judge_hit(kind, punch, smash, tier)["gain"])


# _gain on a fresh frame, so the posture rule's per-frame contact cap has nothing booked against it.
func _next_gain(mod, kind: String, force: float, smash: bool) -> float:
	await physics_frame
	return _gain(mod, kind, force, smash)


func _empty_bar(mod) -> void:
	mod.warden._posture.posture = 0.0
	mod.warden._posture.idle = 0.0
	mod.warden._posture.staggered = false


# One ball contact on `body` (a part or the Warden) the way the ball's own code makes it: smash_landing names the
# body for the length of a landing. Returns how far the Warden's bar moved. A frame passes first, so the posture
# rule's one-contact-gain-per-frame cap never hides a second measure.
func _contact(mod, body: Node3D, kind: String, force: float, landing: bool) -> float:
	await physics_frame
	_empty_bar(mod)
	var player = mod.ctx.player
	player.smash_landing = body if landing else null
	player.struck.emit(body, kind, force)
	player.smash_landing = null
	return mod.warden.posture()


# Floors 1..n gone the way a drop leaves them: body freed, hatch freed with it.
func _drop_floors(mod, n: int) -> void:
	for k in range(1, n + 1):
		mod._free_part("hatch_%d" % k)
		mod._free_body(mod._floor_bodies.get(k))
		mod._floor_bodies.erase(k)


func _place_ball(mod, at: Vector3) -> void:
	mod.ctx.player.reset_to(at)
	mod.ctx.player.body().global_position = at


func _group_has_part(tree_root: Node) -> int:
	var n := 0
	for node in tree_root.get_tree().get_nodes_in_group("enemy"):
		n += 1 if node.get_script() == WeakPart else 0
	return n


func _waking_parts() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var ids: Array = mod._part_nodes.keys()
	ids.sort()
	_t.check("waking dial 1: three hatches and the override stand as parts", ids == ["hatch_1", "hatch_2", "hatch_3", "override"], str(ids))
	var in_group := get_nodes_in_group(WeakPart.GROUP).size()
	_t.eq("waking dial 1: the parts are in the weak_part group", in_group, 4)
	var clean := true
	var shut := true
	for id in ids:
		var part = mod.weak_part(id)
		clean = clean and not part.is_in_group("enemy") and not part.has_method("take_damage") and not part.has_signal("died") \
				and not part.has_method("is_dead") and part.is_inside_tree()
		shut = shut and part.collision_layer == 0 and part._cover.visible and not part._cavity.visible
	_t.check("parts are not enemies: not in the enemy group, no health, no death, no attack", clean, "")
	_t.check("parts start shut: no layer for the line to read, cover shown", shut, "")
	_t.eq("no part is counted by the enemy group (director, ultimate, presentation scans)", _group_has_part(game), 0)
	var alive_before: int = game.world.director_alive()
	mod._open_weak("hatch_1")
	_t.eq("an open part does not move the director's enemy count", game.world.director_alive(), alive_before)
	# Positions: a hatch sits on its floor's rim wall above the bank; the override is the pit's fixed bore head.
	var placed := true
	for k in range(1, 4):
		var at: Vector3 = mod.weak_part("hatch_%d" % k).global_position
		var flat := Vector2(at.x - mod._center.x, at.z - mod._center.z).length()
		placed = placed and absf(flat - (mod.PAD_RADIUS - Waking.HATCH_INSET)) < 0.01 \
				and absf(at.y - (mod._center.y + mod.floors.floor_height(k) + Waking.BANK_RISE + Waking.HATCH_LIFT)) < 0.01
	var head: Vector3 = mod.weak_part("override").global_position
	_t.check("each hatch is on its floor's rim wall above the bank", placed, "")
	_t.check("the override is the pit's bore head, a fixed spot half way out",
			absf(Vector2(head.x - mod._center.x, head.z - mod._center.z).length() - Waking.BORE_HEAD_RADIUS) < 0.01, str(head))
	# A part cannot be struck for damage and cannot die: combat ignores it.
	var ledger: Dictionary = mod.ctx.spawner.delivered_damage().duplicate(true)
	mod.ctx.spawner.strike(mod.weak_part("hatch_1"), "ram", 40.0)
	_t.check("combat.strike on a part does nothing", mod.ctx.spawner.delivered_damage() == ledger and is_instance_valid(mod.weak_part("hatch_1")), "")
	game.free()
	await physics_frame


func _contacts() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod._open_weak("hatch_1")
	var part = mod.weak_part("hatch_1")
	var seal: float = Waking.SEAL_HP
	var punch: float = mod.ctx.spawner.punch_of("ram", RAM)
	var full := _gain(mod, "ram", RAM, true)
	_t.check("a smash landing on a full gain is worth something (the test's own premise)", full > 0.5, str(full))
	# A reel smash on the open hatch: full gain into the Warden's bar, the seal worn by the punch, the part untouched.
	var paid: float = await _contact(mod, part, "ram", RAM, true)
	_t.near("a reel smash on the open hatch pays the judged gain in full into the Warden's bar", paid, full, 0.001)
	_t.near("and wears the hatch's seal by the punch", mod.weak.seal_hp("hatch_1"), seal - punch, 0.001)
	_t.check("and the part is whole: still standing, not dead", is_instance_valid(part) and mod.weak.state("hatch_1") == WeakPoints.OPEN, "")
	# A non-reel contact on the open hatch: chip.
	var plain: float = await _next_gain(mod, "ram", RAM, false)
	var chip: float = await _contact(mod, part, "ram", RAM, false)
	_t.near("a non-reel contact on the open hatch pays the chip", chip, plain * WeakPoints.CHIP, 0.001)
	_t.near("and leaves the seal alone", mod.weak.seal_hp("hatch_1"), seal - punch, 0.001)
	# A reel landing on the Warden's body, hatch open: no point, chip.
	var body: float = await _contact(mod, mod.warden, "ram", RAM, true)
	_t.near("a smash landing on the Warden's body pays the chip though a hatch is open", body, full * WeakPoints.CHIP, 0.001)
	var slam_plain: float = await _next_gain(mod, "slam", RAM, false)
	var plain_body: float = await _contact(mod, mod.warden, "slam", RAM, false)
	_t.near("a plain contact on the body pays the chip", plain_body, slam_plain * WeakPoints.CHIP, 0.001)
	# A reel that lands on a hatch the rule has shut (the line outlived the open): chip, no wear.
	mod.weak.step(mod.clock + 100.0)
	_t.eq("the hatch re-sealed", mod.weak.state("hatch_1"), WeakPoints.SHUT)
	var worn: float = mod.weak.seal_hp("hatch_1")
	var late: float = await _contact(mod, part, "ram", RAM, true)
	_t.near("a reel on a shut hatch pays the chip", late, full * WeakPoints.CHIP, 0.001)
	_t.near("and wears nothing", mod.weak.seal_hp("hatch_1"), worn, 0.001)
	# No double pay: the part is six metres from the Warden here, inside the slam's radius, so the landing's own SLAM
	# push strikes the Warden's body the same frame. The bar moves once, by the part's judged gain. A shut hatch is the
	# case the posture rule's own per-frame cap would not catch: its chip is smaller than the SLAM's gain.
	var slams := [0]
	game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float):
		slams[0] += 1 if enemy == mod.warden and kind == "slam" else 0)
	_drop_floors(mod, 1)
	mod._open_weak("hatch_2")
	var want: float = await _next_gain(mod, "ram", RAM, true)
	var open_bar: float = await _real_landing(mod, "hatch_2")
	_t.check("the ball's own contact code ran the landing: the line let go and the slam push reached the Warden", not mod.ctx.player.kit.hooked and slams[0] == 1,
			"hooked %s slams %d" % [mod.ctx.player.kit.hooked, slams[0]])
	_t.near("one landing on an open part raises the bar once, by the judged gain, not again through the SLAM push", open_bar, want, 0.001)
	_t.near("and wears the seal once", mod.weak.seal_hp("hatch_2"), seal - punch, 0.001)
	mod.weak.step(mod.clock + 100.0)
	_t.eq("hatch_2 re-sealed", mod.weak.state("hatch_2"), WeakPoints.SHUT)
	slams[0] = 0
	var shut_bar: float = await _real_landing(mod, "hatch_2")
	_t.check("the shut hatch's landing also drew a SLAM push", slams[0] == 1, str(slams[0]))
	_t.near("a landing on a shut hatch raises the bar once, by the chip: the SLAM push adds nothing", shut_bar, want * WeakPoints.CHIP, 0.001)
	game.free()
	await physics_frame


# A committed haul on `id`'s part, landing through the ball's own contact code with the part six metres from the Warden.
# Returns the Warden's bar afterwards.
func _real_landing(mod, id: String) -> float:
	var part = mod.weak_part(id)
	part.global_position = mod.warden.global_position + Vector3(6.0, 1.0, 0.0)
	await physics_frame
	_empty_bar(mod)
	var player = mod.ctx.player
	_place_ball(mod, part.global_position + Vector3(2.0, 0.0, 0.0))
	player.kit.hooked = true
	player.kit.on_body = true
	player.kit.anchor_body = part
	player.kit.line_state = Augments.LINE_SMASH
	player._rigid.recent_velocities.clear()
	player._rigid.recent_velocities.append(Vector3(-RAM, 0.0, 0.0))
	mod._touching.clear()
	mod._step_parts()
	return mod.warden.posture()


func _hookable() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var part = mod.weak_part("hatch_1")
	var at: Vector3 = part.global_position
	var from := Vector3(mod._center.x + 12.0, at.y - 4.5, mod._center.z)
	var mask: int = Augments.WORLD_MASK | Augments.ENEMY_MASK | Augments.STAKE_MASK
	await physics_frame
	var space: PhysicsDirectSpaceState3D = mod.warden.get_world_3d().direct_space_state
	var aim := func() -> Dictionary:
		return Augments.grapple_target(space, from, (at - from).normalized(), from, 80.0, 0.0, mask, true)
	var shut: Dictionary = aim.call()
	_t.check("a shut hatch does not latch: the aim is not a body", shut.get("state") != Augments.AIM_BODY, str(shut.get("state")))
	mod._open_weak("hatch_1")
	await physics_frame
	await physics_frame
	var open: Dictionary = aim.call()
	_t.check("an open hatch latches: the aim is the part's body", open.get("state") == Augments.AIM_BODY and open.get("body") == part, str(open.get("state")))
	_t.check("and it stays out of the ball's enemy-only paths (no grip, no crush)", not part.is_in_group("enemy"), "")
	mod.weak.step(mod.clock + 100.0)
	mod._sync_part("hatch_1")
	await physics_frame
	await physics_frame
	var reshut: Dictionary = aim.call()
	_t.check("a re-sealed hatch stops latching", reshut.get("state") != Augments.AIM_BODY, str(reshut.get("state")))
	mod._open_weak("hatch_1")
	mod.weak.apply({"point": "hatch_1", "gain_scale": 1.0, "damage": 1000.0, "broke": true}, mod.clock)
	mod._sync_part("hatch_1")
	await physics_frame
	await physics_frame
	var broken: Dictionary = aim.call()
	_t.check("a broken hatch does not latch", broken.get("state") != Augments.AIM_BODY and not part.hookable(), str(broken.get("state")))
	# A line that was on the part when it shut is let go; a committed haul keeps homing.
	mod.weak.step(mod.clock + 100.0)
	mod._open_weak("hatch_2")
	var second = mod.weak_part("hatch_2")
	var kit = mod.ctx.player.kit
	kit.hooked = true
	kit.on_body = true
	kit.anchor_body = second
	kit.line_state = Augments.LINE_LATCHED
	mod.weak.step(mod.clock + 100.0)
	mod._sync_part("hatch_2")
	_t.check("a latched line is dropped when its hatch shuts", not kit.hooked, "")
	mod._open_weak("hatch_3")
	var third = mod.weak_part("hatch_3")
	kit.hooked = true
	kit.on_body = true
	kit.anchor_body = third
	kit.line_state = Augments.LINE_SMASH
	mod.weak.step(mod.clock + 100.0)
	mod._sync_part("hatch_3")
	_t.check("a committed haul keeps homing on a hatch that shuts", kit.hooked, "")
	game.free()
	await physics_frame


# Each attack's own end opens its hatch, once. mod.clock is advanced by hand and the hazards laid and stepped by the
# module's own methods, so the end is the real end (every hazard past its live seconds).
func _run_attack(mod, family: String, hatch: String, drop_floor := 0) -> Dictionary:
	var opens: Array = []
	var listener := func(id: String, _at: Vector3, _seconds: float): opens.append(id)
	mod.ctx.events.weak_point_opened.connect(listener)
	mod._clear_attacks()
	mod._last_warn = -INF
	mod._commit_attack(family)
	var attack: Dictionary = mod.attacks[0]
	var open_step := -1
	var end_step := -1
	var shut_while_live := true
	for i in 900:
		mod.clock += 0.02
		# drop_floor: that floor's drop warning starts once the attack is fully laid, so it ends inside the warning.
		if drop_floor > 0 and mod._pending.is_empty() and mod._dropping == 0:
			mod._dropping = drop_floor
			mod._drop_left = 1.0
		mod._lay_pending()
		mod._step_attacks(0.02)
		var live := false
		var ended: bool = mod._pending.is_empty()
		for h in attack["hazards"]:
			live = live or h.is_live()
			ended = ended and h.is_done()
		if open_step < 0 and opens.has(hatch):
			open_step = i
		if end_step < 0 and ended and not (attack["hazards"] as Array).is_empty():
			end_step = i
		if live and open_step < 0 and mod.weak.state(hatch) != WeakPoints.SHUT:
			shut_while_live = false
		if end_step >= 0 and i > end_step + 40:
			break
	mod.ctx.events.weak_point_opened.disconnect(listener)
	return {"opens": opens.filter(func(id): return id == hatch).size(), "open_step": open_step, "end_step": end_step, "shut_while_live": shut_while_live}


func _openers() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod.set_physics_process(false)
	mod.phase = 1
	var burrow := _run_attack(mod, "burrow", "hatch_1")
	_t.check("a burrow leaves hatch_1 shut while it is live", burrow["shut_while_live"], "")
	_t.eq("a burrow opens hatch_1 once, as it ends", burrow["opens"], 1)
	_t.check("the burrow opens it on the step its last hazard finished", burrow["open_step"] == burrow["end_step"] and burrow["end_step"] > 0, str(burrow))
	mod.weak.step(mod.clock + 100.0)
	_drop_floors(mod, 1)
	mod.phase = 2
	var cave := _run_attack(mod, "cave_in", "hatch_2")
	_t.check("a cave-in leaves hatch_2 shut while it is live", cave["shut_while_live"], "")
	_t.eq("a cave-in opens hatch_2 once, as it settles", cave["opens"], 1)
	_t.check("the cave-in opens it on the step its last hole finished", cave["open_step"] == cave["end_step"] and cave["end_step"] > 0, str(cave))
	# The burrow in the second phase: floor 1 is gone, and its hatch left with it.
	mod.weak.step(mod.clock + 100.0)
	var gone := _run_attack(mod, "burrow", "hatch_1")
	_t.eq("a burrow after floor 1 dropped opens nothing: the hatch left with its floor", gone["opens"], 0)
	# The bore jam: hatch_3 off the pit, the override in it, once per jam.
	mod.weak.step(mod.clock + 100.0)
	_drop_floors(mod, 2)
	mod.phase = 3
	mod._jammed_until = -INF
	var opens: Array = []
	game.events.weak_point_opened.connect(func(id: String, _at: Vector3, _s: float): opens.append(id))
	_bore(mod, 3)
	_t.check("a bore jam opens hatch_3", mod.weak_open() == ["hatch_3"] and opens == ["hatch_3"], str(opens))
	mod._step_attacks(0.0)
	mod._step_attacks(0.0)
	_t.eq("and a jam still running opens nothing more", opens.size(), 1)
	mod.weak.step(mod.clock + 100.0)
	# Floor 3's body is gone (the pit's override is buried until then); its hatch stays for the checks below.
	mod._free_body(mod._floor_bodies.get(3))
	mod._floor_bodies.erase(3)
	_bore(mod, 4)
	_t.check("a bore jam in the pit opens the override", mod.weak_open() == ["override"] and opens.back() == "override", str(opens))
	# Each open carries the point's world position and its open seconds.
	var seen := []
	game.events.weak_point_opened.connect(func(id: String, at: Vector3, seconds: float): seen.append([id, at, seconds]))
	mod.weak.step(mod.clock + 100.0)
	mod._open_weak("hatch_3")
	_t.check("an open emits the part's world position and the open seconds",
			seen.size() == 1 and seen[0][0] == "hatch_3" and (seen[0][1] as Vector3).is_equal_approx(mod.weak_part("hatch_3").global_position)
			and absf(float(seen[0][2]) - mod.weak.open_seconds) < 0.0001, str(seen))
	game.free()
	await physics_frame


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


# Only a reachable hatch opens (dial 1): floor k's hatch is buried while a floor above it stands, and not worth opening
# once its own floor is on its way down.
func _reachable() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod.set_physics_process(false)
	mod.phase = 1
	_t.check("phase 1 on a fresh floor: hatch_1 is reachable, the rest are buried", mod.part_reachable("hatch_1") and not mod.part_reachable("hatch_2")
			and not mod.part_reachable("hatch_3") and not mod.part_reachable("override"), "")
	# The gate's path: an attack that ends inside floor 1's drop warning opens nothing and says nothing.
	var emitted: Array = []
	game.events.weak_point_opened.connect(func(id: String, _at: Vector3, _s: float): emitted.append(id))
	var warned := _run_attack(mod, "burrow", "hatch_1", 1)
	_t.check("floor 1 in its drop warning: hatch_1 is not reachable", mod._dropping == 1 and not mod.part_reachable("hatch_1"), "")
	_t.check("a burrow ending inside the drop warning opens nothing and emits nothing", warned["end_step"] >= 0 and warned["opens"] == 0 and mod.weak_open().is_empty()
			and mod.weak.state("hatch_1") == WeakPoints.SHUT and emitted.is_empty(), str(emitted))
	_t.check("and no objective text or bot target for it", not mod.objective_text().contains("is open"), mod.objective_text())
	mod._dropping = 0
	mod._clear_attacks()
	mod._drops.append(1)
	_t.check("floor 1 queued behind another drop is not reachable either", not mod.part_reachable("hatch_1"), "")
	var queued := _run_attack(mod, "burrow", "hatch_1")
	_t.check("a burrow ending while its floor is queued opens nothing", queued["opens"] == 0 and emitted.is_empty(), str(emitted))
	mod._drops.clear()
	# A buried hatch never opens: a cave-in or a bore jam in phase 1 leaves hatch_2 and hatch_3 shut.
	var cave := _run_attack(mod, "cave_in", "hatch_2")
	_t.check("a cave-in ending in phase 1 leaves hatch_2 shut with no emit", cave["opens"] == 0 and mod.weak.state("hatch_2") == WeakPoints.SHUT and emitted.is_empty(), str(emitted))
	_bore(mod, 1)
	_t.check("a bore jam in phase 1 leaves hatch_3 shut with no emit", mod.weak.state("hatch_3") == WeakPoints.SHUT and mod.weak.state("override") == WeakPoints.SHUT
			and emitted.is_empty(), str(emitted))
	# The same family in its own phase still opens its hatch (the control that the refusals above are the check's doing).
	var own := _run_attack(mod, "burrow", "hatch_1")
	_t.eq("a burrow ending in phase 1 with floor 1 standing still opens hatch_1", own["opens"], 1)
	mod.weak.step(mod.clock + 100.0)
	# Phase 2: floor 1 gone, floor 2 top; the override stays buried until the pit.
	_drop_floors(mod, 1)
	mod.phase = 2
	_t.check("after floor 1 drops hatch_2 is reachable and hatch_3 is not", mod.part_reachable("hatch_2") and not mod.part_reachable("hatch_3") and not mod.part_reachable("hatch_1"), "")
	mod.phase = 4
	_t.check("the override is buried in the pit phase while a floor still stands", not mod.part_reachable("override"), "")
	_drop_floors(mod, 3)
	_t.check("the override is reachable in the pit phase once every floor is gone", mod.part_reachable("override"), "")
	mod._drops.append(3)
	_t.check("and buried again while a floor sits in the drop queue", not mod.part_reachable("override"), "")
	mod._drops.clear()
	mod._dropping = 3
	_t.check("and while a floor is in its drop warning", not mod.part_reachable("override"), "")
	mod._dropping = 0
	mod.phase = 3
	_t.check("and not in phase 3", not mod.part_reachable("override"), "")
	game.free()
	await physics_frame
	# A buried part is not touched: it pays nothing to the Warden's bar, not even the chip.
	booted = await _boot(2, {"waking.weak_points": 1.0})
	game = booted[0]
	mod = booted[1]
	var control: float = await _real_landing(mod, "hatch_1")
	_t.check("control: a landing on the reachable shut hatch_1 pays the chip", control > 0.0, str(control))
	# A fly-by with no line on it: the ball inside REACH of a shut hatch pays nothing.
	var flyer = mod.ctx.player
	flyer.kit.hooked = false
	flyer.kit.anchor_body = null
	_empty_bar(mod)
	_place_ball(mod, mod.weak_part("hatch_1").global_position + Vector3(2.0, 0.0, 0.0))
	flyer._rigid.recent_velocities.clear()
	flyer._rigid.recent_velocities.append(Vector3(-RAM, 0.0, 0.0))
	mod._touching.clear()
	mod._step_parts()
	_t.near("a ball flying past a shut hatch with no line on it pays nothing", mod.warden.posture(), 0.0, 0.0001)
	mod.weak_part("hatch_1").global_position += Vector3(0.0, -60.0, 0.0)  # park it: only the buried part is in reach
	var buried: float = await _real_landing(mod, "hatch_2")
	_t.near("a landing on the buried hatch_2 pays nothing", buried, 0.0, 0.0001)
	mod._open_weak("hatch_3")
	var buried_open: float = await _real_landing(mod, "hatch_3")
	_t.near("and nothing on a buried hatch the rule had opened", buried_open, 0.0, 0.0001)
	# OPEN visuals: the cover is hidden, the cavity shows with the gap emission, and the part is on the stake layer.
	var part = mod.weak_part("hatch_1")
	mod._open_weak("hatch_1")
	mod._sync_part("hatch_1")
	_t.check("an OPEN part: cover hidden, cavity visible, ancient-green notches lit, on the stake layer",
			not part._cover.visible and part._cavity.visible and part._notches.visible and not part.lit_colors().is_empty()
			and part.collision_layer == Augments.STAKE_MASK and part.hookable(), "")
	game.free()
	await physics_frame


# A hand's reel test is combat's shared predicate: a smash landing or a winching haul on a ram/stomp/slam contact.
func _mind_hand_reel() -> void:
	var booted = await _boot(3, {"mind.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var player = mod.ctx.player
	mod.phase = Mind.HAND_PHASE
	mod._send_hand()
	var hand = mod.hands[0]
	await physics_frame
	hand.phase = hand.Phase.ROAM
	_brace(mod, hand)
	var shared: bool = mod.ctx.spawner.is_reel_impact("ram", false)
	_t.check("premise: a hooked, winching ram is a reel by the shared predicate; unhooked is not", not shared, "")
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	_t.eq("a hit that is not a reel pays chip: the button is unworn", mod.weak.seal_hp("hand_0"), Mind.SEAL_HP)
	await physics_frame
	_brace(mod, hand)
	player.kit.hooked = true
	player.kit.winching = true
	_t.check("premise: now the shared predicate calls it a reel", mod.ctx.spawner.is_reel_impact("ram", false), "")
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	var worn: float = mod.weak.seal_hp("hand_0")
	_t.check("a winching haul hit on the hand is a reel and wears the button", worn < Mind.SEAL_HP, str(worn))
	player.kit.hooked = false
	player.kit.winching = false
	await physics_frame
	_brace(mod, hand)
	player.smash_landing = hand
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	player.smash_landing = null
	_t.check("a smash-landing hit on the hand is a reel", mod.weak.seal_hp("hand_0") < worn, str(mod.weak.seal_hp("hand_0")))
	game.free()
	await physics_frame


func _breaks() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var breaks := [["hatch_1", "burrow"], ["hatch_2", "cave_in"], ["hatch_3", "bore"]]
	var removed: Array = []
	for row in breaks:
		var id: String = row[0]
		mod._open_weak(id)
		var part = mod.weak_part(id)
		await _contact(mod, part, "ram", 60.0, true)
		_t.eq("a reel smash with the punch for it breaks %s" % id, mod.weak.state(id), WeakPoints.BROKEN)
		_t.check("%s is a cavity now: cover hidden, cavity shown, not hookable" % id, not part._cover.visible and part._cavity.visible and not part.hookable(), "")
		removed.append(row[1])
		var exposed: Array = WakingAttacks.exposed(4, mod._removed_families())
		var every := true
		for seed in 64:
			every = every and not (mod._removed_families() as Array).has(WakingAttacks.choose(seed, 4, mod._removed_families()))
		if removed.size() < 3:
			_t.check("breaking %s removes %s from exposed and choose" % [id, row[1]], not exposed.has(row[1]) and every, str(exposed))
		else:
			_t.check("the third break leaves the families whole: never all removed", exposed == WakingAttacks.FAMILIES, str(exposed))
	# A fresh fight: only the bore's hatch broken takes the bore from phase 3 on.
	game.free()
	await physics_frame
	var again = await _boot(2, {"waking.weak_points": 1.0})
	var mod2 = again[1]
	mod2._open_weak("hatch_3")
	await _contact(mod2, mod2.weak_part("hatch_3"), "ram", 60.0, true)
	_t.check("breaking hatch_3 alone removes bore", WakingAttacks.exposed(3, mod2._removed_families()) == ["burrow", "cave_in"], str(mod2._removed_families()))
	mod2._open_weak("override")
	await _contact(mod2, mod2.weak_part("override"), "ram", 60.0, true)
	_t.check("breaking the override removes pit_spray only: the pit's bore is one disc",
			WakingAttacks.bore(5, Vector3(10, 0, 0), Vector3.ZERO, 4, 36.0, mod2._removed_families()).size() == 1
			and (mod2._removed_families() as Array).has("pit_spray"), str(mod2._removed_families()))
	again[0].free()
	await physics_frame


func _lifecycle() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	mod._open_weak("hatch_1")
	await _contact(mod, mod.weak_part("hatch_1"), "ram", 60.0, true)
	_t.eq("hatch_1 broke", mod.weak.state("hatch_1"), WeakPoints.BROKEN)
	# Shatter chunk one: floor 1 drops after its warning and takes its hatch, broken or not.
	mod.warden._posture.chunks = 3
	for i in 240:
		await physics_frame
		if not mod._floor_bodies.has(1):
			break
	_t.check("the floor dropped", not mod._floor_bodies.has(1), "")
	var names := get_nodes_in_group(WeakPart.GROUP).map(func(n): return String(n.name))
	_t.check("a broken hatch's floor shattering leaves no orphan: the part is freed and out of every group",
			mod.weak_part("hatch_1") == null and not names.has("WeakPart_hatch_1"), str(names))
	_t.eq("the other parts stand", mod._part_nodes.keys().size(), 3)
	_t.eq("and the weak_part group lists exactly them", get_nodes_in_group(WeakPart.GROUP).size(), 3)
	var struck_connections: int = mod.ctx.player.struck.get_connections().filter(func(c): return c["callable"] == Callable(mod, "_on_player_struck")).size()
	_t.eq("the module listens to the ball while the fight runs", struck_connections, 1)
	mod.exit_arena()
	_t.eq("exit_arena removes every part", get_nodes_in_group(WeakPart.GROUP).size(), 0)
	struck_connections = mod.ctx.player.struck.get_connections().filter(func(c): return c["callable"] == Callable(mod, "_on_player_struck")).size()
	_t.eq("and stops listening", struck_connections, 0)
	game.free()
	await physics_frame
	# Boss death frees them too.
	var dead = await _boot(2, {"waking.weak_points": 1.0})
	var mod3 = dead[1]
	_t.eq("a fresh fight has its four parts", get_nodes_in_group(WeakPart.GROUP).size(), 4)
	mod3._on_warden_died(Vector3.ZERO, 0)
	_t.eq("the Warden's death removes every part", get_nodes_in_group(WeakPart.GROUP).size(), 0)
	dead[0].free()
	await physics_frame


func _seat_at(mod, k: int, offset: Vector3) -> Vector3:
	var at: Vector3 = mod.seat_position(k)
	return Vector3(at.x, mod._top() + 1.0, at.z) + offset


# Puts a point back to a whole seal, OPEN, so one test's wear does not decide the next.
func _refill(mod, id: String, open := true) -> void:
	var part: Dictionary = mod.weak._parts[id]
	part["seal_hp"] = part["max_hp"]
	part["state"] = WeakPoints.OPEN if open else WeakPoints.SHUT
	part["opened_at"] = mod.clock
	part["first_open"] = mod.clock


func _reel(d: Dictionary) -> Dictionary:
	d["reel"] = true
	return d


func _mind_seats() -> void:
	var booted = await _boot(3, {"mind.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var player = mod.ctx.player
	mod.warden.open_lens = 0
	_t.check("mind seat positions follow the lens formula", mod.seat_position(0).is_equal_approx(mod.warden.family_point_at()), "")
	mod.warden.open_lens = 1
	_t.check("and the formula whichever seat the lens is on", mod.seat_position(1).is_equal_approx(mod.warden.family_point_at()), "")
	mod.warden.open_lens = 0
	_t.near("the reach is the Warden's own contact reach", Mind.SEAT_REACH, Warden.FAMILY_REACH)
	mod._open_weak("seat_1")
	var full := _gain(mod, "slam", RAM, true)
	_place_ball(mod, _seat_at(mod, 1, Vector3(1.0, 0.0, 0.0)))
	var in_reach: float = await _contact(mod, mod.warden, "slam", RAM, true)
	_t.near("a reel on the Warden within reach of the open seat counts on the seat: full", in_reach, full, 0.001)
	_t.check("and wears the seat's seal", mod.weak.seal_hp("seat_1") < Mind.SEAL_HP, str(mod.weak.seal_hp("seat_1")))
	_refill(mod, "seat_1")
	_place_ball(mod, _seat_at(mod, 1, Vector3(Mind.SEAT_REACH + 1.0, 0.0, 0.0)))
	var out: float = await _contact(mod, mod.warden, "slam", RAM, true)
	_t.near("a reel just out of reach pays the chip", out, full * WeakPoints.CHIP, 0.001)
	_t.near("and leaves the seal alone", mod.weak.seal_hp("seat_1"), Mind.SEAL_HP, 0.001)
	_place_ball(mod, _seat_at(mod, 1, Vector3(Mind.SEAT_REACH - 0.3, 0.0, 0.0)))
	var edge: float = await _contact(mod, mod.warden, "slam", RAM, true)
	_t.near("and just inside the reach pays full", edge, full, 0.001)
	_refill(mod, "seat_1", false)
	_place_ball(mod, _seat_at(mod, 1, Vector3(1.0, 0.0, 0.0)))
	var shut: float = await _contact(mod, mod.warden, "slam", RAM, true)
	_t.near("within reach of a shut seat the contact pays the chip", shut, full * WeakPoints.CHIP, 0.001)
	_refill(mod, "seat_1")
	var seat_plain: float = await _next_gain(mod, "slam", RAM, false)
	var plain: float = await _contact(mod, mod.warden, "slam", RAM, false)
	_t.near("a non-reel contact on the open seat pays the chip", plain, seat_plain * WeakPoints.CHIP, 0.001)
	# One reel per landing per point: the contact and the SLAM shockwave of one landing wear the seal once.
	var f2 := 12.0
	var punch_ram: float = mod.ctx.spawner.punch_of("ram", f2)
	var punch_slam: float = mod.ctx.spawner.punch_of("slam", f2)
	_refill(mod, "seat_1")
	await physics_frame
	var ram_raw: Dictionary = mod.warden.judge_hit("ram", punch_ram, true, 1)
	var slam_raw: Dictionary = mod.warden.judge_hit("slam", punch_slam, true, 0)
	var ram_hit: Dictionary = mod._weak_judge(_reel(ram_raw.duplicate()), "", "ram")
	var slam_hit: Dictionary = mod._weak_judge(_reel(slam_raw.duplicate()), "", "slam")
	_t.near("one landing: the contact pays full and wears the seal", float(ram_hit["gain"]), float(ram_raw["gain"]), 0.001)
	_t.near("and the same landing's SLAM strike does not wear it again", mod.weak.seal_hp("seat_1"), Mind.SEAL_HP - punch_ram, 0.001)
	_t.near("nor pay full again: it pays the chip", float(slam_hit["gain"]), float(slam_raw["gain"]) * WeakPoints.CHIP, 0.001)
	await physics_frame
	mod._weak_judge(_reel(ram_raw.duplicate()), "", "ram")
	_t.near("a later landing counts again", mod.weak.seal_hp("seat_1"), Mind.SEAL_HP - 2.0 * punch_ram, 0.001)
	# The plate's brace: the verb it braces meets 1 / BRACE_MULT on the open seat while the plate stands.
	mod.weak.step(mod.clock + 100.0)
	mod._commit_attack("plate")
	var verb: String = mod._plate_verb
	var open: Array = mod.weak_open()
	_t.check("a plate opens a seat and names a verb", verb != "" and open.size() == 1, "%s %s" % [verb, open])
	var seat_id := String(open[0])
	var seat_k := int(seat_id.substr(5))
	_place_ball(mod, _seat_at(mod, seat_k, Vector3(1.0, 0.0, 0.0)))
	var braced_gain := _gain(mod, verb, RAM, true)
	var braced: float = await _contact(mod, mod.warden, verb, RAM, true)
	_t.near("the braced verb on the open seat pays 1 / BRACE_MULT of the full gain", braced, braced_gain / MindAttacks.BRACE_MULT, 0.001)
	_refill(mod, seat_id)
	var other: String = ["stomp", "ram", "slam"].filter(func(k): return k != verb)[0]
	var other_gain: float = await _next_gain(mod, other, RAM, true)
	var free_verb: float = await _contact(mod, mod.warden, other, RAM, true)
	_t.near("any other verb pays full", free_verb, other_gain, 0.001)
	_refill(mod, seat_id)
	mod._plate_until = mod.clock - 1.0
	var lapsed: float = await _contact(mod, mod.warden, verb, RAM, true)
	_t.near("after the plate's window the verb pays full again", lapsed, braced_gain, 0.001)
	game.free()
	await physics_frame


func _brace(mod, hand) -> void:
	hand.habit = "ram"
	hand.phase = hand.Phase.LIVE
	mod._step_hands()


func _mind_hands() -> void:
	var booted = await _boot(3, {"mind.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var player = mod.ctx.player
	_t.eq("hands start at the cap", mod._hand_cap(), Mind.HAND_CAP)
	mod.phase = Mind.HAND_PHASE
	mod._send_hand()
	_t.eq("a hand arrives", mod.hands.size(), 1)
	var hand = mod.hands[0]
	_t.eq("and holds a button slot", int(mod._hand_slots[hand.get_instance_id()]), 0)
	await physics_frame
	hand.phase = hand.Phase.ROAM
	hand.habit = ""
	player.smash_landing = hand
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	player.smash_landing = null
	_t.eq("a reel on an unbraced hand wears nothing", mod.weak.seal_hp("hand_0"), Mind.SEAL_HP)
	await physics_frame
	_brace(mod, hand)
	_t.eq("a braced hand opens its button", mod.weak.state("hand_0"), WeakPoints.OPEN)
	_t.check("the hand's button is not a Warden point to the bot or the objective", mod.weak_open().is_empty(), "")
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	_t.eq("a plain contact on the braced hand wears nothing", mod.weak.seal_hp("hand_0"), Mind.SEAL_HP)
	await physics_frame
	_brace(mod, hand)
	var hits := []
	game.events.boss_weak_point_hit.connect(func(id: String): hits.append(id))
	player.smash_landing = hand
	mod.ctx.spawner.strike(hand, "ram", 12.0)
	player.smash_landing = null
	_t.check("a reel on the braced hand wears its button and says so", mod.weak.seal_hp("hand_0") < Mind.SEAL_HP and hits == ["hand_0"], str(hits))
	_t.check("and the hand is still in the fight", not hand.is_dead() and mod.hands.has(hand), "")
	await physics_frame
	_brace(mod, hand)
	player.smash_landing = hand
	mod.ctx.spawner.strike(hand, "ram", 60.0)
	player.smash_landing = null
	_t.eq("a reel with the punch for it breaks the button", mod.weak.state("hand_0"), WeakPoints.BROKEN)
	_t.check("the hand is disabled through the boss-add death", hand.is_dead() and not mod.hands.has(hand), "")
	_t.eq("and the cap drops by one for the rest of the fight", mod._hand_cap(), Mind.HAND_CAP - 1)
	var most := 0
	for i in 6:
		mod.attack_count = i
		mod.phase = Mind.HAND_PHASE
		mod._send_hand()
		mod.hands = mod.hands.filter(func(h): return is_instance_valid(h) and not h.is_dead())
		most = maxi(most, mod.hands.size())
	_t.eq("no more than the lowered cap is ever fielded", most, Mind.HAND_CAP - 1)
	_t.eq("and the next hand takes the unbroken slot", int(mod._hand_slots[mod.hands[0].get_instance_id()]), 1)
	game.free()
	await physics_frame


func _ultimate() -> void:
	for dial in [0.0, 1.0]:
		var booted = await _boot(2, {"waking.weak_points": dial})
		var game = booted[0]
		var mod = booted[1]
		var ult = mod.ctx.spawner.ultimate
		var full := _gain(mod, "ram", RAM, false)
		await physics_frame
		_empty_bar(mod)
		var result: Dictionary = mod.ctx.spawner.resolve(mod.warden, "ram", RAM)
		ult.warden_posture(mod.warden, result)
		var want := full * (WeakPoints.CHIP if dial > 0.5 else 1.0)
		_t.near("ultimate path at dial %d: the hit pays %s" % [int(dial), "the chip" if dial > 0.5 else "full, as before"], mod.warden.posture(), want, 0.001)
		game.free()
		await physics_frame
	# On an open seat the ultimate's contact is judged full when it was a reel.
	var mind = await _boot(3, {"mind.weak_points": 1.0})
	var mod2 = mind[1]
	mod2._open_weak("seat_0")
	_place_ball(mod2, _seat_at(mod2, 0, Vector3(1.0, 0.0, 0.0)))
	var open_want: float = await _next_gain(mod2, "slam", RAM, false)
	_empty_bar(mod2)
	var open_hit: Dictionary = mod2.ctx.spawner.resolve(mod2.warden, "slam", RAM)
	open_hit["reel"] = true
	mod2.ctx.spawner.ultimate.warden_posture(mod2.warden, open_hit)
	_t.near("ultimate path: a reel on an open seat pays full", mod2.warden.posture(), open_want, 0.001)
	mind[0].free()
	await physics_frame


func _bot() -> void:
	var booted = await _boot(2, {"waking.weak_points": 1.0})
	var game = booted[0]
	var mod = booted[1]
	var bot = BotDriver.new(game, "skipper", 1)
	var rng_before: int = bot.rng.state
	bot._read_weak_points(mod, 0.016)
	_t.check("nothing open: the bot's target stays the Warden and it draws no roll", bot._open_part(mod) == null and bot.rng.state == rng_before, "")
	mod._open_weak("hatch_1")
	bot._read_weak_points(mod, 0.016)
	_t.check("an open hatch with the go: the bot's target is that part", bot._open_part(mod) == mod.weak_part("hatch_1"), "")
	mod.weak.step(mod.clock + 100.0)
	bot._read_weak_points(mod, 0.016)
	_t.check("re-sealed: back to the Warden", bot._open_part(mod) == null, "")
	var nearest: Node3D = bot._nearest_enemy()
	_t.check("the bot's enemy scan never returns a part", nearest == null or nearest.get_script() != WeakPart, "")
	game.free()
	await physics_frame
	var off = await _boot(2, {"waking.weak_points": 0.0})
	var mod0 = off[1]
	var bot0 = BotDriver.new(off[0], "skipper", 1)
	var state_before: int = bot0.rng.state
	bot0._read_weak_points(mod0, 0.016)
	_t.check("dial 0: the bot has no part to go for and nothing moved", bot0._open_part(mod0) == null and bot0.rng.state == state_before and not bot0._weak_go, "")
	off[0].free()
	await physics_frame
