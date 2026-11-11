extends SceneTree

const ComicPage := preload("res://src/ui/comic_page.gd")
const Game := preload("res://src/game.gd")
const Parts := preload("res://src/build/parts.gd")
const RunMoments := preload("res://src/core/run_moments.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Intent := preload("res://src/movement/intent.gd")
const Screens := preload("res://src/ui/screens.gd")
const SummaryRows := preload("res://src/ui/summary_rows.gd")
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
	_captions_fit()
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


func _rows() -> void:
	var chips: Array = Screens.summary_chips(KNOWN, 3)
	var words: Array = chips.map(func(chip): return String(chip[2]).to_upper())
	var groups := ["kept", "lost", ""]
	_t.check("every row belongs to a group", chips.all(func(chip): return chip.size() == 4 and chip[3] in groups), str(chips))
	_t.check("cogs and scrap are one row, not a pair side by side", not words.has("COGS LEFT") and not words.has("SCRAP HELD"), str(words))
	_t.check("a run with no side jobs won shows no side-jobs row", chips.size() == 5 and not words.any(func(w): return w.contains("EVENT") or w.contains("JOB")), str(words))
	var won := KNOWN.duplicate()
	won["events_won"] = 2
	won["save_used"] = 1
	var full: Array = Screens.summary_chips(won, 3)
	var by_word := {}
	for chip in full:
		by_word[String(chip[2]).to_upper()] = chip[3]
	_t.check("two side jobs won show the row, in the lost group", by_word.get("SIDE JOBS WON", "?") == "lost", str(by_word))
	_t.check("the run's tally is kept, what the ball carried is lost", by_word.get("TIME") == "kept" and by_word.get("STAGES") == "kept" and by_word.get("CLOCKED OUT") == "kept"
			and by_word.get("SCRAP") == "lost" and by_word.get("PARTS BOLTED ON") == "lost", str(by_word))
	_t.check("the earned save is neither kept nor lost", by_word.get("SAVE USED", "?") == "", str(by_word))
	var blocks: Array = SummaryRows.grouped(full)
	var heads: Array = blocks.map(func(block): return block[0])
	_t.check("the blocks run kept, lost, then the save with no header", heads == ["Kept in your totals", "Lost with this run", ""], str(heads))
	_t.check("a run that used no save has two blocks", SummaryRows.grouped(chips).size() == 2, "")


func _caption() -> void:
	var page: Script = ComicPage
	var floor_size: int = int(page.get_script_constant_map().get("CAPTION_MIN_FONT", 0))
	var small: int = int(page.call("caption_font", 0.3)) if floor_size > 0 else 0
	var large: int = int(page.call("caption_font", 2.0)) if floor_size > 0 else 0
	_t.check("a caption never draws under 18 px, the smallest bold type VISUAL-LANGUAGE allows", floor_size >= 18 and small >= 18 and large >= 18,
		"floor %d, at 0.3 %d, at 2.0 %d" % [floor_size, small, large])


func _texts(node: Node, out: PackedStringArray) -> void:
	if node is Label:
		out.append((node as Label).text)
	for child in node.get_children():
		_texts(child, out)


func _shown() -> void:
	var screens = _game.screens
	var all_text := PackedStringArray()
	_texts(screens._stats, all_text)
	var joined := "\n".join(all_text)
	_t.check("Kept in your totals is drawn exactly once", all_text.count("Kept in your totals") == 1, joined)
	_t.check("Lost with this run is drawn exactly once", all_text.count("Lost with this run") == 1, joined)
	_t.check("kept and lost appear nowhere else on the stats", joined.to_lower().count("kept in your totals") == 1 and joined.to_lower().count("lost with this run") == 1, joined)
	var rows := 0
	for group in screens._stats.get_children():
		rows += (group.get_child(group.get_child_count() - 1) as Container).get_child_count()
	_t.check("each stat is a row under a group", rows >= 5, "%d rows" % rows)
	_t.check("the live screen has neither COGS LEFT nor SCRAP HELD", not joined.contains("COGS LEFT") and not joined.contains("SCRAP HELD"), joined)
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


# Every caption the run-end page can print, with the longest facts the run can feed it.
func _all_captions() -> Dictionary:
	var worlds: Array = Worlds.ROWS.map(func(row): return String(row["name"]))
	var parts: Array = Parts.rows().values().map(func(row): return String(row.get("name", "")))
	var bosses: Array = ["The Reactor Warden", "The Meltdown Warden", "The Hive Warden", "The Brood Warden", "The Mind Warden", "The Crown Warden"]
	for row in Worlds.ROWS:
		bosses.append(String(Worlds.boss_of(int(row["id"])).get("name", "")))
	var facts := {"opening": worlds, "key_item": parts, "boss_stagger": bosses, "biggest_hit": ["99999"],
		"set_piece": ["99 machines"], "near_death": ["100%"], "top_speed": ["99"], "ledger": ["999"]}
	var out := {"first": [], "last_won": [], "last_lost": [], "tall": [], "square": []}
	for kind in RunMoments.CAPTIONS:
		var size := String(RunMoments.SIZES.get(kind, "square"))
		if kind == "opening":
			size = "first"
		elif kind in ["won", "lost"]:
			size = "last_" + kind
		for line in RunMoments.CAPTIONS[kind]:
			for fact in facts.get(kind, [""]):
				out[size].append(String(line).replace("%s", fact))
	out["first"].append(ComicPage.EMPTY_CAPTION)
	return out


# The page as the summary builds it: 3:4, comic_height tall, the panels fit_rows keeps. The project's
# one window is 1600 x 900 stretched as canvas_items, so 900 is the smallest screen height the UI
# sees: the page is 450 tall there, and 240 at the floor a long body shrinks it to. For every size
# sequence the page can hold (a wide opening, up to four middle panels square or tall, a wide
# finale), every real caption goes into each panel in turn with the other panels on their longest,
# a lost run's finale also carries each loss card, and what the page keeps must fit: each caption
# inside its panel, the loss card inside the finale and clear of its caption.
func _captions_fit() -> void:
	var captions := _all_captions()
	var longest := {}
	for size in captions:
		var worst := ""
		for text in captions[size]:
			if ComicPage.caption_rect(Rect2(0, 0, 100, 100), text, 0.5).size.y > ComicPage.caption_rect(Rect2(0, 0, 100, 100), worst, 0.5).size.y:
				worst = text
		longest[size] = worst
	for height in [450.0, 420.0, 390.0]:
		var box := Rect2(Vector2.ZERO, Vector2(height * 0.75, height))
		var k := box.size.x / 720.0
		var bad := PackedStringArray()
		var pages := 0
		var captions_checked := 0
		var shortest := 99
		var cards_shown := 0
		var cards_dropped := 0
		for mask in 16:
			for middle in 5:
				for target in middle + 2:
					var size_of_target := "first" if target == 0 else "last" if target == middle + 1 else ("tall" if (mask >> (target - 1)) & 1 == 1 else "square")
					var pool: Array = captions[size_of_target] + (captions["square"] if size_of_target == "tall" else []) if size_of_target != "last" else captions["last_won"] + captions["last_lost"]
					for text in pool:
						# A won finale has no loss card; a lost one carries each of the four.
						for card in (ComicPage.LOSS_CARDS if text in RunMoments.CAPTIONS["lost"] else [""]):
							var list: Array = [{"size": "wide", "caption": longest["first"]}]
							for i in middle:
								var tall := (mask >> i) & 1 == 1
								list.append({"size": "tall" if tall else "square", "caption": longest["tall"] if tall else longest["square"]})
							list.append({"size": "wide", "kind": "finale", "caption": longest["last_lost"]})
							list[target]["caption"] = text
							var finale_card: String = card if size_of_target == "last" else ComicPage.LOSS_CARDS[0]
							if size_of_target != "last":
								list[list.size() - 1]["caption"] = longest["last_lost"]
							var kept: Array = ComicPage.fit_rows(box, list, finale_card)
							var rects: Array = ComicPage.panel_rects(box, kept.map(func(i): return list[i]))
							pages += 1
							shortest = mini(shortest, kept.size() - mini(list.size(), 3))
							for j in kept.size():
								captions_checked += 1
								var last: bool = j == kept.size() - 1
								var shows_card: bool = last and ComicPage.card_fits(box, list, kept, finale_card)
								cards_shown += 1 if shows_card else 0
								cards_dropped += 1 if last and not shows_card else 0
								if not _fits(rects[j], String(list[kept[j]]["caption"]), k, finale_card if shows_card else ""):
									bad.append("%s in panel %d of %d kept" % [list[kept[j]]["caption"], j, kept.size()])
		var note := "%d pages, %d captions placed at page height %.0f, k %.2f, fewest panels kept (against the minimum) %d, %d loss cards shown, %d left off, %d misfits: %s" % [pages, captions_checked, height, k, shortest, cards_shown, cards_dropped, bad.size(), " | ".join(bad.slice(0, 3))]
		_t.check("every caption lies inside its panel and clear of the loss card at page height %.0f" % height, captions_checked > 0 and bad.is_empty(), note)
		_t.check("and the page keeps at least the opening, one middle panel and the finale at page height %.0f" % height, shortest >= 0, note)
	var lone: Array = ComicPage.panel_rects(Rect2(0, 0, 337.5, 450), [{"size": "wide"}])
	_t.check("the blank page's one caption fits", _fits(lone[0], ComicPage.EMPTY_CAPTION, 337.5 / 720.0), "")
	# The check can fail: a caption three times the longest real one overflows its panel.
	var small := Rect2(Vector2.ZERO, Vector2(337.5, 450.0))
	var tiny: Array = ComicPage.panel_rects(small, [{"size": "wide"}, {"size": "square"}, {"size": "square"}, {"size": "wide", "kind": "finale"}])
	var triple: String = longest["square"] + " " + longest["square"] + " " + longest["square"]
	_t.check("planted: a caption three times the longest real one does not fit", not _fits(tiny[1], triple, small.size.x / 720.0), triple)
	# Under 390 a long body squeezes the page past what dropping panels can rescue. There the page
	# draws the picture alone: at the 240 floor the opening's longest caption is not shown, and at
	# 450 the same caption is.
	var floor_box := Rect2(Vector2.ZERO, Vector2(Screens.COMIC_MIN_HEIGHT * 0.75, Screens.COMIC_MIN_HEIGHT))
	var floor_list: Array = [{"size": "wide", "caption": longest["first"]}, {"size": "square", "caption": longest["square"]}, {"size": "wide", "kind": "finale", "caption": longest["last_lost"]}]
	var floor_rects: Array = ComicPage.panel_rects(floor_box, floor_list)
	var floor_k := floor_box.size.x / 720.0
	var spilled := 0
	for j in floor_list.size():
		var said := String(floor_list[j]["caption"])
		if ComicPage.caption_shown(floor_rects[j], said, floor_k) and not _fits(floor_rects[j], said, floor_k):
			spilled += 1
	_t.check("at the page floor no caption is drawn outside its panel", spilled == 0, "%d spilled" % spilled)
	_t.check("at the page floor the opening's longest caption is left off, not spilled", not ComicPage.caption_shown(floor_rects[0], longest["first"], floor_k), longest["first"])
	_t.check("and at page height 450 the same caption is shown", ComicPage.caption_shown(ComicPage.panel_rects(small, floor_list)[0], longest["first"], small.size.x / 720.0), longest["first"])


# Does the caption lie inside its panel, and clear of a loss card on the same panel?
func _fits(panel: Rect2, text: String, k: float, card := "") -> bool:
	var box: Rect2 = ComicPage.caption_rect(panel, text, k)
	if not panel.encloses(box):
		return false
	if card != "":
		var plate: Rect2 = ComicPage.card_rect(panel, card, k)
		return panel.encloses(plate) and not box.intersects(plate)
	return true
