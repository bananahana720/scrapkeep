extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# One grammar for every enemy threat, drawn by combat's telegraph.gd and the boss's
# hazard.gd. The attack type decides how a threat draws; its committed geometry decides
# where. Each node builds its descriptor from the same fields its contains() reads, so
# the drawing and the damage use the same numbers (TH-03 AO-08, TH-16 RR-01).
#
# Four types, told apart by shape, fill, motion and sound, never by colour alone
# (VISUAL-LANGUAGE.md sections 3 and 4).
#   INSTANT     a sharp edge; a striped fill closes in from the edge over the warning,
#               and a solid flash marks the landing.
#   WAVE        the whole reach dashed and faint; a bright front at its real position
#               (speed x elapsed) with chevrons the way it travels, a curtain as tall as
#               its height band, and 15% stripes over the ground it has swept.
#   PROJECTILE  a dotted flight trace from the launcher to the landing point, eaten as
#               the shell flies, and a reticle whose brackets close on the blast edge.
#   LANE        rails along the strip, and a striped fill that runs from the source.
#
# The tone says whose it is. HAZARD is hostile: its areas carry 45-degree HAZARD and
# charcoal stripes, it warns with its type's sound, and a boss's brass `owner` becomes a
# tick every 30 degrees on the rim. AMBER is the player's own: clean fills, no stripes,
# no warn sound. Bone (Palette.SAND) is a harmless field: a dashed ring and nothing else.
# Every line sits on a charcoal keyline, because HAZARD on sandstone is only 1.3:1.
# Instant, projectile and lane draw their height band (RR-02) as posts and a top rail at
# `reach`; a wave draws it as a curtain on its front.
#
# A descriptor is a Dictionary:
#   type      Type
#   form      "radial" (centre, r_in, r_out, a0, a1, open) or "lane" (centre, dir, back,
#             length, half_width); angles are atan2(z, x) about +y
#   reach     the height band above the ground a jump clears
#   progress  0 to 1 across the warning; live: true once the attack has landed or runs
#   front     WAVE: the front's radius (full circle) or angle offset from a0 (sector); -1
#             while arming
#   launch, bump   PROJECTILE: flight_point() from launch to centre
#   tone, live_tone, pull (a wedge that pulls toward its apex), owner (a rim tick colour)

enum Type { INSTANT, WAVE, PROJECTILE, LANE }

const UNSET := -1
const KINDS := ["threat_instant", "threat_wave", "threat_projectile", "threat_lane"]
const GROUP := "threat"

const PRIORITY := 40
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
const EDGE_MIN := 0.35
const EDGE_PER_METRE := 0.04
const RAIL := 0.25
const UNDERLAY := 0.35
const UNDERLAY_ALPHA := 0.85
# Half the width of a wave's front: the band drawn and the band contains() tests.
const WAVE_EDGE := 1.0
const DASH := 2.2
const CHEVRON_HALF := 1.6
const CHEVRON_DEPTH := 1.3
const CHEVRON_LINE := 0.2
const RADIAL_CHEVRONS := 8
const SWEEP_CHEVRONS := [0.3, 0.6, 0.9]
const PULL_CHEVRONS := [0.3, 0.55, 0.8]
const BAND_ALPHA := 0.16
const BAND_TOP := 0.12
const BRACKET_OPEN := 1.6
const BRACKET_SHUT := 0.72
const DOT_SPACING := 1.6
const DOT_SIZE := 0.22
const TRACE_ALPHA := 0.85
const LANE_STEP := 2.0
const STRIPE_PITCH := 0.5
const POST_SPACING := 4.0
const POST_HALF := 0.06
const POST_ALPHA := 0.35
const RAIL_ALPHA := 0.7
const OWNER_STEP := PI / 6.0
const OWNER_SPACING := 4.0

# Layers whose name starts with "stripe" draw the hostile stripe pattern.
const STATIC_LAYERS := ["under", "stripe", "base", "fill"]
const MOTION_LAYERS := ["motion_under", "stripe_motion", "motion"]


