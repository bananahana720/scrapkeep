extends SceneTree

const Game := preload("res://src/game.gd")

const PAGES := {
	"help": "res://src/ui/help_page.gd",
	"achievements": "res://src/ui/achievements_page.gd",
	"work_orders": "res://src/ui/work_orders_page.gd",
	"logbook": "res://src/ui/logbook_page.gd",
	"settings": "res://src/ui/settings_pages.gd",
	"camp": "res://src/ui/camp_menu.gd",
	"jukebox": "res://src/ui/jukebox_page.gd",
	"radio": "res://src/ui/radio_page.gd",
}

const BLOCKED_BY := {
	"page_open": ["achievements", "help", "jukebox", "logbook", "radio", "settings", "work_orders"],
	"overlay_open": ["achievements", "camp", "help", "jukebox", "logbook", "radio", "work_orders"],
	"title_deck": ["achievements", "camp", "help", "jukebox", "logbook", "radio", "settings", "work_orders"],
	"toggle_help": ["achievements", "logbook", "settings", "work_orders"],
	"toggle_achievements": ["help", "logbook", "settings", "work_orders"],
	"toggle_work_orders": ["achievements", "help", "logbook", "settings"],
	"toggle_logbook": ["achievements", "help", "settings", "work_orders"],
	"toggle_settings": ["achievements", "help", "logbook", "work_orders"],
	"toggle_camp": ["achievements", "help", "logbook", "settings", "work_orders"],
}

var _t := preload("res://tests/support/t.gd").new("screens_page_list_test")
var _game
var _screens
var _pages := {}


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await _frames(3)
	_screens = _game.screens
	_screens.prologue_enabled = false
	_game.ctx.calm = true
	_game.flow.show_title()
	await _frames(2)
	for id in PAGES:
		var page = _screens.get("_" + id)
		if _t.check("the screen owns a %s page" % id, page is Control and page.get_script() != null and page.get_script().resource_path == PAGES[id], str(page)):
			_pages[id] = page
	if _t.eq("every page is found", _pages.size(), PAGES.size()):
		for guard in BLOCKED_BY:
			var blocked: Array = []
			for id in _pages:
				_reset()
				_pages[id].visible = true
				if _blocks(guard):
					blocked.append(id)
			_reset()
			blocked.sort()
			_t.eq("%s is blocked by exactly these pages" % guard, blocked, BLOCKED_BY[guard])
	_list_holds_every_page()
	_game.free()
	quit(_t.verdict())


func _reset() -> void:
	_screens._stop_walk()
	for id in _pages:
		_pages[id].visible = false
	_t.check("reset leaves the title screen", _screens.get("_state") == "title" and not _screens.overlay_open() and not _screens.settings_open(), _screens.get("_state"))


func _blocks(guard: String) -> bool:
	match guard:
		"page_open":
			return _screens.page_open()
		"overlay_open":
			return _screens.overlay_open()
		"title_deck":
			_screens._layout_backdrop()
			return _screens.get("_veil").anchor_bottom == 1.0
		"toggle_camp":
			_screens.toggle_camp()
			return not _screens.walking()
	var target_id := guard.trim_prefix("toggle_")
	var target: Control = _pages[target_id]
	var before := target.visible
	_screens.call(guard)
	return target.visible == before


func _list_holds_every_page() -> void:
	var listed = _screens.get("_pages")
	if not _t.check("the screen holds one list of pages", listed is Array and not listed.is_empty(), str(listed)):
		return
	var found: Array = []
	var scripts: Array = []
	for child in _screens.get("_content").get_children():
		var script = child.get_script()
		var path: String = script.resource_path if script != null else ""
		if path.ends_with("_page.gd") or path.ends_with("_pages.gd") or path.ends_with("_menu.gd"):
			found.append(child)
			scripts.append(path)
	scripts.sort()
	var want: Array = PAGES.values()
	want.sort()
	_t.eq("the page nodes under the screen are exactly these", scripts, want)
	for page in found:
		_t.check("the list holds %s" % page.get_script().resource_path.get_file(), page in listed, "")
	var unique: Array = []
	for page in listed:
		if not page in unique:
			unique.append(page)
	_t.check("the list holds each page once and nothing else", unique.size() == listed.size() and listed.size() == found.size(),
		"%d listed, %d unique, %d found" % [listed.size(), unique.size(), found.size()])
