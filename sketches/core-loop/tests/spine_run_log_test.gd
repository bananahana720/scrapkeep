extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# The run log: a scripted three-stage run writes one well-formed line with three stage
# records, and a death in a later run appends a second line carrying the death.

const TICK_LIMIT := 90 * 40

var _game
var _double
var _failures := 0
var _started := false
var _ticks := 0
var _wait := 0
var _phase := "break"
var _ended := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _started:
		_started = true
		_double = SpawnerDouble.new()
		_game.add_child(_double)
		_double.setup(_game.ctx)
		_game.ctx.spawner = _double
		var boss := BossDouble.new()
		_game.add_child(boss)
		boss.setup(_game.ctx)
		_game.ctx.calm = true
		_game.flow.force_warden = true
		_game.player.source = Intent.Scripted.new()
		_game.events.run_ended.connect(func(_w): _ended = true)
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.codex.declare({"id": "storm_lattice", "category": "build"})
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report("timeout", false, "stuck in %s" % _game.flow.state_name())
		return _finish()
	var flow = _game.flow
	if _ended:
		return _finish()
	if flow.state_name() == "boss":
		_game.ctx.boss.defeat()
	if flow.state_name() == "stage" and _phase == "break":
		_wait += 1
		if _wait == 20:
			if _game.run.stage == 1:
				_game.codex.mark_discovered("storm_lattice", _game.player.ball_position())
			_game.run.add_core("event", Vector3.ZERO)
			_double.strike(flow.warden, "arc", 99999.0)
			_game.run.add_part("tread_plating", "gate")
			_game.events.reward_chosen.emit("tread_plating")
			_wait = 0
	return false


func _lines() -> PackedStringArray:
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	return FileAccess.get_file_as_string(path).strip_edges().split("\n", false)


func _finish() -> bool:
	var lines := _lines()
	var record = JSON.parse_string(lines[0]) if lines.size() == 1 else null
	var ok: bool = record is Dictionary
	var stages: Array = record.get("stages", []) if ok else []
	var complete := stages.size() == 3
	for row in stages:
		complete = complete and row["ticks_to_warden_break"] != null and row["heft_at_exit"] != null and (row["part_ids_at_exit"] as Array).size() == int(row["stage"]) \
			and int(row["bonus_cores"]) == 1 and (row["deaths"] as Array).is_empty() and row.has("events_joined") and row.has("events_won")
	_report("one line", ok and lines.size() == 1 and record["outcome"] == "won" and record["run_id"] == _game.run.run_id and record["class"] == "runner_gunner"
			and record["codex"] == ["storm_lattice"] and record.get("anomalies", null) == [] and record.get("brindle_phase_reached", null) == 3,
		"%d line(s) after a won run: outcome %s, class %s, codex %s, Brindle phase %s" % [lines.size(), record.get("outcome", "?") if ok else "?", record.get("class", "?") if ok else "?", record.get("codex", []) if ok else [], record.get("brindle_phase_reached", "?") if ok else "?"])
	var traversal_keys := true
	for key in ["flow_share", "dead_stops", "bites", "smashes", "breaks", "verb_fails", "prompts_shown"]:
		traversal_keys = traversal_keys and ok and record.has(key)
	_report("traversal fields", traversal_keys and float(record.get("prompts_shown", -1)) >= 0.0 and float(record.get("prompts_shown", -1)) == floorf(float(record.get("prompts_shown", -1))) and record.get("breaks") is Dictionary and record.get("verb_fails") is Dictionary,
		"flow share %s, dead stops %s, bites %s, smashes %s" % [record.get("flow_share", "?") if ok else "?", record.get("dead_stops", "?") if ok else "?", record.get("bites", "?") if ok else "?", record.get("smashes", "?") if ok else "?"])
	_report("three stages", complete,
		"%d stage record(s); stage 1 %s" % [stages.size(), JSON.stringify(stages[0]) if stages.size() > 0 else "none"])

	_game.flow.new_run()
	_game.run.damage(9999.0, "test")
	var after := _lines()
	var death = JSON.parse_string(after[-1]) if after.size() == 2 else null
	var died: bool = death is Dictionary and death["outcome"] == "died" and death["run_id"] != record.get("run_id", "") \
		and (death["stages"] as Array).size() == 1 and (death["stages"][0]["deaths"] as Array).size() == 1
	_report("death line", died, "%d line(s); the death record %s" % [after.size(), after[-1] if after.size() > 0 else "none"])
	print("spine_run_log_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
