# smoke: solo timeout=240s (two bot children of 450 ticks each, side by side)
extends SceneTree

# SR13 2026-10-14: a stage's six beats (arrive, loot, find, hold, fight, leave) each have one
# owning module and a logged tick count per attempt. This test pins the table, the classifier's
# truth table, a scripted stage's tick counts to the frame, a stage with beats skipped, a retry,
# determinism of two identical scripts, and the audit the balance report prints against its
# thresholds. The 50-seed bot sweep is a tool run, not this file (tools/bot_run.gd, tools/balance_report.gd).

const T := preload("res://tests/support/t.gd")
const StageBeats := preload("res://src/core/stage_beats.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")

# The number of checks this file makes. A run that makes any other number fails.
const EXPECTED := 84
const TAIL := 20

var _nodes: Array[Node] = []


class FlowStub:
	extends RefCounted
	var warden: Node3D = null


func _initialize() -> void:
	var t := T.new("stage_beats_test")
	_table(t)
	_classifier(t)
	_scripted_stage(t)
	_skipped(t)
	_retry(t)
	_determinism(t)
	_audit(t)
	_bot_column(t)
	if t.checks != EXPECTED:
		t.check("check count", false, "ran %d checks, expected %d" % [t.checks, EXPECTED])
	for node in _nodes:
		node.free()
	quit(t.verdict())


func _table(t) -> void:
	t.eq("six beats in order", StageBeats.BEATS, ["arrive", "loot", "find", "hold", "fight", "leave"])
	var seen := {}
	for beat in StageBeats.BEATS:
		var path: String = StageBeats.owner_of(beat)
		t.check("%s has an owning module that exists" % beat, path.begins_with("res://src/") and FileAccess.file_exists(path), path)
		seen[path] = true
	t.eq("one distinct module per beat", seen.size(), StageBeats.BEATS.size())
	t.eq("an unknown beat has no owner", StageBeats.owner_of("rest"), "")


func _reading(state: String, landed: bool, engaged: bool, staggered: bool, since: int) -> Dictionary:
	return {"state": state, "landed": landed, "engaged": engaged, "staggered": staggered, "since_pickup": since, "loot_tail": TAIL}


func _classifier(t) -> void:
	var cases := [
		["before landing", _reading("stage", false, false, false, 999), "arrive"],
		["before landing, a pickup does not make it loot", _reading("stage", false, false, false, 0), "arrive"],
		["landed, nothing picked up", _reading("stage", true, false, false, 999), "find"],
		["landed, a pickup this tick", _reading("stage", true, false, false, 0), "loot"],
		["landed, pickup at the tail edge", _reading("stage", true, false, false, TAIL), "loot"],
		["landed, pickup one past the tail", _reading("stage", true, false, false, TAIL + 1), "find"],
		["engaged, guard up", _reading("stage", true, true, false, 999), "hold"],
		["engaged in the ring, guard up", _reading("beacon", true, true, false, 999), "hold"],
		["engaged, pickup beats nothing", _reading("stage", true, true, false, 0), "hold"],
		["engaged, staggered", _reading("beacon", true, true, true, 999), "fight"],
		["gates", _reading("gates", true, true, true, 0), "leave"],
		["launch", _reading("launch", true, false, false, 999), "leave"],
		["dead", _reading("dead", true, true, false, 0), ""],
		["boss arena", _reading("boss", true, false, false, 0), ""],
	]
	for c in cases:
		t.eq("classify: " + c[0], StageBeats.classify(c[1]), c[2])


# Builds a recorder on a fresh bus with a flow stub that holds a Warden node.
func _rig() -> Dictionary:
	var events := GameEvents.new()
	var flow := FlowStub.new()
	flow.warden = Node3D.new()
	_nodes.append(events)
	_nodes.append(flow.warden)
	var rec := StageBeats.Recorder.new(events, flow, TAIL)
	return {"events": events, "flow": flow, "rec": rec}


func _steps(rig: Dictionary, n: int) -> void:
	for i in n:
		rig["rec"].step()


# The whole scripted stage. Tick counts: arrive 10, find 5 + 5, loot 20, hold 7, fight 4, leave 5.
func _play_full(rig: Dictionary, stage: int) -> void:
	var ev = rig["events"]
	ev.stage_entered.emit(stage, false)
	ev.flow_changed.emit("stage")
	_steps(rig, 10)
	ev.landed.emit(5.0)
	_steps(rig, 5)
	ev.scrap_collected.emit(1, Vector3.ZERO, 1)
	_steps(rig, 25)
	ev.warden_engaged.emit(stage)
	_steps(rig, 7)
	ev.posture_changed.emit(rig["flow"].warden, 100.0, true)
	_steps(rig, 4)
	ev.beacon_unsealed.emit(stage)
	ev.flow_changed.emit("gates")
	_steps(rig, 3)
	ev.flow_changed.emit("launch")
	_steps(rig, 2)
	ev.stage_cleared.emit(stage)
	_steps(rig, 6)


