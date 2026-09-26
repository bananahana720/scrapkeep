extends Node

# The design feedback loop's run log (DEMO-SPEC). It listens to the bus and reads the
# run state and the ball, never a module's internals, and appends one record to
# runs.ndjson at every death and at the end of a run. A record is cumulative: each
# line carries the whole run so far, with the codex log's run_id.

const LOG_FILE := "runs.ndjson"

var events
var run
var player
var codex
var storage_dir := "user://"
var records_written := 0

var _record := {}
var _stages := {}


func setup(events_ref, run_ref, player_ref, codex_ref, dir: String) -> void:
	name = "RunLog"
	events = events_ref
	run = run_ref
	player = player_ref
	codex = codex_ref
	storage_dir = dir
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.stage_cleared.connect(_on_stage_cleared)
	events.event_started.connect(func(id: String): _stage_list("events_joined").append(id))
	events.event_ended.connect(_on_event_ended)
	events.player_died.connect(_on_player_died)
	events.run_ended.connect(_on_run_ended)


func _on_run_started(class_id: String) -> void:
	_stages = {}
	_record = {"run_id": run.run_id, "class": class_id, "outcome": "running", "brindle_phase_reached": null}


func _stage(index: int) -> Dictionary:
	if not _stages.has(index):
		_stages[index] = {
			"stage": index,
			"ticks_to_warden_break": null,
			"heft_at_exit": null,
			"part_ids_at_exit": null,
			"bonus_cores": 0,
			"deaths": [],
			"events_joined": [],
			"events_won": [],
		}
	return _stages[index]


func _stage_list(key: String) -> Array:
	return _stage(run.stage)[key]


func _ticks() -> int:
	return int(round(run.stage_time * Engine.physics_ticks_per_second))


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_stage(stage)


func _on_beacon_unsealed(stage: int) -> void:
	_stage(stage)["ticks_to_warden_break"] = _ticks()


func _on_stage_cleared(stage: int) -> void:
	var row := _stage(stage)
	row["heft_at_exit"] = run.heft()
	row["part_ids_at_exit"] = run.parts.duplicate()
	row["bonus_cores"] = run.bonus_cores


func _on_event_ended(id: String, outcome: String) -> void:
	if outcome == "won":
		_stage_list("events_won").append(id)


func _on_player_died() -> void:
	var at: Vector3 = player.ball_position()
	_stage_list("deaths").append({"x": at.x, "y": at.y, "z": at.z, "ticks": _ticks()})
	_write("died")


func _on_run_ended(won: bool) -> void:
	_write("won" if won else "lost")


func _write(outcome: String) -> void:
	if _record.is_empty():
		return
	var line := _record.duplicate(true)
	line["outcome"] = outcome
	var stages: Array = []
	var keys := _stages.keys()
	keys.sort()
	for index in keys:
		stages.append(_stages[index])
	line["stages"] = stages
	line["codex"] = codex.discovered_this_run() if codex != null else []
	line["anomalies"] = run.anomalies.duplicate(true)
	if codex.append_line(storage_dir.path_join(LOG_FILE), JSON.stringify(line)):
		records_written += 1
