extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Achievements := preload("res://src/core/achievements.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ContentRegistry := preload("res://src/core/content_registry.gd")

# ST5-3: every achievement row that unlocks a pilot carries a beat line of at most
# BEAT_WORDS words, validate_beats refuses a pilot row without one, one past the cap or one with no row, the
# earned toast's text is the name then the beat, and a locked pilot card shows the beat
# under its condition.

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
			_t.eq("%s has no beat" % id, Achievements.beat_of(id), "")
			continue
		pilots += 1
		var beat := Achievements.beat_of(id)
		var words := beat.split(" ", false).size()
		_t.check("%s beat within cap" % id, beat != "" and words <= Achievements.BEAT_WORDS, "%d words: %s" % [words, beat])
		_t.eq("%s toast second line" % id, Achievements.toast_text(id), "%s\n%s" % [row["name"], beat])
	_t.eq("pilot unlock rows", pilots, 5)
	_t.eq("a row without a beat toasts its name", Achievements.toast_text("kills_100"), "Hundred Down")

	var bare: Dictionary = Achievements.BEATS.duplicate()
	bare.erase("brindle_routed")
	var long: Dictionary = Achievements.BEATS.duplicate()
	long["brindle_routed"] = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen"
	var stray: Dictionary = Achievements.BEATS.duplicate()
	stray["no_such_row"] = "A line for nothing."
	_t.check("validate_beats refuses a pilot row with no beat", not Achievements.validate_beats(Achievements.ROWS, bare).is_empty(), "")
	_t.check("validate_beats refuses a beat past the cap", not Achievements.validate_beats(Achievements.ROWS, long).is_empty(), "")
	_t.check("validate_beats refuses a beat with no row", not Achievements.validate_beats(Achievements.ROWS, stray).is_empty(), "")
	_t.eq("the beat table validates", Achievements.validate_beats(), [])
	_t.eq("the row table still validates", Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), ClassDef.all().map(func(d): return d.id), Cosmetics.ids()), [])
	_t.eq("the pinned ROWS digest is unchanged", ContentRegistry.digest(Achievements.ROWS), ContentRegistry.GOLDEN_HASHES["achievements.ROWS"])

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
			card.hint_text.ends_with("\n" + Achievements.beat_of(id)) and card.hint_text.begins_with(String(Achievements.row(id)["text"])),
			card.hint_text.replace("\n", " / "))
	_t.check("locked cards checked", checked >= 1, "%d" % checked)
	_game.free()
	quit(_t.verdict())