# hostile (HAZARD), owned (the player's, AMBER) or neutral (a harmless bone field).
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


# The event_kinds row: sound id, glyph shape and priority for this type.
static func row(type: int) -> Dictionary:
	return EventKinds.THREAT_ROWS.get(kind(type), {})


static func bright(tone: Color) -> Color:
	return tone.lightened(0.35)


# A lob with a fixed flight time is a straight line plus a parabola: projectile.gd's
# ballistic solve is this with bump = 0.5 * gravity * flight^2.
static func flight_point(launch: Vector3, landing: Vector3, bump: float, s: float) -> Vector3:
	return launch.lerp(landing, s) + Vector3.UP * bump * s * (1.0 - s)


static func lob_bump(gravity: float, seconds: float) -> float:
	return 0.5 * gravity * seconds * seconds


static func edge_width(d: Dictionary) -> float:
	return maxf(EDGE_MIN, float(d.get("r_out", 0.0)) * EDGE_PER_METRE)


static func is_full(d: Dictionary) -> bool:
	return absf(float(d["a1"]) - float(d["a0"])) >= TAU - 0.001


# WAVE on a sector: the angle the front stands at.
static func front_angle(d: Dictionary) -> float:
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	var sweep := signf(a1 - a0) if a1 != a0 else 1.0
	return a0 + sweep * clampf(maxf(float(d["front"]), 0.0), 0.0, absf(a1 - a0))


# The solid layer shows only while an INSTANT area is live (slag stays molten); the
# landing flash reuses its geometry.
static func fill_tint(d: Dictionary) -> Color:
	if int(d["type"]) != Type.INSTANT or not d.get("live", false):
		return Color(0.0, 0.0, 0.0, 0.0)
	var live_tone: Color = d.get("live_tone", d["tone"])
	return Color(live_tone, LIVE_ALPHA)


# Every mark a descriptor draws, static (drawn once) or motion (redrawn as it runs).
# A mark: role, layer, tone, tris (y is height above the ground unless abs), and the
# numbers its role stands for, which the tests compare with contains().
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


# --- The four types ----------------------------------------------------------------

