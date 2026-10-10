extends SceneTree

const RunLog := preload("res://src/core/run_log.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# BUGFIX-CORE F002 (2026-10-09): a cleared stage's posture fight_ticks survive a later
# stage's record. Stage 1's Warden posture opens at tick 100 and the stage clears at tick
# 900 with no break; a line written at stage 2's tick 50 must still say 800 for stage 1,
# not a value read from stage 2's clock.

const WARDEN_SRC := "extends Node3D\nfunc chunks_left() -> int:\n\treturn 4\nfunc glances() -> int:\n\treturn 0\n"
const CODEX_SRC := "extends RefCounted\nvar lines := []\nfunc discovered_this_run() -> Array:\n\treturn []\nfunc append_line(_path: String, text: String) -> bool:\n\tlines.append(text)\n\treturn true\n"

var _t := T.new("run_log_posture_stages_test")


func _double(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script


func _tick(run, ticks: int) -> void:
	run.stage_time = float(ticks) / Engine.physics_ticks_per_second


func _initialize() -> void:
	var events := GameEvents.new()
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").new())
	var codex = _double(CODEX_SRC).new()
	var warden: Node3D = _double(WARDEN_SRC).new()
	var log := RunLog.new()
	log.setup(events, run, null, codex, "user://")
	events.run_started.emit("probe")
	run.stage = 1
	_tick(run, 0)
	events.stage_entered.emit(1, false)
	_tick(run, 100)
	events.posture_changed.emit(warden, 0.2, false)
	_tick(run, 900)
	events.stage_cleared.emit(1)
	run.stage = 2
	_tick(run, 0)
	events.stage_entered.emit(2, false)
	_tick(run, 50)
	events.run_ended.emit(false)
	_t.eq("one line written", codex.lines.size(), 1)
	var line: Dictionary = JSON.parse_string(codex.lines[0]) if codex.lines.size() > 0 else {}
	var stage_one: Dictionary = {}
	for row in line.get("stages", []):
		if int(row["stage"]) == 1:
			stage_one = row
	var posture: Dictionary = stage_one.get("posture", {})
	_t.eq("stage 1 keeps its posture fight_ticks", int(posture.get("fight_ticks", -1)), 800)
	log.free()
	warden.free()
	events.free()
	quit(_t.verdict())
