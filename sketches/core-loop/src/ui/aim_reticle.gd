extends Control

const AimStyle := preload("res://src/movement/aim_style.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const RING := 13.0
const DIAMOND := 15.0
const GAUGE_RING := 24.0
const GAUGE_WIDTH := 3.0
const HARPOON_RING := 19.0
const HARPOON_WIDTH := 2.5
# Reduced motion (Game.set_reduced_motion keeps it current): a dry fire no longer shakes the reticle.
static var reduced_motion := false
const DRY_SHAKE := 3.0
const DRY_SHAKE_TIME := 0.25
const SHAKE_HZ := 40.0
# The ultimate meter (design-v3/SKILL-BAR.md section 5): an arc METER_GAP outside the gauge
# ring, METER_WIDTH thick, sweeping METER_SWEEP clockwise round a gap centred on six o'clock,
# where the Q keycap (METER_Q_H tall) sits once the meter is full.
# The dark under an unfilled gauge or meter: ink at this alpha, so the field shows through.
const BACKING_ALPHA := 0.55
const METER_GAP := float(UiTokens.GAP_M)
const METER_WIDTH := 4.0
const METER_SWEEP := TAU * 0.75
const METER_Q_H := 20.0
# The full meter breathes at 1 Hz; the hook lock pulses at 2 Hz, so the two never read alike.
const BREATH_HZ := 1.0
const BREATH_DEPTH := 0.12
# The pilot rides in view inside the ball (ball_looks.gd: the cutaway's window faces the
# camera), and at the resting camera the aim point sits on the pilot's head. While the reticle
# is over the pilot its dark tracks and fills drop to BACK_OVER of their strength and its lines
# to LINE_OVER, so the rider shows through and the readings stay; the aim point itself stays
# whole, and the reticle never leaves the camera's centre ray. PILOT_SHARE is the part of the
# ball's radius the pilot shows through; the change runs over BAND px so it never pops.
const BACK_OVER := 0.2
const LINE_OVER := 0.6
const PILOT_SHARE := 0.65
const BAND := 20.0

# The reticle carries no words: its shape and colour are the aim state (AimStyle), and
# a grapple target in reach adds the right-mouse key glyph beside it (key_glyphs.gd).
# While a hold-gauge-release shot charges, a ring round it fills clockwise from twelve,
# linearly, in the class colour, and closes when the gauge is full. The one exception is the
# full ultimate meter's Q keycap in the arc's gap, drawn here only while the Q prompt is not
# (key_glyphs.gd), so Q is never drawn twice.
var player
var camera: Camera3D
var gauge := 0.0
var gauge_color := Color.WHITE
# The inner ring is the harpoon's readiness: 1 when a press would bite, filling as the hook docks
# after a smash. It reads the kit's own rewind, so a kill that refunds it fills the ring at once.
var harpoon_fill := 1.0
# The ultimate meter, 0 to 1, as the HUD reads it (AbilitySlots.ultimate_of); during the set
# piece it is the flight still to run. meter_full is the one ready fact every layer reads.
var meter := 0.0
var meter_full := false
var meter_active := false
var meter_color := Color.WHITE
# The Q prompt draws the keycap in the gap this tick.
var hide_q := false
var _shake_left := 0.0
var _shake_clock := 0.0
var _breath_clock := 0.0
var _cover := 0.0


func setup(player_ref, camera_ref: Camera3D) -> void:
	player = player_ref
	camera = camera_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player.get("events") != null:
		player.events.line_state_changed.connect(_on_line_state)


# The only thing the reticle knows is the aim record the fire action also uses.
func reading() -> Dictionary:
	return player.kit.aim


func _process(delta: float) -> void:
	step(delta)
	queue_redraw()


func step(delta: float) -> void:
	_shake_left = maxf(0.0, _shake_left - delta)
	_shake_clock += delta
	_breath_clock = _breath_clock + delta if meter_full else 0.0
	harpoon_fill = harpoon_readiness()


static func meter_radius() -> float:
	return GAUGE_RING + METER_GAP


# The meter arc's start and end angles for a fill (screen angles: 0 at three o'clock, growing
# clockwise). It starts left of the gap and fills clockwise over twelve to the gap's far side.
static func meter_span(fill: float) -> Vector2:
	var start := PI * 0.5 + (TAU - METER_SWEEP) * 0.5
	return Vector2(start, start + METER_SWEEP * clampf(fill, 0.0, 1.0))


# The fill is the class colour (identity); where the class colour is the live mint itself, the
# fill draws in sand-light bare metal, so mint still means only "ready" (SKILL-BAR section 12).
static func meter_fill_color(class_color: Color) -> Color:
	if Color(class_color, 1.0).is_equal_approx(EventKinds.role_color("live")):
		return EventKinds.role_color("neutral").lightened(0.25)
	return class_color


# The rim turns live mint at full ("your verb works now"); below full it is a dark track.
static func meter_rim(full: bool) -> Color:
	return EventKinds.role_color("live") if full else Color(UiTokens.INK, BACKING_ALPHA)


# The full meter's width scale at `t` seconds into the breath: one breath a second.
static func breathe(t: float) -> float:
	return 1.0 + BREATH_DEPTH * sin(TAU * BREATH_HZ * t)


# How far the reticle is over the pilot, 0 clear to 1 on them: `apart` px from the aim point to
# the centre of a pilot `pilot_px` in radius.
static func over_pilot(apart: float, pilot_px: float) -> float:
	if pilot_px <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, (pilot_px + RING + BAND - apart) / BAND)


