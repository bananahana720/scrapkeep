# smoke: solo timeout=360s (nine stage-5 bot runs in child processes at once; a loaded machine slows them)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Game := preload("res://src/game.gd")
const T := preload("res://tests/support/t.gd")

# The mind band (design-v3/wardens/mind.md section 7) on stage 5, the Hanging Isle's hand, with
# the pendulum tilt live. The arms are posture_sweep.gd's: small (no start mass), grown (540)
# and the camper, each on seeds 0, 1 and 2 with the pilots posture_bands_test.gd names. Every
# run is its own process (this script with --arm), so a run repeats: the alpha table, the
# skipper or camper bot, stage 5 entered as tools/bot_run.gd --from-stage does, and the stage's
# Warden given the kind's driver (src/combat/warden_mind.gd). A fight runs from the later of the
# bot's turn and its first contact to the break (posture_sweep.gd measure); a run that never
# breaks counts as the cap. Bands: grown median 25 to 45 s, small median at least twice grown's,
# the camper never breaks it; the measured medians are pinned below with the 10 percent tolerance.
# The Warden is not made a harpoon anchor here: with "harpoon_anchor" on, Ctrl hauls are gated to
# the stagger and the bot breaks no Warden in 150 s with or without the tilt (2026-10-11, 9 of 9
# runs capped both ways; posture_bands_test.gd's 2026-10-10 header saw the same stall), so the
# anchor's own effect on the band waits on the bot. KF4_BANDS_ANCHOR=1 and KF4_BANDS_DRIVER=0 in
# the environment rerun those arms. The alpha stage-5 Warden stands on the ground until KD5 and
# KF8 hang it under the island, so this is the tilt on the ground, not the mounted fight.

const SEEDS := [0, 1, 2]
const PILOTS := {0: "pylon_engineer", 1: "runner_gunner", 2: "demolitions_caster"}
const ARMS := {"small": {"policy": "skipper", "mass": 0}, "grown": {"policy": "skipper", "mass": 540},
	"camper": {"policy": "camper", "mass": 0}}
const STAGE := 5
const CAP_S := 150.0
const DRIVER_PATH := "res://src/combat/warden_mind.gd"
# Pins (median fight seconds over the three seeds), measured with the tilt live:
# 2026-10-11 (wave 13 KF4): measured 66.4 / 49.4 s (small/grown 1.34) with the tilt; the same arms with
# no driver measured 78.6 / 41.5 s (1.89). The band misses both ways (grown over 45 s with the tilt, small
# under twice grown with and without it), so the stage-5 numbers need a tuning call, not this unit's dials
# (the tilt angle is fixed at 10 degrees, and the lens height means nothing on the ground).
const EXPECT_SMALL_S := 66.4
const EXPECT_GROWN_S := 49.4
const TOLERANCE := 0.10

var _settings := {}
# Child state.
var _game
var _driver
var _run_seed := 0
var _arm := ""
var _struck_s := -1.0
var _tilts := 0
var _attached := false
var _entered := false
var _done := false
var _mounting := ""


func _initialize() -> void:
	_settings = PostureSweep._parse(OS.get_cmdline_user_args())
	if _settings.has("arm"):
		_begin_child()
		return
	_parent()


# ---- Parent ----------------------------------------------------------------------------

