extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Density := preload("res://src/presentation/density.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

enum Type { INSTANT, WAVE, PROJECTILE, LANE }

const UNSET := -1
const KINDS := ["threat_instant", "threat_wave", "threat_projectile", "threat_lane"]
const GROUP := "threat"

const PRIORITY := 40
const LIVE_PRIORITY := PRIORITY + 1
const LINE_UNDER_PRIORITY := PRIORITY - 1
const LINE_PRIORITY := PRIORITY + 2
const SEGMENTS := 72
const AREA_ALPHA := 0.1
const EDGE_ALPHA := 0.95
const OUTLINE_ALPHA := 0.5
const FILL_ALPHA := 0.35
const SWEPT_ALPHA := 0.15
const RUN_ALPHA := 0.35
const LIVE_ALPHA := 0.8
const FLASH_ALPHA := 0.9
const FLASH_SECONDS := 0.22
const CRACK_SECONDS := 0.5
const CRACK_SORT := -1000.0
const CRACK_HOLD := 0.2
const CRACK_ALPHA := 0.95
const CRACK_HALF := 0.07
const CRACK_RING_HALF := 0.06
const CRACK_STEP := 2.2
const CRACK_MIN := 6
const CRACK_MAX := 28
const CRACK_LENGTH := 0.18
const CRACK_SHORT := 0.5
const CRACK_LONG := 1.2
const CRACK_JAG := 0.3
const CRACK_RING_JAG := 0.12
const DUST_SECONDS := 0.35
const DUST_ALPHA := 0.75
const DUST_SIZE := 0.45
const DUST_KICK := 1.1
const DUST_SWELL := 0.8
const DUST_TONE := Color(0.902, 0.871, 0.792)
const EDGE_MIN := 0.35
const EDGE_PER_METRE := 0.04
const EDGE_MAX := 0.6
const TRACE_DASH := 0.7
const TRACE_HALF := 0.07
const RAIL := 0.25
const CAP := RAIL * 2.0
const DASH_HALF := RAIL * 1.4
const SHELL_EDGE := 0.6
const LIVE_LANE := 0.9
const UNDERLAY := 0.35
const UNDERLAY_ALPHA := 1.0
const WAVE_EDGE := 1.0
const DASH := 2.2
const OWN_DASH := 1.0
const CHEVRON_HALF := 1.6
const CHEVRON_DEPTH := 1.3
const CHEVRON_LINE := 0.2
const RADIAL_CHEVRONS := 8
const SWEEP_CHEVRONS := [0.3, 0.6, 0.9]
const PULL_CHEVRONS := [0.3, 0.55, 0.8]
const BAND_ALPHA := 0.16
const BAND_TOP := 0.12
const BRACKET_OPEN := 1.6
const DOT_SPACING := 1.6
const DOT_SIZE := 0.22
const TRACE_ALPHA := 0.85
const LANE_STEP := 2.0
const STRIPE_PITCH := 0.5
const POST_SPACING := 4.0
const POST_HALF := 0.06
const POST_ALPHA := 0.35
const SPIKE_HALF := 0.22
const SPIKE_ALPHA := 0.7
const SHELL_AREA_ALPHA := 0.24
const LENS_CLEAR := 1.0
const LENS_FULL := 3.0
const RAIL_ALPHA := 0.7
const OWNER_STEP := PI / 6.0
const OWNER_SPACING := 4.0

const HAZE_FILL := 1.15
const LIVE_SCORCH := 0.4
const LIVE_SCORCH_ALPHA := 0.8
const AIR_LIVE_ALPHA := 0.61
const LIVE_PULSE_SECONDS := 1.6
const LIVE_PULSE_MIX := 0.35
const TELEGRAPH_FLAG := "telegraph"
const LOOKS := ["classic", "haze", "clear", "edges", "tape"]
const TAPE_SHADE := 0.55
const TAPE_SHARE := 0.35
const CLEAR_RAIL_HALF := 0.05
const CLEAR_RAIL_ALPHA := 0.45
const CLEAR_POST_ALPHA := 0.2
const CLEAR_SPIKE_ALPHA := 0.45
const CLEAR_BAND_TOP_ALPHA := 0.45
const CLEAR_LIVE_ALPHA := 0.55
const EDGES_FILL := 0.5
const FENCE_CLEAR := 3.0
const FENCE_FULL := 6.0
const DEPTH_PULL := 0.3


static func haze() -> bool:
	return Painter.haze_on()


static func set_haze(on: bool) -> void:
	Painter._look = "haze" if on else "classic"


static func look() -> String:
	return Painter.look_now()


static func set_look(name: String) -> void:
	Painter._look = name if name in LOOKS else "haze"


static func reset_for_tests() -> void:
	Painter._look = ""
	Painter._held_looks.clear()
	Painter._materials.clear()
	Painter.materials_built = 0
	Painter._warmed = false


static func striped() -> bool:
	return Painter.striped_on()


static func soft() -> bool:
	return Painter.soft_on()


static func follow_row(tuning) -> void:
	var row: String = tuning.option(Tuning.TELEGRAPH_KEY)
	if row != look():
		set_look(row)
		Painter._warmed = false


const STATIC_LAYERS := ["under", "stripe", "base", "fill", "fence"]
const TINTED_LAYERS := ["fill", "crack", "dust"]
const MOTION_LAYERS := ["motion_under", "stripe_motion", "motion"]
const DRIVEN_LAYERS := ["stripe", "stripe_motion", "motion", "motion_under"]

enum Drive { PASS, RADIAL, LANE, DOTS, CHEVRON, CURTAIN }
const FAR := 1.0e9
const CURTAIN_STEPS := 48
const FILL_STENCIL := {"fill": 1, "area": 2, "swept": 4, "run": 8, "live": 16, "reach": 32}
const FILL_SORT := {"area": -6000.0, "reach": -5000.0, "fill": -4000.0, "run": -3000.0, "swept": -2000.0, "live": -1000.0}


static func stance(tone: Color) -> String:
	if tone == Palette.HAZARD:
		return "hostile"
	if tone == Palette.SAND:
		return "neutral"
	return "owned"


static func valid(type: int) -> bool:
	return type >= 0 and type < KINDS.size()


static func kind(type: int) -> String:
	return KINDS[type] if valid(type) else ""


static func row(type: int) -> Dictionary:
	return EventKinds.THREAT_ROWS.get(kind(type), {})


static func bright(tone: Color) -> Color:
	return tone.lightened(0.35)


static func trace_tone(tone: Color) -> Color:
	return Color(tone if stance(tone) == "hostile" else bright(tone), TRACE_ALPHA)


static func flight_point(launch: Vector3, landing: Vector3, bump: float, s: float) -> Vector3:
	return launch.lerp(landing, s) + Vector3.UP * bump * s * (1.0 - s)


static func lob_bump(gravity: float, seconds: float) -> float:
	return 0.5 * gravity * seconds * seconds


static func edge_width(d: Dictionary) -> float:
	return clampf(float(d.get("r_out", 0.0)) * EDGE_PER_METRE, EDGE_MIN, EDGE_MAX)


static func fill_share(d: Dictionary) -> float:
	return 1.0 if d.get("live", false) else clampf(float(d.get("progress", 0.0)), 0.0, 1.0)


static func fill_room(d: Dictionary) -> Vector2:
	if d["form"] == "lane":
		return Vector2(0.0, maxf(0.0, float(d["half_width"]) - RAIL))
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var w := outline_width(d)
	var lo := r_in + w if r_in > 0.05 else 0.0
	var hi := r_out - w
	if hi < lo:
		lo = maxf(0.0, (lo + hi) * 0.5) if r_in > 0.05 else 0.0
		hi = lo
	return Vector2(lo, hi)


static func outline_width(d: Dictionary) -> float:
	match int(d["type"]):
		Type.PROJECTILE:
			return edge_width(d) * SHELL_EDGE
		Type.LANE:
			return RAIL + DASH_HALF
	return edge_width(d)


static func fill_end(d: Dictionary) -> float:
	return maxf(-float(d["back"]), float(d["length"]) - CAP)


static func _live_lane(d: Dictionary) -> bool:
	return int(d["type"]) == Type.LANE and live_band(d)


static func live_band(d: Dictionary) -> bool:
	return d.get("live", false) and not d.has("front_m") and not d.has("body_m")


static func fill_span(d: Dictionary) -> Vector2:
	if _live_lane(d):
		return Vector2(0.0, float(d["half_width"]) * LIVE_LANE) if d["form"] == "lane" else Vector2(d["r_in"], d["r_out"])
	var p := fill_share(d)
	var room := fill_room(d)
	if d["form"] == "lane" or room.x <= 0.0:
		return Vector2(0.0, room.y * p)
	var mid := (room.x + room.y) * 0.5
	var half := (room.y - room.x) * 0.5 * p
	return Vector2(mid - half, mid + half)


static func is_full(d: Dictionary) -> bool:
	return absf(float(d["a1"]) - float(d["a0"])) >= TAU - 0.001


static func front_angle(d: Dictionary) -> float:
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var sweep := signf(a1 - a0) if a1 != a0 else 1.0
	return a0 + sweep * clampf(maxf(float(d["front"]), 0.0), 0.0, absf(a1 - a0))


static func fill_tint(d: Dictionary) -> Color:
	if int(d["type"]) != Type.INSTANT or not d.get("live", false):
		return Color(0.0, 0.0, 0.0, 0.0)
	if haze() and stance(d["tone"]) == "hostile":
		if d.get("air", false):
			return Color(d.get("live_tone", d["tone"]), AIR_LIVE_ALPHA)
		return Color(_pulsed(Palette.HAZARD.lerp(Palette.CHARCOAL, LIVE_SCORCH), Palette.CHARCOAL, d), LIVE_SCORCH_ALPHA)
	var live_tone: Color = d.get("live_tone", d["tone"])
	return Color(_pulsed(live_tone, Palette.CHARCOAL, d), LIVE_ALPHA)


static func _pulsed(core: Color, deeper: Color, d: Dictionary) -> Color:
	if not d.has("live_age"):
		return core
	var swing := 0.5 - 0.5 * cos(TAU * float(d["live_age"]) / LIVE_PULSE_SECONDS)
	return core.lerp(deeper, LIVE_PULSE_MIX * swing * swing)


static func marks(d: Dictionary, motion: bool) -> Array:
	var out: Array = []
	if stance(d["tone"]) == "neutral":
		if not motion:
			_lined(out, "outline", false, Color(Palette.SAND, EDGE_ALPHA), func(grow: float): return _dashed_outline(d, grow), {})
		return out
	if not motion and d.has("owner"):
		_lined(out, "owner", false, Color(d["owner"], 1.0), func(grow: float): return _owner_ticks(d, grow), {"owner": d["owner"]})
	if not motion and int(d["type"]) != Type.WAVE:
		_fence(out, d)
	match int(d["type"]):
		Type.INSTANT:
			_instant(d, motion, out)
		Type.WAVE:
			_wave(d, motion, out)
		Type.PROJECTILE:
			_projectile(d, motion, out)
		Type.LANE:
			_lane(d, motion, out)
	return out


static func all_marks(d: Dictionary) -> Array:
	return marks(d, false) + marks(d, true)


static func roles(d: Dictionary) -> Array:
	var out: Array = []
	for m in all_marks(d):
		if not m["layer"].ends_with("under") and not m["role"] in out:
			out.append(m["role"])
	out.sort()
	return out


static func can_drive(d: Dictionary) -> bool:
	if int(d["type"]) != Type.WAVE:
		return true
	return is_full(d) and _area_layer(d, true) != "motion"


static func driven_marks(d: Dictionary) -> Array:
	var out: Array = []
	if stance(d["tone"]) == "neutral":
		return out
	var lane: bool = d["form"] == "lane"
	match int(d["type"]):
		Type.INSTANT:
			var fill_tris := _lane_strip(d, -float(d["back"]), fill_end(d), -float(d["half_width"]), float(d["half_width"])) if lane else _footprint(d)
			out.append(_driven(_mark("fill", _area_layer(d, true), _area_tone(d, FILL_ALPHA), fill_tris),
				Drive.LANE if lane else Drive.RADIAL))
		Type.LANE:
			var tris: PackedVector3Array
			if lane:
				var half: float = d["half_width"]
				tris = _lane_strip(d, -float(d["back"]), float(d["length"]), -half, half)
			else:
				tris = _arc(d, d["r_in"], d["r_out"], d["a0"], d["a1"])
			out.append(_driven(_mark("run", _area_layer(d, true), _area_tone(d, RUN_ALPHA), tris),
				Drive.LANE if lane else Drive.RADIAL, 1.0))
		Type.WAVE:
			_driven_wave(d, out)
		Type.PROJECTILE:
			_driven_projectile(d, out)
	return out


static func drive(d: Dictionary) -> Dictionary:
	var out := {}
	var live: bool = d.get("live", false)
	match int(d["type"]):
		Type.INSTANT:
			out[_area_layer(d, true)] = _span_clip(d, 1.0)
		Type.LANE:
			var band := live_band(d)
			var entry := _span_clip(d, live_alpha() / RUN_ALPHA if band else 1.0)
			entry["live"] = band
			out[_area_layer(d, true)] = entry
		Type.WAVE:
			var r_in: float = d["r_in"]
			var r_out: float = d["r_out"]
			var arming := float(d["front"]) < 0.0
			var f := maxf(float(d["front"]), 0.0)
			var inner := maxf(r_in, f - WAVE_EDGE)
			var outer := minf(r_out, f + WAVE_EDGE)
			var lines := {"clip": Vector4(inner, outer, f + WAVE_EDGE + 0.3 + CHEVRON_DEPTH, clampf(f, r_in, r_out)),
				"alpha": lerpf(0.35, 0.8, float(d["progress"])) if arming else 1.0, "radius": f, "inner": inner, "outer": outer}
			out["motion"] = lines
			out["motion_under"] = lines
			out[_area_layer(d, true)] = {"clip": Vector4(-FAR, -1.0 if arming else maxf(r_in, f - WAVE_EDGE), 0.0, 0.0), "alpha": 1.0}
		Type.PROJECTILE:
			if stance(d["tone"]) == "hostile":
				out[_area_layer(d, true)] = _span_clip(d, 1.0)
			var arc := {"clip": Vector4(0.0, 0.0, float(d["progress"]), 0.0), "alpha": 1.0}
			out["motion"] = arc
			out["motion_under"] = arc
	return out


static func _span_clip(d: Dictionary, alpha: float) -> Dictionary:
	var span := fill_span(d)
	var clip := Vector4(span.x, span.y, 0.0, 0.0)
	if d["form"] == "lane":
		clip = Vector4(-FAR, float(d["length"]) if _live_lane(d) else fill_end(d), -1.0, span.y)
	return {"clip": clip, "alpha": alpha, "span": span, "share": fill_share(d)}


static func _driven(m: Dictionary, drive_mode: int, scaled := 0.0, grow := 0.0) -> Dictionary:
	m["c1"] = Vector4(drive_mode, scaled, grow, 0.0)
	return m


static func _driven_lined(out: Array, role: String, hot: Color, build: Callable) -> void:
	var under: Dictionary = build.call(UNDERLAY)
	under.merge({"role": role + "_under", "layer": "motion_under", "tone": Color(Palette.CHARCOAL, UNDERLAY_ALPHA)}, true)
	out.append(under)
	var line: Dictionary = build.call(0.0)
	line.merge({"role": role, "layer": "motion", "tone": hot}, true)
	out.append(line)


static func _driven_wave(d: Dictionary, out: Array) -> void:
	var c: Vector3 = d["centre"]
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var reach: float = d["reach"]
	out.append(_driven(_mark("swept", _area_layer(d, true), _area_tone(d, SWEPT_ALPHA), _arc(d, r_in, r_out, 0.0, TAU)), Drive.RADIAL))
	var hot := Color(bright(d["tone"]), 1.0)
	_driven_lined(out, "front", hot, func(grow: float):
		var m := _mark("front", "", hot, _arc(d, r_in - grow, r_out + grow, 0.0, TAU))
		return _driven(m, Drive.RADIAL, 0.0 if grow > 0.0 else 1.0, grow))
	_driven_lined(out, "chevrons", hot, func(grow: float):
		var tris := PackedVector3Array()
		var c0 := PackedFloat32Array()
		for i in RADIAL_CHEVRONS:
			var a := TAU * (i + 0.5) / RADIAL_CHEVRONS
			var ray := Vector3(cos(a), 0.0, sin(a))
			var side := Vector3.UP.cross(ray)
			var tip := _at(c, a, r_out)
			var start := tris.size()
			_chevron(tris, tip, ray, CHEVRON_LINE + grow)
			for k in range(start, tris.size()):
				var off: Vector3 = tris[k] - tip
				c0.append_array([ray.x, ray.z, off.dot(ray), off.dot(side)])
		var m := _mark("chevrons", "", hot, tris, {"outward": true})
		m["c0"] = c0
		m["c1"] = Vector4(Drive.CHEVRON, 0.0 if grow > 0.0 else 1.0, r_out, 0.0)
		return m)
	var wall := PackedVector3Array()
	var top := PackedVector3Array()
	var rays := PackedFloat32Array()
	for i in CURTAIN_STEPS:
		var a0 := TAU * i / CURTAIN_STEPS
		var a1 := TAU * (i + 1) / CURTAIN_STEPS
		_wall(wall, _at(c, a0, r_out), _at(c, a1, r_out), 0.0, reach)
		_wall(top, _at(c, a0, r_out), _at(c, a1, r_out), reach - rail_half(), reach + rail_half())
		for a in [a0, a0, a1, a0, a1, a1]:
			rays.append_array([cos(a), sin(a), 0.0, 0.0])
	var band := _driven(_mark("band", "motion", Color(hot, BAND_ALPHA), wall, {"height": reach}), Drive.CURTAIN)
	band["c0"] = rays
	out.append(band)
	var band_top := _driven(_mark("band_top", "motion", Color(hot, top_alpha()), top, {"height": reach}), Drive.CURTAIN, 1.0)
	band_top["c0"] = rays
	out.append(band_top)


static func _driven_projectile(d: Dictionary, out: Array) -> void:
	if stance(d["tone"]) == "hostile":
		out.append(_driven(_mark("fill", _area_layer(d, true), _area_tone(d, FILL_ALPHA), _footprint(d)), Drive.RADIAL))
	if not d.has("launch"):
		return
	var arc := _flight_arc(d, 0.0)
	var under := _driven(_mark("trace_under", "motion_under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA), _flight_arc(d, UNDERLAY * 0.25)["tris"]), Drive.DOTS)
	under["abs"] = true
	under["c0"] = arc["shares"]
	out.append(under)
	var trace := _driven(_mark("trace", "motion", trace_tone(d["tone"]), arc["tris"], {"points": arc["points"]}), Drive.DOTS)
	trace["abs"] = true
	trace["c0"] = arc["shares"]
	out.append(trace)


static func _flight_arc(d: Dictionary, grow: float, from := 0.0) -> Dictionary:
	var c: Vector3 = d["centre"]
	var launch: Vector3 = d["launch"]
	var bump: float = d["bump"]
	var steps := clampi(int((launch.distance_to(c) + bump * 0.5) / DOT_SPACING), 6, 48)
	var tris := PackedVector3Array()
	var points := PackedVector3Array()
	var shares := PackedFloat32Array()
	for i in steps:
		var s1 := float(i + 1) / steps
		if s1 < from:
			continue
		var a := flight_point(launch, c, bump, (i + 1.0 - TRACE_DASH) / steps)
		var b := flight_point(launch, c, bump, s1)
		points.append(b)
		var along := (b - a).normalized()
		var flat := along.cross(Vector3.UP)
		flat = flat.normalized() if flat.length() > 0.001 else Vector3.RIGHT
		var tall := along.cross(flat).normalized()
		var start := tris.size()
		for side in [flat, tall]:
			var w: Vector3 = side * (TRACE_HALF + grow)
			_quad(tris, a - w, a + w, b + w, b - w)
		for k in tris.size() - start:
			shares.append_array([s1, 0.0, 0.0, 0.0])
	return {"tris": tris, "points": points, "shares": shares}


static func _instant(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	if motion:
		out.append(_grown_fill(d, "fill", _area_tone(d, FILL_ALPHA)))
		return
	out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA), _footprint(d)))
	_lined(out, "edge", false, Color(tone, EDGE_ALPHA), func(grow: float): return _edge_tris(d, grow),
		{"r_in": d.get("r_in", 0.0), "r_out": d.get("r_out", 0.0)})
	out.append(_mark("solid", "fill", Color.WHITE, _footprint(d)))


static func _wave(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	if d["form"] != "radial":
		push_error("threat_grammar: a WAVE needs a radial form")
		return
	if not motion:
		_lined(out, "outline", false, Color(tone, OUTLINE_ALPHA), func(grow: float): return _dashed_outline(d, grow), {})
		return
	var arming := float(d["front"]) < 0.0
	if not arming:
		var swept: PackedVector3Array
		if is_full(d):
			swept = _arc(d, d["r_in"], maxf(float(d["r_in"]), float(d["front"]) - WAVE_EDGE), 0.0, TAU)
		else:
			swept = _arc(d, d["r_in"], d["r_out"], d["a0"], front_angle(d))
		out.append(_mark("swept", _area_layer(d, true), _area_tone(d, SWEPT_ALPHA), swept))
	var hot := Color(bright(tone), lerpf(0.35, 0.8, float(d["progress"])) if arming else 1.0)
	var reach: float = d["reach"]
	var c: Vector3 = d["centre"]
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	if is_full(d):
		var f := maxf(float(d["front"]), 0.0)
		var inner := maxf(r_in, f - WAVE_EDGE)
		var outer := minf(r_out, f + WAVE_EDGE)
		_lined(out, "front", true, hot, func(grow: float): return _arc(d, inner - grow, outer + grow, 0.0, TAU),
			{"radius": f, "inner": inner, "outer": outer})
		var ahead := f + WAVE_EDGE + 0.3 + CHEVRON_DEPTH
		if ahead <= r_out:
			_lined(out, "chevrons", true, hot, func(grow: float): return _radial_chevrons(c, ahead, grow), {"outward": true})
		var ring: Array = []
		for i in 49:
			ring.append(_at(c, TAU * i / 48.0, clampf(f, r_in, r_out)))
		_band(out, ring, reach, hot)
		return
	var angle := front_angle(d)
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var sweep := signf(a1 - a0) if a1 != a0 else 1.0
	_lined(out, "front", true, hot, func(grow: float): return _spoke(c, angle, r_in, r_out, WAVE_EDGE + grow),
		{"angle": angle, "offset": maxf(float(d["front"]), 0.0)})
	var tangent := Vector3(-sin(angle), 0.0, cos(angle)) * sweep
	_lined(out, "chevrons", true, hot, func(grow: float): return _sweep_chevrons(c, angle, r_in, r_out, tangent, grow), {"along": sweep})
	var line: Array = []
	for i in 9:
		line.append(_at(c, angle, lerpf(r_in, r_out, i / 8.0)))
	_band(out, line, reach, hot)


static func _projectile(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	var c: Vector3 = d["centre"]
	var r: float = d["r_out"]
	if not motion:
		out.append(_mark("area", _area_layer(d, false), _area_tone(d, SHELL_AREA_ALPHA), _footprint(d)))
		var w := outline_width(d)
		_lined(out, "edge", false, Color(tone, EDGE_ALPHA * 0.8), func(grow: float): return _own_edge_tris(d, grow) if stance(tone) == "owned" else _arc(d, r - w - grow, r + grow, 0.0, TAU),
			{"r_out": r, "centre": c})
		return
	if stance(tone) == "hostile":
		out.append(_grown_fill(d, "fill", _area_tone(d, FILL_ALPHA)))
	if d.has("launch"):
		var arc := _flight_arc(d, 0.0, float(d["progress"]))
		var under := _mark("trace_under", "motion_under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA),
			_flight_arc(d, UNDERLAY * 0.25, float(d["progress"]))["tris"])
		under["abs"] = true
		out.append(under)
		var trace := _mark("trace", "motion", trace_tone(tone), arc["tris"], {"points": arc["points"]})
		trace["abs"] = true
		out.append(trace)


static func _lane(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	var run_tone := _area_tone(d, live_alpha() if live_band(d) else RUN_ALPHA)
	var run_layer := _area_layer(d, true)
	if d["form"] == "lane":
		var length: float = d["length"]
		var half: float = d["half_width"]
		if motion:
			out.append(_grown_fill(d, "run", run_tone, run_layer))
			return
		out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA), _footprint(d)))
		_lined(out, "edge", false, Color(tone, EDGE_ALPHA), func(grow: float): return _edge_tris(d, grow),
			{"half_width": half, "length": length})
		return
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	if motion:
		out.append(_grown_fill(d, "run", run_tone, run_layer))
		return
	out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA), _footprint(d)))
	var c: Vector3 = d["centre"]
	_lined(out, "edge", false, Color(tone, EDGE_ALPHA), func(grow: float): return _spoke(c, a0, r_in, r_out, RAIL + grow) + _spoke(c, a1, r_in, r_out, RAIL + grow),
		{"r_out": r_out})
	_lined(out, "outline", false, Color(tone, EDGE_ALPHA), func(grow: float): return _dashes(d, r_out - RAIL, DASH_HALF + grow, a0, a1), {})
	var mid := (a0 + a1) * 0.5
	var pull: bool = d.get("pull", false)
	var toward := Vector3(cos(mid), 0.0, sin(mid)) * (-1.0 if pull else 1.0)
	_lined(out, "chevrons", false, Color(tone, EDGE_ALPHA), func(grow: float): return _line_chevrons(c, mid, r_in, r_out, toward, grow),
		{"pull": pull})


