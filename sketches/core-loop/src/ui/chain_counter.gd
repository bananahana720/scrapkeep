extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")

# The hook chain's combo beside the ability bar (design-v3/HOOK-CHAIN.md, "One source, every
# layer"). The HUD steps it each frame from player.chain.combo and nothing here writes the chain.
# Shown only while the combo is 2 or more. Each new link swells the digits and eases them back
# in PULSE seconds; when the chain ends the last number drops and fades over FALL seconds, then
# hides. The colour is the chain_link row's, so the live colour law holds. The count wears two
# linked rings and a times sign ("chain x2"), so it reads as a count of links and not as a
# stray number beside the bar (w37 film 022, PF-21).

const FONT := UiTokens.HEADING
const PULSE := 0.12
const SWELL := 0.35
const FALL := 0.3
const DROP := 18.0
const BOX := Vector2(104.0, 48.0)
const LINK := 9.0
const LINK_W := 2.5
const TIMES := "×"

# The combo on show: the live combo, or the last one while it falls.
var shown := 0
var _combo := 0
var _pulse := -1.0
var _fall := -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOX
	size = BOX
	visible = false


# True while there is something to draw: a live combo or a falling one.
func showing() -> bool:
	return _combo >= 2 or _fall >= 0.0


func text() -> String:
	return str(shown) if showing() else ""


func step(delta: float, combo: int) -> void:
	var was := showing()
	if combo >= 2:
		if combo > _combo:
			_pulse = 0.0
		_fall = -1.0
		shown = combo
	elif _combo >= 2 and _fall < 0.0:
		_fall = 0.0
		_pulse = -1.0
	_combo = combo
	if _pulse >= 0.0:
		_pulse += delta
		if _pulse >= PULSE:
			_pulse = -1.0
	if _fall >= 0.0:
		_fall += delta
		if _fall >= FALL:
			_fall = -1.0
	visible = showing()
	if visible or was:
		queue_redraw()


func _draw() -> void:
	if not showing():
		return
	var color := EventKinds.line_color("chain_link")
	var scale := 1.0
	var drop := 0.0
	if _pulse >= 0.0:
		scale += SWELL * (1.0 - _pulse / PULSE)
	if _fall >= 0.0:
		var t := _fall / FALL
		drop = DROP * t
		color.a = 1.0 - t
	draw_set_transform(Vector2(0.0, size.y * 0.5 + drop), 0.0, Vector2(scale, scale))
	_draw_links(color)
	var x := LINK * 3.4
	x += UiDraw.text(self, x, 0.0, TIMES, UiTokens.LABEL, color)
	UiDraw.text(self, x + 1.0, 0.0, str(shown), FONT, color, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Two linked rings, the chain itself, with their middle at the counter's mid line.
func _draw_links(color: Color) -> void:
	var outline := Color(UiDraw.OUTLINE, UiDraw.OUTLINE.a * color.a)
	for at in [Vector2(LINK, 0.0), Vector2(LINK * 2.2, 0.0)]:
		draw_arc(at, LINK * 0.8, 0.0, TAU, 24, outline, LINK_W + 2.0)
	for at in [Vector2(LINK, 0.0), Vector2(LINK * 2.2, 0.0)]:
		draw_arc(at, LINK * 0.8, 0.0, TAU, 24, color, LINK_W)
