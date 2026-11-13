extends Control

const UiTokens := preload("res://src/ui/ui_tokens.gd")
# The diamond is the world's hazard warning (meaning, not chrome); its keyline and bang are chrome.
const Palette := preload("res://src/core/palette.gd")

# The mark over the ball while it stands where a hit will land: a hazard diamond with a
# bang, filling from its foot with the warning's own progress, so it is all but full as
# the hit lands. A floor mark is drawn on the world, and a camera inside it sees rails
# overhead and a tinted floor with no edge (first-timer film, 10 Nov 2026: hit six times,
# the reader could say what was coming before none). This says the one thing a floor mark
# cannot from inside: you are in it, and this much warning is left.
#
# It reads the dodge watch (combat/near_miss.gd standing_in), so it shows for exactly the
# threats a near miss is judged on, and leaving or jumping clear takes it down where the
# near miss's chevrons then fire. No word, no sound, no flash: the fill is its only motion.
# It stands LIFT over the ball's top edge on screen and steps up over `avoid` (the aim
# reticle's box, from the HUD) as the part name does (ui/part_name.gd).

const HALF := 19.0
const KEYLINE := 3.0
# A bone rim outside the keyline: the mark often stands across the rail of the very warning
# it reports, which is hazard on charcoal too.
const RIM := 2.5
const EDGE := 3.0
const LIFT := Vector2(0.0, -38.0)
const AVOID_GAP := float(UiTokens.GAP_XS)
const EMPTY_SHADE := 0.62
const BANG_HALF := 2.5
const BANG_TOP := -11.0
const BANG_FOOT := 3.0
const DOT_TOP := 6.0
const DOT_SIZE := 5.0

var avoid := Rect2()
# How far the warning has run, 0 to 1, or -1 when the ball stands in none.
var run := -1.0
var _at := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func show_run(value: float) -> void:
	var next := clampf(value, 0.0, 1.0) if value >= 0.0 else -1.0
	if next == run:
		return
	run = next
	queue_redraw()


func shown() -> bool:
	return run >= 0.0


# Where the ball's top edge is on screen; the mark stands above it.
func follow(ball_top: Vector2) -> void:
	var at := (ball_top + LIFT).round()
	if _box(at).intersects(avoid):
		at.y = floorf(avoid.position.y - HALF - KEYLINE - RIM - AVOID_GAP)
	if at != _at:
		_at = at
		queue_redraw()


# Where the mark sits on screen while it shows, for what must stay clear of it.
func rect() -> Rect2:
	return _box(_at) if shown() else Rect2()


func _box(at: Vector2) -> Rect2:
	var reach := Vector2.ONE * (HALF + KEYLINE + RIM)
	return Rect2(at - reach, reach * 2.0)


# The filled part of a diamond of half-diagonal `half` about the origin for a run of 0 to 1,
# foot first: a triangle up to the waist, then the waist and the shoulders.
static func fill_points(half: float, share: float) -> PackedVector2Array:
	var level := half - 2.0 * half * clampf(share, 0.0, 1.0)
	if level >= half:
		return PackedVector2Array()
	if level <= -half:
		return _diamond(half)
	if level >= 0.0:
		return PackedVector2Array([Vector2(-(half - level), level), Vector2(half - level, level), Vector2(0.0, half)])
	return PackedVector2Array([Vector2(-(half + level), level), Vector2(half + level, level), Vector2(half, 0.0),
		Vector2(0.0, half), Vector2(-half, 0.0)])


static func _diamond(half: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, -half), Vector2(half, 0.0), Vector2(0.0, half), Vector2(-half, 0.0)])


func _draw() -> void:
	if not shown():
		return
	draw_set_transform(_at)
	draw_colored_polygon(_diamond(HALF + KEYLINE + RIM), UiTokens.TEXT)
	draw_colored_polygon(_diamond(HALF + KEYLINE), UiTokens.INK)
	draw_colored_polygon(_diamond(HALF), Palette.HAZARD)
	var inner := HALF - EDGE
	draw_colored_polygon(_diamond(inner), Palette.HAZARD.lerp(UiTokens.INK, EMPTY_SHADE))
	var filled := fill_points(inner, run)
	if filled.size() >= 3:
		draw_colored_polygon(filled, Palette.HAZARD)
	draw_rect(Rect2(-BANG_HALF, BANG_TOP, BANG_HALF * 2.0, BANG_FOOT - BANG_TOP), UiTokens.TEXT)
	draw_rect(Rect2(-DOT_SIZE * 0.5, DOT_TOP, DOT_SIZE, DOT_SIZE), UiTokens.TEXT)
	draw_set_transform(Vector2.ZERO)