static func _area_layer(d: Dictionary, motion: bool) -> String:
	if stance(d["tone"]) == "hostile":
		return "stripe_motion" if motion else "stripe"
	return "motion" if motion else "base"


static func live_alpha() -> float:
	return CLEAR_LIVE_ALPHA if soft() else LIVE_ALPHA


static func _area_tone(d: Dictionary, alpha: float) -> Color:
	if look() == "edges":
		alpha *= EDGES_FILL
	if stance(d["tone"]) != "hostile":
		return Color(d["tone"], alpha)
	return Color(Palette.HAZARD, alpha * HAZE_FILL) if haze() else Color(1.0, 1.0, 1.0, alpha)


static func _grown_fill(d: Dictionary, role: String, tone: Color, layer := "") -> Dictionary:
	var span := fill_span(d)
	var tris: PackedVector3Array
	if d["form"] == "lane":
		tris = _lane_strip(d, -float(d["back"]), float(d["length"]) if _live_lane(d) else fill_end(d), -span.y, span.y)
	else:
		tris = _arc(d, span.x, span.y, d["a0"], d["a1"])
	return _mark(role, layer if layer != "" else _area_layer(d, true), tone, tris, {"span": span, "share": fill_share(d)})


static func _fence(out: Array, d: Dictionary) -> void:
	var reach: float = d["reach"]
	if reach <= 0.05:
		return
	var tone: Color = d["tone"]
	var lines := _boundary(d)
	var soft_fence := soft()
	var layer := "fence" if soft_fence else "base"
	if int(d["type"]) == Type.PROJECTILE:
		out.append(_mark("band", layer, Color(tone, CLEAR_SPIKE_ALPHA if soft_fence else SPIKE_ALPHA), _spikes(lines, reach), {"height": reach}))
		return
	var posts := PackedVector3Array()
	for line in lines:
		var run := 0.0
		for i in line.size():
			if i > 0:
				run += (line[i] as Vector3).distance_to(line[i - 1])
			if i == 0 or run >= POST_SPACING:
				run = 0.0
				var at: Vector3 = line[i]
				_wall(posts, at + Vector3(-POST_HALF, 0.0, 0.0), at + Vector3(POST_HALF, 0.0, 0.0), 0.0, reach)
				_wall(posts, at + Vector3(0.0, 0.0, -POST_HALF), at + Vector3(0.0, 0.0, POST_HALF), 0.0, reach)
	if soft_fence:
		out.append(_mark("band", layer, Color(tone, CLEAR_POST_ALPHA), posts, {"height": reach}))
		out.append(_mark("band_top", layer, Color(tone, CLEAR_RAIL_ALPHA), _rail(lines, reach, CLEAR_RAIL_HALF), {"height": reach}))
		return
	out.append(_mark("band", "base", Color(tone, POST_ALPHA), posts, {"height": reach}))
	_lined(out, "band_top", false, Color(tone, RAIL_ALPHA), func(grow: float): return _rail(lines, reach, BAND_TOP + grow), {"height": reach})


