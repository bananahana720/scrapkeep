extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/core/icons.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const MechanicsDiagram := preload("res://src/ui/mechanics_diagram.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const CreditsHint := preload("res://src/ui/credits_hint.gd")


const GOAL := [
	{"icon": "res_heft", "kind": "heft_class_changed", "words": "Get heavy"},
	{"icon": "obj_warden", "kind": "warden_engaged", "words": "Break Wardens"},
	{"icon": "res_scrap", "kind": "bay_entered", "words": "Visit Moss"},
	{"icon": "obj_launch", "kind": "world_entered", "words": "Next world"},
]

var back: Button
var diagram
var pictures := {}
var page_button: Button
var page := 0
var rules := {}
var tuning
var _mechanics: HBoxContainer
var _rows: Array[HBoxContainer] = []
var _rules: VBoxContainer
var _goal: HBoxContainer


func _init() -> void:
	name = "HelpPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 24)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal = _goal_row()
	add_child(_goal)
	diagram = ControlsDiagram.new()
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(diagram)
	for ids in MechanicsDiagram.PAGES:
		var row := _mechanics_row(ids)
		row.visible = false
		_rows.append(row)
		add_child(row)
	_mechanics = _rows[0]
	_rules = _rules_column()
	_rules.visible = false
	add_child(_rules)
	var actions := _hbox(18)
	page_button = ChoiceButton.new("pictures", "", "Pictures")
	page_button.pressed.connect(toggle_pictures)
	actions.add_child(page_button)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_child(back)
	add_child(actions)
	visibility_changed.connect(_reset_page)


func toggle_pictures() -> void:
	show_page((page + 1) % (_rows.size() + 2))


func show_page(index: int) -> void:
	page = index
	var rules_page := page == _rows.size() + 1
	diagram.visible = page == 0
	for i in _rows.size():
		_rows[i].visible = page == i + 1
	_mechanics = _rows[clampi(page - 1, 0, _rows.size() - 1)]
	_rules.visible = rules_page
	rules["active"].visible = actives_on()
	_goal.visible = not rules_page
	if page == 0:
		page_button.text = "Pictures"
	elif page < _rows.size():
		page_button.text = "More"
	elif page == _rows.size():
		page_button.text = "Rules"
	else:
		page_button.text = "Controls"


func _show(name: String) -> void:
	show_page({"controls": 0, "pictures": 1, "rules": _rows.size() + 1}[name])


func pictures_showing() -> bool:
	return page > 0 and page <= _rows.size()


func actives_on() -> bool:
	return tuning != null and tuning.option("actives") == "on"


func _reset_page() -> void:
	if not visible:
		show_page(0)
	else:
		refresh_keys()


func refresh_keys() -> void:
	for rule in FieldNotes.FIELD_RULES:
		rules[rule["id"]].setup(FieldNotes.rule_parts(rule))


static func key_rows() -> Array:
	return ControlsDiagram.controls().filter(func(row): return row.has("short") and row.has("caps"))


func _mechanics_row(ids: Array) -> HBoxContainer:
	var row := _hbox(18)
	row.name = "MechanicsPictures%d" % (_rows.size() + 1)
	for id in ids:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := MechanicsDiagram.new(id)
		card.add_child(picture)
		var caption: Label = null
		if MechanicsDiagram.CAPTIONS.has(id):
			caption = _label(MechanicsDiagram.CAPTIONS[id], UiTokens.BODY, Palette.SAND)
			caption.name = "Caption"
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card.add_child(caption)
		row.add_child(card)
		pictures[id] = {"picture": picture, "caption": caption}
	return row


class RuleLine extends CreditsHint:
	func drawn_words() -> PackedStringArray:
		return PackedStringArray([text()])


func _rules_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "FieldRules"
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for rule in FieldNotes.FIELD_RULES:
		var line := RuleLine.new()
		line.name = "Rule_" + String(rule["id"])
		line.setup(FieldNotes.rule_parts(rule))
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(line)
		rules[rule["id"]] = line
	return column


func _goal_row() -> HBoxContainer:
	var row := _hbox(14)
	for i in GOAL.size():
		var step: Dictionary = GOAL[i]
		var color := EventKinds.color(step["kind"])
		if i > 0:
			row.add_child(_icon(Icons.shape("chevron"), Color(Palette.SAND, 0.6), 22.0))
		row.add_child(_icon(Icons.texture(step["icon"]), Icons.tint(step["icon"], color), 36.0))
		row.add_child(_label(step["words"], UiTokens.HEADING, color))
	return row


func _hbox(separation: int) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", separation)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


func _icon(texture: Texture2D, tint: Color, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = tint
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(side, side)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
