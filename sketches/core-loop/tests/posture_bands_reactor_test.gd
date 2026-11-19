# smoke: solo timeout=360s (twenty-seven bot runs in child processes at once; a loaded machine slows them)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotOptions := preload("res://tools/bot_options.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")
const PlatformPin := preload("res://tests/support/platform_pin.gd")

# The reactor band (design-v3/wardens/reactor.md section 7; K-UNITS wave K-F, KF2), modelled on
# tests/posture_bands_test.gd: a solo bot sweep on the reactor's first stage, the alpha table's
# stage 1 (Spillway, plating 90, hp 650, curve 2.0, ram_shatters false), with the dam_face
# mechanism live: once the stage's Warden stands, the child mounts src/combat/warden_reactor.gd
# on it through set_mount_driver, so every pulse opens the gates and lays the sheet. The arms
# are tools/posture_sweep.gd's (small: skipper from mass 0; grown: skipper from 540; camper:
# shoots from range), seeds 0 to 8 (three seeds until 19 Nov 2026), one child process each, a run that never breaks counting
# as the 120 s cap (posture_bands_test.gd's smoke limit). Bands: grown median 25 to 45 s, small median at least twice grown's, the
# camper never breaks it; the live medians stay within 10 percent of the pins below.
# The child is this script run with --arm (posture_sweep.gd's child shape on the alpha table).
# The Warden is not made a harpoon anchor here: KF1b measured the bot stalling on the
# stagger-gated haul (posture_bands_test.gd header), and KF8 wires the park's anchors.

