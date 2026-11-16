extends Control

const UiTokens := preload("res://src/ui/ui_tokens.gd")
# The diamond is the world's hazard warning (meaning, not chrome); its keyline and bang are chrome.
const Palette := preload("res://src/core/palette.gd")
const WayOutPaint := preload("res://src/presentation/way_out_paint.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# The mark over the ball while it stands where a hit will land: a hazard diamond with a
# bang, filling from its foot with the warning's own progress, so it is all but full as
# the hit lands. A floor mark is drawn on the world, and a camera inside it sees rails
# overhead and a tinted floor with no edge (first-timer film, 10 Nov 2026: hit six times,
# the reader could say what was coming before none). This says the one thing a floor mark
# cannot from inside: you are in it, and this much warning is left.
#
# A bone pointer stands outside the diamond toward the attack's source (a shell's launch point,
# a lane's start, a ring's middle), so "you are in danger" also says "from there" (PF-16, w42
# film). It is a solid triangle: a shape, no word, and not the floor's way-out chevrons, which
# are open, lie on the ground and say where to go. Bone with an ink keyline, not another red.
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

# The pointer: a unit screen direction toward the source (zero for none), and the screen box of
# the way-out chevrons' first stretch, which the pointer steps out past rather than cover.
const POINTER_LEN := 22.0
const POINTER_WIDTH := 22.0
const POINTER_GAP := float(UiTokens.GAP_XS)
const POINTER_STEP := 6.0
const POINTER_PUSH_MAX := 120.0
# A source nearer the ball than this on screen has no direction worth drawing.
const POINTER_MIN_PX := 14.0
const WAY_CHEVRONS := 2

var avoid := Rect2()
var pointer := Vector2.ZERO
var keep_clear := Rect2()
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


# One call from the HUD each frame: points at the source in the dodge watch's escape (near_miss.gd)
# and keeps clear of that escape's chevrons. `ball` is the ball's centre in the world.
func aim(cam: Camera3D, ball: Vector3, escape: Dictionary) -> void:
	var dir := Vector2.ZERO
	var clear := Rect2()
	if cam != null and escape.has("source"):
		dir = screen_dir(cam, ball, escape["source"])
		clear = way_rect(cam, ball, escape.get("dir", Vector3.ZERO))
	if dir != pointer or clear != keep_clear:
		pointer = dir
		keep_clear = clear
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


# The screen box of the first chevrons of the floor's way out from the ball (way_out_paint.gd).
static func way_rect(cam: Camera3D, ball: Vector3, way: Vector3) -> Rect2:
	if way.length_squared() <= 0.0:
		return Rect2()
	var foot := ball - Vector3.UP * Tuning.RADIUS
	var side := Vector3(-way.z, 0.0, way.x)
	var far := WayOutPaint.START_M + WayOutPaint.SPACING_M * WAY_CHEVRONS
	var box := Rect2()
	var first := true
	for along in [WayOutPaint.START_M - WayOutPaint.SWEEP_M, far]:
		for across in [-WayOutPaint.HALF_SPAN_M, WayOutPaint.HALF_SPAN_M]:
			var p: Vector3 = foot + way * along + side * across
			if cam.is_position_behind(p):
				continue
			var q := cam.unproject_position(p)
			box = Rect2(q, Vector2.ZERO) if first else box.expand(q)
			first = false
	return box


# The pointer's outline (keyline) polygon about the mark's centre, for a unit direction `dir`
# pushed `push` px further out: a triangle whose flat foot lies past the mark's box, whatever the
# angle, and whose tip is POINTER_LEN beyond the foot.
static func pointer_keyline(dir: Vector2, push := 0.0) -> PackedVector2Array:
	return _pointer(dir, push, KEYLINE)


static func pointer_fill(dir: Vector2, push := 0.0) -> PackedVector2Array:
	return _pointer(dir, push, 0.0)


static func _pointer(dir: Vector2, push: float, grow: float) -> PackedVector2Array:
	if dir == Vector2.ZERO:
		return PackedVector2Array()
	var reach := HALF + KEYLINE + RIM
	var foot := reach * (absf(dir.x) + absf(dir.y)) + POINTER_GAP + KEYLINE + push
	var perp := Vector2(-dir.y, dir.x)
	var half := POINTER_WIDTH * 0.5 + grow
	var base := foot - grow
	return PackedVector2Array([dir * base + perp * half, dir * base - perp * half, dir * (foot + POINTER_LEN + grow * 1.5)])


# How far past its resting place the pointer must stand to clear `keep_clear`, in whole steps.
func _push() -> float:
	if keep_clear.size == Vector2.ZERO and keep_clear.position == Vector2.ZERO:
		return 0.0
	var push := 0.0
	while push <= POINTER_PUSH_MAX:
		if not _poly_box(pointer_keyline(pointer, push), _at).intersects(keep_clear):
			return push
		push += POINTER_STEP
	return 0.0


static func _poly_box(poly: PackedVector2Array, at: Vector2) -> Rect2:
	var box := Rect2(at + poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(at + p)
	return box


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
	if pointer != Vector2.ZERO:
		var push := _push()
		draw_colored_polygon(pointer_keyline(pointer, push), UiTokens.INK)
		draw_colored_polygon(pointer_fill(pointer, push), UiTokens.TEXT)
	draw_set_transform(Vector2.ZERO)