func _parent() -> void:
	var t := T.new("posture_bands_mind_test")
	var folder := OS.get_user_data_dir().path_join("posture-bands-mind-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	var keys := []
	for arm in ARMS:
		for run_seed in SEEDS:
			var home := folder.path_join("%s-%d" % [arm, run_seed])
			DirAccess.make_dir_recursive_absolute(home)
			var args := ["--arm=" + arm, "--run-seed=%d" % run_seed, "--result=" + home.path_join("result.tsv"), "--home=" + home,
				"--anchor=%s" % OS.get_environment("KF4_BANDS_ANCHOR") if OS.has_environment("KF4_BANDS_ANCHOR") else "--anchor=0",
				"--driver=%s" % OS.get_environment("KF4_BANDS_DRIVER") if OS.has_environment("KF4_BANDS_DRIVER") else "--driver=1"]
			if int(ARMS[arm]["mass"]) > 0:
				args.append("--start-mass=%d" % int(ARMS[arm]["mass"]))
			jobs.append({"script": "res://tests/posture_bands_mind_test.gd", "args": args})
			keys.append([arm, run_seed, home])
	var results := ChildRuns.run(jobs, 330.0)
	var fights := {}
	var broke := {}
	var tilted := {}
	var mountings := {}
	var ran := 0
	for i in keys.size():
		var arm: String = keys[i][0]
		var path: String = String(keys[i][2]).path_join("result.tsv")
		var line := FileAccess.get_file_as_string(path).strip_edges() if FileAccess.file_exists(path) else ""
		var cols := line.split("\t")
		if not fights.has(arm):
			fights[arm] = []
			broke[arm] = 0
			tilted[arm] = 0
		if cols.size() < 6 or results[i]["timed_out"]:
			print("  %s seed %d: no result (exit %s, timed out %s)" % [arm, keys[i][1], results[i]["code"], results[i]["timed_out"]])
			fights[arm].append(CAP_S)
			continue
		ran += 1
		print("  %s seed %d: %s" % [arm, keys[i][1], line.replace("\t", " ")])
		fights[arm].append(float(cols[3]))
		if cols[2] == "true":
			broke[arm] += 1
		if int(cols[4]) > 0:
			tilted[arm] += 1
		mountings[cols[5]] = true
	t.check("every run reported", ran == keys.size(), "%d of %d runs wrote a result" % [ran, keys.size()])
	t.check("every run fought the under_island hand with its driver", mountings.keys() == ["under_island"],
		"mountings %s" % [mountings.keys()])
	t.check("the tilt was live in every skipper run", tilted.get("small", 0) == SEEDS.size() and tilted.get("grown", 0) == SEEDS.size(),
		"runs that saw a tilt: small %d, grown %d of %d" % [tilted.get("small", 0), tilted.get("grown", 0), SEEDS.size()])
	var small := PostureSweep.median(fights.get("small", []))
	var grown := PostureSweep.median(fights.get("grown", []))
	print("  medians: small %.1f s, grown %.1f s, camper %.1f s; fights %s" % [small, grown,
		PostureSweep.median(fights.get("camper", [])), fights])
	t.check("grown breaks it in 25 to 45 s (median)", grown >= 25.0 and grown <= 45.0, "grown median %.1f s" % grown)
	t.check("small takes at least twice grown's time (median)", grown > 0.0 and small >= 2.0 * grown,
		"small %.1f s, grown %.1f s, ratio %.2f" % [small, grown, small / grown if grown > 0.0 else 0.0])
	t.eq("the camper never breaks it", broke.get("camper", -1), 0)
	t.check("small median within 10 percent of the pin", absf(small - EXPECT_SMALL_S) <= TOLERANCE * EXPECT_SMALL_S,
		"small %.1f s, pin %.1f s" % [small, EXPECT_SMALL_S])
	t.check("grown median within 10 percent of the pin", absf(grown - EXPECT_GROWN_S) <= TOLERANCE * EXPECT_GROWN_S,
		"grown %.1f s, pin %.1f s" % [grown, EXPECT_GROWN_S])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)
	quit(t.verdict())


# ---- Child: one run ----------------------------------------------------------------------

func _begin_child() -> void:
	SimClock.ticks = true
	_arm = String(_settings["arm"])
	_run_seed = int(_settings.get("run-seed", "0"))
	Engine.time_scale = 1.0
	seed(_run_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)


func _physics_process(delta: float) -> bool:
	if not _settings.has("arm") or _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		var home := String(_settings["home"])
		_game.codex.storage_dir = home
		_game.run_log.storage_dir = home
		_driver = BotDriver.new(_game, String(ARMS[_arm]["policy"]), _run_seed)
		_driver.class_index = BotDriver.class_index_for(_run_seed, String(PILOTS[_run_seed]))
		_driver.stage_limit = CAP_S * 4.0
		_driver.fight_limit = CAP_S
		_game.presentation.audio.bake_now()
		_game.events.enemy_struck.connect(_on_struck)
		_driver.start()
		_game.flow.enter_stage(STAGE, Vector3.ZERO, false)
		_entered = true
		return false
	_attach()
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


# The stage's Warden becomes a park Warden: a harpoon anchor driven by the kind's file.
func _attach() -> void:
	if _attached or _game.run.stage != STAGE:
		return
	var warden = _game.flow.warden
	if not is_instance_valid(warden):
		return
	if String(_settings.get("anchor", "0")) == "1":
		warden.set_harpoon_anchor(true)
	var script = load(DRIVER_PATH) if ResourceLoader.exists(DRIVER_PATH) and String(_settings.get("driver", "1")) != "0" else null
	if script != null:
		var driver = script.new()
		warden.set_mount_driver(driver)
		if driver.has_signal("island_tilted"):
			driver.island_tilted.connect(func(_d: float, _a: Vector3): _tilts += 1)
	_mounting = String(warden.mounting) if warden.mount_driver != null else "none"
	_attached = true


func _on_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if _struck_s >= 0.0 or not is_instance_valid(enemy) or _game.flow == null or enemy != _game.flow.warden:
		return
	if _game.run.stage != STAGE:
		return
	_struck_s = _game.run.stage_time


func _record() -> void:
	var note := {}
	for each in _driver.stage_notes:
		if int(each.get("stage", 0)) == STAGE:
			note = each
	var run := PostureSweep.measure(note, CAP_S, _struck_s)
	var line := "\t".join([_arm, str(_run_seed), str(run["broke"]), "%.2f" % float(run["fight"]), str(_tilts),
		_mounting if _mounting != "" else "none", _driver.outcome])
	var file := FileAccess.open(String(_settings["result"]), FileAccess.WRITE)
	file.store_string(line + "\n")
	file.close()