static func _instant(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	if motion:
		var p: float = 1.0 if d.get("live", false) else float(d["progress"])
		if d["form"] == "lane":
			var half: float = d["half_width"]
			var tris := _lane_strip(d, -float(d["back"]), float(d["length"]), -half, -half + p * half)
			tris.append_array(_lane_strip(d, -float(d["back"]), float(d["length"]), half - p * half, half))
			out.append(_mark("fill", _area_layer(d, true), _area_tone(d, FILL_ALPHA), tris, {"inner": half - p * half}))
			return
		var inner := lerpf(float(d["r_out"]), float(d["r_in"]), p)
		out.append(_mark("fill", _area_layer(d, true), _area_tone(d, FILL_ALPHA), _arc(d, inner, d["r_out"], d["a0"], d["a1"]), {"inner": inner}))
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
		out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA * 1.4), _footprint(d)))
		var w := edge_width(d) * 0.6
		_lined(out, "edge", false, Color(tone, EDGE_ALPHA * 0.8), func(grow: float): return _arc(d, r - w - grow, r + grow, 0.0, TAU),
			{"r_out": r})
		_lined(out, "pip", false, Color(tone, EDGE_ALPHA), func(grow: float): return _pip(c, grow), {"centre": c})
		return
	var p: float = d["progress"]
	var gap := r * lerpf(BRACKET_OPEN, BRACKET_SHUT, p)
	_lined(out, "bracket", true, Color(bright(tone), EDGE_ALPHA), func(grow: float): return _brackets(c, gap, r, grow),
		{"centre": c, "gap": gap})
	if d.has("launch"):
		var launch: Vector3 = d["launch"]
		var bump: float = d["bump"]
		var steps := clampi(int((launch.distance_to(c) + bump * 0.5) / DOT_SPACING), 6, 48)
		var points := PackedVector3Array()
		var tris := PackedVector3Array()
		for i in range(1, steps + 1):
			var s := float(i) / steps
			if s < p:
				continue
			var at := flight_point(launch, c, bump, s)
			points.append(at)
			_dot(tris, at, DOT_SIZE)
		var keyline := PackedVector3Array()
		for at in points:
			_dot(keyline, at, DOT_SIZE + 0.08)
		var under := _mark("trace_under", "motion_under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA), keyline)
		under["abs"] = true
		out.append(under)
		var trace := _mark("trace", "motion", Color(bright(tone), TRACE_ALPHA), tris, {"points": points})
		trace["abs"] = true
		out.append(trace)


static func _lane(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	var live: bool = d.get("live", false)
	var p: float = 1.0 if live else float(d["progress"])
	var run_tone := _area_tone(d, LIVE_ALPHA if live else RUN_ALPHA)
	var run_layer := _area_layer(d, true)
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		var half: float = d["half_width"]
		if motion:
			var end := -back + p * (length + back)
			out.append(_mark("run", run_layer, run_tone, _lane_strip(d, -back, end, -half * 0.9, half * 0.9), {"from": -back, "to": end}))
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
		var reach_r := lerpf(r_in, r_out, p)
		out.append(_mark("run", run_layer, run_tone, _arc(d, r_in, reach_r, a0, a1), {"from": r_in, "to": reach_r}))
		return
	out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA), _footprint(d)))
	var c: Vector3 = d["centre"]
	_lined(out, "edge", false, Color(tone, EDGE_ALPHA), func(grow: float): return _spoke(c, a0, r_in, r_out, RAIL + grow) + _spoke(c, a1, r_in, r_out, RAIL + grow),
		{"r_out": r_out})
	_lined(out, "outline", false, Color(tone, EDGE_ALPHA), func(grow: float): return _dashes(d, r_out - RAIL, RAIL * 1.4 + grow, a0, a1), {})
	var mid := (a0 + a1) * 0.5
	var pull: bool = d.get("pull", false)
	var toward := Vector3(cos(mid), 0.0, sin(mid)) * (-1.0 if pull else 1.0)
	_lined(out, "chevrons", false, Color(tone, EDGE_ALPHA), func(grow: float): return _line_chevrons(c, mid, r_in, r_out, toward, grow),
		{"pull": pull})


# Hostile areas draw on the stripe layers in white, so the stripe texture shows through.
static func _area_layer(d: Dictionary, motion: bool) -> String:
	if stance(d["tone"]) == "hostile":
		return "stripe_motion" if motion else "stripe"
	return "motion" if motion else "base"


static func _area_tone(d: Dictionary, alpha: float) -> Color:
	return Color(1.0, 1.0, 1.0, alpha) if stance(d["tone"]) == "hostile" else Color(d["tone"], alpha)


# RR-02 for the ground types: posts every POST_SPACING metres along the outer boundary
# and a rail at `reach`, the height a jump must clear.
static func _fence(out: Array, d: Dictionary) -> void:
	var reach: float = d["reach"]
	if reach <= 0.05:
		return
	var tone: Color = d["tone"]
	var lines := _boundary(d)
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
	out.append(_mark("band", "base", Color(tone, POST_ALPHA), posts, {"height": reach}))
	_lined(out, "band_top", false, Color(tone, RAIL_ALPHA), func(grow: float): return _rail(lines, reach, BAND_TOP + grow), {"height": reach})


