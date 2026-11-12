extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Density := preload("res://src/presentation/density.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")

# One grammar for every enemy threat, drawn by combat's telegraph.gd and the boss's
# hazard.gd. The attack type decides how a threat draws; its committed geometry decides
# where. Each node builds its descriptor from the same fields its contains() reads, so
# the drawing and the damage use the same numbers (TH-03 AO-08, TH-16 RR-01).
#
# Four types, told apart by shape, fill, motion and sound, never by colour alone
# (VISUAL-LANGUAGE.md sections 3 and 4).
#   INSTANT     a sharp edge; a striped fill grows from the centre over the warning,
#               and a solid flash marks the landing.
#   WAVE        the whole reach dashed and faint; a bright front at its real position
#               (speed x elapsed) with chevrons the way it travels, a curtain as tall as
#               its height band, and 15% stripes over the ground it has swept.
#   PROJECTILE  a thin dashed flight arc from the launcher that ends on the landing point,
#               eaten as the shell flies, over an edge and a fill that grows from the centre.
#   LANE        rails along the strip, and a striped fill that grows from its centre line.
#
# The pending fill (wave 36, PF-16): every ground hit but a wave fills from the shape's
# centre (its centre point, its centre line, or a band's middle) toward its outline, and
# its front meets the outline's inner face on the hit tick and not before (fill_span), so a
# shape that looks full means now. The fill never draws under the outline. The live look
# (fill_tint, the live lane's class) is unchanged.
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
#   air       true when only a ball in the air can be caught (the netcaster); drawing only

enum Type { INSTANT, WAVE, PROJECTILE, LANE }

const UNSET := -1
const KINDS := ["threat_instant", "threat_wave", "threat_projectile", "threat_lane"]
const GROUP := "threat"

const PRIORITY := 40
# Draw layers by render priority, back to front: the charcoal keylines under the fills
# (their base look), the fills at PRIORITY, a live lane's band one above (it wins over the
# other fills), then every hot P1 line above that band (FEEL-READABILITY.md section 1.1: a
# P1 line is never covered by a fill). A keyline stays under the fills, because lifting it
# over them changes every telegraph's look (measured 0.3 to 0.7 percent of the frame,
# over the still budget); inside a live band it is dimmed, the hot line above it is not.
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
# The landing (FX-05, effects critique E5): when a hostile ground mark goes live, an ink crack
# ring and a dust kick at its edge put the hit's cause on the floor at its moment, after the
# telegraph that drew the edge is gone. The ring is the edge redrawn as a jagged charcoal line
# with short cracks running out of it; the dust is bone puffs thrown outward from the edge.
# Ink, not light, so Reduce flashes leaves it whole; Reduced motion keeps the puffs in place.
# Crack: one per CRACK_STEP metres of edge (CRACK_MIN to CRACK_MAX), each CRACK_LENGTH of the
# mark's size long (clamped), held CRACK_HOLD seconds and gone by CRACK_SECONDS.
const CRACK_SECONDS := 0.5
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
# The crack's zigzag: its middle steps sideways this share of its length; the ring's corners
# step in or out by up to CRACK_RING_JAG metres.
const CRACK_JAG := 0.3
const CRACK_RING_JAG := 0.12
# Dust: one puff per crack, DUST_SIZE across at the edge, thrown DUST_KICK metres out and
# swelling by DUST_SWELL while it fades over DUST_SECONDS.
const DUST_SECONDS := 0.35
const DUST_ALPHA := 0.75
const DUST_SIZE := 0.45
const DUST_KICK := 1.1
const DUST_SWELL := 0.8
const DUST_TONE := Color("ece3cc")
const EDGE_MIN := 0.35
const EDGE_PER_METRE := 0.04
# The widest an outline is drawn, metres: a 30 m ring's edge was 1.2 m of solid line.
const EDGE_MAX := 0.6
# The shell's flight arc: the dash's share of each step, and the half width of its ribbon.
const TRACE_DASH := 0.7
const TRACE_HALF := 0.07
const RAIL := 0.25
# A lane's far cap is this deep (_edge_tris); its pending fill stops at the cap's inner face.
const CAP := RAIL * 2.0
# A pull wedge's dashed outline: half width, standing RAIL inside r_out (_lane).
const DASH_HALF := RAIL * 1.4
# A shell's ring edge is this share of edge_width (_projectile).
const SHELL_EDGE := 0.6
# A live lane's band runs this share of its half width, the full length (as before wave 36).
const LIVE_LANE := 0.9
const UNDERLAY := 0.35
# The keyline is opaque: HAZARD (L* 60.7) sits level with the pale floors, so the edge's lightness
# step is the keyline's, and Forward+ blends in linear light, where 0.85 charcoal over the noon
# Slag Bowl deck left only 18.8 to 21.0 L* (3060, #498 comment 6428905151; tools/keyline_floor_capture.gd).
const UNDERLAY_ALPHA := 1.0
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