# The same, this frame, from where the ball sits on screen.
func cover(centre: Vector2) -> float:
	if camera == null or not player.has_method("shown_position"):
		return 0.0
	var at: Vector3 = player.shown_position()
	if camera.is_position_behind(at):
		return 0.0
	var ball := camera.unproject_position(at)
	var edge := camera.unproject_position(at + camera.global_basis.x * Tuning.RADIUS * PILOT_SHARE)
	return over_pilot(centre.distance_to(ball), ball.distance_to(edge))


func q_shown() -> bool:
	return meter_full and not meter_active and not hide_q


func q_glyph() -> String:
	return Glyphs.of("ultimate")


func drawn_words() -> PackedStringArray:
	return Keycap.words(q_glyph()) if q_shown() else PackedStringArray()


func _on_line_state(state: String, _target: Node3D, _at: Vector3, _cause: String) -> void:
	if state == "dry_fire":
		_shake_left = DRY_SHAKE_TIME
		_shake_clock = 0.0


# One minus the rewind left over the rewind time, from the kit.
func harpoon_readiness() -> float:
	var total: float = player.tuning.harpoon_rewind() if player.get("tuning") != null else 0.0
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - player.kit.rewind_left / total, 0.0, 1.0)


# How far a dry fire has pushed the reticle off the centre, in pixels: at most DRY_SHAKE.
func shake_offset() -> Vector2:
	if reduced_motion or _shake_left <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_shake_clock * TAU * SHAKE_HZ) * DRY_SHAKE, 0.0)


# The aim found nothing in reach but the centre ray meets a surface beyond the line's reach.
func _out_of_range(aim: Dictionary) -> bool:
	if camera == null or not camera.is_inside_tree() or not player.kit.on(Augments.GRAPPLE):
		return false
	if aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
		return false
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * Augments.AIM_CAST,
		Augments.WORLD_MASK | Augments.ENEMY_MASK)
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit["position"] as Vector3).distance_to(player.shown_position()) > player.grapple_range()


# What the reticle draws for an aim style. While a line stands it is a dot: the latch is shown
# on the thing it bit, and a lock mark beside it would say "can hook" and "hooked" at once.
func drawn_shape(style: Dictionary) -> String:
	if player.kit.hooked:
		return "dot"
	return style["shape"]