const SEEDS := [0, 1, 2, 3, 4, 5, 6, 7, 8]
const ARMS := ["small", "grown", "camper"]
# A run that never breaks counts as this cap; the camper's run lasts it, so it bounds the wall time.
const CAP := 120.0
const DRIVER_PATH := "res://src/combat/warden_reactor.gd"
# 2026-10-11 (w13 KF2): first pin, measured on 28fe659 plus KF2 with the dam_face sheet live (SHEET_TOP 14 m):
# small 76.7 s of [58.1, 79.8, 76.7], grown 34.4 s of [34.4, 47.7, 19.9], ratio 2.23, campers capped; a repeat
# measured 79.8 / 34.4. Without the sheet the same runs gave 46.1 / 20.4 (grown under the band); with the ride
# carried to the core itself (SHEET_TOP 4 m) 54.7 / 38.1 (ratio 1.44), so the lip distance is the dial.
# 2026-10-11 (w13 KF2b): re-pinned at CAP 120 s on 02eeaeb plus KF2b (the flume pour rebuilt in on_pulse;
# the dam_face sheet these runs fight is unchanged). Sweep 1, under the solo smoke with the seven reactor
# files: passed against 76.7 / 34.4 (within 10 percent); the smoke does not print per-seed values on a pass.
# Sweep 2, direct: small [73.44, 77.83, 88.74] median 77.8, grown [32.80, 50.29, 18.87] median 32.8, ratio
# 2.37, campers [120, 120, 120]. Sweep 3, direct, load average about 40: small [73.44, 77.83, 120.00 capped]
# median 77.8, grown [32.80, 50.29, 18.91] median 32.8, ratio 2.37, campers [120, 120, 120]. Small seed 2
# hitting the cap is why "small breaks it in every run" is a [report] line, not a check.
# 2026-10-11 (w13 KF-BOT fix round, coordinator ruling 4): re-pinned on the w13 base b2c6fa3, which already
# measured under the old pins (the B4 adapter merge 49f9a0a moved posture_bands_test's small pin the same way;
# inference). The reactor is not an anchor here, so the latch arm's gate leaves this fight on the old path: head
# and base give the same distribution. Three direct sweeps each, head and base side by side, load 22 to 47:
# head small [55.60, 70.97, 62.05] / [59.31, 70.97, 53.53] / [59.31, 70.97, 56.13], medians 62.0 / 59.3 / 59.3;
# grown [35.76, 47.47, 22.77] / [35.77, 47.47, 22.77] / [35.77, 47.47, 22.77], median 35.8 each; campers 120.
# Base small medians 59.3 / 55.6 / 59.3, grown 35.8 each. Small seed 0 and seed 2 vary run to run (55.6 or 59.3;
# 53.5 to 62.1). The ratio band, small at least twice grown, fails on head and base alike at 1.55 to 1.74: that
# is the band, not a pin, so it stays a red check for the coordinator (no row: QUARANTINE.tsv is at its cap).
# 2026-10-13 WT-BANDS round 5: small re-pin 59.3 -> 69.80 s after IDENTITY-DET.
# Three unchanged controls: small [69.80, 69.80, 69.80], grown [33.94, 33.94, 33.94],
# ratio 2.05657 in each; both median spreads 0 percent. Small seed 2 reaches CAP in each.
# Grown pin 35.8, tuning, arms, seeds, bands and tolerance stay unchanged.
# 2026-10-14 coordinator, at the SQ12 restore: small re-pin 69.80 -> 88.32 s. Spillway's camp is now
# the library's runner_yard interior; small seed 1 broke at 88.32 s (was 69.80). Two identical runs,
# one at the SQ12-FIX merge without SI1 and one with it: small [55.41, 88.32, 120.00], grown
# [33.94, 50.29, 18.61]. Bands hold: grown 33.9 s in 25 to 45, ratio 2.60, camper 0 breaks.
# 2026-10-18 Gate lane, stage/alpha-w17 666662c5 (the staging "reactor-band drift"): small re-pin 88.32 -> 53.27 s,
# grown 35.8 -> 31.23 s. Two direct runs, one on 666662c5 and one on the pre-stack stage 102324cd, byte-identical:
# small [53.27, 43.25, 81.45], grown [31.23, 44.62, 16.68], campers 120, rides per run [1, 2, 2, 0, 1, 0, 2, 2, 6].
# The drift predates the wave 17 stack. Small 53.3 s sits inside the 45-70 s ordinary-pilot ruling (DECISIONS
# section 5). The ratio band (small at least twice grown) reads 1.71 on both and stays a red check for the coordinator.
# 2026-10-24 (base-cruise ruling, #424): pins hold, measured 51.0 / 31.2. Over 24 seeds small 71.1 s, grown 19.6 s
# (ratio 3.63); grown is 5.4 s under the 25 to 45 s band there, and 20.6 s on the pre-change stage, so not this change.
# 2026-11-08 (invariants thread, ruling bl, the bot's point-blank bite at a 0.25 s re-press, #624): small re-pin
# 53.27 -> 60.23 s, grown 31.23 -> 31.80 s. One direct run on stage/alpha-w31 07fb5323, the same as the Gate lane's
# bands A run and its solo rerun: small [52.62, 60.23, 90.12], grown [31.80, 51.40, 26.78], campers 120, rides per
# run [3, 5, 6, 0, 2, 0, 2, 3, 1]. Small 60.2 s sits inside the 45-70 s ordinary-pilot ruling. The ratio band reads
# 1.89 and stays the owed red check, as before.
# 2026-11-15 (coordinator, wave 41 close): small re-pin 60.23 -> 73.09 s, grown 31.80 -> 31.34 s. Two direct runs
# alone on an idle PC on stage/alpha-w41 fab0aa76, byte-identical: small [48.95, 73.09, 120.00], grown
# [31.34, 38.67, 18.82], campers 120, rides per run [1, 2, 7, 0, 1, 0, 1, 1, 3]. The small median already read
# 71.5 s on the wave 41 cut (49e801ad) and 73.1 s with the difficulty stack (PR 845), so the move is the harder
# stage and not a later change. The ratio now reads 2.33 and the twice-grown check passes. Small 73.1 s is 3 s
# over the 45-70 s ordinary-pilot ruling (DECISIONS section 5); ruling cu (harder, never easier) is the newer
# one, and the overshoot is on the list for Andrew's sitting.
# 2026-11-17 (ruling eb, Mac gate; tests/support/platform_pin.gd): Mac pins beside the Linux ones (73.09 / 31.34 stay).
# The Mac plays each seed a different fight (its sinf and cosf round differently). One run alone on w43/gate-mac-reds
# 30c61601 (stage alpha-w43 35e0fc83, Mac Studio M5 Max, Godot 4.7.2), the same medians as the wave 43 gate's run: small
# [53.15, 64.13, 60.87] median 60.87, grown [31.34, 25.42, 21.74] median 25.42, ratio 2.39, campers 120, rides per run
# [1, 3, 1, 0, 1, 0, 1, 1, 2]. Grown 25.4 s sits 0.4 s over the 25 s band floor on the Mac.
# 2026-11-19 (Gate, stage/alpha-w44 ca8b06bbb plus w44/brindle-bot-camera 7adeb1b4c, Mac Studio, Godot 4.7.2): nine seeds,
# Mac re-pin small 60.87 -> 54.96 s, grown 25.42 -> 19.39 s. b0c797f04 (MG-11) made pack_pressure.gd observe() count a
# hit-stopped tick at its true length; that plays seed 1 a different fight (64.1 -> 42.3 s small), which alone decided the
# three-seed medians and broke the twice-grown rule. Old against new observe() over seeds 3 to 8 agree within 7 s, so the
# clock shifts no band. Nine seeds: small [48.63, 42.32, 54.96, 120, 55.31, 18.10, 53.93, 55.80, 120] median 54.96, grown
# [31.34, 28.76, 15.78, 15.16, 19.36, 14.47, 23.11, 35.16, 19.39] median 19.39, ratio 2.83, campers 120. Grown sits 5.6 s
# under the 25 s floor, as the 24-seed read of 24 Oct said: the three-seed pass was luck. The band check stays red and is
# carried on KNOWN-FAILING.tsv beside posture_bands_test's grown floor (the stage 1 Warden plating sweep). Linux pins stay.
const EXPECT_SMALL_S := 73.09
const EXPECT_SMALL_S_MAC := 54.96
const EXPECT_GROWN_S := 31.34
const EXPECT_GROWN_S_MAC := 19.39
const TOLERANCE := 0.10
const WALL_S := 330.0