# --telegraph=haze (Tuning.FLAGS, the default; classic is the other option): a hostile floor
# fill becomes a red haze with no hazard stripes. Every fill alpha scales by the one
# HAZE_FILL, so each stencil class still holds one alpha and the LIVE / RUN ratio the drive
# hands the shader is unchanged; the P1 lines, their keylines, the geometry, contains() and
# the drive clips are not touched. LIVE_SCORCH is the live INSTANT slag layer's tone.
# HAZE_FILL is the first 0.05 step at which the fill clears every place by at least 0.5 over the
# 10 CIE76 floor (tools/grade_probe.gd; rulings #241 6328893598 and 6331787112). On the 3060
# (#241 comment 6331769617) the lowest gap, camp ledger, was 8.65 at 1.0, 10.03 at 1.1 and 10.72
# at 1.15.
# Above 1.25 the live alpha (LIVE_ALPHA x HAZE_FILL) passes 1.0.
# LIVE_SCORCH / LIVE_SCORCH_ALPHA: the live slag is drawn over the pending fill, which stays on
# (p = 1 once live), and live must read clearly different from pending at chase distance
# (ATTACK-READS.md:27: "Clear live/pending distinctions and safe holes survive haze."). More
# HAZARD cannot add value contrast: ff5a3c is L* 60.7 and the pale floors are L* 64 to 67, so on
# the 3060 live minus pending was -1.2 L* at stage 2 and +0.3 in the arena (#241 6342833117).
# So the live slag is a dark scorched core, HAZARD.lerp(CHARCOAL, LIVE_SCORCH) at
# LIVE_SCORCH_ALPHA, under the unchanged HAZARD edge and keyline. Linear-light model over grey
# L* 67: pending 64.2, live about 48 at (0.4, 0.8), a 16 L* step. The 3060 sweep at 512b636f
# (#241 6345835130) measured live 13.0 L* under pending in stage 2 and 11.4 in the arena, and the
# coordinator kept 0.4 / 0.8 (#241 6345854759); haze_pose_capture --scorch / --live-alpha sweeps
# the candidates either side.
# AIR_LIVE_ALPHA: an air-only mark (the netcaster's net, which catches the ball only in the air)
# must not wear the scorch, which reads as the strongest ground hit and sends the player off the
# ground. It keeps the pre-scorch look at this fill: HAZARD at 0.61, the HAZE_SOLID that cf302195
# paired with HAZE_FILL 1.15 (ruling #241 6331787112; the stage's 0.4 would sit level with the
# 0.4025 pending fill). Rulings #241 6347013047 section 4 and 6347979378. On the 3060 this tint
# read -1.2 / +0.3 L* live minus pending (6342833117), so E07's live cue belongs in the air band
# (the wave 19 card), not in this fill.
const HAZE_FILL := 1.15
const LIVE_SCORCH := 0.4
const LIVE_SCORCH_ALPHA := 0.8
const AIR_LIVE_ALPHA := 0.61
const TELEGRAPH_FLAG := "telegraph"


# Whether the haze look is on: set_haze() (tests, tools), else the launcher flag, read once
# through Tuning's own parse so a repeated flag resolves the same way (the last wins). A
# running game re-reads the telegraph row at each stage entry and retry (follow_row).
# The state lives on Painter, whose static code cannot call this class's statics.
static func haze() -> bool:
	return Painter.haze_on()


static func set_haze(on: bool) -> void:
	Painter._haze = 1 if on else 0


