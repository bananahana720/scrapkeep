extends SceneTree

const Game := preload("res://src/game.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")

# M0: the delivered-damage baseline and provenance (design-v3/STRATEGY-SPINE.md §7 row
# M0, §8 row 1). Every assertion reads combat's own ledger (delivered_damage(), mirrored
# onto ctx.run's meta for run_log), never a re-derivation, so a pass here is a pass on
# the real accounting path strike() -> enemy.take_damage() -> the ledger.
#
# Proves:
# 1. the ledger total equals the real HP lost, summed directly off every struck target
#    (a chaser, the Warden, a Fleet add, a vault and Brindle's hull), not a re-derivation;
# 2. overkill is clamped, on an ordinary kill and on a boss hit that would pass a
#    phase floor (boss.gd clamps to the floor, not to 0);
# 3. a vault (the one static, non-combatant damageable in the game) is counted under its
#    own "cache" class, not "enemy"; a plain non-damageable node is still excluded,
#    silently, not double-counted;
# 4. a zero-damage run is reported as zero (delivered_damage present, total 0.0), not
#    missing, the instant a run starts and before any hit;
# 5. per-source and per-action attribution reconcile (they sum to the same total);
# 6. range buckets (near/mid/far) are assigned from distance to the ball.
# Also touches retirement counts, drops_to_break, and an upgrade-tree proc volley's
# bolts tagging themselves item_proc instead of the player's own weapon fire.

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
	# A real, hittable non-combatant (finding 3, fix round 1): vault.gd's own header
	# says it never moves and never attacks, unlike the plain Node3D the scenery check
	# below uses, which strike() already rejected before this unit even existed.
	var vault: Node3D = ctx.spawner.spawn_enemy("vault", Vector3(6.0, 0.0, 0.0))
	for e in [enemy_a, warden, adds, lobber, vault]:
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

	# 1 (finding 4, fix round 1): the actual HP lost, read off each target directly
	# (never through the ledger being tested), for the independent reconciliation at
	# the end of this run. Keyed by instance id: enemy_a dies, so its node may not
	# survive to be read again the ordinary way.
	var hp_before := {}
	for e in [enemy_a, warden, adds, lobber, vault]:
		hp_before[e.get_instance_id()] = e.hp

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

	# finding 5, fix round 1: resolve()'s own "drop" key (the drop-mode writer's
	# warden_drop.gd tags a landing this way on proto/core-loop-v3-lab) must win over
	# the kind guess, so a stomp-kind drop lands as drop_or_slam too, not
	# ram_or_contact. The key does not exist on this base yet (only warden_drop.gd
	# sets it), so this is a direct unit check on _classify_source rather than a full
	# strike(), which cannot produce a "drop" result here.
	_report("stomp_drop_flag_wins", _combat._classify_source("stomp", "", true) == "drop_or_slam"
			and _combat._classify_source("stomp", "", false) == "ram_or_contact",
		"_classify_source('stomp', '', drop) read '%s' with drop=true and '%s' with drop=false (needs drop_or_slam, then ram_or_contact)"
			% [_combat._classify_source("stomp", "", true), _combat._classify_source("stomp", "", false)])

	# drop_or_slam, auto-classified from kind "slam" alone (no explicit source), on the
	# Warden target class; three partial hits feed drops_to_break. review finding 2, fix
	# round 2: drops_to_break is loop_mode "drop"'s own measure, so the base's default
	# "v2" mode must not count these; the mode-gated part is proven right after.
	var hp_w: float = warden.max_hp
	_report("v2_mode_not_drop_counted", not LoopMode.is_drop(ctx.tuning),
		"the base's default loop_mode read '%s' (needs anything but 'drop', so the count below proves the gate, not a coincidence)"
			% [LoopMode.mode(ctx.tuning)])
	_combat.strike(warden, "slam", hp_w * 0.1)
	_report("v2_mode_slam_not_counted", _combat._warden_drop_hits == 0,
		"a slam hit on the Warden outside loop_mode 'drop' bumped _warden_drop_hits to %d (needs 0, unmeasured)"
			% [_combat._warden_drop_hits])
	ctx.tuning.set_option("loop_mode", "drop")
	_combat.strike(warden, "slam", hp_w * 0.1)
	_combat.strike(warden, "slam", hp_w * 0.1)
	# review finding 2, fix round 2: a ball dropping onto the Warden tags "stomp"
	# (player_ball.gd's STOMP), not "slam"; it must count as a drop hit too.
	_combat.strike(warden, "stomp", hp_w * 0.1)
	_report("drop_or_slam_source", float(_combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0)) >= hp_w * 0.2 - 0.01,
		"two slam hits on the Warden (in loop_mode drop) landed %.1f under by_source.drop_or_slam (needs >= %.1f)"
			% [float(_combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0)), hp_w * 0.2])
	_report("warden_target_class", float(_combat.delivered_damage()["by_target_class"].get("Warden", 0.0)) >= hp_w * 0.4 - 0.01,
		"the Warden's own bucket read %.1f (needs >= %.1f)" % [float(_combat.delivered_damage()["by_target_class"].get("Warden", 0.0)), hp_w * 0.4])
	_report("drop_hits_count_stomp_and_slam", _combat._warden_drop_hits == 3,
		"one v2-mode slam (uncounted) plus two drop-mode slams and one drop-mode stomp left _warden_drop_hits at %d (needs 3)"
			% [_combat._warden_drop_hits])

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
	# strike() rejected this case before M0 existed; it is regression coverage for the
	# guard, not evidence about caches or vaults (finding 3, fix round 1's own point).
	var scenery := Node3D.new()
	var before_scenery: Dictionary = _combat.delivered_damage().duplicate(true)
	_combat.strike(scenery, "arc", 999.0)
	_report("scenery_excluded", int(_combat.delivered_damage()["hits"]) == int(before_scenery["hits"])
			and absf(float(_combat.delivered_damage()["total"]) - float(before_scenery["total"])) < 0.001,
		"a strike() call on a plain node (no take_damage) left hits at %d and total at %.1f unchanged"
			% [int(_combat.delivered_damage()["hits"]), float(_combat.delivered_damage()["total"])])
	scenery.free()

	# 3. The real case: a vault, the one static non-combatant that does reach strike()
	# (finding 3, fix round 1). It must be counted, just not under "enemy".
	var hp_v: float = vault.max_hp
	var enemy_before_vault: float = float(_combat.delivered_damage()["by_target_class"].get("enemy", 0.0))
	_combat.strike(vault, "arc", hp_v * 0.4, "", "weapon")
	_report("cache_target_class", float(_combat.delivered_damage()["by_target_class"].get("cache", 0.0)) >= hp_v * 0.4 - 0.01,
		"a vault hit landed %.1f under by_target_class.cache (needs >= %.1f)"
			% [float(_combat.delivered_damage()["by_target_class"].get("cache", 0.0)), hp_v * 0.4])
	_report("cache_excluded_from_enemy", float(_combat.delivered_damage()["by_target_class"].get("enemy", 0.0)) == enemy_before_vault,
		"the vault hit left by_target_class.enemy at %.1f, unchanged from %.1f (a static cache is not an 'enemy')"
			% [float(_combat.delivered_damage()["by_target_class"].get("enemy", 0.0)), enemy_before_vault])

	# 1 (finding 1, fix round 1): an upgrade-tree proc volley tags its bolts item_proc,
	# not the hardcoded "weapon" _fire() used to write into every bolt regardless of
	# who fired it. Read the fired bolt directly; a collision is a separate concern
	# (combat_pattern_test.gd already covers bolts reaching their target).
	var weapon: String = _combat.active_weapon()
	var bolts_before: int = _combat.bolts.fired
	_combat._fire(weapon, "item_proc")
	var fired_bolts: Array = _combat.bolts._bolts
	_report("proc_volley_source", _combat.bolts.fired > bolts_before and fired_bolts.size() > 0
			and String(fired_bolts[-1].get("source", "")) == "item_proc",
		"an upgrade-tree-sourced _fire() call tagged its bolt '%s' (needs 'item_proc', not the old hardcoded 'weapon')"
			% [String(fired_bolts[-1].get("source", "")) if fired_bolts.size() > 0 else "<no bolt>"])

	# drops_to_break: two drop-mode slam hits and one drop-mode stomp hit landed on the
	# Warden this stage attempt (the earlier v2-mode slam above is excluded by design);
	# the Warden's own break (beacon_unsealed) must snapshot that count for the stage,
	# still in loop_mode "drop" (still set from above). Read before entering the boss
	# arena below: stage_content_cleared (which entering the arena emits) starts a fresh
	# attempt and would zero this count first.
	ctx.events.beacon_unsealed.emit(1)
	var drops: Dictionary = _combat.delivered_damage()["drops_to_break"]
	_report("drops_to_break", int(drops.get("1", -1)) == 3,
		"stage 1's drops_to_break read %s after two drop-mode slams, one drop-mode stomp and its break (needs 3)" % [drops])
	# The gate itself: a beacon break outside loop_mode "drop" must not read 0 (a
	# measurement that never ran), it must read null (explicitly unmeasured).
	ctx.tuning.set_option("loop_mode", "v2")
	ctx.events.beacon_unsealed.emit(2)
	var drops_v2: Dictionary = _combat.delivered_damage()["drops_to_break"]
	_report("drops_to_break_null_outside_drop_mode", drops_v2.get("2", "missing") == null,
		"stage 2's drops_to_break broke in loop_mode 'v2' and read %s (needs null, not 0 or missing)" % [drops_v2])

	# Boss (finding 4, fix round 1): boss.gd clamps to a phase floor instead of to 0,
	# and that path was never exercised. Enter the arena, strike the hull once inside
	# the phase-1 floor headroom, then again hard enough to hit the floor, and check
	# the ledger's own boss bucket against what boss.gd itself reports losing.
	_game.flow.enter_boss(Vector3.ZERO)
	var boss = ctx.boss
	var hull = boss.ship.hull
	var boss_hp_before: float = boss.hp
	var boss_bucket_before: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	_combat.strike(hull, "arc", 5000.0, "", "weapon")
	_combat.strike(hull, "arc", boss.max_hp * 5.0, "", "weapon")
	var boss_hp_after: float = boss.hp
	var real_boss_loss: float = boss_hp_before - boss_hp_after
	var boss_bucket_after: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	_report("boss_floor_clamped", boss_hp_after > 0.0 and boss_hp_after < boss_hp_before,
		"the second hull hit was sized to blow past the phase-1 floor; boss.hp landed at %.1f (needs clamped above 0, below %.1f)"
			% [boss_hp_after, boss_hp_before])
	_report("boss_target_class", absf(boss_bucket_after - boss_bucket_before - real_boss_loss) < 0.05,
		"two hull hits (the second past the phase-1 floor) dropped the boss %.1f hp; by_target_class.boss rose by %.1f (need equal)"
			% [real_boss_loss, boss_bucket_after - boss_bucket_before])

	# review finding 1, fix round 2: the scooter catch removes the rest of the boss's HP
	# pool through boss.gd's own _defeat() (an enemy_struck listener that runs before
	# take_damage() and sets hp = 0.0 outside its accounting, and boss.take_damage()
	# itself returns 0 in EJECT since state != FIGHT), so strike()'s own return-value
	# path used to miss the whole remaining pool and never retire the boss. jump_to_phase
	# (boss.gd's own dev hook, also how the round-2 review reproduced this) goes straight
	# to EJECT without simulating the full 75 s fight; the scooter still starts mid-air,
	# so it is marked landed and the ball is put on it directly, the same way
	# boss_flow_test.gd's own scooter case does (Harness.put_ball to the scooter, never
	# the other way: the scooter is an AnimatableBody3D with sync_to_physics, so setting
	# its own global_position from script does not take effect before a physics tick).
	boss.jump_to_phase(4)
	boss._eject["landed"] = true
	ctx.player.reset_to(boss.scooter.global_position)
	ctx.player.body().global_position = boss.scooter.global_position
	var boss_hp_before_catch: float = boss.hp
	var boss_bucket_before_catch: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	var boss_retirements_before: int = int(_combat.delivered_damage()["retirements"].get("boss", 0))
	_combat.strike(boss.scooter, "ram", 50.0)
	var boss_bucket_after_catch: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	_report("boss_defeat_ledger", boss.state_name() == "defeated" and boss.hp == 0.0 and boss_hp_before_catch > 0.0
			and absf(boss_bucket_after_catch - boss_bucket_before_catch - boss_hp_before_catch) < 0.05,
		"the scooter catch dropped boss.hp %.1f -> %.1f (state %s); by_target_class.boss rose by %.1f (needs the whole remaining pool, %.1f, not 0)"
			% [boss_hp_before_catch, boss.hp, boss.state_name(), boss_bucket_after_catch - boss_bucket_before_catch, boss_hp_before_catch])
	_report("boss_retirement", int(_combat.delivered_damage()["retirements"].get("boss", 0)) == boss_retirements_before + 1,
		"the boss's defeat retired %d under retirements.boss (needs %d, one more than before the catch)"
			% [int(_combat.delivered_damage()["retirements"].get("boss", 0)), boss_retirements_before + 1])

	# 1 (finding 4, fix round 1): sum the real HP lost over every struck target this run
	# (partial and overkill hits alike, enemies, the vault and the boss) and compare it
	# with the ledger's own total, independent of the by_* buckets below. The scooter
	# catch's own loss (finding 1, fix round 2) folds in here too.
	var real_total_lost := real_boss_loss + boss_hp_before_catch
	for e in [enemy_a, warden, adds, lobber, vault]:
		var id: int = e.get_instance_id()
		# enemy.gd's own take_damage() subtracts past 0 rather than clamping (hp -=
		# amount, unlike the removed value it returns), so a dead target's hp can read
		# negative; the real HP it had to lose bottoms out at 0, same as removed did.
		var after: float = maxf(0.0, e.hp) if is_instance_valid(e) else 0.0
		real_total_lost += float(hp_before[id]) - after
	_report("total_matches_real_hp_lost", absf(float(_combat.delivered_damage()["total"]) - real_total_lost) < 0.5,
		"ledger total %.2f vs the sum of real HP lost across every struck target %.2f (need equal)"
			% [float(_combat.delivered_damage()["total"]), real_total_lost])

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

	# No double counting: exactly the strike() calls made above, once each (chaser,
	# 4x warden [1 v2-mode slam, 2 drop-mode slam, 1 drop-mode stomp], adds, lobber,
	# vault, 2x boss hull, the scooter catch; the two scenery/proc-only calls above
	# never reach take_damage() and are not in this count).
	_report("hit_count", int(ledger["hits"]) == 11,
		"11 strike() calls above produced %d ledger hits (needs 11, one per call, none doubled)" % [int(ledger["hits"])])
