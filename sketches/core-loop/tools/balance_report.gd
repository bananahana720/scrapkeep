extends SceneTree

const RunState := preload("res://src/core/run_state.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const StageBeats := preload("res://src/core/stage_beats.gd")


const BREAK_BAND := Vector2(10.0, 90.0)
const SYNERGY_SHARE := 0.6
const CLUSTER_METRES := 15.0
const POLICIES := ["skipper", "completionist", "random"]
const CURVE_TEST := "res://tests/build_power_curve_test.gd"
const LOW_BUILD := "skipper"
const HIGH_BUILD := "absurd"
const TARGETS := [
	{"what": "Skipper Warden I fight", "policy": "skipper", "stage": 1, "metric": "fight", "band": Vector2(20.0, 40.0)},
	{"what": "Skipper Warden II fight", "policy": "skipper", "stage": 2, "metric": "fight", "band": Vector2(35.0, 60.0)},
	{"what": "Skipper Warden III fight", "policy": "skipper", "stage": 3, "metric": "fight", "band": Vector2(50.0, 90.0)},
	{"what": "Skipper stage-3 exit heft", "policy": "skipper", "stage": 3, "metric": "heft", "band": Vector2(2.5, 3.5)},
	{"what": "Completionist Warden III fight", "policy": "completionist", "stage": 3, "metric": "fight", "band": Vector2(10.0, 25.0)},
	{"what": "Completionist stage-3 exit heft (at or under 9.07)", "policy": "completionist", "stage": 3, "metric": "heft", "band": Vector2(0.0, 9.07)},
	{"what": "Skipper HP lost, stage 1 (% of max)", "policy": "skipper", "stage": 1, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Skipper HP lost, stage 2 (% of max)", "policy": "skipper", "stage": 2, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Skipper HP lost, stage 3 (% of max)", "policy": "skipper", "stage": 3, "metric": "hp", "band": Vector2(20.0, 60.0)},
	{"what": "Brindle, skipper win", "policy": "skipper", "stage": 0, "metric": "boss", "band": Vector2(120.0, 240.0)},
	{"what": "Brindle, completionist rout", "policy": "completionist", "stage": 0, "metric": "boss", "band": Vector2(75.0, 150.0)},
]
const SYNERGY_TARGET := Vector2(0.1, 0.6)
const DAMAGE_KINDS := ["ram", "stomp", "slam", "runner", "arc", "turret", "synergy", "shell"]
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


static func _join(dir: String) -> Array[Dictionary]:
	var spine := {}
	for record in _ndjson(dir.path_join("runs.ndjson")):
		spine[record.get("run_id", "")] = record
	var discoveries := {}
	for line in _ndjson(dir.path_join("codex-log.ndjson")):
		if line.get("kind") == "discovered":
			var id: String = line.get("run_id", "")
			if not discoveries.has(id):
				discoveries[id] = {}
			discoveries[id][line.get("id", "")] = true
	var runs: Array[Dictionary] = []
	for bot in _ndjson(dir.path_join("bots.ndjson")):
		var id: String = bot.get("run_id", "")
		var found: Dictionary = discoveries.get(id, {}).duplicate()
		var record: Dictionary = spine.get(id, {})
		for codex_id in record.get("codex", []):
			found[codex_id] = true
		runs.append({"bot": bot, "spine": record, "found": found})
	return runs


static func _sources(root: String) -> Array:
	var dirs := []
	var listing := DirAccess.open(root)
	if listing != null:
		for sub in listing.get_directories():
			if FileAccess.file_exists(root.path_join(sub).path_join("bots.ndjson")):
				dirs.append(root.path_join(sub))
	if dirs.is_empty():
		dirs.append(root)
	dirs.sort()
	return dirs


func _build() -> bool:
	var runs: Array[Dictionary] = []
	for dir in _sources(_in):
		runs.append_array(_join(dir))
	if runs.is_empty():
		_lines.append("No bots.ndjson rows in %s." % _in)
		return false
	var entries = JSON.parse_string(FileAccess.get_file_as_string(_in.path_join("codex-entries.json")))
	if not entries is Array:
		entries = []

	var band := _heft_band()
	_header(runs)
	_targets(runs, band)
	_runs_table(runs)
	for stage in range(1, StageDefs.COUNT + 1):
		_stage_section(runs, stage, band)
	_boss_section(runs)
	_hands_section(runs)
	_beats_section(runs)
	_damage_section(runs)
	_hurt_section(runs)
	_delivered_damage_section(runs)
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


static func _fight_seconds(run: Dictionary, stage: int) -> float:
	var row := _stage_row(run, stage)
	var note := _note(run, stage)
	var broken := -1.0
	var engaged := -1.0
	if row.get("ticks_to_warden_break") != null:
		broken = float(row["ticks_to_warden_break"]) / Engine.physics_ticks_per_second
	elif note.get("warden_broken_s") != null:
		broken = float(note["warden_broken_s"])
	if row.get("ticks_to_warden_engaged") != null:
		engaged = float(row["ticks_to_warden_engaged"]) / Engine.physics_ticks_per_second
	elif note.get("warden_engaged_s") != null:
		engaged = float(note["warden_engaged_s"])
	if broken < 0.0 or engaged < 0.0:
		return -1.0
	var start := engaged
	if note.get("warden_fight_s") != null:
		start = maxf(start, float(note["warden_fight_s"]))
	return maxf(0.0, broken - start)


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
	_lines.append("| Policy | Seed | Class | Outcome | Stage reached | Game s | Wall s | Spine record | Codex found | Smash damage HP | Smash HP per fight (mean) | Fight slots | Chains | Best combo | Misses |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for run in runs:
		var b: Dictionary = run["bot"]
		var record: Dictionary = run["spine"]
		var fights = record.get("smash_damage_by_fight")
		var chains = record.get("chains")
		var fight_mean := "-"
		if fights is Array and not fights.is_empty():
			fight_mean = "%.2f" % _mean(fights)
		_lines.append("| %s | %d | %s | %s | %d | %.1f | %.1f | %s | %d | %s | %s | %s | %s | %s | %s |" % [b.get("policy", "?"), int(b.get("seed", 0)),
			b.get("class", "?"), b.get("outcome", "?"), int(b.get("stage_reached", 0)), float(b.get("game_seconds", 0.0)),
			float(b.get("wall_seconds", 0.0)), "yes" if not (run["spine"] as Dictionary).is_empty() else "no",
			(run["found"] as Dictionary).size(),
			"%.2f" % float(record["smash_damage"]) if record.has("smash_damage") else "-", fight_mean,
			str(fights.size()) if fights is Array else "-", str(chains.size()) if chains is Array else "-",
			str(int(record["best_combo"])) if record.has("best_combo") else "-",
			str(int(record["misses"])) if record.has("misses") else "-"])
	_lines.append("")


func _stage_section(runs: Array[Dictionary], stage: int, band: Dictionary) -> void:
	var def := StageDefs.of(stage)
	var limits: Vector2 = band.get(stage, Vector2.ZERO)
	_lines.append("## Stage %d: %s (Warden plating %d, HP %d)" % [stage, def["name"], int(def["warden_plating"]), int(def["warden_hp"])])
	_lines.append("")
	_lines.append("Heft band at exit, from the power-curve table: %.2f to %.2f. Bands read min / median / max." % [limits.x, limits.y])
	_lines.append("")
	_lines.append("| Policy | Entered | Warden fight s (engaged and committed, to break) | Break s from entry | Heft at exit | Parts at exit | Bonus cores | HP lost % of max | Deaths | Events started (ambient too) | Events won |")
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


func _hurt_section(runs: Array[Dictionary]) -> void:
	_lines.append("## What hurt the player (HP lost by source, summed over runs)")
	_lines.append("")
	_lines.append("| Policy | Stage | Sources |")
	_lines.append("| --- | --- | --- |")
	for policy in POLICIES:
		for stage in range(1, StageDefs.COUNT + 2):
			var sums := {}
			for run in runs:
				if run["bot"].get("policy") != policy:
					continue
				var by = _note(run, stage).get("hit_sources", {}) if stage <= StageDefs.COUNT else \
					((run["bot"].get("boss") as Dictionary).get("hit_sources", {}) if run["bot"].get("boss") is Dictionary else {})
				if not by is Dictionary:
					continue
				for key in by:
					sums[key] = float(sums.get(key, 0.0)) + float(by[key])
			if sums.is_empty():
				continue
			var parts := []
			for key in sums:
				parts.append("%s %.0f" % [key, sums[key]])
			_lines.append("| %s | %s | %s |" % [policy, str(stage) if stage <= StageDefs.COUNT else "Brindle", ", ".join(parts)])
	_lines.append("")


func _delivered_damage_section(runs: Array[Dictionary]) -> void:
	_lines.append("## Delivered damage (M0 baseline)")
	_lines.append("")
	var by_source := {}
	var by_action := {}
	var by_target := {}
	var by_range := {"near": 0.0, "mid": 0.0, "far": 0.0}
	var retirements := {}
	var total := 0.0
	var overkill := 0.0
	var hits := 0
	var zero_damage_runs := 0
	var run_count := 0
	var slam_stages := {}
	for run in runs:
		var record: Dictionary = run["spine"]
		if not record.has("delivered_damage"):
			continue
		var d: Dictionary = record["delivered_damage"]
		run_count += 1
		total += float(d.get("total", 0.0))
		overkill += float(d.get("overkill", 0.0))
		hits += int(d.get("hits", 0))
		if float(d.get("total", 0.0)) <= 0.0:
			zero_damage_runs += 1
		for key in (d.get("by_source", {}) as Dictionary):
			by_source[key] = float(by_source.get(key, 0.0)) + float(d["by_source"][key])
		for key in (d.get("by_action", {}) as Dictionary):
			by_action[key] = float(by_action.get(key, 0.0)) + float(d["by_action"][key])
		for key in (d.get("by_target_class", {}) as Dictionary):
			by_target[key] = float(by_target.get(key, 0.0)) + float(d["by_target_class"][key])
		for key in (d.get("by_range", {}) as Dictionary):
			by_range[key] = float(by_range.get(key, 0.0)) + float(d["by_range"][key])
		for key in (d.get("retirements", {}) as Dictionary):
			retirements[key] = int(retirements.get(key, 0)) + int(d["retirements"][key])
		for stage in (d.get("warden_slam_hits", {}) as Dictionary):
			var hit_list: Array = slam_stages.get(stage, [])
			hit_list.append(int(d["warden_slam_hits"][stage]))
			slam_stages[stage] = hit_list
	if run_count == 0:
		_lines.append("No delivered_damage records in these runs (older run_log, before M0).")
		_lines.append("")
		return
	_lines.append("%d run(s), %d zero-damage run(s), %d hit(s), %.0f HP delivered, %.0f HP overkill clamped." \
		% [run_count, zero_damage_runs, hits, total, overkill])
	_lines.append("")
	_lines.append("| Source | HP |")
	_lines.append("| --- | --- |")
	for key in by_source:
		_lines.append("| %s | %.0f |" % [key, by_source[key]])
	_lines.append("")
	_lines.append("| Action | HP |")
	_lines.append("| --- | --- |")
	for key in by_action:
		_lines.append("| %s | %.0f |" % [key, by_action[key]])
	_lines.append("")
	_lines.append("| Target class | HP | Retirements |")
	_lines.append("| --- | --- | --- |")
	for key in by_target:
		_lines.append("| %s | %.0f | %d |" % [key, by_target[key], int(retirements.get(key, 0))])
	_lines.append("")
	_lines.append("| Range | HP |")
	_lines.append("| --- | --- |")
	for key in ["near", "mid", "far"]:
		_lines.append("| %s | %.0f |" % [key, by_range[key]])
	_lines.append("")
	if not slam_stages.is_empty():
		_lines.append("Warden stomp and slam hits to break (mean per broken stage):")
		for stage in slam_stages:
			_lines.append("- stage %s: %.1f (%d break(s))" % [stage, _mean(slam_stages[stage]), slam_stages[stage].size()])
		_lines.append("")


static func _mean(list: Array) -> float:
	var total := 0.0
	for v in list:
		total += float(v)
	return total / maxf(1.0, float(list.size()))


func _damage_section(runs: Array[Dictionary]) -> void:
	_lines.append("## What broke the Wardens (share of Warden damage by strike kind)")
	_lines.append("")
	_lines.append("`runner` is the runner-gunner's laser, `arc` the engineer's caster, `turret` the mounted turret; `synergy` is build's synergy strikes.")
	_lines.append("")
	_lines.append("| Policy | Stage | " + " | ".join(DAMAGE_KINDS) + " | other |")
	_lines.append("| --- | --- | " + " | ".join(DAMAGE_KINDS.map(func(_k): return "---")) + " | --- |")
	for policy in POLICIES:
		for stage in range(1, StageDefs.COUNT + 1):
			var sums := {}
			var total := 0.0
			for run in runs:
				if run["bot"].get("policy") != policy:
					continue
				var by = _note(run, stage).get("warden_damage", {})
				if not by is Dictionary:
					continue
				for kind in by:
					sums[kind] = float(sums.get(kind, 0.0)) + float(by[kind])
					total += float(by[kind])
			if total <= 0.0:
				continue
			var cells := []
			var named := 0.0
			for kind in DAMAGE_KINDS:
				cells.append("%d%%" % int(round(100.0 * float(sums.get(kind, 0.0)) / total)))
				named += float(sums.get(kind, 0.0))
			_lines.append("| %s | %d | %s | %d%% |" % [policy, stage, " | ".join(cells), int(round(100.0 * (total - named) / total))])
	_lines.append("")


func _hands_section(runs: Array[Dictionary]) -> void:
	_lines.append("## The bots' hands (mean per stage entered)")
	_lines.append("")
	_lines.append("| Policy | Class | Stages | Telegraphs evaded | Hits taken | Cap hits | Magnet stuns | Plants | Slingshots | Specials | Seconds short of plating |")
	_lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for policy in POLICIES:
		for class_id in ["pylon_engineer", "runner_gunner", "demolitions_caster"]:
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


const BEATS_RUNS := 50

func _beats_section(runs: Array[Dictionary]) -> void:
	var rows_by_stage := {}
	var all_rows := []
	var logged := 0
	for run in runs:
		var beats: Array = run["bot"].get("beats", [])
		if beats.is_empty():
			continue
		logged += 1
		for row in beats:
			all_rows.append(row)
			var stage := int(row["stage"])
			if not rows_by_stage.has(stage):
				rows_by_stage[stage] = []
			rows_by_stage[stage].append(row)
	_lines.append("## Stage beats (mean seconds per stage entered)")
	_lines.append("")
	if all_rows.is_empty():
		_lines.append("No run logged a beats column.")
		_lines.append("")
		return
	var tps := Engine.physics_ticks_per_second
	_lines.append("| Stage | Rows | " + " | ".join(StageBeats.BEATS) + " | Skipped beats |")
	_lines.append("| --- | --- | " + " | ".join(StageBeats.BEATS.map(func(_b): return "---")) + " | --- |")
	var stages := rows_by_stage.keys()
	stages.sort()
	for stage in stages:
		var rows: Array = rows_by_stage[stage]
		var cells := []
		for beat in StageBeats.BEATS:
			var ticks := 0.0
			for row in rows:
				ticks += float(row["ticks"][beat])
			cells.append("%.1f" % (ticks / rows.size() / tps))
		var skipped := 0
		for row in rows:
			skipped += (row["skipped"] as Array).size()
		_lines.append("| %d | %d | %s | %d |" % [stage, rows.size(), " | ".join(cells), skipped])
	_lines.append("")
	var audit: Dictionary = StageBeats.audit(all_rows)
	var checks := [
		["Every logged stage reached its exit", audit["exits"] == audit["stages"], "%d of %d" % [audit["exits"], audit["stages"]]],
		["No beat skipped", audit["skipped"] == 0, "%d skipped beat%s" % [audit["skipped"], "" if audit["skipped"] == 1 else "s"]],
		["Runs logged", logged >= BEATS_RUNS, "%d of %d" % [logged, BEATS_RUNS]],
	]
	var failed := []
	for check in checks:
		_lines.append("- %s: %s (%s)" % [check[0], "PASS" if check[1] else "FAIL", check[2]])
		if not check[1]:
			failed.append("%s %s" % [check[0].to_lower(), check[2]])
	_lines.append("")
	if not failed.is_empty():
		_flags.append("Stage beats: " + "; ".join(failed))


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
				_flags.append("%s fought the stage %d Warden for %.1f s (engaged and committed to break), outside %d to %d s (%.1f s from entry)."
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
