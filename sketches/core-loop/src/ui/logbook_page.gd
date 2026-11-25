extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const STATUS_TEXT := {"none": "", "unencountered": "Unencountered", "new": "New", "available": "Available"}

var rows := {}
var detail: Label
var back: Button
var _list: VBoxContainer
var _codex
var _profile


func _init() -> void:
	name = "LogbookPage"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 16)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_override("font", UiFonts.bold())
	detail.add_theme_font_size_override("font_size", UiTokens.BODY)
	detail.add_theme_color_override("font_color", Palette.SAND)
	add_child(detail)
	back = ChoiceButton.new("back", "key_esc", "Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(back)


func refresh(codex, profile) -> void:
	_codex = codex
	_profile = profile
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	rows.clear()
	detail.text = "Select an entry to read."
	if _codex == null:
		return
	for entry in _codex.entries("", _profile):
		var id: String = entry["id"]
		var button := Button.new()
		button.name = id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_override("font", UiFonts.bold())
		button.add_theme_font_size_override("font_size", UiTokens.LABEL)
		_list.add_child(button)
		rows[id] = button
		_read_row(id, entry)
		button.pressed.connect(func(): open_entry(id))


func open_entry(id: String) -> void:
	if _codex == null or not rows.has(id):
		return
	_codex.open_entry(id, _profile)
	for entry in _codex.entries("", _profile):
		if entry["id"] != id:
			continue
		_read_row(id, entry)
		var words: String = _codex.entry_detail(id, _profile)
		detail.text = "%s\n%s" % [entry["name"], words]
		return


func _read_row(id: String, entry: Dictionary) -> void:
	var status: String = entry["status"]
	rows[id].text = "%s  ·  %s" % [entry["name"], STATUS_TEXT[status]]
	rows[id].add_theme_color_override("font_color", Palette.AMBER if status == "new" else Palette.SAND if entry["known"] else UiTokens.quiet())
