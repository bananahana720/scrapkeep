extends SceneTree

# JL-27: the runner's tick contract on Spillway Drop, in process. jev_run.gd's Trial
# runs on a stage of its own and a responder answers every snapshot with the first
# offered option. Every intent must apply at exactly state.tick + k, the events must
# validate, hello must report the effective seed, and two kinematic runs of the same
# seed must write the same trace_hash. A third run is killed at tick KILL_AT (EV-0555,
# end on death): the trial must end at the tick it sees the death, write done.json
# there, and write no state after it. The two trials run one after the other, because
# the stage counts enemies across the whole scene tree. The real process and the
# harness are exercised by the batches under artifacts/local/tasks/JL-27/.

const Stage := preload("res://src/stage.gd")
const JevIO := preload("res://src/jev/jev_io.gd")
const JevRun := preload("res://src/jev/jev_run.gd")

const D := 90
const K := 26
const MAX_TICKS := 4 * D
const SEED := 3
const KILL_AT := 100


class Responder:
	extends RefCounted

	var io
	var answered := {}

	func _init(io_ref) -> void:
		io = io_ref

	func waiting(_seq: int) -> void:
		var seq := 0
		while FileAccess.file_exists(io.dir.path_join("state-%06d.json" % seq)):
			if not answered.has(seq):
				_answer(seq)
			seq += 1

	func _answer(seq: int) -> void:
		var state = JSON.parse_string(FileAccess.get_file_as_string(io.dir.path_join("state-%06d.json" % seq)))
		var offered := JevIO.offered_options(state["jev"])
		var intent := {
			"protocol": JevIO.PROTOCOL,
			"seq": seq,
			"intent": offered[0],
			"arm": "scripted",
			"source": "forced" if offered.size() == 1 else "rule",
			"meta": {"rule": "first-offered"},
		}
		var path: String = io.dir.path_join("intent-%06d.json" % seq)
		var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
		file.store_string(JevIO.stringify(intent) + "\n")
		file.close()
		DirAccess.rename_absolute(path + ".tmp", path)
		answered[seq] = true


var _out := ""
var _runs := ["first", "second", "dying"]
var _current := {}
var _hashes := []
var _failures := 0


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("res://").path_join("../../artifacts/local/jev-bridge-test/spillway").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")


func _check(ok: bool, text: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", text])
	if not ok:
		_failures += 1


func _next() -> bool:
	if _runs.is_empty():
		return false
	var label: String = _runs.pop_front()
	var dir := _out.path_join(label)
	_clear(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)
	var stage = Stage.new()
	stage.test_mode = true
	stage.seed_override = SEED
	viewport.add_child(stage)
	var trial = JevRun.Trial.new(stage, {"io": dir, "scenario": "mid-climb", "seed": SEED, "mode": "kinematic",
		"snapshot_every": D, "hold_ticks": K, "max_ticks": MAX_TICKS})
	var responder := Responder.new(trial.io)
	trial.on_wait = responder.waiting
	# The callable does not keep the responder alive, so the case does.
	_current = {"label": label, "dir": dir, "viewport": viewport, "stage": stage, "trial": trial, "responder": responder}
	return true


func _physics_process(_delta: float) -> bool:
	if _current.is_empty():
		if not _next():
			_finish()
			return true
		return false
	var trial = _current["trial"]
	if not trial.started:
		if not trial.begin():
			_end_current()
		return false
	if _current["label"] == "dying" and trial.view_tick() == KILL_AT and _current["stage"].run.alive():
		_current["stage"].run.damage(1.0e6)
	if trial.tick():
		_end_current()
	return false


func _end_current() -> void:
	var trial = _current["trial"]
	var dir: String = _current["dir"]
	var label: String = _current["label"]
	_check(trial.outcome == "complete" and trial.exit_code == 0, "%s: trial completes (%s)" % [label, trial.outcome])
	var hello = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("hello.json")))
	_check(hello != null and int(hello["seed"]) == SEED and hello["sketch"] == "spillway-drop",
		"%s: hello names spillway-drop and the effective seed %d" % [label, SEED])
	var text := FileAccess.get_file_as_string(dir.path_join(JevIO.EVENTS_FILE))
	var errors := JevIO.validate_events(text)
	_check(errors.is_empty(), "%s: events.ndjson validates %s" % [label, errors.slice(0, 2)])
	var on_time := true
	var intents := 0
	for line in text.split("\n", false):
		var event = JSON.parse_string(line)
		if event["kind"] == "intent":
			intents += 1
			if int(event["tick"]) != int(event["seq"]) * D + K:
				on_time = false
	var least := 1 if label == "dying" else 3
	_check(on_time and intents == trial.applied and intents >= least, "%s: all %d intents applied at seq x %d + %d" % [label, intents, D, K])
	# The scenario line carries the choice counts the stage metrics need (JL-27-A2):
	# the harness's measure() sees only this line, not the state files.
	var multi := 0
	var offered := 0
	var kept := 0
	for seq in trial.snapshots:
		var state = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("state-%06d.json" % seq)))
		var ids := JevIO.offered_options(state["jev"])
		offered += state["jev"]["options"].size()
		kept += ids.size()
		if ids.size() >= 2:
			multi += 1
	var line: Dictionary = trial.scenario_result()
	var total := func(table): return table.values().reduce(func(a, b): return a + b, 0)
	_check(line.get("snapshots", -1) == trial.snapshots and line.get("multi", -1) == multi
		and total.call(line.get("offered", {})) == offered and total.call(line.get("kept", {})) == kept,
		"%s: the scenario line counts %d snapshots, %d with a choice, %d offers, %d kept (got %s)" % [
			label, trial.snapshots, multi, offered, kept,
			[line.get("snapshots"), line.get("multi"), line.get("offered"), line.get("kept")]])
	_check(line.get("threat_rule", "") == "stage-threat-rule 2", "%s: the scenario line names the threat rule epoch" % label)
	var done = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("done.json")))
	if label == "dying":
		var dead_tick: int = line.get("dead_tick", -1)
		var last_state := int(KILL_AT / D)
		_check(dead_tick == KILL_AT + 1 and done != null and int(done["tick"]) == dead_tick,
			"dying: the trial ends at the tick it sees the death (dead_tick %d, done.json tick %s)" % [
				dead_tick, done["tick"] if done != null else "none"])
		_check(trial.snapshots == last_state + 1
			and not FileAccess.file_exists(dir.path_join("state-%06d.json" % (last_state + 1))),
			"dying: no state after the death (%d snapshots, last at tick %d)" % [trial.snapshots, last_state * D])
		_check(line.get("result", "") == "timeout" and line.get("end", "") == "scrapped",
			"dying: the scenario line says timeout, ended scrapped (got %s, %s)" % [line.get("result"), line.get("end")])
		_check(line.get("epoch", "") == "stage-threat-rule 2 + end-on-death", "dying: the scenario line names the epoch")
	else:
		_hashes.append(done["trace_hash"] if done != null else "")
	trial.close()
	_current["viewport"].queue_free()
	_current = {}


func _finish() -> void:
	_check(_hashes.size() == 2 and _hashes[0] != "" and _hashes[0] == _hashes[1],
		"kinematic: the same seed writes the same trace_hash twice (%s)" % [_hashes])
	print("jev_bridge_test: %s" % ("PASS" if _failures == 0 else "FAILED %d" % _failures))
	quit(0 if _failures == 0 else 1)


func _clear(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