# The F1 telegraph row takes effect at the next stage entry or retry. A flip re-warms the
# mark pipelines, since the haze look draws with a different material key.
static func follow_row(tuning) -> void:
	var on: bool = tuning.option(Tuning.TELEGRAPH_KEY) == "haze"
	if on != haze():
		set_haze(on)
		Painter._warmed = false


# Layers whose name starts with "stripe" draw the hostile stripe pattern.
const STATIC_LAYERS := ["under", "stripe", "base", "fill"]
const MOTION_LAYERS := ["motion_under", "stripe_motion", "motion"]
# The layers a driven painter draws with threat_mark.gdshaderinc.
const DRIVEN_LAYERS := ["stripe", "stripe_motion", "motion", "motion_under"]

# How a driven mark follows the frame (threat_mark.gdshaderinc names each one).
enum Drive { PASS, RADIAL, LANE, DOTS, CHEVRON, CURTAIN }
const FAR := 1.0e9
const CURTAIN_STEPS := 48
# P6 fill classes: the stencil value a class writes and tests, so overlapping fills of
# one class draw once (E1-DENSITY.md section 2), and a sorting offset that runs each class
# as one contiguous batch under every line at the same priority. A class writes over
# another's value, so the batches must not interleave for the union to hold. Fills unioned
# in one class must share an alpha, or the overlap shows whichever drew first and flips
# with camera depth, so a class exists per alpha:
#   area   INSTANT and LANE footprints (AREA_ALPHA)
#   reach  a PROJECTILE's footprint (AREA_ALPHA * 1.4), its own class since fix round 2
#   fill, swept, run  the INSTANT fill, a WAVE's swept ground, a pending LANE's run
#   live   a LANE that is damaging (LIVE_ALPHA). It renders one priority above the other
#          fills (LIVE_PRIORITY), so its band draws over a pending run, a fill and a swept
#          ring from every camera depth, as the base drew it whenever the lane sorted nearer.
#          Every P1 line (LINE_UNDER_PRIORITY, LINE_PRIORITY) draws above it. Lanes still
#          union with lanes of their own class.
const FILL_STENCIL := {"fill": 1, "area": 2, "swept": 4, "run": 8, "live": 16, "reach": 32}
# Offsets are spaced at least 1000 apart: only their order matters, and a gap under the
# camera far plane (700 m) could let depth sort reorder two classes.
const FILL_SORT := {"area": -6000.0, "reach": -5000.0, "fill": -4000.0, "run": -3000.0, "swept": -2000.0, "live": -1000.0}


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
	return clampf(float(d.get("r_out", 0.0)) * EDGE_PER_METRE, EDGE_MIN, EDGE_MAX)


# How far the warning has run for the pending fill: 0 at commit, 1 on the hit tick and live.
static func fill_share(d: Dictionary) -> float:
	return 1.0 if d.get("live", false) else clampf(float(d.get("progress", 0.0)), 0.0, 1.0)


# The ground the outline leaves for the fill: [lo, hi] between the outline's inner faces, in
# radius for a radial, in |lateral| for a lane (whose far cap ends it at fill_end()).
# Clamped: a shape narrower than its outline leaves no room, never a reversed span.
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


# How far a radial outline reaches in from its edge: a ring's edge (a shell's is SHELL_EDGE of
# it), or a pull wedge's dashed outline, RAIL in plus DASH_HALF.
static func outline_width(d: Dictionary) -> float:
	match int(d["type"]):
		Type.PROJECTILE:
			return edge_width(d) * SHELL_EDGE
		Type.LANE:
			return RAIL + DASH_HALF
	return edge_width(d)


# A lane's pending fill runs from its back end to the inner face of its far cap (_edge_tris).
static func fill_end(d: Dictionary) -> float:
	return maxf(-float(d["back"]), float(d["length"]) - CAP)


# A live LANE's band, as before wave 36: LIVE_LANE of the half width along the full length, or
# a radial one from r_in to r_out.
static func _live_lane(d: Dictionary) -> bool:
	return int(d["type"]) == Type.LANE and live_band(d)


# Whether a live mark draws its dense live band. A lane with a running front (`front_m`, Brindle's
# charge: only the hull's nose hurts) keeps its pending look, a light full fill inside strong
# rails, so a camera inside it still sees the floor, the ball and the edges (PF-16: the live band
# turned the lower screen flat orange before the hull arrived).
static func live_band(d: Dictionary) -> bool:
	return d.get("live", false) and not d.has("front_m")


