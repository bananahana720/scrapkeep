# smoke: solo timeout=360s fixed-fps=90 (20 seeded crowd encounters run twice, 6 s uncapped and 14 s capped, then 5 at the early cap; about 200 s wall, 179.3 s in a w23 gate chunk)
extends SceneTree

# SQ2 attacker budget (W13-INTEGRATION-3.md SQ2). 20 seeded encounters at the park table's
# highest tier: stage 6's packs and elite, as many units as that stage's director allows at
# the top time tier with the spike on the hard run tier, dropped around a ball held on one
# spot. Each encounter runs twice:
# - uncapped (the world root's cap set past the crowd): the peak count of units in WARN or
#   LIVE at once, the measure KE9's report did not take. It justifies the cap: some seed
#   must pass it, or the budget would never bind. The whole crowd is ready inside its
#   first rest, so the peak lands in the first seconds;
# - capped, at the late cap (heft class 5 in world 3): the same count never passes the cap
#   on any tick of any seed; no two distinct threats (a different director pack, or a
#   different kind in the same pack) start their warnings within AttackBudget.MIN_GAP, while
#   pack mates of one kind may share a beat (Andrew's "Pack as one"); and the line moves: no unit waits longer than WAIT_LIMIT for a
#   slot, finished or not.
# Five more seeds run at the early cap (a fresh ball in world 1) with stage 1's packs, so
# the chaser is in the crowd. The curve itself is
# checked as data: START at the beginning, never falling, never past LATE.
# The count is read from each unit's own phase, not from the budget's groups.
# The Warden and its posture fight are exempt: neither is a counter, and neither names the
# budget.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Counter := preload("res://src/combat/counter.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const T := preload("res://tests/support/t.gd")

const SEEDS := 20
const UNCAPPED_SECONDS := 6.0
const SECONDS := 14.0
# A crowd of 24 sharing the slots, each attack about 2 s of warning and live, turns over in
# about 12 s; a unit waiting past that has been skipped.
const WAIT_LIMIT := 12.0
const SPEED := 4
const BASE_TICKS := 90
const RING_MIN := 8.0
const RING_MAX := 16.0
const LATE_HEFT := 5
const LATE_WORLD := 3
const EARLY_SEEDS := 5
const EARLY_SECONDS := 8.0

var _game
var _test := T.new("attack_budget_test")
var _ball_at := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	_structure()
	_curve()
	if not await _boot():
		_finish()
		return
	var crowd := _crowd_size()
	var late := AttackBudget.cap_at(LATE_HEFT, LATE_WORLD)
	_test.check("crowd fills the top tier's cap", crowd > late, "%d units at stage 6, hard run tier, top tier; late cap %d" % [crowd, late])
	var uncapped_peaks: Array = []
	var capped_peaks: Array = []
	var gaps: Array = []
	var joined := 0
	var violations := 0
	var waits: Array = []
	for seed_value in SEEDS:
		var open: Dictionary = await _encounter(seed_value, crowd, false, LATE_HEFT, LATE_WORLD, UNCAPPED_SECONDS)
		uncapped_peaks.append(open.peak)
		var shut: Dictionary = await _encounter(seed_value, crowd, true, LATE_HEFT, LATE_WORLD, SECONDS)
		capped_peaks.append(shut.peak)
		gaps.append(shut.min_gap)
		joined += shut.joined
		violations += shut.over
		waits.append(shut.longest_wait)
		print("seed %d: uncapped peak %d (closest distinct warnings %.2f s), capped peak %d (closest distinct warnings %.2f s), ticks over cap %d, longest wait %.2f s, attacks %d uncapped / %d capped"
			% [seed_value, open.peak, open.min_gap, shut.peak, shut.min_gap, shut.over, shut.longest_wait, open.attacks, shut.attacks])
	_test.check("uncapped peak passes the late cap on some seed", uncapped_peaks.max() > late,
		"uncapped peaks %s, late cap %d" % [uncapped_peaks, late])
	_test.eq("ticks over the late cap, all seeds", violations, 0)
	_test.check("capped peak reaches the late cap", capped_peaks.max() == late, "capped peaks %s" % [capped_peaks])
	_test.check("no two distinct packs or kinds warn within the gap", gaps.min() >= AttackBudget.MIN_GAP - 0.5 / BASE_TICKS,
		"closest distinct warning starts per seed %s, floor %.2f s" % [gaps, AttackBudget.MIN_GAP])
	_test.check("pack mates share a beat", joined > 0, "%d warnings joined their pack mate's beat" % joined)
	_test.check("no unit waits past the limit", waits.max() <= WAIT_LIMIT, "longest waits %s, limit %.1f s" % [waits, WAIT_LIMIT])
	# The early cap binds too: a fresh ball in world 1 meets START attackers at most.
	var early := AttackBudget.cap_at(1, 1)
	var early_over := 0
	var early_peaks: Array = []
	for seed_value in EARLY_SEEDS:
		var first: Dictionary = await _encounter(seed_value, crowd, true, 1, 1, EARLY_SECONDS, 1)
		early_over += first.over
		early_peaks.append(first.peak)
	_test.eq("ticks over the early cap", early_over, 0)
	_test.check("capped peak reaches the early cap", early_peaks.max() == early, "early peaks %s, cap %d" % [early_peaks, early])
	# Hive defenders skip the whole budget (2026-10-17 cards "Swarm campers" and "All at hives"): with a
	# live hive at the ball the crowd passes the late cap and distinct warnings may share a beat.
	var hive := _hive()
	var defended: Dictionary = await _encounter(0, crowd, true, LATE_HEFT, LATE_WORLD, SECONDS)
	hive.queue_free()
	await process_frame
	_test.check("hive defenders pass the cap", defended.peak > late, "peak %d beside a live hive, late cap %d" % [defended.peak, late])
	_test.check("hive defenders skip the gap", defended.min_gap < AttackBudget.MIN_GAP - 0.5 / BASE_TICKS,
		"closest distinct warning starts %.2f s" % defended.min_gap)
	print("uncapped peak: min %d, median %d, max %d of %d units; late cap %d; longest wait max %.2f s"
		% [uncapped_peaks.min(), _median(uncapped_peaks), uncapped_peaks.max(), crowd, late, waits.max()])
	_finish()


