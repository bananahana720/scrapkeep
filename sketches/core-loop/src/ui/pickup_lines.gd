extends Control

const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")


const FONT := UiTokens.HEADING
const ROW := 40.0
const RISE := float(UiTokens.GAP_M)
const SLAM := 0.08
const SWELL := 1.15
const FADE := 0.25
const OUTLINE := 6
const WIDTH := 480.0

var lines: Array = []


func _init() -> void:
	name = "PickupLines"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_line(words: String, tint: Color, row: int, life: float) -> void:
	for line in lines:
		if int(line[2]) == row:
			lines.erase(line)
			break
	lines.append([words, tint, row, 0.0, life])
	queue_redraw()


func layout(size_now: Vector2, rows: int) -> void:
	var bottom := ScreenRegions.rect("bottom", size_now)
	size = Vector2(WIDTH, ROW * rows + RISE)
	position = Vector2(float(UiTokens.GAP_L), bottom.position.y - size.y - float(UiTokens.GAP_XS))


func step(delta: float) -> void:
	for line in lines:
		line[3] = float(line[3]) + delta
	lines = lines.filter(func(line): return float(line[3]) < float(line[4]))
	queue_redraw()


func showing() -> bool:
	return not lines.is_empty()


func rect() -> Rect2:
	if not visible or not showing():
		return Rect2()
	var font := UiFonts.bold()
	var wide := 0.0
	for line in lines:
		wide = maxf(wide, font.get_string_size(String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT).x * SWELL)
	return Rect2(position, Vector2(maxf(size.x, wide + OUTLINE), size.y))


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if visible:
		for line in lines:
			out.append(String(line[0]))
	return out


func _draw() -> void:
	var font := UiFonts.bold()
	for line in lines:
		var age: float = line[3]
		var life: float = line[4]
		var t := clampf(age / life, 0.0, 1.0)
		var leave := clampf((age - (life - FADE)) / FADE, 0.0, 1.0)
		var scale_now := 1.0 if UiTokens.reduced_motion or age >= SLAM else lerpf(SWELL, 1.0, age / SLAM)
		var lift := 0.0 if UiTokens.reduced_motion else RISE * t
		var base := size.y - ROW * int(line[2]) - lift - font.get_descent(FONT)
		var px := int(round(FONT * scale_now))
		var at := Vector2(0.0, base)
		var tint: Color = line[1]
		draw_string_outline(font, at, String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, OUTLINE, Color(UiTokens.INK, 1.0 - leave))
		draw_string(font, at, String(line[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(tint, FlashGuard.info(1.0 - leave)))
