# smoke: bots timeout=1800s (48 bot runs on stage 3, small and grown, in child processes, as many at once as memory and cores allow, each cut at RUN_CAP_S)
# 2026-10-23: 24 seeds per arm took 1322 s alone on a 4-core, 15 GB cloud sandbox (8 at once), under the 1800 s bot ceiling; with the camper's 8 it took 2070 s, so the camper moved to posture_bands_swarm_camper_test.
# 1800 s is the bot ceiling, so the margin is 1.31x, not the usual 1.5x; a slower box needs fewer seeds a run, not a higher cap.
# 2026-10-18: with the parallel cap (8 at once on a 4-core, 16 GB cloud sandbox) the sweep took 1096 s alone; 1.5x is 1644 s; the gate box, loaded, ran past 1208 s, so it takes the bot ceiling, 1800 s.
# 2026-10-12, W13 smoke triage: completed in 510.708 s alone with its fixed bands still red; 1.5x rounded up to 10 s is 770 s, beyond the ordinary 360 s cap.
# 2026-10-13 WT-BANDS: paired record gain 100 -> 150; measured small 104.78 -> 104.78 s, grown 46.40 -> 38.77 s.
# Re-pinned small 164.03 -> 104.78 s and grown 118.32 -> 38.77 s from five agreeing sweeps.
# Small medians [105.90, 104.78, 104.78, 104.78, 104.78]; grown [38.77, 38.77, 38.77, 38.77, 38.77].
# All five pass the live band, twice-grown and mechanism contracts; only the old pins failed during calibration.
# Load start/end [23.00/43.76, 43.76/31.66, 31.66/30.69, 30.69/33.08, 33.08/29.26]. Bands and arms unchanged.
# The KF-BOT measurements below are historical; the current WT-BANDS measurements are above.
extends "res://tools/bot_run.gd"

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const PlatformPin := preload("res://tests/support/platform_pin.gd")

# KF3 (wardens/swarm.md section 7): the swarm band on its first stage, stage 3's headframe hive,
# with the hoist live. tools/bot_run.gd plays the alpha table from stage 3 to the stage's end
# (--from-stage=3 --until=3), one process per arm and seed; this file is both the parent and
# the child. A child (--swarm-hoist=1) is bot_run with one addition: once the stage's Warden
# stands it opts in as a harpoon anchor and takes the swarm driver (src/combat/warden_swarm.gd),
# as a park Warden does (warden.gd "The per-kind hook"), and writes hoist.json beside its record
# with the highest offset the hive reached, so a run whose hoist never moved fails here.
# hoist.json also lists the hive's height (the driver's height) on each tick a stagger opens.
# The arms are tools/posture_sweep.gd's: small and grown are the skipper at 0 and 540 start
# mass, the camper only shoots from range. Small and grown run SEED_COUNT seeds each, the camper
# CAMPER_SEEDS (swarm.md section 7 asked for eight per arm; eight seeds left the small/grown ratio
# chaotic across commits, 23 Oct), the pilot seed % 3 as the sweep plays it. A fight's seconds are
# the stage clock at the break less the bot's turn to the Warden; a run is cut TURN_S past
# RUN_CAP_S of stage time (--ticks), and a fight that has not broken by RUN_CAP_S counts at RUN_CAP_S.
# The cap sits above the measured fights, so the medians and the pins compare real fight lengths, not the cap.
# The band (the common contract): grown median 25 to 45 s, small median at least twice grown,
# the camper never breaks it (posture_bands_swarm_camper_test). swarm.md section 7's mechanism check rides with it: at least half
# the grown seeds land a stagger during a low dwell (the hive under LOW_DWELL_M). Its second check,
# one finish from a latch, is on since the bot's latch arm (KF-BOT, 2026-10-11; tools/bot_driver.gd
# _anchor_fight): at least one grown seed takes a chunk with a haul from a line on a hardpoint inside a
# stagger (the stage note's latch_chunks).
# The ordinary pilot's first stagger (the small arm's median, from its turn to the Warden) falls in
# FIRST_STAGGER_BAND_S: the measured 24-seed median 50.32 s, plus or minus 10 s. It replaces the hive's
# 60 to 85 s window of the "Per Warden" ruling (DECISIONS, 17 Oct 22:32) under option 1 of the swarm
# hive card, 23 Oct ("ordinary pilots stay at about 75 s"; DECISIONS.md section 5).

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster"]
const SEED_COUNT := 24
const CAMPER_SEEDS := 8
const ARM_ROWS := {"small": {"policy": "skipper", "mass": 0}, "grown": {"policy": "skipper", "mass": 540},
	"camper": {"policy": "camper", "mass": 0}}
