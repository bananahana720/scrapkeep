extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const Radio := preload("res://src/core/radio.gd")
const RadioTakes := preload("res://src/core/radio_takes.gd")
const RadioDial := preload("res://src/ui/radio_dial.gd")


const CRATE := Vector2(470.0, 380.0)
const ROW := Vector2(440.0, 36.0)

signal track_chosen(id: String, on_tape: bool)
signal tape_chosen(index: int)

var back: Button
var tune_button: Button
var shuffle_button: Button
var new_button: Button

var _count: Label
var _note: Label
var _tapes: HBoxContainer
var _crate: VBoxContainer
var _tape: VBoxContainer
var _tape_name: Label
var _rows := {}
var _tape_rows := {}
var _tape_buttons: Array[Button] = []


func _init() -> void:
	name = "RadioPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tapes = HBoxContainer.new()
	_tapes.alignment = BoxContainer.ALIGNMENT_CENTER
	_tapes.add_theme_constant_override("separation", 8)
	_tapes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tapes)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 24)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_crate = _column(body)
	_count = _crate.get_parent().get_parent().get_child(0)
	_tape = _column(body)
	_tape_name = _tape.get_parent().get_parent().get_child(0)
	_note = UiDraw.label(UiTokens.BODY, Palette.SAND)
	_note.custom_minimum_size = Vector2(0.0, 28.0)
	add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	new_button = ChoiceButton.new("new", "key_n", "New tape")
	shuffle_button = ChoiceButton.new("shuffle", "key_x", "Shuffle")
	tune_button = ChoiceButton.new("tune", "key_t", "Play on the radio")
	back = ChoiceButton.new("back", "key_esc", "Back")
	for b in [new_button, shuffle_button, tune_button, back]:
		b.focus_mode = Control.FOCUS_NONE if b != back else Control.FOCUS_ALL
		buttons.add_child(b)


func _column(parent: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(column)
	column.add_child(UiDraw.label(UiTokens.BODY, UiTokens.TEXT))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size = CRATE
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list)
	return list


static func reading(profile, radio) -> Dictionary:
	var found: Array = []
	for station in Radio.dial():
		for id in RadioTakes.on_station(station):
			if profile != null and profile.has_tune(id) and not id in found:
				found.append(id)
	for id in RadioTakes.all_ids():
		if profile != null and profile.has_tune(id) and not id in found:
			found.append(id)
	var takes := RadioTakes.take_ids().filter(func(id): return profile != null and profile.has_tune(id)).size()
	var every: Array = []
	for station in Radio.dial():
		for id in RadioTakes.on_station(station):
			if not id in every:
				every.append(id)
	for id in RadioTakes.all_ids():
		if not id in every:
			every.append(id)
	return {"found": found, "takes": takes, "tape": radio.mixtape, "ids": radio.current_mixtape()["ids"].duplicate(),
		"count": "%d / %d" % [found.size(), every.size()]}


func refresh(profile, radio) -> void:
	var read := reading(profile, radio)
	_count.text = read["count"]
	for b in _tape_buttons:
		b.queue_free()
	_tape_buttons.clear()
	for i in radio.mixtapes.size():
		var b := ChoiceButton.new("tape_%d" % i, "key_%d" % (i + 1), String(radio.mixtapes[i]["name"]))
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.set_pressed_no_signal(i == radio.mixtape)
		b.pressed.connect(func(): tape_chosen.emit(i))
		_tapes.add_child(b)
		_tape_buttons.append(b)
	new_button.disabled = radio.mixtapes.size() >= Radio.MAX_MIXTAPES
	_tape_name.text = String(radio.current_mixtape()["name"]).to_upper() + "  %d / %d" % [read["ids"].size(), Radio.MAX_TRACKS]
	var focused := focused_id()
	_fill(_crate, _rows, read["found"], false, read["ids"])
	_fill(_tape, _tape_rows, read["ids"], true, read["ids"])
	tune_button.text = "On the radio" if radio.station == Radio.MIXTAPE else "Play on the radio"
	if focused != "":
		focus(focused[0] == "t", focused.substr(2))


func _fill(list: VBoxContainer, rows: Dictionary, ids: Array, on_tape: bool, taped: Array) -> void:
	for id in rows:
		rows[id].queue_free()
	rows.clear()
	for id in ids:
		var row := TrackRow.new(id, id in taped and not on_tape)
		row.pressed.connect(func(): track_chosen.emit(id, on_tape))
		row.focus_entered.connect(_show_note.bind(id))
		list.add_child(row)
		rows[id] = row


func _show_note(id: String) -> void:
	var t := RadioTakes.track(id)
	_note.text = "" if t.is_empty() else "%s. %s" % [t["name"], t.get("sleeve", "")]


func focused_id() -> String:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for id in _rows:
		if _rows[id] == owner:
			return "c:" + id
	for id in _tape_rows:
		if _tape_rows[id] == owner:
			return "t:" + id
	return ""


func focus(on_tape: bool, id: String) -> void:
	var rows := _tape_rows if on_tape else _rows
	if rows.has(id):
		rows[id].grab_focus.call_deferred()
	elif not _rows.is_empty():
		_rows.values()[0].grab_focus.call_deferred()


func focus_first() -> void:
	if not _rows.is_empty():
		_rows.values()[0].grab_focus()
	else:
		back.grab_focus()


func crate_row(id: String) -> Button:
	return _rows.get(id)


func tape_row(id: String) -> Button:
	return _tape_rows.get(id)


func note_text() -> String:
	return _note.text


class TrackRow extends Button:
	var id := ""
	var taped := false

	func _init(track_id: String, on_tape: bool) -> void:
		id = track_id
		taped = on_tape
		var t := RadioTakes.track(id)
		var station := String(t.get("station", ""))
		var color := RadioDial.tint(String(RadioTakes.station(station).get("color", "SLATE")))
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = ROW
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		text = "%s   %s" % [Radio.call_sign(station) if station != "" else "----", t.get("name", id)]
		add_theme_font_override("font", UiFonts.bold())
		add_theme_font_size_override("font_size", UiTokens.BODY)
		var edge: Color = Palette.BRASS if t.get("tier", "") == "legend" else Color(color, 0.7)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := ChoiceButton.plate(edge.lightened(0.25) if state == "hover" else edge, 2, 14.0)
			box.content_margin_top = 4.0
			box.content_margin_bottom = 4.0
			add_theme_stylebox_override(state, box)
		add_theme_stylebox_override("focus", ChoiceButton.plate(UiTokens.TEXT, 4, 14.0, false))
		var words: Color = UiTokens.quiet() if taped else Palette.SAND
		add_theme_color_override("font_color", words)
		for key in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(key, UiTokens.TEXT)
