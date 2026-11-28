extends SceneTree

const Game := preload("res://src/game.gd")
const ChasePlate := preload("res://src/ui/chase_plate.gd")
const ShiftBoard := preload("res://src/core/shift_board.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Profile := preload("res://src/core/profile.gd")
const Screens := preload("res://src/ui/screens.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The summary says what to chase next (BACKLOG W1-72, gameplay critique finding 10).
#   (a) the plate's reading: the shift board's next rung, its words and what it opens, and the world's
#       secret count from the codex; a stamped rung moves it on; a full board leaves the secrets;
#       a world with no secret rows and a full board shows no plate.
#   (b) the game's path: a lost run's summary tapes the plate up left of the comic page, opposite the
#       "next shift" note; once the shift closes it names the rung after the one the run stamped (a
#       first run's Clocked In), its pips match the codex, and the column and the row still fit.

const DIR := "user://summary_chase_test/"
const PATH := DIR + "run.json"

var _t := T.new("summary_chase_test")
var _game
var _serial := 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_run.call_deferred()


func _run() -> void:
	_reading()
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = PATH
	root.add_child(_game)
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	await _frames(2)
	await _on_summary()
	_game.free()
	DirAccess.remove_absolute(PATH)
	quit(_t.verdict())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _fresh() -> Profile:
	_serial += 1
	var path := "%schase-%d-%d.json" % [DIR, OS.get_process_id(), _serial]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var store := Profile.new(path)
	store.load_profile()
	return store


func _reading() -> void:
	var profile := _fresh()
	var none := func(_id): return false
	var two := func(id): return id in ["spillway_turbine_seep", "flume_weir_cache"]
	var read := ChasePlate.reading(profile, 1, none)
	_t.eq("a fresh profile chases the board's first rung", read["next"], "clock_in")
	_t.eq("its words are the rung's own", [read["name"], read["text"]], [ShiftBoard.RUNGS["clock_in"]["name"], ShiftBoard.RUNGS["clock_in"]["text"]])
	_t.eq("it says what the rung opens", read["pays"], ShiftBoard.pays_words(ShiftBoard.RUNGS["clock_in"]["pays"]))
	_t.eq("the Spillway's secrets, none found", [read["secrets"]["name"], read["secrets"]["found"], read["secrets"]["total"]],
		["Spillway", 0, Secrets.WORLD_CODEX[1].size()])
	_t.eq("found secrets count from the codex", int(ChasePlate.reading(profile, 1, two)["secrets"]["found"]), 2)
	profile.earn("ach_d7_salt_skip", 1.0)
	_t.eq("a stamped rung moves the plate on", ChasePlate.reading(profile, 1, none)["next"], "first_warden")
	var said := ChasePlate.said(ChasePlate.reading(profile, 1, two))
	_t.eq("the plate as words", said, "Warden Breaker. Break a Warden's core in the Spillway. A new look. Spillway secrets 2 of %d." % Secrets.WORLD_CODEX[1].size())
	var later := ChasePlate.reading(profile, 2, none)
	_t.check("a world with no secret rows shows the rung alone", (later["secrets"] as Dictionary).is_empty() and ChasePlate.shows(later), str(later))
	var full := _fresh()
	for id in ShiftBoard.ids():
		var when: Dictionary = ShiftBoard.RUNGS[id]["when"]
		if when.has("earned"):
			full.earn(String(when["earned"]), 1.0)
		else:
			full.hear_tune(String(when["tune"]))
	var done := ChasePlate.reading(full, 1, two, true)
	_t.check("a full board leaves the secrets", done["next"] == "" and ChasePlate.shows(done)
		and ChasePlate.said(done) == "Spillway secrets 2 of %d." % Secrets.WORLD_CODEX[1].size(), ChasePlate.said(done))
	_t.check("a full board in a world with no secrets shows nothing", not ChasePlate.shows(ChasePlate.reading(full, 2, none, true)))
	var plate := ChasePlate.new(ChasePlate.reading(profile, 1, two))
	var pips: Array = plate.find_child("Pips", true, false).get_children()
	_t.check("one pip per secret, the found ones first as stars", pips.size() == Secrets.WORLD_CODEX[1].size()
		and pips.slice(0, 2).all(func(p): return p.texture == preload("res://src/core/icons.gd").shape("star"))
		and pips.slice(2).all(func(p): return p.texture == preload("res://src/core/icons.gd").shape("ring")), str(pips.size()))
	plate.free()


func _on_summary() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(10)
	_game.combat.heft_override = 0.05
	_game.flow._engage()
	_game.run.damage(9999.0, "warden")
	await _frames(6)
	var screens = _game.screens
	_t.eq("the run is over", _game.flow.state_name(), "summary")
	var codex = _game.ctx.codex
	var profile = _game.ctx.profile
	var sitting: bool = _game.tuning != null and _game.tuning.sitting()
	var expect := ChasePlate.reading(profile, _game.ctx.stages.world_of(_game.run.stage), func(id): return codex.known(id), sitting)
	_t.check("the shift has closed: the first run clocked in, and the plate chases the rung after it",
		ShiftBoard.stamped("clock_in", profile) and expect["next"] == "first_warden", str(expect))
	_t.eq("the summary's plate reads the board and the codex as they stand", screens.chase_text(), ChasePlate.said(expect))
	_t.check("it names the next rung", screens.chase_text().begins_with("Warden Breaker."), screens.chase_text())
	var chase: Control = screens._chase
	var comic: Control = screens.comic_page()
	_t.check("the plate stands left of the comic page, the note right of it", chase != null and comic != null and chase.get_index() == 0
		and comic.get_index() == 1 and chase.global_position.x + chase.size.x <= comic.global_position.x
		and (screens._tip == null or screens._tip.global_position.x >= comic.global_position.x + comic.size.x),
		"chase %s, comic %s" % [chase, comic])
	var floor_y: float = screens._screen().y - 8.0
	_t.check("the column still ends on the screen", screens._title.get_global_rect().position.y >= 0.0
		and screens._actions.get_global_rect().end.y <= floor_y and chase.get_global_rect().end.y <= screens._actions.get_global_rect().position.y,
		"plate to %.0f, buttons %.0f to %.0f of %.0f" % [chase.get_global_rect().end.y, screens._actions.get_global_rect().position.y, screens._actions.get_global_rect().end.y, floor_y])
	_t.check("the row fits the narrowest screen", screens._comic_row.get_combined_minimum_size().x <= Screens.NARROW_W - 2.0 * Screens.SIDE,
		"%.0f px" % screens._comic_row.get_combined_minimum_size().x)
	_game.flow.new_run()
	await _frames(3)
	_t.eq("a new run takes the plate down", screens.chase_text(), "")
	_game.combat.heft_override = -1.0
