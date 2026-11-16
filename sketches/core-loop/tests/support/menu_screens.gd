extends RefCounted

# Shared by menu_reach_test and menu_size_test (rows UA-05 and UA-09 in BACKLOG.md): builds every menu
# screen in turn on a real Game and hands each one to a check while it is on show.

const Game := preload("res://src/game.gd")

var game
var screens
var tree: SceneTree


func _frames(count: int) -> void:
	for i in count:
		await tree.process_frame


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


# Calls check.call(name, scope_node) once per screen while that screen is up. Returns the screen count.
func visit(check: Callable) -> int:
	var count := 0
	var title_pages = screens._settings
	screens._on_flow_changed("title")
	await _frames(2)
	count += await _emit(check, "title", screens)

	for page in 4:
		screens.toggle_settings()
		await _frames(2)
		title_pages.show_page(page)
		await _frames(2)
		count += await _emit(check, "title settings page %d" % page, screens)
		screens.toggle_settings()
		await _frames(1)

	screens.toggle_help()
	await _frames(2)
	count += await _emit(check, "help", screens)
	screens.toggle_help()
	await _frames(1)

	screens.toggle_achievements()
	await _frames(2)
	count += await _emit(check, "achievements", screens)
	screens.toggle_achievements()
	await _frames(1)

	game.flow.open_class_select()
	await _frames(3)
	count += await _emit(check, "pilot select", screens)

	game.flow.show_title()
	game.flow.press_start()
	await _frames(2)
	game.pick_pilot(0)
	await _frames(3)
	for state in ["dead", "summary"]:
		screens._on_flow_changed(state)
		screens._guard = 0.0
		game.summary_latched = false
		await _frames(3)
		count += await _emit(check, state, screens)

	# The pause menu and its settings pages (the same pages as the title's, in the pause host).
	game.flow.show_title()
	game.flow.press_start()
	game.pick_pilot(0)
	await _frames(3)
	var menu = game.get_node("PauseMenu")
	menu._open = false
	menu.open()
	await _frames(3)
	count += await _emit(check, "pause menu", menu)
	menu._enter_settings()
	for page in 4:
		menu.settings_page().show_page(page)
		await _frames(2)
		count += await _emit(check, "pause settings page %d" % page, menu)
	menu._leave_settings(false)
	menu.close()
	await _frames(1)
	return count


func _emit(check: Callable, name: String, scope: Node) -> int:
	await check.call(name, scope)
	return 1


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


# Every visible button or focusable control under `scope`, for the size check.
static func targets(scope: Node, found: Array = []) -> Array:
	for child in scope.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		if child is Control:
			var c := child as Control
			if (c is BaseButton or c.focus_mode == Control.FOCUS_ALL) and c.is_visible_in_tree() and c.size.x > 0.0 and c.size.y > 0.0:
				found.append(c)
		targets(child, found)
	return found


static func label(c: Control) -> String:
	var text := ""
	if "text" in c:
		text = String(c.text)
	return "%s %s%s" % [c.get_class(), c.name, (" \"" + text + "\"") if text != "" else ""]