const STAGE := 3
const GROWN_BAND_S := Vector2(25.0, 45.0)
# 2026-11-17 (ruling eb, Mac gate; tests/support/platform_pin.gd): the measured first-stagger median has a Mac value
# beside the Linux 50.32 s, with the same plus or minus 10 s. One run of this test on w43/gate-mac-reds 30c61601 (stage
# alpha-w43 35e0fc83, Mac Studio M5 Max, Godot 4.7.2, 24 seeds a side) read small first-stagger median 36.61 s, as the
# wave 43 gate's four solo runs did; small 71.24 s and grown 31.98 s pass their Linux pins there, so those stay single.
# 2026-11-20 (wave 44 close, Mac Studio, stage/alpha-w44 212fb8e0 after w44/brindle-bot-camera): lens crosshair aim
# moved the Mac small first-stagger median across all 24 seeds from 36.61 s to 48.45 s (4/4 solo runs identical,
# 201/202 checks green, right beside Linux's 50.32 s). Mac band re-centered on 48.45 s; Linux band unchanged.
const FIRST_STAGGER_BAND_S := Vector2(40.32, 60.32)
const FIRST_STAGGER_BAND_S_MAC := Vector2(38.45, 58.45)
const SMALL_FACTOR := 2.0
const HOIST_TOP := 29.0
const RUN_CAP_S := 300.0
const TURN_S := 30.0
const LOW_DWELL_M := 0.01
const DRIVER_PATH := "res://src/combat/warden_swarm.gd"
# 2026-10-11 (w13 KF-BOT, base b2c6fa3 plus the bot's latch arm, tools/bot_driver.gd _anchor_fight): re-measured
# with the latch arm on, eight seeds, cut at RUN_CAP_S 300 s, three sweeps on a loaded machine (load 46 to 60), all
# three identical: grown 118.32 s of [139.63, 93.86, 105.69, 131.11, 98.16, 151.46, 117.9, 118.32]; small 164.03 s
# of [164.03, 121.54, 158.93, 210.52, 169.36, 148.18, 179.94, 138.2]; the camper never breaks it. Low-dwell staggers
# per grown seed [4, 4, 4, 3, 2, 3, 2, 3]; finishes from a latch per grown seed [2, 4, 4, 3, 4, 4, 4, 4] (camper all
# 0). The three sweeps agree within 10 percent, so both medians are pinned. Before the latch arm (KF3 fix round):
# grown 151.71 s, small 223.12 s.
# 2026-10-11 (KF-BOT fix round, coordinator ruling 3): a fourth sweep, direct, load 20 to 45, gave the same 24
# fights to the hundredth and prints the hand's counts per seed. Grown: latches [42, 31, 31, 46, 32, 43, 33, 35],
# ride s [70.2, 45.6, 54.1, 78.8, 51.9, 76.2, 57.5, 55.8], line shots [354, 712, 87, 399, 809, 126, 287, 878],
# chunks from a haul [2, 4, 4, 3, 4, 4, 4, 4], drop break on seeds 0, 4, 7. The hand latches, rides, fires and
# finishes as swarm.md section 4 describes, so the miss is the mechanism's tuning, not the hand: owner call.
# THESE PINS ARE NOT THE BAND. The two band checks stay red: grown 118.32 s against 25 to 45 s, small/grown 1.39
# against 2. The latch arm keeps posture from draining through the high dwell (shots from the line) and finishes
# every stagger with a haul (the alpha rows set ram_shatters false, so a ram never takes a chunk), but posture still
# fills only from rams in the 4 s low dwell and about 1.5 a second from the line, so a chunk costs two to three
# hoist cycles. Owner tuning call (no stage-3 tune is in KF-BOT's scope): restate the headframe band near the
# sheet's own prediction (60 to 85 s, swarm.md:177), raise line-shot posture on an anchor, or shorten the high dwell.
# 2026-10-17 (KNOCKBACK-FEEL, PR #43): small re-pinned 104.78 -> 88.16 s. Cause: hit-stop scaling (juice.gd
# THROW_STOP_MS), not knockback scatter. With juice.gd at main and the rest of #43 the small median is 109.47 s
# (in the old pin); with the throw-based stop it is 84.65 to 88.16 s across two sweeps. Grown stays at its pin
# (38.54 s) and small/grown stays above 2 (2.29). Receipts: /mnt/project-files/gate/knockback-43/.
# 2026-10-17 (SQ2, PR #15): hive defenders skip the attacker budget (Andrew's cards "Swarm campers"
# 20:52:11Z and "All at hives" 21:19:16Z). Measured over seeds 0 to 7: small 91.27 s of [74.35, 105.61,
# 187.68, 78.73, 108.58, 76.19, 64.94, 91.27], grown 38.77 s of [34.72, 36.94, 42.94, 37.47, 46.4, 26.12,
# 38.77, 55.52], 2.35x; the camper broke it on none of seeds 0 to 15 but seed 8 (222 s). Was 104.78 / 38.77.
# stage/alpha-w16 carries both #43 and #15: #43's 88.16 s stands until the combined sweep re-pins it.
# 2026-10-18 (wave 16 close, main f9f58944 plus the parallel cap): the combined sweep re-pins small
# 88.16 -> 99.54 s and grown 38.77 -> 42.69 s. Measured with every child recorded (8 at once on a
# 4-core sandbox): small 99.54 s of [88.36, 106.18, 99.9, 99.54, 89.76, 84.33, 71.83, 106.63], grown
# 42.69 s of [62.85, 38.09, 42.69, 51.71, 61.81, 38.15, 37.85, 38.71], 2.33x; the camper broke it on
# none. The #104 thread's sweep on f9f58944 (gate/pr104-swarm-ablation.txt) gave the same fights to the
# hundredth except grown seed 1, which the kernel killed for memory there and which is 38.09 s here.
# 2026-10-23 (swarm hive option 1, alpha_defs.gd HIVE_HEAVY_RATIO): 24 seeds a side on stage
# w18 re-pin small 99.54 -> 72.89 s and grown 42.69 -> 33.95 s, 2.15x. Before the tune, the same 24 seeds read
# small 75.69 s and grown 40.67 s, 1.86x, first stagger 50.32 s; trials in /mnt/project-files/gate/c10-swarm/.
# 2026-11-25 (W48-COMBAT, 48-seed sweep on w48/combat-dig-waking with 5 Dig 2-attack kits & PF-42 headframe fix):
# measured small 68.27 s (was 66.82 s on w45, +1.45 s under Dig 2-attack stall pressure), grown 30.33 s (was
# 30.38 s on w45, inside 25..45 s GROWN_BAND_S with 5.33 s margin), ratio 2.25x (>= 2.0x SMALL_FACTOR), small
# first stagger 48.04 s (inside 38.45..58.45 s Mac band), 24/24 low-dwell staggers, 24/24 latch finishes.
# Re-pinned to the 48-seed measured medians with all design bands and 10% tolerance unchanged.
const EXPECT_SMALL_S := 68.27
const EXPECT_GROWN_S := 30.33
const TOLERANCE := 0.10
# 2026-10-18: a 4-core, 16 GB cloud sandbox ran all 24 children at once; the kernel killed grown
# seed 1 for memory (exit 9, no record, counted as a 300 s fight) and every camper hit the 900 s
# wall cap, so the band read grown 51.71 s. CHILD_MEMORY_B is one child's budget (about 700 MB
# resident at its peak) and CHILDREN_PER_CORE caps the children to the cores, so each child
# finishes its run on any machine.
const CHILD_MEMORY_B := 1024 * 1024 * 1024
const CHILDREN_PER_CORE := 2