# The curve's shape: START for a fresh ball in world 1 (Andrew's pick), growing with heft
# class and world, never past LATE, and reaching it in the late Highdraft.
func _curve() -> void:
	_test.eq("a fresh ball in world 1 meets the start cap", AttackBudget.cap_at(1, 1), AttackBudget.START)
	_test.eq("start cap is six", AttackBudget.START, 6)
	var rising := true
	var bounded := true
	for world in [1, 2, 3]:
		for heft in range(1, 6):
			var cap := AttackBudget.cap_at(heft, world)
			bounded = bounded and cap <= AttackBudget.LATE and cap >= AttackBudget.START
			if heft > 1:
				rising = rising and cap >= AttackBudget.cap_at(heft - 1, world)
			if world > 1:
				rising = rising and cap >= AttackBudget.cap_at(heft, world - 1)
	_test.check("the cap never falls as the player grows", rising)
	_test.check("the cap stays between start and late", bounded)
	_test.eq("the late Highdraft reaches the late cap", AttackBudget.cap_at(LATE_HEFT, LATE_WORLD), AttackBudget.LATE)
	var rows: Array = []
	for world in [1, 2, 3]:
		var row: Array = []
		for heft in range(1, 6):
			row.append(AttackBudget.cap_at(heft, world))
		rows.append("world %d: %s" % [world, row])
	print("cap by heft class 1 to 5: " + "; ".join(rows))


# --- Structure -------------------------------------------------------------------------

func _structure() -> void:
	var counter_src := FileAccess.get_file_as_string("res://src/combat/counter.gd")
	_test.check("counter asks the budget before it warns", counter_src.contains("AttackBudget.ask(self)"))
	_test.check("counter releases its slot when the attack ends", counter_src.contains("AttackBudget.release(self)"))
	var chaser_src := FileAccess.get_file_as_string("res://src/combat/chaser.gd")
	_test.check("chaser asks and releases", chaser_src.contains("AttackBudget.ask(self)") and chaser_src.contains("AttackBudget.release(self)"))
	for path in ["res://src/combat/warden.gd", "res://src/core/boss_posture.gd"]:
		var src := FileAccess.get_file_as_string(path)
		_test.check("%s is exempt" % path.get_file(), not src.contains("AttackBudget") and not src.contains("counter.gd"),
			"names neither the budget nor counter.gd")


# --- Encounters ------------------------------------------------------------------------

func _boot() -> bool:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear()
	for node in [_game.presentation, _game.hud, _game.screens, _game.notes, _game.panel, _game.camera, _game.world,
			_game.build, _game.boss, _game.beacon, _game.run_log, _game.codex, _game.progress]:
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	Engine.physics_ticks_per_second = BASE_TICKS * SPEED
	Engine.max_physics_steps_per_frame = SPEED * 2
	Engine.time_scale = float(SPEED)
	await _frames(2)
	var ctx = _game.ctx
	_ball_at = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	var step := root.get_physics_process_delta_time()
	return _test.check("one physics step is 1/90 s", absf(step - 1.0 / float(BASE_TICKS)) < 0.000001, "step %.6f s" % step)


# Stage 6's director at the park table's highest tier: top time tier, spike on, hard run tier.
# A stand-in hive: what attack_budget.gd reads of a swarm-family Warden, at the ball.
func _hive() -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar kind := \"warden\"\nvar family := \"swarm\"\nfunc is_dead() -> bool:\n\treturn false\n"
	script.reload()
	var hive: Node3D = script.new()
	_game.ctx.root.add_child(hive)
	hive.global_position = _ball_at
	hive.add_to_group(AttackBudget.ANCHOR_GROUP)
	return hive


