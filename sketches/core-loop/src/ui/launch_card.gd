extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The stage card: the stage's icon and name, faded in over the launch and out after the
# drop, with the stage's modifier (SI3) on a second line when it has one. It only draws: it takes no input and never pauses anything, so the ball keeps
# every bit of the speed it launched with (principle 1).

const ICON := 44.0
const FONT := 32
const LINE_FONT := 20
const LINE_GAP := 8.0
const GAP := 14.0
const FADE_IN := 0.25
const HOLD := 1.4
const FADE_OUT := 0.4

var icon_id := ""
var title := ""
var line := ""
var color := Color.WHITE
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func extent() -> Vector2:
	var w := ICON + GAP + UiDraw.width(title, FONT)
	if line.is_empty():
		return Vector2(w, ICON + 8.0)
	return Vector2(maxf(w, UiDraw.width(line, LINE_FONT)), ICON + 8.0 + LINE_GAP + LINE_FONT)


func showing() -> bool:
	return visible


func show_card(icon: String, text: String, tint: Color, subline := "") -> void:
	icon_id = icon
	title = text
	line = subline
	color = tint
	custom_minimum_size = extent()
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN * (1.0 - modulate.a))
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): visible = false)
	queue_redraw()


# Keeps a card that is already up on screen for another full hold.
func extend() -> void:
	if visible:
		show_card(icon_id, title, color, line)


func drawn_words() -> PackedStringArray:
	if not visible:
		return PackedStringArray()
	return PackedStringArray([title]) if line.is_empty() else PackedStringArray([title, line])


func _draw() -> void:
	var w := ICON + GAP + UiDraw.width(title, FONT)
	var x := (size.x - w) * 0.5
	var mid := (ICON + 8.0) * 0.5 if not line.is_empty() else size.y * 0.5
	draw_texture_rect(Icons.texture(icon_id), Rect2(Vector2(x, mid - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint(icon_id, color))
	UiDraw.text(self, x + ICON + GAP, mid, title, FONT, color)
	var rule_y := ICON + 7.0 if not line.is_empty() else size.y - 1.0
	draw_line(Vector2(x, rule_y), Vector2(x + w, rule_y), Color(color, 0.6), 2.0)
	if not line.is_empty():
		UiDraw.text(self, (size.x - UiDraw.width(line, LINE_FONT)) * 0.5, ICON + 8.0 + LINE_GAP + LINE_FONT * 0.5, line, LINE_FONT, color)
