extends Control

const AimStyle := preload("res://src/movement/aim_style.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
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
# The weapon's timing instrument (PILOT-CADENCE section 5.3, LEGIBILITY section 14.1) sits inside
# the reticle's ring at INSTRUMENT_R, round the aim point and clear of it: no mark comes nearer the
# centre than DOT_CLEAR px, so the centre dot is never covered. Rivet's chambers are discs, a hot
# round a size larger, a spent one a dim open ring; Sable's charge is an arc on a dark track, and
# her full-charge tick cuts a dark gap through it so it reads apart from the fill without colour.
# Each mark sits on a dark backing.
const INSTRUMENT_R := 10.0
const DOT_CLEAR := 4.0
const CHAMBER_R := 2.0
const HOT_R := 2.6
const CHAMBER_BACK := 1.0
const TRACK_WIDTH := 4.0
const FILL_WIDTH := 3.0
const SWEEP_WIDTH := 1.5
const NOTCH_WIDTH := 4.0
const NOTCH_EDGE := 3.0
const FULL_TICK := 4.0

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
# The weapon's cadence this tick, as WeaponDriver.state_snapshot() publishes it, and the pilot's
# class colour; the reticle reads nothing else of the weapon (cadence_marks).
var cadence := {}
var cadence_color := Color.WHITE
var _shake_left := 0.0
var _shake_clock := 0.0
var _breath_clock := 0.0
var _cover := 0.0
const OUT_OF_RANGE_FRAMES := 6
var _out_of_range_cached := false
var _cast_frame := -1
var _cast_camera := Transform3D()
var _cast_ball := Vector3.INF
var _cast_reach := -1.0
var _prepared_frame := -1
var _drawn_style := {}
var _drawn_centre := Vector2.ZERO
var _has_drawn := false
var _d_aim_state := -1
var _d_far := false
var _d_hooked := false
var _d_grapple := false
var _d_harpoon_fill := 0.0
var _d_gauge := 0.0
var _d_gauge_color := Color.WHITE
var _d_meter := 0.0
var _d_meter_full := false
var _d_meter_active := false
var _d_meter_color := Color.WHITE
var _d_hide_q := false
var _d_cover := 0.0
var _d_view := Vector2.ZERO
var _d_glyph := ""
var _d_snap_point := Vector3.INF
var _d_cam_xform := Transform3D()
var _d_cam_fov := 0.0
var _d_cadence := []
var _d_cadence_color := Color.WHITE
var _was_animating := false


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
	if player == null:
		return
	step(delta)
	if not is_visible_in_tree():
		return
	var aim := reading()
	_refresh_out_of_range(aim)
	var view := get_viewport_rect().size
	var centre := view * 0.5 + shake_offset()
	_cover = cover(centre)
	var aim_state: int = aim.get("state", Augments.AIM_NONE)
	var hooked: bool = player.kit.hooked
	var grapple: bool = player.kit.on(Augments.GRAPPLE)
	if _drawn_style.is_empty() or aim_state != _d_aim_state or _out_of_range_cached != _d_far:
		_drawn_style = AimStyle.of(aim, _out_of_range_cached)
	var shape := drawn_shape(_drawn_style)
	var has_snap := shape == "brackets" or shape == "diamond"
	var snap_point: Vector3 = aim.get("point", Vector3.INF) if has_snap and aim.get("point") is Vector3 else Vector3.INF
	var cam_xform := camera.global_transform if has_snap and camera != null else Transform3D()
	var cam_fov := camera.fov if has_snap and camera != null else 0.0
	var glyph := q_glyph() if q_shown() else ""
	var animating := _shake_left > 0.0 or meter_full
	var cadence_now := cadence_key(cadence)
	var dirty := not _has_drawn or animating or _was_animating \
		or aim_state != _d_aim_state or _out_of_range_cached != _d_far \
		or hooked != _d_hooked or grapple != _d_grapple \
		or harpoon_fill != _d_harpoon_fill or gauge != _d_gauge or gauge_color != _d_gauge_color \
		or meter != _d_meter or meter_full != _d_meter_full or meter_active != _d_meter_active \
		or meter_color != _d_meter_color or hide_q != _d_hide_q \
		or _cover != _d_cover or view != _d_view or glyph != _d_glyph \
		or cadence_now != _d_cadence or cadence_color != _d_cadence_color \
		or (has_snap and (snap_point != _d_snap_point or cam_xform != _d_cam_xform or cam_fov != _d_cam_fov))
	if dirty:
		_has_drawn = true
		_d_aim_state = aim_state
		_d_far = _out_of_range_cached
		_d_hooked = hooked
		_d_grapple = grapple
		_d_harpoon_fill = harpoon_fill
		_d_gauge = gauge
		_d_gauge_color = gauge_color
		_d_meter = meter
		_d_meter_full = meter_full
		_d_meter_active = meter_active
		_d_meter_color = meter_color
		_d_hide_q = hide_q
		_d_cover = _cover
		_d_view = view
		_d_glyph = glyph
		_d_snap_point = snap_point
		_d_cam_xform = cam_xform
		_d_cam_fov = cam_fov
		_d_cadence = cadence_now
		_d_cadence_color = cadence_color
		queue_redraw()
	_drawn_centre = centre
	_prepared_frame = Engine.get_process_frames()
	_was_animating = animating


func _refresh_out_of_range(aim: Dictionary) -> void:
	if camera == null or not camera.is_inside_tree() or not player.kit.on(Augments.GRAPPLE) \
			or aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE:
		_out_of_range_cached = false
		_cast_frame = -1
		return
	var at := camera.global_transform
	var ball: Vector3 = player.shown_position()
	var reach: float = player.grapple_range()
	var now := Engine.get_physics_frames()
	if _cast_frame >= 0 and now - _cast_frame < OUT_OF_RANGE_FRAMES and at == _cast_camera and ball == _cast_ball and reach == _cast_reach:
		return
	_cast_frame = now
	_cast_camera = at
	_cast_ball = ball
	_cast_reach = reach
	_out_of_range_cached = _out_of_range(aim)


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


# The screen the reticle covers: its outermost ring, the ultimate meter, round the centre it is drawn at.
func rect() -> Rect2:
	if not is_visible_in_tree():
		return Rect2()
	var centre := get_viewport_rect().size * 0.5 + shake_offset()
	var r := GAUGE_RING + METER_GAP + METER_WIDTH
	return Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)


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
	var style: Dictionary
	var centre: Vector2
	if _prepared_frame == Engine.get_process_frames() and not _drawn_style.is_empty() \
			and int(aim.get("state", Augments.AIM_NONE)) == _d_aim_state:
		style = _drawn_style
		centre = _drawn_centre
	else:
		style = AimStyle.of(aim, _out_of_range(aim))
		# The reticle marks the camera's centre ray, which is the viewport centre whatever
		# size layout gave this control.
		centre = get_viewport_rect().size * 0.5 + shake_offset()
		_cover = cover(centre)
	var color: Color = style["color"]
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
	_draw_cadence(centre)


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