# The fill now, along the grow axis (a live lane's band: _live_lane): from the centre (a disc from r 0, a band from
# its middle out to both edges, a lane from its centre line out to both rails), reaching
# fill_room's faces at fill_share 1 and inside them before.
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
	if haze() and stance(d["tone"]) == "hostile":
		if d.get("air", false):
			return Color(d.get("live_tone", d["tone"]), AIR_LIVE_ALPHA)
		return Color(Palette.HAZARD.lerp(Palette.CHARCOAL, LIVE_SCORCH), LIVE_SCORCH_ALPHA)
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


# --- Driven drawing (E1-DENSITY.md section 1) ----------------------------------------
# A combat telegraph builds its motion marks once, at full extent, each vertex tagged with
# how it follows the frame; drive(d) then hands the frame's numbers to the shader. The
# numbers are the same expressions marks(d, true) draws, so both paths draw one shape. A
# sector wave (a boss hazard's) stays on marks(), and so does a wave that is not hostile:
# its swept ground would share the "motion" layer with its front, and drive() gives a
# layer one clip, so the swept clip would overwrite the front's (E1 fix round, finding 5b).

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


# Per layer, the frame's clip and alpha scale (threat_mark.gdshaderinc), plus the numbers
# they stand for, which the tests compare with contains().
static func drive(d: Dictionary) -> Dictionary:
	var out := {}
	var live: bool = d.get("live", false)
	match int(d["type"]):
		Type.INSTANT:
			# No "live" key: a live INSTANT keeps its fill class, under the scorch tint (as base).
			out[_area_layer(d, true)] = _span_clip(d, 1.0)
		Type.LANE:
			var band := live_band(d)
			var entry := _span_clip(d, LIVE_ALPHA / RUN_ALPHA if band else 1.0)
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
			# The flight arc keeps a dash while the shell has not passed its end.
			var arc := {"clip": Vector4(0.0, 0.0, float(d["progress"]), 0.0), "alpha": 1.0}
			out["motion"] = arc
			out["motion_under"] = arc
	return out


# A pending fill's clip (threat_mark: radial keeps r in [clip.x, clip.y]; a lane keeps along in
# [clip.x, clip.y] and |lateral| in [clip.z, clip.w]) and the span it stands for.
static func _span_clip(d: Dictionary, alpha: float) -> Dictionary:
	var span := fill_span(d)
	var clip := Vector4(span.x, span.y, 0.0, 0.0)
	if d["form"] == "lane":
		clip = Vector4(-FAR, float(d["length"]) if _live_lane(d) else fill_end(d), -1.0, span.y)
	return {"clip": clip, "alpha": alpha, "span": span, "share": fill_share(d)}


static func _driven(m: Dictionary, drive_mode: int, scaled := 0.0, grow := 0.0) -> Dictionary:
	m["c1"] = Vector4(drive_mode, scaled, grow, 0.0)
	return m


# One hot line and its charcoal keyline, as _lined draws them; build(grow) returns the
# line's mark widened by grow.
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
		_wall(top, _at(c, a0, r_out), _at(c, a1, r_out), reach - BAND_TOP, reach + BAND_TOP)
		for a in [a0, a0, a1, a0, a1, a1]:
			rays.append_array([cos(a), sin(a), 0.0, 0.0])
	var band := _driven(_mark("band", "motion", Color(hot, BAND_ALPHA), wall, {"height": reach}), Drive.CURTAIN)
	band["c0"] = rays
	out.append(band)
	var band_top := _driven(_mark("band_top", "motion", Color(hot, 0.8), top, {"height": reach}), Drive.CURTAIN, 1.0)
	band_top["c0"] = rays
	out.append(band_top)


