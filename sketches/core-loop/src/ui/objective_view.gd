extends Control

const Icons := preload("res://src/ui/icons.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The objective, top centre: its glyph (ringed by how much of the Warden is broken), at
# most five words from objectives.gd and, while the Warden is still to be found, the
# distance to it in whole metres. A finished goal shows in the same place with a tick where the
# glyph was (a lost one with a cross), drawn here so it needs no glyph of its own. Under the goal,
# on the same plate, a quieter detour row (objectives.gd detour_shown): a smaller glyph, the
# detour's words and metres, all at UiTokens.QUIET_ALPHA, so it reads as on offer, never as the goal.

const ICON := 34.0
const FONT := UiTokens.BODY
const GAP := 12.0
const PLATE_PAD := 6.0
const PAST_STEP := 0.4
const DETOUR_ICON := 24.0
const DETOUR_GAP := float(UiTokens.GAP_S)

var icon_id := ""
var words := ""
var color := Color.WHITE
var progress := -1.0
var metres := -1
# "" for a goal, "won" or "lost" for the done row.
var done := ""
# The live step of a loop row (objectives.gd STEPS): the steps before it are drawn dim.
var step := 0
# The detour row: "" words for none.
var detour_icon := ""
var detour_words := ""
var detour_color := Color.WHITE
var detour_metres := -1


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


func set_detour(icon: String, text: String, tint: Color, distance := -1) -> void:
	if icon == detour_icon and text == detour_words and tint == detour_color and distance == detour_metres:
		return
	detour_icon = icon
	detour_words = text
	detour_color = tint
	detour_metres = distance
	custom_minimum_size = extent()
	queue_redraw()


func extent() -> Vector2:
	if not _detour_shown():
		return Vector2(_row_width(), ICON)
	return Vector2(maxf(_row_width(), _detour_width()), ICON + DETOUR_GAP + DETOUR_ICON)


func distance_text() -> String:
	return _metres_text(metres)


static func _metres_text(m: int) -> String:
	return "%dm" % m if m >= 0 else ""


func _row_width() -> float:
	var w := ICON + GAP + UiDraw.width(words, FONT)
	if metres >= 0:
		w += GAP + UiDraw.width(distance_text(), FONT, true)
	return w


func _detour_shown() -> bool:
	return words != "" and detour_words != ""


func _detour_width() -> float:
	var w := DETOUR_ICON + GAP + UiDraw.width(detour_words, FONT)
	if detour_metres >= 0:
		w += GAP + UiDraw.width(_metres_text(detour_metres), FONT, true)
	return w


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if words != "":
		out.append(words)
		if metres >= 0:
			out.append(distance_text())
	if _detour_shown():
		out.append(detour_words)
		if detour_metres >= 0:
			out.append(_metres_text(detour_metres))
	return out


func _draw() -> void:
	if words == "":
		return
	var box := extent()
	var plate_w := box.x + PLATE_PAD * 2.0
	UiDraw.panel(self, Rect2(Vector2((size.x - plate_w) * 0.5, -PLATE_PAD), Vector2(plate_w, box.y + PLATE_PAD * 2.0)))
	if _detour_shown():
		_draw_detour(ICON + DETOUR_GAP)
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


# The detour row's ink: its colour stepped back to QUIET_ALPHA, so it reads as on offer, not as the goal.
func detour_ink() -> Color:
	return Color(detour_color, detour_color.a * UiTokens.QUIET_ALPHA)


# The detour row at `top`, centred under the goal and quieter than it.
func _draw_detour(top: float) -> void:
	var quiet := detour_ink()
	var x := (size.x - _detour_width()) * 0.5
	var mid := top + DETOUR_ICON * 0.5
	draw_texture_rect(Icons.texture(detour_icon), Rect2(Vector2(x, top), Vector2(DETOUR_ICON, DETOUR_ICON)).grow(-3.0), false, Icons.tint(detour_icon, quiet))
	x += DETOUR_ICON + GAP
	x += UiDraw.text(self, x, mid, detour_words, FONT, quiet)
	if detour_metres >= 0:
		UiDraw.text(self, x + GAP, mid, _metres_text(detour_metres), FONT, quiet, true)


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
