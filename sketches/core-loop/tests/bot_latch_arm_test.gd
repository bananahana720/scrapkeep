# smoke: solo timeout=600s (three stage-3 bot runs in child processes at once, each cut at RUN_CAP_S; a loaded machine slows them)
extends "res://tools/bot_run.gd"

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")

# KF-BOT (wardens/swarm.md section 4; PARK.md section 7): the skipper bot's latch arm against a
# Warden that is a harpoon anchor. The stage is stage 3's headframe hive on the alpha table, made
# an anchor with the swarm driver once it stands, as posture_bands_swarm_test's child does: the
# hive rides the hoist, out of ram reach 8 s in every 12. tools/bot_run.gd plays the stage (one
# process per seed, the grown arm: 540 start mass, the pilot seed % 3); this file is the parent
# and, with --latch-arm=1, the child. The bot's stage note carries what the hand did
# (tools/bot_driver.gd _anchor_fight): latch_bites (lines that took a hardpoint), latch_ride_s
# (seconds on the line), latch_shots (shots fired while on it) and drop_break (the Warden broke
# in a stagger in which the bot hauled from over the open point: the drop finisher).
# The mechanism, per seed: at least one latch, a ride of RIDE_SHARE_MIN of the stage time to the break,
# one shot from the line, and one haul that takes a posture chunk. Every count is printed per seed,
# and a zero fails; the drop finish is printed only (see the note at the end of _initialize).

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster"]
const SEEDS := [0, 1, 2]
const STAGE := 3
const MASS := 540
const RUN_CAP_S := 300.0
const TURN_S := 30.0
# 2026-10-22 (Gate lane, coordinator ruling A, #241 6329024348): 3.0 -> 2.5 s. The stage's new
# stage-3 Dig packs (dig_rig, dig_dispatch) end seed 0's fight sooner: the hive breaks at 38 s after
# 7 latches instead of 52 s after 19, and seed 0 (pylon_engineer) rides 2.7 s, every run. With the
# packs ablated it rides 10.8 s and passes. The floor checks that the arm works, not pacing; the
# planted controls below keep a 0 s ride or no latch failing. Wave 19: a fixed pack for this test.
# 2026-10-24 (coordinator ruling, #427): 2.5 -> 2.0 s. The hive's heavy stagger (a grown build's smashing ram
# takes two chunks, alpha_defs.gd HIVE_HEAVY_RATIO) ends seed 0's fight sooner by design: broken at 34.96 s
# after 5 latches and a 2.0 s ride, three solo runs identical, against 38.47 s, 7 latches and 2.7 s on the
# base. Not lowered a third time: if the grown fight shortens again, this check becomes a ride-to-fight ratio.
# 2026-11-08 (invariants thread, ruling bh, #619 seed streams): the ride is now a share of the stage time to
# the break (warden_broken_s, the same quantity as every "broken at" below; it includes the approach). #619 gave
# each stage its own random stream, so seed 0 plays a different stage-3 fight: broken at 27.1 s on a drop
# finisher after 5 latches, 8 shots from the line and 3 haul chunks, with a 1.6 s ride. The share holds where
# the seconds did not: 2.7 / 38.47 = 0.070 (w18), 2.0 / 34.96 = 0.057 (#427), 1.6 / 27.1 = 0.059 (now);
# seeds 1 and 2 ride 9.5 / 28.4 and 3.0 / 19.3. A fight that never breaks counts RUN_CAP_S.
const RIDE_SHARE_MIN := 0.05
const DRIVER_PATH := "res://src/combat/warden_swarm.gd"

var _child := false
var _hoisted = null


