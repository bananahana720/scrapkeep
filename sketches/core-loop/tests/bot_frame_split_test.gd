# smoke: solo timeout=120s (one headless bot_run child cut at 450 ticks)
extends SceneTree

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")

# bot_run --frame-split=2 (tools/frame_split.gd): the frame log's parts. The 6 s GATES hitch was the bot
# driver's own climb planner, 60 to 85 ms in one tick, found by timing that tick (bot_ms) and
# reading the frame without it (net_ms).
# Pins, on a park stage-2 run of 450 ticks:
#   keys     every row carries phys_ms, proc_ms, bot_ms and net_ms;
#   net      net_ms is the row's ms less bot_ms, on every row;
#   bot      some row has bot_ms over zero (the driver's tick is timed);
#   events   the first frame is over 40 ms and carries an events list of bracket stamps, each with
#            a name, a time and an on-CPU time.
# Evidence limit: the identity and the plumbing, not a timing; the planted --inject-ms cost is read
# from a windowed GATES frame log.

const KEYS := ["phys_ms", "proc_ms", "bot_ms", "net_ms"]


func _initialize() -> void:
	var t := T.new("bot_frame_split_test")
	var out := OS.get_user_data_dir().path_join("bot-frame-split-%d" % OS.get_process_id())
	var results := ChildRuns.run([{"script": "res://tools/bot_run.gd", "args": ["--out=" + out, "--policy=skipper", "--seeds=1",
		"--table=park", "--from-stage=2", "--ticks=450", "--frame-log=1", "--frame-split=2"]}], 110.0)
	var result: Dictionary = results[0]
	t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
		"exit %s, timed out %s" % [result["code"], result["timed_out"]])
	var path := out.path_join("frames-1.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	t.check("the frame log has rows", lines.size() > 100, "%d rows in %s" % [lines.size(), path])
	var missing := 0
	var off := 0
	var bot := false
	var first = null
	for line in lines:
		var row = JSON.parse_string(line)
		if not row is Dictionary:
			continue
		if first == null:
			first = row
		for key in KEYS:
			if not row.has(key):
				missing += 1
		if row.has("net_ms") and row.has("bot_ms") and absf(float(row["net_ms"]) - (float(row["ms"]) - float(row["bot_ms"]))) > 0.001:
			off += 1
		bot = bot or float(row.get("bot_ms", 0.0)) > 0.0
	t.eq("rows missing a part", missing, 0)
	t.eq("rows where net_ms is not ms less bot_ms", off, 0)
	t.check("the driver's tick is timed", bot, "no row has bot_ms over zero")
	var events = first.get("events") if first is Dictionary else null
	t.check("the first frame carries stamps", events is Array and not events.is_empty() and float(first["ms"]) > 40.0,
		"ms %s, events %s" % [first.get("ms") if first is Dictionary else null, events])
	if events is Array and not events.is_empty():
		t.eq("a stamp is name, time, on-CPU time", String(events[0]).split(" ").size(), 3)
	quit(t.verdict())
