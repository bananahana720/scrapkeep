extends SceneTree
# F6 2026-10-04: the lesson rows are gone, so the lesson-words check is removed.

# Legacy plating/third-stage rule: use the multiworld double, not the alpha route.

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")
const Objectives := preload("res://src/core/objectives.gd")

# The objective line names the Warden, the player's punch against its plating and the
# stage's hint, never the word optional. The HUD shows the row objectives.gd picks in at
# most five words, with no bars, heft dial or core pips. The words fit each stage's Warden
# family (v2 W10): stage 1's reactor is the one that vents, and stage 2's hive is beaten
# through its guard, never its "vents".

# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _frames := 0
var _failures := 0
var _stage_one := ""


func _initialize() -> void:
	_game = LegacyGame.new()
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
		return false
	# Half the hull is taken two frames before the HUD is read, so its bar has had a frame to follow.
	# The regen clock is set back with it (a fresh run's hull regenerates at once), so the half holds.
	if _frames == 2:
		_game.run.hp = _game.run.max_hp * 0.5
		_game.run.since_damage = 0.0
	if _frames < 4:
		return false
	var hud = _game.hud
	_report("hull bar", absf(hud.hull_shown() - 0.5) < 0.01, "half the hull is gone and the bar stands at %.2f" % hud.hull_shown())
	_report("stage 1 objective", _stage_one.contains("Warden") and _stage_one.contains("plating %d" % int(StageDefs.of(1)["warden_plating"])) and _stage_one.contains("Break its guard, then smash the core.") and not _stage_one.to_lower().contains("optional"),
		"\"%s\"" % _stage_one)
	var reading: Dictionary = hud.objective_reading()
	_report("hud objective", reading["words"] == "Break the Warden" and reading["icon"] == "obj_warden"
			and hud._objective.words == reading["words"] and hud._objective.drawn_words() == PackedStringArray(["Break the Warden"]),
		"the HUD shows \"%s\" with glyph %s and no bars, pips or heft dial" % [reading["words"], reading["icon"]])
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var stage_two: String = _game.flow.objective_text()
	_report("stage 2 objective", stage_two.contains("plating %d" % int(StageDefs.of(2)["warden_plating"])) and stage_two.contains("guard rack") and stage_two.contains("smash the core") and not stage_two.contains("caps") and not stage_two.contains("vent") and not stage_two.to_lower().contains("optional"),
		"\"%s\"" % stage_two)
	print("spine_objective_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
