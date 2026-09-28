extends Node

# The design feedback loop's run log (DEMO-SPEC). It listens to the bus and reads the
# run state and the ball, never a module's internals, and appends one record to
# runs.ndjson at every death and at the end of a run. A record is cumulative: each
# line carries the whole run so far, with the codex log's run_id. A run left without a
# death or an end since its last line (a new run started, the game closed, a bot that
# gave up) gets one more line with outcome "abandoned" and where it was left
# ("abandoned_in": "stage" or "arena"), so the loop sees runs that never finished. The
# arena block (I3) is the boss-entry record: it rides in every line after entry.

const LOG_FILE := "runs.ndjson"
const LoopMode := preload("res://src/core/loop_mode.gd")

var events
var run
var player
var codex
var storage_dir := "user://"
var records_written := 0

var _record := {}
var _stages := {}
var _in_arena := false
var _phase := 0
# True when the run has moved on since its last line.
var _dirty := false


func setup(events_ref, run_ref, player_ref, codex_ref, dir: String) -> void:
	name = "RunLog"
	events = events_ref
	run = run_ref
	player = player_ref
	codex = codex_ref
	storage_dir = dir
	events.run_started.connect(_on_run_started)
	events.stage_entered.connect(_on_stage_entered)
	events.warden_engaged.connect(_on_warden_engaged)
	events.beacon_unsealed.connect(_on_beacon_unsealed)
	events.stage_cleared.connect(_on_stage_cleared)
	events.event_started.connect(func(id: String): _stage_list("events_joined").append(id))
	events.event_ended.connect(_on_event_ended)
	events.player_died.connect(_on_player_died)
	events.run_ended.connect(_on_run_ended)
	events.boss_phase_changed.connect(_on_boss_phase)
	events.stage_content_cleared.connect(_on_stage_content_cleared)


func _on_run_started(class_id: String) -> void:
	_abandon()
	_stages = {}
	_in_arena = false
	_phase = 0
	_record = {"run_id": run.run_id, "class": class_id, "outcome": "running", "brindle_phase_reached": null}
	_record.merge(_lab_tag())


# The fun lab's mode and gun role (loop_mode.gd), on the run and on each stage entry, so
# a report splits runs by mode even when the panel flipped it mid-run.
func _lab_tag() -> Dictionary:
	var tuning = player.get("tuning") if player != null else null
	return LoopMode.tag(tuning) if tuning != null else {}


func _stage(index: int) -> Dictionary:
	if not _stages.has(index):
		_stages[index] = {
			"stage": index,
			"ticks_to_warden_engaged": null,
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
	_in_arena = false
	_dirty = true
	_stage(stage).merge(_lab_tag(), true)


# warden_engaged fires once per stage attempt, so a retry's engagement replaces the
# last one, as a retry's break does.
func _on_warden_engaged(stage: int) -> void:
	_stage(stage)["ticks_to_warden_engaged"] = _ticks()


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


# A death in the arena goes in the arena's own record, on the arena's clock and the
# run's, with Brindle's phase; the stage rows keep only deaths on their own maps.
func _on_player_died() -> void:
	var at: Vector3 = player.ball_position()
	var death := {"x": at.x, "y": at.y, "z": at.z, "ticks": _ticks()}
	if _in_arena:
		death["run_ticks"] = int(round(run.run_time * Engine.physics_ticks_per_second))
		death["phase"] = _phase
		(_record["arena"]["deaths"] as Array).append(death)
	else:
		_stage_list("deaths").append(death)
	_write("died")


func _on_stage_content_cleared(reason: String) -> void:
	if reason != "arena" and reason != "arena_retry":
		return
	_in_arena = true
	_dirty = true
	_phase = 0
	if not _record.has("arena"):
		_record["arena"] = {"entries": 0, "deaths": []}
	_record["arena"]["entries"] += 1


func _on_boss_phase(phase: int, _name: String) -> void:
	_phase = phase
	var reached = _record.get("brindle_phase_reached")
	_record["brindle_phase_reached"] = maxi(phase, int(reached)) if reached != null else phase


func _on_run_ended(won: bool) -> void:
	_write("won" if won else "lost")


func _abandon() -> void:
	if _dirty and not _record.is_empty():
		_record["abandoned_in"] = "arena" if _in_arena else "stage"
		_write("abandoned")
		_record.erase("abandoned_in")


func _exit_tree() -> void:
	_abandon()


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
	# M0's delivered-damage ledger (combat.gd), mirrored onto the run through set_meta so
	# this module never needs its own reference to the spawner. A run with no hits still
	# carries the reset ledger (total 0.0), so a zero-damage run reads as zero, not missing.
	line["delivered_damage"] = run.get_meta("delivered_damage", {})
	_dirty = false
	if codex.append_line(storage_dir.path_join(LOG_FILE), JSON.stringify(line)):
		records_written += 1
