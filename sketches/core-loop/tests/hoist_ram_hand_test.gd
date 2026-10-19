# smoke: bots timeout=1800s (six stage-3 bot runs in child processes, two at a time, about 60 s each alone, the tarn's 150 s fight longer)
extends "res://tools/band_run.gd"

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const T := preload("res://tests/support/t.gd")

# Challenge lane unit C3-hoist: the bot's hoist ram-at-dwell hand (tools/bot_driver.gd _hoist_hand; the
# "hoist_ram" verb in tools/skill_band.gd). The stage-3 Warden is the swarm hive on the hoist; at its
# low dwell it hangs level with the pit's shelf but 36 m in, so the hand flies the ball off the rim at
# it with punch at or over the posture rule's stagger threshold, where a latch-ride's contacts land under.
#
# The unit half checks the kit gate: Novice never selects the hand, Learner and Expert can, and the
# Expert's band plays like no band (an Expert reads every tell, so its stream is never touched).
# The run half plays one deterministic stage-3 fight five ways from a saved entrance (the build
# library's pylon_engineer at heft class 4, tests/fixtures/hoist_entrance_stage3.json, seed 40500),
# each cut FIGHT_S after the bot commits to the Warden (about 25 s after the engagement):
#   expert   the band's full kit: the hand lands a ram at or over the plating within RAM_BY_S of the
#            engagement, and records hoist_rams, hoist_glance and its last contact.
#   plain    no band: the same row as the expert (bar wall time, run id and the band's own record).
#   off      the Expert with the hand switched off (hoist-hand=0, the control switch): no hoist keys,
#            so the switch really turns the hand off.
#   novice   no hoist keys: the Novice does not run the hand.
#   learner  the base kit at its fifth attempt runs the hand: its kit allows it and the run is clean
#            (its read roll is per cycle, so a count is printed, not asserted).
#   tarn     the Expert from an ordinary build's entrance (a tarn at heft class 2 of the challenge library, below).
# This file is the parent and, with --hoist-child=1, the child: band_run, with the control switch.
#
# The tarn fixture, tests/fixtures/hoist_entrance_stage3_tarn.json, is artifacts/challenge-lib/lib-base/s3/
# tarn-skipper-9001.json of the challenge library (run seed 1598811041, the same pit as the pylon fixture's
# seed; heft 2.19 at the Warden). --seeds=40500 is the bot's own seed for the resume, not the document's run
# seed (the document carries that). The ordinary build is not yet landing a staggering ram from its run in:
# its run clips the headframe landmark's collider (Landmark_headframe StaticBody3D "Collider", the -col meshes
# of assets/models/park/landmark_headframe.glb, park_recipes.gd:793; the frame has six legs) about 15 m from the
# hive (the pylon, at heft class 4, flies over it), so TARN_RAMS_REQUIRED is false and the row is reported, with
# its checks on the record's shape only. Set it true once the arc clears the frame.

const ENTRANCE := "res://tests/fixtures/hoist_entrance_stage3.json"
const STAGE := 3
const SEED := 40500
const TARN_ENTRANCE := "res://tests/fixtures/hoist_entrance_stage3_tarn.json"
const TARN_FIGHT_S := 150.0
const TARN_TICKS := 19000
const TARN_RAMS_REQUIRED := false
# The fight clock starts when the bot commits to the Warden, at the stage start; the hive is engaged near 48 s.
const FIGHT_S := 75.0
const RAM_BY_S := 20.0
const TICKS := 8600
const WALL_S := 900.0
const IGNORED := ["wall_seconds", "run_id", "band"]
const HOIST_KEYS := ["hoist_rams", "hoist_glance", "hoist_stomps", "hoist_last_punch", "hoist_last_kind", "hoist_last_s", "hoist_last_staggered"]

var _child := false


func _initialize() -> void:
	if _parse(OS.get_cmdline_user_args()).get("hoist-child", "") == "1":
		_child = true
		super._initialize()
		return
	var t := T.new("hoist_ram_hand_test")
	_unit(t)
	_runs(t)
	quit(t.verdict())


