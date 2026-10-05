extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")

# Every class's bot still clears stage 1 with a random upgrade branch: char_bot_test's
# skipper run for seeds 0 to 5 (Sable, Rivet, Kest, Tarn, Tally, the remembered cannon), with
# the bot taking one of the two offered picks at class select and again when stage 1 clears. The six run in
# parallel child processes at a fixed 90 fps, so the ticks are the real game's.
#
# Evidence limit: one seeded branch per class through stage 1 and the second pick's
# offer; tree_play_test plays all 16 builds per class. Nothing here measures feel.

const SEEDS := [0, 1, 2, 3, 4, 5]
const TIMEOUT_S := 110.0


func _initialize() -> void:
	var jobs := []
	for seed_number in SEEDS:
		jobs.append({"script": "res://tests/trees/tree_bot_run.gd", "args": ["--seed=%d" % seed_number]})
	var results := ChildRuns.run(jobs, TIMEOUT_S)
	var failures := 0
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
		print("[seed %d random branch] exit %d%s, %s -> %s" % [SEEDS[i], results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", s["verdict"] if s["verdict"] != "" else "no verdict",
			"PASS" if ok else "FAIL"])
	print("tree_bot_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
