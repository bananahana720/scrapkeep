# smoke: bots timeout=1800s (five stage-3 bot runs in child processes, two at a time, about 60 s each alone)
extends "res://tools/band_run.gd"

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const T := preload("res://tests/support/t.gd")

# Challenge lane unit C3-hoist: the bot's hoist ram-at-dwell hand (tools/bot_driver.gd _hoist_hand; the
# "hoist_ram" verb in tools/skill_band.gd). The stage-3 Warden is the swarm hive on the hoist; at its
# low dwell it hangs level with the pit's shelf but 36 m in, so the hand flies the ball off the rim at
# it with punch at or over the plating (130), where a latch-ride's contacts land under.
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
#            so the old driver did not land that ram.
#   novice   no hoist keys: the Novice does not run the hand.
#   learner  the base kit at its fifth attempt runs the hand: its kit allows it and the run is clean
#            (its read roll is per cycle, so a count is printed, not asserted).
# This file is the parent and, with --hoist-child=1, the child: band_run, with the control switch.

const ENTRANCE := "res://tests/fixtures/hoist_entrance_stage3.json"
const STAGE := 3
const SEED := 40500
# The fight clock starts when the bot commits to the Warden, at the stage start; the hive is engaged near 48 s.
const FIGHT_S := 75.0
const RAM_BY_S := 20.0
const TICKS := 8600
const WALL_S := 900.0
const IGNORED := ["wall_seconds", "run_id", "band"]
const HOIST_KEYS := ["hoist_rams", "hoist_glance", "hoist_stomps", "hoist_last_punch", "hoist_last_kind", "hoist_last_s"]

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


func _runs(t) -> void:
	var folder := OS.get_user_data_dir().path_join("hoist-ram-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var labels := ["expert", "plain", "off", "novice", "learner"]
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
	t.check("the ram lands within %.0f s of engagement" % RAM_BY_S, last_s > 0.0 and last_s - engaged <= RAM_BY_S,
		"engaged %.2f s, last %.2f s" % [engaged, last_s])
	t.check("the hand switched off records no hoist contact", _hoist_counts(rows["off"]) == 0, "keys %s" % [_hoist_keys(rows["off"])])
	t.check("the novice records no hoist contact", _hoist_counts(rows["novice"]) == 0, "keys %s" % [_hoist_keys(rows["novice"])])
	var plain: Dictionary = _strip(rows["plain"])
	var banded: Dictionary = _strip(rows["expert"])
	t.check("the expert's row equals the unbanded row on a Warden-3 fight", plain == banded, "differs in %s" % [_differing(plain, banded)])
	print("[report] learner a5: hoist_rams %d, hoist_glance %d" % [int(_note(rows["learner"]).get("hoist_rams", 0)), int(_note(rows["learner"]).get("hoist_glance", 0))])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)


func _job(folder: String, label: String) -> Dictionary:
	var args := ["--hoist-child=1", "--out=" + folder.path_join(label), "--policy=skipper", "--seeds=%d" % SEED, "--table=park", "--gate=1",
		"--entrance=" + ProjectSettings.globalize_path(ENTRANCE), "--from-stage=%d" % STAGE, "--until=%d" % STAGE,
		"--fight-limit=%d" % roundi(FIGHT_S), "--stage-limit=600", "--ticks=%d" % TICKS]
	match label:
		"expert", "off":
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
