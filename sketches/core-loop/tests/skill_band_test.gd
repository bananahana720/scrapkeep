# smoke: bots timeout=1800s (eighteen park bot runs in child processes, four at a time, about 100 s each alone)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SkillBand := preload("res://tools/skill_band.gd")
const PostureSweep := preload("res://tools/posture_sweep.gd")
const T := preload("res://tests/support/t.gd")

# Challenge lane unit C1 (DECISIONS section 5): the skill bands. The unit half checks the table's
# interpolation, the read roll and the verb gates. The identity half is the calibration claim that
# existing persona results do not move at Expert: three policies on two seeds run once with no band
# and once with --band=expert must leave equal rows, bar the fields that are wall time, the run id
# or the band's own record. The contrast half checks the Novice's hands (no kit casts, no ultimate, no bites)
# and reports one seed's hull lost per band; one run's hull does not order the bands (ruling bi).

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
	var learner_attempts := {1: [0.45, 0.65, 0.25], 3: [0.375, 0.785, 0.35], 5: [0.30, 0.92, 0.45], 9: [0.30, 0.92, 0.45]}
	for attempt in learner_attempts:
		var band = SkillBand.make("learner", attempt, 7)
		t.near("learner attempt %d reaction" % attempt, band.reaction_s, learner_attempts[attempt][0])
		t.near("learner attempt %d read chance" % attempt, band.read_chance, learner_attempts[attempt][1])
		t.near("learner attempt %d window share" % attempt, band.window_share, learner_attempts[attempt][2])
		t.near("learner attempt %d describe window_share" % attempt, float(band.describe().get("window_share", -1.0)), learner_attempts[attempt][2])
	var expert = SkillBand.make("expert", 4, 7)
	t.near("expert window share", expert.window_share, 0.85)
	t.near("expert describe window_share", float(expert.describe().get("window_share", -1.0)), 0.85)
	var before: int = expert._rng.state
	var all_read := true
	for key in 500:
		all_read = all_read and expert.reads(key)
		expert.hits_window(key)
	t.check("expert reads every tell and rolls windows without touching its stream", all_read and expert._rng.state == before,
		"state %d -> %d" % [before, expert._rng.state])
	var novice = SkillBand.make("novice", 1, 7)
	t.near("novice window share", novice.window_share, 0.15)
	t.near("novice describe window_share", float(novice.describe().get("window_share", -1.0)), 0.15)
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
	# A typo plays the Expert; the refusal is recorded quietly here, so no ERROR line reaches the smoke.
	SkillBand.quiet = true
	var fallback = SkillBand.make("nonesuch", 1, 7)
	SkillBand.quiet = false
	t.check("an unknown band is refused with its name", SkillBand.last_refusal.contains("nonesuch"))
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
	labels.append("skipper-1-learner5")
	jobs.append(_job(folder, labels[-1], "skipper", 1, "learner", "", 5))
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
	# The Novice has no slot casts, no ultimate presses, no active presses and no harpoon or latch bites.
	for label in ["skipper-1-novice", "tally-1-novice"]:
		var row: Dictionary = rows[label]
		var casts: Dictionary = row.get("slot_casts", {})
		var bites := _counted(row, ["harpoon_bites", "latch_bites", "latch_presses"])
		t.check("%s uses no kit hands" % label, int(casts.get("special", -1)) == 0 and int(casts.get("line", -1)) == 0
				and int(row.get("ult_presses", -1)) == 0 and int(row.get("active_presses", -1)) == 0 and bites == 0,
			"casts %s, ult presses %s, active presses %s, bites %d" % [casts, row.get("ult_presses"), row.get("active_presses"), bites])
		t.eq("%s records its band" % label, [row["band"]["name"], int(row["band"]["attempt"])], ["novice", 1])
	t.eq("learner records its band", [rows["skipper-1-learner"]["band"]["name"], int(rows["skipper-1-learner"]["band"]["attempt"])], ["learner", 1])
	t.eq("learner attempt 1 sends no active presses", int(rows["skipper-1-learner"].get("active_presses", -1)), 0)
	t.check("the row's reaction_s is the band's", absf(float(rows["skipper-1-learner"].get("reaction_s", 0.0)) - 0.45) < 0.001,
		"reaction_s %s" % [rows["skipper-1-learner"].get("reaction_s")])
	var fifth: Dictionary = rows["skipper-1-learner5"].get("band", {})
	t.check("learner --attempt=5 reaches its last values", int(fifth.get("attempt", 0)) == 5
			and absf(float(fifth.get("reaction_s", 0.0)) - 0.30) < 0.001
			and absf(float(fifth.get("window_share", 0.0)) - 0.45) < 0.001,
		"band %s" % [fifth])
	t.eq("learner attempt 5 sends no active presses", int(rows["skipper-1-learner5"].get("active_presses", -1)), 0)
	var banded: Dictionary = rows["skipper-1-expert"]
	t.check("a banded row records its band", (banded.get("band") as Dictionary).get("name", "") == "expert"
			and rows["skipper-1-plain"].get("band") == null, "band %s" % [banded.get("band")])
	print("[report] skipper seed 1 evasions: expert %d, novice %d, learner %d; outcomes expert %s, novice %s, learner %s" % [
		_evasions(rows["skipper-1-expert"]), _evasions(rows["skipper-1-novice"]), _evasions(rows["skipper-1-learner"]), rows["skipper-1-expert"].get("outcome"),
		rows["skipper-1-novice"].get("outcome"), rows["skipper-1-learner"].get("outcome")])
	# Evasions count the tells that threatened the ball, which a worse dodger meets more of (it
	# stands in more of them), so they do not order the bands, and one run's hull does not either.
	# 2026-11-08 (invariants thread, ruling bi, #619 seed streams): the "novice loses at least as much
	# hull as expert" check is now a report. Skipper seed 1 expert, same tree, two runs side by side:
	# 18.0 and 0.0 hull lost, so the order was a coin flip (the owed skill_band flip). Over seeds 1 to 6
	# novice >= expert held 5 of 6 before #619 and 3 of 6 after; summed hull, novice 51 / expert 25
	# before and 55 / 66 after. The bands' order is read where it is stable: clear rates over many
	# seeds in the gate's band reads (W1 Novice <= 42 percent, rulings ab and bk), not one run here.
	var hull_expert := float(rows["skipper-1-expert"]["max_hp"]) - float(rows["skipper-1-expert"]["min_hp"])
	var hull_novice := float(rows["skipper-1-novice"]["max_hp"]) - float(rows["skipper-1-novice"]["min_hp"])
	print("[report] skipper seed 1 hull lost: expert %.1f, novice %.1f" % [hull_expert, hull_novice])
	if t.failures == 0:
		PostureSweep._remove_tree(folder)


func _job(folder: String, label: String, policy: String, run_seed: int, band: String, pilot := "", attempt := 0) -> Dictionary:
	var args := ["--out=" + folder.path_join(label), "--policy=" + policy, "--seeds=%d" % run_seed, "--table=park",
		"--gate=1", "--ticks=%d" % TICKS]
	if band != "":
		args.append("--band=" + band)
	if attempt > 0:
		args.append("--attempt=%d" % attempt)
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


func _counted(record: Dictionary, names: Array) -> int:
	var total := 0
	var notes: Array = (record.get("stages", []) as Array).duplicate()
	if record.get("boss") is Dictionary:
		notes.append(record["boss"])
	for note in notes:
		for key in names:
			total += int(note.get(key, 0))
	return total


func _evasions(record: Dictionary) -> int:
	var total := 0
	for note in record.get("stages", []):
		total += int(note.get("evasions", 0))
	var boss = record.get("boss")
	if boss is Dictionary:
		total += int(boss.get("evasions", 0))
	return total
