extends SceneTree

const Store := preload("res://src/core/scrapbook_store.gd")
const CampLines := preload("res://src/core/camp_lines.gd")
const ComicPage := preload("res://src/ui/comic_page.gd")
const CampScrapbook := preload("res://src/ui/camp_scrapbook.gd")
const T := preload("res://tests/support/t.gd")

# The scrapbook, its shelf and the camp line:
#   S1 save/load_all round-trips a page and its shots, newest first;
#   S2 the shelf keeps the newest 60, deleting older JSON and PNGs together;
#   S3 a page with no run_id is refused; an empty shelf loads as [];
#   L1 every case yields a line, at least 40 distinct lines exist, the choice is deterministic;
#   C1 the comic page draws 0, 1, 4, 5 and 6 panels with and without shots, and its layout never overlaps;
#   B1 the scrapbook shows an empty line, turns pages and stops at the ends.

var _t := T.new("camp_scrapbook_test")


func _page(i: int, won := false, world := 1, pilot := "runner_gunner", panels := 4, shot := false) -> Dictionary:
	var rows: Array = []
	for n in panels:
		rows.append({"kind": "key_item" if n < panels - 1 else "finale", "t": 40.0 * (n + 1), "stage": 1, "world": world, "world_name": "Spillway Works",
			"caption": "Panel %d." % n, "sfx": "KRANG!" if n == 1 else "", "size": ["tall", "square", "square", "tall", "square"][n % 5] if n < panels - 1 else "wide",
			"facts": {"hits": n}, "shot": Image.create(48, 27, false, Image.FORMAT_RGB8) if shot else null})
	return {"schema": 1, "run_id": "run-%03d" % i, "ended_unix": 1700000000.0 + i, "pilot": pilot, "pilot_name": "Rivet", "won": won,
		"stage_reached": 2, "world": world, "world_name": "Spillway Works", "title": "SCRAPKEEP #%d: THE SPILLWAY JOB" % i, "panels": rows}


