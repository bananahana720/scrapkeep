extends Button

const Palette := preload("res://src/core/palette.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ScrapFrame := preload("res://src/ui/scrap_frame.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")


const KEY_H := 28.0
const SLOT := 88.0
const NOTCH := 9.0
const WIDTH := 340.0
const HEIGHT := 390.0
const SKIP_PROMPT := "Take it or skip. No reroll."

var node := {}
var key := ""
var depth := 1
var color := Palette.SAND
var _name: Label
var _effect: Label
var _set_piece: Label
var _skip_prompt: Label
var _taken := false
var _lift := 0.0
var _serial := 0
var _slot: StyleBox


func _init(node_row := {}, key_id := "", class_color := Palette.SAND, node_depth := 1, world_one := false, shell := false, set_piece_table := WorldOneCards.SET_PIECE_LINES, pilot := "", offer_kind := UpgradeTree.OFFER_PAIR) -> void:
	node = node_row
	key = key_id
	color = ClassDef.screen_color(class_color)
	depth = node_depth
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accessibility_name = String(node.get("name", ""))
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	pivot_offset = custom_minimum_size * 0.5
	_serial = hash(String(node.get("id", node.get("name", ""))))
	add_theme_stylebox_override("normal", ClassCard.keeper_plate(Color(color, 0.7), _serial, 2))
	add_theme_stylebox_override("hover", ClassCard.keeper_plate(color, _serial, 4))
	add_theme_stylebox_override("pressed", ClassCard.keeper_plate(Palette.AMBER, _serial, 4))
	add_theme_stylebox_override("focus", ClassCard.keeper_plate(UiTokens.TEXT, _serial, 3, false))
	add_theme_stylebox_override("disabled", ClassCard.keeper_plate(Color(color, 0.3), _serial, 2))
	_slot = ScrapFrame.hand_plate(UiTokens.Hand.KEEPER, _serial + 1)
	_slot.border_width = 3.0
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 24.0 + SLOT + 26.0
	box.offset_left = 20.0
	box.offset_right = -20.0
	box.offset_bottom = -14.0
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_name = _text(String(node.get("name", "")), UiTokens.LABEL, color)
	box.add_child(_name)
	_effect = _text(WorldOneCards.effect_line(node, world_one, shell), UiTokens.BODY, Palette.SAND)
	box.add_child(_effect)
	var piece := WorldOneCards.set_piece_line(node, set_piece_table, pilot)
	_set_piece = _text(piece, UiTokens.BODY, Color(Palette.SAND, 0.85))
	_set_piece.visible = piece != ""
	box.add_child(_set_piece)
	_skip_prompt = _text(SKIP_PROMPT if offer_kind == UpgradeTree.OFFER_TAKE_OR_SKIP else "", UiTokens.BODY, Palette.AMBER)
	_skip_prompt.visible = offer_kind == UpgradeTree.OFFER_TAKE_OR_SKIP
	box.add_child(_skip_prompt)
	mouse_entered.connect(func():
		if not disabled:
			grab_focus())


func mark_taken() -> void:
	_taken = true
	add_theme_stylebox_override("disabled", ClassCard.keeper_plate(Palette.AMBER, _serial, 4))


func is_taken() -> bool:
	return _taken


func effect_text() -> String:
	return _effect.text


func set_piece_text() -> String:
	return _set_piece.text if _set_piece.visible else ""


func set_piece_visible() -> bool:
	return _set_piece.visible


func skip_prompt_text() -> String:
	return _skip_prompt.text if _skip_prompt.visible else ""


func skip_prompt_visible() -> bool:
	return _skip_prompt.visible


static func depth_rows() -> Array:
	var rows: Array = []
	var world := 1
	while true:
		var depth := UpgradeTree.depth_cap(world)
		rows.append({"world": world, "depth": depth})
		if depth == UpgradeTree.DEPTHS:
			break
		world += 1
	return rows


static func depth_sentence() -> String:
	var parts: Array = []
	for row in depth_rows():
		parts.append(("%d deep in world %d" if parts.is_empty() else "%d in world %d") % [row["depth"], row["world"]])
	return "Picks go " + ", ".join(parts) + "."


func depth_text() -> String:
	return depth_sentence()


func node_id() -> String:
	return String(node.get("id", ""))


func drawn_words() -> PackedStringArray:
	return Keycap.words(key)


func _text(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(delta: float) -> void:
	var up := 1.0 if (is_hovered() or has_focus()) and not disabled else 0.0
	_lift = move_toward(_lift, up, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var bright := UiTokens.TEXT if is_hovered() and not disabled else Palette.SAND
	Keycap.draw(self, Vector2(20.0 + Keycap.size_of(key, KEY_H).x * 0.5, 18.0 + KEY_H * 0.5), key, bright, KEY_H)
	var centre := Vector2(size.x * 0.5, 24.0 + SLOT * 0.5 - 6.0 * _lift)
	var rect := Rect2(centre - Vector2(SLOT, SLOT) * 0.5, Vector2(SLOT, SLOT))
	_slot.border_color = color if _lift > 0.5 else Palette.SAND
	draw_style_box(_slot, rect)
	var icon_id := String(node.get("icon", ""))
	var inset := rect.grow(-12.0)
	draw_texture_rect(Icons.texture(icon_id), inset, false, Icons.tint(icon_id, color))
	for i in depth:
		var x := rect.position.x + rect.size.x * 0.5 + (float(i) - (depth - 1) * 0.5) * (NOTCH + 4.0)
		draw_rect(Rect2(x - NOTCH * 0.5, rect.position.y - 5.0, NOTCH, 8.0), Palette.CHARCOAL)
		draw_rect(Rect2(x - NOTCH * 0.5 + 1.5, rect.position.y - 3.5, NOTCH - 3.0, 5.0), color)
