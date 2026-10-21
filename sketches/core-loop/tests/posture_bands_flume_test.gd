# smoke: bots timeout=1800s (fifteen park bot runs in child processes, eight at a time, about 135 s each alone)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const T := preload("res://tests/support/t.gd")

# The reactor band's flume column (design-v3/wardens/reactor.md section 7, card FLUME-POSTURE): the
# stage-2 park Warden, the meltdown relic on the flume mounting, hung 12 m over the drum floor and out
# of ram reach, so the fight is the harpoon line's bolts (warden_reactor.gd FlumePosture). The arms are
# tools/posture_sweep.gd's (small: skipper from mass 0; grown: skipper from 540; camper: shoots from
# range), each a tools/bot_run.gd child on --table=park entering stage 2 directly (--from-stage=2,
# --stages=2), seeds 0 to 4, the seed's own pilot. A fight is warden_broken_s less
# warden_engaged_s (engage to break); a run that never breaks counts as the CAP. Bands: grown median
# 25 to 45 s, small median at least twice grown's, the camper never breaks it; the live medians stay
# within 10 percent of the pins below.

const SEEDS := [0, 1, 2, 3, 4]
const ARMS := ["small", "grown", "camper"]
const CAP := 120.0
# The approach to the Warden takes about 90 s of stage time; this leaves the CAP after it.
const TICKS := 24000
const WALL_S := 1100.0
# 2026-10-16 (FLUME-POSTURE): first pin, on 6d7c7a0c plus FlumePosture (reference damage 17.83, reference
# heft 1.5, heft exponent the stage curve 2.0), measured with tools/bot_run.gd children of this shape:
# small [75.87 Sable, 62.41 Rivet, 120 Kest capped] median 75.9, grown [36.77, 27.37, 97.91] median 36.8,
# ratio 2.06, campers never broke. Kest's sticky charge lands too little damage per second to break it
# small inside the CAP. Earlier exponents on the same runs: 1.0 gave Sable small 109.9 / grown 65.4 and
# Rivet 78.6 / 41.2; 1.25 gave medians 69.8 / 43.4, ratio 1.61.
# 2026-10-16 (FLUME-POSTURE fix round, ruling FL3): re-pinned after the pay was normalized by the pilot's
# base weapon damage per second (every base kit fills the bar at Rivet's 7.07 per second at heft 1.5):
# small [64.85 Sable, 62.41 Rivet, 86.43 Kest] median 64.9, grown [26.27, 27.37, 45.94] median 27.4,
# ratio 2.37, campers never broke. Rivet's runs are unchanged from the first pin, as FL3 intends.
# 2026-10-16 (merge 16b44f36 into cand/alpha-w15): re-pinned on the candidate, which carries park data
# merges the card's base 6d7c7a0c lacked (KD1-DRESS, PARK-SEAT, DOMES-STOP, PARK-TILE). Two identical runs:
# small [71.63, 72.22, 97.91] median 72.2, grown [23.9, 25.57, 33.97] median 25.6, ratio 2.82, campers
# never broke. Every design band holds; only the pin moved.
# 2026-10-18 (Gate lane, stage/alpha-w17 bca19617 with the #126 flume pass): widened to seeds 0 to 4 and
# re-pinned from those five, per the coordinator's ruling on #126 (re-pin stage-wide from at least 5 seeds). One
# direct run: small [78.76, 76.32, 85.75, 63.0, 49.01] median 76.3, grown [25.83, 28.29, 28.36, 28.88, 19.39]
# median 28.3, ratio 2.70, campers never broke (pilots pylon_engineer, runner_gunner, demolitions_caster, tarn,
# tally). Every design band holds; the grown pin moved 25.6 -> 28.3 and the small pin 72.2 -> 76.3.
# 2026-10-20 (P4 hardpoint offsets, ruling 17 on #149 6274605849, Challenge verdict): re-pinned on
# claude/happy-mayer-rtqcu5-p4 c548c9e9, where the flume Warden's line bites the channel cheeks the
# landmark GLB draws (card 2 hp_1, hp_2) instead of the body offsets. One run of this test: small
# [55.53, 61.19, 59.99, 59.99, 52.02] median 60.0, grown [29.16, 26.28, 20.51, 26.47, 14.12] median 26.3,
# ratio 2.28, campers never broke. Small-arm reruns of both trees with records kept: the stage
# reproduced the old small fights exactly, every P4 run engages on the stage's tick (within 0.04 s) and
# still breaks the line through 3 or 4 chunks and hauls. The cheeks hold the line, so the small skipper
# re-bites less (pylon_engineer 31 to 18 bites, 70.9 to 47.7 s on the line) and the bar drains less;
# tarn and tally move under 4 s. The faster line is the card's intended change, not skipped content.
# Every design band holds; grown sits 1.3 s over its 25 s floor.
const EXPECT_SMALL_S := 60.0
const EXPECT_GROWN_S := 26.3
const TOLERANCE := 0.10


