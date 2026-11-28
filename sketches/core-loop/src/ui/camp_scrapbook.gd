extends Control


const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ComicPage := preload("res://src/ui/comic_page.gd")
const CampLines := preload("res://src/core/camp_lines.gd")
const ScrapbookStore := preload("res://src/core/scrapbook_store.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")

const STATION_ID := "scrapbook"
const STATION_KEY := "key_b"
const STATION_LABEL := "Scrapbook"
const STATION_RADIUS := 4.0
const FIRE_PIT := "camp_fire_pit"
const EMPTY_LINE := "Nothing pasted in yet. The paste pot is full and has been waiting."
const LINE_SECONDS := 5.0
const LINE_GROUP := "camp_line"
const LINE_FADE := 1.2
const PAGE_H := 560.0
const HINT_PARTS := [{"cap": "key_q", "say": "Q"}, {"cap": "key_e", "say": "E"}, {"say": "turn"}, {"cap": "key_esc", "say": "Esc"}, {"say": "back"}]

var pages: Array = []
var index := 0
var store

var _view: Control
var _count: Label
var _empty: Label
var _hint: Control
var _holder: Control


func _init() -> void:
	name = "CampScrapbook"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Vector2(0.0, PAGE_H)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.offset_top = 70.0
	_holder.offset_bottom = -64.0
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)
	_count = _label(UiTokens.LABEL, Palette.AMBER)
	_count.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_count.offset_top = 22.0
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_count)
	_hint = CreditsHint.new()
	_hint.name = "Keys"
	_hint.setup(HINT_PARTS)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -52.0
	add_child(_hint)
	_empty = _label(UiTokens.LABEL, Palette.SAND)
	_empty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.text = EMPTY_LINE
	add_child(_empty)


func show_pages(list: Array) -> void:
	pages = list
	index = 0
	_rebuild()


func turn(step: int) -> bool:
	var next := clampi(index + step, 0, maxi(0, pages.size() - 1))
	if next == index:
		return false
	index = next
	_rebuild()
	return true


func _page_view(page: Dictionary) -> Control:
	var view := ComicPage.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.show_page(page)
	return view


func _rebuild() -> void:
	if is_instance_valid(_view):
		_holder.remove_child(_view)
		_view.queue_free()
	_view = null
	_empty.visible = pages.is_empty()
	_hint.visible = not pages.is_empty()
	if pages.is_empty():
		_count.text = ""
		return
	if store != null:
		store.load_shots(pages[index])
	_view = _page_view(pages[index])
	_holder.add_child(_view)
	_count.text = "%d / %d" % [index + 1, pages.size()]


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var step := 0
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		if code in [KEY_RIGHT, KEY_PAGEDOWN, KEY_E]:
			step = 1
		elif code in [KEY_LEFT, KEY_PAGEUP, KEY_Q]:
			step = -1
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER]:
			step = 1
		elif event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER]:
			step = -1
	if step != 0:
		turn(step)
		get_viewport().set_input_as_handled()


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func attach(hub) -> void:
	var game = hub.game
	var dir: String = game.storage_dir if game != null and game.get("storage_dir") != null else "user://"
	var store := ScrapbookStore.new(dir)
	var book: Control = (load("res://src/ui/camp_scrapbook.gd") as GDScript).new()
	book.name = "CampScrapbook"
	book.store = store
	book.visible = false
	var pit: Node3D = hub.piece(FIRE_PIT)
	var at: Vector3 = (pit.global_position if pit != null else Vector3.ZERO) + Vector3(0.0, 1.0, 0.0)
	var open := func():
		book.show_pages(store.summaries())
		game.screens.open_walk_page(book)
	hub.add_station(STATION_ID, at, STATION_LABEL, STATION_KEY, STATION_RADIUS, open)
	hub.tree_exiting.connect(func():
		if is_instance_valid(book) and book.get_parent() == null:
			book.free())
	var layer := CanvasLayer.new()
	layer.name = "CampLineLayer"
	layer.layer = 40
	hub.add_child(layer)
	hub.walk_entered.connect(func():
		var stats: Dictionary = {}
		var profile = game.ctx.profile if game.get("ctx") != null else null
		if profile != null and profile.has_method("stat"):
			for key in ["stages_cleared", "deaths", "kills"]:
				stats[key] = profile.stat(key)
		show_line(layer, CampLines.line_for(store.summaries(), stats)))
	hub.walk_left.connect(func():
		for card in layer.get_children():
			card.queue_free())


static func show_line(layer: Node, text: String) -> Control:
	var card := PanelContainer.new()
	card.name = "CampLine"
	card.add_to_group(LINE_GROUP)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.BRASS.lerp(Palette.LEDGER, 0.55), 0.96)
	style.border_color = Palette.CHARCOAL
	style.set_border_width_all(3)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 420.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", UiTokens.BODY)
	label.add_theme_color_override("font_color", Palette.CHARCOAL)
	card.add_child(label)
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.offset_left = 24.0
	card.offset_bottom = -90.0
	card.offset_top = -90.0
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(card)
	var tween := card.create_tween()
	tween.tween_interval(LINE_SECONDS)
	tween.tween_property(card, "modulate:a", 0.0, LINE_FADE)
	tween.tween_callback(card.queue_free)
	return card
