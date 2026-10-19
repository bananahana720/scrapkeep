extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
const MechanicsDiagram := preload("res://src/ui/mechanics_diagram.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")

# The title's one-page how to play (DESIGN-V2 section 14.10): the run's goal loop as
# four icons in their event colours (the last is the next world), then the controls
# diagram Tab's first page draws, with no pilot chosen yet. Nothing here is written twice: the keys and words are
# FieldNotes.CONTROLS, the colours are event_kinds rows. Back presses H, as H opened it.

const GOAL := [
	{"icon": "res_heft", "kind": "heft_class_changed", "words": "Grow"},
	{"icon": "obj_warden", "kind": "warden_engaged", "words": "Break the Warden"},
	{"icon": "res_scrap", "kind": "bay_entered", "words": "Visit Moss"},
	{"icon": "obj_launch", "kind": "world_entered", "words": "Next world"},
]

# The word on the page button while each page shows: the page it turns to.
const PAGE_BUTTON := {"controls": "Pictures", "pictures": "Rules", "rules": "Controls"}

var back: Button
var diagram
var pictures := {}
var page_button: Button
var rules := {}
var _mechanics: HBoxContainer
var _rules: VBoxContainer
var _goal: HBoxContainer


func _init() -> void:
	name = "HelpPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal = _goal_row()
	add_child(_goal)
	diagram = ControlsDiagram.new()
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(diagram)
	_mechanics = _mechanics_row()
	_mechanics.visible = false
	add_child(_mechanics)
	_rules = _rules_column()
	_rules.visible = false
	add_child(_rules)
	var actions := _hbox(18)
	page_button = ChoiceButton.new("pictures", "", "Pictures")
	page_button.pressed.connect(toggle_pictures)
	actions.add_child(page_button)
	back = ChoiceButton.new("back", "key_h", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.add_child(back)
	add_child(actions)
	visibility_changed.connect(_reset_page)


# The Help button steps Controls, Pictures, Rules and back; its label names the next page.
func toggle_pictures() -> void:
	var next := "pictures" if diagram.visible else ("rules" if _mechanics.visible else "controls")
	_show(next)


func _show(page: String) -> void:
	diagram.visible = page == "controls"
	_mechanics.visible = page == "pictures"
	_rules.visible = page == "rules"
	# The rules page drops the goal row so its seven lines fit the calm-screen budget.
	_goal.visible = page != "rules"
	page_button.text = PAGE_BUTTON[page]


func _reset_page() -> void:
	if not visible:
		_show("controls")


static func key_rows() -> Array:
	return FieldNotes.CONTROLS.filter(func(row): return row.has("short") and row.has("caps"))


func _mechanics_row() -> HBoxContainer:
	var row := _hbox(18)
	row.name = "MechanicsPictures"
	for id in ["breach", "lift", "companion"]:
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 8)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := MechanicsDiagram.new(id)
		card.add_child(picture)
		var caption := _label(MechanicsDiagram.CAPTIONS[id], 16, Palette.SAND)
		caption.name = "Caption"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(caption)
		row.add_child(card)
		pictures[id] = {"picture": picture, "caption": caption}
	return row


# One label per FieldNotes.FIELD_RULES line: wall grip, jam fields, cast times, the radio dial,
# relay stakes and the F active.
func _rules_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = "FieldRules"
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for rule in FieldNotes.FIELD_RULES:
		var line := _label(rule["words"], 26, Palette.SAND)
		line.name = "Rule_" + String(rule["id"])
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
		row.add_child(_label(step["words"], 28, color))
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