func _initialize() -> void:
	var t := T.new("posture_bands_flume_test")
	var folder := OS.get_user_data_dir().path_join("posture-bands-flume-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	for arm in ARMS:
		var row := PostureSweep.arm_named(arm)
		for run_seed in SEEDS:
			var args := ["--out=" + folder.path_join("%s-%d" % [arm, run_seed]), "--policy=" + String(row["policy"]),
				"--seeds=%d" % run_seed, "--table=park", "--from-stage=2", "--stages=2", "--ticks=%d" % TICKS,
				"--start-mass=%d" % int(row["mass"])]
			jobs.append({"script": "res://tools/bot_run.gd", "args": args})
	# Eight at a time: fifteen children at once overrun a 4-core box (LESSONS 39).
	var results := ChildRuns.run(jobs, WALL_S, 8)
	var fights := {}
	var broke := {}
	var pilots := {}
	for i in jobs.size():
		var arm: String = ARMS[i / SEEDS.size()]
		var run_seed: int = SEEDS[i % SEEDS.size()]
		var record := _record(folder.path_join("%s-%d" % [arm, run_seed]))
		var note := _stage_note(record, 2)
		t.check("%s seed %d ran and engaged the stage-2 Warden" % [arm, run_seed], results[i]["code"] == 0
				and not results[i]["timed_out"] and note.get("warden_engaged_s") != null,
			"exit %s, timed out %s, stage 2 note %s" % [results[i]["code"], results[i]["timed_out"], note])
		var engaged = note.get("warden_engaged_s")
		var broken = note.get("warden_broken_s")
		var fight := CAP
		if engaged != null and broken != null:
			fight = minf(CAP, float(broken) - float(engaged))
		if not fights.has(arm):
			fights[arm] = []
			broke[arm] = 0
			pilots[arm] = []
		fights[arm].append(fight)
		pilots[arm].append(String(record.get("class", "?")))
		if broken != null:
			broke[arm] += 1
	var small := PostureSweep.median(fights.get("small", [CAP]))
	var grown := PostureSweep.median(fights.get("grown", [CAP]))
	print("[report] medians small %.1f s, grown %.1f s, ratio %.2f; small %s, grown %s, camper %s; pilots %s" % [small, grown,
		small / grown if grown > 0.0 else 0.0, fights.get("small", []), fights.get("grown", []), fights.get("camper", []),
		pilots.get("small", [])])
	print("[report] small broke it in %d of %d runs, grown in %d" % [broke.get("small", 0), SEEDS.size(), broke.get("grown", 0)])
	t.check("grown breaks it in 25 to 45 s", grown >= 25.0 and grown <= 45.0, "grown median %.1f s" % grown)
	t.check("small takes at least twice grown's time", grown > 0.0 and small >= 2.0 * grown, "small %.1f s, grown %.1f s" % [small, grown])
	t.eq("the camper never breaks it", broke.get("camper", -1), 0)
	t.check("small median within 10 percent of the pin", absf(small - EXPECT_SMALL_S) <= TOLERANCE * EXPECT_SMALL_S,
		"small %.1f s, pin %.1f s" % [small, EXPECT_SMALL_S])
	t.check("grown median within 10 percent of the pin", absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.1f s, pin %.1f s" % [grown, EXPECT_GROWN_S])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)
	quit(t.verdict())


func _record(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	return record if record is Dictionary else {}


func _stage_note(record: Dictionary, stage: int) -> Dictionary:
	var found := {}
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == stage:
			found = note
	return found
