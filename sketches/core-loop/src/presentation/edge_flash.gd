extends Control

const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

# The hit-taken read: the screen edge toward where the hit came from flushes in the
# player_hit colour and fades. Drawn as four gradient bands, so it costs no material and
# no texture; the band facing the source carries the colour, the others only a hint.
# A zero direction (source unknown) lights all four evenly.
#
# The notch (FX-06): Reduced motion and Reduce flashes dim the flash, so a light hit there was
# about 0.1 alpha and the direction all but vanished. A known source also gets a steady ink
# wedge on the edge toward it, its tip at the edge and its rim in the hit colour, at full
# strength for NOTCH_S in every mode. It holds still and never pulses, so no setting dims it.

const BAND := 0.16
const SIDE_FLOOR := 0.15
const NOTCH_S := 0.4
const NOTCH_WIDE := UiTokens.GAP_XXXL
const NOTCH_DEEP := UiTokens.GAP_XL
const NOTCH_INSET := UiTokens.GAP_S

var direction := Vector2.ZERO
var color := Color.RED
var alpha := 0.0
# 1 normally; reduced motion sets it to the store's REDUCED_FLASH share. Reduce flashes caps
# it at FlashGuard's information share; the lower of the two wins, so the hit still reads.
var flash_scale := 1.0
var _peak := 0.0
var _left := 0.0
var _life := 0.4
var _notch_left := 0.0


func _init() -> void:
	name = "EdgeFlash"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func flash(toward: Vector2, tint: Color, strength: float, seconds: float) -> void:
	direction = toward.normalized() if toward.length() > 0.01 else Vector2.ZERO
	color = tint
	_peak = clampf(strength * minf(flash_scale, FlashGuard.info(1.0)), 0.0, 1.0)
	_life = maxf(0.05, seconds)
	_left = _life
	alpha = _peak
	_notch_left = NOTCH_S if direction != Vector2.ZERO else 0.0
	queue_redraw()


func notch_shown() -> bool:
	return _notch_left > 0.0


func weight(edge: Vector2) -> float:
	if direction == Vector2.ZERO:
		return 1.0
	return maxf(SIDE_FLOOR, direction.dot(edge))


func _process(delta: float) -> void:
	if _left <= 0.0 and _notch_left <= 0.0:
		return
	_left = maxf(0.0, _left - delta)
	_notch_left = maxf(0.0, _notch_left - delta)
	alpha = _peak * ease(_left / _life, 0.6) if _life > 0.0 else 0.0
	queue_redraw()


# The notch's three corners for a `view` sized screen: its tip where the ray from the centre
# toward the source meets the edge (inset, and slid along the edge so the whole wedge stays on
# screen), pointing straight out through that edge, its base toward the centre.
static func notch_points(toward: Vector2, view: Vector2) -> PackedVector2Array:
	var dir := toward.normalized()
	var half := view * 0.5 - Vector2.ONE * NOTCH_INSET
	var to_side := half.x / absf(dir.x) if absf(dir.x) > 0.001 else INF
	var to_top := half.y / absf(dir.y) if absf(dir.y) > 0.001 else INF
	var tip := view * 0.5 + dir * minf(to_side, to_top)
	var keep := NOTCH_INSET + NOTCH_WIDE * 0.5
	var out := Vector2(signf(dir.x), 0.0)
	if to_side <= to_top:
		tip.y = clampf(tip.y, keep, view.y - keep)
	else:
		tip.x = clampf(tip.x, keep, view.x - keep)
		out = Vector2(0.0, signf(dir.y))
	var base := tip - out * NOTCH_DEEP
	var side := Vector2(-out.y, out.x) * NOTCH_WIDE * 0.5
	return PackedVector2Array([tip, base + side, base - side])


func _draw() -> void:
	if _notch_left > 0.0:
		var wedge := notch_points(direction, size)
		draw_colored_polygon(wedge, UiTokens.INK)
		wedge.append(wedge[0])
		draw_polyline(wedge, Color(color, 1.0), UiTokens.FOCUS_EDGE, true)
	if alpha <= 0.001:
		return
	var w := size.x
	var h := size.y
	var band := minf(w, h) * BAND
	var clear := Color(color, 0.0)
	var edges := [
		[Vector2.LEFT, [Vector2(0, 0), Vector2(band, 0), Vector2(band, h), Vector2(0, h)], [1, 0, 0, 1]],
		[Vector2.RIGHT, [Vector2(w - band, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - band, h)], [0, 1, 1, 0]],
		[Vector2.UP, [Vector2(0, 0), Vector2(w, 0), Vector2(w, band), Vector2(0, band)], [1, 1, 0, 0]],
		[Vector2.DOWN, [Vector2(0, h - band), Vector2(w, h - band), Vector2(w, h), Vector2(0, h)], [0, 0, 1, 1]],
	]
	for edge in edges:
		var a := alpha * weight(edge[0])
		var colors := PackedColorArray()
		for outer in edge[2]:
			colors.append(Color(color, a) if outer == 1 else clear)
		draw_polygon(PackedVector2Array(edge[1]), colors)
