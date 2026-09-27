extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# The balance report (DEMO-SPEC, "Balance report"). It reads what the bot runs left in
# one folder (tools/bot_run.gd): the spine's runs.ndjson and codex-log.ndjson, plus the
# runner's bots.ndjson and codex-entries.json. It prints per-stage bands, the boss fight,
# codex rates by policy, the bots' use of their hands, the tuning targets and the flags
# below, and writes the same Markdown to artifacts/local/balance-<label>.md. It reports
# and never tunes: tuning stays a human-approved edit to stage_defs, the heft constants
# or the part catalogue.
#
#   godot --headless --path sketches/core-loop --script res://tools/balance_report.gd \
#     -- --in=<dir> --label=<label> [--out-dir=<dir>]
#
# The Warden fight is timed from warden_engaged to the break: from the run log's
# ticks_to_warden_engaged when the spine records it, else from the bot's own note of
# the same signal. Time from stage entry is shown beside it.
#
# Flags:
#   - a Warden fight outside 10 to 90 s, or a Warden never broken (a stalled run);
#   - heft at stage exit outside the band read from build_power_curve_test's BUILDS table;
#   - a named synergy (codex category build) found in more than 60% of runs, below the
#     10% target, or in none;
#   - any codex entry no run discovered;
#   - a death cluster: two or more deaths on one stage within 15 m of each other.
#
# The heft band: the power-curve table describes end-of-run builds, from the skipper's
# (3 gate parts, mass 60) to the absurd one (17 parts, mass 700). A stage-s exit is read
# as s/3 of the way along each: parts and mass scale linearly with stages cleared. That
# interpolation is this report's assumption, stated in the report.
#
# TARGETS are the coordinator's tuning bands for wave 3b (starting values, like every
# number here); the report says which the runs hit, and changes nothing.

