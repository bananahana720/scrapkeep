# smoke: bots timeout=1200s (twelve bot runs in child processes at once, each through its world's boss; 195 s alone on 2026-10-12, 546 s at main and 640 s at w17 on a 4-core cloud box at load 7 to 20 on 2026-10-18, same ticks and the same per-child wall, so the 300 s solo cap no longer fits; moved to the bot tier with alpha_posture_bands_test)
# 2026-10-12, W13 smoke triage: 195.469 s alone; 1.5x rounded up to 10 s is 300 s, inside the 360 s ordinary cap.
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const Stage2 := preload("res://tests/alpha_posture_bands_test.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const ClassDef := preload("res://src/core/class_def.gd")

# World 2 (Dig, stages 3 and 4) and world 3 (Highdraft, stages 5 and 6) Wardens and bosses, played
# by the skipper on tools/bot_run.gd --table=alpha (tools/posture_sweep.md, "World 2 and 3 Wardens
# and bosses"). One process per seed and world: --from-stage=3 --until=4 ends as the world 2 boss's
# victory enters stage 5; --from-stage=5 runs to the end of the run. A fight's seconds are the stage
# clock at the break less the bot's turn to the Warden, as in the stage-2 test; a boss is its
# defeated_s on the driver's boss clock (stepped sim time). The bands are fixed, not fit to results:
# each Warden's median falls within 0.7 x to 1.6 x the stage-2 skipper window, and each boss's
# median is under BOSS_CAP_S. A Warden that never breaks counts at the driver's stall limit, a boss
# never beaten at the cap. Medians are the upper median of six, one run per pilot.
# The bot's own seed mapping (seed % roster size) moves when the roster grows, so each seed names
# its pilot through --pilot and each run's record must show that pilot played. Seeds 1 to 4 keep
# the pilots of the 2026-10-04 eight-seed table (Rivet, Kest, Tarn, Sable), so those rows compare
# directly; Tally and the cannon take seeds 5 and 6. The pins cover the whole roster, so a new
# pilot without a band seed fails here. The doc carries all eight seeds from a tools run
# (tools/posture_sweep.md, "World 2 and 3 bands, pilots named, 2026-10-05 (wave 16)").
const PILOTS := {"runner_gunner": 1, "demolitions_caster": 2, "tarn": 3, "pylon_engineer": 4, "tally": 5, "remembered_cannon": 6}
const WORLDS := {2: {"from": 3, "stages": [3, 4]}, 3: {"from": 5, "stages": [5, 6]}}
const WARDEN_BAND_S := Vector2(0.7 * Stage2.REACH_SKIPPER_S.x, 1.6 * Stage2.REACH_SKIPPER_S.y)
const WARDEN_CAP_S := BotDriver.STAGE_LIMIT
const BOSS_CAP_S := 240.0


func _initialize() -> void:
	var t := T.new("alpha_posture_bands_w23_test")
	var folder := OS.get_user_data_dir().path_join("alpha-posture-bands-w23-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	for world in WORLDS:
		for pilot in PILOTS:
			var args := ["--out=" + folder.path_join("w%d-%s" % [world, pilot]), "--policy=skipper",
				"--seeds=%d" % PILOTS[pilot], "--pilot=" + pilot, "--table=alpha",
				"--from-stage=%d" % WORLDS[world]["from"]]
			if world == 2:
				args.append("--until=4")
			jobs.append({"script": "res://tools/bot_run.gd", "args": args})
	var results := ChildRuns.run(jobs, 900.0)
	_bands(t, folder, results)
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


func _record(folder: String, world: int, pilot: String) -> Dictionary:
	var path := folder.path_join("w%d-%s" % [world, pilot]).path_join("bots.ndjson")
	var line := FileAccess.get_file_as_string(path).split("\n", false)
	var record = JSON.parse_string(line[0]) if not line.is_empty() else null
	return record if record is Dictionary else {}


# One fight's seconds per pilot: the break less the bot's turn to the Warden, or the cap.
func _fights(folder: String, world: int, stage: int) -> Array:
	var out := []
	for pilot in PILOTS:
		var fight := WARDEN_CAP_S
		for note in _record(folder, world, pilot).get("stages", []):
			if int(note.get("stage", 0)) == stage and note.get("warden_broken_s") != null:
				fight = float(note["warden_broken_s"]) - float(note.get("warden_fight_s", 0.0))
		out.append(fight)
	return out


func _bosses(folder: String, world: int) -> Array:
	var out := []
	for pilot in PILOTS:
		var boss = _record(folder, world, pilot).get("boss")
		var defeated = boss.get("defeated_s") if boss is Dictionary else null
		out.append(float(defeated) if defeated != null else BOSS_CAP_S)
	return out


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1.0


func _bands(t, folder: String, results: Array) -> void:
	for i in range(results.size()):
		t.check("world bot run %d ran" % i, results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
	for world in WORLDS:
		for pilot in PILOTS:
			t.eq("w%d %s plays %s" % [world, pilot, pilot], _record(folder, world, pilot).get("class", ""), pilot)
	var pinned: Array = PILOTS.keys()
	pinned.sort()
	var roster := []
	for row in ClassDef.all():
		roster.append(row.id)
	roster.sort()
	t.eq("the pins cover the roster", pinned, roster)
	for world in WORLDS:
		for stage in WORLDS[world]["stages"]:
			var fights := _fights(folder, world, stage)
			var median := _median(fights)
			print("stage %d Warden median %.2f s of %s" % [stage, median, fights])
			t.check("stage %d skipper breaks its Warden in %.0f to %.0f s" % [stage, WARDEN_BAND_S.x, WARDEN_BAND_S.y],
				median >= WARDEN_BAND_S.x and median <= WARDEN_BAND_S.y, "median %.2f s of %s" % [median, fights])
		var bosses := _bosses(folder, world)
		var boss_median := _median(bosses)
		print("world %d boss median %.2f s of %s" % [world, boss_median, bosses])
		t.check("world %d boss falls in under %.0f s" % [world, BOSS_CAP_S], boss_median < BOSS_CAP_S,
			"median %.2f s of %s" % [boss_median, bosses])


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
