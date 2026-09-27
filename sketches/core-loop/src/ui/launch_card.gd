extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The stage card: the stage's icon and name, faded in over the launch and out after the
# drop. It only draws: it takes no input and never pauses anything, so the ball keeps
# every bit of the speed it launched with (principle 1).

const ICON := 44.0
const FONT := 32
const GAP := 14.0
const FADE_IN := 0.25
const HOLD := 1.4
const FADE_OUT := 0.4

var icon_id := ""
var title := ""
var color := Color.WHITE
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0


func extent() -> Vector2:
	return Vector2(ICON + GAP + UiDraw.width(title, FONT), ICON + 8.0)


func showing() -> bool:
	return visible


func show_card(icon: String, text: String, tint: Color) -> void:
	icon_id = icon
	title = text
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
		show_card(icon_id, title, color)


func drawn_words() -> PackedStringArray:
	return PackedStringArray([title]) if visible else PackedStringArray()


func _draw() -> void:
	var w := extent().x
	var x := (size.x - w) * 0.5
	var mid := size.y * 0.5
	draw_texture_rect(Icons.texture(icon_id), Rect2(Vector2(x, mid - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint(icon_id, color))
	UiDraw.text(self, x + ICON + GAP, mid, title, FONT, color)
	draw_line(Vector2(x, size.y - 1.0), Vector2(x + w, size.y - 1.0), Color(color, 0.6), 2.0)
