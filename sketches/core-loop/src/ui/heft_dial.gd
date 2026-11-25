extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const Palette := preload("res://src/core/palette.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")


const ICON := 24.0
const RADIUS := 17.0
const GAP := 6.0
const FONT := UiTokens.BODY
const SWING := 9.0
const FLASH_SECONDS := 0.9

var classes := 5
var heft_class := 1
var progress := 0.0
var numeral := "I"
var color := Palette.AMBER
var needle := 0.0
var _flash := 0.0
var _flash_color := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ICON + GAP + RADIUS * 2.0 + GAP + UiDraw.width("VV", FONT), RADIUS * 2.0)
	size = custom_minimum_size


func set_reading(class_now: int, class_count: int, share: float, shown: String, tint: Color) -> void:
	heft_class = class_now
	classes = maxi(class_count, 2)
	progress = share
	numeral = shown
	color = tint


func target() -> float:
	return clampf((heft_class - 1 + progress) / float(classes - 1), 0.0, 1.0)


func flash(tint: Color) -> void:
	_flash_color = tint
	_flash = FLASH_SECONDS


func drawn_words() -> PackedStringArray:
	return PackedStringArray([numeral])


func _process(delta: float) -> void:
	needle = lerpf(needle, target(), 1.0 - exp(-SWING * delta))
	_flash = maxf(0.0, _flash - delta)
	queue_redraw()


func _draw() -> void:
	var tint := color.lerp(_flash_color, FlashGuard.info(_flash / FLASH_SECONDS)) if _flash > 0.0 else color
	var mid := size.y * 0.5
	draw_texture_rect(Icons.texture("res_heft"), Rect2(Vector2(0.0, mid - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint("res_heft", tint))
	var hub := Vector2(ICON + GAP + RADIUS, size.y - 3.0)
	draw_arc(hub, RADIUS, PI, TAU, 24, UiDraw.OUTLINE, 5.0)
	draw_arc(hub, RADIUS, PI, TAU, 24, Color(tint, 0.45), 2.5)
	for i in classes:
		var a := PI + PI * i / float(classes - 1)
		var dir := Vector2(cos(a), sin(a))
		draw_line(hub + dir * (RADIUS - 5.0), hub + dir * (RADIUS + 1.0), tint, 2.0)
	var angle := PI + PI * needle
	draw_line(hub, hub + Vector2(cos(angle), sin(angle)) * (RADIUS - 2.0), UiDraw.OUTLINE, 4.0)
	draw_line(hub, hub + Vector2(cos(angle), sin(angle)) * (RADIUS - 2.0), Palette.SAND, 2.0)
	draw_circle(hub, 3.0, Palette.SAND)
	UiDraw.text(self, hub.x + RADIUS + GAP, mid, numeral, FONT, tint)
