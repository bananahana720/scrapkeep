extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SettingsStore := preload("res://src/ui/settings_store.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")
const Push := preload("res://tests/support/push.gd")
const T := preload("res://tests/support/t.gd")

# The settings page from the title and from the pause menu (alpha R12, S3), on the real
# game with real key and click events:
#   - the title's Settings button and S open the page without pausing or capturing the
#     mouse, and Esc goes back to the title and does not quit;
#   - the pause menu's settings row opens the same page, Back returns to the first page
#     with Settings focused, and the first page keeps its words;
#   - a rebind applies to the InputMap at once, is saved, and boots again; a key another
#     verb holds is refused as Taken; Esc cancels; Reset keys restores the defaults;
#   - Low applies at once, is saved and boots again; a --preset= flag beats it; fullscreen
#     is on for a fresh install, off is saved, the window mode is not touched headless, and
#     launch follows the setting only for a player's game, and --fullscreen=0|1 beats both.
# Storage is the game's test folder; the settings file is removed at the start and the end.

const PAGE_BUDGET := 70
const PAUSE_BUDGET := 40

var _t := T.new("ui_settings_pages_test")
var _game


func _initialize() -> void:
	_wipe()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _wipe() -> void:
	var dir := "user://test-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join(SettingsStore.FILE)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _settle(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await process_frame
		left -= _game.get_process_delta_time()


