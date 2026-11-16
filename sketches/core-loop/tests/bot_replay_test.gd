extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")

# A seeded bot run replays: tree_bot_run's seed 0, launched twice at a fixed 90 fps, must give the same stage 1
# record (the tick the Warden broke at, the heft at exit, the parts). Until 15 Nov 2026 char_bot_test kept the
# wall clock and a clock-made run id, and one seed broke the Warden at 4050 to 6438 ticks across five launches
# of one commit; tree_bot_test passed or failed by which launch it got. Both children run at once, so this test's
# wall time is one child's, on any machine with two cores.
#
# Evidence limit: one seed of one runner. It shows this runner replays, not that every bot runner does.

const SEED := 0
const TIMEOUT_S := 110.0


func _initialize() -> void:
	var jobs := []
	for i in 2:
		jobs.append({"script": "res://tests/trees/tree_bot_run.gd", "args": ["--seed=%d" % SEED]})
	var results := ChildRuns.run(jobs, TIMEOUT_S, 2)
	var failures := 0
	var records := []
	for i in results.size():
		var s := ChildRuns.summary(results[i])
		var ok: bool = results[i]["code"] == 0 and String(s["verdict"]).ends_with(": PASS") and s["errors"].is_empty()
		if not ok:
			failures += 1
		var record := ""
		for line in s["checks"]:
			if line.begins_with("[stage 1 record]"):
				record = line
		records.append(record)
		for line in s["errors"]:
			print("  child: ", line)
		print("[seed %d launch %d] exit %d%s in %.0f s, %s -> %s" % [SEED, i + 1, results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", results[i]["seconds"], s["verdict"] if s["verdict"] != "" else "no verdict",
			"PASS" if ok else "FAIL"])
	var replays: bool = records[0] != "" and records[0] == records[1]
	if not replays:
		failures += 1
	print("[seed %d replays] first %s; again %s -> %s" % [SEED, records[0], records[1], "PASS" if replays else "FAIL"])
	print("bot_replay_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)
