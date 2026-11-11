extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The objective, top centre: its glyph (ringed by how much of the Warden is broken), at
# most five words from objectives.gd and, while the Warden is still to be found, the
# distance to it in whole metres. A finished goal shows in the same place with a tick where the
# glyph was (a lost one with a cross), drawn here so it needs no glyph of its own.

const ICON := 34.0
const FONT := UiTokens.BODY
const GAP := 12.0
const PLATE_PAD := 6.0
const PAST_STEP := 0.4

var icon_id := ""
var words := ""
var color := Color.WHITE
var progress := -1.0
var metres := -1
# "" for a goal, "won" or "lost" for the done row.
var done := ""
# The live step of a loop row (objectives.gd STEPS): the steps before it are drawn dim.
var step := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_objective(icon: String, text: String, tint: Color, broken := -1.0, distance := -1, finished := "", live := 0) -> void:
	# Called every frame by the HUD: shape and redraw only when a shown value changed.
	if icon == icon_id and text == words and tint == color and broken == progress and distance == metres and finished == done and live == step:
		return
	done = finished
	step = live
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
	if done != "":
		_draw_done(icon_rect)
	else:
		draw_texture_rect(Icons.texture(icon_id), icon_rect.grow(-4.0), false, Icons.tint(icon_id, color))
	if progress >= 0.0:
		draw_arc(icon_rect.get_center(), ICON * 0.52, 0.0, TAU, 32, Color(color, 0.22), 3.0)
		if progress > 0.0:
			draw_arc(icon_rect.get_center(), ICON * 0.52, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 32, color, 3.0)
	x += ICON + GAP
	var parts := words.split(", ")
	for i in parts.size():
		x += UiDraw.text(self, x, mid, parts[i] + (", " if i < parts.size() - 1 else ""), FONT, Color(color, PAST_STEP) if i < step else color)
	x += GAP
	if metres >= 0:
		UiDraw.text(self, x, mid, distance_text(), FONT, color, true)


# The done row's mark: a tick for a goal finished, a cross for one lost, inked like the words.
func _draw_done(rect: Rect2) -> void:
	var c := rect.get_center()
	var r := ICON * 0.3
	var strokes: Array = [PackedVector2Array([c + Vector2(-r, 0.0), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r, -r * 0.7)])]
	if done == "lost":
		strokes = [PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, r)]), PackedVector2Array([c + Vector2(-r, r), c + Vector2(r, -r)])]
	for stroke in strokes:
		draw_polyline(stroke, UiDraw.OUTLINE, 8.0)
	for stroke in strokes:
		draw_polyline(stroke, color, 4.0)
