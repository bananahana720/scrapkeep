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
#   events   a frame over 40 ms carries an events list of bracket stamps, each with a name, a time
#            and an on-CPU time; --inject-ms plants that frame, since the load frame alone (once
#            the pin) came in at 27-34 ms on a 4 vCPU cloud box by wave 20;
#   marks    a tick's phys_tail, phys_deferred and phys_deleted come in that order.
# Evidence limit: the identity and the plumbing, not a timing; the planted --inject-ms cost is read
# from a windowed GATES frame log.

const KEYS := ["phys_ms", "proc_ms", "bot_ms", "net_ms"]


func _initialize() -> void:
	var t := T.new("bot_frame_split_test")
	var out := OS.get_user_data_dir().path_join("bot-frame-split-%d" % OS.get_process_id())
	var results := ChildRuns.run([{"script": "res://tools/bot_run.gd", "args": ["--out=" + out, "--policy=skipper", "--seeds=1",
		"--table=park", "--from-stage=2", "--ticks=450", "--frame-log=1", "--frame-split=2", "--inject-ms=60"]}], 110.0)
	var result: Dictionary = results[0]
	t.check("child ran clean", result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
		"exit %s, timed out %s" % [result["code"], result["timed_out"]])
	var path := out.path_join("frames-1.ndjson")
	var lines := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
	t.check("the frame log has rows", lines.size() > 100, "%d rows in %s" % [lines.size(), path])
	var missing := 0
	var off := 0
	var bot := false
	var slow = null
	for line in lines:
		var row = JSON.parse_string(line)
		if not row is Dictionary:
			continue
		if slow == null and float(row.get("ms", 0.0)) > 40.0:
			slow = row
		for key in KEYS:
			if not row.has(key):
				missing += 1
		if row.has("net_ms") and row.has("bot_ms") and absf(float(row["net_ms"]) - (float(row["ms"]) - float(row["bot_ms"]))) > 0.001:
			off += 1
		bot = bot or float(row.get("bot_ms", 0.0)) > 0.0
	t.eq("rows missing a part", missing, 0)
	t.eq("rows where net_ms is not ms less bot_ms", off, 0)
	t.check("the driver's tick is timed", bot, "no row has bot_ms over zero")
	var events = slow.get("events") if slow is Dictionary else null
	t.check("a frame over 40 ms carries stamps", events is Array and not events.is_empty(),
		"ms %s, events %s" % [slow.get("ms") if slow is Dictionary else null, events])
	if events is Array and not events.is_empty():
		t.eq("a stamp is name, time, on-CPU time", String(events[0]).split(" ").size(), 3)
		var names: Array = events.map(func(e): return String(e).split(" ")[0])
		var tail := names.find("phys_tail")
		t.check("a tick marks its deferred calls, then its deletes", tail >= 0 and names.find("phys_deferred", tail) > tail
			and names.find("phys_deleted", tail) > names.find("phys_deferred", tail), str(names))
	quit(t.verdict())
