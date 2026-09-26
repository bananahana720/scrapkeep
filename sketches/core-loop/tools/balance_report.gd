extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# The balance report (DEMO-SPEC, "Balance report"). It reads what the bot runs left in
# one folder (tools/bot_run.gd): the spine's runs.ndjson and codex-log.ndjson, plus the
# runner's bots.ndjson and codex-entries.json. It prints per-stage bands and the flags
# below, and writes the same Markdown to artifacts/local/balance-<label>.md. It reports
# and never tunes: tuning stays a human-approved edit to stage_defs, the heft constants
# or the part catalogue.
#
#   godot --headless --path sketches/core-loop --script res://tools/balance_report.gd \
#     -- --in=<dir> --label=<label> [--out-dir=<dir>]
#
# Flags:
#   - a Warden broken outside 10 to 90 s from stage entry (the run log's measure), or
#     never broken (a stalled run); each flag also names the fight time from the bot's
#     first engagement, so a detour-heavy policy can be told from a slow fight;
#   - heft at stage exit outside the band read from build_power_curve_test's BUILDS table;
#   - a named synergy (codex category build) found in more than 60% of runs, or in none;
#   - any codex entry no run discovered;
#   - a death cluster: two or more deaths on one stage within 15 m of each other.
#
# The heft band: the power-curve table describes end-of-run builds, from the skipper's
# (3 gate parts, mass 60) to the absurd one (17 parts, mass 700). A stage-s exit is read
# as s/3 of the way along each: parts and mass scale linearly with stages cleared. That
# interpolation is this report's assumption, stated in the report.

const BREAK_BAND := Vector2(10.0, 90.0)
const SYNERGY_SHARE := 0.6
const CLUSTER_METRES := 15.0
const POLICIES := ["skipper", "completionist", "random"]
const CURVE_TEST := "res://tests/build_power_curve_test.gd"
const LOW_BUILD := "skipper"
const HIGH_BUILD := "absurd"

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

	_header(runs)
	_runs_table(runs)
	var band := _heft_band()
	for stage in range(1, StageDefs.COUNT + 1):
		_stage_section(runs, stage, band)
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
	for run in runs:
		wall += float(run["bot"].get("wall_seconds", 0.0))
		game += float(run["bot"].get("game_seconds", 0.0))
		var o: String = run["bot"].get("outcome", "?")
		outcomes[o] = int(outcomes.get(o, 0)) + 1
	_lines.append("# Balance report: %s" % _label)
	_lines.append("")
	_lines.append("Generated %s from `%s`: %d bot runs, outcomes %s. %.0f s of game in %.0f s of wall time (%.1f s wall per run)."
		% [Time.get_datetime_string_from_system(), ProjectSettings.globalize_path(_in), runs.size(), _counts(outcomes),
			game, wall, wall / maxf(1.0, runs.size())])
	_lines.append("It reports and never tunes (DEMO-SPEC). Times are stage time; the break time is ticks_to_warden_break / %d."
		% Engine.physics_ticks_per_second)
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


# Seconds from the bot's first engagement with the Warden (warden_engaged) to its break,
# from the runner's notes; the run log itself only has time from stage entry.
static func _fight_seconds(run: Dictionary, stage: int) -> float:
	for note in (run["bot"] as Dictionary).get("stages", []):
		if int(note.get("stage", 0)) == stage and note.get("warden_engaged_s") != null and note.get("warden_broken_s") != null:
			return float(note["warden_broken_s"]) - float(note["warden_engaged_s"])
	return -1.0


static func _stage_row(run: Dictionary, stage: int) -> Dictionary:
	for row in (run["spine"] as Dictionary).get("stages", []):
		if int(row.get("stage", 0)) == stage:
			return row
	return {}


func _stage_section(runs: Array[Dictionary], stage: int, band: Dictionary) -> void:
	var def := StageDefs.of(stage)
	var limits: Vector2 = band.get(stage, Vector2.ZERO)
	_lines.append("## Stage %d: %s (Warden plating %d, HP %d)" % [stage, def["name"], int(def["warden_plating"]), int(def["warden_hp"])])
	_lines.append("")
	_lines.append("Heft band at exit, from the power-curve table: %.2f to %.2f." % [limits.x, limits.y])
	_lines.append("")
	_lines.append("| Policy | Entered | Warden break s from entry (min / median / max) | Fight s, engaged to break | Heft at exit | Parts at exit | Bonus cores | Deaths | Events started (ambient too) | Events won |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for policy in POLICIES + ["all"]:
		var breaks: Array = []
		var fights: Array = []
		var hefts: Array = []
		var parts: Array = []
		var cores: Array = []
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
		_lines.append("| %s | %d | %s | %s | %s | %s | %s | %d | %s | %s |" % [policy, entered, _band(breaks, 1), _band(fights, 1), _band(hefts, 2),
			_band(parts, 0), _band(cores, 0), deaths, _counts(joined), _counts(won)])
	_lines.append("")


func _codex_section(runs: Array[Dictionary], entries: Array) -> void:
	_lines.append("## Codex coverage")
	_lines.append("")
	_lines.append("| Entry | Category | Runs that found it | Share |")
	_lines.append("| --- | --- | --- | --- |")
	var total := runs.size()
	for entry in entries:
		var id: String = entry.get("id", "")
		var hits := 0
		for run in runs:
			if (run["found"] as Dictionary).has(id):
				hits += 1
		var share := float(hits) / float(maxi(1, total))
		_lines.append("| %s (%s) | %s | %d of %d | %d%% |" % [entry.get("name", id), id, entry.get("category", "?"), hits, total, int(round(share * 100.0))])
		if entry.get("category") == "build":
			if hits == 0:
				_flags.append("Synergy %s (%s) was found in no run." % [entry.get("name", id), id])
			elif share > SYNERGY_SHARE:
				_flags.append("Synergy %s (%s) was found in %d of %d runs (%d%%, above %d%%)."
					% [entry.get("name", id), id, hits, total, int(round(share * 100.0)), int(SYNERGY_SHARE * 100.0)])
		elif hits == 0:
			_flags.append("Codex entry %s (%s, %s) was discovered in no run." % [entry.get("name", id), id, entry.get("category", "?")])
	_lines.append("")


func _flag_breaks(runs: Array[Dictionary]) -> void:
	for run in runs:
		var b: Dictionary = run["bot"]
		var who := "%s seed %d" % [b.get("policy", "?"), int(b.get("seed", 0))]
		if b.get("outcome") == "stalled":
			_flags.append("%s never broke the stage %d Warden (stalled past the bot's stage limit)." % [who, int(b.get("stage_reached", 0))])
		for row in (run["spine"] as Dictionary).get("stages", []):
			if row.get("ticks_to_warden_break") == null:
				continue
			var seconds := float(row["ticks_to_warden_break"]) / Engine.physics_ticks_per_second
			if seconds < BREAK_BAND.x or seconds > BREAK_BAND.y:
				var fight := _fight_seconds(run, int(row["stage"]))
				_flags.append("%s broke the stage %d Warden at %.1f s from entry, outside %d to %d s (fight from engagement: %s)."
					% [who, int(row["stage"]), seconds, int(BREAK_BAND.x), int(BREAK_BAND.y), "%.1f s" % fight if fight >= 0.0 else "unknown"])


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