# What of a cadence snapshot the instrument draws, so the reticle redraws when a mark would change
# and not for a timer it does not show. Empty for a trigger with no instrument here.
static func cadence_key(snap: Dictionary) -> Array:
	match String(snap.get("trigger", "")):
		"press":
			if int(snap.get("mag", 0)) <= 0:
				return []
			return ["press", int(snap["mag"]), int(snap.get("chamber", 0)), int(snap.get("hot", 0)),
				bool(snap.get("reloading", false)), float(snap.get("reload", 0.0)), String(snap.get("window", "")),
				snap.get("window_range", Vector2.ZERO), float(snap.get("reload_s", 0.0))]
		"tap_charge":
			return ["tap_charge", float(snap.get("charge", 0.0)), bool(snap.get("charging", false))]
	return []


# The instrument for a cadence snapshot, as marks round the aim point (offsets in px, screen
# angles: 0 at three o'clock, growing clockwise). Each mark is a "disc", "ring", "arc" or
# "line", names its `role`, and its `layer`: "back" for a dark backing (thinned by _back over the
# pilot), "line" for a reading (thinned by _thin). Mint marks only the press-now moment; the
# pilot's colour marks what the press makes; slate is a window spent; nothing is brass.
static func cadence_marks(snap: Dictionary, class_color: Color) -> Array:
	match String(snap.get("trigger", "")):
		"press":
			return _rivet_marks(snap) if int(snap.get("mag", 0)) > 0 else []
		"tap_charge":
			return _sable_marks(snap, class_color)
	return []


