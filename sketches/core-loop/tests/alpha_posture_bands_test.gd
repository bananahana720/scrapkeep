# smoke: bots timeout=1200s (four bot runs in child processes at once, 30000 ticks each; a loaded machine slows them: 128 s alone, over 180 s beside a gate on 2026-10-08, one child 366.9 s wall and the parent killed at the 360 s solo ceiling on 2026-10-15; moved to the bot tier with run_tier_test, RT-CAP)
# F6 2026-10-04: no row picks a fight; posture is the only rule.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")

# The alpha table's two zone Wardens, one row each (tools/posture_sweep.md, "Alpha Wardens"). The
# alpha rows are played by tools/bot_run.gd on --table=alpha, one process per seed and policy, from
# the run's start: the skipper goes straight to each Warden, the completionist does each stage's
# activities first. A fight's seconds are the stage clock at the break less the bot's turn to the
# Warden (warden_fight_s). The bots.ndjson stage notes carry both. Seeds 1 to 3, 30000 ticks (enough
# to clear stage 2 for both policies: the two-hook completionist breaks seed 2's Reach Warden at about
# 26700); the window is the sweep's three-seed median, widened.
# Two seeds in the gate since 2026-10-04 (wave 10): three ran 160-170 s per child under gate load against the
# 180 s per-test cap; the nightly bot matrix carries the breadth (decisions.tsv, wave 9 row d).
# Each seed names its pilot through --pilot, because the bot's own seed mapping (seed % roster size)
# moves when the roster grows; each run's record must show that pilot played. This test samples two
# pilots on purpose, so it has no roster-cover check: the cannon, Tally, Tarn and Sable are measured
# on worlds 2 and 3 by tests/alpha_posture_bands_w23_test.gd, not here.
const PILOTS := {"runner_gunner": 1, "demolitions_caster": 2}
const ALPHA_TICKS := 30000
# GP3 2026-10-08 re-recorded with the pressure rows (alpha_defs.gd PRESSURE) under the default
# Breath (hard). Bigger, sooner packs did not lengthen the fights: the measured medians are
# Spillway 59.0 s of [56.99, 58.98] and Reach 44.7 s of [44.29, 44.68] (before: Spillway 63.9 to
# 79.7, Reach 42.0 to 46.0). The floors rise to about 10 s under them, narrowing each band toward
# its upper half; the ceilings stay. Pushing the medians themselves up is the tuning sweep's job.
# GP3F 2026-10-08: the default Breath now plays the rows as written (no hard multiplier on top); the
# medians are Spillway 61.8 s of [61.81, 50.82] and Reach 46.7 s of [40.25, 46.67]. Bands unchanged.
# KF0 2026-10-10 (unit KF0 Reconciliation): one Warden kind per world (PARK.md section 7), so the
# Reach Warden is now the reactor relic's meltdown variant, not the swarm remnant, and world 1's packs
# lost the deflector's rebound pack (decisions.tsv). Re-measured on this file's runs: Spillway skipper
# 63.5 s of [52.02, 63.52], Reach skipper 54.5 s of [54.46, 51.67], Reach completionist 32.6 s of
# [28.72, 32.57]. The w23 test, whose Warden band derives from REACH_SKIPPER_S, measured stage 3 (now
# the swarm remnant) 53.5 s and stage 5 (the Mind's hand, no choir) 93.6 s, two of six pilots past
# 125 s. All inside their windows, so the bands stay: they are fixed, not fit to results.
# 2026-10-17 (SQ2, PR #15): floor 50 -> 45 s. With the attacker budget fewer adds attack at once, so
# the skipper breaks the Spillway Warden in 45.2 and 48.5 s (main cf63e622: 51.1 and 55.2 s). Andrew's
# posture-family ruling "Stage-page timing, Andrew tapped 15:34:22Z 17 Oct (~45-70 s first stagger)";
# the ceiling stays.
const SPILLWAY_SKIPPER_S := Vector2(45.0, 90.0)
const REACH_SKIPPER_S := Vector2(35.0, 80.0)
# The Reach completionist's median fight is at most this many times the skipper's.
const REACH_COMPLETIONIST_FACTOR := 1.25