static func _spikes(lines: Array, reach: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for line in lines:
		var run := 0.0
		var closed: bool = line.size() > 2 and (line[0] as Vector3).is_equal_approx(line[-1])
		for i in line.size():
			if i > 0:
				run += (line[i] as Vector3).distance_to(line[i - 1])
			if (i > 0 and run < POST_SPACING) or (closed and i == line.size() - 1):
				continue
			run = 0.0
			var at := Vector3((line[i] as Vector3).x, 0.0, (line[i] as Vector3).z)
			for side in [Vector3(SPIKE_HALF, 0.0, 0.0), Vector3(0.0, 0.0, SPIKE_HALF)]:
				tris.append_array(PackedVector3Array([at - side, Vector3(at.x, reach, at.z), at + side]))
	return tris


static func _rail(lines: Array, h: float, half: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for line in lines:
		for i in line.size() - 1:
			_wall(tris, line[i], line[i + 1], h - half, h + half)
	return tris


static func _boundary(d: Dictionary) -> Array:
	var lines: Array = []
	if d["form"] == "lane":
		var half: float = d["half_width"]
		for side in [-1.0, 1.0]:
			lines.append([_lane_at(d, -float(d["back"]), side * half), _lane_at(d, float(d["length"]), side * half)])
		return lines
	var c: Vector3 = d["centre"]
	var r: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var open: Array = d.get("open", [])
	var steps := maxi(4, int(ceil(absf(a1 - a0) * r / LANE_STEP)))
	var line: Array = []
	if not is_full(d):
		line.append(_at(c, a0, float(d["r_in"])))
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		if _is_open(open, a):
			if line.size() > 1:
				lines.append(line)
			line = []
			continue
		line.append(_at(c, a, r))
	if not is_full(d):
		line.append(_at(c, a1, float(d["r_in"])))
	if line.size() > 1:
		lines.append(line)
	return lines


static func _owner_ticks(d: Dictionary, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	if d["form"] == "lane":
		var half: float = d["half_width"]
		var along := -float(d["back"])
		while along <= float(d["length"]):
			for side in [-1.0, 1.0]:
				_seg(tris, _lane_at(d, along, side * (half - 0.8)), _lane_at(d, along, side * (half + 0.4)), 0.2 + grow)
			along += OWNER_SPACING
		return tris
	var c: Vector3 = d["centre"]
	var r: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var count := int(floor(absf(a1 - a0) / OWNER_STEP + 0.001))
	var sweep := signf(a1 - a0) if a1 != a0 else 1.0
	for i in count + (0 if is_full(d) else 1):
		var a := a0 + sweep * OWNER_STEP * i
		if _is_open(d.get("open", []), a):
			continue
		_seg(tris, _at(c, a, r - 1.2), _at(c, a, r + 0.4), 0.2 + grow)
	return tris


static func _radial_chevrons(c: Vector3, r: float, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for i in RADIAL_CHEVRONS:
		var a := TAU * (i + 0.5) / RADIAL_CHEVRONS
		_chevron(tris, _at(c, a, r), Vector3(cos(a), 0.0, sin(a)), CHEVRON_LINE + grow)
	return tris


static func _sweep_chevrons(c: Vector3, angle: float, r_in: float, r_out: float, tangent: Vector3, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for share in SWEEP_CHEVRONS:
		var at := _at(c, angle, lerpf(r_in, r_out, share)) + tangent * (WAVE_EDGE + 0.3 + CHEVRON_DEPTH)
		_chevron(tris, at, tangent, CHEVRON_LINE + grow)
	return tris


static func _line_chevrons(c: Vector3, angle: float, r_in: float, r_out: float, toward: Vector3, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for share in PULL_CHEVRONS:
		_chevron(tris, _at(c, angle, lerpf(r_in, r_out, share)), toward, CHEVRON_LINE + 0.05 + grow)
	return tris


static func _spoke(c: Vector3, angle: float, r0: float, r1: float, half: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	_seg(tris, _at(c, angle, r0), _at(c, angle, r1), half)
	return tris


static func _mark(role: String, layer: String, tone: Color, tris: PackedVector3Array, extra := {}) -> Dictionary:
	var m := {"role": role, "layer": layer, "tone": tone, "tris": tris, "abs": false}
	m.merge(extra, true)
	return m


static func _lined(out: Array, role: String, motion: bool, tone: Color, draw: Callable, extra: Dictionary) -> void:
	out.append(_mark(role + "_under", "motion_under" if motion else "under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA), draw.call(UNDERLAY), extra))
	out.append(_mark(role, "motion" if motion else "base", tone, draw.call(0.0), extra))


static func _band(out: Array, line: Array, reach: float, hot: Color) -> void:
	var wall := PackedVector3Array()
	var top := PackedVector3Array()
	for i in line.size() - 1:
		_wall(wall, line[i], line[i + 1], 0.0, reach)
		_wall(top, line[i], line[i + 1], reach - rail_half(), reach + rail_half())
	out.append(_mark("band", "motion", Color(hot, BAND_ALPHA), wall, {"height": reach}))
	out.append(_mark("band_top", "motion", Color(hot, top_alpha() * hot.a), top, {"height": reach}))


static func rail_half() -> float:
	return CLEAR_RAIL_HALF if soft() else BAND_TOP


static func top_alpha() -> float:
	return CLEAR_BAND_TOP_ALPHA if soft() else 0.8


static func _footprint(d: Dictionary) -> PackedVector3Array:
	if d["form"] == "lane":
		return _lane_strip(d, -float(d["back"]), float(d["length"]), -float(d["half_width"]), float(d["half_width"]))
	return _arc(d, d["r_in"], d["r_out"], d["a0"], d["a1"])


static func _edge_tris(d: Dictionary, grow: float) -> PackedVector3Array:
	if stance(d["tone"]) == "owned":
		return _own_edge_tris(d, grow)
	var tris := PackedVector3Array()
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		var half: float = d["half_width"]
		for side in [-1.0, 1.0]:
			tris.append_array(_lane_strip(d, -back - grow, length + grow, side * half - RAIL - grow, side * half + RAIL + grow))
		tris.append_array(_lane_strip(d, length - CAP - grow, length + grow, -half, half))
		return tris
	var w := edge_width(d)
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	tris.append_array(_arc(d, r_out - w - grow, r_out + grow, a0, a1))
	if r_in > 0.05:
		tris.append_array(_arc(d, r_in - grow, r_in + w + grow, a0, a1))
	if not is_full(d):
		var c: Vector3 = d["centre"]
		for a in [a0, a1]:
			_seg(tris, _at(c, a, r_in), _at(c, a, r_out), w * 0.5 + grow)
	return tris


static func _own_edge_tris(d: Dictionary, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		var half: float = d["half_width"]
		var count := maxi(2, int(round((length + back) / OWN_DASH)))
		for side in [-1.0, 1.0]:
			for i in count:
				tris.append_array(_lane_strip(d, lerpf(-back, length, (i + 0.225) / count) - grow, lerpf(-back, length, (i + 0.775) / count) + grow,
					side * half - RAIL - grow, side * half + RAIL + grow))
		var across := maxi(1, int(round(2.0 * half / OWN_DASH)))
		for i in across:
			tris.append_array(_lane_strip(d, length - CAP - grow, length + grow, lerpf(-half, half, (i + 0.225) / across) - grow,
				lerpf(-half, half, (i + 0.775) / across) + grow))
		return tris
	var w := outline_width(d)
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	tris.append_array(_dashes(d, r_out - w * 0.5, w * 0.5 + grow, a0, a1, OWN_DASH))
	if r_in > 0.05:
		tris.append_array(_dashes(d, r_in + w * 0.5, w * 0.5 + grow, a0, a1, OWN_DASH))
	if not is_full(d):
		var c: Vector3 = d["centre"]
		for a in [a0, a1]:
			var n := maxi(2, int(round((r_out - r_in) / OWN_DASH)))
			for i in n:
				_seg(tris, _at(c, a, lerpf(r_in, r_out, (i + 0.225) / n)), _at(c, a, lerpf(r_in, r_out, (i + 0.775) / n)), w * 0.5 + grow)
	return tris


static func _dashed_outline(d: Dictionary, grow: float) -> PackedVector3Array:
	var w := edge_width(d) * 0.5
	if d["form"] == "lane":
		return _dashed_lane(d, w + grow)
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var tris := _dashes(d, r_out - w, w + grow, a0, a1)
	if r_in > 0.05:
		tris.append_array(_dashes(d, r_in + w, w + grow, a0, a1))
	if not is_full(d):
		var c: Vector3 = d["centre"]
		for a in [a0, a1]:
			var count := maxi(2, int(round((r_out - r_in) / DASH)))
			for i in count:
				var s0 := lerpf(r_in, r_out, (i + 0.225) / count)
				var s1 := lerpf(r_in, r_out, (i + 0.775) / count)
				_seg(tris, _at(c, a, s0), _at(c, a, s1), w + grow)
	return tris


static func _dashed_lane(d: Dictionary, half: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var back: float = d["back"]
	var length: float = d["length"]
	var width: float = d["half_width"]
	var count := maxi(2, int(round((length + back) / DASH)))
	for side in [-1.0, 1.0]:
		for i in count:
			_seg(tris, _lane_at(d, lerpf(-back, length, (i + 0.225) / count), side * width),
				_lane_at(d, lerpf(-back, length, (i + 0.775) / count), side * width), half)
	var across := maxi(1, int(round(2.0 * width / DASH)))
	for i in across:
		_seg(tris, _lane_at(d, length, lerpf(-width, width, (i + 0.225) / across)),
			_lane_at(d, length, lerpf(-width, width, (i + 0.775) / across)), half)
	return tris


static func _dashes(d: Dictionary, r: float, half: float, a0: float, a1: float, period := DASH) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var count := maxi(3, int(round(absf(a1 - a0) * r / period)))
	for i in count:
		var b0 := lerpf(a0, a1, (i + 0.225) / count)
		var b1 := lerpf(a0, a1, (i + 0.775) / count)
		tris.append_array(_arc(d, r - half, r + half, b0, b1))
	return tris


static func _arc(d: Dictionary, r0: float, r1: float, a0: float, a1: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	r0 = maxf(0.0, r0)
	if r1 <= r0:
		return tris
	var c: Vector3 = d["centre"]
	var open: Array = d.get("open", [])
	var span := a1 - a0
	var segs := maxi(1, int(ceil(absf(span) / TAU * SEGMENTS - 0.001)))
	for i in segs:
		var b0 := a0 + span * i / segs
		var b1 := a0 + span * (i + 1) / segs
		if _is_open(open, (b0 + b1) * 0.5):
			continue
		_quad(tris, _at(c, b0, r0), _at(c, b0, r1), _at(c, b1, r1), _at(c, b1, r0))
	return tris


static func _is_open(open: Array, angle: float) -> bool:
	if open.size() != SEGMENTS:
		return false
	return open[int(floor(wrapf(angle, 0.0, TAU) / TAU * SEGMENTS)) % SEGMENTS]


static func _lane_strip(d: Dictionary, from: float, to: float, left: float, right: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	if to <= from:
		return tris
	var steps := maxi(1, int(ceil((to - from) / LANE_STEP)))
	for i in steps:
		var t0 := lerpf(from, to, float(i) / steps)
		var t1 := lerpf(from, to, float(i + 1) / steps)
		_quad(tris, _lane_at(d, t0, left), _lane_at(d, t0, right), _lane_at(d, t1, right), _lane_at(d, t1, left))
	return tris


static func _lane_at(d: Dictionary, along: float, lateral: float) -> Vector3:
	var c: Vector3 = d["centre"]
	var dir: Vector3 = d["dir"]
	var p := c + dir * along + Vector3.UP.cross(dir).normalized() * lateral
	return Vector3(p.x, 0.0, p.z)


static func _chevron(tris: PackedVector3Array, tip: Vector3, forward: Vector3, half: float) -> void:
	var side := Vector3.UP.cross(forward).normalized()
	for s in [-1.0, 1.0]:
		_seg(tris, tip, tip - forward * CHEVRON_DEPTH + side * s * CHEVRON_HALF, half)


static func _at(c: Vector3, angle: float, r: float) -> Vector3:
	return Vector3(c.x + cos(angle) * r, 0.0, c.z + sin(angle) * r)


static func _seg(tris: PackedVector3Array, p: Vector3, q: Vector3, half: float) -> void:
	var along := Vector3(q.x - p.x, 0.0, q.z - p.z)
	if along.length() < 0.001:
		return
	var side := Vector3.UP.cross(along.normalized()) * half
	var a := Vector3(p.x, 0.0, p.z)
	var b := Vector3(q.x, 0.0, q.z)
	_quad(tris, a - side, a + side, b + side, b - side)


static func _wall(tris: PackedVector3Array, p: Vector3, q: Vector3, h0: float, h1: float) -> void:
	_quad(tris, Vector3(p.x, h0, p.z), Vector3(p.x, h1, p.z), Vector3(q.x, h1, q.z), Vector3(q.x, h0, q.z))


static func _quad(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tris.append_array(PackedVector3Array([a, b, c, a, c, d]))


class Painter:
	extends Node3D

	var ground := Callable()
	var ground_many := Callable()
	var floor_y := 0.0
	var lift := 0.2
	var driven := false
	var centre := Vector3.ZERO
	var heading := Vector2(0.0, -1.0)
	var motion_class := "fill"
	var area_class := "area"
	var _live := false
	var _governed := {}
	var _layers := {}
	var _driven_values := {}

	static var _stripes := {}
	# Godot frees a shader when its last material referencing it is freed (~5 ms compile hitch).
	static var _held_looks := {}
	static var _look := ""

	static func look_now() -> String:
		if _look == "":
			var flags := Tuning.new()
			flags.apply_cmdline("launch")
			_look = flags.option(Tuning.FLAGS[TELEGRAPH_FLAG][0])
		return _look

	static func haze_on() -> bool:
		return look_now() != "classic"

	static func soft_on() -> bool:
		return look_now() in ["clear", "edges", "tape"]

	static func striped_on() -> bool:
		return look_now() in ["classic", "tape"]

	static var _materials := {}
	static var materials_built := 0
	static var _warmed := false

	static func mark_key(fill_class: String, stripes: bool, priority: int, governed: bool) -> String:
		return "%s/%s/%d/%s/%s" % [fill_class, stripes, priority, governed, soft_on()]

	static func mark_material(fill_class: String, stripes: bool, priority: int, governed: bool) -> ShaderMaterial:
		var depth := soft_on()
		var key := mark_key(fill_class, stripes, priority, governed)
		if _materials.has(key):
			return _materials[key]
		var code := "shader_type spatial;\n"
		if stripes:
			code += "#define STRIPES\n"
		if depth:
			code += "#define DEPTH_AWARE\n"
		if FILL_STENCIL.has(fill_class):
			code += "stencil_mode read, write, compare_not_equal, %d;\n" % FILL_STENCIL[fill_class]
		code += "#include \"res://assets/shaders/telegraph_mark.gdshaderinc\"\n"
		var shader := Shader.new()
		shader.code = code
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = priority
		mat.set_shader_parameter("governed", 1.0 if governed else 0.0)
		mat.set_shader_parameter("lens", Vector2(FENCE_CLEAR, FENCE_FULL) if fill_class == "fence" else Vector2(LENS_CLEAR, LENS_FULL))
		mat.set_shader_parameter("ink_col", Palette.CHARCOAL)
		mat.set_shader_parameter("is_fill", 1.0 if fill_class in ["fill", "run", "swept"] else 0.0)
		mat.set_shader_parameter("is_fence", 1.0 if fill_class == "fence" else 0.0)
		mat.set_shader_parameter("flash_scale", FlashGuard.info(1.0))
		if depth:
			mat.set_shader_parameter("depth_pull", DEPTH_PULL)
		if stripes:
			mat.set_shader_parameter("texture_albedo", stripe_texture())
			mat.set_shader_parameter("uv1_scale", Vector3.ONE / (STRIPE_PITCH * sqrt(2.0)))
			mat.set_shader_parameter("stripe_pitch", STRIPE_PITCH)
			mat.set_shader_parameter("stripe_tape", 1.0 if soft_on() else 0.0)
			mat.set_shader_parameter("tape_dark", Color(TAPE_SHADE, TAPE_SHADE, TAPE_SHADE))
			mat.set_shader_parameter("tape_share", TAPE_SHARE)
			mat.set_shader_parameter("hazard_col", Palette.HAZARD)
		_materials[key] = mat
		materials_built += 1
		return mat

	static func warm_keys() -> Array:
		var keys := []
		for fill_class in FILL_STENCIL:
			for governed in [false, true]:
				keys.append([fill_class, striped_on(), LIVE_PRIORITY if fill_class == "live" else PRIORITY, governed])
		keys.append(["", false, LINE_UNDER_PRIORITY, false])
		keys.append(["", false, LINE_PRIORITY, false])
		if soft_on():
			keys.append(["", false, PRIORITY, false])
			keys.append(["fence", false, LINE_PRIORITY, false])
		return keys

	static func warm_up(parent: Node) -> Node3D:
		if _warmed or parent == null:
			return null
		_warmed = true
		var holder := Node3D.new()
		parent.add_child(holder)
		var formats := [true, false] if soft_on() else [true]
		for pair in _cross(warm_keys(), formats):
			var key: Array = pair[0]
			var custom: bool = pair[1]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0.0, 0.0), Vector3(0.0, 0.0, 0.01)])
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
			var flags := 0
			if custom:
				arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
				arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
				flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
					| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
			var instance := MeshInstance3D.new()
			instance.top_level = true
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			instance.extra_cull_margin = 16384.0
			instance.mesh = mesh
			instance.material_override = mark_material(key[0], key[1], key[2], key[3])
			instance.sorting_offset = FILL_SORT.get(key[0], 0.0)
			instance.set_instance_shader_parameter("centre", Vector3.ZERO)
			instance.set_instance_shader_parameter("heading", Vector2(0.0, -1.0))
			instance.set_instance_shader_parameter("clip", Vector4.ZERO)
			instance.set_instance_shader_parameter("alpha_scale", 0.0)
			holder.add_child(instance)
		_free_after_frames(holder, 3)
		return holder

	static func _cross(keys: Array, formats: Array) -> Array:
		var out := []
		for key in keys:
			for custom in formats:
				out.append([key, custom])
		return out

	static func _free_after_frames(node: Node, frames: int) -> void:
		var tree := node.get_tree()
		for i in frames:
			await tree.process_frame
		if is_instance_valid(node):
			node.queue_free()

	static func stripe_texture() -> ImageTexture:
		var tape := soft_on()
		if not _stripes.has(tape):
			var size := 128
			var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
			var light := Color.WHITE if tape else Palette.HAZARD
			var dark := Color(TAPE_SHADE, TAPE_SHADE, TAPE_SHADE) if tape else Palette.CHARCOAL
			var band := int(round(size * (1.0 - TAPE_SHARE))) if tape else size / 2
			for y in size:
				for x in size:
					image.set_pixel(x, y, light if (x + y) % size < band else dark)
			image.generate_mipmaps()
			_stripes[tape] = ImageTexture.create_from_image(image)
		return _stripes[tape]

	func paint(all: Array, layers: Array) -> void:
		var heights := _heights_under(all, layers)
		for layer in layers:
			var verts := PackedVector3Array()
			var colors := PackedColorArray()
			var custom := _is_driven(layer)
			var c0 := PackedFloat32Array()
			var c1 := PackedFloat32Array()
			for m in all:
				if m["layer"] != layer:
					continue
				var tone: Color = m["tone"]
				var absolute: bool = m["abs"]
				for v in m["tris"]:
					if absolute:
						verts.append(v)
					else:
						var key := Vector2(v.x, v.z)
						if not heights.has(key):
							heights[key] = ground.call(Vector3(v.x, floor_y, v.z)) if ground.is_valid() else floor_y
						verts.append(Vector3(v.x, heights[key] + lift + v.y, v.z))
					colors.append(tone)
				if custom:
					_append_custom(c0, m.get("c0"), m["tris"].size())
					_append_custom(c1, m.get("c1"), m["tris"].size())
			if layer == "fence" and verts.is_empty() and not _layers.has(layer):
				continue
			_set_layer(layer, verts, colors, c0, c1, custom and layer_governed(all, layer))

	func _heights_under(all: Array, layers: Array) -> Dictionary:
		var heights := {}
		if not ground_many.is_valid():
			return heights
		var keys := PackedVector2Array()
		for m in all:
			if m["abs"] or not layers.has(m["layer"]):
				continue
			for v in m["tris"]:
				var key := Vector2(v.x, v.z)
				if not heights.has(key):
					heights[key] = keys.size()
					keys.append(key)
		var ys: PackedFloat64Array = ground_many.call(keys) if not keys.is_empty() else PackedFloat64Array()
		if ys.size() != keys.size():
			return {}
		for key in keys:
			heights[key] = ys[heights[key]]
		return heights

	static func layer_governed(all: Array, layer: String) -> bool:
		var governed := 0
		var exempt := 0
		for m in all:
			if m["layer"] != layer:
				continue
			if Density.is_shed_exempt(Density.class_of_role(m["role"])):
				exempt += 1
			else:
				governed += 1
		if governed > 0 and exempt > 0:
			push_error("Painter: layer %s mixes governed and exempt roles; left ungoverned" % layer)
		return governed > 0 and exempt == 0 and layer.begins_with("stripe")

	func drive(values: Dictionary) -> void:
		for layer in values:
			var instance: MeshInstance3D = _layers.get(layer)
			if instance == null:
				continue
			var now: Dictionary = values[layer]
			var last: Dictionary = _driven_values.get(layer, {})
			if layer == "stripe_motion" and bool(now.get("live", false)) != _live:
				_live = bool(now.get("live", false))
				_apply_class(layer)
			if last.get("clip") != now["clip"]:
				instance.set_instance_shader_parameter("clip", now["clip"])
			if last.get("alpha") != now["alpha"]:
				instance.set_instance_shader_parameter("alpha_scale", now["alpha"])
			_driven_values[layer] = now

	func tint(layer: String, color: Color) -> void:
		(_layer(layer).material_override as StandardMaterial3D).albedo_color = color

	func _is_driven(layer: String) -> bool:
		return driven and layer in DRIVEN_LAYERS

	static func _append_custom(into: PackedFloat32Array, value, count: int) -> void:
		if value is PackedFloat32Array:
			into.append_array(value)
			return
		var per: Vector4 = value if value is Vector4 else Vector4.ZERO
		for i in count:
			into.append_array([per.x, per.y, per.z, per.w])

	func vertex_count(layer: String) -> int:
		if not _layers.has(layer) or _layers[layer].mesh == null:
			return 0
		return (_layers[layer].mesh as ArrayMesh).surface_get_array_len(0)

	func _set_layer(layer: String, verts: PackedVector3Array, colors: PackedColorArray,
			c0 := PackedFloat32Array(), c1 := PackedFloat32Array(), governed := false) -> void:
		var instance := _layer(layer)
		if _is_driven(layer):
			_governed[layer] = governed
			_apply_class(layer)
		if verts.is_empty():
			instance.mesh = null
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = colors
		var flags := 0
		if _is_driven(layer):
			arrays[Mesh.ARRAY_CUSTOM0] = c0
			arrays[Mesh.ARRAY_CUSTOM1] = c1
			flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
				| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		instance.mesh = mesh

	func _fill_class(layer: String) -> String:
		if not layer.begins_with("stripe"):
			return ""
		if layer == "stripe":
			return area_class
		return "live" if _live else motion_class

	func _apply_class(layer: String) -> void:
		var instance: MeshInstance3D = _layers[layer]
		var fill_class := _fill_class(layer)
		instance.material_override = mark_material(fill_class, layer.begins_with("stripe") and striped_on(), LIVE_PRIORITY if fill_class == "live" else _priority(layer), _governed.get(layer, false))
		instance.sorting_offset = FILL_SORT.get(fill_class, 0.0)

	static func _priority(layer: String) -> int:
		if layer == "crack" or layer == "fence":
			return LINE_PRIORITY
		if layer.ends_with("under"):
			return LINE_UNDER_PRIORITY
		if layer == "base" or layer == "motion":
			return LINE_PRIORITY
		return PRIORITY

	func pull_toward_eye() -> void:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam == null:
			return
		for layer in TINTED_LAYERS:
			if not _layers.has(layer):
				continue
			var instance: MeshInstance3D = _layers[layer]
			if instance.mesh == null or (instance.material_override as StandardMaterial3D).no_depth_test:
				continue
			instance.global_position = Vector3.ZERO
			var middle := instance.global_transform * instance.mesh.get_aabb().get_center()
			instance.global_position = (cam.global_position - middle).normalized() * DEPTH_PULL

	var _pulls := false

	# Godot auto-enables _process at _ready for any script defining _process, so gate it here.
	func _ready() -> void:
		set_process(_pulls)

	func _process(_delta: float) -> void:
		pull_toward_eye()

	func _layer(layer: String) -> MeshInstance3D:
		if _layers.has(layer):
			return _layers[layer]
		var instance := MeshInstance3D.new()
		instance.top_level = true
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if _is_driven(layer):
			instance.extra_cull_margin = 4.0
			instance.set_instance_shader_parameter("centre", centre)
			instance.set_instance_shader_parameter("heading", heading)
			add_child(instance)
			_layers[layer] = instance
			_apply_class(layer)
			return instance
		if soft_on() and not layer in TINTED_LAYERS:
			instance.material_override = mark_material("fence" if layer == "fence" else "", layer.begins_with("stripe") and striped_on(), _priority(layer), false)
			add_child(instance)
			_layers[layer] = instance
			return instance
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = not (soft_on() and layer in TINTED_LAYERS)
		if not mat.no_depth_test:
			_pulls = true
			set_process(true)
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.render_priority = _priority(layer)
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		mat.distance_fade_min_distance = FENCE_CLEAR if layer == "fence" else LENS_CLEAR
		mat.distance_fade_max_distance = FENCE_FULL if layer == "fence" else LENS_FULL
		if layer.begins_with("stripe") and striped_on():
			mat.albedo_texture = stripe_texture()
			mat.uv1_triplanar = true
			mat.uv1_world_triplanar = true
			mat.uv1_scale = Vector3.ONE / (STRIPE_PITCH * sqrt(2.0))
		var look := "striped" if mat.albedo_texture != null else "plain"
		if not _held_looks.has(look):
			_held_looks[look] = mat
		instance.material_override = mat
		if layer == "crack":
			instance.sorting_offset = CRACK_SORT
		add_child(instance)
		_layers[layer] = instance
		return instance


class Flash:
	extends Painter

	var _age := 0.0
	var _tone := Color.WHITE
	var _fill := false
	var _crack := false
	var _dust := Callable()
	var _life := 0.0
	var _crack_alpha := Callable()

	func start(fill: Array, tone: Color, crack: Array, crack_alpha: Callable, dust: Callable, life: float) -> void:
		_tone = tone
		_fill = not fill.is_empty()
		_crack = not crack.is_empty()
		_crack_alpha = crack_alpha
		_dust = dust
		_life = life
		var layers: Array = []
		if _fill:
			layers.append("fill")
		if _crack:
			layers.append("crack")
		paint(fill + crack, layers)
		set_process(true)
		_show(0.0)

	func _ready() -> void:
		set_process(true)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life:
			queue_free()
			return
		_show(_age)

	func _show(age: float) -> void:
		_show_marks(age)
		pull_toward_eye()

	func _show_marks(age: float) -> void:
		if _fill:
			if age >= FLASH_SECONDS:
				_fill = false
				_layer("fill").visible = false
			else:
				tint("fill", Color(_tone, FlashGuard.info(FLASH_ALPHA) * (1.0 - age / FLASH_SECONDS)))
		if _crack:
			tint("crack", Color(1.0, 1.0, 1.0, _crack_alpha.call(age)))
		if _dust.is_valid():
			if age >= DUST_SECONDS:
				_dust = Callable()
				_layer("dust").visible = false
				return
			var dust: Dictionary = _dust.call(age)
			paint([dust], ["dust"])
			tint("dust", Color(1.0, 1.0, 1.0, dust["alpha"]))


static func crack_alpha(age: float) -> float:
	if age <= CRACK_HOLD:
		return CRACK_ALPHA
	return CRACK_ALPHA * clampf(1.0 - (age - CRACK_HOLD) / (CRACK_SECONDS - CRACK_HOLD), 0.0, 1.0)


static func lands(d: Dictionary) -> bool:
	return stance(d["tone"]) == "hostile" and int(d["type"]) != Type.WAVE \
		and not d.get("air", false) and not d.get("aerial", false)


static func landing(d: Dictionary) -> Array:
	if not lands(d):
		return []
	var rng := RandomNumberGenerator.new()
	var c: Vector3 = d["centre"]
	rng.seed = hash(Vector3i((c * 10.0).round()))
	var size: float = d["r_out"] if d["form"] == "radial" else float(d["half_width"]) * 2.0
	var reach := clampf(size * CRACK_LENGTH, CRACK_SHORT, CRACK_LONG)
	var tris := PackedVector3Array()
	for line in _boundary(d):
		_jagged(tris, line, rng)
	var edge := _edge_points(d, rng)
	var from := RAIL + UNDERLAY if d["form"] == "lane" else 0.0
	var puffs: Array = []
	for e in edge:
		var out: Vector3 = e[1]
		var p: Vector3 = e[0] + out * from
		var side := Vector3.UP.cross(out)
		var long := reach * rng.randf_range(0.7, 1.15)
		var bend := side * long * CRACK_JAG * (1.0 if rng.randf() < 0.5 else -1.0)
		var mid := p + out * long * 0.5 + bend
		var tip := p + out * long + side * long * rng.randf_range(-0.15, 0.15)
		_seg(tris, p - out * CRACK_HALF * 2.0, mid, CRACK_HALF)
		_seg(tris, mid, tip, CRACK_HALF * 0.7)
		if rng.randf() < 0.5:
			_seg(tris, mid, mid + (out - bend.normalized() * 0.8).normalized() * long * 0.45, CRACK_HALF * 0.6)
		puffs.append([p, out])
	return [_mark("crack", "crack", Palette.CHARCOAL, tris, {"cracks": edge.size()}),
		_mark("dust", "dust", DUST_TONE, PackedVector3Array(), {"puffs": puffs})]


static func dust_tris(puffs: Array, throw: float, t: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var half := DUST_SIZE * 0.5 * (1.0 + DUST_SWELL * t)
	for puff in puffs:
		var out: Vector3 = puff[1]
		var at: Vector3 = puff[0] + out * (DUST_KICK * throw + half)
		at.y = float(puff[2]) if puff.size() > 2 else 0.0
		var side := Vector3.UP.cross(out)
		_quad(tris, at - out * half, at + side * half, at + out * half, at - side * half)
	return tris


static func _jagged(tris: PackedVector3Array, line: Array, rng: RandomNumberGenerator) -> void:
	for i in line.size() - 1:
		var p: Vector3 = line[i]
		var q: Vector3 = line[i + 1]
		var side := Vector3.UP.cross(q - p).normalized()
		var mid := (p + q) * 0.5 + side * rng.randf_range(-CRACK_RING_JAG, CRACK_RING_JAG)
		_seg(tris, p, mid, CRACK_RING_HALF)
		_seg(tris, mid, q, CRACK_RING_HALF)


static func _edge_points(d: Dictionary, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		var half: float = d["half_width"]
		var dir: Vector3 = Vector3(d["dir"].x, 0.0, d["dir"].z).normalized()
		var right := Vector3.UP.cross(dir).normalized()
		var per_side := clampi(int(round((length + back) / CRACK_STEP)), CRACK_MIN / 2, CRACK_MAX / 2)
		for s in [-1.0, 1.0]:
			for i in per_side:
				var along := lerpf(-back, length, (i + rng.randf_range(0.3, 0.7)) / per_side)
				out.append([_lane_at(d, along, s * half), right * s])
		var cap := maxi(1, int(round(half * 2.0 / CRACK_STEP)))
		for i in cap:
			out.append([_lane_at(d, length, lerpf(-half, half, (i + 0.5) / cap)), dir])
		return out
	var c: Vector3 = d["centre"]
	var r: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var open: Array = d.get("open", [])
	var count := clampi(int(round(absf(a1 - a0) * r / CRACK_STEP)), CRACK_MIN, CRACK_MAX)
	for i in count:
		var a := lerpf(a0, a1, (i + rng.randf_range(0.3, 0.7)) / count)
		if _is_open(open, a):
			continue
		out.append([_at(c, a, r), Vector3(cos(a), 0.0, sin(a))])
	return out


static func flash(parent: Node, d: Dictionary, floor_y: float, lift: float, ground := Callable(), ground_many := Callable()) -> Node3D:
	var instant := int(d["type"]) == Type.INSTANT
	var landed := landing(d)
	if not instant and landed.is_empty():
		return null
	var node := Flash.new()
	node.floor_y = floor_y
	node.lift = lift
	node.ground = ground
	node.ground_many = ground_many
	parent.add_child(node)
	var fill := marks(d, false).filter(func(m): return m["layer"] == "fill") if instant else []
	var crack := landed.filter(func(m): return m["layer"] == "crack")
	var puffs: Array = landed[1]["puffs"] if landed.size() > 1 else []
	for puff in puffs:
		var at: Vector3 = puff[0]
		puff.append((ground.call(Vector3(at.x, floor_y, at.z)) if ground.is_valid() else floor_y) + lift)
	var dust := Callable()
	if not puffs.is_empty():
		dust = func(age: float) -> Dictionary: return dust_at(puffs, age)
	node.start(fill, d["tone"], crack, crack_alpha, dust, flash_life(not fill.is_empty(), not crack.is_empty(), not puffs.is_empty()))
	return node


static func flash_life(fill: bool, crack: bool, dust: bool) -> float:
	var out := FLASH_SECONDS if fill else 0.0
	if crack:
		out = maxf(out, CRACK_SECONDS)
	if dust:
		out = maxf(out, DUST_SECONDS)
	return out


static func dust_at(puffs: Array, age: float) -> Dictionary:
	var t := clampf(age / DUST_SECONDS, 0.0, 1.0)
	var throw := (1.0 - (1.0 - t) * (1.0 - t)) * EnemyMotion.motion_scale
	var grounded: bool = not puffs.is_empty() and (puffs[0] as Array).size() > 2
	return _mark("dust", "dust", DUST_TONE, dust_tris(puffs, throw, t), {"alpha": DUST_ALPHA * (1.0 - t), "abs": grounded})