static func _driven_projectile(d: Dictionary, out: Array) -> void:
	# Only a hostile shell's landing fills: a batted (AMBER) shell is the player's own, and its fill
	# would share the "motion" layer with the trace, a governed fill beside an exempt line.
	if stance(d["tone"]) == "hostile":
		out.append(_driven(_mark("fill", _area_layer(d, true), _area_tone(d, FILL_ALPHA), _footprint(d)), Drive.RADIAL))
	if not d.has("launch"):
		return
	var arc := _flight_arc(d, 0.0)
	var under := _driven(_mark("trace_under", "motion_under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA), _flight_arc(d, UNDERLAY * 0.25)["tris"]), Drive.DOTS)
	under["abs"] = true
	under["c0"] = arc["shares"]
	out.append(under)
	var trace := _driven(_mark("trace", "motion", Color(bright(d["tone"]), TRACE_ALPHA), arc["tris"], {"points": arc["points"]}), Drive.DOTS)
	trace["abs"] = true
	trace["c0"] = arc["shares"]
	out.append(trace)


# The shell's flight as a thin dashed arc (PF-25: a chain of squares read as placeholders):
# one dash per step, two crossed ribbons TRACE_HALF + grow wide, so it reads as a line from any
# camera. Dash i covers [i + 1 - TRACE_DASH, i + 1] / steps of the flight, so the last dash
# ends on the landing point; a dash whose end the shell has passed (share < from) is left out.
# tris; points, each dash's end on the flight; shares, each vertex's dash end (Drive.DOTS).
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


# --- The four types ----------------------------------------------------------------

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
		out.append(_mark("area", _area_layer(d, false), _area_tone(d, AREA_ALPHA * 1.4), _footprint(d)))
		var w := outline_width(d)
		_lined(out, "edge", false, Color(tone, EDGE_ALPHA * 0.8), func(grow: float): return _arc(d, r - w - grow, r + grow, 0.0, TAU),
			{"r_out": r})
		_lined(out, "pip", false, Color(tone, EDGE_ALPHA), func(grow: float): return _pip(c, grow), {"centre": c})
		return
	if stance(tone) == "hostile":
		out.append(_grown_fill(d, "fill", _area_tone(d, FILL_ALPHA)))
	if d.has("launch"):
		var arc := _flight_arc(d, 0.0, float(d["progress"]))
		var under := _mark("trace_under", "motion_under", Color(Palette.CHARCOAL, UNDERLAY_ALPHA),
			_flight_arc(d, UNDERLAY * 0.25, float(d["progress"]))["tris"])
		under["abs"] = true
		out.append(under)
		var trace := _mark("trace", "motion", Color(bright(tone), TRACE_ALPHA), arc["tris"], {"points": arc["points"]})
		trace["abs"] = true
		out.append(trace)


static func _lane(d: Dictionary, motion: bool, out: Array) -> void:
	var tone: Color = d["tone"]
	var run_tone := _area_tone(d, LIVE_ALPHA if live_band(d) else RUN_ALPHA)
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


# Hostile areas draw on the stripe layers in white, so the stripe texture shows through
# (under haze, in HAZARD red with no texture).
static func _area_layer(d: Dictionary, motion: bool) -> String:
	if stance(d["tone"]) == "hostile":
		return "stripe_motion" if motion else "stripe"
	return "motion" if motion else "base"


static func _area_tone(d: Dictionary, alpha: float) -> Color:
	if stance(d["tone"]) != "hostile":
		return Color(d["tone"], alpha)
	return Color(Palette.HAZARD, alpha * HAZE_FILL) if haze() else Color(1.0, 1.0, 1.0, alpha)


# The pending fill of the one ground grammar: the room between the outline's inner faces, from
# the centre out (fill_span). span and share are the numbers the tests compare with contains().
static func _grown_fill(d: Dictionary, role: String, tone: Color, layer := "") -> Dictionary:
	var span := fill_span(d)
	var tris: PackedVector3Array
	if d["form"] == "lane":
		tris = _lane_strip(d, -float(d["back"]), float(d["length"]) if _live_lane(d) else fill_end(d), -span.y, span.y)
	else:
		tris = _arc(d, span.x, span.y, d["a0"], d["a1"])
	return _mark(role, layer if layer != "" else _area_layer(d, true), tone, tris, {"span": span, "share": fill_share(d)})


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


# --- Drawing ------------------------------------------------------------------------

# One top-level mesh per layer in world space. Underlays draw at PRIORITY - 1 and the
# rest at PRIORITY, with no depth test, above every player effect (combat note 10).
class Painter:
	extends Node3D

	# (Vector3) -> float, the ground under a point; unset draws flat at floor_y.
	var ground := Callable()
	# (PackedVector2Array) -> PackedFloat64Array, the ground under many (x, z) points in one ask;
	# an empty answer leaves each point to ground.
	var ground_many := Callable()
	var floor_y := 0.0
	var lift := 0.2
	# A driven painter (a combat telegraph) draws DRIVEN_LAYERS with the shared
	# threat_mark shaders, builds its motion marks once and moves them with drive().
	var driven := false
	var centre := Vector3.ZERO
	var heading := Vector2(0.0, -1.0)
	# The P6 class of the stripe_motion layer: "fill" (an INSTANT fill, a LANE run) or
	# "swept" (a WAVE's swept ground).
	var motion_class := "fill"
	# The stencil class of the "stripe" (footprint) layer; a PROJECTILE's is "reach".
	var area_class := "area"
	var _live := false
	var _governed := {}
	var _layers := {}
	var _driven_values := {}

	static var _stripes: ImageTexture
	# The first material of each look a line layer draws with (plain or striped), held for the
	# session. A mark's StandardMaterial3D is its own, since tint() writes it, and when the last
	# material with a look is freed Godot frees that look's shader too: the next mark compiled it
	# again, about 5 ms on the 4080, once a lobber volley came after the last ring had gone.
	static var _held_looks := {}
	static var _haze := -1  # -1 unread, 0 classic, 1 haze

	static func haze_on() -> bool:
		if _haze < 0:
			var flags := Tuning.new()
			flags.apply_cmdline("launch")
			_haze = 1 if flags.option(Tuning.FLAGS[TELEGRAPH_FLAG][0]) == "haze" else 0
		return _haze == 1

	static var _materials := {}
	# Materials created so far; a run that has warmed up must not raise it.
	static var materials_built := 0
	static var _warmed := false

	# One shared material per (stencil class, stripes, priority, governed), so every driven
	# telegraph draws with the same few materials. governed comes from the layer's roles
	# (layer_governed), not from the stencil class.
	static func mark_material(fill_class: String, stripes: bool, priority: int, governed: bool) -> ShaderMaterial:
		var key := "%s/%s/%d/%s" % [fill_class, stripes, priority, governed]
		if _materials.has(key):
			return _materials[key]
		var code := "shader_type spatial;\n"
		if stripes:
			code += "#define STRIPES\n"
		if FILL_STENCIL.has(fill_class):
			code += "stencil_mode read, write, compare_not_equal, %d;\n" % FILL_STENCIL[fill_class]
		code += "#include \"res://src/combat/threat_mark.gdshaderinc\"\n"
		var shader := Shader.new()
		shader.code = code
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = priority
		mat.set_shader_parameter("governed", 1.0 if governed else 0.0)
		if stripes:
			mat.set_shader_parameter("texture_albedo", stripe_texture())
			mat.set_shader_parameter("uv1_scale", Vector3.ONE / (STRIPE_PITCH * sqrt(2.0)))
		_materials[key] = mat
		materials_built += 1
		return mat

	# Every (class, stripes, priority, governed) a driven telegraph can ask mark_material
	# for: each fill class governed or not, and the two line layers.
	static func warm_keys() -> Array:
		var keys := []
		for fill_class in FILL_STENCIL:
			for governed in [false, true]:
				keys.append([fill_class, not haze_on(), LIVE_PRIORITY if fill_class == "live" else PRIORITY, governed])
		keys.append(["", false, LINE_UNDER_PRIORITY, false])
		keys.append(["", false, LINE_PRIORITY, false])
		return keys

	# Compiles every mark pipeline before play: one driven-format triangle per key, at zero
	# alpha, kept in view for a few frames and then freed. Without it the first live lane or
	# projectile compiles its shader mid-fight. Once per process; the materials are shared.
	static func warm_up(parent: Node) -> Node3D:
		if _warmed or parent == null:
			return null
		_warmed = true
		var holder := Node3D.new()
		parent.add_child(holder)
		for key in warm_keys():
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.01, 0.0, 0.0), Vector3(0.0, 0.0, 0.01)])
			arrays[Mesh.ARRAY_COLOR] = PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])
			arrays[Mesh.ARRAY_CUSTOM0] = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			arrays[Mesh.ARRAY_CUSTOM1] = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
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

	static func _free_after_frames(node: Node, frames: int) -> void:
		var tree := node.get_tree()
		for i in frames:
			await tree.process_frame
		if is_instance_valid(node):
			node.queue_free()

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
			_set_layer(layer, verts, colors, c0, c1, custom and layer_governed(all, layer))

	# The ground under every grounded vertex paint() will draw, read in one ask of ground_many.
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

	# Whether the density governor fades a driven layer: every role on it is a governed
	# class in Density.CLASS_OF_ROLE (P6 fills). P6 is hostile ground, so only the stripe
	# layers qualify; an owned or neutral fill on "motion" stays as it drew before E1. A
	# layer that mixes a governed role with an exempt one stays exempt and reports it,
	# since fading it would fade a P1 line.
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

	# The frame's numbers for each driven layer (Threat.drive); only changed values reach
	# the renderer.
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

	# The stencil class a driven layer's fills union in, "" for a line layer.
	func _fill_class(layer: String) -> String:
		if not layer.begins_with("stripe"):
			return ""
		if layer == "stripe":
			return area_class
		return "live" if _live else motion_class

	# The layer's shared material and batch for its current stencil class.
	func _apply_class(layer: String) -> void:
		var instance: MeshInstance3D = _layers[layer]
		var fill_class := _fill_class(layer)
		instance.material_override = mark_material(fill_class, layer.begins_with("stripe") and not haze_on(), LIVE_PRIORITY if fill_class == "live" else _priority(layer), _governed.get(layer, false))
		instance.sorting_offset = FILL_SORT.get(fill_class, 0.0)

	static func _priority(layer: String) -> int:
		if layer == "crack":
			return LINE_PRIORITY
		if layer.ends_with("under"):
			return LINE_UNDER_PRIORITY
		if layer == "base" or layer == "motion":
			return LINE_PRIORITY
		return PRIORITY

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
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.no_depth_test = true
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.render_priority = _priority(layer)
		if layer.begins_with("stripe") and not haze_on():
			mat.albedo_texture = stripe_texture()
			mat.uv1_triplanar = true
			mat.uv1_world_triplanar = true
			mat.uv1_scale = Vector3.ONE / (STRIPE_PITCH * sqrt(2.0))
		var look := "striped" if mat.albedo_texture != null else "plain"
		if not _held_looks.has(look):
			_held_looks[look] = mat
		instance.material_override = mat
		add_child(instance)
		_layers[layer] = instance
		return instance