# The child: band_run, and the hoist hand's control switch when --hoist-hand=0.
func _physics_process(delta: float) -> bool:
	if not _child:
		return false
	if _driver != null and String(_settings.get("hoist-hand", "1")) == "0":
		_driver.hoist_hand_enabled = false
	return super._physics_process(delta)


func _unit(t) -> void:
	var novice = SkillBand.make("novice", 1, 7)
	var learner = SkillBand.make("learner", 1, 7)
	var learner5 = SkillBand.make("learner", 5, 7)
	var expert = SkillBand.make("expert", 1, 7)
	t.check("novice never selects the hoist hand", not novice.allows("hoist_ram"), "kit %s" % novice.kit)
	t.check("learner can select the hoist hand", learner.allows("hoist_ram") and learner5.allows("hoist_ram"), "kit %s" % learner.kit)
	t.check("expert can select the hoist hand", expert.allows("hoist_ram"), "kit %s" % expert.kit)
	# The new verb moves no other gate: the base kit is the old base kit and the Novice has none of it.
	t.check("the hoist verb changes no other verb's gate",
		not novice.allows("harpoon") and learner.allows("harpoon") and not learner.allows("active") and not learner.allows("chain")
		and expert.allows("active") and expert.allows("chain"), "gates moved")
	# The read roll is per hoist cycle: an Expert reads all of them and leaves its stream alone, a Learner's
	# answer is stable per cycle key.
	var before: int = expert._rng.state
	var all_read := true
	for cycle in 40:
		all_read = all_read and expert.reads(7001 * 1000 + cycle)
	t.check("expert reads every hoist cycle without touching its stream", all_read and expert._rng.state == before)
	var again = SkillBand.make("learner", 1, 7)
	t.check("a learner's read of a cycle is stable", again.reads(7001 * 1000 + 3) == learner.reads(7001 * 1000 + 3))
	_unit_pace(t)


# The learned pace cannot lock the hand: after a slow, non-staggering go a later cycle's window still holds.
func _unit_pace(t) -> void:
	var stub = GDScript.new()
	stub.source_code = "extends RefCounted\nvar bot_driven := false\n"
	stub.reload()
	var driver = BotDriver.new(stub.new(), "skipper", 1)
	var cruise := 14.0
	var floor_pace: float = cruise * BotDriver.HOIST_PACE
	driver._hoist_pace = 2.0
	t.check("a slow learned pace is floored at cruise times the pace margin", driver._hoist_run_pace(cruise) == floor_pace, "pace %s" % driver._hoist_run_pace(cruise))
	driver._hoist_pace = 40.0
	t.check("a fast learned pace is kept", driver._hoist_run_pace(cruise) == 40.0, "pace %s" % driver._hoist_run_pace(cruise))
	# A mid-window start (cue 3 s into a 6 s rest dwell, 60 m out) needs less than the floor, so the go is not refused.
	driver._hoist_to_low = BotDriver.HOIST_TO_LOW_REST
	driver._hoist_cue_s = 3.0
	driver._hoist_pace = 2.0
	var refused: bool = driver._hoist_arc_speed_at(60.0, cruise) > driver._hoist_run_pace(cruise)
	t.check("a later cycle still runs after a slow learned pace", not refused,
		"arc %.1f vs pace %.1f" % [driver._hoist_arc_speed_at(60.0, cruise), driver._hoist_run_pace(cruise)])
	driver._hoist_forget_pace()
	t.check("a go that ends without a staggering contact drops the learned pace", driver._hoist_pace == 0.0 and driver._hoist_run_pace(cruise) == floor_pace,
		"pace %s" % driver._hoist_pace)
	driver._hoist_rose = true
	driver._hoist_wait_s = 5.0
	driver._hoist_released = true
	driver._hoist_pace = 3.0
	driver._hoist_reset()
	t.check("a target change clears the rise mark, the wait and the pace", not driver._hoist_rose and driver._hoist_wait_s == 0.0 and not driver._hoist_released and driver._hoist_pace == 0.0,
		"rose %s, wait %s" % [driver._hoist_rose, driver._hoist_wait_s])
	var held := true
	for i in 100:
		held = held and not driver._hoist_wait(0.25)
	t.check("the hand holds the stage for up to the wait limit", held and not driver._hoist_released, "waited %s" % driver._hoist_wait_s)
	for i in 40:
		driver._hoist_wait(0.25)
	t.check("past the wait limit the hand releases the stick to the line arm", driver._hoist_released, "waited %s" % driver._hoist_wait_s)
	driver._hoist_new_cycle()
	t.check("the next cycle takes the stick back and starts its own wait", not driver._hoist_released and driver._hoist_wait_s == 0.0,
		"released %s, wait %s" % [driver._hoist_released, driver._hoist_wait_s])
	t.check("one tick into the new cycle the hand still holds the stage", not driver._hoist_wait(1.0 / 90.0), "wait %s" % driver._hoist_wait_s)


