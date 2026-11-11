extends CanvasLayer

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Companion := preload("res://src/core/companion.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# The companion assembly screen, a calm menu between attempts. It lists the pieces the run
# owns, shows the two sockets and writes the result back to run.companion (the model's
# to_dict) after every change. workshop.gd decides when it may open (never in play) and
# routes the keys; this layer only shows and edits.
#
#   Pick a piece to put it in a socket; pick a seated piece to take it out, or press the
#   empty key (U, pad Y) to empty both. One piece works on its own and SPIL-9 wears it
#   (COMPANION-GROWS). A third piece, or a second of one family, is refused with one line.
#   Keys: W/S or the d-pad move, Enter or pad A picks, 1-6 pick directly, Esc or pad B
#   leaves (the Back choice wears the Esc cap).
#
# No title and no socket text (ruling cx): the two sockets are drawn marks holding the
# piece's icon, an empty socket an empty ring, and the cap beside them with the cross icon
# empties both (U, pad Y: fixed keys, as before; the cap follows the device in hand).

signal closed

const LAYER := 6
const MAX_ROWS := 6
const LINE_FULL := "Both sockets are full."
const LINE_FAMILY := "One of each kind."
# One icon per piece, from the icon registry, so a socket mark says which piece sits in it.
const PIECE_ICONS := {"primer_coil": "cmp_primer_coil", "primer_mesh": "cmp_primer_mesh",
	"ram_prow": "cmp_ram_prow", "ram_spring": "cmp_ram_spring", "escape_vent": "cmp_escape_vent",
	"escape_rail": "cmp_escape_rail"}
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
var _marks: Control
var _rows: VBoxContainer
var _effect: Label
var _line: Label
var _back: ChoiceButton


func setup(game_ref) -> void:
	game = game_ref
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_veil = ColorRect.new()
	# Near solid: the screen behind (the title, a summary) must not read through the panel.
	_veil.color = Color(Palette.CHARCOAL, 0.96)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 12)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_marks = Marks.new(self)
	_column.add_child(_marks)
	_rows = VBoxContainer.new()
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_theme_constant_override("separation", 8)
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_rows)
	_effect = UiDraw.label(UiTokens.BODY, Palette.SAND)
	_column.add_child(_effect)
	_line = UiDraw.label(UiTokens.BODY, Palette.AMBER)
	_column.add_child(_line)
	_back = ChoiceButton.new("back", "key_esc", "Back")
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.custom_minimum_size.x = 260.0
	_back.pressed.connect(close)
	_column.add_child(_back)


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
	elif staged.size() >= game.run.companion_seats():
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
	_marks.queue_redraw()
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	var count := mini(model.owned.size(), MAX_ROWS)
	for i in count:
		var id: String = model.owned[i]
		var row := ChoiceButton.new("piece", "key_%d" % (i + 1), _name_of(id))
		row.icon = Icons.texture(PIECE_ICONS.get(id, "disc"))
		row.add_theme_constant_override("icon_max_width", 24)
		row.add_theme_constant_override("h_separation", 8)
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


# The icon id in each socket, "" for an empty one: what the two marks show. A core riding in
# SPIL-9 (run_state.stow_core) holds the last socket and shows as the core.
func socket_icons() -> Array[String]:
	var out: Array[String] = []
	var seats: int = game.run.companion_seats()
	for i in Companion.SOCKETS:
		if i >= seats:
			out.append("res_core")
		else:
			out.append(String(PIECE_ICONS.get(staged[i], "disc")) if i < staged.size() else "")
	return out


# The key glyph id the empty cap shows now, for the device in hand.
func empty_cap() -> String:
	return "pad_y" if Glyphs.is_pad() else "key_u"


# The pixels each row has for its icon beside the keycap and the name, for the layout checks.
func icon_room() -> Array[float]:
	var out: Array[float] = []
	for row in _rows.get_children():
		var words: float = row.get_theme_font("font").get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, row.get_theme_font_size("font_size")).x
		out.append(row.size.x - row.get_theme_stylebox("normal").get_minimum_size().x - words - float(row.get_theme_constant("h_separation")))
	return out


# The words on screen, one per line, for tests and the layout checks.
func screen_text() -> String:
	var lines := PackedStringArray()
	for row in _rows.get_children():
		lines.append(row.text)
	for label in [_effect, _line]:
		if label.text != "":
			lines.append(label.text)
	return "\n".join(lines)


# The two sockets and the empty cap, drawn: a dark disc ringed in sand holding the piece's
# icon (amber ring when filled), an empty ring when nothing sits there, then the cap with a
# cross that empties both. Nothing here is a word.
class Marks extends Control:
	const RADIUS := 34.0
	const GAP := 28.0
	var panel

	func _init(owner_panel) -> void:
		panel = owner_panel
		name = "SocketMarks"
		custom_minimum_size = Vector2(0.0, RADIUS * 2.0 + 16.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var icons: Array[String] = panel.socket_icons()
		var cap: String = panel.empty_cap()
		var cap_w := Keycap.size_of(cap, 30.0).x
		var total := icons.size() * RADIUS * 2.0 + (icons.size() - 1) * GAP + GAP * 1.5 + cap_w + 34.0
		var x := (size.x - total) * 0.5 + RADIUS
		var y := size.y * 0.5
		for icon in icons:
			var at := Vector2(x, y)
			if icon == "":
				draw_arc(at, RADIUS, 0.0, TAU, 40, Color(Palette.SAND, 0.35), 3.0, true)
			else:
				draw_circle(at, RADIUS, Color(Palette.CHARCOAL.darkened(0.35), 0.96))
				draw_arc(at, RADIUS, 0.0, TAU, 40, Palette.AMBER, 3.0, true)
				var side := RADIUS * 1.3
				draw_texture_rect(Icons.texture(icon), Rect2(at - Vector2(side, side) * 0.5, Vector2(side, side)), false, Icons.tint(icon, Palette.SAND))
			x += RADIUS * 2.0 + GAP
		x += GAP * 0.5 - RADIUS + cap_w * 0.5
		Keycap.draw(self, Vector2(x, y), cap, Palette.SAND, 30.0)
		x += cap_w * 0.5 + 8.0 + 13.0
		var side2 := 26.0
		draw_texture_rect(Icons.shape("cross"), Rect2(Vector2(x, y) - Vector2(side2, side2) * 0.5, Vector2(side2, side2)), false, Palette.SAND)
