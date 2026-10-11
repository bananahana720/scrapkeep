# smoke: solo timeout=360s (nine bot runs on stage 3 in child processes at once, each cut at FIGHT_CAP_S; a loaded machine slows them)
extends "res://tools/bot_run.gd"

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")

# KF3 (wardens/swarm.md section 7): the swarm band on its first stage, stage 3's headframe hive,
# with the hoist live. tools/bot_run.gd plays the alpha table from stage 3 to the stage's end
# (--from-stage=3 --until=3), one process per arm and seed; this file is both the parent and
# the child. A child (--swarm-hoist=1) is bot_run with one addition: once the stage's Warden
# stands it opts in as a harpoon anchor and takes the swarm driver (src/combat/warden_swarm.gd),
# as a park Warden does (warden.gd "The per-kind hook"), and writes hoist.json beside its record
# with the highest offset the hive reached, so a run whose hoist never moved fails here.
# The arms are tools/posture_sweep.gd's: small and grown are the skipper at 0 and 540 start
# mass, the camper only shoots from range. A fight's seconds are the stage clock at the break
# less the bot's turn to the Warden; a run is cut TURN_S past FIGHT_CAP_S of stage time (--ticks) and a
# fight that has not broken by FIGHT_CAP_S counts at the cap, posture_bands_test's 150 s.
# The band (the common contract): grown median 25 to 45 s, small median at least twice grown,
# the camper never breaks it; the medians are pinned below with the 10 percent tolerance.

const SEEDS := {0: "pylon_engineer", 1: "runner_gunner", 2: "demolitions_caster"}
const ARM_ROWS := {"small": {"policy": "skipper", "mass": 0}, "grown": {"policy": "skipper", "mass": 540},
	"camper": {"policy": "camper", "mass": 0}}
const STAGE := 3
const GROWN_BAND_S := Vector2(25.0, 45.0)
const SMALL_FACTOR := 2.0
const HOIST_TOP := 29.0
const FIGHT_CAP_S := 150.0
const TURN_S := 30.0
const DRIVER_PATH := "res://src/combat/warden_swarm.gd"
# 2026-10-11 (w13 KF3 kf3-swarm, base 28fe659 plus warden_swarm.gd): measured with the hoist live, three
# runs: grown 141.71 s of [148.01, 137.38, 141.71]; small 150 s, all three past the 150 s cap (uncapped
# 240+, 168.52, 208.05); the camper never breaks it. With the hive standing (no driver, the red run,
# uncapped) the same arms measured small 50.10 s and grown 32.95 s. The hive is out of ram reach 8 s in
# every 12 and posture drains after 3 s without gain (boss_posture.gd), so the skipper's posture leaks
# away each high dwell: grown sits outside 25 to 45 s and small/grown is 1.06 under the cap, under 2.
# Those two band checks stay red for the coordinator's ruling; the pins hold the measured fight.
const EXPECT_SMALL_S := 150.0
const EXPECT_GROWN_S := 141.71
const TOLERANCE := 0.10

var _child := false
var _hoisted = null
var _hoist_top := 0.0


