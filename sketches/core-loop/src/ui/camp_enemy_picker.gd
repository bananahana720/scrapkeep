extends VBoxContainer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const Sandbox := preload("res://src/world/camp_sandbox.gd")

# The camp's enemy picker, the page the dispatch box opens (camp_sandbox.gd owns the yard).
# Every kind the pilot has met in a run is a plain row; a kind not yet met is a dim name with
# a dark disc, and its note says where it turns up. A met row calls that enemy onto a grate in
# the sandbox yard (up to Sandbox.CAP at a time); "Clear yard" sends them all home; Back, Esc
# or pad B closes the page. The page reads and writes which kinds have been met through the
# player's saved stats ("met.<kind>"), the one place this feature touches the save; the yard
# itself never writes it.

const MET_PREFIX := "met."
const ROW_SIZE := Vector2(250.0, 40.0)
const COLUMNS := 3
const LIST_H := 330.0
const NOTE_FONT := UiTokens.BODY
const ROW_GAP := 8
# The note spans the grid exactly: three rows and the two gaps between them.
const NOTE_W := (ROW_SIZE.x + ROW_GAP) * COLUMNS - ROW_GAP
const NOTE_OPEN := "Pick a crew to send to the grate. Four at a time; the box does not argue."

signal kind_chosen(kind: String)
signal clear_chosen
signal closed

var clear_button: Button
var back_button: Button

var _count: Label
var _live: YardPips
var _note: Label
var _grid: GridContainer
var _rows := {}
var _met := {}
var _full := false