var _settings := {}
var _bot_options
var _game
var _driver
var _reactor
var _done := false
var _attached := false
var _struck_s := -1.0
var _run_seed := 0


func _initialize() -> void:
	_settings = PostureSweep._parse(OS.get_cmdline_user_args())
	_bot_options = BotOptions.new(_settings, self)
	if _settings.has("arm"):
		_begin_child()
		return
	var t := T.new("posture_bands_reactor_test")
	var folder := OS.get_user_data_dir().path_join("posture-bands-reactor-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	for arm in ARMS:
		for run_seed in SEEDS:
			var args := ["--arm=" + arm, "--run-seed=%d" % run_seed, "--result=" + folder.path_join("%s-%d.tsv" % [arm, run_seed]),
				"--home=" + folder.path_join("%s-%d" % [arm, run_seed])]
			var mass := float(PostureSweep.arm_named(arm)["mass"])
			if mass > 0.0:
				args.append("--start-mass=%d" % int(mass))
			jobs.append({"script": "res://tests/posture_bands_reactor_test.gd", "args": args})
	var results := ChildRuns.run(jobs, WALL_S)
	var rows := {}
	for i in jobs.size():
		var arm: String = ARMS[i / SEEDS.size()]
		var run_seed: int = SEEDS[i % SEEDS.size()]
		var path := folder.path_join("%s-%d.tsv" % [arm, run_seed])
		var line := FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""
		var cols := line.split("\t")
		t.check("%s seed %d ran" % [arm, run_seed], results[i]["code"] == 0 and not results[i]["timed_out"] and cols.size() >= 6,
			"exit %s, timed out %s, row '%s'" % [results[i]["code"], results[i]["timed_out"], line])
		if not rows.has(arm):
			rows[arm] = []
		rows[arm].append(cols)
	var all_rows: Array = rows.values().reduce(func(acc, r): return acc + r, [])
	# A fast break can come before the first pulse; the camper's full-length runs must see the gates.
	t.check("every run mounted the reactor driver; the gates opened in every camper run", all_rows.size() == ARMS.size() * SEEDS.size()
			and all_rows.all(func(c): return c.size() >= 6 and c[3] == "true")
			and rows.get("camper", []).all(func(c): return c.size() >= 6 and int(c[4]) > 0),
		"attached and gates per run %s" % [all_rows.map(func(c): return "%s/%s" % [c[3], c[4]] if c.size() >= 6 else "?")])
	var small := _median(rows.get("small", []))
	var grown := _median(rows.get("grown", []))
	var camper_broke: int = rows.get("camper", []).filter(func(c): return c.size() >= 6 and c[1] == "true").size()
	var small_broke: int = rows.get("small", []).filter(func(c): return c.size() >= 6 and c[1] == "true").size()
	print("[report] medians small %.1f s, grown %.1f s, ratio %.2f; small %s, grown %s, camper %s; rides per run %s" % [small, grown,
		small / grown if grown > 0.0 else 0.0, _fights(rows.get("small", [])), _fights(rows.get("grown", [])),
		_fights(rows.get("camper", [])), all_rows.map(func(c): return c[5] if c.size() >= 6 else "?")])
	t.check("grown breaks it in 25 to 45 s", grown >= 25.0 and grown <= 45.0, "grown median %.1f s" % grown)
	t.check("small takes at least twice grown's time", grown > 0.0 and small >= 2.0 * grown, "small %.1f s, grown %.1f s" % [small, grown])
	# Not a band bullet (reactor.md section 7): a small run that hits the cap is reported, not gated.
	print("[report] small broke it in %d of %d runs" % [small_broke, SEEDS.size()])
	t.eq("the camper never breaks it", camper_broke, 0)
	t.check("small median within 10 percent of the pin", absf(small - PlatformPin.pick(EXPECT_SMALL_S, EXPECT_SMALL_S_MAC)) <= TOLERANCE * PlatformPin.pick(EXPECT_SMALL_S, EXPECT_SMALL_S_MAC),
		"small %.1f s, pin %.1f s" % [small, PlatformPin.pick(EXPECT_SMALL_S, EXPECT_SMALL_S_MAC)])
	t.check("grown median within 10 percent of the pin", absf(grown - PlatformPin.pick(EXPECT_GROWN_S, EXPECT_GROWN_S_MAC)) <= TOLERANCE * PlatformPin.pick(EXPECT_GROWN_S, EXPECT_GROWN_S_MAC),
		"grown %.1f s, pin %.1f s" % [grown, PlatformPin.pick(EXPECT_GROWN_S, EXPECT_GROWN_S_MAC)])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)
	quit(t.verdict())


