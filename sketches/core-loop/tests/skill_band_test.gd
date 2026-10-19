# smoke: bots timeout=1800s (seventeen park bot runs in child processes, four at a time, about 100 s each alone)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const T := preload("res://tests/support/t.gd")

# Challenge lane unit C1 (DECISIONS section 5): the skill bands. The unit half checks the table's
# interpolation, the read roll and the verb gates. The identity half is the calibration claim that
# existing persona results do not move at Expert: three policies on two seeds run once with no band
# and once with --band=expert must leave equal rows, bar the fields that are wall time, the run id
# or the band's own record. The contrast half checks a Novice takes at least as much hull damage as an Expert.

const POLICIES := ["skipper", "completionist", "camper"]
# Tally's weapon is the card hand; a band must not take her throws away.
const TALLY := "tally"
const SEEDS := [1, 2]
const TICKS := 9000
const WALL_S := 900.0
# The fields allowed to differ between a banded and an unbanded row.
const IGNORED := ["wall_seconds", "run_id", "band"]


func _initialize() -> void:
	var t := T.new("skill_band_test")
	_unit(t)
	_runs(t)
	quit(t.verdict())


func _unit(t) -> void:
	var learner_attempts := {1: [0.45, 0.65], 3: [0.375, 0.785], 5: [0.30, 0.92], 9: [0.30, 0.92]}
	for attempt in learner_attempts:
		var band = SkillBand.make("learner", attempt, 7)
		t.near("learner attempt %d reaction" % attempt, band.reaction_s, learner_attempts[attempt][0])
		t.near("learner attempt %d read chance" % attempt, band.read_chance, learner_attempts[attempt][1])
	var expert = SkillBand.make("expert", 4, 7)
	var before: int = expert._rng.state
	var all_read := true
	for key in 500:
		all_read = all_read and expert.reads(key)
	t.check("expert reads every tell without touching its stream", all_read and expert._rng.state == before,
		"state %d -> %d" % [before, expert._rng.state])
	var novice = SkillBand.make("novice", 1, 7)
	var gave := []
	for verb in ["special", "line_cast", "plant", "harpoon", "weak_points", "ultimate", "active", "chain"]:
		if novice.allows(verb):
			gave.append(verb)
	t.check("novice allows none of the kit verbs", gave.is_empty(), "allowed %s" % [gave])
	var learner = SkillBand.make("learner", 1, 7)
	t.check("learner has the base kit, untimed ultimate, no actives or chain",
		learner.allows("special") and learner.allows("line_cast") and learner.allows("plant") and learner.allows("harpoon")
		and learner.allows("weak_points") and learner.allows("ultimate") and not learner.timed_ultimate()
		and not learner.allows("active") and not learner.allows("chain"), "kit %s" % learner.kit)
	t.check("expert allows everything and times the ultimate", expert.allows("active") and expert.allows("chain") and expert.timed_ultimate())
	var read := 0
	for key in 2000:
		if learner.reads(key):
			read += 1
	var rate := float(read) / 2000.0
	t.check("learner read rate matches its chance", absf(rate - learner.read_chance) <= 0.03,
		"rate %.3f, chance %.3f" % [rate, learner.read_chance])
	var again = SkillBand.make("learner", 1, 7)
	t.check("a tell's answer is stable and the stream replays", again.reads(5) == learner.reads(5) and again.reads(5) == again.reads(5))
	# A typo plays the Expert; the push_error is the intended report.
	var fallback = SkillBand.make("nonesuch", 1, 7)
	t.eq("unknown band falls back to expert", fallback.name, "expert")


