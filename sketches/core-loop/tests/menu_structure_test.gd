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
# The camp-walk path sets screens._walking directly (the 3D camp is not built here), as camp_hub_test's
# feature page does, then opens a page through the real open_walk_page and toggle_achievements.
# A heading that is allowed on a page, by page, with the reason: Moss's jukebox heading says whose jukebox it is.
const ALLOWED := {}

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


# The restating headings a built screen still holds (an allowed one for that page excepted).
func _restating(node: Node, page := "") -> Array:
	return HEADINGS.filter(func(h): return _holds(node, h) and not ALLOWED.get(page, []).has(h))


func _wears_esc(button: Button) -> bool:
	return button != null and button.key == "key_esc"


# One real Esc through the engine's input path, with game._input live (it returns early in test_mode).
func _real_esc() -> void:
	_game.test_mode = false
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.physical_keycode = KEY_ESCAPE
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await _frames(3)
	_game.test_mode = true


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

	var plant := preload("res://src/ui/choice_button.gd").new("back", "key_a", "Back")
	_t.check("planted: a Back wearing A is not read as Esc", not _wears_esc(plant))
	plant.free()
	screens._show("CAMP", Color.WHITE, "")
	_t.check("planted: a CAMP heading is found by the restating scan", _restating(screens) == ["CAMP"], str(_restating(screens)))
	screens._on_flow_changed("title")

	# The five headings, on the screens that carried them.
	screens.toggle_settings()
	await _frames(2)
	_t.check("the title's Settings holds no restating heading", screens._settings.visible and _restating(screens, "settings") == [], str(_texts(screens)))
	screens.toggle_settings()
	screens.toggle_help()
	await _frames(2)
	_t.check("Help holds no HOW TO PLAY heading", screens.help_open() and _restating(screens, "help") == [], str(_texts(screens)))
	screens.toggle_help()
	screens.toggle_achievements()
	await _frames(2)
	_t.check("Achievements holds no ACHIEVEMENTS heading", not _holds(screens, "ACHIEVEMENTS"), str(_texts(screens)))
	_t.check("Achievements' Back wears Esc from the title", _wears_esc(screens._achievements.back), screens._achievements.back.key)
	_t.eq("Achievements holds no restating heading", _restating(screens, "achievements"), [])
	screens.toggle_achievements()
	screens._walking = true
	screens.toggle_achievements()
	await _frames(2)
	_t.check("Achievements' Back wears Esc from the camp walk", _wears_esc(screens._achievements.back), screens._achievements.back.key)
	screens.toggle_achievements()
	var page := PanelContainer.new()
	var own := Label.new()
	own.text = "Dispatch box"
	page.add_child(own)
	screens.open_walk_page(page)
	await _frames(2)
	_t.check("a station page stands alone, with no CAMP heading over it", _holds(screens, "Dispatch box") and _restating(screens, "walk_page") == [], str(_texts(screens)))
	screens.close_walk_page()
	screens._walking = false
	_game.flow.open_class_select()
	await _frames(3)
	_t.check("pilot select holds no Choose your pilot heading but keeps the voice line",
		not _holds(screens, "Choose your pilot") and _holds(screens, Screens.PILOT_LINE), str(_texts(screens)))
	_t.eq("its footer is the Enter cap and start", screens._footer.text(), "Enter start")
	_t.eq("pilot select holds none of the five restating headings", _restating(screens, "class_select"), [])

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
		_holds(title_pages, "Less motion") and _holds(title_pages, "Fewer flashes") and title_pages.read("quality")["value"] == "high"
		and title_pages.read("reduced_motion")["pip"] == 0 and title_pages.read("reduce_flashes")["pip"] == 0, str(_texts(title_pages)))

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

	# The stick steps a Feel row, as it did in the pause column (ui_right is the default map's stick and d-pad).
	title_pages.show_page(3)
	title_pages.row("effects").grab_focus()
	var before_level: float = title_pages.row("effects").level
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -1.0
	var used: bool = title_pages.handle(stick)
	_t.check("a stick push left steps Effects down", used and is_equal_approx(title_pages.row("effects").level, maxf(before_level - 0.1, 0.0)), "%s -> %s" % [before_level, title_pages.row("effects").level])
	stick.axis_value = 1.0
	title_pages.handle(stick)
	_t.near("a stick push right steps it back", title_pages.row("effects").level, before_level)
	var idle := InputEventJoypadMotion.new()
	idle.axis = JOY_AXIS_LEFT_X
	idle.axis_value = 0.0
	_t.check("a centred stick is not used", not title_pages.handle(idle))

	# Esc on every screen outside the title goes back or stays; it never quits (real routing, game._input live).
	screens.toggle_settings()
	_game.flow.show_title()
	_game.flow.open_class_select()
	await _frames(2)
	await _real_esc()
	_t.check("Esc on pilot select goes back to the title and the game runs on", _game.flow.state_name() == "title", _game.flow.state_name())
	_game.flow._set_state(_game.flow.DEAD)
	await _frames(2)
	_t.eq("the death screen is up", screens._state, "dead")
	await _real_esc()
	_t.check("Esc on the death screen opens the camp, as the summary's Esc does", screens.camp_open() and _game.flow.state_name() == "title", _game.flow.state_name())
	await _real_esc()
	_t.check("a second Esc leaves the camp and the game runs on", _game.flow.state_name() == "title" and not screens.camp_open(), "camp %s" % screens.camp_open())

	# C on the summary: one press, one action, and none while the companion panel is open.
	_game.flow.show_title()
	_game.flow.press_start()
	_game.pick_pilot(0)
	await _frames(3)
	_game.flow._set_state(_game.flow.SUMMARY)
	await _frames(2)
	_game.summary_latched = false
	var panel = _game.workshop().companion_panel
	panel._open = true
	screens._input(_key(KEY_C))
	_t.eq("C does nothing on the summary while the companion panel is open", screens._state, "summary")
	panel._open = false
	screens._input(_key(KEY_C))
	await _frames(2)
	_t.check("C chooses a pilot on the summary once the panel is shut", _game.flow.state_name() == "class_select", _game.flow.state_name())

	# Title wording and Esc.
	_game.flow.show_title()
	await _frames(3)
	_t.eq("the title reads SCRAPKEEP", screens._title.text, Screens.TITLE)
	_t.check("the sitting tag is off the title", not "SITTING" in screens._title.text)
	var menu_dev = _game.get_node("PauseMenu")
	_t.check("Breath is hidden in the pause column without --dev", not _game.dev and not menu_dev.row("breath").visible)
	var stamp: String = title_pages.stamp.text
	_t.check("a default profile's build stamp has no sitting word", not stamp.contains("sitting") and stamp != "", stamp)
	var sitting_seen := false
	if _game.tuning != null:
		_game.tuning.apply_args(PackedStringArray(["--profile=sitting"]), "launch")
		title_pages.refresh()
		sitting_seen = title_pages.stamp.text.ends_with("sitting") and not title_pages.stamp.text.contains(":")
	_t.check("a sitting profile shows one word, sitting, after the build id", sitting_seen, title_pages.stamp.text)
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
	_game.free()
	await _frames(1)
	quit(_t.verdict())