static func _rail(lines: Array, h: float, half: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for line in lines:
		for i in line.size() - 1:
			_wall(tris, line[i], line[i + 1], h - half, h + half)
	return tris


# The outer boundary as polylines, broken where a quenched span leaves a gap.
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


# A boss's mark on its own attack: a brass tick every 30 degrees on the rim, or every
# OWNER_SPACING metres along a lane's rails (VISUAL-LANGUAGE.md section 4).
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


static func _pip(c: Vector3, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	_seg(tris, c + Vector3(-0.7, 0.0, 0.0), c + Vector3(0.7, 0.0, 0.0), 0.12 + grow)
	_seg(tris, c + Vector3(0.0, 0.0, -0.7), c + Vector3(0.0, 0.0, 0.7), 0.12 + grow)
	return tris


# --- Shared pieces ------------------------------------------------------------------

static func _mark(role: String, layer: String, tone: Color, tris: PackedVector3Array, extra := {}) -> Dictionary:
	var m := {"role": role, "layer": layer, "tone": tone, "tris": tris, "abs": false}
	m.merge(extra, true)
	return m


# A line and the wider charcoal band under it, so HAZARD still reads on the orange
# Spillway checker. draw(grow) returns the line's tris widened by grow.
static func _lined(out: Array, role: String, motion: bool, tone: Color, draw: Callable, extra: Dictionary) -> void:
	out.append(_mark(role + "_under", "motion_under" if motion else "under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA), draw.call(UNDERLAY), extra))
	out.append(_mark(role, "motion" if motion else "base", tone, draw.call(0.0), extra))


# A curtain along a ground line, as tall as the band a jump clears, with a bright rail
# along its top: the height the attack reaches is drawn, not implied (RR-02).
static func _band(out: Array, line: Array, reach: float, hot: Color) -> void:
	var wall := PackedVector3Array()
	var top := PackedVector3Array()
	for i in line.size() - 1:
		_wall(wall, line[i], line[i + 1], 0.0, reach)
		_wall(top, line[i], line[i + 1], reach - BAND_TOP, reach + BAND_TOP)
	out.append(_mark("band", "motion", Color(hot, BAND_ALPHA), wall, {"height": reach}))
	out.append(_mark("band_top", "motion", Color(hot, 0.8 * hot.a), top, {"height": reach}))


static func _footprint(d: Dictionary) -> PackedVector3Array:
	if d["form"] == "lane":
		return _lane_strip(d, -float(d["back"]), float(d["length"]), -float(d["half_width"]), float(d["half_width"]))
	return _arc(d, d["r_in"], d["r_out"], d["a0"], d["a1"])


# The solid boundary: rings inside the radial edge, or rails and a far cap on a lane.
static func _edge_tris(d: Dictionary, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		var half: float = d["half_width"]
		for side in [-1.0, 1.0]:
			tris.append_array(_lane_strip(d, -back - grow, length + grow, side * half - RAIL - grow, side * half + RAIL + grow))
		tris.append_array(_lane_strip(d, length - RAIL * 2.0 - grow, length + grow, -half, half))
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


static func _dashed_outline(d: Dictionary, grow: float) -> PackedVector3Array:
	var w := edge_width(d) * 0.5
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


static func _dashes(d: Dictionary, r: float, half: float, a0: float, a1: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var count := maxi(3, int(round(absf(a1 - a0) * r / DASH)))
	for i in count:
		var b0 := lerpf(a0, a1, (i + 0.225) / count)
		var b1 := lerpf(a0, a1, (i + 0.775) / count)
		tris.append_array(_arc(d, r - half, r + half, b0, b1))
	return tris


# A band between two radii over an angle range, leaving quenched segments undrawn.
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


static func _brackets(c: Vector3, gap: float, r: float, grow: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var arm := maxf(0.8, gap * 0.4)
	var half := 0.14 + r * 0.015 + grow
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner := Vector3(c.x + sx * gap, 0.0, c.z + sz * gap)
			_seg(tris, corner, corner - Vector3(sx * arm, 0.0, 0.0), half)
			_seg(tris, corner, corner - Vector3(0.0, 0.0, sz * arm), half)
	return tris


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


# Three crossed squares: a dot that reads from any camera angle.
static func _dot(tris: PackedVector3Array, at: Vector3, s: float) -> void:
	_quad(tris, at + Vector3(-s, -s, 0.0), at + Vector3(s, -s, 0.0), at + Vector3(s, s, 0.0), at + Vector3(-s, s, 0.0))
	_quad(tris, at + Vector3(0.0, -s, -s), at + Vector3(0.0, -s, s), at + Vector3(0.0, s, s), at + Vector3(0.0, s, -s))
	_quad(tris, at + Vector3(-s, 0.0, -s), at + Vector3(s, 0.0, -s), at + Vector3(s, 0.0, s), at + Vector3(-s, 0.0, s))


static func _quad(tris: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tris.append_array(PackedVector3Array([a, b, c, a, c, d]))


# --- Drawing ------------------------------------------------------------------------

# One top-level mesh per layer in world space. Underlays draw at PRIORITY - 1 and the
# rest at PRIORITY, with no depth test, above every player effect (combat note 10).
class Painter:
	extends Node3D

	# (Vector3) -> float, the ground under a point; unset draws flat at floor_y.
	var ground := Callable()
	var floor_y := 0.0
	var lift := 0.2
	var _layers := {}

	static var _stripes: ImageTexture

	# 45-degree HAZARD and charcoal stripes, one period per texture repeat.
	static func stripe_texture() -> ImageTexture:
		if _stripes == null:
			var size := 32
			var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
			for y in size:
				for x in size:
					image.set_pixel(x, y, Palette.HAZARD if (x + y) % size < size / 2 else Palette.CHARCOAL)
			image.generate_mipmaps()
			_stripes = ImageTexture.create_from_image(image)
		return _stripes

	func paint(all: Array, layers: Array) -> void:
		var heights := {}
		for layer in layers:
			var verts := PackedVector3Array()
			var colors := PackedColorArray()
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
			_set_layer(layer, verts, colors)

	func tint(layer: String, color: Color) -> void:
		(_layer(layer).material_override as StandardMaterial3D).albedo_color = color

	func vertex_count(layer: String) -> int:
		if not _layers.has(layer) or _layers[layer].mesh == null:
			return 0
		return (_layers[layer].mesh as ArrayMesh).surface_get_array_len(0)

	func _set_layer(layer: String, verts: PackedVector3Array, colors: PackedColorArray) -> void:
		var instance := _layer(layer)
		if verts.is_empty():
			instance.mesh = null
			return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		instance.mesh = mesh

	func _layer(layer: String) -> MeshInstance3D:
		if _layers.has(layer):
			return _layers[layer]
		var instance := MeshInstance3D.new()
		instance.top_level = true
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.render_priority = PRIORITY - 1 if layer.ends_with("under") else PRIORITY
		if layer.begins_with("stripe"):
			mat.albedo_texture = stripe_texture()
			mat.uv1_triplanar = true
			mat.uv1_world_triplanar = true
			mat.uv1_scale = Vector3.ONE / (STRIPE_PITCH * sqrt(2.0))
		instance.material_override = mat
		add_child(instance)
		_layers[layer] = instance
		return instance


# The solid flash an INSTANT threat leaves where it landed; it outlives the telegraph
# its owner frees on the landing tick, then fades.
class Flash:
	extends Painter

	var _age := 0.0
	var _tone := Color.WHITE

	func start(fill: Array, tone: Color) -> void:
		_tone = tone
		paint(fill, ["fill"])
		tint("fill", Color(_tone, FLASH_ALPHA))

	func _process(delta: float) -> void:
		_age += delta
		if _age >= FLASH_SECONDS:
			queue_free()
			return
		tint("fill", Color(_tone, FLASH_ALPHA * (1.0 - _age / FLASH_SECONDS)))


static func flash(parent: Node, d: Dictionary, floor_y: float, lift: float) -> Node3D:
	var node := Flash.new()
	node.floor_y = floor_y
	node.lift = lift
	parent.add_child(node)
	node.start(marks(d, false).filter(func(m): return m["layer"] == "fill"), d["tone"])
	return node
