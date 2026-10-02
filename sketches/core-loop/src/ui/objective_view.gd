extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The objective, top centre: its glyph (ringed by how much of the Warden is broken), at
# most five words from objectives.gd and, while the Warden is still to be found, the
# distance to it in whole metres.

const ICON := 34.0
const FONT := 19
const GAP := 12.0
const PLATE_PAD := 6.0

var icon_id := ""
var words := ""
var color := Color.WHITE
var progress := -1.0
var metres := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_objective(icon: String, text: String, tint: Color, broken := -1.0, distance := -1) -> void:
	# Called every frame by the HUD: shape and redraw only when a shown value changed.
	if icon == icon_id and text == words and tint == color and broken == progress and distance == metres:
		return
	icon_id = icon
	words = text
	color = tint
	progress = broken
	metres = distance
	custom_minimum_size = extent()
	queue_redraw()


func extent() -> Vector2:
	return Vector2(_row_width(), ICON)


func distance_text() -> String:
	return "%dm" % metres if metres >= 0 else ""


func _row_width() -> float:
	var w := ICON + GAP + UiDraw.width(words, FONT)
	if metres >= 0:
		w += GAP + UiDraw.width(distance_text(), FONT, true)
	return w


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if words != "":
		out.append(words)
		if metres >= 0:
			out.append(distance_text())
	return out


func _draw() -> void:
	if words == "":
		return
	var plate_w := _row_width() + PLATE_PAD * 2.0
	UiDraw.panel(self, Rect2(Vector2((size.x - plate_w) * 0.5, -PLATE_PAD), Vector2(plate_w, ICON + PLATE_PAD * 2.0)))
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
	if metres >= 0:
		UiDraw.text(self, x, mid, distance_text(), FONT, color, true)
