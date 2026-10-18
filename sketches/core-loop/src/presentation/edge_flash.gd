extends Control

const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# The hit-taken read: the screen edge toward where the hit came from flushes in the
# player_hit colour and fades. Drawn as four gradient bands, so it costs no material and
# no texture; the band facing the source carries the colour, the others only a hint.
# A zero direction (source unknown) lights all four evenly.

const BAND := 0.16
const SIDE_FLOOR := 0.15

var direction := Vector2.ZERO
var color := Color.RED
var alpha := 0.0
# 1 normally; reduced motion sets it to the store's REDUCED_FLASH share. Reduce flashes caps
# it at FlashGuard's information share; the lower of the two wins, so the hit still reads.
var flash_scale := 1.0
var _peak := 0.0
var _left := 0.0
var _life := 0.4


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
	queue_redraw()


func weight(edge: Vector2) -> float:
	if direction == Vector2.ZERO:
		return 1.0
	return maxf(SIDE_FLOOR, direction.dot(edge))


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(0.0, _left - delta)
	alpha = _peak * ease(_left / _life, 0.6)
	queue_redraw()


func _draw() -> void:
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
