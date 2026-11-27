# smoke: solo timeout=300s (two fixed-tick bot children, sequential for isolated caches)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const Replay := preload("res://tools/bot_replay.gd")
const Options := preload("res://tools/bot_options.gd")
const T := preload("res://tests/support/t.gd")
const SEED := 3
# The skipper fills the ultimate meter at 38.7 s (tick 3487) on this seed; it fires a little after tick 3600, so 3600 ticks ended just short.
const TICKS := 4000


func _initialize() -> void:
	var t := T.new("bot_switch_replay_test")
	var base := OS.get_user_data_dir().path_join("bot-switch-replay-%d" % OS.get_process_id())
	for i in 2:
		var folder := base.path_join(str(i))
		var args := ["--out=" + folder, "--policy=skipper", "--seeds=%d" % SEED,
			"--pilot=demolitions_caster", "--ticks=%d" % TICKS, "--bot-audit=1"]
		for key in Options.FAST_FLAGS:
			args.append("--%s=%d" % [key, i])
		var child: Dictionary = ChildRuns.run([{"script": "res://tools/bot_run.gd", "home": folder, "args": args}], 130.0)[0]
		t.check("child %d completed without script errors" % i,
			child.code == 0 and not child.timed_out and ChildRuns.summary(child).errors.is_empty(),
			"exit %s, timeout %s" % [child.code, child.timed_out])
		var bot_path: String = folder.path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(bot_path).split("\n", false) if FileAccess.file_exists(bot_path) else PackedStringArray()
		var record = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
		t.check("child %d ran the complete fixed tick span" % i, record is Dictionary
			and record.get("ticks") == TICKS and record.get("outcome") == "ticks_done")
	var a := base.path_join("0")
	var b := base.path_join("1")
	var result := Replay.compare(a, b, SEED)
	t.check("switches preserve outcome, every stage tick and complete logs", result.pass, JSON.stringify(result))
	var events := FileAccess.get_file_as_string(a.path_join("events-%d.ndjson" % SEED))
	t.check("replay exercises the ultimate music beat", events.contains('"event":"ultimate_started"'),
		"ultimate_started events %d, ultimate_ready events %d, last bot record %s" % [
			events.count('"event":"ultimate_started"'), events.count('"event":"ultimate_ready"'), _ultimate_note(a)])
	if t.failures == 0:
		_remove(base)
	else:
		print("bot_switch_replay_test: evidence " + base)
	quit(t.verdict())


func _ultimate_note(folder: String) -> String:
	var path := folder.path_join("bots.ndjson")
	var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	var record = JSON.parse_string(rows[-1]) if not rows.is_empty() else null
	if not record is Dictionary:
		return "no bot record"
	return "ult_fill_s %s, ult_presses %s, ultimates %s, ult_sources %s" % [
		record.get("ult_fill_s"), record.get("ult_presses"), record.get("ultimates"), record.get("ult_sources")]


func _remove(path: String) -> void:
	for sub in DirAccess.get_directories_at(path):
		_remove(path.path_join(sub))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
