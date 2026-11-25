extends Control

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const ChoiceButton := preload("res://src/ui/choice_button.gd")
const TreeCard := preload("res://src/ui/tree_card.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const PickQuiet := preload("res://src/ui/pick_quiet.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const Parts := preload("res://src/build/parts.gd")
const Icons := preload("res://src/ui/icons.gd")


signal chosen(index: int)
signal later

const FADE_IN := 0.28
const FADE_OUT := 0.22
const DROP := 26.0
const STAGGER := 0.06
const POP := 1.12
const CARD_GAP := 36.0
const PART_ICONS := 6
const PART_ICON := 26.0
const HEADING := "Rig your kit. Pick one."
const HELD := "Paused"
const TAKEN_TOAST := "%s taken"

var depth := 0
var _veil: ColorRect
var _column: VBoxContainer
var _heading: Label
var _held_line: Label
var _hidden: Array = []
var _taken_names: Array = []
var _offered: Array = []
var _row: HBoxContainer
var _later: Button
var _parts: Button
var _part_icons: HBoxContainer
var _foot: HBoxContainer
var _tween: Tween
var _open := false
var _pad_ready := false
var _generation := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_veil = ColorRect.new()
	_veil.color = Color(Palette.CHARCOAL, 0.72)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_column = VBoxContainer.new()
	_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 24)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_heading = Label.new()
	_heading.text = HEADING
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_override("font", UiFonts.bold())
	_heading.add_theme_font_size_override("font_size", UiTokens.HEADING)
	_heading.add_theme_color_override("font_color", Palette.SAND)
	_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_heading)
	_held_line = Label.new()
	_held_line.text = HELD
	_held_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_held_line.add_theme_font_override("font", UiFonts.bold())
	_held_line.add_theme_font_size_override("font_size", UiTokens.BODY)
	_held_line.add_theme_color_override("font_color", Palette.AMBER)
	_held_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_held_line)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(CARD_GAP))
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_row)
	_foot = HBoxContainer.new()
	_foot.alignment = BoxContainer.ALIGNMENT_CENTER
	_foot.add_theme_constant_override("separation", int(CARD_GAP))
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_foot)
	_parts = BuildReadout.new()
	_parts.text = ""
	_parts.accessibility_name = "Parts"
	_parts.tooltip_text = TreeCard.depth_sentence()
	_parts.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_parts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_part_icons = HBoxContainer.new()
	_part_icons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_part_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_part_icons.add_theme_constant_override("separation", UiTokens.GAP_XS)
	_part_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_parts.add_child(_part_icons)
	_parts.visible = false
	_foot.add_child(_parts)
	_later = ChoiceButton.new("later", "key_esc", "Later")
	_later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_later.pressed.connect(func(): later.emit())
	_later.mouse_entered.connect(func():
		if not _later.disabled:
			_later.grab_focus())
	_foot.add_child(_later)


func _ready() -> void:
	var host = get_parent()
	if host != null and host.get("game") != null:
		host.game.events.tree_picked.connect(_on_picked)


func is_open() -> bool:
	return _open


func held_text() -> String:
	return _held_line.text if _held_line.is_visible_in_tree() else ""


func cards() -> Array:
	return _row.get_children().filter(func(c): return not c.is_queued_for_deletion())


func later_button() -> Button:
	return _later


func parts_button() -> Button:
	return _parts


func open(class_id: String, pick_depth: int, nodes: Array, path: Array, color: Color) -> void:
	_generation += 1
	_open = true
	_pad_ready = false
	depth = pick_depth
	visible = true
	_offered = nodes
	if _hidden.is_empty():
		_hidden = PickQuiet.hush(get_parent())
		_quiet_host(true)
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for i in nodes.size():
		var card := TreeCard.new(nodes[i], "key_%d" % (i + 1), color, pick_depth, _world_one(), _shell(), TreeCard.WorldOneCards.SET_PIECE_LINES, class_id)
		card.pressed.connect(func(): chosen.emit(i))
		_row.add_child(card)
	_show_parts(pick_depth)
	_set_live(true)
	var first: Array = cards()
	if not first.is_empty():
		first[0].grab_focus()
	_play_in()


