extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")


const SHELF_COLORS := [Palette.AMBER, Palette.COPPER, Palette.SANDSTONE, Palette.LEDGER]
const DETENTS := ["Idle", "Cruise", "Full tilt"]
const SLEEVE_SIZE := Vector2(232.0, 44.0)
const DECK := 300.0
const CRATE_H := 360.0

signal sleeve_chosen(id: String)

var back: Button
var play_button: Button
var deck: Turntable

var _count: Label
var _note: Label
var _shelves: HBoxContainer
var _detents: Array[Button] = []
var _sleeves := {}
var _found := {}
var _playing := ""


func _init() -> void:
	name = "JukeboxPage"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count = UiDraw.label(UiTokens.LABEL, Palette.AMBER)
	add_child(_count)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 24)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	deck = Turntable.new()
	deck.custom_minimum_size = Vector2(DECK, DECK)
	deck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(deck)
	var crate := ScrollContainer.new()
	crate.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	crate.follow_focus = true
	crate.custom_minimum_size = Vector2(0.0, CRATE_H)
	body.add_child(crate)
	_shelves = HBoxContainer.new()
	_shelves.add_theme_constant_override("separation", 12)
	_shelves.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crate.add_child(_shelves)
	for shelf in TuneRows.SHELVES.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shelves.add_child(column)
		column.add_child(UiDraw.label(UiTokens.BODY, SHELF_COLORS[shelf], TuneRows.SHELVES[shelf].to_upper()))
		for row in TuneRows.on_shelf(shelf):
			var sleeve := Sleeve.new(row, SHELF_COLORS[shelf])
			sleeve.pressed.connect(_on_sleeve.bind(String(row["id"])))
			sleeve.focus_entered.connect(_show_note.bind(String(row["id"])))
			column.add_child(sleeve)
			_sleeves[row["id"]] = sleeve
	_note = UiDraw.label(UiTokens.BODY, Palette.SAND)
	_note.custom_minimum_size = Vector2(0.0, 30.0)
	add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	play_button = ChoiceButton.new("play", "key_space", "Play")
	play_button.focus_mode = Control.FOCUS_NONE
	buttons.add_child(play_button)
	for i in DETENTS.size():
		var detent := ChoiceButton.new("detent_%d" % i, "key_%d" % (i + 1), DETENTS[i])
		detent.toggle_mode = true
		detent.focus_mode = Control.FOCUS_NONE
		buttons.add_child(detent)
		_detents.append(detent)
	back = ChoiceButton.new("back", "key_esc", "Back")
	buttons.add_child(back)


static func reading(profile, playing := "", detent := 2, sitting := false) -> Dictionary:
	var found: Array = []
	var shown: Array = []
	for id in TuneRows.ids():
		var has: bool = profile != null and profile.has_tune(id)
		if has:
			found.append(id)
		if has or not TuneRows.shut(id, profile, sitting):
			shown.append(id)
	return {"found": found, "shown": shown, "total": shown.size(), "playing": playing, "detent": detent,
		"count": "%d / %d" % [found.size(), shown.size()]}


func refresh(profile, playing := "", detent := 2, sitting := false) -> void:
	var read := reading(profile, playing, detent, sitting)
	_found.clear()
	for id in read["found"]:
		_found[id] = true
	_playing = playing
	_count.text = read["count"]
	for id in _sleeves:
		_sleeves[id].visible = id in read["shown"]
		_sleeves[id].set_state(_found.has(id), id == playing)
	for i in _detents.size():
		_detents[i].set_pressed_no_signal(i == detent)
	play_button.text = "Stop" if playing != "" else "Play"
	deck.set_record(TuneRows.row(playing), SHELF_COLORS[int(TuneRows.row(playing).get("shelf", 0))] if playing != "" else Palette.SLATE)
	var focused := focused_id()
	_show_note(focused if focused != "" else playing)


func focus_first() -> void:
	var first := ""
	for id in TuneRows.ids():
		if _found.has(id):
			first = id
			break
	_sleeves[first if first != "" else TuneRows.ids()[0]].grab_focus()


func focused_id() -> String:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for id in _sleeves:
		if _sleeves[id] == owner:
			return id
	return ""


func sleeve(id: String) -> Button:
	return _sleeves.get(id)


func detent_button(i: int) -> Button:
	return _detents[i]


func note_text() -> String:
	return _note.text


func is_found(id: String) -> bool:
	return _found.has(id)


func _on_sleeve(id: String) -> void:
	sleeve_chosen.emit(id)


func _show_note(id: String) -> void:
	var row := TuneRows.row(id)
	if row.is_empty():
		_note.text = ""
		return
	if _found.has(id):
		_note.text = "%s. %s" % [row["name"], row["sleeve"]]
		_note.add_theme_color_override("font_color", Palette.SAND)
	else:
		_note.text = "Not heard yet. %s" % row["where"]
		_note.add_theme_color_override("font_color", UiTokens.quiet())


