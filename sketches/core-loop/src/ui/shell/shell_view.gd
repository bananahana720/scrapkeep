extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const GameMap := preload("res://src/core/game_map.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const PlaceholderPage := preload("res://src/ui/placeholder_page.gd")

# The home screen and everything under it, as one view on the title (screens.gd owns
# it, the way it owns the how-to-play page). O on the title opens the home; each entry
# is a ChoiceButton that presses its key through game._screen_key, and every view is
# drawn from game_map.gd, so nothing here names an entry. Enter walks a live entry
# with children as a list, a placeholder as its page, and a live leaf to its route.
# Esc, or a click on Back, steps out one level; Space starts a run from anywhere here.
# The view lives only inside the title state: any flow change closes it.

signal changed

var game
var stack: Array[String] = []
var page
var _list: GridContainer
var _back: Button


func setup(game_ref) -> void:
	game = game_ref
	name = "Shell"
	visible = false
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list = GridContainer.new()
	_list.add_theme_constant_override("h_separation", 16)
	_list.add_theme_constant_override("v_separation", 12)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_list)
	_back = ChoiceButton.new("back", "key_esc", "Back")
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(game._screen_key.bind(KEY_ESCAPE))
	add_child(_back)
	page = PlaceholderPage.new()
	page.visible = false
	page.back.pressed.connect(game._screen_key.bind(KEY_ESCAPE))
	add_child(page)


# "home", "list" or "page".
func view() -> String:
	if stack.is_empty():
		return "home"
	return "page" if GameMap.action(stack.back()) == "page" else "list"


func heading() -> String:
	return GameMap.HOME_TITLE if stack.is_empty() else GameMap.entry(stack.back()).get("title", "")


func open() -> void:
	stack.clear()
	visible = true
	_render()


func close() -> void:
	if not visible:
		return
	stack.clear()
	visible = false
	changed.emit()


func back() -> void:
	if stack.is_empty():
		close()
		return
	stack.pop_back()
	_render()


func button_for(id: String) -> Button:
	for child in _list.get_children():
		if child.action == id:
			return child
	return null


# The key handler behind game._screen_key while the title shows the shell (and O on the
# title). Keys it does not own return false, so F-keys still pass.
func key(keycode: int) -> bool:
	if not visible:
		if keycode == KEY_O:
			open()
			return true
		return false
	if keycode == KEY_ESCAPE:
		back()
		return true
	if keycode == KEY_O:
		close()
		return true
	if keycode == KEY_SPACE or keycode == KEY_ENTER:
		game.flow.press_start()
		return true
	if view() == "page":
		return false
	for e in GameMap.children(GameMap.HOME if stack.is_empty() else stack.back()):
		if e["key"] != "" and OS.find_keycode_from_string(e["key"]) == keycode:
			_activate(e["id"])
			return true
	return false


func _activate(id: String) -> void:
	match GameMap.action(id):
		"list", "page":
			stack.append(id)
			_render()
		"start":
			game.flow.press_start()


func _render() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var shown := view()
	_list.visible = shown != "page"
	_back.visible = shown != "page"
	page.visible = shown == "page"
	if shown == "page":
		page.show_entry(stack.back())
	else:
		var entries := GameMap.children(GameMap.HOME if stack.is_empty() else stack.back())
		_list.columns = 2 if entries.size() > 5 else 1
		for e in entries:
			var button := ChoiceButton.new(e["id"], "key_" + String(e["key"]).to_lower(), e["title"])
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.custom_minimum_size = Vector2(340.0, 52.0)
			if e["status"] == GameMap.PLACEHOLDER:
				button.add_theme_color_override("font_color", Color(Palette.SAND, 0.65))
			button.pressed.connect(game._screen_key.bind(OS.find_keycode_from_string(e["key"])))
			_list.add_child(button)
	changed.emit()
