extends RefCounted

const Icons := preload("res://src/core/icons.gd")
const UiTokens := preload("res://src/core/ui_tokens.gd")
const UiFonts := preload("res://src/core/ui_fonts.gd")


const MOUSE := ["key_lmb", "key_rmb"]
const LABELS := {"key_ctrl": "Ctrl", "key_space": "Space", "key_shift": "Shift", "key_tab": "Tab",
	"pad_a": "A", "pad_b": "B", "pad_x": "X", "pad_y": "Y", "pad_lb": "LB", "pad_rb": "RB",
	"pad_lt": "LT", "pad_rt": "RT", "pad_ls": "L", "pad_rs": "R", "pad_start": "Start", "pad_back": "Back",
	"pad_btn": "Pad", "key_mmb": "MMB", "key_mb4": "MB4", "key_mb5": "MB5", "key_bind": "Bind",
	"key_comma": ",", "key_period": ".", "key_slash": "/", "key_semicolon": ";",
	"pad_dl": "D-pad left", "pad_du": "D-pad up", "pad_dr": "D-pad right", "pad_dd": "D-pad down"}
const PAD_ROUND := ["pad_a", "pad_b", "pad_x", "pad_y", "pad_ls", "pad_rs"]
const PAD := 7.0
const DPAD := {"pad_dl": Vector2.LEFT, "pad_du": Vector2.UP, "pad_dr": Vector2.RIGHT, "pad_dd": Vector2.DOWN}


static func is_mouse(key: String) -> bool:
	return key in MOUSE


static func from_svg(key: String) -> bool:
	return is_mouse(key)


static func label(key: String) -> String:
	return LABELS.get(key, key.trim_prefix("key_").to_upper())


const LETTER := 0.58
const ROOM := 5.0
const MIN_H := UiTokens.CAPTION + ROOM


static func cap_height(height: float) -> float:
	return maxf(height, MIN_H)


static func font_size(height: float) -> int:
	return maxi(UiTokens.CAPTION, int(height * LETTER))


static func size_of(key: String, height := 24.0) -> Vector2:
	if not is_mouse(key) and not DPAD.has(key):
		height = cap_height(height)
	if is_mouse(key):
		return Vector2(height * 0.8, height)
	if key in PAD_ROUND or DPAD.has(key):
		return Vector2(height, height)
	var w := UiFonts.width(label(key), font_size(height))
	return Vector2(maxf(height, w + PAD * 2.0), height)


static func draw(canvas: CanvasItem, at: Vector2, key: String, color: Color, height := 24.0) -> Rect2:
	var size := size_of(key, height)
	var rect := Rect2(at - size * 0.5, size)
	if not is_mouse(key) and not DPAD.has(key):
		height = cap_height(height)
	# Godot's SVG importer drops <text> elements, so key glyphs draw in code instead of SVG.
	if from_svg(key):
		var side := height
		canvas.draw_texture_rect(Icons.texture(key), Rect2(at - Vector2(side, height) * 0.5, Vector2(side, height)), false, Icons.tint(key, color))
		return rect
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiTokens.INK, UiTokens.PLATE_ALPHA)
	box.border_color = color
	box.set_border_width_all(2)
	box.border_width_bottom = 4
	box.set_corner_radius_all(int(height * 0.5) if key in PAD_ROUND else int(height * 0.2))
	canvas.draw_style_box(box, rect)
	if DPAD.has(key):
		_draw_dpad(canvas, at, DPAD[key], color, height)
		return rect
	var fs := font_size(height)
	var text := label(key)
	var font := UiFonts.bold()
	var baseline := at.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - 1.0
	canvas.draw_string(font, Vector2(at.x - UiFonts.width(text, fs) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return rect


static func _draw_dpad(canvas: CanvasItem, at: Vector2, lit: Vector2, color: Color, height: float) -> void:
	var arm := height * 0.18
	var lit_arm := height * 0.32
	var reach := height * 0.38
	var dim := Color(color, 0.18)
	canvas.draw_rect(Rect2(at - Vector2(reach, arm * 0.5), Vector2(reach * 2.0, arm)), dim)
	canvas.draw_rect(Rect2(at - Vector2(arm * 0.5, reach), Vector2(arm, reach * 2.0)), dim)
	var tip := at + lit * reach
	var across := Vector2(lit.y, lit.x).abs()
	canvas.draw_rect(Rect2(at.min(tip) - across * lit_arm * 0.5, lit.abs() * reach + across * lit_arm), color)


static func words(key: String) -> PackedStringArray:
	return PackedStringArray() if is_mouse(key) or DPAD.has(key) else PackedStringArray([label(key)])
