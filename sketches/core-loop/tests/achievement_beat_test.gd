extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")

# ST5-3: every achievement row that unlocks a pilot carries a beat line of at most
# BEAT_WORDS words, validate refuses a pilot row without one or with one past the cap, the
# earned toast's text is the name then the beat, and a locked pilot card shows the beat
# under its condition.
# 2026-10-10 (w13 B5 fix round, re-pin): a beat-less row with a delivered cosmetic reward
# toasts its name then "New look: <item>" (CUSTOMIZE section 4); validate now gets the real
# cosmetic ids, and the beat checks filter on validate's beat messages only, so a reward id
# that happens to contain "beat" (trail_any_downbeat) is not counted as a beat problem.

var _t := preload("res://tests/support/t.gd").new("achievement_beat_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var pilots := 0
	for id in Achievements.ids():
		var row: Dictionary = Achievements.row(id)
		if not row.get("reward", {}).has("pilot"):
			_t.check("%s has no beat" % id, not row.has("beat"), str(row.get("beat", "")))
			continue
		pilots += 1
		var beat := Achievements.beat_of(id)
		var words := beat.split(" ", false).size()
		_t.check("%s beat within cap" % id, beat != "" and words <= Achievements.BEAT_WORDS, "%d words: %s" % [words, beat])
		_t.eq("%s toast second line" % id, Achievements.toast_text(id), "%s\n%s" % [row["name"], beat])
	_t.eq("pilot unlock rows", pilots, 5)
	_t.eq("a row without a beat toasts its name first", Achievements.toast_text("kills_100").split("\n")[0], "Hundred Down")
	_t.eq("a delivered cosmetic reward toasts New look", Achievements.toast_text("kills_100"), "Hundred Down\nNew look: %s" % Cosmetics.row("paint_rivet_forge")["name"])
	_t.eq("a pending cosmetic reward toasts its name only", Achievements.toast_text(Achievements.for_cosmetic("shell_sable_felt")), Achievements.row(Achievements.for_cosmetic("shell_sable_felt"))["name"])

	var signals := Achievements.bus_signals()
	var ids: Array = []
	for def in ClassDef.all():
		ids.append(def.id)
	var bare: Dictionary = Achievements.row("brindle_routed").duplicate(true)
	bare.erase("beat")
	var long: Dictionary = Achievements.row("brindle_routed").duplicate(true)
	long["beat"] = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen"
	var cosmetics := Cosmetics.ids()
	var beat_problem := func(p): return p.contains(": beat ") or p.contains("beat line")
	_t.check("validate refuses a pilot row with no beat", not Achievements.validate({"x": bare}, signals, ids, cosmetics).filter(beat_problem).is_empty(), "")
	_t.check("validate refuses a beat past the cap", not Achievements.validate({"x": long}, signals, ids, cosmetics).filter(beat_problem).is_empty(), "")
	var table_beat := Achievements.validate(Achievements.ROWS, signals, ids, cosmetics).filter(beat_problem)
	_t.check("the table validates", table_beat.is_empty(), "%s" % [table_beat])

	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(3)
	_game.flow.press_start()
	await _frames(2)
	var checked := 0
	for card in _game.screens.class_cards():
		if not card.locked or card.def.starter:
			continue
		var id := Achievements.for_pilot(card.def.id)
		checked += 1
		_t.check("%s locked card shows the beat under the condition" % card.def.display_name,
			card.hint_text.ends_with("\n" + Achievements.beat_of(id)) and card.hint_text.begins_with(String(card.def.unlock["label"])),
			card.hint_text.replace("\n", " / "))
	_t.check("locked cards checked", checked >= 1, "%d" % checked)
	_game.free()
	quit(_t.verdict())