# What a hostile mark leaves where it lands, on the tick it goes live: an INSTANT's solid flash
# over its footprint, and for every ground mark but a wave (its running front is its landing)
# the ink crack ring and dust kick at its edge (landing()). It outlives the telegraph its owner
# frees on the landing tick, then fades.
class Flash:
	extends Painter

	var _age := 0.0
	var _tone := Color.WHITE
	var _fill := false
	var _crack := false
	var _dust := Callable()
	var _life := 0.0
	var _crack_alpha := Callable()

	# fill: the INSTANT's solid marks; crack: the ink marks; crack_alpha(age) their alpha;
	# dust(age): the dust mark at that age, or unset with no dust. The painter's own code
	# cannot call the grammar's statics, so Threat.flash hands them in.
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
		_show(0.0)

	func _process(delta: float) -> void:
		_age += delta
		if _age >= _life:
			queue_free()
			return
		_show(_age)

	func _show(age: float) -> void:
		if _fill:
			tint("fill", Color(_tone, FlashGuard.info(FLASH_ALPHA) * maxf(0.0, 1.0 - age / FLASH_SECONDS)))
		if _crack:
			tint("crack", Color(1.0, 1.0, 1.0, _crack_alpha.call(age)))
		if _dust.is_valid():
			var dust: Dictionary = _dust.call(age)
			paint([dust], ["dust"])
			tint("dust", Color(1.0, 1.0, 1.0, dust["alpha"]))


