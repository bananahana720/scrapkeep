extends SceneTree

const Game := preload("res://src/game.gd")

# M0: the delivered-damage baseline and provenance (design-v3/STRATEGY-SPINE.md §7 row
# M0, §8 row 1). Every assertion reads combat's own ledger (delivered_damage(), mirrored
# onto ctx.run's meta for run_log), never a re-derivation, so a pass here is a pass on
# the real accounting path strike() -> enemy.take_damage() -> the ledger.
#
# Proves:
# 1. the ledger total equals the total HP lost by enemies, bosses and adds;
# 2. overkill is clamped;
# 3. scenery (a node without take_damage) is excluded, silently, not double-counted;
# 4. a zero-damage run is reported as zero (delivered_damage present, total 0.0), not
#    missing, the instant a run starts and before any hit;
# 5. per-source and per-action attribution reconcile (they sum to the same total);
# 6. range buckets (near/mid/far) are assigned from distance to the ball.
# Also touches retirement counts and drops_to_break, which the ledger carries too.

var _game
var _combat
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_run_all()
	var ok := _failures == 0
	print("combat_delivered_damage_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _sum(map: Dictionary) -> float:
	var total := 0.0
	for key in map:
		total += float(map[key])
	return total


func _run_all() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_combat = ctx.spawner

	# 4. A zero-damage run: run_started alone (no hit yet) must already carry the reset
	# ledger, present and at zero, not an absent key.
	var fresh: Dictionary = _game.run.get_meta("delivered_damage", {})
	_report("zero_damage_run", fresh.has("total") and float(fresh["total"]) == 0.0 and int(fresh.get("hits", -1)) == 0,
		"a run with no hits yet carries delivered_damage %s (needs total 0.0, hits 0, present)" % [fresh])

	_game.flow.enter_stage(1, Vector3.ZERO, false)
	_game.player.reset_to(Vector3.ZERO)
	_game.player.body().global_position = Vector3.ZERO

	# Three targets at controlled distances from the ball (at the origin): near, mid, far.
	var enemy_a: Node3D = ctx.spawner.spawn_enemy("chaser", Vector3(3.0, 0.0, 0.0))
	var warden: Node3D = ctx.spawner.spawn_enemy("warden", Vector3(10.0, 0.0, 0.0))
	var adds: Node3D = ctx.spawner.spawn_enemy("mag_trapper", Vector3(20.0, 0.0, 0.0))
	var lobber: Node3D = ctx.spawner.spawn_enemy("lobber", Vector3(3.0, 0.0, 0.0))
	for e in [enemy_a, warden, adds, lobber]:
		e.plating = 0.0
	# The Warden and the vault sit on the ground under `at` (spawn_enemy's own contract),
	# which can lift them off the flat plane this test assumes; pin the exact 3D spot the
	# range bucket is checked against.
	warden.global_position = Vector3(10.0, 0.0, 0.0)

	# 6. Range buckets, read directly off the three placements above.
	_report("range_buckets", _combat._range_bucket(enemy_a) == "near" and _combat._range_bucket(warden) == "mid"
			and _combat._range_bucket(adds) == "far",
		"chaser at 3 m -> %s, warden at 10 m -> %s, adds at 20 m -> %s (need near, mid, far)"
			% [_combat._range_bucket(enemy_a), _combat._range_bucket(warden), _combat._range_bucket(adds)])

	var before: Dictionary = _combat.delivered_damage().duplicate(true)

	# 1 + 2. Overkill: a hit far past a chaser's hp. removed must clamp to exactly its hp
	# (the real HP lost), even though the hit's own "dealt" was ten times that.
	var hp_a: float = enemy_a.max_hp
	_combat.strike(enemy_a, "arc", hp_a * 10.0, "", "weapon")
	var total_after_a: float = float(_combat.delivered_damage()["total"])
	_report("overkill_clamped", enemy_a.is_dead() and absf(total_after_a - float(before["total"]) - hp_a) < 0.01,
		"a %.0f-hp chaser hit for %.0fx its hp: ledger total rose by %.2f (needs exactly %.0f, the real hp lost)"
			% [hp_a, 10.0, total_after_a - float(before["total"]), hp_a])
	_report("overkill_recorded", float(_combat.delivered_damage()["overkill"]) > 0.0,
		"overkill %.1f recorded on the killing blow (needs > 0)" % [float(_combat.delivered_damage()["overkill"])])
	_report("weapon_source", float(_combat.delivered_damage()["by_source"].get("weapon", 0.0)) >= hp_a - 0.01,
		"an explicit weapon-sourced hit landed %.1f under by_source.weapon (needs >= %.0f)"
			% [float(_combat.delivered_damage()["by_source"].get("weapon", 0.0)), hp_a])
	_report("enemy_target_class", float(_combat.delivered_damage()["by_target_class"].get("enemy", 0.0)) >= hp_a - 0.01,
		"a chaser (target class 'enemy') accounted for %.1f under by_target_class.enemy (needs >= %.0f)"
			% [float(_combat.delivered_damage()["by_target_class"].get("enemy", 0.0)), hp_a])

	# drop_or_slam, auto-classified from kind "slam" alone (no explicit source), on the
	# Warden target class; three partial hits feed drops_to_break.
	var hp_w: float = warden.max_hp
	_combat.strike(warden, "slam", hp_w * 0.1)
	_combat.strike(warden, "slam", hp_w * 0.1)
	_combat.strike(warden, "slam", hp_w * 0.1)
	_report("drop_or_slam_source", float(_combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0)) >= hp_w * 0.3 - 0.01,
		"three slam hits on the Warden landed %.1f under by_source.drop_or_slam (needs >= %.1f)"
			% [float(_combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0)), hp_w * 0.3])
	_report("warden_target_class", float(_combat.delivered_damage()["by_target_class"].get("Warden", 0.0)) >= hp_w * 0.3 - 0.01,
		"the Warden's own bucket read %.1f (needs >= %.1f)" % [float(_combat.delivered_damage()["by_target_class"].get("Warden", 0.0)), hp_w * 0.3])

	# item_proc, auto-classified from kind "synergy", on a Fleet reinforcement ("adds").
	var hp_adds: float = adds.max_hp
	_combat.strike(adds, "synergy", hp_adds * 0.3)
	_report("item_proc_source", float(_combat.delivered_damage()["by_source"].get("item_proc", 0.0)) >= hp_adds * 0.3 - 0.01,
		"a synergy hit on a Fleet unit landed %.1f under by_source.item_proc (needs >= %.1f)"
			% [float(_combat.delivered_damage()["by_source"].get("item_proc", 0.0)), hp_adds * 0.3])
	_report("adds_target_class", float(_combat.delivered_damage()["by_target_class"].get("adds", 0.0)) >= hp_adds * 0.3 - 0.01,
		"a Fleet unit's own bucket read %.1f (needs >= %.1f)"
			% [float(_combat.delivered_damage()["by_target_class"].get("adds", 0.0)), hp_adds * 0.3])

	# A genuine zero-damage hit (force 0, plating 0): reported as zero, not skipped.
	var hits_before_zero: int = int(_combat.delivered_damage()["hits"])
	var zero_before: int = int(_combat.delivered_damage()["zero_damage_hits"])
	_combat.strike(lobber, "pin", 0.0)
	_report("zero_damage_hit", int(_combat.delivered_damage()["hits"]) == hits_before_zero + 1
			and int(_combat.delivered_damage()["zero_damage_hits"]) == zero_before + 1,
		"a force-0 hit counted as a hit (%d -> %d) and as a zero-damage hit (%d -> %d)"
			% [hits_before_zero, int(_combat.delivered_damage()["hits"]), zero_before, int(_combat.delivered_damage()["zero_damage_hits"])])

	# 3. Scenery: a plain node with no take_damage never reaches the ledger, silently.
	var scenery := Node3D.new()
	var before_scenery: Dictionary = _combat.delivered_damage().duplicate(true)
	_combat.strike(scenery, "arc", 999.0)
	_report("scenery_excluded", int(_combat.delivered_damage()["hits"]) == int(before_scenery["hits"])
			and absf(float(_combat.delivered_damage()["total"]) - float(before_scenery["total"])) < 0.001,
		"a strike() call on a plain node (no take_damage) left hits at %d and total at %.1f unchanged"
			% [int(_combat.delivered_damage()["hits"]), float(_combat.delivered_damage()["total"])])
	scenery.free()

	# 5. Reconciliation: no hit counts twice and none go unattributed.
	var ledger: Dictionary = _combat.delivered_damage()
	var total: float = float(ledger["total"])
	var source_sum := _sum(ledger["by_source"])
	var action_sum := _sum(ledger["by_action"])
	var target_sum := _sum(ledger["by_target_class"])
	var range_sum := _sum(ledger["by_range"])
	_report("reconciles", absf(source_sum - total) < 0.05 and absf(action_sum - total) < 0.05
			and absf(target_sum - total) < 0.05 and absf(range_sum - total) < 0.05,
		"total %.2f vs by_source %.2f, by_action %.2f, by_target_class %.2f, by_range %.2f (all must match)"
			% [total, source_sum, action_sum, target_sum, range_sum])

	# Retirement counts: the chaser's death retired one "enemy".
	_report("retirements", int(ledger["retirements"].get("enemy", 0)) == 1,
		"one chaser killed retired %d under retirements.enemy (needs 1)" % [int(ledger["retirements"].get("enemy", 0))])

	# drops_to_break: three drop_or_slam hits landed on the Warden this stage attempt;
	# the Warden's own break (beacon_unsealed) must snapshot that count for the stage.
	ctx.events.beacon_unsealed.emit(1)
	var drops: Dictionary = _combat.delivered_damage()["drops_to_break"]
	_report("drops_to_break", int(drops.get("1", -1)) == 3,
		"stage 1's drops_to_break read %s after three slam hits on the Warden and its break (needs 3)" % [drops])

	# No double counting: exactly the strike() calls made above, once each.
	_report("hit_count", int(ledger["hits"]) == 6,
		"6 strike() calls above produced %d ledger hits (needs 6, one per call, none doubled)" % [int(ledger["hits"])])
