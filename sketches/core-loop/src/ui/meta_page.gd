extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")

# The between-run head starts (SG12), in table order (MetaOptions.ROWS): the level line on
# top, then one row per node. An opened node shows an amber star, its name and what it gives;
# a closed one a slate ring, its name, what it gives and, as its note, the one-run thing that
# opens it (its grant row's text). Nothing is bought here, so no row shows a price. Every word
# is a table row. Back sits on Esc. The achievements page's colours and shapes, so a star means
# the same thing on both pages.

const ROW_WIDTH := 640.0

var back: Button
var rows := {}

var _level: Label
var _list: VBoxContainer


func _init() -> void:
	name = "MetaPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = _label("", 28, Palette.AMBER)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.name = "Level"
	add_child(_level)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


# Rebuilds the page from the saved profile.
func refresh(profile) -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	rows.clear()
	_level.text = level_text_for(profile)
	for id in MetaOptions.ids():
		var row := _row(id, profile)
		_list.add_child(row)
		rows[id] = row


func level_text() -> String:
	return _level.text


static func level_text_for(profile) -> String:
	var opened := MetaOptions.level(profile) if profile != null else 0
	return "Head starts: %d of %d" % [opened, MetaOptions.ids().size()]


# The words one row shows, for a test and for the row itself.
static func reading(id: String, profile) -> Dictionary:
	var data := MetaOptions.row(id)
	var open: bool = profile != null and profile.has_option(id)
	var note := "" if open else String(Achievements.row(String(data["grant"])).get("text", ""))
	return {"open": open, "name": String(data["name"]), "text": String(data["text"]), "note": note}


func _row(id: String, profile) -> Control:
	var read := reading(id, profile)
	var open: bool = read["open"]
	var box := HBoxContainer.new()
	box.name = id
	box.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mark := TextureRect.new()
	mark.texture = Icons.shape("star" if open else "ring")
	mark.modulate = Palette.AMBER if open else Color(Palette.SLATE, 0.8)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(30.0, 30.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(mark)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(words)
	var shade := Palette.SAND if open else Palette.SLATE
	words.add_child(_label(read["name"], 24, Palette.AMBER if open else shade))
	words.add_child(_label(read["text"], 16, Color(shade, 0.9)))
	if read["note"] != "":
		var note := _label(read["note"], 18, Palette.SAND)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note.name = "Note"
		box.add_child(note)
	return box


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
