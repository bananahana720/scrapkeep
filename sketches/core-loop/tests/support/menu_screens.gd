extends RefCounted

# Shared by menu_reach_test and menu_size_test (rows UA-05 and UA-09 in BACKLOG.md): builds every menu
# screen in turn on a real Game and hands each one to a check while it is on show.
# visit() calls check.call(name, scope_node, showing) once per screen. `showing` is true only when the
# game's own state says that screen is the one up, so a screen that failed to open is never scanned
# under another name. `uncovered` lists the stick menus this helper does not open yet.

const Game := preload("res://src/game.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")

var game
var screens
var tree: SceneTree
var uncovered: Array = [
	"camp menu strip (camp_menu.gd) and customize_page.gd: opened by walking the 3D camp",
	"camp stations: shop_counter.gd, camp_enemy_picker.gd, tree_card.gd, tree_pick.gd, camp_scrapbook.gd, logbook_page.gd (each opens only from its walk zone)",
	"start card (workshop.gd, start_pick_card.gd) and companion_panel.gd: open only inside a run or from a held companion piece",
	"victory (left out on purpose)",
]


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


# Steps frames until the game has been handed this much frame time (the click guard and the card's opening
# both run on frame time).
func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await tree.process_frame
		left -= tree.root.get_process_delta_time()


# Builds the game at the project's base resolution (1600x900, project.godot).
func start(scene_tree: SceneTree) -> void:
	tree = scene_tree
	tree.root.size = Vector2i(1600, 900)
	game = Game.new()
	game.test_mode = true
	tree.root.add_child(game)
	await _frames(3)
	screens = game.screens
	screens.prologue_enabled = false
	game.ctx.calm = true


func finish() -> void:
	game.free()
	await _frames(1)


# The screens' click guard (screens.CLICK_GUARD, 0.5 s) keeps buttons disabled just after a screen opens.
func _settle() -> void:
	await _wait(0.6)
	await _frames(2)


func visit(check: Callable) -> int:
	var count := 0
	var title_pages = screens.settings_page()
	screens._on_flow_changed("title")
	await _settle()
	count += await _emit(check, "title", screens,
		screens._state == "title" and not screens.settings_open() and not screens.help_open() and not screens.achievements_open() and not screens.camp_open())

	for page in 4:
		screens.toggle_settings()
		await _frames(2)
		title_pages.show_page(page)
		title_pages.focus_first()
		await _frames(2)
		count += await _emit(check, "title settings page %d" % page, screens, screens.settings_open() and title_pages.last_page == page)
		screens.toggle_settings()
		await _frames(1)

	screens.toggle_help()
	await _frames(2)
	count += await _emit(check, "help", screens, screens.help_open())
	screens.toggle_help()
	await _frames(1)

	screens.toggle_achievements()
	await _frames(2)
	count += await _emit(check, "achievements", screens, screens.achievements_open())
	screens.toggle_achievements()
	await _frames(1)

	# The paint swatch shows only for a pilot whose paint the profile owns, so own one for pilot 1.
	var profile = game.ctx.profile
	var first_pilot = game.flow.classes[0]
	for id in Cosmetics.for_slot("paint", first_pilot.id):
		if not Cosmetics.row(id)["starter"]:
			profile.unlock_cosmetic(id)
			break
	game.flow.open_class_select()
	await _settle()
	await _wait(1.0)  # the focused pilot card opens, which shows its paint swatch
	count += await _emit(check, "pilot select", screens, game.flow.state_name() == "class_select" and screens._state == "class_select")

	game.flow.show_title()
	game.flow.press_start()
	await _frames(2)
	game.pick_pilot(0)
	await _frames(3)
	for state in ["dead", "summary"]:
		screens._on_flow_changed(state)
		game.summary_latched = false
		await _settle()
		count += await _emit(check, state, screens, screens._state == state)

	# Moss's jukebox and the radio, opened from the camp page as J and the radio button do.
	screens._on_flow_changed("title")
	await _frames(2)
	screens._camp.visible = true
	screens._camp.refresh(game)
	screens.toggle_jukebox()
	await _frames(3)
	count += await _emit(check, "jukebox", screens, screens._jukebox.visible)
	screens.toggle_jukebox()
	if game.get("radio_deck") != null:
		screens.toggle_radio()
		await _frames(3)
		count += await _emit(check, "radio", screens, screens._radio.visible)
		screens.toggle_radio()
	else:
		uncovered.append("radio (no radio deck on this Game)")
	screens._on_flow_changed("title")
	await _frames(2)

	# The pause menu and its settings pages (the same pages as the title's, in the pause host).
	game.flow.show_title()
	game.flow.press_start()
	game.pick_pilot(0)
	await _frames(3)
	var menu = game.get_node("PauseMenu")
	menu.open()
	await _frames(3)
	count += await _emit(check, "pause menu", menu, menu.is_open() and not menu.settings_open())
	menu.press("settings")
	for page in 4:
		menu.settings_page().show_page(page)
		menu.settings_page().focus_first()
		await _frames(2)
		count += await _emit(check, "pause settings page %d" % page, menu, menu.is_open() and menu.settings_open() and menu.settings_page().last_page == page)
	menu.close()
	await _frames(1)
	return count


