extends SceneTree

const ComicPage := preload("res://src/ui/comic_page.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Screens := preload("res://src/ui/screens.gd")
const T := preload("res://tests/support/t.gd")

# W35 PF-09 and roadmap item 6: the RUN OVER screen explains every number it shows.
#   - each stat row says what the number is and whether it is kept or lost, in the row itself;
#     the old pair "COGS LEFT" and "SCRAP HELD" is one row; a zero side-job row is left out;
#   - the shift board line is a plain sentence with no bracketed stamp word;
#   - the comic's captions draw at no less than the smallest bold type the project allows;
#   - one Esc press on the summary leaves it (it goes to the camp, as K does).

const DIR := "user://summary_rows_test/"
const PATH := DIR + "run.json"
const KNOWN := {"class": "Sable", "stages": 2, "scrap": 935, "cogs": 922, "mass": 40.0, "heft": 1.0,
	"parts": ["a", "b"], "kills": 11, "events_won": 0, "time": 187.0, "retries": 0, "save_used": 0}

var _t := T.new("summary_rows_test")
var _game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_run.call_deferred()


func _run() -> void:
	_rows()
	_caption()
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = PATH
	root.add_child(_game)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _frames(2)
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(5)
	_game.run.damage(9999.0, "test")
	await _frames(3)
	_t.eq("the run is over", _game.flow.state_name(), "summary")
	_shown()
	await _esc()
	_game.free()
	DirAccess.remove_absolute(PATH)
	quit(_t.verdict())


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _meaning_ok(chip: Array) -> bool:
	if chip.size() < 4:
		return false
	var said := String(chip[3])
	return said.contains("kept") or said.contains("lost")


func _rows() -> void:
	var chips: Array = Screens.summary_chips(KNOWN, 3)
	var words: Array = chips.map(func(chip): return String(chip[2]).to_upper())
	var unexplained := chips.filter(func(chip): return not _meaning_ok(chip)).map(func(chip): return String(chip[2]))
	_t.check("every row says kept or lost", unexplained.is_empty(), "no meaning on: " + ", ".join(unexplained))
	_t.check("cogs and scrap are one row, not a pair side by side", not words.has("COGS LEFT") and not words.has("SCRAP HELD"), str(words))
	_t.check("a run with no side jobs won shows no side-jobs row", chips.size() == 5 and not words.any(func(w): return w.contains("EVENT") or w.contains("JOB")), str(words))
	var won := KNOWN.duplicate()
	won["events_won"] = 2
	var with_jobs: Array = Screens.summary_chips(won, 3)
	_t.check("two side jobs won show the row, explained", with_jobs.size() == 6 and with_jobs.all(_meaning_ok), str(with_jobs.map(func(chip): return chip.slice(1))))
	var meanings := {}
	for chip in chips:
		meanings[String(chip[2]).to_upper()] = String(chip[3]) if chip.size() > 3 else ""
	_t.check("what the ball carries is lost, the run's tally is kept", String(meanings.get("SCRAP", "")).contains("lost")
			and String(meanings.get("PARTS BOLTED ON", "")).contains("lost") and String(meanings.get("KILLS", "")).contains("kept"), str(meanings))


func _caption() -> void:
	var page: Script = ComicPage
	var floor_size: int = int(page.get_script_constant_map().get("CAPTION_MIN_FONT", 0))
	var small: int = int(page.call("caption_font", 0.3)) if floor_size > 0 else 0
	var large: int = int(page.call("caption_font", 2.0)) if floor_size > 0 else 0
	_t.check("a caption never draws under 18 px, the smallest bold type VISUAL-LANGUAGE allows", floor_size >= 18 and small >= 18 and large >= 18,
		"floor %d, at 0.3 %d, at 2.0 %d" % [floor_size, small, large])


func _shown() -> void:
	var screens = _game.screens
	var cells: Array = screens._stats.get_children()
	var bad := PackedStringArray()
	var all_text := PackedStringArray()
	for cell in cells:
		var text := (cell.get_child(1) as Label).text
		all_text.append(text)
		if not (text.contains("kept") or text.contains("lost")):
			bad.append(text)
	_t.check("each stat on the live screen carries kept or lost", cells.size() >= 5 and bad.is_empty(), " | ".join(all_text))
	_t.check("the live screen has neither COGS LEFT nor SCRAP HELD nor EVENTS WON 0", not " ".join(all_text).contains("COGS LEFT")
			and not " ".join(all_text).contains("SCRAP HELD"), " | ".join(all_text))
	_t.check("no bracketed stamp word on the body", not screens.body_text().contains("(LOGGED)") and not screens.body_text().contains("(HIRED)"), screens.body_text())


# One press of Esc, through the engine's input path, and the summary is gone: the title with the camp open.
func _esc() -> void:
	var screens = _game.screens
	# Game._input returns early in test_mode, so the press goes through the whole tree with it off.
	_game.test_mode = false
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ESCAPE
		key.physical_keycode = KEY_ESCAPE
		key.pressed = down
		Input.parse_input_event(key)
		Input.flush_buffered_events()
	await _frames(3)
	_game.test_mode = true
	_t.check("one Esc leaves the summary for the camp, with no second press", _game.flow.state_name() != "summary" and screens.camp_open(),
		"flow %s camp %s" % [_game.flow.state_name(), screens.camp_open()])