func _crowd_size() -> int:
	var row: Dictionary = Park.of(6)
	var d = Director.new(6)
	var source := row.duplicate(true)
	source["map"] = ""
	d.use_row(source, "", func(): return RunTier.HARD)
	d.threat = float(row.threat)
	d.stage_time = Director.TIER_SECONDS * (Director.MAX_TIME_TIERS + 1)
	d.spike = true
	return d.cap()


func _kinds(rng: RandomNumberGenerator, count: int, stage: int) -> Array:
	var row: Dictionary = Park.of(stage)
	var packs: Array = row.packs + [row.elite]
	var kinds: Array = []
	var pack_seq := 0
	while kinds.size() < count:
		for kind in packs[rng.randi_range(0, packs.size() - 1)].kinds:
			kinds.append([kind, pack_seq])
		pack_seq += 1
	return kinds.slice(0, count)


func _encounter(seed_value: int, count: int, budget: bool, heft: int, world: int, seconds: float, stage := 6) -> Dictionary:
	var ctx = _game.ctx
	var world_root: Node = ctx.root
	if budget:
		world_root.remove_meta(AttackBudget.OFF_META)
	else:
		world_root.set_meta(AttackBudget.OFF_META, true)
	_game.world.director.heft_class = heft
	_game.world.director.world = world
	ctx.spawner.fleet.holds.clear()
	_game.player.reset_to(_ball_at)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7100 + seed_value
	var units: Array = []
	for drawn in _kinds(rng, count, stage):
		var kind: String = drawn[0]
		var angle := rng.randf() * TAU
		var r := rng.randf_range(RING_MIN, RING_MAX)
		var at: Vector3 = _ball_at + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		var unit = ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 1.8))
		unit._set_health(99999.0)
		# As world.gd tags a director arrival: the pack it came with.
		unit.set_meta("pack_seq", int(drawn[1]))
		units.append(unit)
	var peak := 0
	var over := 0
	var cap_now := AttackBudget.cap_at(heft, world)
	var warned := {}
	var was := {}
	var latest := {}
	var min_gap := INF
	var joined := 0
	var waiting_since := {}
	var longest := 0.0
	var ticks := int(seconds * BASE_TICKS)
	for i in ticks:
		await physics_frame
		_game.player.reset_to(_ball_at)
		var live := 0
		for unit in units:
			if _attacking(unit):
				live += 1
		peak = maxi(peak, live)
		for unit in units:
			if not _budgeted(unit):
				continue
			var id: int = unit.get_instance_id()
			var now := _attacking(unit)
			if now and not bool(was.get(id, false)):
				warned[id] = int(warned.get(id, 0)) + 1
				var volley := [int(unit.get_meta("pack_seq")), String(unit.kind)]
				for other in latest:
					var since := float(i - int(latest[other])) / BASE_TICKS
					if other != volley:
						min_gap = minf(min_gap, since)
					elif since < AttackBudget.MIN_GAP:
						joined += 1
				latest[volley] = i
			was[id] = now
		if live > cap_now:
			over += 1
		for unit in get_nodes_in_group(AttackBudget.WAITING):
			var id: int = unit.get_instance_id()
			if not waiting_since.has(id):
				waiting_since[id] = i
		for id in waiting_since.keys():
			var node = instance_from_id(id)
			if node == null or not node.is_in_group(AttackBudget.WAITING):
				longest = maxf(longest, float(i - int(waiting_since[id])) / BASE_TICKS)
				waiting_since.erase(id)
	for id in waiting_since:
		longest = maxf(longest, float(ticks - int(waiting_since[id])) / BASE_TICKS)
	var attacks := 0
	for unit in units:
		if _budgeted(unit):
			attacks += int(warned.get(unit.get_instance_id(), 0))
	_clear()
	await _frames(2)
	return {"peak": peak, "over": over, "attacks": attacks, "longest_wait": longest, "min_gap": min_gap, "joined": joined}


# The units the budget covers: every counter and the chaser. The lobber's shells keep their
# own cadence and are not counted.
func _budgeted(unit) -> bool:
	return is_instance_valid(unit) and (unit is Counter or unit is Chaser)


# In WARN or LIVE, read from the unit's own phase: a counter out of roam, a chaser winding
# up or lunging.
func _attacking(unit) -> bool:
	if not _budgeted(unit):
		return false
	if unit is Counter:
		return unit.phase != Counter.Phase.ROAM
	return unit.state == Chaser.State.WINDUP or unit.state == Chaser.State.LUNGE


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _median(values: Array) -> int:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func _finish() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = BASE_TICKS
	if _game != null:
		_game.free()
	quit(_test.verdict())