func _initialize() -> void:
	if _parse(OS.get_cmdline_user_args()).get("swarm-hoist", "") == "1":
		_child = true
		super._initialize()
		return
	var t := T.new("posture_bands_swarm_test")
	var folder := OS.get_user_data_dir().path_join("posture-bands-swarm-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	var names := []
	for arm in ARM_ROWS:
		for run_seed in SEEDS:
			var out := folder.path_join("%s-%d" % [arm, run_seed])
			var args := ["--swarm-hoist=1", "--out=" + out, "--policy=" + String(ARM_ROWS[arm]["policy"]), "--seeds=%d" % run_seed,
				"--pilot=" + String(SEEDS[run_seed]), "--table=alpha", "--from-stage=%d" % STAGE, "--until=%d" % STAGE,
				"--ticks=%d" % roundi((FIGHT_CAP_S + TURN_S) * Engine.physics_ticks_per_second)]
			if int(ARM_ROWS[arm]["mass"]) > 0:
				args.append("--start-mass=%d" % int(ARM_ROWS[arm]["mass"]))
			jobs.append({"script": "res://tests/posture_bands_swarm_test.gd", "args": args})
			names.append([arm, run_seed, out])
	t.check("the sweep has runs", not jobs.is_empty(), "%d jobs" % jobs.size())
	var results := ChildRuns.run(jobs, 900.0)
	var fights := {}
	for i in results.size():
		var arm: String = names[i][0]
		var run_seed: int = names[i][1]
		var out: String = names[i][2]
		t.check("%s seed %d ran" % [arm, run_seed], results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
		var record := _record(out)
		t.eq("%s seed %d plays %s" % [arm, run_seed, SEEDS[run_seed]], record.get("class", ""), SEEDS[run_seed])
		var hoist = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("hoist.json"))) if FileAccess.file_exists(out.path_join("hoist.json")) else null
		var top: float = float(hoist.get("top", 0.0)) if hoist is Dictionary else 0.0
		t.check("%s seed %d fought the live hoist" % [arm, run_seed], hoist is Dictionary and hoist.get("driver", "") == DRIVER_PATH
				and top >= HOIST_TOP, "hoist %s" % [hoist])
		if not fights.has(arm):
			fights[arm] = []
		fights[arm].append(_fight(record))
	var grown: float = _median(fights.get("grown", []))
	var small: float = _median(fights.get("small", []))
	var camper_broke: int = fights.get("camper", []).filter(func(s): return s < FIGHT_CAP_S).size()
	print("swarm band stage %d: small %.2f s of %s, grown %.2f s of %s, camper %s" % [STAGE, small, fights.get("small", []),
		grown, fights.get("grown", []), fights.get("camper", [])])
	t.check("grown breaks the hive in 25 to 45 s", grown >= GROWN_BAND_S.x and grown <= GROWN_BAND_S.y, "grown median %.2f s" % grown)
	t.check("small takes at least twice grown's time", grown > 0.0 and small >= SMALL_FACTOR * grown, "small %.2f s, grown %.2f s" % [small, grown])
	t.eq("the camper never breaks it", camper_broke, 0)
	t.check("small median within 10 percent of the pin", EXPECT_SMALL_S > 0.0 and absf(small - EXPECT_SMALL_S) <= TOLERANCE * EXPECT_SMALL_S,
		"small %.2f s, pin %.2f s" % [small, EXPECT_SMALL_S])
	t.check("grown median within 10 percent of the pin", EXPECT_GROWN_S > 0.0 and absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.2f s, pin %.2f s" % [grown, EXPECT_GROWN_S])
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


# The child: bot_run, plus the hoist on the stage's Warden.
func _physics_process(delta: float) -> bool:
	if not _child:
		return false
	_hoist_live()
	return super._physics_process(delta)


func _hoist_live() -> void:
	if _game == null or _game.flow == null or _game.run.stage != STAGE:
		return
	var warden = _game.flow.get("warden")
	if not is_instance_valid(warden) or warden.get("family") != "swarm":
		return
	if warden != _hoisted:
		if not ResourceLoader.exists(DRIVER_PATH):
			return
		warden.set_harpoon_anchor(true)
		warden.set_mount_driver(load(DRIVER_PATH).new())
		_hoisted = warden
		_write_hoist()
	var top: float = warden.global_position.y - warden.home.y
	if top > _hoist_top + 1.0:
		_hoist_top = top
		_write_hoist()


func _write_hoist() -> void:
	var file := FileAccess.open(_out.path_join("hoist.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"driver": DRIVER_PATH, "top": _hoist_top}))


func _record(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	return record if record is Dictionary else {}


func _fight(record: Dictionary) -> float:
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == STAGE and note.get("warden_broken_s") != null:
			return minf(FIGHT_CAP_S, float(note["warden_broken_s"]) - float(note.get("warden_fight_s", 0.0)))
	return FIGHT_CAP_S


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2]) if not sorted.is_empty() else -1.0


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