func _runs(t) -> void:
	var folder := OS.get_user_data_dir().path_join("skill-band-%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var jobs := []
	var labels := []
	for policy in POLICIES:
		for run_seed in SEEDS:
			for arm in ["plain", "expert"]:
				labels.append("%s-%d-%s" % [policy, run_seed, arm])
				jobs.append(_job(folder, labels[-1], policy, run_seed, "" if arm == "plain" else "expert"))
	for arm in ["plain", "expert", "novice"]:
		labels.append("tally-1-" + arm)
		jobs.append(_job(folder, labels[-1], "skipper", 1, "" if arm == "plain" else arm, TALLY))
	labels.append("skipper-1-novice")
	jobs.append(_job(folder, labels[-1], "skipper", 1, "novice"))
	labels.append("skipper-1-learner")
	jobs.append(_job(folder, labels[-1], "skipper", 1, "learner"))
	var results := ChildRuns.run(jobs, WALL_S, 4)
	var rows := {}
	for i in jobs.size():
		rows[labels[i]] = _record(folder.path_join(labels[i]))
		t.check("%s ran" % labels[i], results[i]["code"] == 0 and not results[i]["timed_out"] and not rows[labels[i]].is_empty(),
			"exit %s, timed out %s" % [results[i]["code"], results[i]["timed_out"]])
	for policy in POLICIES:
		for run_seed in SEEDS:
			var plain: Dictionary = _strip(rows["%s-%d-plain" % [policy, run_seed]])
			var expert: Dictionary = _strip(rows["%s-%d-expert" % [policy, run_seed]])
			t.check("%s seed %d: expert row equals the unbanded row" % [policy, run_seed], plain == expert,
				"differs in %s" % [_differing(plain, expert)])
	var tally_plain: Dictionary = _strip(rows["tally-1-plain"])
	var tally_expert: Dictionary = _strip(rows["tally-1-expert"])
	t.check("tally seed 1: expert row equals the unbanded row", tally_plain == tally_expert,
		"differs in %s" % [_differing(tally_plain, tally_expert)])
	var tally_shots := int(rows["tally-1-novice"].get("shots", 0))
	print("[report] tally seed 1 shots: plain %d, novice %d" % [int(rows["tally-1-plain"].get("shots", 0)), tally_shots])
	t.check("tally novice still throws cards", rows["tally-1-novice"].get("class") == "tally" and tally_shots > 0,
		"class %s, shots %d" % [rows["tally-1-novice"].get("class"), tally_shots])
	var banded: Dictionary = rows["skipper-1-expert"]
	t.check("a banded row records its band", (banded.get("band") as Dictionary).get("name", "") == "expert"
			and rows["skipper-1-plain"].get("band") == null, "band %s" % [banded.get("band")])
	print("[report] skipper seed 1 evasions: expert %d, novice %d, learner %d; outcomes expert %s, novice %s, learner %s" % [
		_evasions(rows["skipper-1-expert"]), _evasions(rows["skipper-1-novice"]), _evasions(rows["skipper-1-learner"]), rows["skipper-1-expert"].get("outcome"),
		rows["skipper-1-novice"].get("outcome"), rows["skipper-1-learner"].get("outcome")])
	# Evasions count the tells that threatened the ball, which a worse dodger meets more of (it
	# stands in more of them), so they do not order the bands; the hull does. Measured on this
	# seed: novice 4 evasions and 12 hull lost, expert 2 and none.
	var hull_expert := float(rows["skipper-1-expert"]["max_hp"]) - float(rows["skipper-1-expert"]["min_hp"])
	var hull_novice := float(rows["skipper-1-novice"]["max_hp"]) - float(rows["skipper-1-novice"]["min_hp"])
	print("[report] skipper seed 1 hull lost: expert %.1f, novice %.1f" % [hull_expert, hull_novice])
	t.check("novice loses at least as much hull as expert", hull_novice >= hull_expert,
		"novice %.1f, expert %.1f" % [hull_novice, hull_expert])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)


func _job(folder: String, label: String, policy: String, run_seed: int, band: String, pilot := "") -> Dictionary:
	var args := ["--out=" + folder.path_join(label), "--policy=" + policy, "--seeds=%d" % run_seed, "--table=park",
		"--gate=1", "--ticks=%d" % TICKS]
	if band != "":
		args.append("--band=" + band)
	if pilot != "":
		args.append("--pilot=" + pilot)
	return {"script": "res://tools/bot_run.gd", "args": args}


func _record(out: String) -> Dictionary:
	var path := out.path_join("bots.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	var record = JSON.parse_string(lines[0]) if not lines.is_empty() else null
	return record if record is Dictionary else {}


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


func _evasions(record: Dictionary) -> int:
	var total := 0
	for note in record.get("stages", []):
		total += int(note.get("evasions", 0))
	var boss = record.get("boss")
	if boss is Dictionary:
		total += int(boss.get("evasions", 0))
	return total
