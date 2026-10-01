extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const ObjectiveView := preload("res://src/ui/objective_view.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The objective line names the Warden, the player's punch against its plating and the
# stage's hint, never the word optional. The HUD shows it in at most five words with
# the same punch and plating as its two bars, the heft class on its dial, and the cores
# as diamonds. The words fit each stage's Warden family (v2 W10): stage 1's reactor is
# the one that vents, and stage 2's hive is beaten through its guard, never its "vents".

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
		# 225 mass is heft 1.5, class II, at 1 + mass/450 (75 was, at the old 1/150).
		_game.run.add_scrap(225, Vector3.ZERO)
		_game.run.add_core("event", Vector3.ZERO)
		return false
	if _frames < 4:
		return false
	var hud = _game.hud
	_report("stage 1 objective", _stage_one.contains("Warden") and _stage_one.contains("plating %d" % int(StageDefs.of(1)["warden_plating"])) and _stage_one.contains("Ram it hard, right after it vents.") and not _stage_one.to_lower().contains("optional"),
		"\"%s\"" % _stage_one)
	var reading: Dictionary = hud.objective_reading()
	_report("hud objective", reading["words"] == "Break the Warden" and reading["icon"] == "obj_warden"
			and is_equal_approx(reading["punch"], _game.flow.punch_now()) and is_equal_approx(reading["plating"], _game.flow.warden_plating())
			and hud._objective.shows_bars() and hud._objective.words == reading["words"],
		"the HUD shows \"%s\" with punch %.0f against plating %.0f as bars" % [reading["words"], reading["punch"], reading["plating"]])
	_report("heft label", hud.heft_reading()["numeral"] == "II" and hud._heft.numeral == "II" and hud._heft.drawn_words() == PackedStringArray(["II"]),
		"after add_scrap(225) the heft dial reads %s" % hud._heft.numeral)
	var three := ObjectiveView.new()
	three.set_objective("obj_warden", "Break the Warden", Color.WHITE, -1.0, -1.0, -1.0, 3, 2)
	var extra: PackedStringArray = three.drawn_words()
	three.free()
	_report("core pips", hud._objective.cores == 1 and ObjectiveView.pip_slots(1, 2) == [true, false]
			and ObjectiveView.pip_slots(0, 2) == [false, false] and extra.has("+1"),
		"one bonus core fills %s; none %s; three add %s" % [ObjectiveView.pip_slots(1, 2), ObjectiveView.pip_slots(0, 2), extra])
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var stage_two: String = _game.flow.objective_text()
	_report("stage 2 objective", stage_two.contains("plating %d" % int(StageDefs.of(2)["warden_plating"])) and stage_two.contains("guard rack") and stage_two.contains("caps") and not stage_two.contains("vent") and not stage_two.to_lower().contains("optional"),
		"\"%s\"" % stage_two)
	var short_one: String = EventKinds.LESSON_SHORT[StageDefs.of(1)["warden_lesson"]]
	var short_two: String = EventKinds.LESSON_SHORT[StageDefs.of(2)["warden_lesson"]]
	_report("lesson words fit the family", short_one.contains("vents") and short_two.contains("guard") and not short_two.contains("vent"),
		"stage 1 (reactor) near the Warden reads \"%s\"; stage 2 (hive) \"%s\"" % [short_one, short_two])
	print("spine_objective_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