func _scripted_stage(t) -> void:
	var rig := _rig()
	_play_full(rig, 1)
	var rows: Array = rig["rec"].rows
	t.eq("one row for the stage", rows.size(), 1)
	var row: Dictionary = rows[0]
	t.eq("row stage", row["stage"], 1)
	t.eq("arrive ticks", row["ticks"]["arrive"], 10)
	t.eq("loot ticks", row["ticks"]["loot"], 20)
	t.eq("find ticks", row["ticks"]["find"], 10)
	t.eq("hold ticks", row["ticks"]["hold"], 7)
	t.eq("fight ticks", row["ticks"]["fight"], 4)
	t.eq("leave ticks", row["ticks"]["leave"], 5)
	t.eq("total ticks is the stage's length", row["total"], 56)
	t.eq("beat ticks sum to the total", StageBeats.sum_ticks(row), 56)
	t.eq("first tick of each beat", row["first"], {"arrive": 1, "find": 11, "loot": 16, "hold": 41, "fight": 48, "leave": 52})
	t.eq("no beat skipped", row["skipped"], [])
	t.eq("the stage reached its exit", row["exit"], true)
	t.eq("one attempt", row["attempts"], 1)
	t.eq("ticks after the exit are not counted", row["total"], 56)
	t.eq("a second stage opens a second row only on entry", rig["rec"].rows.size(), 1)
	rig["events"].stage_entered.emit(2, false)
	_steps(rig, 3)
	t.eq("the next stage is its own row", rig["rec"].rows.size(), 2)
	t.eq("an open row has not reached its exit", rig["rec"].rows[1]["exit"], false)
	t.eq("an open row counts ticks so far", rig["rec"].rows[1]["total"], 3)
	t.eq("an open row lists every beat it has not reached as skipped", rig["rec"].rows[1]["skipped"].size(), 5)
	t.check("the row serialises to JSON and back", JSON.parse_string(JSON.stringify(row)) is Dictionary, "")


func _skipped(t) -> void:
	var rig := _rig()
	var ev = rig["events"]
	ev.stage_entered.emit(3, false)
	_steps(rig, 4)
	ev.landed.emit(5.0)
	ev.warden_engaged.emit(3)
	_steps(rig, 6)
	ev.beacon_unsealed.emit(3)
	ev.flow_changed.emit("gates")
	_steps(rig, 2)
	ev.stage_cleared.emit(3)
	var row: Dictionary = rig["rec"].rows[0]
	t.eq("a stage with no pickup, find or stagger lists the missing beats", row["skipped"], ["loot", "find", "fight"])
	t.eq("skipped beats have zero ticks", [row["ticks"]["loot"], row["ticks"]["find"], row["ticks"]["fight"]], [0, 0, 0])
	t.eq("skipped beats have no first tick", row["first"].has("loot") or row["first"].has("find") or row["first"].has("fight"), false)
	t.eq("the stage still reached its exit", row["exit"], true)
	var other := Node3D.new()
	_nodes.append(other)
	var rig2 := _rig()
	var ev2 = rig2["events"]
	ev2.stage_entered.emit(1, false)
	ev2.landed.emit(1.0)
	ev2.warden_engaged.emit(1)
	ev2.posture_changed.emit(other, 100.0, true)
	_steps(rig2, 3)
	t.eq("another enemy's stagger does not open the fight", rig2["rec"].rows[0]["ticks"]["fight"], 0)
	ev2.posture_changed.emit(rig2["flow"].warden, 40.0, false)
	_steps(rig2, 3)
	t.eq("posture below the stagger does not open the fight", rig2["rec"].rows[0]["ticks"]["fight"], 0)
	t.eq("the guard phase keeps counting as hold", rig2["rec"].rows[0]["ticks"]["hold"], 6)



func _retry(t) -> void:
	var rig := _rig()
	var ev = rig["events"]
	ev.stage_entered.emit(1, false)
	ev.flow_changed.emit("stage")
	ev.landed.emit(1.0)
	_steps(rig, 8)
	ev.player_died.emit()
	ev.flow_changed.emit("dead")
	_steps(rig, 30)
	t.eq("ticks while dead are not a beat", rig["rec"].rows[0]["total"], 8)
	ev.stage_entered.emit(1, true)
	ev.flow_changed.emit("stage")
	_steps(rig, 5)
	t.eq("a retry reuses the stage's row", rig["rec"].rows.size(), 1)
	t.eq("a retry counts a second attempt", rig["rec"].rows[0]["attempts"], 2)
	t.eq("a retry restarts the tick count", rig["rec"].rows[0]["total"], 5)
	t.eq("a retry waits for its own landing", rig["rec"].rows[0]["ticks"]["arrive"], 5)