func _fights(rows: Array) -> Array:
	return rows.map(func(c): return c[2] if c.size() >= 6 else "?")


func _median(rows: Array) -> float:
	var fights := rows.filter(func(c): return c.size() >= 6).map(func(c): return float(c[2]))
	return PostureSweep.median(fights) if not fights.is_empty() else 0.0


# ---- Child: one run on the alpha table's stage 1 --------------------------------------------

func _begin_child() -> void:
	SimClock.ticks = true
	_run_seed = int(_settings.get("run-seed", "0"))
	seed(_run_seed)
	Engine.time_scale = 1.0
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null or not _settings.has("arm"):
		return false
	if _driver == null:
		var home := String(_settings["home"])
		DirAccess.make_dir_recursive_absolute(home)
		_game.codex.storage_dir = home
		_game.run_log.storage_dir = home
		var arm := PostureSweep.arm_named(String(_settings["arm"]))
		_driver = BotDriver.new(_game, String(arm["policy"]), _run_seed)
		_driver.stage_limit = CAP * 4.0
		_driver.fight_limit = CAP
		_game.presentation.audio.bake_now()
		_bot_options.apply_audio(_game.presentation.audio)
		_game.events.enemy_struck.connect(_on_struck)
		_game.run.run_seed_override = _run_seed
		_driver.start()
		return false
	_mount()
	var over: bool = _driver.tick(delta)
	if not over and _driver.warden_broken():
		_driver._end("broken")
		over = true
	if not over:
		return false
	_done = true
	_record()
	_game.free()
	_game = null
	quit(0)
	return false


# The stage's Warden takes the reactor's driver once it stands (the file must exist).
func _mount() -> void:
	if _attached or _game.flow == null or not is_instance_valid(_game.flow.warden):
		return
	_attached = true
	if not ResourceLoader.exists(DRIVER_PATH):
		_attached = false
		return
	_reactor = load(DRIVER_PATH).new()
	_game.flow.warden.set_mount_driver(_reactor)


func _on_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if _struck_s >= 0.0 or not is_instance_valid(enemy) or _game.flow == null or enemy != _game.flow.warden:
		return
	_struck_s = _game.run.stage_time


# One row: arm, broke, fight seconds, driver mounted, gates opened, sheet rides.
func _record() -> void:
	var note: Dictionary = _driver.stage_notes[_driver.stage_notes.size() - 1] if not _driver.stage_notes.is_empty() else {}
	var run := PostureSweep.measure(note, CAP, _struck_s)
	var mounted := _reactor != null
	var line := "\t".join([String(_settings["arm"]), str(run["broke"]), "%.2f" % float(run["fight"]), str(mounted),
		str(_reactor.gates_opened if mounted else 0), str(_reactor.rides if mounted else 0),
		ClassDef.all()[_driver.class_index].id])
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(line + "\n")
	file.close()
