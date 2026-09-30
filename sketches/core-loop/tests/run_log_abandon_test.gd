extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# A run left by a new run gets an "abandoned" line that carries that run's own anomalies,
# codex finds, durability metrics and mass, not the new run's reset state.

var _game
var _failures := 0
var _frames := 0
var _expected_mass := 0.0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		var double := SpawnerDouble.new()
		_game.add_child(double)
		double.setup(_game.ctx)
		_game.ctx.spawner = double
		var boss := BossDouble.new()
		_game.add_child(boss)
		boss.setup(_game.ctx)
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(1)
		_game.codex.declare({"id": "probe_entry", "category": "build"})
		return false
	if _frames < 12:
		return false
	_game.run.armor_mode = true
	_game.run.note_anomaly("probe_marker")
	_game.run.mass = 7.5
	_game.run.metrics["probe_metric"] = 3
	_game.codex.mark_discovered("probe_entry", _game.player.ball_position())
	_game.flow.new_run()
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	_check("lines", lines.size() >= 1, "%d line(s)" % lines.size())
	var line: Dictionary = JSON.parse_string(lines[lines.size() - 1]) if lines.size() > 0 else {}
	_check("outcome", line.get("outcome") == "abandoned", "outcome %s" % line.get("outcome"))
	var anomalies := JSON.stringify(line.get("anomalies", []))
	_check("anomalies", anomalies.contains("probe_marker"), anomalies)
	_check("codex", (line.get("codex", []) as Array).has("probe_entry"), JSON.stringify(line.get("codex", [])))
	var durability: Dictionary = line.get("durability", {})
	_check("metrics", durability.get("probe_metric") == 3, JSON.stringify(durability))
	_check("mass", is_equal_approx(float(durability.get("mass_end", -1.0)), 7.5), "mass_end %s" % durability.get("mass_end"))
	print("run_log_abandon_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures > 0 else 0)
	return true
