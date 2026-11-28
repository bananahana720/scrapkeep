extends PanelContainer

const ShiftBoard := preload("res://src/core/shift_board.gd")
const Secrets := preload("res://src/core/secrets.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const Icons := preload("res://src/core/icons.gd")
const Palette := preload("res://src/core/palette.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const Comfort := preload("res://src/core/comfort.gd")


const WIDTH := 300.0
const SERIAL := 34
const ICON := 26.0
const PIP := float(UiTokens.BODY)
const FLAP_SECONDS := 0.36

var _flap: Label
var _settling: Tween

var _said := ""


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
	var plate = ScrapFrame.hand_plate(UiTokens.Hand.OLD_WORKS, SERIAL)
	plate.set_content_margin_all(UiTokens.GAP_L)
	plate.content_margin_bottom = UiTokens.GAP_XL
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
		_flap = AchievementsPage.flap(String(read["name"]), UiTokens.LABEL)
		_flap.name = "Flap"
		head.add_child(_flap)
		var text := AchievementsPage.chalk(String(read["text"]))
		text.name = "Chalk"
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = WIDTH
		column.add_child(text)
		var pays := _label(String(read["pays"]), UiTokens.CAPTION, _works().quiet)
		pays.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.OLD_WORKS))
		column.add_child(pays)
	var count: Dictionary = read["secrets"]
	if not count.is_empty():
		if String(read["next"]) != "":
			var gap := Control.new()
			gap.custom_minimum_size.y = UiTokens.GAP_S
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(gap)
		var secrets := _label("%s secrets" % count["name"], UiTokens.BODY, _works().ink)
		secrets.add_theme_font_override("font", UiFonts.face(UiTokens.Hand.OLD_WORKS))
		column.add_child(secrets)
		var pips := _line(column)
		pips.name = "Pips"
		for i in int(count["total"]):
			var found := i < int(count["found"])
			pips.add_child(_icon("star" if found else "ring", UiTokens.ACCENT if found else Color(Palette.SLATE, 0.8), PIP))


func _ready() -> void:
	if _flap == null:
		return
	if Comfort.reduced_motion:
		_flap.visible_ratio = 1.0
		return
	_flap.visible_ratio = 0.0
	_settling = create_tween().set_trans(UiTokens.hand(UiTokens.Hand.OLD_WORKS).trans)
	_settling.tween_property(_flap, "visible_ratio", 1.0, FLAP_SECONDS)


func text() -> String:
	return _said


static func _works() -> Dictionary:
	return UiTokens.HANDS[UiTokens.Hand.OLD_WORKS]


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
