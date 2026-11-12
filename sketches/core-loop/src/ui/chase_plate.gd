extends PanelContainer

const ShiftBoard := preload("res://src/core/shift_board.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Icons := preload("res://src/ui/icons.gd")
const Palette := preload("res://src/core/palette.gd")

# What to chase next shift (BACKLOG W1-72, gameplay critique finding 10): a plate the summary tapes up
# left of the comic page, opposite the "next shift" tip. It names the shift board's next rung (an empty
# slate ring, the rung's name, what to do and what it opens) and the run's world's secrets as pips, an
# amber star for each found and a slate ring for each still out there, the achievements page's marks.
# Display only: every word is a shift_board.gd or secrets.gd row.

const WIDTH := 300.0
const SERIAL := 34
const ICON := 26.0
const PIP := float(UiTokens.BODY)

var _said := ""


# The plate's facts, for the plate and a test. next: the rung id ("" when the board is full). secrets:
# secrets.gd world_count, {} when the world has no secret rows.
static func reading(profile, world: int, known: Callable, sitting := false) -> Dictionary:
	var board := ShiftBoard.reading(profile, sitting)
	var out := {"next": String(board["next"]), "name": String(board["next_name"]), "text": String(board["next_text"]),
		"pays": String(board["next_pays"]), "secrets": {}}
	var count := Secrets.world_count(world, known)
	if int(count["total"]) > 0:
		out["secrets"] = count
	return out


static func shows(read: Dictionary) -> bool:
	return String(read["next"]) != "" or not (read["secrets"] as Dictionary).is_empty()


# The plate as one line of words, for a test and the screen reader of tests: "" for an empty plate.
static func said(read: Dictionary) -> String:
	var parts := PackedStringArray()
	if String(read["next"]) != "":
		parts.append("%s. %s %s." % [read["name"], read["text"], read["pays"]])
	var count: Dictionary = read["secrets"]
	if not count.is_empty():
		parts.append("%s secrets %d of %d." % [count["name"], count["found"], count["total"]])
	return " ".join(parts)


func _init(read: Dictionary) -> void:
	name = "ChasePlate"
	_said = said(read)
	var plate := ScrapFrame.plate(UiTokens.LINE, SERIAL, Color(UiTokens.INK, UiTokens.PLATE_ALPHA), float(UiTokens.EDGE), 0.5)
	plate.set_content_margin_all(UiTokens.GAP_L)
	add_theme_stylebox_override("panel", plate)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UiTokens.GAP_XS)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	if String(read["next"]) != "":
		var head := _line(column)
		head.add_child(_icon("ring", Color(Palette.SLATE, 0.8), ICON))
		head.add_child(_label(String(read["name"]), UiTokens.LABEL, UiTokens.ACCENT))
		var text := _label(String(read["text"]), UiTokens.BODY, UiTokens.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = WIDTH
		column.add_child(text)
		column.add_child(_label(String(read["pays"]), UiTokens.CAPTION, UiTokens.quiet(UiTokens.TEXT)))
	var count: Dictionary = read["secrets"]
	if not count.is_empty():
		if String(read["next"]) != "":
			var gap := Control.new()
			gap.custom_minimum_size.y = UiTokens.GAP_S
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(gap)
		column.add_child(_label("%s secrets" % count["name"], UiTokens.BODY, UiTokens.TEXT))
		var pips := _line(column)
		pips.name = "Pips"
		for i in int(count["total"]):
			var found := i < int(count["found"])
			pips.add_child(_icon("star" if found else "ring", UiTokens.ACCENT if found else Color(Palette.SLATE, 0.8), PIP))


func text() -> String:
	return _said


func _line(column: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.GAP_S)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	return row


func _icon(shape: String, tint: Color, side: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = Icons.shape(shape)
	icon.modulate = tint
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(side, side)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(words: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
