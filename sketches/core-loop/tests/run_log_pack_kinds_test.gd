extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunLog := preload("res://src/core/run_log.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")

# Each stage row's packs entry carries the pack's faction and the kinds it spawned, in
# spawn order, so a run line says what arrived, not only who sent it (EV-0624).

var _game
var _failures := 0
var _frames := 0


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
		return false
	if _frames < 12:
		return false
	_game.events.pack_arrived.emit("fleet", Vector3.ZERO, ["chaser", "chaser", "lobber"])
	_game.events.pack_arrived.emit("raid", Vector3.ZERO, ["thief"])
	_game.flow.new_run()
	var path: String = _game.storage_dir.path_join(RunLog.LOG_FILE)
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n", false)
	var line: Dictionary = JSON.parse_string(lines[lines.size() - 1]) if lines.size() > 0 else {}
	var row: Dictionary = {}
	for one in line.get("stages", []):
		row = one
		break
	var packs: Array = row.get("packs", [])
	_check("two packs logged", packs.size() == 2, JSON.stringify(packs))
	var first: Dictionary = packs[0] if packs.size() > 0 and packs[0] is Dictionary else {}
	var second: Dictionary = packs[1] if packs.size() > 1 and packs[1] is Dictionary else {}
	_check("first pack carries faction and kind list", first.get("faction") == "fleet" and first.get("kinds") == ["chaser", "chaser", "lobber"], JSON.stringify(first))
	_check("second pack carries its kind", second.get("faction") == "raid" and second.get("kinds") == ["thief"], JSON.stringify(second))
	print("run_log_pack_kinds_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures > 0 else 0)
	return true
