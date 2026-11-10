extends SceneTree

const Game := preload("res://src/game.gd")
const Screens := preload("res://src/ui/screens.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const T := preload("res://tests/support/t.gd")

# Wave 36 unslop-nav (ruling cx): the title, pause and settings screens lose their slop.
#   - the headings that restate the screen (SETTINGS, Choose your pilot, HOW TO PLAY, ACHIEVEMENTS,
#     CAMP over a station page) are on no built screen, read from the labels the screen holds;
#   - the pause column is Resume, New run, Field notes, Radio, Settings, Quit; Music, Effects,
#     Screen shake, Hit-stop and Find cards are the Feel tab both hosts show, and the title's Music
#     row writes the value the pause menu used to;
#   - "Restart run" and "Run again" are on no screen;
#   - Esc on the title moves the focus to Quit and never quits, however often it is pressed;
#   - the control rows name a verb once, and the wording rows read as the brief says.
# A planted heading must fail the heading check, so a zero from the scan is not a blind scan.

const PAUSE_COLUMN := ["resume", "restart", "notes", "radio", "settings", "quit"]
const FEEL_ROWS := ["music", "effects", "shake", "hitstop", "ceremony"]
const HEADINGS := ["SETTINGS", "Choose your pilot", "HOW TO PLAY", "ACHIEVEMENTS", "CAMP"]

var _t := T.new("menu_structure_test")
var _game
var _quits := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


# Every visible label and button text under a node, as the player would read it.
func _texts(node: Node, found: Array = []) -> Array:
	if node is CanvasItem and not node.visible:
		return found
	if node is Label:
		found.append(node.text)
	elif node is BaseButton and "text" in node:
		found.append(node.text)
	for child in node.get_children():
		_texts(child, found)
	return found


# True when a visible label or button reads exactly `heading`.
func _holds(node: Node, heading: String) -> bool:
	return _texts(node).has(heading)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _run() -> void:
	root.size = Vector2i(1600, 900)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	await _frames(3)
	var screens = _game.screens
	screens.prologue_enabled = false
	_game.ctx.calm = true

	# The planted case: a screen that does carry a restating heading fails the scan.
	screens._on_flow_changed("title")
	screens._show("SETTINGS", Color.WHITE, "")
	_t.check("planted: a restating heading is found by the scan", _holds(screens, "SETTINGS"))
	screens._on_flow_changed("title")
	_t.check("planted: the plain title does not read SETTINGS", not _holds(screens, "SETTINGS"))

	# The five headings, on the screens that carried them.
	screens.toggle_settings()
	await _frames(2)
	_t.check("the title's Settings holds no SETTINGS heading", screens._settings.visible and not _holds(screens, "SETTINGS"), str(_texts(screens)))
	screens.toggle_settings()
	screens.toggle_help()
	await _frames(2)
	_t.check("Help holds no HOW TO PLAY heading", screens.help_open() and not _holds(screens, "HOW TO PLAY"), str(_texts(screens)))
	screens.toggle_help()
	screens.toggle_achievements()
	await _frames(2)
	_t.check("Achievements holds no ACHIEVEMENTS heading", not _holds(screens, "ACHIEVEMENTS"), str(_texts(screens)))
	_t.eq("Achievements' Back wears Esc from the title", screens._achievements.back.key, "key_esc")
	screens.toggle_achievements()
	screens._walking = true
	screens.toggle_achievements()
	await _frames(2)
	_t.eq("Achievements' Back wears Esc from the camp walk", screens._achievements.back.key, "key_esc")
	screens.toggle_achievements()
	var page := PanelContainer.new()
	var own := Label.new()
	own.text = "Dispatch box"
	page.add_child(own)
	screens.open_walk_page(page)
	await _frames(2)
	_t.check("a station page stands alone, with no CAMP heading over it", _holds(screens, "Dispatch box") and not _holds(screens, "CAMP"), str(_texts(screens)))
	screens.close_walk_page()
	screens._walking = false
	_game.flow.open_class_select()
	await _frames(3)
	_t.check("pilot select holds no Choose your pilot heading but keeps the voice line",
		not _holds(screens, "Choose your pilot") and _holds(screens, Screens.PILOT_LINE), str(_texts(screens)))
	_t.eq("its footer is the Enter cap and start", screens._footer.text(), "Enter start")
	for heading in HEADINGS:
		_t.check("%s is on no built screen now" % heading, not _holds(screens, heading) or heading == "CAMP", heading)

	# One name for starting over, on the death screen and the summary.
	_game.flow.show_title()
	_game.flow.press_start()
	await _frames(2)
	_game.pick_pilot(0)
	await _frames(3)
	screens._on_flow_changed("dead")
	await _frames(2)
	_t.check("the death screen says New run and Choose pilot", _holds(screens, "New run") and _holds(screens, "Choose pilot")
		and not _holds(screens, "Restart run") and not _holds(screens, "Run again"), str(_texts(screens)))
	_t.eq("Choose pilot wears C on the death screen", screens.button_for("class").key, "key_c")
	screens._on_flow_changed("summary")
	await _frames(2)
	_t.check("the summary says New run, never Run again", _holds(screens, "New run") and not _holds(screens, "Run again")
		and not _holds(screens, "Restart run"), str(_texts(screens)))
	_t.eq("Choose pilot wears C on the summary too", screens.button_for("class").key, "key_c")
	_t.check("the summary never offers Space (the jump) for it", screens.button_for("class").key != "key_space")

	# The pause column and the Feel tab, in both hosts.
	var menu = _game.get_node("PauseMenu")
	var visible_ids := []
	for id in menu._order:
		if menu.row(id).visible:
			visible_ids.append(id)
	_t.eq("the pause column is exactly six entries, in order", visible_ids, PAUSE_COLUMN)
	_t.eq("the pause column's start-over row reads New run", menu.row("restart").text, "New run")
	_t.check("no volume row stays in the pause column", not menu._order.has("music") and not menu._order.has("effects"))
	_t.check("the Feel tab is the fourth settings page", SettingsPages.PAGES.size() == 4 and SettingsPages.PAGES.back() == "feel"
		and SettingsPages.PAGE_WORDS.get("feel") == "Feel")
	var hosts := {"pause": menu.settings_page(), "title": screens._settings}
	for host in hosts:
		var pages = hosts[host]
		for id in FEEL_ROWS:
			_t.check("%s's settings hold the %s row" % [host, id], pages.row(id) != null)
		pages.show_page(3)
		_t.eq("%s's Feel tab walks the five rows then Back" % host, pages.page_ids(), FEEL_ROWS + ["back"])
		_t.eq("%s's ceremonies row is worded Find cards" % host, pages.row("ceremony").text.begins_with("Find cards"), true)
	# Music from the title's Settings changes the stored value the pause menu used to change.
	var title_pages = screens._settings
	screens._on_flow_changed("title")
	screens.toggle_settings()
	await _frames(2)
	title_pages.row("music").set_level(0.3)
	_t.near("the title's Music row stores the level", float(_game.settings_store().volumes.get("Music", -1.0)), 0.3)
	menu.settings_page().refresh()
	_t.near("the pause menu's Feel tab reads the same level", menu.settings_page().row("music").level, 0.3)
	menu.settings_page().row("shake").set_level(0.5)
	_t.near("the Screen shake row stores its comfort level", float(_game.settings_store().comfort.get("shake", -1.0)), 0.5)

	# Controls: a verb's name once, then its key cap and its pad cap.
	title_pages.show_page(1)
	var jump_name := 0
	for text in _texts(title_pages):
		if text == "Jump":
			jump_name += 1
	_t.eq("the Controls tab names Jump once", jump_name, 1)
	_t.check("the pick rows read Pick 1, not Slot 1", _holds(title_pages, "Pick 1") and not _holds(title_pages, "Slot 1"))
	title_pages.show_page(0)
	_t.check("Display wording: Less motion, Fewer flashes, lower-case quality",
		_holds(title_pages, "Less motion: off") and _holds(title_pages, "Fewer flashes: off") and _holds(title_pages, "Quality: high"), str(_texts(title_pages)))

	# A helper under Frame smoothing and Wide picture, only while the row is focused.
	title_pages.show_page(0)
	title_pages.row("fullscreen").grab_focus()
	await _frames(1)
	_t.eq("no helper while another row has focus", title_pages.helper_text(), "")
	title_pages.row("frame_smoothing").grab_focus()
	await _frames(1)
	var smoothing: String = title_pages.helper_text()
	_t.check("Frame smoothing shows a helper of at most eight words", smoothing != "" and smoothing.split(" ").size() <= 8, smoothing)
	title_pages.row("wide_picture").grab_focus()
	await _frames(1)
	var wide: String = title_pages.helper_text()
	_t.check("Wide picture shows its own helper of at most eight words", wide != "" and wide != smoothing and wide.split(" ").size() <= 8, wide)
	title_pages.row("fullscreen").grab_focus()
	await _frames(1)
	_t.eq("the helper leaves with the focus", title_pages.helper_text(), "")

	# Title wording and Esc.
	_game.flow.show_title()
	await _frames(3)
	_t.eq("the title reads SCRAPKEEP", screens._title.text, Screens.TITLE)
	_t.check("the sitting tag is off the title", not "SITTING" in screens._title.text)
	var quit: Button = screens.button_for("quit")
	quit.pressed.connect(func(): _quits += 1)
	_t.check("nothing is focused on a fresh title", not quit.has_focus())
	screens._input(_key(KEY_ESCAPE))
	await _frames(1)
	_t.check("Esc on the title focuses Quit and does not quit", quit.has_focus() and _quits == 0, "quits %d" % _quits)
	screens._input(_key(KEY_ESCAPE))
	await _frames(1)
	_t.check("a second Esc does not quit either", quit.has_focus() and _quits == 0 and _game.flow.state_name() == "title", "quits %d" % _quits)
	screens._input(_key(KEY_ENTER))
	_t.check("Enter on the focused Quit takes the quit path", _quits == 1, "quits %d" % _quits)

	quit_and_report()


func quit_and_report() -> void:
	quit(_t.verdict())