func _init() -> void:
	name = "CampEnemyPicker"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiDraw.label(UiTokens.LABEL, Palette.AMBER, "Dispatch box"))
	_count = UiDraw.label(UiTokens.BODY, Palette.SAND)
	add_child(_count)
	_live = YardPips.new()
	_live.name = "YardPips"
	add_child(_live)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	scroll.custom_minimum_size = Vector2((ROW_SIZE.x + 10.0) * COLUMNS + 20.0, LIST_H)
	add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", ROW_GAP)
	_grid.add_theme_constant_override("v_separation", ROW_GAP)
	scroll.add_child(_grid)
	for kind in Sandbox.kinds():
		var row := Row.new(kind)
		row.pressed.connect(_on_row.bind(kind))
		row.focus_entered.connect(_show_note.bind(kind))
		_grid.add_child(row)
		_rows[kind] = row
	# The note keeps to the list's width (a line across the whole screen reads as one long
	# line) and holds the height of the longest note, so the buttons never move under a focus.
	_note = UiDraw.label(NOTE_FONT, Palette.SAND)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lines := _most_note_lines()
	_note.custom_minimum_size = Vector2(NOTE_W, lines * UiFonts.bold().get_height(NOTE_FONT) + (lines - 1) * _note.get_theme_constant("line_spacing"))
	add_child(_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	clear_button = ChoiceButton.new("clear", "key_c", "Clear yard")
	clear_button.pressed.connect(func(): clear_chosen.emit())
	buttons.add_child(clear_button)
	back_button = ChoiceButton.new("back", "key_esc", "Back")
	back_button.pressed.connect(func(): closed.emit())
	buttons.add_child(back_button)
	refresh([], 0)


# --- What the save holds -------------------------------------------------------------

# The kinds with a "met" mark in these stats. A null save has met nothing.
static func met_kinds(saved) -> Array:
	var out: Array = []
	if saved == null:
		return out
	for kind in Sandbox.kinds():
		if saved.stat(MET_PREFIX + kind) > 0.0:
			out.append(kind)
	return out


# The kinds this game's save has met.
static func met_of(game) -> Array:
	return met_kinds(game.ctx.profile) if game != null and game.ctx != null else []


# True the first time a kind is marked met. Saves only when the save can be written.
static func mark_met(saved, kind: String) -> bool:
	if saved == null or kind == "" or saved.stat(MET_PREFIX + kind) > 0.0:
		return false
	saved.set_stat(MET_PREFIX + kind, 1.0)
	if saved.can_save:
		saved.save()
	return true


# Marks every enemy a run spawns as met. The sandbox spawns without the bus fact, so a
# called enemy never marks itself.
static func watch(game) -> void:
	if game == null or game.events == null or game.has_meta("met_watch"):
		return
	game.set_meta("met_watch", true)
	game.events.enemy_spawned.connect(func(enemy: Node3D, kind: String):
		if not enemy.has_meta("sandbox_slot"):
			mark_met(game.ctx.profile, kind))


# --- The page ----------------------------------------------------------------------------

# The rows for these met kinds, in picker order: {kind, name, met, where}.
static func reading(met: Array) -> Array:
	var out: Array = []
	for kind in Sandbox.kinds():
		out.append({"kind": kind, "name": Sandbox.name_of(kind), "met": kind in met, "where": Sandbox.where_met(kind)})
	return out


func refresh(met: Array, live: int, cap := Sandbox.CAP) -> void:
	_met.clear()
	for kind in met:
		_met[kind] = true
	_full = live >= cap
	var known := 0
	for kind in _rows:
		var seen: bool = _met.has(kind)
		known += 1 if seen else 0
		_rows[kind].set_state(seen, _full)
	_count.text = "Met %d of %d" % [known, _rows.size()]
	_live.set_yard(live, cap)
	clear_button.disabled = live <= 0
	var focused := focused_kind()
	if focused != "":
		_show_note(focused)
	else:
		_note.text = NOTE_OPEN
		_note.add_theme_color_override("font_color", Palette.SAND)


func focus_first() -> void:
	for kind in _rows:
		if _met.has(kind):
			_rows[kind].grab_focus()
			return
	for kind in _rows:
		_rows[kind].grab_focus()
		return


func focused_kind() -> String:
	var owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for kind in _rows:
		if _rows[kind] == owner:
			return kind
	return ""


func row(kind: String) -> Button:
	return _rows.get(kind)


func kinds() -> Array:
	return _rows.keys()


func is_met(kind: String) -> bool:
	return _met.has(kind)


func note_text() -> String:
	return _note.text


# The yard as [live, cap]: the pips' filled and total count.
func yard_pips() -> Vector2i:
	return Vector2i(_live.live, _live.cap)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _on_row(kind: String) -> void:
	_show_note(kind)
	if not _met.has(kind) or _full:
		return
	kind_chosen.emit(kind)


func _show_note(kind: String) -> void:
	if not _rows.has(kind):
		return
	var color := Palette.SAND
	if not _met.has(kind):
		color = Palette.SLATE
	elif _full:
		color = Palette.COPPER
	_note.text = _note_for(kind, _met.has(kind), _full)
	_note.add_theme_color_override("font_color", color)


# A kind's note: where it turns up when not met, that the yard is full, or its own line.
static func _note_for(kind: String, met: bool, full: bool) -> String:
	if not met:
		return "Not met yet. %s" % Sandbox.where_met(kind)
	if full:
		return "%s. The yard is full. Clear it, or wait for the floor to thin out." % Sandbox.name_of(kind)
	return "%s. %s" % [Sandbox.name_of(kind), Sandbox.line_of(kind)]


# The most lines any note the page can show takes, wrapped at the note's width.
static func _most_note_lines() -> int:
	var font := UiFonts.bold()
	var tallest := font.get_multiline_string_size(NOTE_OPEN, HORIZONTAL_ALIGNMENT_CENTER, NOTE_W, NOTE_FONT).y
	for kind in Sandbox.kinds():
		for state in [[false, false], [true, true], [true, false]]:
			tallest = maxf(tallest, font.get_multiline_string_size(_note_for(kind, state[0], state[1]), HORIZONTAL_ALIGNMENT_CENTER, NOTE_W, NOTE_FONT).y)
	return maxi(1, roundi(tallest / font.get_height(NOTE_FONT)))


# The yard as one pip a slot: amber filled, slate empty (a count drawn, not worded).
class YardPips extends Control:
	const SIDE := 16.0
	const GAP := 8.0
	var live := 0
	var cap := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func set_yard(now: int, slots: int) -> void:
		live = now
		cap = slots
		custom_minimum_size = Vector2(maxf(0.0, cap * (SIDE + GAP) - GAP), SIDE + 4.0)
		queue_redraw()

	func _draw() -> void:
		for i in cap:
			draw_circle(Vector2(SIDE * 0.5 + i * (SIDE + GAP), size.y * 0.5), SIDE * 0.5, Palette.AMBER if i < live else Palette.SLATE)


# One enemy kind in the list: a disc and the name. A kind not yet met is slate, with a dark
# disc as its silhouette; a kind the yard cannot take right now is edged in copper.
class Row extends Button:
	var kind := ""
	var met := false
	var full := false

	func _init(kind_id: String) -> void:
		kind = kind_id
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = ROW_SIZE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		clip_text = true
		add_theme_font_override("font", UiFonts.bold())
		add_theme_font_size_override("font_size", UiTokens.BODY)
		set_state(false, false)

	func set_state(is_met: bool, is_full: bool) -> void:
		met = is_met
		full = is_full
		text = Sandbox.name_of(kind)
		var edge: Color = Color(Palette.SLATE, 0.5)
		if met:
			edge = Palette.COPPER if full else UiTokens.LINE
		for state in ["normal", "hover", "pressed", "disabled"]:
			var box := ChoiceButton.plate(edge.lightened(0.25) if state == "hover" else edge, 2, 38.0)
			box.content_margin_top = 4.0
			box.content_margin_bottom = 4.0
			add_theme_stylebox_override(state, box)
		add_theme_stylebox_override("focus", ChoiceButton.plate(UiTokens.TEXT, 4, 38.0, false))
		var words: Color = Palette.SAND if met else UiTokens.quiet()
		if met and full:
			words = UiTokens.quiet()
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			add_theme_color_override(key, UiTokens.TEXT if key != "font_color" and met and not full else words)
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(20.0, size.y * 0.5)
		var r := size.y * 0.28
		if met:
			draw_circle(c, r, Color(0.06, 0.07, 0.07))
			draw_circle(c, r * 0.45, Palette.AMBER)
		else:
			draw_circle(c, r, Color(0.02, 0.02, 0.03, 0.9))
			draw_arc(c, r, 0.0, TAU, 20, Color(Palette.SLATE, 0.45), 1.0)