class Sleeve extends Button:
	var row: Dictionary
	var tint: Color
	var found := false
	var playing := false

	func _init(r: Dictionary, color: Color) -> void:
		row = r
		tint = color
		accessibility_name = String(r.get("name", ""))
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = SLEEVE_SIZE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		add_theme_font_override("font", UiFonts.bold())
		add_theme_font_size_override("font_size", UiTokens.BODY)
		set_state(false, false)

	func set_state(is_found: bool, is_playing: bool) -> void:
		found = is_found
		playing = is_playing
		text = String(row["name"]) if found else "???"
		var edge: Color = Palette.ARC if playing else (Palette.BRASS if found and row["rare"] else (Color(tint, 0.7) if found else Color(Palette.SLATE, 0.6)))
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := ChoiceButton.plate(edge.lightened(0.25) if state == "hover" else edge, 3 if playing else 2, 50.0)
			box.content_margin_left = 50.0
			box.content_margin_top = 4.0
			box.content_margin_bottom = 4.0
			add_theme_stylebox_override(state, box)
		add_theme_stylebox_override("focus", ChoiceButton.plate(Palette.ARC if playing else UiTokens.TEXT, 4, 50.0, false))
		var words: Color = Palette.SAND if found else UiTokens.quiet()
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(key, UiTokens.TEXT if key != "font_color" and found else words)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(26.0, size.y * 0.5)
		var r := size.y * 0.36
		draw_circle(c, r, Color(0.06, 0.07, 0.07) if found else Color(Palette.SLATE, 0.25))
		for g in [0.82, 0.66]:
			draw_arc(c, r * g, 0.0, TAU, 24, Color(1, 1, 1, 0.08), 1.0)
		draw_circle(c, r * 0.4, tint if found else Color(Palette.SLATE, 0.6))
		draw_circle(c, 2.0, Palette.CHARCOAL)


class Turntable extends Control:
	const RPM := 33.333
	const STAMP := 0.6
	const WORD := "KA-CHUNK"
	var record := {}
	var label_color := Palette.SLATE
	var turn := 0.0
	var arm := 0.0
	var stamp_left := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_record(row: Dictionary, color: Color) -> void:
		if not row.is_empty() and row.get("id", "") != record.get("id", ""):
			stamp_left = STAMP
		record = row
		label_color = color
		queue_redraw()

	func playing() -> bool:
		return not record.is_empty()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		arm = move_toward(arm, 1.0 if playing() else 0.0, delta * 3.0)
		if playing() and arm >= 1.0:
			turn = fmod(turn + delta * TAU * RPM / 60.0, TAU)
		stamp_left = maxf(0.0, stamp_left - delta)
		queue_redraw()

	func _draw() -> void:
		var s := size
		var plinth := Rect2(Vector2.ZERO, s)
		draw_rect(plinth, Color(Palette.CHARCOAL, 0.95))
		draw_rect(plinth, Palette.COPPER, false, 3.0)
		for corner in [Vector2(12, 12), Vector2(s.x - 12, 12), Vector2(12, s.y - 12), Vector2(s.x - 12, s.y - 12)]:
			draw_circle(corner, 4.0, Palette.COPPER.darkened(0.3))
		var c := Vector2(s.x * 0.44, s.y * 0.54)
		var r := minf(s.x, s.y) * 0.38
		draw_circle(c, r + 8.0, Palette.CABLE)
		draw_circle(c, r, Color(0.05, 0.055, 0.055))
		for i in 7:
			draw_arc(c, r * (0.92 - i * 0.07), 0.0, TAU, 48, Color(1, 1, 1, 0.06), 1.0)
		if playing():
			draw_arc(c, r * 0.78, turn, turn + 0.7, 12, Color(1, 1, 1, 0.22), 3.0)
			draw_arc(c, r * 0.6, turn + PI, turn + PI + 0.5, 12, Color(1, 1, 1, 0.16), 3.0)
		draw_circle(c, r * 0.34, label_color if playing() else Color(Palette.SLATE, 0.5))
		if playing():
			var tick := c + Vector2(cos(turn), sin(turn)) * r * 0.24
			draw_circle(tick, 3.5, Palette.CHARCOAL)
		draw_circle(c, 4.0, Palette.SAND)
		var pivot := Vector2(s.x * 0.88, s.y * 0.16)
		var length := r * 1.3
		var rest := deg_to_rad(95.0)
		var on := rest
		while on < deg_to_rad(170.0) and (pivot + Vector2(cos(on), sin(on)) * length).distance_to(c) > r * 0.8:
			on += deg_to_rad(1.0)
		var angle := lerpf(rest, on, arm)
		var tip := pivot + Vector2(cos(angle), sin(angle)) * length
		draw_circle(pivot, 11.0, Palette.COPPER)
		draw_line(pivot, tip, Palette.SAND, 4.0)
		draw_rect(Rect2(tip - Vector2(7, 5), Vector2(14, 10)), Palette.AMBER)
		var knob := Vector2(s.x * 0.88, s.y * 0.86)
		draw_circle(knob, 14.0, Palette.CABLE)
		draw_circle(knob, 10.0, Palette.ARC)
		if stamp_left > 0.0:
			var a := clampf(stamp_left / STAMP * 1.6, 0.0, 1.0)
			var at := Vector2(s.x * 0.08, s.y * 0.14)
			draw_set_transform(at, -0.12, Vector2.ONE * lerpf(1.0, 1.25, a))
			draw_string(UiFonts.bold(), Vector2(2, 2), WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.HEADING, Color(Palette.CHARCOAL, a))
			draw_string(UiFonts.bold(), Vector2.ZERO, WORD, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTokens.HEADING, Color(Palette.AMBER, a))
			draw_set_transform(Vector2.ZERO)
