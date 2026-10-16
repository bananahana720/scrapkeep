# smoke: solo timeout=300s (20 seeded crowd encounters run twice, 6 s uncapped and 14 s capped; about 180 s wall)
extends SceneTree

# SQ2 attacker budget (W13-INTEGRATION-3.md SQ2). 20 seeded encounters at the park table's
# highest tier: stage 6's packs and elite, as many units as that stage's director allows at
# the top time tier with the spike on the hard run tier, dropped around a ball held on one
# spot. Each encounter runs twice:
# - uncapped (the world root's cap set past the crowd): the peak count of units in WARN or
#   LIVE at once, the measure KE9's report did not take. It justifies the cap: some seed
#   must pass it, or the budget would never bind. The whole crowd is ready inside its
#   first rest, so the peak lands in the first seconds;
# - capped (AttackBudget.CAP): the same count never passes the cap on any tick of any seed,
#   and the line moves: no unit waits longer than WAIT_LIMIT for a slot, finished or not.
# The count is read from each unit's own phase, not from the budget's groups.
# The Warden and its posture fight are exempt: neither is a counter, and neither names the
# budget.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Counter := preload("res://src/combat/counter.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const T := preload("res://tests/support/t.gd")

const SEEDS := 20
const UNCAPPED_SECONDS := 6.0
const SECONDS := 14.0
# A crowd of 24 sharing 4 slots, each attack about 2 s of warning and live, turns over in
# about 12 s; a unit waiting past that has been skipped.
const WAIT_LIMIT := 12.0
const SPEED := 4
const BASE_TICKS := 90
const RING_MIN := 8.0
const RING_MAX := 16.0
const UNCAPPED := 999

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
	if not await _boot():
		_finish()
		return
	var crowd := _crowd_size()
	_test.check("crowd fills the top tier's cap", crowd >= AttackBudget.CAP * 2, "%d units at stage 6, hard run tier, top tier" % crowd)
	var uncapped_peaks: Array = []
	var capped_peaks: Array = []
	var violations := 0
	var waits: Array = []
	for seed_value in SEEDS:
		var open: Dictionary = await _encounter(seed_value, crowd, UNCAPPED, UNCAPPED_SECONDS)
		uncapped_peaks.append(open.peak)
		var shut: Dictionary = await _encounter(seed_value, crowd, -1, SECONDS)
		capped_peaks.append(shut.peak)
		violations += shut.over
		waits.append(shut.longest_wait)
		print("seed %d: uncapped peak %d, capped peak %d, ticks over cap %d, longest wait %.2f s, attacks %d uncapped / %d capped"
			% [seed_value, open.peak, shut.peak, shut.over, shut.longest_wait, open.attacks, shut.attacks])
	_test.check("uncapped peak passes the cap on some seed", uncapped_peaks.max() > AttackBudget.CAP,
		"uncapped peaks %s, cap %d" % [uncapped_peaks, AttackBudget.CAP])
	_test.eq("ticks over the cap, all seeds", violations, 0)
	_test.check("capped peak reaches the cap", capped_peaks.max() == AttackBudget.CAP, "capped peaks %s" % [capped_peaks])
	_test.check("no unit waits past the limit", waits.max() <= WAIT_LIMIT, "longest waits %s, limit %.1f s" % [waits, WAIT_LIMIT])
	print("uncapped peak: min %d, median %d, max %d of %d units; longest wait max %.2f s"
		% [uncapped_peaks.min(), _median(uncapped_peaks), uncapped_peaks.max(), crowd, waits.max()])
	_finish()


# --- Structure -------------------------------------------------------------------------

func _structure() -> void:
	var counter_src := FileAccess.get_file_as_string("res://src/combat/counter.gd")
	_test.check("counter asks the budget before it warns", counter_src.contains("AttackBudget.ask(self)"))
	_test.check("counter releases its slot when the attack ends", counter_src.contains("AttackBudget.release(self)"))
	for path in ["res://src/combat/warden.gd", "res://src/combat/boss_posture.gd"]:
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


func _kinds(rng: RandomNumberGenerator, count: int) -> Array:
	var row: Dictionary = Park.of(6)
	var packs: Array = row.packs + [row.elite]
	var kinds: Array = []
	while kinds.size() < count:
		kinds.append_array(packs[rng.randi_range(0, packs.size() - 1)].kinds)
	return kinds.slice(0, count)


func _encounter(seed_value: int, count: int, cap: int, seconds: float) -> Dictionary:
	var ctx = _game.ctx
	var world_root: Node = ctx.root
	if cap > 0:
		world_root.set_meta(AttackBudget.CAP_META, cap)
	else:
		world_root.remove_meta(AttackBudget.CAP_META)
	ctx.spawner.fleet.holds.clear()
	_game.player.reset_to(_ball_at)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7100 + seed_value
	var units: Array = []
	for kind in _kinds(rng, count):
		var angle := rng.randf() * TAU
		var r := rng.randf_range(RING_MIN, RING_MAX)
		var at: Vector3 = _ball_at + Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		var unit = ctx.spawner.spawn_enemy(kind, ctx.terrain.drop_point(at.x, at.z, 1.8))
		unit._set_health(99999.0)
		units.append(unit)
	var peak := 0
	var over := 0
	var cap_now := AttackBudget.CAP if cap <= 0 else cap
	var waiting_since := {}
	var longest := 0.0
	var ticks := int(seconds * BASE_TICKS)
	for i in ticks:
		await physics_frame
		_game.player.reset_to(_ball_at)
		var live := 0
		for unit in units:
			if not is_instance_valid(unit) or not unit is Counter:
				continue
			if unit.phase != Counter.Phase.ROAM:
				live += 1
		peak = maxi(peak, live)
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
		if is_instance_valid(unit) and unit is Counter:
			attacks += unit.warned
	_clear()
	await _frames(2)
	return {"peak": peak, "over": over, "attacks": attacks, "longest_wait": longest}


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
