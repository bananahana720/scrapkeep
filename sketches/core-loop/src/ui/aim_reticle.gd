extends Control

const AimStyle := preload("res://src/movement/aim_style.gd")
const Augments := preload("res://src/movement/augments.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const RING := 13.0
const DIAMOND := 15.0
const GAUGE_RING := 24.0
const GAUGE_WIDTH := 3.0
const HARPOON_RING := 19.0
const HARPOON_WIDTH := 2.5
static var reduced_motion := false
const DRY_SHAKE := 3.0
const DRY_SHAKE_TIME := 0.25
const SHAKE_HZ := 40.0
const BACKING_ALPHA := 0.55
const METER_GAP := float(UiTokens.GAP_M)
const METER_WIDTH := 4.0
const METER_SWEEP := TAU * 0.75
const METER_Q_H := 20.0
const BREATH_HZ := 1.0
const BREATH_DEPTH := 0.12
const BACK_OVER := 0.2
const LINE_OVER := 0.6
const PILOT_SHARE := 0.65
const BAND := 20.0
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
const HIT_FLASH := 0.25
const KEST_APEX := 7.0
const KEST_TOP := 13.0
const KEST_HALF := 4.5
const PIP_LONG := 6.0
const PIP_WIDE := 3.5
const PIP_HIT := 1.35
const SQUARE_HALF := 3.0
const BRACKET_FLUSH := 6.5
const BRACKET_OPEN := 12.0
const BRACKET_H := 4.5
const BRACKET_SERIF := 2.0
const BRACKET_HIT := 1.4
const MARK_BACK := 2.0
const ACK_PULSE_S := 0.08
const ACK_INNER := 1.5
const ACK_OUTER := 5.5
const ACK_WIDTH := 2.0

var player
var camera: Camera3D
var gauge := 0.0
var gauge_color := Color.WHITE
var harpoon_fill := 1.0
var meter := 0.0
var meter_full := false
var meter_active := false
var meter_color := Color.WHITE
var hide_q := false
var cadence := {}
var cadence_color := Color.WHITE
var _hit_seen := []
var _hit_age := INF
var _shake_left := 0.0
var _shake_clock := 0.0
var _ack_left := 0.0
var _ack_color := Color.WHITE
var _ack_strength := 1.0
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
		player.events.grapple_fired.connect(func(_anchor: Vector3): pulse(1.0, EventKinds.line_color("locked")))
		player.events.shot_fired.connect(func(_weapon: String, _from: Vector3, _to: Vector3): pulse(0.75))
		player.events.boosted.connect(func(_dir: Vector3): pulse(0.85))
		player.events.dashed.connect(func(_dir: Vector3): pulse(0.85))
		player.events.slot_cast.connect(func(_slot: String, _id: String, _at: Vector3): pulse(1.0))
		player.events.active_fired.connect(func(_id: String, _at: Vector3, _count: int): pulse(1.0))
		player.events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _seconds: float):
			pulse(1.15, EventKinds.role_color("live")))


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
	var animating := _shake_left > 0.0 or _ack_left > 0.0 or meter_full
	var cadence_now := cadence_key(cadence, _hit_age)
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
	_ack_left = maxf(0.0, _ack_left - delta)
	_breath_clock = _breath_clock + delta if meter_full else 0.0
	harpoon_fill = harpoon_readiness()
	var hit := cadence_hit(cadence)
	if hit.is_empty():
		_hit_seen = []
		_hit_age = INF
	elif hit != _hit_seen:
		_hit_seen = hit
		_hit_age = 0.0
	else:
		_hit_age += delta


static func meter_radius() -> float:
	return GAUGE_RING + METER_GAP


static func meter_span(fill: float) -> Vector2:
	var start := PI * 0.5 + (TAU - METER_SWEEP) * 0.5
	return Vector2(start, start + METER_SWEEP * clampf(fill, 0.0, 1.0))


static func meter_fill_color(class_color: Color) -> Color:
	if Color(class_color, 1.0).is_equal_approx(EventKinds.role_color("live")):
		return EventKinds.role_color("neutral").lightened(0.25)
	return class_color


static func meter_rim(full: bool) -> Color:
	return EventKinds.role_color("live") if full else Color(UiTokens.INK, BACKING_ALPHA)


static func breathe(t: float) -> float:
	return 1.0 + BREATH_DEPTH * sin(TAU * BREATH_HZ * t)


static func over_pilot(apart: float, pilot_px: float) -> float:
	if pilot_px <= 0.0:
		return 0.0
	return smoothstep(0.0, 1.0, (pilot_px + RING + BAND - apart) / BAND)


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


func pulse(strength := 1.0, color := Color.TRANSPARENT) -> void:
	_ack_left = ACK_PULSE_S
	_ack_strength = clampf(strength, 0.25, 1.5)
	_ack_color = color if color.a > 0.0 else EventKinds.role_color("neutral")
	queue_redraw()


