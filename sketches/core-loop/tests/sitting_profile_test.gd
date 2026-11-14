extends SceneTree

const Game := preload("res://src/game.gd")
const Achievements := preload("res://src/core/achievements.gd")
const T := preload("res://tests/support/t.gd")

# --profile=sitting (SKILL-BAR section 10, B7): all six pilots open on the title, the saved
# profile file is byte-identical after a run started under the flag, and the flag fires no
# unlock achievement. The flag is a launch row, so it is set through the same table a
# command line would use.

var _t := T.new("sitting_profile_test")
var _game
var _earned: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_game.ctx.calm = true
	_run()
	_game.queue_free()
	quit(_t.verdict())
	return true


func _open_ids() -> Array:
	return _game.flow.classes.filter(func(d): return _game.pilot_unlocked(d)).map(func(d): return d.id)


func _profile_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(_game.ctx.profile.path)


func _title_text() -> String:
	return _game.screens._title.text


func _run() -> void:
	_game.events.achievement_earned.connect(func(id): _earned.append(id))
	var classes: Array = _game.flow.classes
	_t.eq("six pilots exist", classes.size(), 6)
	_t.eq("default profile opens one pilot", _open_ids().size(), 1)
	_t.check("default title has no tag", not _title_text().contains("SITTING"), _title_text())
	_game.ctx.profile.save()
	var before := _profile_bytes()
	_t.check("profile file written before the run", before.size() > 0, str(before.size()))
	var parsed: Dictionary = _game.tuning.apply_args(PackedStringArray(["--profile=sitting"]), "launch")
	_t.check("flag parsed from the launch table", parsed.has("profile") and _game.tuning.sitting(), str(parsed))
	_game.sitting_save_guard()
	_t.eq("sitting opens all six", _open_ids().size(), 6)
	_game.flow.open_class_select()
	_game.flow.show_title()
	_t.check("the sitting title stays SCRAPKEEP (the log line records the profile)", _title_text() == "SCRAPKEEP", _title_text())
	_game.screens.toggle_help()
	_game.screens.toggle_help()
	_t.check("the title survives Help and back", _title_text() == "SCRAPKEEP", _title_text())
	_game.flow.open_class_select()
	for i in classes.size():
		_t.check("card %d is not locked" % i, not _game.screens._choices.get_child(i).locked, classes[i].id)
	var owned := false
	for def in classes:
		if not def.starter and _game.ctx.profile.has_pilot(def.id):
			owned = true
	_t.check("profile holds no pilot it did not earn", not owned, "has_pilot false for every non-starter")
	var any_earned := false
	for id in Achievements.ids():
		any_earned = any_earned or _game.ctx.profile.earned(id)
	_t.check("no achievement earned", not any_earned and _earned.is_empty(), str(_earned))
	_game.flow.choose_class(classes.size() - 1)
	_t.eq("a locked pilot starts a run", _game.ctx.run.class_def.id, classes[classes.size() - 1].id)
	_game.events.player_died.emit()
	_game.events.run_ended.emit(true)
	_t.check("profile cannot save under the flag", not _game.ctx.profile.can_save, "can_save false")
	_t.check("profile bytes identical after save points", _profile_bytes() == before, "%d before, %d after" % [before.size(), _profile_bytes().size()])
	any_earned = false
	for id in Achievements.ids():
		any_earned = any_earned or _game.ctx.profile.earned(id)
	_t.check("no achievement earned through the run", not any_earned, str(_earned))
	_t.check("default option restores the lock", _game.tuning.set_option("profile", "default") and _open_ids().size() == 1, "back to one pilot")
	_t.check("the earned sitting opens nothing in advance (W1-78)", _game.tuning.set_option("profile", "sitting-earned")
		and not _game.tuning.sitting() and _open_ids().size() == 1, "%d open" % _open_ids().size())
