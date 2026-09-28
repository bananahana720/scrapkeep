extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const GameMap := preload("res://src/core/game_map.gd")

# The one page every placeholder shares (game_map.gd): a salvaged plate with a stamped
# "???" tag, the entry's title and teaser, and Back. An entry with children (the kit
# tree) also draws them as a row of nodes, so the page shows the thing's shape. The dev
# note, avenues and touches stay in the registry. Roughness lives on the frame; the
# words are plain (ROADMAP, HUD look). Back presses Esc through the game's screen key,
# as every menu button presses its key.

const PLATE_WIDTH := 560.0

var back: Button
var tag: Label
var title: Label
var teaser: Label
var nodes: HBoxContainer
var entry_id := ""


func _init() -> void:
	name = "PlaceholderPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame = ScrapFrame.plate(Palette.SAND, 7, Color(Palette.CHARCOAL, 0.94), 3.0, 0.62)
	frame.content_margin_left = 36.0
	frame.content_margin_right = 36.0
	frame.content_margin_top = 30.0
	frame.content_margin_bottom = 30.0
	plate.add_theme_stylebox_override("panel", frame)
	add_child(plate)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	tag = _label(GameMap.UNKNOWN, 28, Palette.AMBER)
	tag.add_theme_stylebox_override("normal", ScrapFrame.tag(Palette.AMBER, 3, false))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(tag)
	title = _label("", 40, Palette.SAND)
	column.add_child(title)
	teaser = _label("", 22, Color(Palette.SAND, 0.85))
	teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(teaser)
	nodes = HBoxContainer.new()
	nodes.alignment = BoxContainer.ALIGNMENT_CENTER
	nodes.add_theme_constant_override("separation", 12)
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(nodes)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)



func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# Fills the page from a registry entry. Nothing here is hard-coded per entry.
func show_entry(id: String) -> void:
	entry_id = id
	var e := GameMap.entry(id)
	title.text = e.get("title", "")
	teaser.text = e.get("teaser", "")
	for child in nodes.get_children():
		nodes.remove_child(child)
		child.queue_free()
	var kids := GameMap.children(id)
	nodes.visible = not kids.is_empty()
	for i in kids.size():
		var kid: Dictionary = kids[i]
		var live: bool = kid["status"] == GameMap.LIVE
		var edge := Palette.VERDIGRIS if live else Color(Palette.SAND, 0.45)
		var node := _label(kid["title"], 22, Palette.SAND if live else Color(Palette.SAND, 0.6))
		node.add_theme_stylebox_override("normal", ScrapFrame.tag(edge, 11 + i, false))
		nodes.add_child(node)
