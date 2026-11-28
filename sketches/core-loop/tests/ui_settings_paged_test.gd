extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const SettingsPages := preload("res://src/ui/settings_pages.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")

# IN4: the settings page in four pages (Feel since wave 36). Display (fullscreen, quality), Controls (a key row
# and a pad row per verb, Reset keys, the fixed verbs) and Look (stick speed, invert Y, dead
# zone, mouse speed, aim assist). LB and RB, Q and E or a click on a tab switch pages; the
# d-pad reaches every row; Look rows step by Enter, A, a click and left and right; the page
# last shown is kept for the session and the pause menu's Settings entry opens on it.

var _t := T.new("ui_settings_paged_test")
var _game
var _page


func _initialize() -> void:
	var dir := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _saved() -> SettingsStore:
	return SettingsStore.new(_game.storage_dir)


func _walk(page) -> Array:
	var seen := []
	page.focus_first()
	seen.append(page.focused_id())
	for i in page.page_ids().size() - 1:
		Push.pad(root, JOY_BUTTON_DPAD_DOWN)
		seen.append(page.focused_id())
	return seen


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _settle(0.6)
	var screens = _game.screens
	_game._screen_key(KEY_S)
	await _settle(0.4)
	_page = screens.settings_page()

	_t.eq("four pages", SettingsPages.PAGES, ["display", "controls", "look", "feel"])
	_t.eq("the session starts on Display", _page.current_page(), "display")
	_t.eq("Display holds fullscreen, quality, reduced motion, reduce flashes, frame smoothing, wide picture and Back", _page.page_ids(), ["fullscreen", "quality", "reduced_motion", "reduce_flashes", "frame_smoothing", "wide_picture", "back"])
	_t.check("the title's page is shown with its first row focused", screens.settings_open() and _page.focused_id() == "fullscreen", "focus %s" % _page.focused_id())
	_t.check("only the shown page's rows are visible", _page.row("fullscreen").is_visible_in_tree() and not _page.row("jump").is_visible_in_tree() and not _page.row("aim_assist").is_visible_in_tree(), "visibility")

	# E, Q, RB and LB switch pages, wrapping.
	Push.key(root, KEY_E)
	_t.eq("E goes to Controls", _page.current_page(), "controls")
	Push.key(root, KEY_E)
	_t.eq("E goes to Look", _page.current_page(), "look")
	Push.key(root, KEY_E)
	_t.eq("E goes to Feel", _page.current_page(), "feel")
	Push.key(root, KEY_E)
	_t.eq("E wraps to Display", _page.current_page(), "display")
	Push.key(root, KEY_Q)
	_t.eq("Q wraps back to Feel", _page.current_page(), "feel")
	Push.key(root, KEY_Q)
	_t.eq("Q goes to Look", _page.current_page(), "look")
	Push.key(root, KEY_Q)
	_t.eq("Q goes to Controls", _page.current_page(), "controls")
	Push.pad(root, JOY_BUTTON_RIGHT_SHOULDER)
	_t.eq("RB goes to Look", _page.current_page(), "look")
	Push.pad(root, JOY_BUTTON_RIGHT_SHOULDER)
	_t.eq("RB goes to Feel", _page.current_page(), "feel")
	Push.pad(root, JOY_BUTTON_RIGHT_SHOULDER)
	_t.eq("RB wraps to Display", _page.current_page(), "display")
	Push.pad(root, JOY_BUTTON_LEFT_SHOULDER)
	_t.eq("LB wraps back to Feel", _page.current_page(), "feel")
	Push.pad(root, JOY_BUTTON_LEFT_SHOULDER)
	_t.eq("LB goes to Look", _page.current_page(), "look")
	Push.pad(root, JOY_BUTTON_LEFT_SHOULDER)
	_t.eq("LB goes to Controls", _page.current_page(), "controls")
	_t.eq("a switch focuses the new page's first row", _page.focused_id(), "jump")
	_t.eq("the run did not start under the page", _game.flow.state_name(), "title")

	# A click on a tab switches too.
	await _frames(2)
	Push.click(root, _page._tabs["look"])
	_t.eq("a click on the Look tab opens Look", _page.current_page(), "look")
	Push.click(root, _page._tabs["display"])
	_t.eq("a click on the Display tab opens Display", _page.current_page(), "display")

	# The d-pad reaches every row of every page, Back included. Re-pinned 2026-10-10 (wave 13 unit
	# B2, design-v3/SKILL-BAR.md section 6): the special's rows retired; the pick's three keys
	# (select_1 to select_3) and the ultimate each have a key row and a pad row.
	var want := {
		"display": ["fullscreen", "quality", "reduced_motion", "reduce_flashes", "frame_smoothing", "wide_picture", "back"],
		"controls": ["jump", "pad_jump", "fire", "pad_fire", "harpoon", "pad_harpoon", "haul", "pad_haul", "boost", "pad_boost",
			"select_1", "pad_select_1", "select_2", "pad_select_2", "select_3", "pad_select_3", "ultimate", "pad_ultimate",
			"active", "pad_active", "interact", "pad_interact", "reset", "back"],
		"look": ["stick_sensitivity", "invert_y", "stick_deadzone", "mouse_sensitivity", "aim_assist", "back"],
		"feel": ["music", "effects", "shake", "hitstop", "ceremony", "back"],
	}
	for index in SettingsPages.PAGES.size():
		var name: String = SettingsPages.PAGES[index]
		_page.show_page(index)
		await _frames(2)
		_t.eq("%s page rows" % name, _page.page_ids(), want[name])
		_t.eq("the d-pad walks every %s row" % name, _walk(_page), want[name])
		Push.pad(root, JOY_BUTTON_DPAD_DOWN)
		_t.eq("down from Back wraps on %s" % name, _page.focused_id(), want[name][0])

	# Look rows step by Enter, the d-pad, a click.
	_page.show_page(2)
	await _frames(2)
	_page.focus_first()
	var camera = _game.camera
	Push.key(root, KEY_ENTER)
	_t.near("Enter steps stick speed from 2.6 to 3.25", _saved().stick_sensitivity(), 3.25)
	_t.near("the camera takes it at once", camera.stick_sensitivity, 3.25)
	_t.eq("the row reads 125 percent", _page.read("stick_sensitivity"), {"label": "Stick speed", "value": "125%", "pip": -1})
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	_t.near("d-pad right steps it up to 3.9", _saved().stick_sensitivity(), 3.9)
	Push.pad(root, JOY_BUTTON_DPAD_RIGHT)
	_t.near("right stops at the top", _saved().stick_sensitivity(), 3.9)
	Push.key(root, KEY_A)
	_t.near("A steps it down", _saved().stick_sensitivity(), 3.25)
	Push.key(root, KEY_ENTER)
	Push.key(root, KEY_ENTER)
	_t.near("Enter wraps from the top to the bottom", _saved().stick_sensitivity(), 1.3)
	Push.pad(root, JOY_BUTTON_DPAD_DOWN)
	_t.eq("down moves to invert", _page.focused_id(), "invert_y")
	Push.pad(root, JOY_BUTTON_A)
	_t.check("A toggles invert Y", _saved().invert_y() and camera.invert_y and _page.read("invert_y") == {"label": "Invert Y", "value": "", "pip": 1}, "read %s" % _page.read("invert_y"))
	Push.click(root, _page.row("mouse_sensitivity"))
	_t.near("a click steps mouse speed", _saved().mouse_sensitivity(), 0.00275)
	_t.near("the camera takes the mouse speed", camera.mouse_sensitivity, 0.00275)
	Push.click(root, _page.row("stick_deadzone"))
	_t.near("a click steps the dead zone to 0.25", _saved().stick_deadzone(), 0.25)
	_t.near("the deadzone reaches the look actions", InputMap.action_get_deadzone("cl_look_left"), 0.25)
	Push.click(root, _page.row("aim_assist"))
	_t.near("a click steps aim assist from 0.5 to 0.75", _saved().aim_assist(), 0.75)
	_t.near("the camera takes aim assist", camera.aim_assist, 0.75)
	_t.eq("the row reads 75 percent", _page.read("aim_assist"), {"label": "Aim assist", "value": "75%", "pip": -1})

	# The page is remembered: close from Look, reopen on Look.
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Esc closes the page", not screens.settings_open(), "open")
	_t.eq("the last page is kept", SettingsPages.last_page, 2)
	_game._screen_key(KEY_S)
	await _frames(2)
	_t.check("the title's page reopens on Look with its first row focused", screens.settings_open() and _page.current_page() == "look" and _page.focused_id() == "stick_sensitivity", "page %s focus %s" % [_page.current_page(), _page.focused_id()])
	Push.key(root, KEY_Q)
	_t.eq("Q from Look goes to Controls", _page.current_page(), "controls")
	Push.key(root, KEY_ESCAPE)
	await _frames(2)

	# Into play for the pause menu.
	var workshop = _game.get_node("Workshop")
	var menu = _game.get_node("PauseMenu")
	workshop.armed = true
	Push.click(root, screens.button_for("start"))
	await _settle(0.6)
	Push.click(root, screens.class_cards()[0])
	await _settle(0.6)
	var guard := 0
	while workshop.pick.is_open() and guard < 5:
		Push.key(root, KEY_ESCAPE)
		await _settle(0.5)
		guard += 1
	_t.check("play is running", _game.flow.in_play() and not paused, "in play %s" % _game.flow.in_play())
	Push.key(root, KEY_P)
	await _settle(0.5)
	_t.check("the pause menu is open", menu.is_open(), "open")
	Push.click(root, menu.row("settings"))
	await _settle(0.5)
	var pause_page = menu.settings_page()
	_t.check("the pause menu's Settings opens the last page", menu.settings_open() and pause_page.current_page() == "controls" and pause_page.focused_id() == "jump", "page %s focus %s" % [pause_page.current_page(), pause_page.focused_id()])
	Push.pad(root, JOY_BUTTON_RIGHT_SHOULDER)
	_t.check("RB works in the pause menu", pause_page.current_page() == "look" and menu.settings_open(), "page %s" % pause_page.current_page())
	Push.key(root, KEY_ESCAPE)
	await _settle(0.4)
	_t.check("Esc returns to the first page with Settings focused", not menu.settings_open() and menu.focused_id() == "settings", "focus %s" % menu.focused_id())
	Push.click(root, menu.row("settings"))
	await _settle(0.4)
	_t.check("Settings opens Look this time", pause_page.current_page() == "look" and pause_page.focused_id() == "stick_sensitivity", "page %s" % pause_page.current_page())

	_game.queue_free()
	await process_frame
	quit(_t.verdict())
