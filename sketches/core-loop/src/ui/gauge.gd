extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# One HUD readout: an icon, an optional short label (a count, in mono digits) and an
# optional bar. Health is a tank gauge (a tick every quarter) and scrap a count. Below
# its warning share the gauge's edge turns iron oxide and pulses at 1 Hz.

const ICON := 26.0
const BAR_H := 12.0
const FONT := 22
const GAP := 8.0
const PULSE_HZ := 1.0
const TICKS := 4

var icon_id := ""
var color := Color.WHITE
var fraction := -1.0
var label := ""
var bar_width := 0.0
var ticks := false
var warn := false
var warn_color := Color.WHITE
var _clock := 0.0


func _init(icon := "", width_of_bar := 0.0, quarter_ticks := false) -> void:
	icon_id = icon
	bar_width = width_of_bar
	ticks = quarter_ticks
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = extent()
	size = custom_minimum_size


func set_reading(value: float, tint: Color, text := "", warning := false, warning_color := Color.WHITE) -> void:
	# Called every frame by the HUD: shape and redraw only when a shown value changed.
	if value == fraction and tint == color and text == label and warning == warn and warning_color == warn_color:
		return
	fraction = value
	color = tint
	label = text
	warn = warning
	warn_color = warning_color
	custom_minimum_size = extent()
	size = custom_minimum_size
	queue_redraw()


func extent() -> Vector2:
	var w := ICON + GAP
	if label != "":
		w += UiDraw.width(label, FONT, true) + GAP
	if bar_width > 0.0:
		w += bar_width
	return Vector2(w, ICON)


func drawn_words() -> PackedStringArray:
	return PackedStringArray([label]) if label != "" else PackedStringArray()


func _process(delta: float) -> void:
	var _bot_scope = preload("res://tools/bot_profile.gd").scope("src/ui/gauge.gd::_process")
	_clock += delta
	if warn:
		queue_redraw()


func _draw() -> void:
	var mid := size.y * 0.5
	draw_texture_rect(Icons.texture(icon_id), Rect2(Vector2(0.0, mid - ICON * 0.5), Vector2(ICON, ICON)), false, Icons.tint(icon_id, color))
	var x := ICON + GAP
	if label != "":
		x += UiDraw.text(self, x, mid, label, FONT, color, true) + GAP
	if bar_width <= 0.0 or fraction < 0.0:
		return
	var bar := Rect2(Vector2(x, mid - BAR_H * 0.5), Vector2(bar_width, BAR_H))
	UiDraw.bar(self, bar, fraction, color)
	if ticks:
		for i in range(1, TICKS):
			var tx := bar.position.x + bar.size.x * i / TICKS
			draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.position.y + BAR_H * 0.45), UiDraw.OUTLINE, 2.0)
	if warn:
		var beat := 0.5 + 0.5 * cos(_clock * TAU * PULSE_HZ)
		draw_rect(bar.grow(2.5), Color(warn_color, 0.35 + 0.65 * beat), false, 2.5)