const BREAK_BAND := Vector2(10.0, 90.0)
const SYNERGY_SHARE := 0.6
const CLUSTER_METRES := 15.0
const POLICIES := ["skipper", "completionist", "random"]
const CURVE_TEST := "res://tests/build_power_curve_test.gd"
const LOW_BUILD := "skipper"
const HIGH_BUILD := "absurd"
# metric: fight (Warden fight s), heft (exit heft), hp (HP lost, % of max), boss (fight s).
# A band top below zero means the power-curve band's top for that stage.
const TARGETS := [
	{"what": "Skipper Warden I fight", "policy": "skipper", "stage": 1, "metric": "fight", "band": Vector2(20.0, 40.0)},
	{"what": "Skipper Warden II fight", "policy": "skipper", "stage": 2, "metric": "fight", "band": Vector2(35.0, 60.0)},
	{"what": "Skipper Warden III fight", "policy": "skipper", "stage": 3, "metric": "fight", "band": Vector2(50.0, 90.0)},
	{"what": "Skipper stage-3 exit heft", "policy": "skipper", "stage": 3, "metric": "heft", "band": Vector2(2.5, 3.5)},
	{"what": "Completionist Warden III fight", "policy": "completionist", "stage": 3, "metric": "fight", "band": Vector2(10.0, 25.0)},
	{"what": "Completionist stage-3 exit heft (at or under the band top)", "policy": "completionist", "stage": 3, "metric": "heft", "band": Vector2(0.0, -1.0)},
	{"what": "Skipper HP lost, stage 1 (% of max)", "policy": "skipper", "stage": 1, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Skipper HP lost, stage 2 (% of max)", "policy": "skipper", "stage": 2, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Skipper HP lost, stage 3 (% of max)", "policy": "skipper", "stage": 3, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Brindle, skipper win", "policy": "skipper", "stage": 0, "metric": "boss", "band": Vector2(120.0, 240.0)},
	{"what": "Brindle, completionist rout", "policy": "completionist", "stage": 0, "metric": "boss", "band": Vector2(75.0, 150.0)},
]
const SYNERGY_TARGET := Vector2(0.1, 0.6)
const HAND_KEYS := ["evasions", "hits", "cap_hits", "magnet_stuns", "plants", "slingshots", "specials", "punch_short_s"]

var _in := ""
var _label := ""
var _lines: Array[String] = []
var _flags: Array[String] = []


func _initialize() -> void:
	var settings := _parse(OS.get_cmdline_user_args())
	if not settings.has("in"):
		printerr("balance_report: usage: -- --in=<dir> --label=<label> [--out-dir=<dir>]")
		quit(2)
		return
	_in = settings["in"]
	_label = settings.get("label", Time.get_date_string_from_system())
	var out_dir: String = settings.get("out-dir", ProjectSettings.globalize_path("res://").path_join("../../artifacts/local").simplify_path())
	var ok := _build()
	var text := "\n".join(_lines) + "\n"
	print(text)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir.path_join("balance-%s.md" % _label)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("balance_report: cannot write %s" % path)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("balance_report: wrote %s (%d flag(s))" % [path, _flags.size()])
	quit(0 if ok else 1)


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
	return out


static func _ndjson(path: String) -> Array:
	var rows := []
	if not FileAccess.file_exists(path):
		return rows
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			rows.append(parsed)
	return rows


# --- the report -----------------------------------------------------------------------

func _build() -> bool:
	var bots := _ndjson(_in.path_join("bots.ndjson"))
	if bots.is_empty():
		_lines.append("No bots.ndjson rows in %s." % _in)
		return false
	# The run log is cumulative: the last line of a run carries the whole run.
	var spine := {}
	for record in _ndjson(_in.path_join("runs.ndjson")):
		spine[record.get("run_id", "")] = record
	var discoveries := {}
	for line in _ndjson(_in.path_join("codex-log.ndjson")):
		if line.get("kind") == "discovered":
			var id: String = line.get("run_id", "")
			if not discoveries.has(id):
				discoveries[id] = {}
			discoveries[id][line.get("id", "")] = true
	var entries = JSON.parse_string(FileAccess.get_file_as_string(_in.path_join("codex-entries.json")))
	if not entries is Array:
		entries = []
	var runs: Array[Dictionary] = []
	for bot in bots:
		var id: String = bot.get("run_id", "")
		var found: Dictionary = discoveries.get(id, {}).duplicate()
		var record: Dictionary = spine.get(id, {})
		for codex_id in record.get("codex", []):
			found[codex_id] = true
		runs.append({"bot": bot, "spine": record, "found": found})

	var band := _heft_band()
	_header(runs)
	_targets(runs, band)
	_runs_table(runs)
	for stage in range(1, StageDefs.COUNT + 1):
		_stage_section(runs, stage, band)
	_boss_section(runs)
	_hands_section(runs)
	_codex_section(runs, entries)
	_flag_breaks(runs)
	_flag_heft(runs, band)
	_flag_deaths(runs)
	_lines.append("## Flags (%d)" % _flags.size())
	_lines.append("")
	if _flags.is_empty():
		_lines.append("None.")
	for flag in _flags:
		_lines.append("- " + flag)
	_lines.append("")
	_lines.append("## What this cannot say")
	_lines.append("")
	_lines.append("A bot run is not play. These bands say what scripted drivers reached, not whether the Warden felt like a chore, "
		+ "whether growth felt like enough, or whether a synergy felt like a find. Andrew's play and the playtest log own feel.")
	return true


func _header(runs: Array[Dictionary]) -> void:
	var wall := 0.0
	var game := 0.0
	var outcomes := {}
	var reaction := -1.0
	for run in runs:
		wall += float(run["bot"].get("wall_seconds", 0.0))
		game += float(run["bot"].get("game_seconds", 0.0))
		var o: String = run["bot"].get("outcome", "?")
		outcomes[o] = int(outcomes.get(o, 0)) + 1
		reaction = float(run["bot"].get("reaction_s", reaction))
	_lines.append("# Balance report: %s" % _label)
	_lines.append("")
	_lines.append("Generated %s from `%s`: %d bot runs, outcomes %s. %.0f s of game in %.0f s of wall time (%.1f s wall per run)."
		% [Time.get_datetime_string_from_system(), ProjectSettings.globalize_path(_in), runs.size(), _counts(outcomes),
			game, wall, wall / maxf(1.0, runs.size())])
	_lines.append("It reports and never tunes (DEMO-SPEC). Stage times are stage time at %d ticks a second. The bots read telegraphs %s."
		% [Engine.physics_ticks_per_second, "with a %.2f s reaction" % reaction if reaction >= 0.0 else "not at all (an older bot)"])
	_lines.append("")


# --- per-run readings -----------------------------------------------------------------

static func _stage_row(run: Dictionary, stage: int) -> Dictionary:
	for row in (run["spine"] as Dictionary).get("stages", []):
		if int(row.get("stage", 0)) == stage:
			return row
	return {}


static func _note(run: Dictionary, stage: int) -> Dictionary:
	for note in (run["bot"] as Dictionary).get("stages", []):
		if int(note.get("stage", 0)) == stage:
			return note
	return {}


# Seconds from warden_engaged to the break: the run log's ticks when it has them, else
# the bot's note. -1 when unknown.
static func _fight_seconds(run: Dictionary, stage: int) -> float:
	var row := _stage_row(run, stage)
	if row.get("ticks_to_warden_engaged") != null and row.get("ticks_to_warden_break") != null:
		return (float(row["ticks_to_warden_break"]) - float(row["ticks_to_warden_engaged"])) / Engine.physics_ticks_per_second
	var note := _note(run, stage)
	if note.get("warden_engaged_s") != null and note.get("warden_broken_s") != null:
		return float(note["warden_broken_s"]) - float(note["warden_engaged_s"])
	return -1.0


static func _hp_percent(run: Dictionary, stage: int) -> float:
	var note := _note(run, stage)
	if note.is_empty() or note.get("hp_lost") == null:
		return -1.0
	return 100.0 * float(note["hp_lost"]) / maxf(1.0, float(note.get("max_hp", 100.0)))


static func _boss_seconds(run: Dictionary) -> float:
	var boss = (run["bot"] as Dictionary).get("boss")
	if not boss is Dictionary or boss.get("defeated_s") == null:
		return -1.0
	return float(boss["defeated_s"])


func _metric(run: Dictionary, metric: String, stage: int) -> float:
	match metric:
		"fight":
			return _fight_seconds(run, stage)
		"heft":
			var row := _stage_row(run, stage)
			return float(row["heft_at_exit"]) if row.get("heft_at_exit") != null else -1.0
		"hp":
			return _hp_percent(run, stage)
		"boss":
			return _boss_seconds(run)
	return -1.0


func _targets(runs: Array[Dictionary], band: Dictionary) -> void:
	_lines.append("## Tuning targets")
	_lines.append("")
	_lines.append("| Target | Band | Runs measured | Min / median / max | In band |")
	_lines.append("| --- | --- | --- | --- | --- |")
	for t in TARGETS:
		var limits: Vector2 = t["band"]
		if limits.y < 0.0:
			limits.y = (band.get(int(t["stage"]), Vector2.ZERO) as Vector2).y
		var values: Array = []
		var inside := 0
		for run in runs:
			if run["bot"].get("policy") != t["policy"]:
				continue
			var v := _metric(run, t["metric"], int(t["stage"]))
			if v < 0.0:
				continue
			values.append(v)
			if v >= limits.x and v <= limits.y:
				inside += 1
		_lines.append("| %s | %.1f to %.1f | %d | %s | %s |" % [t["what"], limits.x, limits.y, values.size(), _band(values, 1),
			"%d of %d" % [inside, values.size()] if not values.is_empty() else "no data"])
	_lines.append("")


func _runs_table(runs: Array[Dictionary]) -> void:
	_lines.append("## Runs")
	_lines.append("")
	_lines.append("| Policy | Seed | Class | Outcome | Stage reached | Game s | Wall s | Spine record | Codex found |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for run in runs:
		var b: Dictionary = run["bot"]
		_lines.append("| %s | %d | %s | %s | %d | %.1f | %.1f | %s | %d |" % [b.get("policy", "?"), int(b.get("seed", 0)),
			b.get("class", "?"), b.get("outcome", "?"), int(b.get("stage_reached", 0)), float(b.get("game_seconds", 0.0)),
			float(b.get("wall_seconds", 0.0)), "yes" if not (run["spine"] as Dictionary).is_empty() else "no",
			(run["found"] as Dictionary).size()])
	_lines.append("")


func _stage_section(runs: Array[Dictionary], stage: int, band: Dictionary) -> void:
	var def := StageDefs.of(stage)
	var limits: Vector2 = band.get(stage, Vector2.ZERO)
	_lines.append("## Stage %d: %s (Warden plating %d, HP %d)" % [stage, def["name"], int(def["warden_plating"]), int(def["warden_hp"])])
	_lines.append("")
	_lines.append("Heft band at exit, from the power-curve table: %.2f to %.2f. Bands read min / median / max." % [limits.x, limits.y])
	_lines.append("")
	_lines.append("| Policy | Entered | Warden fight s (engaged to break) | Break s from entry | Heft at exit | Parts at exit | Bonus cores | HP lost % of max | Deaths | Events started (ambient too) | Events won |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for policy in POLICIES + ["all"]:
		var breaks: Array = []
		var fights: Array = []
		var hefts: Array = []
		var parts: Array = []
		var cores: Array = []
		var hp: Array = []
		var deaths := 0
		var entered := 0
		var joined := {}
		var won := {}
		for run in runs:
			if policy != "all" and run["bot"].get("policy") != policy:
				continue
			var row := _stage_row(run, stage)
			if row.is_empty():
				continue
			entered += 1
			if row.get("ticks_to_warden_break") != null:
				breaks.append(float(row["ticks_to_warden_break"]) / Engine.physics_ticks_per_second)
			var fight := _fight_seconds(run, stage)
			if fight >= 0.0:
				fights.append(fight)
			var lost := _hp_percent(run, stage)
			if lost >= 0.0:
				hp.append(lost)
			if row.get("heft_at_exit") != null:
				hefts.append(float(row["heft_at_exit"]))
				parts.append(float((row.get("part_ids_at_exit", []) as Array).size()))
				cores.append(float(row.get("bonus_cores", 0)))
			deaths += (row.get("deaths", []) as Array).size()
			for id in row.get("events_joined", []):
				joined[id] = int(joined.get(id, 0)) + 1
			for id in row.get("events_won", []):
				won[id] = int(won.get(id, 0)) + 1
		if entered == 0:
			continue
		_lines.append("| %s | %d | %s | %s | %s | %s | %s | %s | %d | %s | %s |" % [policy, entered, _band(fights, 1), _band(breaks, 1),
			_band(hefts, 2), _band(parts, 0), _band(cores, 0), _band(hp, 0), deaths, _counts(joined), _counts(won)])
	_lines.append("")


func _boss_section(runs: Array[Dictionary]) -> void:
	var fought: Array[Dictionary] = []
	for run in runs:
		if run["bot"].get("boss") is Dictionary:
			fought.append(run)
	_lines.append("## Brindle")
	_lines.append("")
	if fought.is_empty():
		var reached := 0
		for run in runs:
			if run["bot"].get("outcome") == "boss":
				reached += 1
		_lines.append("No boss fight in these runs (%d reached a `boss` flow state with no boss module and ended there)." % reached)
		_lines.append("")
		return
	_lines.append("Times are seconds from arena entry; each phase entry is when that phase began.")
	_lines.append("")
	_lines.append("| Policy | Seed | Outcome | Entry heft | Phase starts | Defeated s | HP lost | Weak-point hits by point | Scrap stolen | Wall stuns |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for run in fought:
		var b: Dictionary = run["bot"]
		var boss: Dictionary = b["boss"]
		var starts := []
		for p in boss.get("phases", []):
			starts.append("%s %.1f" % [p.get("name", p.get("phase", "?")), float(p.get("at_s", 0.0))])
		_lines.append("| %s | %d | %s | %.2f | %s | %s | %.0f | %s | %d | %s |" % [b.get("policy", "?"), int(b.get("seed", 0)),
			boss.get("outcome", "?"), float(boss.get("entry_heft", 0.0)), ", ".join(starts) if not starts.is_empty() else "-",
			"%.1f" % float(boss["defeated_s"]) if boss.get("defeated_s") != null else "-", float(boss.get("hp_lost", 0.0)),
			_weak_hits(boss.get("weak_point_hits", {})), int(boss.get("stolen", 0)), str(boss.get("wall_stuns", "-"))])
	_lines.append("")


static func _weak_hits(hits) -> String:
	if hits is Array:
		return str(hits.size())
	if not hits is Dictionary or hits.is_empty():
		return "-"
	var parts := []
	for key in hits:
		parts.append("%s %d" % [key, int(hits[key])])
	return ", ".join(parts)


# How much each policy used the hands the bot has: per stage entered, mean counts.
func _hands_section(runs: Array[Dictionary]) -> void:
	_lines.append("## The bots' hands (mean per stage entered)")
	_lines.append("")
	_lines.append("| Policy | Class | Stages | Telegraphs evaded | Hits taken | Cap hits | Magnet stuns | Plants | Slingshots | Specials | Seconds short of plating |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for policy in POLICIES:
		for class_id in ["runner_gunner", "pylon_engineer"]:
			var sums := {}
			var stages := 0
			for run in runs:
				if run["bot"].get("policy") != policy or run["bot"].get("class") != class_id:
					continue
				for note in run["bot"].get("stages", []):
					stages += 1
					for key in HAND_KEYS:
						sums[key] = float(sums.get(key, 0.0)) + float(note.get(key, 0.0))
			if stages == 0:
				continue
			var cells := []
			for key in HAND_KEYS:
				cells.append("%.1f" % (float(sums.get(key, 0.0)) / stages))
			_lines.append("| %s | %s | %d | %s |" % [policy, class_id, stages, " | ".join(cells)])
	_lines.append("")


func _codex_section(runs: Array[Dictionary], entries: Array) -> void:
	var per_policy := {}
	for policy in POLICIES:
		per_policy[policy] = runs.filter(func(r): return r["bot"].get("policy") == policy)
	_lines.append("## Codex coverage by policy")
	_lines.append("")
	_lines.append("Named synergies (category build) are held to %d%% to %d%% of runs." % [int(SYNERGY_TARGET.x * 100.0), int(SYNERGY_TARGET.y * 100.0)])
	_lines.append("")
	_lines.append("| Entry | Category | Skipper | Completionist | Random | All runs | Share |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- |")
	var total := runs.size()
	for entry in entries:
		var id: String = entry.get("id", "")
		var cells := []
		for policy in POLICIES:
			var hits := 0
			for run in per_policy[policy]:
				if (run["found"] as Dictionary).has(id):
					hits += 1
			cells.append("%d of %d" % [hits, (per_policy[policy] as Array).size()])
		var all := 0
		for run in runs:
			if (run["found"] as Dictionary).has(id):
				all += 1
		var share := float(all) / float(maxi(1, total))
		_lines.append("| %s (%s) | %s | %s | %d of %d | %d%% |" % [entry.get("name", id), id, entry.get("category", "?"),
			" | ".join(cells), all, total, int(round(share * 100.0))])
		if entry.get("category") == "build":
			if all == 0:
				_flags.append("Synergy %s (%s) was found in no run." % [entry.get("name", id), id])
			elif share > SYNERGY_SHARE:
				_flags.append("Synergy %s (%s) was found in %d of %d runs (%d%%, above %d%%)."
					% [entry.get("name", id), id, all, total, int(round(share * 100.0)), int(SYNERGY_SHARE * 100.0)])
			elif share < SYNERGY_TARGET.x:
				_flags.append("Synergy %s (%s) was found in %d of %d runs (%d%%, below the %d%% target)."
					% [entry.get("name", id), id, all, total, int(round(share * 100.0)), int(SYNERGY_TARGET.x * 100.0)])
		elif all == 0:
			_flags.append("Codex entry %s (%s, %s) was discovered in no run." % [entry.get("name", id), id, entry.get("category", "?")])
	_lines.append("")


# --- flags ----------------------------------------------------------------------------

func _flag_breaks(runs: Array[Dictionary]) -> void:
	for run in runs:
		var b: Dictionary = run["bot"]
		var who := "%s seed %d" % [b.get("policy", "?"), int(b.get("seed", 0))]
		if b.get("outcome") == "stalled":
			_flags.append("%s never broke the stage %d Warden (stalled past the bot's stage limit)." % [who, int(b.get("stage_reached", 0))])
		if b.get("outcome") == "boss_stalled":
			_flags.append("%s did not beat Brindle within the bot's fight limit." % who)
		for row in (run["spine"] as Dictionary).get("stages", []):
			var stage := int(row.get("stage", 0))
			var fight := _fight_seconds(run, stage)
			if fight < 0.0:
				continue
			if fight < BREAK_BAND.x or fight > BREAK_BAND.y:
				var entry := float(row["ticks_to_warden_break"]) / Engine.physics_ticks_per_second if row.get("ticks_to_warden_break") != null else -1.0
				_flags.append("%s fought the stage %d Warden for %.1f s from engagement, outside %d to %d s (%.1f s from entry)."
					% [who, stage, fight, int(BREAK_BAND.x), int(BREAK_BAND.y), entry])


func _flag_heft(runs: Array[Dictionary], band: Dictionary) -> void:
	for run in runs:
		var b: Dictionary = run["bot"]
		for row in (run["spine"] as Dictionary).get("stages", []):
			if row.get("heft_at_exit") == null:
				continue
			var stage := int(row["stage"])
			var limits: Vector2 = band.get(stage, Vector2(0.0, INF))
			var heft := float(row["heft_at_exit"])
			if heft < limits.x or heft > limits.y:
				_flags.append("%s seed %d left stage %d at heft %.2f, outside the %.2f to %.2f band (%d parts)."
					% [b.get("policy", "?"), int(b.get("seed", 0)), stage, heft, limits.x, limits.y, (row.get("part_ids_at_exit", []) as Array).size()])


# Single-linkage clusters of death positions per stage.
func _flag_deaths(runs: Array[Dictionary]) -> void:
	for stage in range(1, StageDefs.COUNT + 1):
		var points: Array = []
		for run in runs:
			for death in _stage_row(run, stage).get("deaths", []):
				points.append({"at": Vector3(float(death["x"]), float(death["y"]), float(death["z"])),
					"who": "%s seed %d" % [run["bot"].get("policy", "?"), int(run["bot"].get("seed", 0))]})
		var group := []
		group.resize(points.size())
		for i in points.size():
			group[i] = i
		for i in points.size():
			for j in range(i + 1, points.size()):
				if (points[i]["at"] as Vector3).distance_to(points[j]["at"]) <= CLUSTER_METRES:
					var from: int = group[j]
					var to: int = group[i]
					for k in points.size():
						if group[k] == from:
							group[k] = to
		var clusters := {}
		for i in points.size():
			if not clusters.has(group[i]):
				clusters[group[i]] = []
			clusters[group[i]].append(points[i])
		for members in clusters.values():
			if members.size() < 2:
				continue
			var centre := Vector3.ZERO
			var who := []
			for m in members:
				centre += m["at"]
				who.append(m["who"])
			centre /= members.size()
			_flags.append("Death cluster on stage %d: %d deaths within %d m around (%.0f, %.0f, %.0f): %s."
				% [stage, members.size(), int(CLUSTER_METRES), centre.x, centre.y, centre.z, ", ".join(who)])


# --- helpers --------------------------------------------------------------------------

# Stage index to Vector2(low, high) heft at exit, read from the power-curve table.
func _heft_band() -> Dictionary:
	var script: GDScript = load(CURVE_TEST)
	var builds: Array = script.get_script_constant_map().get("BUILDS", []) if script != null else []
	var low := {}
	var high := {}
	for build in builds:
		if build["name"] == LOW_BUILD:
			low = build
		elif build["name"] == HIGH_BUILD:
			high = build
	var band := {}
	for stage in range(1, StageDefs.COUNT + 1):
		var share := float(stage) / float(StageDefs.COUNT)
		band[stage] = Vector2(_heft(low, share), _heft(high, share))
	return band


static func _heft(build: Dictionary, share: float) -> float:
	if build.is_empty():
		return 1.0
	return 1.0 + float(build["mass"]) * share * RunState.HEFT_PER_MASS + (build["parts"] as Array).size() * share * RunState.HEFT_PER_PART


static func _band(values: Array, digits: int) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var mid: float = sorted[sorted.size() / 2] if sorted.size() % 2 == 1 else (sorted[sorted.size() / 2 - 1] + sorted[sorted.size() / 2]) * 0.5
	var f := "%." + str(digits) + "f"
	return (f + " / " + f + " / " + f) % [sorted[0], mid, sorted[-1]]


static func _counts(counts: Dictionary) -> String:
	if counts.is_empty():
		return "-"
	var parts := []
	for key in counts:
		parts.append("%s %d" % [key, counts[key]])
	return ", ".join(parts)
