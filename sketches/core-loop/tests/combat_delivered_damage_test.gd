extends SceneTree

const Game := preload("res://src/game.gd")

# 2026-10-04: retire with F6. The plating regression uses explicit test-only rows.
class PlatingGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld



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
# Also touches retirement counts, warden_slam_hits per stage, and an upgrade-tree proc volley's
# bolts tagging themselves item_proc instead of the player's own weapon fire.

var _game
var _combat
var _failures := 0
var _started := false
var _boss_hull_strikes := 0


func _initialize() -> void:
	_game = PlatingGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null or _started:
		return false
	_started = true
	_finish()
	return false


# The boss case waits one physics frame (a posture contact must land after the frame
# its stagger opened), so the checks run as a coroutine and the verdict follows them.
func _finish() -> void:
	await _run_all()
	var ok := _failures == 0
	print("combat_delivered_damage_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)


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

	_report("slam_source_by_kind", _combat._classify_source("slam", "") == "drop_or_slam"
			and _combat._classify_source("stomp", "") == "ram_or_contact",
		"_classify_source read '%s' for slam and '%s' for stomp (needs drop_or_slam, then ram_or_contact)"
			% [_combat._classify_source("slam", ""), _combat._classify_source("stomp", "")])

	# F6 2026-10-04: a posture Warden takes health only through a shatter, so the plating-era
	# slam-damage checks on it (slam_is_a_hit, drop_or_slam_source, warden_target_class,
	# slam_hits_counted, warden_slam_hits) are gone; the zero-hit break below stays.

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

	# The Warden's break (beacon_unsealed) snapshots the slam-hit count for the stage. Read before entering the boss arena below: stage_content_cleared
	# (which entering the arena emits) starts a fresh attempt and would zero them first.
	ctx.events.beacon_unsealed.emit(1)
	# A break with no hit on the Warden reads a real 0.
	ctx.events.beacon_unsealed.emit(2)
	var slam_hits_2: Dictionary = _combat.delivered_damage()["warden_slam_hits"]
	_report("warden_slam_hits_zero", int(slam_hits_2.get("2", -1)) == 0,
		"stage 2 broke with no hit on the Warden: warden_slam_hits %s (needs 0)" % [slam_hits_2])

	# Boss. Repointed 2026-10-04 (F2a fix round): Brindle's health is four posture
	# chunks, hp reads the chunks left, and guns never remove one. Guns stagger the
	# hull, a smash a frame later shatters one chunk, and the ledger's boss bucket must
	# rise by exactly that one, which is what boss.gd itself reports losing.
	# The field's real HP lost is read before the arena: the boss case awaits a frame,
	# and the arena entry frees the stage's enemies at that frame's end.
	var field_lost := 0.0
	for e in [enemy_a, warden, adds, lobber, vault]:
		var id: int = e.get_instance_id()
		# enemy.gd's own take_damage() subtracts past 0 rather than clamping (hp -=
		# amount, unlike the removed value it returns), so a dead target's hp can read
		# negative; the real HP it had to lose bottoms out at 0, same as removed did.
		var after: float = maxf(0.0, e.hp) if is_instance_valid(e) else 0.0
		field_lost += float(hp_before[id]) - after
	_game.flow.enter_boss(Vector3.ZERO)
	var boss = ctx.boss
	var hull = boss.ship.hull
	var boss_hp_before: float = boss.hp
	var boss_bucket_before: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	var shots := 0
	while not boss.staggered() and shots < 200:
		_combat.strike(hull, "arc", 5000.0, "", "weapon")
		shots += 1
	var guns_took: float = boss_hp_before - boss.hp
	var opened_on: int = Engine.get_physics_frames()
	while Engine.get_physics_frames() == opened_on:
		await physics_frame
	ctx.player.smash_landing = hull
	_combat.strike(hull, "ram", 150.0)
	ctx.player.smash_landing = null
	_boss_hull_strikes = shots + 1
	var boss_hp_after: float = boss.hp
	var real_boss_loss: float = boss_hp_before - boss_hp_after
	var boss_bucket_after: float = float(_combat.delivered_damage()["by_target_class"].get("boss", 0.0))
	_report("boss_chunk_lost", guns_took == 0.0 and real_boss_loss == 1.0 and boss.chunks_left() == 3,
		"%d shots staggered the hull and took %.1f hp; a smash in the opening took %.1f (needs one chunk), %d chunks left"
			% [shots, guns_took, real_boss_loss, boss.chunks_left()])
	_report("boss_target_class", absf(boss_bucket_after - boss_bucket_before - 1.0) < 0.05,
		"one chunk lost dropped the boss %.1f hp; by_target_class.boss rose by %.1f (needs 1)"
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
	# the other way: the scooter is a kinematic AnimatableBody3D, and since BRINDLE-HULL it
	# no longer has sync_to_physics, so the ball goes to it).
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
	real_total_lost += field_lost
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
	# adds, lobber,
	# vault, the boss hull's gun shots and its smash, the scooter catch; the two
	# scenery/proc-only calls above never reach take_damage() and are not in this count).
	var calls := 5 + _boss_hull_strikes
	_report("hit_count", int(ledger["hits"]) == calls,
		"%d strike() calls above produced %d ledger hits (needs %d, one per call, none doubled)" % [calls, int(ledger["hits"]), calls])
