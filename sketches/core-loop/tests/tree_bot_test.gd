# smoke: solo timeout=300s (seven bot children at a fixed 90 fps, one fewer at once than the machine has cores)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")

# Every class's bot still clears stage 1 with a random upgrade branch: char_bot_test's
# skipper run for seeds 0 to 5 (Sable, Rivet, Kest, Tarn, Tally, the remembered cannon), with
# the bot taking one of the offered picks at class select, when stage 1 clears and, if the class rises inside stage 1, at that rise. The six run
# in child processes at a fixed 90 fps, so the ticks are the real game's. At most one fewer than
# the machine's cores run at once (3 on a 4 vCPU box, all 6 on the PC): six at once on 4 vCPU took
# 106 to 122 s a child against the 110 s child cap (w33 gate, main and stage alike).
#
# Evidence limit: one seeded branch per class through stage 1 and the later pick
# offers; tree_play_test plays all 16 builds per class. Nothing here measures feel.

const SEEDS := [0, 1, 2, 3, 4, 5]
const TIMEOUT_S := 110.0


func _initialize() -> void:
	var jobs := []
	for seed_number in SEEDS:
		jobs.append({"script": "res://tests/trees/tree_bot_run.gd", "args": ["--seed=%d" % seed_number]})
	# The first seed runs a second time: a seeded bot run must replay tick for tick.
	jobs.append({"script": "res://tests/trees/tree_bot_run.gd", "args": ["--seed=%d" % SEEDS[0]]})
	var results := ChildRuns.run(jobs, TIMEOUT_S, _parallel())
	var failures := 0
	var first := _record(results[0])
	var again := _record(results[SEEDS.size()])
	var replays := first != "" and first == again
	if not replays:
		failures += 1
	print("[seed %d replays] first %s; again %s -> %s" % [SEEDS[0], first, again, "PASS" if replays else "FAIL"])
	for i in SEEDS.size():
		var s := ChildRuns.summary(results[i])
		var ok: bool = results[i]["code"] == 0 and String(s["verdict"]).ends_with(": PASS") and s["errors"].is_empty()
		if not ok:
			failures += 1
		for line in s["checks"]:
			if line.begins_with("[stage 1 cleared]") or line.begins_with("[stage 1 record]") or line.begins_with("[tree picks]"):
				print("  ", line)
		for line in s["errors"]:
			print("  child: ", line)
		print("[seed %d random branch] exit %d%s in %.0f s, %s -> %s" % [SEEDS[i], results[i]["code"],
			" (timed out)" if results[i]["timed_out"] else "", results[i]["seconds"], s["verdict"] if s["verdict"] != "" else "no verdict",
			"PASS" if ok else "FAIL"])
	print("tree_bot_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


# The child's stage 1 record line: the tick the Warden broke at, the heft at exit and the parts.
static func _record(result: Dictionary) -> String:
	for line in ChildRuns.summary(result)["checks"]:
		if line.begins_with("[stage 1 record]"):
			return line
	return ""


# One core stays free for the parent and the box; a child at a fixed fps gets slower, not wrong, when
# it shares a core, so the cap is about time.
static func _parallel() -> int:
	return clampi(OS.get_processor_count() - 1, 1, SEEDS.size() + 1)