func _draw() -> void:
	if player == null:
		return
	var aim := reading()
	var style := AimStyle.of(aim, _out_of_range(aim))
	var color: Color = style["color"]
	# The reticle marks the camera's centre ray, which is the viewport centre whatever
	# size layout gave this control.
	var centre := get_viewport_rect().size * 0.5 + shake_offset()
	_cover = cover(centre)
	if player.kit.on(Augments.GRAPPLE):
		var ready := EventKinds.line_color("locked")
		draw_arc(centre, HARPOON_RING, 0.0, TAU, 48, _back(Color(ready, 0.25)), HARPOON_WIDTH)
		draw_arc(centre, HARPOON_RING, -PI * 0.5, -PI * 0.5 + TAU * harpoon_fill, 48, _thin(ready), HARPOON_WIDTH)
	if gauge > 0.0:
		draw_arc(centre, GAUGE_RING, 0.0, TAU, 48, _back(Color(UiTokens.INK, BACKING_ALPHA)), GAUGE_WIDTH + UiTokens.EDGE)
		draw_arc(centre, GAUGE_RING, -PI * 0.5, -PI * 0.5 + TAU * clampf(gauge, 0.0, 1.0), 48, _thin(gauge_color),
			GAUGE_WIDTH + (1.5 if gauge >= 1.0 else 0.0))
	_draw_meter(centre)
	match drawn_shape(style):
		"dot":
			draw_circle(centre, 2.5, color)
		"cross":
			draw_line(centre - Vector2(8.0, 0.0), centre + Vector2(8.0, 0.0), color, 2.0)
			draw_line(centre - Vector2(0.0, 8.0), centre + Vector2(0.0, 8.0), color, 2.0)
		"ring":
			draw_circle(centre, RING, _back(Color(color, 0.3)))
			draw_arc(centre, RING, 0.0, TAU, 40, _thin(color), 2.5)
			draw_circle(centre, 2.5, color)
		"hollow_ring":
			draw_arc(centre, RING, 0.0, TAU, 40, _thin(color), 2.5)
		"brackets":
			# An enemy the harpoon would bite: the snap line to the body. The brackets on the body
			# are the line view's, in the world, so there is one set and it pulses.
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
		"diamond":
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			# The snap line shows the magnet pulling the hook off your aim onto the target.
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
			var points := PackedVector2Array([
				at + Vector2(0.0, -DIAMOND), at + Vector2(DIAMOND, 0.0),
				at + Vector2(0.0, DIAMOND), at + Vector2(-DIAMOND, 0.0), at + Vector2(0.0, -DIAMOND)])
			draw_polyline(points, color, 2.5)


func _thin(c: Color) -> Color:
	return Color(c, c.a * lerpf(1.0, LINE_OVER, _cover))


func _back(c: Color) -> Color:
	return Color(c, c.a * lerpf(1.0, BACK_OVER, _cover))


# The ultimate meter: nothing at 0, so the aim stays clear until the first point; then a dark
# track over the whole sweep, the fill in the class colour, and at full a mint rim, a 1 Hz
# breath and the Q keycap in the gap.
func _draw_meter(centre: Vector2) -> void:
	if meter <= 0.0 and not meter_full:
		return
	var r := meter_radius()
	var whole := meter_span(1.0)
	var span := meter_span(meter)
	draw_arc(centre, r, whole.x, whole.y, 48, _back(meter_rim(false)), METER_WIDTH + 2.0)
	var width := METER_WIDTH * (breathe(_breath_clock) if meter_full else 1.0)
	if span.y > span.x:
		draw_arc(centre, r, span.x, span.y, 48, _thin(meter_color), width)
	if meter_full:
		var rim := _thin(meter_rim(true))
		draw_arc(centre, r + width * 0.5 + 1.0, whole.x, whole.y, 48, rim, 1.5)
		draw_arc(centre, r - width * 0.5 - 1.0, whole.x, whole.y, 48, rim, 1.5)
	if q_shown():
		Keycap.draw(self, centre + Vector2(0.0, r), q_glyph(), meter_rim(true), METER_Q_H)