func ack_fraction() -> float:
	return clampf(_ack_left / ACK_PULSE_S, 0.0, 1.0)


func harpoon_readiness() -> float:
	var total: float = player.tuning.harpoon_rewind() if player.get("tuning") != null else 0.0
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - player.kit.rewind_left / total, 0.0, 1.0)


func rect() -> Rect2:
	if not is_visible_in_tree():
		return Rect2()
	var centre := get_viewport_rect().size * 0.5 + shake_offset()
	var r := GAUGE_RING + METER_GAP + METER_WIDTH
	return Rect2(centre - Vector2(r, r), Vector2(r, r) * 2.0)


func shake_offset() -> Vector2:
	if reduced_motion or _shake_left <= 0.0:
		return Vector2.ZERO
	return Vector2(sin(_shake_clock * TAU * SHAKE_HZ) * DRY_SHAKE, 0.0)


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
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
		"diamond":
			var at := centre
			if camera != null and not camera.is_position_behind(aim["point"]):
				at = camera.unproject_position(aim["point"])
			draw_line(centre, at, Color(color, 0.6), 1.5)
			draw_circle(centre, 2.0, color)
			var points := PackedVector2Array([
				at + Vector2(0.0, -DIAMOND), at + Vector2(DIAMOND, 0.0),
				at + Vector2(0.0, DIAMOND), at + Vector2(-DIAMOND, 0.0), at + Vector2(0.0, -DIAMOND)])
			draw_polyline(points, color, 2.5)
	_draw_cadence(centre)
	_draw_ack(centre)


func _draw_ack(centre: Vector2) -> void:
	if _ack_left <= 0.0:
		return
	var frac := ack_fraction()
	var expand := 0.0 if reduced_motion else (1.0 - frac) * 3.0 * _ack_strength
	var inner := RING + ACK_INNER + expand
	var outer := RING + ACK_OUTER + expand
	var c := _thin(Color(_ack_color, 0.85 * frac))
	var width := ACK_WIDTH * (0.5 + 0.5 * frac)
	for i in 4:
		var dir := Vector2.from_angle(PI * 0.25 + PI * 0.5 * float(i))
		draw_line(centre + dir * inner, centre + dir * outer, c, width)


func _thin(c: Color) -> Color:
	return Color(c, c.a * lerpf(1.0, LINE_OVER, _cover))


func _back(c: Color) -> Color:
	return Color(c, c.a * lerpf(1.0, BACK_OVER, _cover))


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


static func cadence_key(snap: Dictionary, hit_age := 0.0) -> Array:
	match String(snap.get("trigger", "")):
		"press":
			if int(snap.get("mag", 0)) <= 0:
				return []
			return ["press", int(snap["mag"]), int(snap.get("chamber", 0)), int(snap.get("hot", 0)),
				bool(snap.get("reloading", false)), float(snap.get("reload", 0.0)), String(snap.get("window", "")),
				snap.get("window_range", Vector2.ZERO), float(snap.get("reload_s", 0.0))]
		"tap_charge":
			return ["tap_charge", float(snap.get("charge", 0.0)), bool(snap.get("charging", false))]
		"lob_snap":
			return ["lob_snap", _kest_reading(snap, hit_age)]
		"beats":
			return ["beats"] + _tarn_reading(snap)
		"stamp":
			return ["stamp", _tally_reading(snap, hit_age)]
		"lock":
			return ["lock"] + _cannon_reading(snap)
	return []


static func cadence_hit(snap: Dictionary) -> Array:
	match String(snap.get("trigger", "")):
		"lob_snap":
			if String(snap.get("window", "")) == "hit":
				return ["lob_snap", int(snap.get("snap_token", 0))]
		"stamp":
			if int(snap.get("stamp_streak", 0)) > 0:
				return ["stamp", int(snap["stamp_streak"])]
	return []


static func cadence_marks(snap: Dictionary, class_color: Color, hit_age := 0.0) -> Array:
	match String(snap.get("trigger", "")):
		"press":
			return _rivet_marks(snap, class_color) if int(snap.get("mag", 0)) > 0 else []
		"tap_charge":
			return _sable_marks(snap, class_color)
		"lob_snap":
			return _kest_marks(_kest_reading(snap, hit_age), class_color)
		"beats":
			return _tarn_marks(_tarn_reading(snap), class_color)
		"stamp":
			return _tally_marks(_tally_reading(snap, hit_age), class_color)
		"lock":
			return _cannon_marks(_cannon_reading(snap), class_color)
	return []