func _initialize() -> void:
	var dir := "user://test-scrapbook-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var store := Store.new(dir)
	_t.eq("S3 empty shelf", store.load_all(), [])
	_t.eq("S3 no run id refused", store.save({"panels": []}), "")
	var path := store.save(_page(1, true, 1, "runner_gunner", 5, true))
	_t.check("S1 save path", path.ends_with("scrapbook/run-001.json") and FileAccess.file_exists(path), path)
	_t.check("S1 png beside it", FileAccess.file_exists(dir.path_join("scrapbook/run-001_0.png")))
	store.save(_page(2))
	var got := store.load_all()
	_t.eq("S1 two pages", got.size(), 2)
	_t.eq("S1 newest first", got[0]["run_id"], "run-002")
	_t.check("S1 shot image back", got[1]["panels"][0]["shot"] is Image and got[0]["panels"][0]["shot"] == null)
	_t.eq("S1 caption kept", got[1]["panels"][1]["caption"], "Panel 1.")
	for i in range(3, 63):
		store.save(_page(i, false, 1, "runner_gunner", 4, i == 3))
	var shelf := store.load_all()
	_t.eq("S2 cap 60", shelf.size(), 60)
	_t.eq("S2 newest", shelf[0]["run_id"], "run-062")
	_t.check("S2 oldest json gone", not FileAccess.file_exists(dir.path_join("scrapbook/run-001.json")))
	_t.check("S2 oldest pngs gone", not FileAccess.file_exists(dir.path_join("scrapbook/run-001_0.png")))
	_t.check("S2 kept json stays", FileAccess.file_exists(dir.path_join("scrapbook/run-062.json")))
	_t.check("S2 kept png stays", FileAccess.file_exists(dir.path_join("scrapbook/run-003_0.png")))

	# Camp lines.
	_t.check("L1 at least 40 lines", CampLines.all_lines().size() >= 40, str(CampLines.all_lines().size()))
	var unique := {}
	for line in CampLines.all_lines():
		unique[line] = true
	_t.eq("L1 lines distinct", unique.size(), CampLines.all_lines().size())
	var cases := {
		"first": [],
		"win": [_page(1, true), _page(0, false, 1, "tarn")],
		"loss1": [_page(2, false, 1), _page(1, true), _page(0, false)],
		"loss2": [_page(2, false, 2), _page(1, true), _page(0, false)],
		"loss3": [_page(2, false, 3), _page(1, true), _page(0, false)],
		"new pilot": [_page(2, false, 1, "tally"), _page(1, true)],
		"streak loss": [_page(3), _page(2), _page(1), _page(0, true)],
		"streak win": [_page(3, true), _page(2, true), _page(1, false)],
	}
	for name in cases:
		var pages: Array = cases[name]
		var a := CampLines.line_for(pages)
		_t.check("L1 line for %s" % name, a != "" and a in CampLines.all_lines(), a)
		_t.eq("L1 deterministic %s" % name, CampLines.line_for(pages), a)
	_t.check("L1 first visit line", CampLines.line_for([]) in CampLines.FIRST)
	_t.check("L1 ledger from stats", CampLines.line_for([], {"deaths": 3.0}) in CampLines.LEDGER)
	_t.check("L1 streak routes", CampLines.line_for(cases["streak loss"]) in CampLines.STREAK_LOSS and CampLines.line_for(cases["streak win"]) in CampLines.STREAK_WIN)
	_t.check("L1 world routes", CampLines.line_for(cases["loss2"]) in CampLines.LOSS_2 and CampLines.line_for(cases["loss3"]) in CampLines.LOSS_3)
	_t.check("L1 outcome field wins over won flag", CampLines.is_won({"outcome": "lost", "won": true}) == false and CampLines.is_won({"outcome": "won"}) and CampLines.is_won({"won": true}))

	# Comic page.
	for n in [0, 1, 4, 5, 6, 9]:
		for shot in [false, true]:
			var cp := ComicPage.new()
			cp.size = Vector2(540, 720)
			root.add_child(cp)
			cp.show_page(_page(1, n % 2 == 0, 1 + n % 3, "runner_gunner", n, shot))
			await process_frame
			var rows: Array = cp.panels
			_t.check("C1 %d panels shot=%s" % [n, shot], rows.size() >= 1 and rows.size() <= 6 and (n == 0 or rows.size() == mini(n, 6)), str(rows.size()))
			cp.queue_free()
	for n in range(1, 7):
		var rows: Array = ComicPage.rows_of(_page(1, false, 1, "x", n))
		var rects := ComicPage.layout(rows, Rect2(0, 0, 400, 600), 10.0)
		var ok := rects.size() == rows.size()
		var area := 0.0
		for i in rects.size():
			area += rects[i].get_area()
			for j in range(i + 1, rects.size()):
				ok = ok and not rects[i].intersects(rects[j])
		_t.check("C1 layout %d no overlap" % n, ok and area > 400.0 * 600.0 * 0.6)
	_t.check("C1 melodrama only on loss", ComicPage.melodrama({"won": true}) == "" and ComicPage.melodrama({"run_id": "a"}) != "")

	# Scrapbook.
	var book := CampScrapbook.new()
	root.add_child(book)
	book.show_pages([])
	_t.check("B1 empty line shown", book._empty.visible and book._empty.text == CampScrapbook.EMPTY_LINE and not book.turn(1))
	book.show_pages(store.load_all())
	await process_frame
	_t.check("B1 first page", book.index == 0 and book._count.text == "Page 1 of 60" and not book._empty.visible)
	_t.check("B1 turn older then stop", book.turn(1) and book.index == 1 and book.turn(-1) and not book.turn(-1))
	book.turn(99)
	_t.eq("B1 last page", book.index, 59)
	var card := CampScrapbook.show_line(book, "A line.")
	_t.check("B1 line card ignores input", card.mouse_filter == Control.MOUSE_FILTER_IGNORE and card.focus_mode == Control.FOCUS_NONE)
	# Clean up the shelf.
	for file in DirAccess.get_files_at(dir.path_join("scrapbook")):
		DirAccess.remove_absolute(dir.path_join("scrapbook").path_join(file))
	quit(_t.verdict())