var _child := false
var _hoisted = null
var _hoist_top := 0.0
var _swarm_driver = null
var _was_staggered := false
var _staggers := []
var _first_stagger_s := -1.0


func _initialize() -> void:
	if _parse(OS.get_cmdline_user_args()).get("swarm-hoist", "") == "1":
		_child = true
		super._initialize()
		return
	var t := T.new(_suite())
	var folder := OS.get_user_data_dir().path_join("posture-bands-swarm-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var sweep := _sweep(t, folder)
	_judge(t, sweep)
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


# The sweep a parent runs, arm to seed count. The camper runs in posture_bands_swarm_camper_test,
# so neither parent passes the bot tier's 1800 s ceiling (23 Oct: small and grown alone took 1322 s).
func _arm_seeds() -> Dictionary:
	return {"small": SEED_COUNT, "grown": SEED_COUNT}


func _suite() -> String:
	return "posture_bands_swarm_test"


# Runs the arms' children and checks each seed; returns per-arm lists keyed by fights, low_staggers,
# latch_finishes and first_staggers.
func _sweep(t, folder: String) -> Dictionary:
	var arms := _arm_seeds()
	var jobs := []
	var names := []
	for arm in arms:
		for run_seed in int(arms[arm]):
			var out := folder.path_join("%s-%d" % [arm, run_seed])
			var args := ["--swarm-hoist=1", "--out=" + out, "--policy=" + String(ARM_ROWS[arm]["policy"]), "--seeds=%d" % run_seed,
				"--pilot=" + String(PILOTS[run_seed % PILOTS.size()]), "--table=alpha", "--from-stage=%d" % STAGE, "--until=%d" % STAGE,
				"--ticks=%d" % roundi((RUN_CAP_S + TURN_S) * Engine.physics_ticks_per_second)]
			if int(ARM_ROWS[arm]["mass"]) > 0:
				args.append("--start-mass=%d" % int(ARM_ROWS[arm]["mass"]))
			jobs.append({"script": "res://tests/posture_bands_swarm_test.gd", "args": args})
			names.append([arm, run_seed, out])
	t.check("the sweep has runs", not jobs.is_empty(), "%d jobs" % jobs.size())
	var parallel := _parallel(jobs.size())
	print("swarm sweep: %d children, %d at once" % [jobs.size(), parallel])
	var results := ChildRuns.run(jobs, 900.0, parallel)
	var sweep := {"fights": {}, "low_staggers": {}, "latch_finishes": {}, "first_staggers": {}}
	for key in sweep:
		for arm in arms:
			sweep[key][arm] = []
	var unrecorded := []
	for i in results.size():
		var arm: String = names[i][0]
		var run_seed: int = names[i][1]
		var out: String = names[i][2]
		t.check("%s seed %d ran" % [arm, run_seed], results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
		var record := _record(out)
		# A child the system killed (exit 9, SIGKILL; on 18 Oct the kernel's out-of-memory killer) or the wall cap cut wrote no
		# record: an error of the sweep, never a fight at the run cap, so it stays out of the medians.
		t.check("%s seed %d wrote a record" % [arm, run_seed], not record.is_empty(),
			"child killed / no record, exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
		if record.is_empty():
			unrecorded.append("%s %d (exit %s)" % [arm, run_seed, results[i]["code"]])
		var pilot: String = PILOTS[run_seed % PILOTS.size()]
		t.eq("%s seed %d plays %s" % [arm, run_seed, pilot], record.get("class", ""), pilot)
		var hoist = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("hoist.json"))) if FileAccess.file_exists(out.path_join("hoist.json")) else null
		var top: float = float(hoist.get("top", 0.0)) if hoist is Dictionary else 0.0
		t.check("%s seed %d fought the live hoist" % [arm, run_seed], hoist is Dictionary and hoist.get("driver", "") == DRIVER_PATH
				and top >= HOIST_TOP, "hoist %s" % [hoist])
		if not record.is_empty():
			sweep["fights"][arm].append(_fight(record))
			sweep["first_staggers"][arm].append(_first_stagger(record, hoist))
		var heights: Array = hoist.get("staggers", []) if hoist is Dictionary else []
		sweep["low_staggers"][arm].append(heights.filter(func(h): return float(h) < LOW_DWELL_M).size())
		sweep["latch_finishes"][arm].append(_latch_chunks(record))
		var note := _stage_note(record)
		print("swarm latch arm %s seed %d: latches %d, ride %.1f s, shots from the line %d, hauls %d, chunks from a haul %d, drop hauls %d, drop chunks %d, drop break %s, fight %.2f s" % [
			arm, run_seed, int(note.get("latch_bites", 0)), float(note.get("latch_ride_s", 0.0)), int(note.get("latch_shots", 0)),
			int(note.get("latch_hauls", 0)), int(note.get("latch_chunks", 0)), int(note.get("drop_hauls", 0)), int(note.get("drop_chunks", 0)),
			note.get("drop_break", false) == true, _fight(record)])
	print("swarm runs with no record (left out of the medians): %s" % [unrecorded])
	t.eq("each arm ran its seeds", arms.keys().map(func(arm): return sweep["fights"][arm].size()), arms.values())
	return sweep


# The band on small and grown.
func _judge(t, sweep: Dictionary) -> void:
	var fights: Dictionary = sweep["fights"]
	var low_staggers: Dictionary = sweep["low_staggers"]
	var latch_finishes: Dictionary = sweep["latch_finishes"]
	var grown: float = _median(fights["grown"])
	var small: float = _median(fights["small"])
	var grown_low: int = low_staggers["grown"].filter(func(n): return n > 0).size()
	print("swarm band stage %d: small %.2f s of %s, grown %.2f s of %s" % [STAGE, small, fights["small"], grown, fights["grown"]])
	print("swarm low-dwell staggers per seed: small %s, grown %s" % [low_staggers["small"], low_staggers["grown"]])
	var first_small: float = _median(sweep["first_staggers"]["small"])
	print("swarm first stagger: small %.2f s of %s, grown %s" % [first_small, sweep["first_staggers"]["small"], sweep["first_staggers"]["grown"]])
	t.check("half the grown seeds stagger the hive in a low dwell", grown_low * 2 >= SEED_COUNT,
		"%d of %d grown seeds, per seed %s" % [grown_low, SEED_COUNT, low_staggers["grown"]])
	print("swarm finishes from a latch per seed: small %s, grown %s" % [latch_finishes["small"], latch_finishes["grown"]])
	var grown_latched: int = latch_finishes["grown"].filter(func(n): return n > 0).size()
	t.check("one finish from a latch", grown_latched >= 1,
		"%d of %d grown seeds took a chunk with a haul from a latch, per seed %s" % [grown_latched, SEED_COUNT, latch_finishes["grown"]])
	t.check("grown breaks the hive in 25 to 45 s", grown >= GROWN_BAND_S.x and grown <= GROWN_BAND_S.y, "grown median %.2f s" % grown)
	t.check("small takes at least twice grown's time", grown > 0.0 and small >= SMALL_FACTOR * grown, "small %.2f s, grown %.2f s" % [small, grown])
	var first_band: Vector2 = PlatformPin.pick(FIRST_STAGGER_BAND_S, FIRST_STAGGER_BAND_S_MAC)
	t.check("an ordinary pilot first staggers the hive within 10 s of the measured %.2f s" % (first_band.x + 10.0), first_small >= first_band.x
		and first_small <= first_band.y, "small first-stagger median %.2f s" % first_small)
	t.check("small and grown medians are measured under the run cap", small < RUN_CAP_S and grown < RUN_CAP_S,
		"small %.2f s, grown %.2f s, cap %.0f s" % [small, grown, RUN_CAP_S])
	t.check("small median within 10 percent of the pin", EXPECT_SMALL_S > 0.0 and absf(small - EXPECT_SMALL_S) <= TOLERANCE * EXPECT_SMALL_S,
		"small %.2f s, pin %.2f s" % [small, EXPECT_SMALL_S])
	t.check("grown median within 10 percent of the pin", EXPECT_GROWN_S > 0.0 and absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.2f s, pin %.2f s" % [grown, EXPECT_GROWN_S])


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
		_swarm_driver = load(DRIVER_PATH).new()
		warden.set_mount_driver(_swarm_driver)
		_hoisted = warden
		_was_staggered = false
		_write_hoist()
	# Read before this tick's mount_offset, so the height is where the hive stood when the stagger opened.
	var staggered: bool = warden.staggered()
	if staggered and not _was_staggered:
		_staggers.append(float(_swarm_driver.height))
		if _first_stagger_s < 0.0:
			_first_stagger_s = float(_game.run.stage_time)
		_write_hoist()
	_was_staggered = staggered
	var top: float = warden.global_position.y - warden.home.y
	if top > _hoist_top + 1.0:
		_hoist_top = top
		_write_hoist()


func _write_hoist() -> void:
	var file := FileAccess.open(_out.path_join("hoist.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"driver": DRIVER_PATH, "top": _hoist_top, "staggers": _staggers,
			"first_stagger_s": _first_stagger_s}))


func _record(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	return record if record is Dictionary else {}


# Chunks the bot took with a haul from a line on a hardpoint inside a stagger (bot_driver.gd _watch_haul).
func _latch_chunks(record: Dictionary) -> int:
	return int(_stage_note(record).get("latch_chunks", 0))


# The bot's note for the stage under test (bot_driver.gd _anchor_fight's counts ride in it).
func _stage_note(record: Dictionary) -> Dictionary:
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == STAGE:
			return note
	return {}


func _fight(record: Dictionary) -> float:
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == STAGE and note.get("warden_broken_s") != null:
			return minf(RUN_CAP_S, float(note["warden_broken_s"]) - _fight_start(note))
	return RUN_CAP_S


# Seconds from the turn to the Warden to the hive's first stagger (hoist.json); RUN_CAP_S if it never staggered.
func _first_stagger(record: Dictionary, hoist) -> float:
	var at: float = float(hoist.get("first_stagger_s", -1.0)) if hoist is Dictionary else -1.0
	if at < 0.0:
		return RUN_CAP_S
	return minf(RUN_CAP_S, at - _fight_start(_stage_note(record)))


# A camper never turns to the Warden, so its note has no warden_fight_s; its fight starts at
# the engagement (bot_driver.gd fight_start_of), not at 0, which read a 140 s break as 0 s.
func _fight_start(note: Dictionary) -> float:
	var start = note.get("warden_fight_s")
	if start == null:
		start = BotDriver.fight_start_of(note)
	return float(start if start != null else 0.0)


# The children that fit at once: all of them on a big machine, fewer where memory or cores are short.
static func _parallel(jobs: int) -> int:
	var available := int(OS.get_memory_info().get("available", -1))
	var by_memory := jobs if available <= 0 else maxi(1, available / CHILD_MEMORY_B)
	return clampi(mini(by_memory, OS.get_processor_count() * CHILDREN_PER_CORE), 1, jobs)


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