# Rivet: a cylinder of chambers clockwise from twelve in firing order. A spent chamber is a hollow
# ring, a loaded one a bone disc, a hot round a larger copper disc. While the cylinder reloads the
# chambers give way to a sweep round the same ring and the notch on it: brackets while it waits,
# solid mint while a press would hit it, solid slate once it is spent.
static func _rivet_marks(snap: Dictionary) -> Array:
	var marks: Array = []
	var bone := EventKinds.role_color("neutral")
	var ink := Color(UiTokens.INK, BACKING_ALPHA)
	var r := INSTRUMENT_R
	if bool(snap.get("reloading", false)):
		marks.append({"shape": "arc", "role": "track", "layer": "back", "r": r, "from": 0.0, "to": TAU, "width": TRACK_WIDTH, "color": ink})
		var reload_s := float(snap.get("reload_s", 0.0))
		var window: Vector2 = snap.get("window_range", Vector2.ZERO)
		var state := String(snap.get("window", ""))
		if reload_s > 0.0 and window.y > window.x and state != "idle":
			var a := -PI * 0.5 + TAU * clampf(window.x / reload_s, 0.0, 1.0)
			var b := -PI * 0.5 + TAU * clampf(window.y / reload_s, 0.0, 1.0)
			match state:
				"open":
					marks.append({"shape": "arc", "role": "notch_open", "layer": "line", "r": r, "from": a, "to": b, "width": NOTCH_WIDTH, "color": EventKinds.role_color("live")})
				"spent":
					marks.append({"shape": "arc", "role": "notch_spent", "layer": "line", "r": r, "from": a, "to": b, "width": NOTCH_WIDTH, "color": EventKinds.role_color("slate")})
				_:
					var dim := Color(bone, 0.6)
					marks.append({"shape": "arc", "role": "notch_waiting", "layer": "line", "r": r, "from": a, "to": b, "width": SWEEP_WIDTH, "color": dim})
					for edge in [a, b]:
						var d := Vector2.from_angle(edge)
						marks.append({"shape": "line", "role": "notch_edge", "layer": "line", "from": d * (r - NOTCH_EDGE), "to": d * (r + NOTCH_EDGE), "width": SWEEP_WIDTH, "color": dim})
		var at := -PI * 0.5 + TAU * clampf(float(snap.get("reload", 0.0)), 0.0, 1.0)
		marks.append({"shape": "arc", "role": "sweep", "layer": "line", "r": r, "from": -PI * 0.5, "to": at, "width": SWEEP_WIDTH, "color": bone})
		var head := Vector2.from_angle(at)
		marks.append({"shape": "line", "role": "sweep_head", "layer": "line", "from": head * (r - NOTCH_EDGE), "to": head * (r + NOTCH_EDGE), "width": 2.0, "color": bone})
		return marks
	var mag := int(snap["mag"])
	var loaded := clampi(int(snap.get("chamber", 0)), 0, mag)
	var spent := mag - loaded
	var hot := clampi(int(snap.get("hot", 0)), 0, loaded)
	for i in mag:
		var at := Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(mag)) * r
		var is_hot := i >= spent and i < spent + hot
		var size := HOT_R if is_hot else CHAMBER_R
		marks.append({"shape": "disc", "role": "chamber_back", "layer": "back", "at": at, "r": size + CHAMBER_BACK, "color": ink})
		if i < spent:
			marks.append({"shape": "ring", "role": "chamber_spent", "layer": "line", "at": at, "r": size, "width": 1.0, "color": Color(bone, 0.7)})
		elif is_hot:
			marks.append({"shape": "disc", "role": "chamber_hot", "layer": "line", "at": at, "r": size, "color": Palette.COPPER})
		else:
			marks.append({"shape": "disc", "role": "chamber_loaded", "layer": "line", "at": at, "r": size, "color": bone})
	return marks


