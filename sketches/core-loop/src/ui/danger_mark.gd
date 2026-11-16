extends Control

const UiTokens := preload("res://src/ui/ui_tokens.gd")
# The diamond is the world's hazard warning (meaning, not chrome); its keyline and bang are chrome.
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The mark over the ball while it stands where a hit will land: a hazard diamond with a
# bang, filling from its foot with the warning's own progress, so it is all but full as
# the hit lands. A floor mark is drawn on the world, and a camera inside it sees rails
# overhead and a tinted floor with no edge (first-timer film, 10 Nov 2026: hit six times,
# the reader could say what was coming before none). This says the one thing a floor mark
# cannot from inside: you are in it, and this much warning is left.
#
# A spike grows out of the diamond toward the attack's source (a shell's launch point, a lane's
# start, a ring's middle), so "you are in danger" also says "from there" (PF-16, w42 film). It is
# the diamond's own fill and keyline, one danger shape with a point, so it cannot be taken for the
# floor's way-out chevrons (bone, open, lying on the ground, saying where to go). No word. It
# shortens to stop short of the ball, and is left out when under SPIKE_MIN px would remain.
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

# The spike: a unit screen direction toward the source (zero for none) and the ball's screen box.
# Its tip stands SPIKE_LEN past the diamond's edge, or 2 px short of the ball when that is nearer.
const SPIKE_LEN := 22.0
const SPIKE_MIN := 8.0
const SPIKE_HALF := 12.0
const BALL_CLEAR := 2.0
# A source nearer the ball than this on screen has no direction worth drawing.
const POINTER_MIN_PX := 14.0
const FILL_COLOR := Palette.HAZARD

var avoid := Rect2()
var pointer := Vector2.ZERO
var ball_box := Rect2()
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


# One call from the HUD each frame: points at the source in the dodge watch's escape (near_miss.gd).
# `ball` is the ball's centre in the world.
func aim(cam: Camera3D, ball: Vector3, escape: Dictionary) -> void:
	var dir := Vector2.ZERO
	var box := Rect2()
	if cam != null and escape.has("source"):
		dir = screen_dir(cam, ball, escape["source"])
		if not cam.is_position_behind(ball):
			var c := cam.unproject_position(ball)
			var r := (cam.unproject_position(ball + cam.global_basis.x * Tuning.RADIUS) - c).length()
			box = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	if dir != pointer or box != ball_box:
		pointer = dir
		ball_box = box
		queue_redraw()


# The screen direction from the ball toward a world point, unit length, zero when too close to
# draw. A point behind the camera has no true screen place; it points the way its offset from the
# ball runs across the camera's own right and up, which is the screen edge it is nearest.
static func screen_dir(cam: Camera3D, ball: Vector3, source: Vector3) -> Vector2:
	if not cam.is_position_behind(source):
		var d := cam.unproject_position(source) - cam.unproject_position(ball)
		return d.normalized() if d.length() >= POINTER_MIN_PX else Vector2.ZERO
	var inv := cam.global_transform.affine_inverse()
	var off := inv * source - inv * ball
	var flat := Vector2(off.x, -off.y)
	return flat.normalized() if flat.length() > 0.01 else Vector2.DOWN


# Where the diamond's outer edge lies along the unit direction `dir`, from its centre.
static func edge_along(dir: Vector2) -> float:
	return (HALF + KEYLINE + RIM) / (absf(dir.x) + absf(dir.y))


# How far past the diamond's edge the spike reaches along `dir` from a mark at `at`: SPIKE_LEN,
# less where its tip would come within BALL_CLEAR of the ball's box or `keep` (the reticle's); 0 when under SPIKE_MIN is left.
static func spike_reach(dir: Vector2, at: Vector2, ball: Rect2, keep := Rect2()) -> float:
	if dir == Vector2.ZERO:
		return 0.0
	var edge := edge_along(dir)
	var reach := 0.0
	while reach < SPIKE_LEN:
		var next := minf(reach + 1.0, SPIKE_LEN)
		var tip := at + dir * (edge + next)
		if (ball.size != Vector2.ZERO and ball.grow(BALL_CLEAR).has_point(tip)) \
				or (keep.size != Vector2.ZERO and keep.grow(BALL_CLEAR).has_point(tip)):
			break
		reach = next
	return reach if reach >= SPIKE_MIN else 0.0


# The spike's outline about the mark's centre: a triangle fused into the diamond, `inset` px inside
# its outer edge (the rim, keyline and fill layers are the diamond's own, drawn in step with it).
static func spike_points(dir: Vector2, reach: float, inset := 0.0) -> PackedVector2Array:
	if dir == Vector2.ZERO or reach <= 0.0:
		return PackedVector2Array()
	var edge := edge_along(dir)
	var foot := edge * 0.5
	var width := SPIKE_HALF + KEYLINE + RIM
	var length := edge + reach - foot
	var hyp := sqrt(width * width + length * length)
	var half := width - inset * hyp / length
	var tip := edge + reach - inset * hyp / width
	var perp := Vector2(-dir.y, dir.x)
	return PackedVector2Array([dir * foot + perp * half, dir * foot - perp * half, dir * tip])


static func spike_color() -> Color:
	return FILL_COLOR


# The spike's drawn tip on screen, or the mark's centre when there is none.
func spike_tip() -> Vector2:
	var reach := spike_reach(pointer, _at, ball_box, avoid)
	return _at + pointer * (edge_along(pointer) + reach) if reach > 0.0 else _at


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
	if not shown():
		return Rect2()
	var box := _box(_at)
	var reach := spike_reach(pointer, _at, ball_box, avoid)
	if reach > 0.0:
		for p in spike_points(pointer, reach):
			box = box.expand(_at + p)
	return box


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
	var reach := spike_reach(pointer, _at, ball_box, avoid)
	var layers := [[HALF + KEYLINE + RIM, 0.0, UiTokens.TEXT], [HALF + KEYLINE, RIM, UiTokens.INK], [HALF, RIM + KEYLINE, spike_color()]]
	for layer in layers:
		draw_colored_polygon(_diamond(layer[0]), layer[2])
		if reach > 0.0:
			draw_colored_polygon(spike_points(pointer, reach, layer[1]), layer[2])
	var inner := HALF - EDGE
	draw_colored_polygon(_diamond(inner), FILL_COLOR.lerp(UiTokens.INK, EMPTY_SHADE))
	var filled := fill_points(inner, run)
	if filled.size() >= 3:
		draw_colored_polygon(filled, FILL_COLOR)
	draw_rect(Rect2(-BANG_HALF, BANG_TOP, BANG_HALF * 2.0, BANG_FOOT - BANG_TOP), UiTokens.TEXT)
	draw_rect(Rect2(-DOT_SIZE * 0.5, DOT_TOP, DOT_SIZE, DOT_SIZE), UiTokens.TEXT)
	draw_set_transform(Vector2.ZERO)
