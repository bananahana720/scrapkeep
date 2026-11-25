# smoke: solo timeout=300s (six bot children at a fixed 90 fps, one fewer at once than the machine has cores)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const Game := preload("res://src/game.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# Every class's bot still clears stage 1 with a random upgrade branch: char_bot_test's
# skipper run for seeds 0 to 5 (Sable, Rivet, Kest, Tarn, Tally, the remembered cannon), with
# the bot taking one of the offered picks at class select, when stage 1 clears and, if the class rises inside stage 1, at that rise. The six run
# in child processes at a fixed 90 fps, so the ticks are the real game's. At most one fewer than
# the machine's cores run at once (3 on a 4 vCPU box, all 6 on the PC): six at once on 4 vCPU took
# 106 to 122 s a child against the 110 s child cap (w33 gate, main and stage alike).
# Also verifies World-1 (world_one_builds=on) Depth-1 opposite-feel keystone pairs and Depth-2
# moved perks across all six pilots with zero script errors.
#
# Evidence limit: one seeded branch per class through stage 1 and the later pick
# offers, plus both Depth-1 opposite-feel arms per pilot under world_one_builds=on;
# tree_play_test plays all 16 builds per class. Nothing here measures feel.

const SEEDS := [0, 1, 2, 3, 4, 5]
const TIMEOUT_S := 110.0
const WORLD_ONE_PAIRS := {
	"pylon_engineer": ["s_static_flutter", "s_rail_lance"],
	"runner_gunner": ["r_fan_hammer", "r_big_iron"],
	"demolitions_caster": ["k_cluster", "k_keg"],
	"tarn": ["t_saw_flurry", "t_guillotine"],
	"tally": ["tl_petty_cash", "tl_compound_interest"],
	"remembered_cannon": ["c_snap_battery", "c_siege_rail"],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := await _check_world_one_pairs()
	var jobs := []
	for seed_number in SEEDS:
		jobs.append({"script": "res://tests/trees/tree_bot_run.gd", "args": ["--seed=%d" % seed_number]})
	var results := ChildRuns.run(jobs, TIMEOUT_S, _parallel())
	for i in results.size():
		var s := ChildRuns.summary(results[i])
		var ok: bool = results[i]["code"] == 0 and String(s["verdict"]).ends_with(": PASS") and s["errors"].is_empty()
		if not ok:
			failures += 1
		for line in s["checks"]:
			if line.begins_with("[stage 1 cleared]") or line.begins_with("[tree picks]"):
				print("  ", line)
		for line in s["errors"]:
			print("  child: ", line)
		print("[seed %d random branch] exit %d%s in %.0f s, %s -> %s" % [SEEDS[i], results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", results[i]["seconds"], s["verdict"] if s["verdict"] != "" else "no verdict",
			"PASS" if ok else "FAIL"])
	print("tree_bot_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _check_world_one_pairs() -> int:
	SimClock.ticks = true
	var failures := 0
	for pilot in WORLD_ONE_PAIRS:
		var seen_d1 := {}
		var seen_d2 := {}
		for sd in [1, 2]:
			var game = Game.new()
			game.test_mode = true
			root.add_child(game)
			while game.flow == null:
				await physics_frame
			game.tuning.set_option("world_one_builds", "on")
			game.run.run_seed_override = sd
			var drv := BotDriver.new(game, "skipper", sd)
			drv.class_index = BotDriver.class_index_for(sd, pilot)
			drv.start()
			for _i in 20:
				drv.tick(1.0 / 90.0)
				await physics_frame
			var tree = game.player.tree
			var d1_ok: bool = tree.world_one and not tree.pending() and drv.tree_picks.size() == 1 \
				and tree.picks == drv.tree_picks and drv.tree_picks[0] in WORLD_ONE_PAIRS[pilot]
			if d1_ok:
				seen_d1[drv.tree_picks[0]] = true
			# Simulate workshop checkpoint after Stage 1 -> Depth-2 moved perk offer.
			tree.open_checkpoint()
			drv.tick(1.0 / 90.0)
			await physics_frame
			var d2_ok: bool = not tree.pending() and drv.tree_picks.size() == 2 \
				and tree.picks == drv.tree_picks \
				and UpgradeTree.path_to(pilot, drv.tree_picks[1], true) == drv.tree_picks
			if d2_ok:
				seen_d2[drv.tree_picks[1]] = true
			if not d1_ok or not d2_ok:
				failures += 1
				print("[world_one %s seed %d] FAIL: pending=%s picks=%s tree=%s" % [pilot, sd, tree.pending(), drv.tree_picks, tree.picks])
			game.free()
		var pair: Array = WORLD_ONE_PAIRS[pilot]
		var pair_ok: bool = seen_d1.has(pair[0]) and seen_d1.has(pair[1]) and seen_d2.size() >= 1
		if not pair_ok:
			failures += 1
		print("[world_one %s depth-1 pair] d1=%s d2=%s -> %s" % [pilot, seen_d1.keys(), seen_d2.keys(), "PASS" if pair_ok else "FAIL"])
	return failures


# One core stays free for the parent and the box; a child at a fixed fps gets slower, not wrong, when
# it shares a core, so the cap is about time.
static func _parallel() -> int:
	return clampi(OS.get_processor_count() - 1, 1, SEEDS.size())