func _runs(t) -> void:
	var folder := OS.get_user_data_dir().path_join("hoist-ram-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var labels := ["expert", "plain", "off", "novice", "learner", "tarn"]
	var jobs := []
	for label in labels:
		jobs.append(_job(folder, label))
	var results := ChildRuns.run(jobs, WALL_S, 2)
	var rows := {}
	for i in labels.size():
		rows[labels[i]] = _record(folder.path_join(labels[i]))
		t.check("%s ran" % labels[i], results[i]["code"] == 0 and not results[i]["timed_out"] and not (rows[labels[i]] as Dictionary).is_empty(),
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
		t.check("%s resumed the entrance and fought the hive" % labels[i], rows[labels[i]].get("resumed") == true and _note(rows[labels[i]]).get("warden_engaged_s") != null,
			"resumed %s, engaged %s" % [rows[labels[i]].get("resumed"), _note(rows[labels[i]]).get("warden_engaged_s")])
		for line in String(results[i]["log"]).split("\n"):
			if line.contains("SCRIPT ERROR") or line.begins_with("ERROR") or line.contains("FAIL"):
				t.check("%s prints no error line" % labels[i], false, line)
	# The Expert lands a ram at or over the plating at a dwell, soon after engagement; the same run with the hand off has no hoist keys.
	var note := _note(rows["expert"])
	var engaged := float(note.get("warden_engaged_s", 0.0)) if note.get("warden_engaged_s") != null else 0.0
	var rams := int(note.get("hoist_rams", 0))
	var last_s := float(note.get("hoist_last_s", 0.0)) if note.get("hoist_last_s") != null else 0.0
	print("[report] expert: hoist_rams %d, hoist_glance %d, stomps %d, last %s at %.2f s (engaged %.2f s), punch %s vs plating %s" % [
		rams, int(note.get("hoist_glance", 0)), int(note.get("hoist_stomps", 0)), note.get("hoist_last_kind"), last_s, engaged,
		note.get("hoist_last_punch"), note.get("hoist_last_plating")])
	t.check("the expert's hand lands a ram over the plating", rams >= 1 and float(note.get("hoist_last_punch", 0.0)) >= float(note.get("hoist_last_plating", 1.0)),
		"hoist_rams %d, last punch %s, plating %s" % [rams, note.get("hoist_last_punch"), note.get("hoist_last_plating")])
	t.check("the ram is a contact that staggered the Warden", note.get("hoist_last_staggered") == true,
		"last staggered %s" % note.get("hoist_last_staggered"))
	t.check("the ram lands within %.0f s of engagement" % RAM_BY_S, last_s > 0.0 and last_s - engaged <= RAM_BY_S,
		"engaged %.2f s, last %.2f s" % [engaged, last_s])
	t.check("the hand switched off records no hoist contact", _hoist_counts(rows["off"]) == 0, "keys %s" % [_hoist_keys(rows["off"])])
	t.check("the novice records no hoist contact", _hoist_counts(rows["novice"]) == 0, "keys %s" % [_hoist_keys(rows["novice"])])
	var plain: Dictionary = _strip(rows["plain"])
	var banded: Dictionary = _strip(rows["expert"])
	t.check("the expert's row equals the unbanded row on a Warden-3 fight", plain == banded, "differs in %s" % [_differing(plain, banded)])
	_tarn(t, rows["tarn"])
	print("[report] learner a5: hoist_rams %d, hoist_glance %d" % [int(_note(rows["learner"]).get("hoist_rams", 0)), int(_note(rows["learner"]).get("hoist_glance", 0))])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)


# The ordinary build's row: it ran, resumed and fought the hive (checked per label) and any hoist contact is a ram or stomp after engagement; a staggering ram is required only
# once TARN_RAMS_REQUIRED is on.
func _tarn(t, row: Dictionary) -> void:
	var note := _note(row)
	var engaged := float(note.get("warden_engaged_s", 0.0)) if note.get("warden_engaged_s") != null else 0.0
	var last_s := float(note.get("hoist_last_s", 0.0)) if note.get("hoist_last_s") != null else 0.0
	print("[report] tarn: hoist_rams %d, hoist_glance %d, last %s staggered %s at %.2f s (engaged %.2f s), heft %s, learned pace %s" % [
		int(note.get("hoist_rams", 0)), int(note.get("hoist_glance", 0)), note.get("hoist_last_kind"), note.get("hoist_last_staggered"),
		last_s, engaged, note.get("warden_fight_heft"), note.get("hoist_pace")])
	var counted := _hoist_counts(row) > 0
	t.check("the tarn's hoist record has a ram or stomp contact at or after engagement when any is counted",
		not counted or (note.get("hoist_last_kind") in ["ram", "stomp"] and last_s >= engaged),
		"kind %s, last %.2f s, engaged %.2f s" % [note.get("hoist_last_kind"), last_s, engaged])
	if TARN_RAMS_REQUIRED:
		t.check("the tarn's hand lands a staggering ram within the fight limit", int(note.get("hoist_rams", 0)) >= 1 and last_s > 0.0,
			"hoist_rams %s, glance %s" % [note.get("hoist_rams"), note.get("hoist_glance")])


func _job(folder: String, label: String) -> Dictionary:
	var entrance := TARN_ENTRANCE if label == "tarn" else ENTRANCE
	var fight := TARN_FIGHT_S if label == "tarn" else FIGHT_S
	var ticks := TARN_TICKS if label == "tarn" else TICKS
	var args := ["--hoist-child=1", "--out=" + folder.path_join(label), "--policy=skipper", "--seeds=%d" % SEED, "--table=park", "--gate=1",
		"--entrance=" + ProjectSettings.globalize_path(entrance), "--from-stage=%d" % STAGE, "--until=%d" % STAGE,
		"--fight-limit=%d" % roundi(fight), "--stage-limit=600", "--ticks=%d" % ticks]
	match label:
		"expert", "off", "tarn":
			args.append("--band=expert")
		"novice":
			args.append("--band=novice")
		"learner":
			args.append_array(["--band=learner", "--attempt=5"])
	if label == "off":
		args.append("--hoist-hand=0")
	return {"script": "res://tests/hoist_ram_hand_test.gd", "args": args}


func _record(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	return record if record is Dictionary else {}


# The stage-3 note of a row.
func _note(record: Dictionary) -> Dictionary:
	for note in record.get("stages", []):
		if int(note.get("stage", 0)) == STAGE:
			return note
	return {}


func _hoist_keys(record: Dictionary) -> Array:
	var out := []
	for key in HOIST_KEYS:
		if _note(record).has(key):
			out.append(key)
	return out


func _hoist_counts(record: Dictionary) -> int:
	var note := _note(record)
	return int(note.get("hoist_rams", 0)) + int(note.get("hoist_glance", 0)) + int(note.get("hoist_stomps", 0))


func _strip(record: Dictionary) -> Dictionary:
	var out := record.duplicate(true)
	for key in IGNORED:
		out.erase(key)
	return out


func _differing(a: Dictionary, b: Dictionary) -> Array:
	var keys := []
	for key in a:
		if not b.has(key) or a[key] != b[key]:
			keys.append(key)
	for key in b:
		if not a.has(key):
			keys.append(key)
	return keys
