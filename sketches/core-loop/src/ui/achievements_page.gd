extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")

# The title's list of every achievement, in table order (Achievements.ROWS): an amber
# star, the name and the date for an earned row; a slate ring, the name and the words
# to do for one not earned yet. A hidden row stays "???" and "Keep playing." until it is
# earned. A row with a count shows how far along it is, from Progress.count_of. Nothing
# is written twice: every word is a table row. Back presses A, as A opened it.

const COLUMNS := 2
const ROW_WIDTH := 600.0
const HIDDEN_NAME := "???"
const HIDDEN_TEXT := "Keep playing."

var back: Button
var rows := {}

var _grid: GridContainer


func _init() -> void:
	name = "AchievementsPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 22)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	back = ChoiceButton.new("back", "key_a", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


# Rebuilds the list from the saved profile and the progress node's counters.
func refresh(profile, progress) -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	rows.clear()
	for id in Achievements.ids():
		var row := _row(id, profile, progress)
		_grid.add_child(row)
		rows[id] = row


# The words one row shows, for a test and for the row itself: name, text, and state.
static func reading(id: String, profile, progress) -> Dictionary:
	var data := Achievements.row(id)
	var earned: bool = profile != null and profile.earned(id)
	var hidden := bool(data.get("hidden", false)) and not earned
	var out := {"earned": earned, "name": HIDDEN_NAME if hidden else String(data["name"]),
		"text": HIDDEN_TEXT if hidden else String(data["text"]), "note": ""}
	if earned:
		var at: int = progress.earned_at(id) if progress != null else 0
		out["note"] = Time.get_date_string_from_unix_time(at) if at > 0 else "Earned"
	elif not hidden and int(data.get("count", 1)) > 1 and progress != null:
		out["note"] = "%d / %d" % [mini(int(progress.count_of(id)), int(data["count"])), int(data["count"])]
	return out


func _row(id: String, profile, progress) -> Control:
	var read := reading(id, profile, progress)
	var earned: bool = read["earned"]
	var box := HBoxContainer.new()
	box.name = id
	box.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var star := TextureRect.new()
	star.texture = Icons.shape("star" if earned else "ring")
	star.modulate = Palette.AMBER if earned else Color(Palette.SLATE, 0.8)
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(30.0, 30.0)
	star.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(star)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(words)
	var shade := Palette.SAND if earned else Palette.SLATE
	words.add_child(_label(read["name"], 24, Palette.AMBER if earned else shade))
	words.add_child(_label(read["text"], 16, Color(shade, 0.9)))
	if read["note"] != "":
		var note := _label(read["note"], 20, Palette.AMBER if earned else Palette.SAND)
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
