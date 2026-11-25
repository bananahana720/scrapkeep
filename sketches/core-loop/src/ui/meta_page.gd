extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Achievements := preload("res://src/core/achievements.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")

# The between-run head starts (SG12), in table order (MetaOptions.ROWS): the level line on
# top, then one row per node. An opened node shows an amber star, its name and what it gives;
# a closed one a slate ring, its name, what it gives and, as its note, the one-run thing that
# opens it (its grant row's text). Nothing is bought here, so no row shows a price. Every word
# is a table row. Back sits on Esc. The achievements page's colours and shapes, so a star means
# the same thing on both pages.

const ROW_WIDTH := 640.0

var back: Button
var rows := {}
var override_rows := {}

var _profile
var _sitting := false
var _level: Label
var _list: VBoxContainer
var _overrides_box: VBoxContainer


func _init() -> void:
	name = "MetaPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level = _label("", UiTokens.HEADING, Palette.AMBER)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.name = "Level"
	add_child(_level)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 12)
	_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	_overrides_box = VBoxContainer.new()
	_overrides_box.name = "Overrides"
	_overrides_box.add_theme_constant_override("separation", 8)
	_overrides_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_overrides_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overrides_box)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


# Rebuilds the page from the saved profile.
func refresh(profile, sitting := false) -> void:
	_profile = profile
	_sitting = sitting
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	rows.clear()
	for child in _overrides_box.get_children():
		_overrides_box.remove_child(child)
		child.queue_free()
	override_rows.clear()
	_level.text = level_text_for(profile)
	for id in MetaOptions.ids():
		var row := _row(id, profile)
		_list.add_child(row)
		rows[id] = row
	var active := MetaOptions.active_overrides(profile, false, sitting)
	for cid in MetaOptions.override_ids():
		var btn := _override_row(cid, profile, cid in active, sitting)
		_overrides_box.add_child(btn)
		override_rows[cid] = btn


func toggle_override(code_id: String) -> bool:
	if _profile == null or not MetaOptions.OVERRIDE_CODES.has(code_id):
		return false
	var ok := MetaOptions.toggle_override(_profile, code_id, _sitting)
	if ok and _profile.can_save:
		_profile.save()
	refresh(_profile, _sitting)
	return ok


func _override_row(cid: String, profile, armed: bool, sitting: bool) -> Button:
	var row := MetaOptions.override_row(cid)
	var open := MetaOptions.override_open(cid, profile, sitting)
	var btn := Button.new()
	btn.name = cid
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.disabled = not open
	btn.custom_minimum_size = Vector2(ROW_WIDTH, 48.0)
	var state := "Armed" if armed else ("Ready" if open else "Locked")
	btn.text = "%s   %s\n%s  Downside %s" % [String(row.get("name", cid)), state, String(row.get("text", "")), String(row.get("downside_text", ""))]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.OLD_WORKS))
	btn.add_theme_font_size_override("font_size", UiTokens.CAPTION)
	var works: Dictionary = UiTokens.HANDS[UiTokens.Hand.OLD_WORKS]
	btn.add_theme_color_override("font_color", Palette.AMBER if armed else (works.ink if open else works.quiet))
	var plate = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, 73 + cid.hash())
	plate.border_color = Palette.AMBER if armed else works.edge
	plate.set_content_margin_all(UiTokens.GAP_S)
	btn.add_theme_stylebox_override("normal", plate)
	btn.pressed.connect(func(): toggle_override(cid))
	return btn


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
	words.add_child(_label(read["name"], UiTokens.LABEL, Palette.AMBER if open else shade))
	words.add_child(_label(read["text"], UiTokens.BODY, Color(shade, 0.9)))
	if read["note"] != "":
		var note := _label(read["note"], UiTokens.BODY, Palette.SAND)
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
