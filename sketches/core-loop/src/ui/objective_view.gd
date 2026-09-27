extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The objective, top centre: its icon (ringed by how much of the Warden is broken), at
# most five words, and the bonus-core pips. Under it, while a plated lock stands, two
# bars compare punch with plating: a notch marks the plating on both, so "can I break
# it" reads as whether the punch bar passes the notch, not as two numbers.

const ICON := 34.0
const FONT := 19
const GAP := 12.0
const PIP := 16.0
const PIP_STEP := 20.0
const BAR_W := 240.0
const BAR_H := 7.0
const BAR_GAP := 4.0
const BAR_ICON := 13.0
const HEADROOM := 1.15

var icon_id := ""
var words := ""
var color := Color.WHITE
var progress := -1.0
var punch := -1.0
var plating := -1.0
var cores := 0
var core_cap := 2


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_objective(icon: String, text: String, tint: Color, broken := -1.0, punch_now := -1.0, plating_now := -1.0,
		core_count := 0, cap := 2) -> void:
	icon_id = icon
	words = text
	color = tint
	progress = broken
	punch = punch_now
	plating = plating_now
	cores = core_count
	core_cap = cap
	custom_minimum_size = extent()
	queue_redraw()


func shows_bars() -> bool:
	return punch >= 0.0 and plating > 0.0


func extent() -> Vector2:
	var h := ICON
	if shows_bars():
		h += BAR_GAP * 2.0 + BAR_H * 2.0 + BAR_GAP
	return Vector2(maxf(_row_width(), BAR_W + BAR_ICON + 6.0), h)


func _row_width() -> float:
	var w := ICON + GAP + UiDraw.width(words, FONT) + GAP + core_cap * PIP_STEP
	if cores > core_cap:
		w += UiDraw.width(_extra(), 18) + 4.0
	return w


func _extra() -> String:
	return "+%d" % (cores - core_cap)


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if words != "":
		out.append(words)
	if cores > core_cap:
		out.append(_extra())
	return out


# The pips this many cores fill: one slot per gate tier they can buy.
static func pip_slots(core_count: int, cap: int) -> Array[bool]:
	var out: Array[bool] = []
	for i in cap:
		out.append(i < core_count)
	return out


func _draw() -> void:
	if words == "":
		return
	var x := (size.x - _row_width()) * 0.5
	var mid := ICON * 0.5
	var icon_rect := Rect2(Vector2(x, 0.0), Vector2(ICON, ICON))
	draw_texture_rect(Icons.texture(icon_id), icon_rect.grow(-4.0), false, Icons.tint(icon_id, color))
	if progress >= 0.0:
		draw_arc(icon_rect.get_center(), ICON * 0.52, 0.0, TAU, 32, Color(color, 0.22), 3.0)
		if progress > 0.0:
			draw_arc(icon_rect.get_center(), ICON * 0.52, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 32, color, 3.0)
	x += ICON + GAP
	x += UiDraw.text(self, x, mid, words, FONT, color) + GAP
	var core_color := EventKinds.color("core_gained")
	var diamond := Icons.shape("diamond")
	var slots := pip_slots(cores, core_cap)
	for i in slots.size():
		var rect := Rect2(Vector2(x + i * PIP_STEP, mid - PIP * 0.5), Vector2(PIP, PIP))
		draw_texture_rect(diamond, rect, false, core_color if slots[i] else Color(core_color, 0.25))
	if cores > core_cap:
		UiDraw.text(self, x + core_cap * PIP_STEP + 2.0, mid, _extra(), 18, core_color)
	if shows_bars():
		_draw_bars()


func _draw_bars() -> void:
	var span := maxf(punch, plating) * HEADROOM
	var left := (size.x - (BAR_W + BAR_ICON + 6.0)) * 0.5 + BAR_ICON + 6.0
	var y := ICON + BAR_GAP * 2.0
	var breaks := punch >= plating
	var punch_color := EventKinds.color("beacon_unsealed") if breaks else EventKinds.color("enemy_struck")
	var plating_color := EventKinds.color("strike_deflected")
	var punch_rect := Rect2(Vector2(left, y), Vector2(BAR_W, BAR_H))
	var plating_rect := Rect2(Vector2(left, y + BAR_H + BAR_GAP), Vector2(BAR_W, BAR_H))
	draw_texture_rect(Icons.texture("cat_damage"), Rect2(Vector2(left - BAR_ICON - 5.0, y - 3.0), Vector2(BAR_ICON, BAR_ICON)), false, Icons.tint("cat_damage", punch_color))
	draw_texture_rect(Icons.texture("cat_defense"), Rect2(Vector2(left - BAR_ICON - 5.0, plating_rect.position.y - 3.0), Vector2(BAR_ICON, BAR_ICON)), false, Icons.tint("cat_defense", plating_color))
	UiDraw.bar(self, punch_rect, punch / span, punch_color)
	UiDraw.bar(self, plating_rect, plating / span, Color(plating_color, 0.55))
	var plate_end := plating_rect.position.x + BAR_W * plating / span
	var hatch := plating_rect.position.x + 3.0
	while hatch < plate_end:
		draw_line(Vector2(hatch, plating_rect.end.y), Vector2(minf(hatch + BAR_H, plate_end), plating_rect.position.y), plating_color, 1.2)
		hatch += 6.0
	draw_line(Vector2(plate_end, punch_rect.position.y - 3.0), Vector2(plate_end, plating_rect.end.y + 3.0), Color.WHITE, 2.0)
	if breaks:
		var tip := Vector2(punch_rect.position.x + BAR_W * punch / span, punch_rect.get_center().y)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(7.0, 0.0), tip + Vector2(0.0, -5.0), tip + Vector2(0.0, 5.0)]), punch_color)
