extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

# The objective line names the Warden, the player's punch against its plating and the
# stage's hint, never the word optional; the HUD shows the heft class and the cores.

var _game
var _frames := 0
var _failures := 0
var _stage_one := ""


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		var double := SpawnerDouble.new()
		_game.add_child(double)
		double.setup(_game.ctx)
		_game.ctx.spawner = double
		_game.ctx.calm = true
		_game.flow.force_warden = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_stage_one = _game.flow.objective_text()
		_game.run.add_scrap(75, Vector3.ZERO)
		_game.run.add_core("event", Vector3.ZERO)
		return false
	if _frames < 4:
		return false
	var hud = _game.hud
	_report("stage 1 objective", _stage_one.contains("Warden") and _stage_one.contains("30") and _stage_one.contains("Ram it hard.") and not _stage_one.to_lower().contains("optional"),
		"\"%s\"" % _stage_one)
	_report("heft label", hud.heft_text().begins_with("Heft II") and String(hud._speed.text).contains("Heft II"),
		"after add_scrap(75) the HUD reads \"%s\"" % hud.heft_text())
	_report("core pips", hud._pips.text == "◆◇" and hud.core_pips(0) == "◇◇" and hud.core_pips(3) == "◆◆ +1",
		"one bonus core shows \"%s\"; none \"%s\"; three \"%s\"" % [hud._pips.text, hud.core_pips(0), hud.core_pips(3)])
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var stage_two: String = _game.flow.objective_text()
	_report("stage 2 objective", stage_two.contains("60") and stage_two.contains("vent caps") and not stage_two.to_lower().contains("optional"),
		"\"%s\"" % stage_two)
	print("spine_objective_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