func _determinism(t) -> void:
	var a := _rig()
	var b := _rig()
	_play_full(a, 1)
	_play_full(b, 1)
	_play_full(a, 2)
	_play_full(b, 2)
	t.eq("two identical scripts log identical rows", JSON.stringify(a["rec"].rows), JSON.stringify(b["rec"].rows))
	t.check("same_timings accepts identical logs", StageBeats.same_timings(a["rec"].rows, b["rec"].rows), "")
	var changed := (JSON.parse_string(JSON.stringify(b["rec"].rows)) as Array)
	changed[1]["ticks"]["find"] += 1
	t.check("same_timings rejects one frame of drift", not StageBeats.same_timings(a["rec"].rows, changed), "")
	t.check("same_timings rejects a missing stage", not StageBeats.same_timings(a["rec"].rows, [a["rec"].rows[0]]), "")


func _audit(t) -> void:
	var rig := _rig()
	_play_full(rig, 1)
	var clean: Array = rig["rec"].rows.duplicate(true)
	var report: Dictionary = StageBeats.audit(clean)
	t.eq("audit counts stages", report["stages"], 1)
	t.eq("audit counts exits", report["exits"], 1)
	t.eq("audit counts skipped beats", report["skipped"], 0)
	t.eq("audit is ok for a clean stage", report["ok"], true)
	var bad := clean.duplicate(true)
	bad[0]["skipped"] = ["loot"]
	bad[0]["exit"] = false
	var report_bad: Dictionary = StageBeats.audit(bad)
	t.eq("audit counts a skipped beat", report_bad["skipped"], 1)
	t.eq("audit counts a missing exit", report_bad["exits"], 0)
	t.eq("audit fails a skipped beat or a missing exit", report_bad["ok"], false)
	t.eq("audit of nothing is not ok", StageBeats.audit([])["ok"], false)
	var line: String = StageBeats.seconds_text(row_for_text(), 90)
	t.eq("seconds_text shows each beat in seconds", line, "arrive 1.0 s, loot 2.0 s, find 0.5 s, hold 0.0 s, fight 0.0 s, leave 0.1 s")


func row_for_text() -> Dictionary:
	return {"ticks": {"arrive": 90, "loot": 180, "find": 45, "hold": 0, "fight": 0, "leave": 9}}


# bot_run's beats column: two children of the same seed on the park table, 450 ticks each, log the
# same stage beats to the frame. The 50-seed sweep with its acceptance lines is the tool run.
func _bot_column(t) -> void:
	var base := OS.get_user_data_dir().path_join("stage-beats-%d" % OS.get_process_id())
	var jobs := []
	for i in 2:
		jobs.append({"script": "res://tools/bot_run.gd", "args": ["--out=" + base.path_join(str(i)), "--policy=skipper",
			"--seeds=1", "--table=park", "--ticks=450"]})
	var results := ChildRuns.run(jobs, 200.0)
	var logs := []
	for i in 2:
		var result: Dictionary = results[i]
		var errors: Array = ChildRuns.summary(result)["errors"]
		t.check("bot child %d ran clean" % i, result["code"] == 0 and not result["timed_out"] and errors.is_empty(),
			"exit %s, timeout %s, errors %s" % [result["code"], result["timed_out"], errors])
		var path := base.path_join(str(i)).path_join("bots.ndjson")
		var rows := FileAccess.get_file_as_string(path).split("\n", false) if FileAccess.file_exists(path) else PackedStringArray()
		var record = JSON.parse_string(rows[0]) if rows.size() == 1 else null
		t.check("bot child %d wrote one record" % i, record is Dictionary, "%d rows in %s" % [rows.size(), path])
		var beats: Array = record.get("beats", []) if record is Dictionary else []
		t.eq("bot child %d logged one stage" % i, beats.size(), 1)
		logs.append(beats)
		if beats.size() == 1:
			var row: Dictionary = beats[0]
			t.eq("bot child %d row is stage 1, still open" % i, [row["stage"], row["exit"]], [1, false])
			t.eq("bot child %d counted every tick it ran" % i, row["total"], int(record["ticks"]))
			t.eq("bot child %d beat ticks sum to the total" % i, StageBeats.sum_ticks(row), int(row["total"]))
			t.check("bot child %d spent ticks arriving and finding" % i, row["ticks"]["arrive"] > 0 and row["ticks"]["find"] + row["ticks"]["loot"] > 0, "%s" % [row["ticks"]])
	t.check("the same seed logs the same beat timings to the frame", logs.size() == 2 and StageBeats.same_timings(logs[0], logs[1]) and logs[0].size() == 1, "")