# The crack ring's alpha at `age` seconds after the landing: held, then gone by CRACK_SECONDS.
static func crack_alpha(age: float) -> float:
	if age <= CRACK_HOLD:
		return CRACK_ALPHA
	return CRACK_ALPHA * clampf(1.0 - (age - CRACK_HOLD) / (CRACK_SECONDS - CRACK_HOLD), 0.0, 1.0)


# Whether a descriptor leaves the landing marks when it goes live: a hostile mark on the
# ground. A wave's landing is its running front; an air-only net and an aerial ring hit the
# ball in the air, where a floor crack would point the wrong way.
static func lands(d: Dictionary) -> bool:
	return stance(d["tone"]) == "hostile" and int(d["type"]) != Type.WAVE \
		and not d.get("air", false) and not d.get("aerial", false)


# The landing's marks from the committed descriptor: "crack" (the ink ring and its cracks, on
# the crack layer) and "dust" (no tris; its "puffs" are [edge point, outward] pairs the Flash
# throws each frame through dust_tris). Seeded by the mark's centre, so a landing draws the
# same every time. Empty when the mark does not land (lands()).
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
	var puffs: Array = []
	for e in edge:
		var p: Vector3 = e[0]
		var out: Vector3 = e[1]
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


# The dust puffs `throw` (0 to 1) of the way out and `t` (0 to 1) through their life: a
# diamond per puff, DUST_SIZE across at the edge, swelling by DUST_SWELL.
static func dust_tris(puffs: Array, throw: float, t: float) -> PackedVector3Array:
	var tris := PackedVector3Array()
	var half := DUST_SIZE * 0.5 * (1.0 + DUST_SWELL * t)
	for puff in puffs:
		var out: Vector3 = puff[1]
		var at: Vector3 = puff[0] + out * (DUST_KICK * throw + half)
		var side := Vector3.UP.cross(out)
		_quad(tris, at - out * half, at + side * half, at + out * half, at - side * half)
	return tris