func _show_parts(pick_depth: int) -> void:
	for child in _part_icons.get_children():
		_part_icons.remove_child(child)
		child.queue_free()
	var held := _held_parts()
	_parts.visible = pick_depth > 1 and not held.is_empty()
	if not _parts.visible:
		return
	for id in held.slice(0, PART_ICONS):
		var icon_id := Parts.icon_of(String(id))
		var icon := TextureRect.new()
		icon.texture = Icons.texture(icon_id)
		icon.modulate = Icons.tint(icon_id, Palette.SAND)
		icon.custom_minimum_size = Vector2(PART_ICON, PART_ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_part_icons.add_child(icon)
	if held.size() > PART_ICONS:
		var more := Label.new()
		more.text = "+%d" % (held.size() - PART_ICONS)
		more.add_theme_font_override("font", UiFonts.bold())
		more.add_theme_font_size_override("font_size", UiTokens.CAPTION)
		more.add_theme_color_override("font_color", Palette.SAND)
		more.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_part_icons.add_child(more)
	var shown := mini(held.size(), PART_ICONS) + (1 if held.size() > PART_ICONS else 0)
	_parts.custom_minimum_size = Vector2(maxf(UiTokens.TARGET, 20.0 + shown * (PART_ICON + 6.0)), maxf(UiTokens.TARGET, PART_ICON + 18.0))


func _held_parts() -> Array:
	var host = get_parent()
	if host == null or host.get("game") == null or host.game.get("run") == null:
		return []
	return host.game.run.parts


func _world_one() -> bool:
	var host = get_parent()
	if host == null or host.get("game") == null:
		return false
	var game = host.game
	return game.tuning != null and game.tuning.world_one()


func _shell() -> bool:
	var host = get_parent()
	if host == null or host.get("game") == null:
		return false
	var game = host.game
	return game.tuning != null and game.tuning.option("hotwire_shell") == "on"


func _exit_tree() -> void:
	if not _hidden.is_empty():
		PickQuiet.restore(_hidden)
		_hidden = []
		_quiet_host(false)


func _quiet_host(on: bool) -> void:
	var host = get_parent()
	if host != null and host.has_method("quiet"):
		host.quiet(on)


func close(chosen_index := -1) -> void:
	if not _open:
		return
	_generation += 1
	_open = false
	_set_live(false)
	PickQuiet.restore(_hidden)
	_quiet_host(false)
	_hidden = []
	_play_out(chosen_index)


func _on_picked(_class_id: String, node_id: String, _depth: int) -> void:
	if not _open:
		return
	for card in cards():
		if card.node_id() == node_id:
			card.mark_taken()
			_taken_names.append(String(card.node.get("name", "")))


func _flush_taken_toasts() -> void:
	var names := _taken_names
	_taken_names = []
	var host = get_parent()
	var hud = host.get("game").get("hud") if host != null and host.get("game") != null else null
	if hud == null:
		return
	if names.is_empty():
		return
	hud.toast(TAKEN_TOAST % ", ".join(names), Palette.SAND, "diamond", 3)


func focused_index() -> int:
	var list := cards()
	for i in list.size():
		if list[i].has_focus():
			return i
	return -1


func step_focus(direction: int) -> void:
	var list := cards()
	if list.is_empty() or not _open:
		return
	var at := focused_index()
	var next := clampi((0 if at < 0 else at) + direction, 0, list.size() - 1)
	if at < 0:
		next = 0 if direction >= 0 else list.size() - 1
	list[next].grab_focus()
	_pad_ready = true


func confirm() -> void:
	if not _open:
		return
	if _later.has_focus():
		later.emit()
		return
	var at := focused_index()
	chosen.emit(0 if at < 0 else at)


func confirm_pad() -> void:
	if not _open:
		return
	if not _pad_ready:
		_pad_ready = true
		var list := cards()
		if focused_index() < 0 and not _later.has_focus() and not list.is_empty():
			list[0].grab_focus()
		return
	confirm()


func _set_live(live: bool) -> void:
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
	var buttons: Array = cards()
	buttons.append(_later)
	buttons.append(_parts)
	for button in buttons:
		(button as BaseButton).disabled = not live
		(button as Control).mouse_filter = Control.MOUSE_FILTER_STOP if live else Control.MOUSE_FILTER_IGNORE
		if not live and (button as Control).has_focus():
			(button as Control).release_focus()


func _play_in() -> void:
	if _tween != null:
		_tween.kill()
	_veil.modulate.a = maxf(_veil.modulate.a, 0.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_veil, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_heading.modulate.a = 0.0
	_tween.tween_property(_heading, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_foot.modulate.a = 0.0
	_tween.tween_property(_foot, "modulate:a", 1.0, FADE_IN).set_delay(STAGGER * 2.0)
	var list := cards()
	for i in list.size():
		var card: Control = list[i]
		card.modulate.a = 0.0
		card.scale = Vector2.ONE
		_tween.tween_property(card, "modulate:a", 1.0, FADE_IN).set_delay(STAGGER * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_method(func(v: float): _nudge(card, v), -DROP, 0.0, FADE_IN).set_delay(STAGGER * i).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _nudge(card: Control, offset: float) -> void:
	if is_instance_valid(card):
		card.position.y = offset


func _play_out(chosen_index: int) -> void:
	if _tween != null:
		_tween.kill()
	var generation := _generation
	_tween = create_tween().set_parallel(true)
	var list := cards()
	for i in list.size():
		var card: Control = list[i]
		_nudge(card, 0.0)
		if i == chosen_index:
			var pop := 1.0 if UiTokens.reduced_motion else POP
			_tween.tween_property(card, "scale", Vector2.ONE * pop, FADE_OUT * 0.45).set_trans(UiTokens.hand(UiTokens.Hand.KEEPER).trans).set_ease(Tween.EASE_OUT)
			_tween.tween_property(card, "modulate:a", 0.0, FADE_OUT).set_delay(FADE_OUT * 0.45).set_ease(Tween.EASE_IN)
		else:
			_tween.tween_property(card, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_veil, "modulate:a", 0.0, FADE_OUT * 1.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_heading, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	_tween.tween_property(_foot, "modulate:a", 0.0, FADE_OUT).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func():
		if generation == _generation and not _open:
			visible = false
			_flush_taken_toasts())