func _initialize() -> void:
	if _parse(OS.get_cmdline_user_args()).get("latch-arm", "") == "1":
		_child = true
		super._initialize()
		return
	var t := T.new("bot_latch_arm_test")
	# Planted controls: the per-seed rule must still reject a broken arm at the share.
	t.check("planted: a 0 s ride fails", not _mechanism(3, 0.0, 2, 2, 27.1)["ride"], "ride 0.0 s")
	t.check("planted: a ride just under the share fails", not _mechanism(3, RIDE_SHARE_MIN * 27.1 - 0.1, 2, 2, 27.1)["ride"],
		"ride %.2f s of a 27.1 s fight" % (RIDE_SHARE_MIN * 27.1 - 0.1))
	t.check("planted: a long fight needs a longer ride", not _mechanism(3, 1.6, 2, 2, 60.0)["ride"], "1.6 s of a 60 s fight")
	t.check("planted: no latch fails", not _mechanism(0, 0.0, 0, 0, 27.1)["latch"], "0 latches")
	t.check("planted: a working arm passes", _mechanism(5, 1.6, 8, 3, 27.1).values().all(func(v): return v), "5 latches, 1.6 s of 27.1 s, 8 shots, 3 chunks")
	var folder := OS.get_user_data_dir().path_join("bot-latch-arm-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	var outs := []
	for run_seed in SEEDS:
		var out := folder.path_join("seed-%d" % run_seed)
		jobs.append({"script": "res://tests/bot_latch_arm_test.gd", "args": ["--latch-arm=1", "--out=" + out, "--policy=skipper",
			"--seeds=%d" % run_seed, "--pilot=" + String(PILOTS[run_seed % PILOTS.size()]), "--table=alpha",
			"--from-stage=%d" % STAGE, "--until=%d" % STAGE, "--start-mass=%d" % MASS,
			"--ticks=%d" % roundi((RUN_CAP_S + TURN_S) * Engine.physics_ticks_per_second)]})
		outs.append(out)
	var results := ChildRuns.run(jobs, 600.0)
	var drops := 0
	for i in results.size():
		var run_seed: int = SEEDS[i]
		t.check("seed %d ran" % run_seed, results[i]["code"] == 0 and not results[i]["timed_out"],
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
		var note := _stage_note(outs[i])
		var hoisted := FileAccess.file_exists(String(outs[i]).path_join("anchor.txt"))
		var bites := int(note.get("latch_bites", 0))
		var ride := float(note.get("latch_ride_s", 0.0))
		var shots := int(note.get("latch_shots", 0))
		var hauls := int(note.get("latch_hauls", 0))
		var chunks := int(note.get("latch_chunks", 0))
		var drop: bool = note.get("drop_break", false) == true
		var broke = note.get("warden_broken_s")
		if drop:
			drops += 1
		print("latch arm seed %d (%s): latches %d (air %d), ride %.1f s, shots from the line %d, hauls %d, chunks from a haul %d, drop hauls %d, drop chunks %d, broken at %s, drop break %s" % [
			run_seed, PILOTS[run_seed % PILOTS.size()], bites, int(note.get("latch_bites_air", 0)), ride, shots, hauls, chunks,
			int(note.get("drop_hauls", 0)), int(note.get("drop_chunks", 0)), broke, drop])
		t.check("seed %d fought an anchor hive on the hoist" % run_seed, hoisted, "anchor.txt written %s" % hoisted)
		var fight := minf(float(broke), RUN_CAP_S) if broke != null else RUN_CAP_S
		var held := _mechanism(bites, ride, shots, chunks, fight)
		t.check("seed %d latches a hardpoint" % run_seed, held["latch"], "%d latches" % bites)
		t.check("seed %d rides the line %d%% of the stage time to the break" % [run_seed, roundi(RIDE_SHARE_MIN * 100.0)], held["ride"],
			"%.1f s on the line, broken at %.1f s (%.3f)" % [ride, fight, ride / maxf(fight, 0.001)])
		t.check("seed %d fires from the line" % run_seed, held["shot"], "%d shots" % shots)
		t.check("seed %d takes a chunk with a haul" % run_seed, held["haul"], "%d hauls, %d chunks from a haul" % [hauls, chunks])
	# 2026-10-11 (KF-BOT merge): the drop finish is printed, not checked. Seed 0 plays a different fight
	# on repeat runs (broken at 108.9, 139.6 and 192.0 s on one head), so a gate on it alone fails at
	# random; seeds 1 and 2 never set it. The haul-chunk check above carries the finish: 2 to 4 on every
	# seed in all five head runs, 0 on every seed with the haul removed (mutation b). Seed 0's drift is a
	# follow-up card (a clock or unordered read in the run).
	print("drop finish: %d of %d seeds broke the hive in a stagger hauled from over the open point" % [drops, SEEDS.size()])
	if t.failures == 0:
		_remove_tree(folder)
	quit(t.verdict())


# The per-seed mechanism rule, one place for the run checks and the planted controls.
static func _mechanism(bites: int, ride: float, shots: int, chunks: int, fight: float) -> Dictionary:
	return {"latch": bites >= 1, "ride": ride > 0.0 and ride >= RIDE_SHARE_MIN * fight, "shot": shots >= 1, "haul": chunks >= 1}


# The child: bot_run, with the stage's swarm Warden made an anchor on the hoist.
func _physics_process(delta: float) -> bool:
	if not _child:
		return false
	_anchor_live()
	# The run ends at the break, as posture_sweep.gd ends it: what follows (the gates, stage 4)
	# is not this test's, and the swarm driver's strike listener outlives the freed hive there.
	if _driver != null and _driver.outcome == "" and _driver.warden_broken():
		_driver._end("broken")
	return super._physics_process(delta)


func _anchor_live() -> void:
	if _game == null or _game.flow == null or _game.run.stage != STAGE:
		return
	var warden = _game.flow.get("warden")
	if not is_instance_valid(warden) or warden.get("family") != "swarm" or warden == _hoisted:
		return
	if not ResourceLoader.exists(DRIVER_PATH):
		return
	warden.set_harpoon_anchor(true)
	warden.set_mount_driver(load(DRIVER_PATH).new())
	_hoisted = warden
	var file := FileAccess.open(_out.path_join("anchor.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string("%s %s\n" % [DRIVER_PATH, warden.harpoon_anchor])


func _stage_note(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	if not FileAccess.file_exists(path):
		return {}
	var lines := FileAccess.get_file_as_string(path).split("\n", false)
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	if not record is Dictionary:
		return {}
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == STAGE:
			return note
	return {}


static func _remove_tree(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