func _initialize() -> void:
	var t := T.new("alpha_posture_bands_test")
	var folder := OS.get_user_data_dir().path_join("alpha-posture-bands-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	for policy in ["skipper", "completionist"]:
		for pilot in PILOTS:
			jobs.append({"script": "res://tools/bot_run.gd", "args": ["--out=" + folder.path_join("alpha-%s-%s" % [policy, pilot]),
				"--policy=" + policy, "--seeds=%d" % PILOTS[pilot], "--pilot=" + pilot, "--ticks=%d" % ALPHA_TICKS,
				"--table=alpha"]})
	var results := ChildRuns.run(jobs, 900.0)
	_alpha(t, folder, results)
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


func _record(folder: String, policy: String, pilot: String) -> Dictionary:
	var path := folder.path_join("alpha-%s-%s" % [policy, pilot]).path_join("bots.ndjson")
	var line := FileAccess.get_file_as_string(path).split("\n", false)
	var record = JSON.parse_string(line[0]) if not line.is_empty() else null
	return record if record is Dictionary else {}


# One fight's seconds per stage and pilot: the break less the bot's turn to the Warden.
func _fights(folder: String, policy: String, stage: int) -> Array:
	var out := []
	for pilot in PILOTS:
		var fight := -1.0
		for note in _record(folder, policy, pilot).get("stages", []):
			if int(note.get("stage", 0)) == stage and note.get("warden_broken_s") != null:
				fight = float(note["warden_broken_s"]) - float(note.get("warden_fight_s", 0.0))
		out.append(fight)
	return out


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1.0


# The alpha Wardens' rows: the skipper's median fight inside each Warden's window, and the Reach
# completionist no slower than the skipper by more than a stated factor.
func _alpha(t, folder: String, results: Array) -> void:
	for i in range(results.size()):
		t.check("alpha bot run %d ran" % i, results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
	for policy in ["skipper", "completionist"]:
		for pilot in PILOTS:
			t.eq("%s %s plays %s" % [policy, pilot, pilot], _record(folder, policy, pilot).get("class", ""), pilot)
	var spillway := _fights(folder, "skipper", 1)
	var reach := _fights(folder, "skipper", 2)
	var reach_full := _fights(folder, "completionist", 2)
	t.check("every alpha fight broke its Warden", not spillway.has(-1.0) and not reach.has(-1.0) and not reach_full.has(-1.0),
		"spillway %s, reach %s, reach completionist %s" % [spillway, reach, reach_full])
	var posture_rows := AlphaDefs.DEFS.all(func(row): return not row.has("warden_fight"))
	t.check("both alpha Wardens are posture rows", posture_rows, "alpha rows")
	var spillway_median := _median(spillway)
	var reach_median := _median(reach)
	var full_median := _median(reach_full)
	t.check("Spillway skipper breaks it in %d to %d s" % [SPILLWAY_SKIPPER_S.x, SPILLWAY_SKIPPER_S.y],
		spillway_median >= SPILLWAY_SKIPPER_S.x and spillway_median <= SPILLWAY_SKIPPER_S.y, "median %.1f s of %s" % [spillway_median, spillway])
	t.check("Reach skipper breaks it in %d to %d s" % [REACH_SKIPPER_S.x, REACH_SKIPPER_S.y],
		reach_median >= REACH_SKIPPER_S.x and reach_median <= REACH_SKIPPER_S.y, "median %.1f s of %s" % [reach_median, reach])
	t.check("Reach completionist is no slower than %.2f times the skipper" % REACH_COMPLETIONIST_FACTOR,
		reach_median > 0.0 and full_median > 0.0 and full_median <= REACH_COMPLETIONIST_FACTOR * reach_median,
		"completionist median %.1f s of %s, skipper %.1f s" % [full_median, reach_full, reach_median])


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