static func _rivet_marks(snap: Dictionary, class_color: Color) -> Array:
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
			marks.append({"shape": "disc", "role": "chamber_hot", "layer": "line", "at": at, "r": size, "color": meter_fill_color(class_color)})
		else:
			marks.append({"shape": "disc", "role": "chamber_loaded", "layer": "line", "at": at, "r": size, "color": bone})
	return marks


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


static func _kest_reading(snap: Dictionary, hit_age: float) -> String:
	match String(snap.get("window", "")):
		"open":
			return "open"
		"spent":
			return "spent"
		"hit":
			return "hit" if hit_age < HIT_FLASH else ""
	return ""


static func _kest_marks(reading: String, class_color: Color) -> Array:
	if reading == "":
		return []
	var ink := Color(UiTokens.INK, BACKING_ALPHA)
	var v := PackedVector2Array([Vector2(-KEST_HALF, -KEST_TOP), Vector2(0.0, -KEST_APEX), Vector2(KEST_HALF, -KEST_TOP)])
	if reading == "hit":
		var mid := Vector2(0.0, -(KEST_APEX + KEST_TOP * 2.0) / 3.0)
		var back := PackedVector2Array()
		for p in v:
			back.append(mid + (p - mid) * 1.4)
		return [
			{"shape": "fill", "role": "snap_back", "layer": "back", "points": back, "color": ink},
			{"shape": "fill", "role": "snap_hit", "layer": "line", "points": v, "color": EventKinds.role_color("neutral")},
			{"shape": "poly", "role": "snap_edge", "layer": "line", "points": v, "closed": true, "width": 1.0, "color": meter_fill_color(class_color)},
		]
	var open := reading == "open"
	return [
		{"shape": "poly", "role": "snap_back", "layer": "back", "points": v, "closed": false, "width": 4.5, "color": ink},
		{"shape": "poly", "role": "snap_open" if open else "snap_spent", "layer": "line", "points": v, "closed": false,
			"width": 2.5 if open else 1.5, "color": EventKinds.role_color("live" if open else "slate")},
	]


static func _tarn_reading(snap: Dictionary) -> Array:
	match String(snap.get("window", "")):
		"open":
			return [2, "open"]
		"hit":
			return [2, "hit"]
		"spent":
			return [0, "spent"]
	return [clampi(int(snap.get("beat", 0)), 0, 2), "hollow"]


static func _tarn_marks(reading: Array, class_color: Color) -> Array:
	var ink := Color(UiTokens.INK, BACKING_ALPHA)
	var bone := EventKinds.role_color("neutral")
	var filled := int(reading[0])
	var marks: Array = []
	for i in 3:
		var state: String = ("filled" if i < filled else "hollow") if i < 2 else String(reading[1])
		var angle: float = [PI, 0.0, -PI * 0.5][i]
		var grow := PIP_HIT if state == "hit" else 1.0
		marks.append({"shape": "fill", "role": "pip_back", "layer": "back",
			"points": _bar(angle, PIP_LONG * grow + MARK_BACK, PIP_WIDE * grow + MARK_BACK), "color": ink})
		var bar := _bar(angle, PIP_LONG * grow, PIP_WIDE * grow)
		match state:
			"hollow":
				marks.append({"shape": "poly", "role": "pip_hollow", "layer": "line", "points": bar, "closed": true, "width": 1.0, "color": Color(bone, 0.7)})
			"filled":
				marks.append({"shape": "fill", "role": "pip_filled", "layer": "line", "points": bar, "color": bone})
			"open":
				marks.append({"shape": "fill", "role": "pip_open", "layer": "line", "points": bar, "color": EventKinds.role_color("live")})
			"hit":
				marks.append({"shape": "fill", "role": "pip_hit", "layer": "line", "points": bar, "color": meter_fill_color(class_color)})
				marks.append({"shape": "poly", "role": "pip_edge", "layer": "line", "points": bar, "closed": true, "width": 1.0, "color": bone})
			"spent":
				marks.append({"shape": "fill", "role": "pip_spent", "layer": "line", "points": bar, "color": EventKinds.role_color("slate")})
	return marks


static func _bar(angle: float, long: float, wide: float) -> PackedVector2Array:
	var along := Vector2.from_angle(angle)
	var across := along.orthogonal() * wide * 0.5
	var near := along * (INSTRUMENT_R - long * 0.5)
	var far := along * (INSTRUMENT_R + long * 0.5)
	return PackedVector2Array([near - across, far - across, far + across, near + across])


static func _tally_reading(snap: Dictionary, hit_age: float) -> String:
	match String(snap.get("window", "")):
		"open":
			return "open"
		"spent":
			return "spent"
	if int(snap.get("stamp_streak", 0)) > 0 and hit_age < HIT_FLASH:
		return "hit"
	return "rest"