func _emit(check: Callable, name: String, scope: Node, showing: bool) -> int:
	await check.call(name, scope, showing)
	return 1


# One stick push through the engine's input path (Input.parse_input_event, as menu_structure_test sends Esc), pressed then released, as the pad's left stick sends it (the
# default map gives ui_up, ui_down, ui_left and ui_right to the left stick). The game's own handlers
# (settings pages, pause menu, achievements page) and the engine's focus search both see it.
func push(action: String) -> void:
	var axis := JOY_AXIS_LEFT_Y if action in ["ui_up", "ui_down"] else JOY_AXIS_LEFT_X
	var value := 1.0 if action in ["ui_down", "ui_right"] else -1.0
	for held in [value, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = held
		Input.parse_input_event(event)
		Input.flush_buffered_events()


# Controls in `all` that the stick never takes focus to when `start` has focus and every control
# reached is pushed up, down, left and right in turn. Returns the names.
func unreached(start: Control, all: Array) -> Array:
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var at: Control = queue.pop_front()
		for action in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if not is_instance_valid(at) or not at.is_visible_in_tree():
				break
			at.grab_focus()
			push(action)
			var now = tree.root.gui_get_focus_owner()
			if now != null and all.has(now) and not seen.has(now):
				seen[now] = true
				queue.append(now)
	return all.filter(func(c): return not seen.has(c))


# The control the game focused when the screen opened; with nothing focused, one ui_down as a player
# would send it. Returns {"start": Control or null, "pushed": bool}.
func first_focus() -> Dictionary:
	var owner = tree.root.gui_get_focus_owner()
	if owner != null:
		return {"start": owner, "pushed": false}
	push("ui_down")
	return {"start": tree.root.gui_get_focus_owner(), "pushed": true}


# Every visible, enabled control under `scope` that takes focus.
static func focusables(scope: Node, found: Array = []) -> Array:
	for child in scope.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			var off := c is BaseButton and (c as BaseButton).disabled
			if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and not off and c.size.x > 0.0 and c.size.y > 0.0:
				found.append(c)
		focusables(child, found)
	return found


# True when a control takes mouse clicks through its own gui_input handler (a script's _gui_input or a
# connection to the gui_input signal) while it is neither a button nor focusable.
static func clicks_by_hand(c: Control) -> bool:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	var script: Script = c.get_script()
	while script != null:
		for method in script.get_script_method_list():
			if method["name"] == "_gui_input":
				return true
		script = script.get_base_script()
	return not c.get_signal_connection_list("gui_input").is_empty()


# Every visible button, focusable control or hand-made click target under `scope`, for the size check.
static func targets(scope: Node, found: Array = []) -> Array:
	for child in scope.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			if (c is BaseButton or c.focus_mode == Control.FOCUS_ALL or clicks_by_hand(c)) and c.is_visible_in_tree() and c.size.x > 0.0 and c.size.y > 0.0:
				found.append(c)
		targets(child, found)
	return found


static func label(c: Control) -> String:
	var text := ""
	if "text" in c:
		text = String(c.text)
	return "%s %s%s" % [c.get_class(), c.name, (" \"" + text + "\"") if text != "" else ""]