# Sable: an empty arc on a dark track at rest, filling clockwise from twelve with the charge in her
# colour (meter_fill_color keeps mint off the fill), and at full charge while held one mint tick
# across twelve: let go now. The bolt leaving empties the charge, so the arc empties with it.
static func _sable_marks(snap: Dictionary, class_color: Color) -> Array:
	var r := INSTRUMENT_R
	var marks: Array = [
		{"shape": "arc", "role": "track", "layer": "back", "r": r, "from": 0.0, "to": TAU, "width": TRACK_WIDTH, "color": Color(UiTokens.INK, BACKING_ALPHA)},
		{"shape": "arc", "role": "empty", "layer": "line", "r": r, "from": 0.0, "to": TAU, "width": 1.0, "color": Color(EventKinds.role_color("neutral"), 0.35)},
	]
	var charge := clampf(float(snap.get("charge", 0.0)), 0.0, 1.0)
	if charge > 0.0:
		marks.append({"shape": "arc", "role": "fill", "layer": "line", "r": r, "from": -PI * 0.5, "to": -PI * 0.5 + TAU * charge, "width": FILL_WIDTH, "color": meter_fill_color(class_color)})
	if charge >= 1.0 and bool(snap.get("charging", false)):
		marks.append({"shape": "line", "role": "full_tick_back", "layer": "back", "from": Vector2(0.0, -(r - FULL_TICK - 1.0)), "to": Vector2(0.0, -(r + FULL_TICK + 2.0)), "width": 5.0, "color": Color(UiTokens.INK, BACKING_ALPHA * 1.6)})
		marks.append({"shape": "line", "role": "full_tick", "layer": "line", "from": Vector2(0.0, -(r - FULL_TICK)), "to": Vector2(0.0, -(r + FULL_TICK + 1.0)), "width": 2.5, "color": EventKinds.role_color("live")})
	return marks


# The nearest a mark comes to the aim point, in px. Every line here is radial with flat ends, so
# its nearest point is its inner end.
static func mark_reach(mark: Dictionary) -> float:
	match String(mark["shape"]):
		"disc", "ring":
			return (mark["at"] as Vector2).length() - float(mark["r"]) - float(mark.get("width", 0.0)) * 0.5
		"arc":
			return float(mark["r"]) - float(mark["width"]) * 0.5
		"line":
			return minf((mark["from"] as Vector2).length(), (mark["to"] as Vector2).length())
	return 0.0


func _draw_cadence(centre: Vector2) -> void:
	for mark in cadence_marks(cadence, cadence_color):
		var c: Color = _back(mark["color"]) if mark["layer"] == "back" else _thin(mark["color"])
		match String(mark["shape"]):
			"disc":
				draw_circle(centre + mark["at"], mark["r"], c)
			"ring":
				draw_arc(centre + mark["at"], mark["r"], 0.0, TAU, 16, c, mark["width"])
			"arc":
				if float(mark["to"]) > float(mark["from"]):
					draw_arc(centre, mark["r"], mark["from"], mark["to"], 40, c, mark["width"])
			"line":
				draw_line(centre + mark["from"], centre + mark["to"], c, mark["width"])