static func _tally_marks(reading: String, class_color: Color) -> Array:
	var square := _square(SQUARE_HALF)
	var marks: Array = [{"shape": "fill", "role": "square_back", "layer": "back", "points": _square(SQUARE_HALF + MARK_BACK * 0.6), "color": Color(UiTokens.INK, BACKING_ALPHA)}]
	match reading:
		"open":
			marks.append({"shape": "poly", "role": "square_open", "layer": "line", "points": square, "closed": true, "width": 2.0, "color": EventKinds.role_color("live")})
		"hit":
			marks.append({"shape": "fill", "role": "square_paid", "layer": "line", "points": square, "color": meter_fill_color(class_color)})
		"spent":
			marks.append({"shape": "fill", "role": "square_spent", "layer": "line", "points": square, "color": EventKinds.role_color("slate")})
		_:
			marks.append({"shape": "poly", "role": "square_rest", "layer": "line", "points": square, "closed": true, "width": 1.0, "color": Color(EventKinds.role_color("neutral"), 0.7)})
	return marks


static func _square(half: float) -> PackedVector2Array:
	var c := Vector2(0.0, -INSTRUMENT_R)
	return PackedVector2Array([c + Vector2(-half, -half), c + Vector2(half, -half), c + Vector2(half, half), c + Vector2(-half, half)])


static func _cannon_reading(snap: Dictionary) -> Array:
	if bool(snap.get("painted", false)):
		match String(snap.get("lock_stage", "")):
			"rail":
				return ["flush", 0.0]
			"barrage":
				return ["spent", clampf(float(snap.get("lock_bracket", 1.0)), 0.0, 1.0)]
		return ["closing", clampf(float(snap.get("lock_bracket", 1.0)), 0.0, 1.0)]
	if String(snap.get("window", "")) == "hit":
		return ["hit", 0.0]
	return ["rest", 1.0]


static func _cannon_marks(reading: Array, class_color: Color) -> Array:
	var state := String(reading[0])
	var d := lerpf(BRACKET_FLUSH, BRACKET_OPEN, float(reading[1]))
	var bone := EventKinds.role_color("neutral")
	var color: Color = bone
	var width := 2.0
	match state:
		"rest":
			color = Color(bone, 0.6)
			width = 1.5
		"flush":
			color = EventKinds.role_color("live")
			width = 2.5
		"spent":
			color = EventKinds.role_color("slate")
	var h := BRACKET_H * (BRACKET_HIT if state == "hit" else 1.0)
	var marks: Array = []
	for side in [-1.0, 1.0]:
		var x: float = side * d
		var bracket := PackedVector2Array([Vector2(x - side * BRACKET_SERIF, -h), Vector2(x, -h),
			Vector2(x, h), Vector2(x - side * BRACKET_SERIF, h)])
		marks.append({"shape": "poly", "role": "bracket_back", "layer": "back", "points": bracket, "closed": false, "width": width + MARK_BACK, "color": Color(UiTokens.INK, BACKING_ALPHA)})
		if state == "hit":
			marks.append({"shape": "poly", "role": "bracket_edge", "layer": "line", "points": bracket, "closed": false, "width": width + 1.5, "color": meter_fill_color(class_color)})
		marks.append({"shape": "poly", "role": "bracket_" + state, "layer": "line", "points": bracket, "closed": false, "width": width, "color": color})
	return marks


static func mark_reach(mark: Dictionary) -> float:
	match String(mark["shape"]):
		"disc", "ring":
			return (mark["at"] as Vector2).length() - float(mark["r"]) - float(mark.get("width", 0.0)) * 0.5
		"arc":
			return float(mark["r"]) - float(mark["width"]) * 0.5
		"line":
			return minf((mark["from"] as Vector2).length(), (mark["to"] as Vector2).length())
		"poly", "fill":
			var pts: PackedVector2Array = mark["points"]
			var closed: bool = mark["shape"] == "fill" or bool(mark.get("closed", false))
			if mark["shape"] == "fill" and Geometry2D.is_point_in_polygon(Vector2.ZERO, pts):
				return 0.0
			var near := INF
			for i in (pts.size() if closed else pts.size() - 1):
				near = minf(near, Geometry2D.get_closest_point_to_segment(Vector2.ZERO, pts[i], pts[(i + 1) % pts.size()]).length())
			return near - float(mark.get("width", 0.0)) * 0.5
	return 0.0


func _draw_cadence(centre: Vector2) -> void:
	for mark in cadence_marks(cadence, cadence_color, _hit_age):
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
			"poly":
				var pts := _at(mark["points"], centre)
				if bool(mark.get("closed", false)):
					pts.append(pts[0])
				draw_polyline(pts, c, mark["width"])
			"fill":
				draw_colored_polygon(_at(mark["points"], centre), c)


static func _at(points: PackedVector2Array, centre: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(centre + p)
	return out
