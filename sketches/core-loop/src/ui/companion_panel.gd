extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const Companion := preload("res://src/core/companion.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The companion assembly screen, a calm menu between attempts. It lists the pieces the run
# owns, shows the two sockets and writes the result back to run.companion (the model's
# to_dict) after every change. workshop.gd decides when it may open (never in play) and
# routes the keys; this layer only shows and edits.
#
#   Pick a piece to put it in a socket; pick a seated piece to take it out, or press U
#   (pad Y) to empty both. One piece works on its own and SPIL-9 wears it (COMPANION-GROWS).
#   A third piece, or a second of one family, is refused with one line.
#   Keys: W/S or the d-pad move, Enter or pad A picks, 1-6 pick directly, Esc or pad B
#   leaves.

signal closed

const LAYER := 6
const MAX_ROWS := 6
const LINE_FULL := "Both sockets are full."
const LINE_FAMILY := "Two of one family will not fit."
const LINE_NONE := "No companion in this run."

var game
var model := Companion.new()
# The pieces seated so far, at most two, always a set the model accepts.
var staged: Array[String] = []
var cursor := 0
var message := ""

var _open := false
var _veil: ColorRect
var _column: VBoxContainer
var _title: Label
var _sockets: Array[Label] = []
var _rows: VBoxContainer
var _effect: Label
var _line: Label
var _hint: Label


func setup(game_ref) -> void:
	game = game_ref
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_veil = ColorRect.new()
	_veil.color = Color(Palette.CHARCOAL, 0.84)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 14)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_title = UiDraw.label(40, Palette.AMBER)
	_title.text = "COMPANION"
	_column.add_child(_title)
	for i in Companion.SOCKETS:
		var socket := UiDraw.label(24, Palette.SAND)
		_sockets.append(socket)
		_column.add_child(socket)
	_rows = VBoxContainer.new()
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_rows)
	_effect = UiDraw.label(20, Palette.SAND)
	_column.add_child(_effect)
	_line = UiDraw.label(20, Palette.AMBER)
	_column.add_child(_line)
	_hint = UiDraw.label(18, Color(Palette.SAND, 0.7))
	_hint.text = "U empties. Esc leaves."
	_column.add_child(_hint)


func is_open() -> bool:
	return _open


# Loads the run's companion. False, panel shut, when the run has none (run.companion {}).
func open() -> bool:
	if _open:
		return true
	var doc: Dictionary = game.run.companion
	if doc.is_empty() or not model.from_dict(doc):
		return false
	staged.assign(model.sockets)
	cursor = 0
	message = ""
	_open = true
	visible = true
	_rebuild()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	closed.emit()


# ---- Edits ----

# Seats the piece at index i of the owned list, or takes it out when it is already seated.
func pick(i: int) -> void:
	if not _open or i < 0 or i >= model.owned.size():
		return
	cursor = i
	var id: String = model.owned[i]
	if staged.has(id):
		staged.erase(id)
		_seat_staged()
		message = ""
	elif staged.size() >= Companion.SOCKETS:
		message = LINE_FULL
	elif staged.size() == 1 and Companion.family_of(staged[0]) == Companion.family_of(id):
		message = LINE_FAMILY
	else:
		staged.append(id)
		message = ""
		if model.assemble(staged) != "":
			staged.erase(id)
			_seat_staged()
			message = LINE_FAMILY
	_commit()


func _seat_staged() -> void:
	if staged.is_empty():
		model.unassemble()
	else:
		model.assemble(staged)


# Both sockets empty; the owned pile stays as it is.
func empty_sockets() -> void:
	if not _open:
		return
	staged.clear()
	model.unassemble()
	message = ""
	_commit()


func _commit() -> void:
	game.run.companion = model.to_dict()
	_rebuild()


# ---- Keys and the pad ----

func handle(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_U:
				empty_sockets()
				return true
			KEY_W:
				step(-1)
				return true
			KEY_S:
				step(1)
				return true
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				pick(event.physical_keycode - KEY_1)
				return true
			KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6:
				pick(event.physical_keycode - KEY_KP_1)
				return true
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		empty_sockets()
		return true
	if event.is_action_pressed("ui_cancel"):
		close()
		return true
	if event.is_action_pressed("ui_up"):
		step(-1)
		return true
	if event.is_action_pressed("ui_down"):
		step(1)
		return true
	if event.is_action_pressed("ui_accept"):
		pick(cursor)
		return true
	return event is InputEventKey or event is InputEventJoypadButton


func step(direction: int) -> void:
	if not _open or model.owned.is_empty():
		return
	cursor = clampi(cursor + direction, 0, model.owned.size() - 1)
	_rebuild()


# ---- Drawing ----

func _rebuild() -> void:
	for i in Companion.SOCKETS:
		_sockets[i].text = "Socket %d: %s" % [i + 1, _name_of(staged[i]) if i < staged.size() else "empty"]
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var count := mini(model.owned.size(), MAX_ROWS)
	for i in count:
		var id: String = model.owned[i]
		var row := ChoiceButton.new("piece", "key_%d" % (i + 1), _name_of(id))
		row.pressed.connect(pick.bind(i))
		row.mouse_entered.connect(func(): cursor = i)
		_rows.add_child(row)
	_focus_cursor.call_deferred()
	_effect.text = String(Companion._row(model.owned[cursor]).get("effect", "")) if cursor < model.owned.size() else ""
	_line.text = message


func _focus_cursor() -> void:
	var rows := _rows.get_children().filter(func(r): return not r.is_queued_for_deletion())
	if _open and cursor < rows.size() and rows[cursor].is_inside_tree():
		rows[cursor].grab_focus()


func _name_of(id: String) -> String:
	return String(Companion._row(id).get("name", id))


# The words on screen, one per line, for tests and the layout checks.
func screen_text() -> String:
	var lines := PackedStringArray([_title.text])
	for socket in _sockets:
		lines.append(socket.text)
	for row in _rows.get_children():
		lines.append(row.text)
	for label in [_effect, _line, _hint]:
		if label.text != "":
			lines.append(label.text)
	return "\n".join(lines)