func _has_key(action: String, code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == code:
			return true
	return false


func _saved() -> SettingsStore:
	return SettingsStore.new(_game.storage_dir)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	await _settle(0.6)
	var screens = _game.screens

	# S3-1: the title.
	_t.eq("S3-1 the game starts on the title", _game.flow.state_name(), "title")
	var button: Button = screens.button_for("settings")
	_t.check("S3-1 the title has a Settings button on S", button != null and button.key == "key_s", "button %s" % [button])
	_game._screen_key(KEY_S)
	_t.check("S3-1 S opens the page", screens.settings_open() and not screens.help_open(), "open %s" % screens.settings_open())
	_t.check("S3-1 opening it neither pauses nor captures the mouse", not paused and not _game.pause_toggled() and not _game.mouse_captured(), "paused %s" % paused)
	await _settle(0.5)
	var title_words: int = WordBudget.count(screens)["hud"]
	_t.check("S3-1 the page reads within %d words" % PAGE_BUDGET, title_words > 0 and title_words <= PAGE_BUDGET, "%d words" % title_words)
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("S3-1 Esc returns to the title and does not quit", not screens.settings_open() and _game.flow.state_name() == "title" and screens.button_for("start") != null, "open %s" % screens.settings_open())
	Push.click(root, screens.button_for("settings"))
	await _frames(2)
	_t.check("S3-1 the button opens it", screens.settings_open() and _game.flow.state_name() == "title", "open %s" % screens.settings_open())
	Push.key(root, KEY_N)
	_t.check("S3-1 a key on the page does not start the run", _game.flow.state_name() == "title" and screens.settings_open(), "state %s" % _game.flow.state_name())
	Push.click(root, screens.button_for("back"))
	await _frames(2)
	_t.check("S3-1 Back closes it", not screens.settings_open(), "open %s" % screens.settings_open())

	# Into play, with the pick closed, and the pause menu open.
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
	_t.check("S3-2 play is running", _game.flow.in_play() and not paused, "in play %s" % _game.flow.in_play())
	Push.key(root, KEY_P)
	await _settle(0.5)
	var before: int = WordBudget.count(menu)["hud"]
	var order: Array = menu._order.duplicate()
	_t.check("S3-2 the first page has a settings row above quit", order.find("settings") == order.size() - 2 and order[-1] == "quit", "order %s" % [order])
	_t.check("S3-2 the first page keeps %d words" % PAUSE_BUDGET, menu.is_open() and before <= PAUSE_BUDGET, "%d words" % before)
	print("  first page words with settings: %d" % before)

	# S3-2: the page from pause.
	Push.click(root, menu.row("settings"))
	await _settle(0.5)
	var page = menu.settings_page()
	var page_words: int = WordBudget.count(menu)["hud"]
	_t.check("S3-2 the settings row opens the page", menu.settings_open() and page.visible and not menu.row("resume").visible, "open %s" % menu.settings_open())
	_t.check("S3-2 the page reads within %d words" % PAGE_BUDGET, page_words <= PAGE_BUDGET, "%d words" % page_words)
	print("  settings page words: %d" % page_words)
	# Re-pinned 2026-10-10 (wave 13 unit B2, design-v3/SKILL-BAR.md section 6): the special's row
	# retired; the pick's three keys and the ultimate each have a row.
	_t.eq("S3-2 the page rows", page.rows.keys().filter(func(id): return not id.begins_with("pad_") and not id in ["stick_sensitivity", "invert_y", "stick_deadzone", "mouse_sensitivity", "aim_assist"]),
		["fullscreen", "quality", "reduced_motion", "reduce_flashes", "frame_smoothing", "wide_picture", "jump", "fire", "harpoon", "haul", "boost", "select_1", "select_2", "select_3", "ultimate", "active", "interact", "reset", "roll", "look", "music", "effects", "shake", "hitstop", "ceremony", "back"])
	_t.check("S3-2 roll and look are fixed", page.row("roll").disabled and page.row("look").disabled, "fixed")
	_t.check("S3-2 the page holds the pause", paused and _game.pause_toggled(), "paused %s" % paused)
	Push.key(root, KEY_S)
	_t.eq("S3-6 W and S move the page's focus", page.focused_id(), "quality")
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	root.push_input(down)
	_t.eq("S3-6 a pad's down moves it too (Display holds fullscreen, quality, reduced motion, reduce flashes and Back)", page.focused_id(), "reduced_motion")
	Push.key(root, KEY_ESCAPE)
	await _settle(0.5)
	_t.check("S3-2 Esc goes back to the first page with Settings focused", not menu.settings_open() and menu.is_open() and menu.focused_id() == "settings" and menu.row("resume").visible, "focus %s" % menu.focused_id())
	_t.eq("S3-2 the first page's words are as before", WordBudget.count(menu)["hud"], before)
	Push.click(root, menu.row("settings"))
	await _settle(0.5)
	Push.click(root, page.back)
	await _settle(0.5)
	_t.check("S3-2 the Back row returns the same way", not menu.settings_open() and menu.focused_id() == "settings", "focus %s" % menu.focused_id())
	menu.press("settings")
	await _settle(0.3)

	# S3-3: rebind jump to G.
	_t.check("S3-3 jump holds Space to start", _has_key("cl_jump", KEY_SPACE) and not _has_key("cl_jump", KEY_G), "events")
	page.press("jump")
	_t.check("S3-3 the row waits for a key", page.capturing(), "capturing")
	Push.key(root, KEY_G)
	_t.check("S3-3 G is on cl_jump at once, Space is not", _has_key("cl_jump", KEY_G) and not _has_key("cl_jump", KEY_SPACE), "events %s" % [InputMap.action_get_events("cl_jump")])
	var pad_kept := false
	for event in InputMap.action_get_events("cl_jump"):
		pad_kept = pad_kept or event is InputEventJoypadButton
	_t.check("S3-3 the pad button stays", pad_kept, "pad %s" % pad_kept)
	_t.check("S3-3 the row's cap shows G", page.glyph_of("jump") == "key_g" and not page.capturing(), page.glyph_of("jump"))
	_t.eq("S3-3 the file holds key:G for cl_jump", _saved().binding("cl_jump"), "key:G")

	# S3-4: Taken and cancel.
	page.press("boost")
	Push.key(root, KEY_CTRL)
	_t.check("S3-4 a key another verb holds is Taken and changes nothing", page.row("boost").text.contains("Taken") and _has_key("cl_boost", KEY_SHIFT) and not _has_key("cl_boost", KEY_CTRL) and _saved().binding("cl_boost") == "", "text %s" % page.row("boost").text)
	_t.eq("S3-4 the line under it names the holder and what to do", page.notice_text(), "Haul uses that key. Press the cap again for another, or move Haul first.")
	Push.key(root, KEY_DOWN)
	Push.key(root, KEY_UP)
	_t.check("S3-4 moving the focus keeps the refusal and its line", page.row("boost").alert and page.notice_text().begins_with("Haul uses"), "alert %s line %s" % [page.row("boost").alert, page.notice_text()])
	for taken in [["P", KEY_P], ["R", KEY_R]]:
		page.press("jump")
		Push.key(root, taken[1])
		_t.check("S3-4 %s is held by pause or retry, so jump reads Taken and keeps G" % taken[0], page.row("jump").text.contains("Taken") and _has_key("cl_jump", KEY_G) and not _has_key("cl_jump", taken[1]), "text %s" % page.row("jump").text)
		_t.check("S3-4 the line names %s by the word the player knows" % taken[0], page.notice_text().begins_with("Pause uses" if taken[0] == "P" else "New run uses"), page.notice_text())
		page.press("jump")
		Push.key(root, KEY_ESCAPE)
	page.press("harpoon")
	var harpoon_before := InputMap.action_get_events("cl_harpoon").size()
	Push.key(root, KEY_ESCAPE)
	_t.check("S3-4 Esc cancels and keeps the page open", not page.capturing() and menu.settings_open() and menu.is_open() and InputMap.action_get_events("cl_harpoon").size() == harpoon_before and _saved().binding("cl_harpoon") == "", "capturing %s" % page.capturing())
	page.press("harpoon")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	root.push_input(click)
	var middle := false
	for event in InputMap.action_get_events("cl_harpoon"):
		middle = middle or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE)
	_t.check("S3-4 a mouse button binds too", middle and _saved().binding("cl_harpoon") == "mouse:3", "saved %s" % _saved().binding("cl_harpoon"))

	# S3-6: quality and fullscreen.
	var mode_before := DisplayServer.window_get_mode()
	Push.click(root, page.row("quality"))
	_t.check("S3-6 Low applies at once and is saved", GraphicsPreset.current == "low" and _saved().quality() == 1 and page.read("quality")["value"] == "low", "preset %s" % GraphicsPreset.current)
	_t.check("S3-6 a fresh install wants fullscreen and stores nothing for it", _saved().fullscreen() and not _saved().comfort.has("fullscreen") and page.read("fullscreen")["pip"] == 1, "%s" % [_saved().comfort])
	Push.click(root, page.row("fullscreen"))
	_t.check("S3-6 fullscreen off is saved and headless never changes the window mode", not _saved().fullscreen() and page.read("fullscreen")["pip"] == 0 and DisplayServer.window_get_mode() == mode_before, "saved %s" % _saved().fullscreen())
	_t.check("S3-6 the old settings keep their keys", _saved().comfort.has("fullscreen") and _saved().comfort.has("quality"), "%s" % [_saved().comfort])
	# The launch rule (DECISIONS cb): a player's game follows the setting, a test or a bot's run
	# keeps the window it was launched with, and --fullscreen=0 or =1 beats both for one launch.
	_t.check("S3-6 a test's game keeps its window whatever the setting says", not _game.launches_fullscreen(true, []), "test")
	_game.test_mode = false
	_t.check("S3-6 a player's game launches fullscreen only while the setting is on", _game.launches_fullscreen(true, []) and not _game.launches_fullscreen(false, []), "player")
	_t.check("S3-6 --fullscreen=0 asks for a window this once", not _game.launches_fullscreen(true, ["--fullscreen=0"]) and _game.launches_fullscreen(false, ["--dev", "--fullscreen=1"]), "flags")
	_game.test_mode = true
	_t.check("S3-6 --fullscreen=1 puts a capture fullscreen too, and the last one given wins", _game.launches_fullscreen(false, ["--fullscreen=1"]) and not _game.launches_fullscreen(true, ["--fullscreen=1", "--fullscreen=0"]), "capture")

	# A new game in the same folder boots with G, Low and the flag's rule. Free this one first.
	# A test game removes its storage folder when it leaves, so the file is carried over.
	var carried := FileAccess.get_file_as_string(_game.storage_dir.path_join(SettingsStore.FILE))
	_game.queue_free()
	await _frames(3)
	DirAccess.make_dir_recursive_absolute("user://test-%d" % OS.get_process_id())
	var carry := FileAccess.open("user://test-%d/%s" % [OS.get_process_id(), SettingsStore.FILE], FileAccess.WRITE)
	carry.store_string(carried)
	carry.close()
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_t.check("S3-3 a new game boots with G", _has_key("cl_jump", KEY_G) and not _has_key("cl_jump", KEY_SPACE), "events %s" % [InputMap.action_get_events("cl_jump")])
	_t.check("S3-6 a new game boots with Low", GraphicsPreset.current == "low", "preset %s" % GraphicsPreset.current)
	GraphicsPreset.apply("high")
	_game.apply_saved_display(["--preset=bogus"])
	_t.check("S3-6 an invalid --preset= flag leaves the saved Low", GraphicsPreset.current == "low", "preset %s" % GraphicsPreset.current)
	GraphicsPreset.apply("high")
	_game.apply_saved_display(["--preset=high"])
	_t.check("S3-6 a --preset= flag beats the saved Low", GraphicsPreset.current == "high", "preset %s" % GraphicsPreset.current)
	_game.apply_saved_display()
	_t.check("S3-6 without the flag the saved Low applies", GraphicsPreset.current == "low", "preset %s" % GraphicsPreset.current)

	# S3-5: Reset keys.
	_game._register_actions()
	_game.apply_saved_bindings()
	_t.check("S3-5 the saved G holds before the reset", _has_key("cl_jump", KEY_G), "events")
	_game.reset_bindings()
	_t.check("S3-5 Space is back at once", _has_key("cl_jump", KEY_SPACE) and not _has_key("cl_jump", KEY_G), "events %s" % [InputMap.action_get_events("cl_jump")])
	_t.check("S3-5 the saved override is gone", _saved().binding("cl_jump") == "" and _saved().bindings.is_empty(), "bindings %s" % [_saved().bindings])
	_t.check("S3-5 quality and fullscreen survive it", _saved().quality() == 1 and not _saved().fullscreen(), "kept")

	# The page's own Reset row does the same through the click.
	var game_menu = _game.get_node("PauseMenu")
	game_menu.settings_page().press("jump")
	var h := InputEventKey.new()
	h.pressed = true
	h.physical_keycode = KEY_H
	game_menu.settings_page().handle(h)
	_t.check("S3-5 a rebind after the reset takes", _has_key("cl_jump", KEY_H), "events")
	game_menu.settings_page().press("reset")
	_t.check("S3-5 the Reset keys row restores Space", _has_key("cl_jump", KEY_SPACE) and not _has_key("cl_jump", KEY_H) and _saved().binding("cl_jump") == "", "events")

	_wipe()
	GraphicsPreset.apply("high")
	quit(_t.verdict())