# The edge redrawn in ink: each boundary step split at a midpoint stepped in or out.
static func _jagged(tris: PackedVector3Array, line: Array, rng: RandomNumberGenerator) -> void:
	for i in line.size() - 1:
		var p: Vector3 = line[i]
		var q: Vector3 = line[i + 1]
		var side := Vector3.UP.cross(q - p).normalized()
		var mid := (p + q) * 0.5 + side * rng.randf_range(-CRACK_RING_JAG, CRACK_RING_JAG)
		_seg(tris, p, mid, CRACK_RING_HALF)
		_seg(tris, mid, q, CRACK_RING_HALF)


# Where the cracks and puffs leave the edge, as [point, outward] pairs: spaced about
# CRACK_STEP along a radial mark's rim (skipping its open gaps) or a lane's rails and far cap.
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


static func flash(parent: Node, d: Dictionary, floor_y: float, lift: float) -> Node3D:
	var node := Flash.new()
	node.floor_y = floor_y
	node.lift = lift
	parent.add_child(node)
	var fill := marks(d, false).filter(func(m): return m["layer"] == "fill")
	var landed := landing(d)
	var crack := landed.filter(func(m): return m["layer"] == "crack")
	var puffs: Array = landed[1]["puffs"] if landed.size() > 1 else []
	var dust := Callable()
	if not puffs.is_empty():
		dust = func(age: float) -> Dictionary: return dust_at(puffs, age)
	node.start(fill, d["tone"], crack, crack_alpha, dust, flash_life(not fill.is_empty(), not crack.is_empty(), not puffs.is_empty()))
	return node


# How long a landing's Flash lives: the longest of its parts.
static func flash_life(fill: bool, crack: bool, dust: bool) -> float:
	var out := FLASH_SECONDS if fill else 0.0
	if crack:
		out = maxf(out, CRACK_SECONDS)
	if dust:
		out = maxf(out, DUST_SECONDS)
	return out


# The dust mark `age` seconds after the landing, with its layer alpha: thrown out on an
# ease-out (not at all under Reduced motion) and fading over DUST_SECONDS.
static func dust_at(puffs: Array, age: float) -> Dictionary:
	var t := clampf(age / DUST_SECONDS, 0.0, 1.0)
	var throw := (1.0 - (1.0 - t) * (1.0 - t)) * EnemyMotion.motion_scale
	return _mark("dust", "dust", DUST_TONE, dust_tris(puffs, throw, t), {"alpha": DUST_ALPHA * (1.0 - t)})
