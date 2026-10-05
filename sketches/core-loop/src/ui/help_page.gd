extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ControlsDiagram := preload("res://src/ui/controls_diagram.gd")
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

var back: Button
var diagram


func _init() -> void:
	name = "HelpPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal_row())
	diagram = ControlsDiagram.new()
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(diagram)
	back = ChoiceButton.new("back", "key_h", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


static func key_rows() -> Array:
	return FieldNotes.CONTROLS.filter(func(row): return row.has("short") and row.has("caps"))


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
