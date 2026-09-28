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
# fix round 2, finding 11/§1.1: P6 hostile-fill layers ("stripe", "stripe_motion", "fill")
# draw below P5 (vfx.gd's P5_RENDER_PRIORITY = 20) and below P1-P3 (PRIORITY above).
const UNION_PRIORITY := 10
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
static func _raw_marks(d: Dictionary, motion: bool) -> Array:
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


# The live-drawable marks: _raw_marks with this frame's union suppression applied, so a
# unioned member's fill/area/swept/run role (§1.3.1) stops drawing here, without
# telegraph.gd or hazard.gd (out of this unit's write set) needing to change -- both
# already call Threat.marks() to get what their own Painter draws every frame. roles()
# and all_marks() below stay on _raw_marks, unfiltered: the clustering decision itself
# (suppressed_roles, union_fill_marks_for) must never read its own output, or suppression
# could get stuck reinforcing itself a frame late.
static func marks(d: Dictionary, motion: bool) -> Array:
	var out := _raw_marks(d, motion)
	var suppressed: Array = active_suppressed_roles(d)
	if suppressed.is_empty():
		return out
	return out.filter(func(m): return not (m["role"] in suppressed))


static func all_marks(d: Dictionary) -> Array:
	return _raw_marks(d, false) + _raw_marks(d, true)


static func roles(d: Dictionary) -> Array:
	var out: Array = []
	for m in all_marks(d):
		if not m["layer"].ends_with("under") and not m["role"] in out:
			out.append(m["role"])
	out.sort()
	return out


# --- Hostile fills at scale: union past four overlapping (§1.3.1, F1a) -----------------
# RR-06 already says overlapping fills add no brightness (_area_tone flattens a hostile
# fill to white so the stripe texture, not additive alpha, carries it). This extends
# that: past four overlapping hostile fills in view, they draw as one shared union at
# FILL_ALPHA and each member keeps only its edge, front, bracket and rail marks. These
# functions are pure over a list of descriptors (never mutate one), so a caller viewing
# the current frame's hostile threats can ask what to union and what to hide, while
# every descriptor's own fields, and so contains(), are untouched.

# Roles a unioned member no longer draws for itself; the shared union mark stands in.
const SUPPRESSED_BY_UNION := ["area", "fill", "swept", "run"]


static func _centre_of(d: Dictionary) -> Vector3:
	if d["form"] == "lane":
		var back: float = d["back"]
		var length: float = d["length"]
		return (d["centre"] as Vector3) + (d["dir"] as Vector3) * (length - back) * 0.5
	return d["centre"]


static func _extent_of(d: Dictionary) -> float:
	if d["form"] == "lane":
		return maxf(float(d["length"]) + float(d["back"]), float(d["half_width"])) * 0.5 + 1.0
	return float(d["r_out"])


static func _bounds_overlap(a: Dictionary, b: Dictionary) -> bool:
	return _centre_of(a).distance_to(_centre_of(b)) <= _extent_of(a) + _extent_of(b)


# fix round 2, finding 13 (blocker): this whole clustering path used to cost real time
# every frame -- suppressed_roles() and union_fill_marks_for() each called
# _hostile_indices(), which called roles() per descriptor, which built that descriptor's
# full static and motion mark GEOMETRY just to read role names; and clustering ran
# Bron-Kerbosch (no pivot), which grows exponentially in the hostile count, paid even
# when nothing unions. Both are replaced:
#
#  - _hostile_indices below is a cheap type/progress predicate, not role() geometry: a
#    hostile INSTANT, PROJECTILE or LANE always emits its "area" role's static mark
#    (_instant/_projectile/_lane's non-motion branch, unconditionally), so it always
#    counts; a hostile WAVE only emits "swept" once it is no longer arming
#    (float(d["front"]) >= 0.0, see _wave's motion branch). No mark geometry is built.
#  - _union_groups is the ONE place clustering runs; suppressed_roles() and
#    union_fill_marks_for() both call it, and refresh_union() (the live per-frame path)
#    calls it once and reuses the result for both, instead of computing it twice.
#  - clustering itself is a coverage-depth count over the existing 2 m grid -- a cell
#    more than cap_hostile_union() real footprints cover -- which matches "more than four
#    overlapping fills" literally (a point genuinely covered by 5 real shapes) and costs
#    O(cells x n), with n restricted to members that even have cap_hostile_union()
#    bounds-overlapping neighbours first (a point covered by more than `cap` real
#    footprints implies every pair among them has overlapping bounds -- both circles
#    contain that shared point -- so this prefilter drops nothing a real group needs, and
#    it also gives "4 or fewer hostile fills in view" its own early exit for free).
#  - grid cells are grouped into connected regions (4-connected flood fill); a region's
#    group is every member that covers any of its cells, so one union mark still covers
#    one continuous over-dense patch, the same shape the old maximal-clique version drew.

const UNION_GROUP_STEP := 2.0


static func _is_hostile_fill(d: Dictionary) -> bool:
	if stance(d["tone"]) != "hostile":
		return false
	if int(d["type"]) == Type.WAVE:
		return float(d.get("front", -1.0)) >= 0.0
	return true


# Hostile descriptors that currently draw a fill/area/swept/run role at all (finding 5a):
# a WAVE still arming, for instance, draws no such role yet and must not count toward
# "more than four overlapping fills", even though it is a hostile threat.
static func _hostile_indices(descriptors: Array) -> Array:
	var out: Array = []
	for i in descriptors.size():
		if _is_hostile_fill(descriptors[i]):
			out.append(i)
	return out


# Every maximal coverage-depth group of hostile fills whose real footprints overlap more
# than cap_hostile_union() deep at some shared point, as Array[int] indices into
# `descriptors`. The one shared computation suppressed_roles() and union_fill_marks_for()
# both build on (finding 13).
static func _union_groups(descriptors: Array) -> Array:
	var hostile_idx := _hostile_indices(descriptors)
	var cap := cap_hostile_union()
	if hostile_idx.size() <= cap:
		return []
	var hostile_descs: Array = []
	for i in hostile_idx:
		hostile_descs.append(descriptors[i])
	var degree: Array = []
	degree.resize(hostile_descs.size())
	for i in degree.size():
		degree[i] = 0
	for i in hostile_descs.size():
		for j in range(i + 1, hostile_descs.size()):
			if _bounds_overlap(hostile_descs[i], hostile_descs[j]):
				degree[i] += 1
				degree[j] += 1
	var candidates: Array = []
	for i in hostile_descs.size():
		if degree[i] >= cap:
			candidates.append(i)
	if candidates.size() <= cap:
		return []
	var candidate_descs: Array = []
	for i in candidates:
		candidate_descs.append(hostile_descs[i])
	var cell_owners := _coverage_cells(candidate_descs, cap)
	if cell_owners.is_empty():
		return []
	var out: Array = []
	for region in _connected_regions(cell_owners):
		var members := {}
		for cell in region:
			for local_i in cell_owners[cell]:
				members[local_i] = true
		if members.size() > cap:
			var group: Array = []
			for local_i in members:
				group.append(hostile_idx[candidates[local_i]])
			group.sort()
			out.append(group)
	return out


# Rasterizes `descs`' combined bounding box into a 2 m grid and returns, for every cell
# more than `cap` of them cover (tested at the cell centre against the real footprint,
# the same predicate contains() reads), the "ix,iz" cell key -> covering local indices.
static func _coverage_cells(descs: Array, cap: int) -> Dictionary:
	var out := {}
	if descs.is_empty():
		return out
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for d in descs:
		var c := _centre_of(d)
		var e := _extent_of(d)
		min_x = minf(min_x, c.x - e)
		max_x = maxf(max_x, c.x + e)
		min_z = minf(min_z, c.z - e)
		max_z = maxf(max_z, c.z + e)
	var half := UNION_GROUP_STEP * 0.5
	var iz := 0
	var z := min_z + half
	while z <= max_z + 0.001:
		var ix := 0
		var x := min_x + half
		while x <= max_x + 0.001:
			var p := Vector3(x, 0.0, z)
			var covering: Array = []
			for i in descs.size():
				if _point_in_footprint(descs[i], p):
					covering.append(i)
			if covering.size() > cap:
				out["%d,%d" % [ix, iz]] = covering
			ix += 1
			x += UNION_GROUP_STEP
		iz += 1
		z += UNION_GROUP_STEP
	return out


static func _connected_regions(cell_owners: Dictionary) -> Array:
	var seen := {}
	var regions: Array = []
	for key in cell_owners:
		if seen.has(key):
			continue
		var stack: Array = [key]
		var region: Array = []
		seen[key] = true
		while not stack.is_empty():
			var cur: String = stack.pop_back()
			region.append(cur)
			var parts := cur.split(",")
			var cx := int(parts[0])
			var cz := int(parts[1])
			for delta in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
				var nk := "%d,%d" % [cx + delta[0], cz + delta[1]]
				if cell_owners.has(nk) and not seen.has(nk):
					seen[nk] = true
					stack.append(nk)
		regions.append(region)
	return regions


static func _angle_in_sector(angle: float, a0: float, a1: float) -> bool:
	var span := a1 - a0
	if absf(span) >= TAU - 0.001:
		return true
	if span >= 0.0:
		return wrapf(angle - a0, 0.0, TAU) <= span + 0.001
	return wrapf(a0 - angle, 0.0, TAU) <= -span + 0.001


# Point-membership test for a descriptor's static footprint (the same r_in..r_out arc or
# lane strip _footprint()'s triangles cover), used only to rasterize the union below.
static func _point_in_footprint(d: Dictionary, point: Vector3) -> bool:
	if d["form"] == "lane":
		var centre: Vector3 = d["centre"]
		var dir: Vector3 = d["dir"]
		var lateral_dir: Vector3 = Vector3.UP.cross(dir).normalized()
		var rel := point - centre
		var along := rel.dot(dir)
		var lateral := rel.dot(lateral_dir)
		return along >= -float(d["back"]) and along <= float(d["length"]) and absf(lateral) <= float(d["half_width"])
	var centre2: Vector3 = d["centre"]
	var radius := Vector2(point.x - centre2.x, point.z - centre2.z).length()
	if radius < float(d["r_in"]) or radius > float(d["r_out"]):
		return false
	var angle := atan2(point.z - centre2.z, point.x - centre2.x)
	if not _angle_in_sector(angle, float(d["a0"]), float(d["a1"])):
		return false
	return not _is_open(d.get("open", []), angle)


const UNION_GRID_STEP := 2.0
const UNION_MIN_STEP := 0.25
# The union mark's own draw height above ground (finding 6/14): telegraph.gd's own LIFT
# is 0.2; matched here since the union mostly stands in for telegraph-sourced fills.
const UNION_LIFT := 0.2


# Rasterizes the cluster's combined static footprint into shared grid cells and emits one
# quad per covered cell, so members that overlap never draw over each other inside the
# same mesh (finding 5c): concatenating raw per-member triangles instead would alpha-blend
# every place two footprints cross, so the union would not read as one flat FILL_ALPHA
# shape. This is a deliberately coarse approximation (a real polygon-boolean union is out
# of scope for this unit); it does not track an INSTANT member's own closing-in progress
# (finding 5d) -- see DESIGN-NOTES "v3 F1a fix round 1" for that open call.
static func _union_footprint(descs: Array) -> PackedVector3Array:
	var tris := PackedVector3Array()
	if descs.is_empty():
		return tris
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for d in descs:
		var c := _centre_of(d)
		var e := _extent_of(d)
		min_x = minf(min_x, c.x - e)
		max_x = maxf(max_x, c.x + e)
		min_z = minf(min_z, c.z - e)
		max_z = maxf(max_z, c.z + e)
	if not (is_finite(min_x) and is_finite(max_x) and is_finite(min_z) and is_finite(max_z)):
		return tris
	var half := UNION_GRID_STEP * 0.5
	var z := min_z + half
	while z <= max_z + 0.001:
		var x := min_x + half
		while x <= max_x + 0.001:
			var p := Vector3(x, 0.0, z)
			for d in descs:
				if _point_in_footprint(d, p):
					_union_cell(tris, d, p, half)
					break
			x += UNION_GRID_STEP
		z += UNION_GRID_STEP
	return tris


# Emits the cell centred at p (half-width `half`) at member d's own ground height
# (finding 6/14), clipped to d's real footprint (finding 5/union-spill): a full quad only
# when every corner and edge midpoint tests inside d's exact shape via
# _point_in_footprint -- the same predicate contains() reads -- so the union never paints
# past a real edge, into an inner safe radius (r_in > 0) or a quenched gap. A cell that
# straddles an edge is quartered down to UNION_MIN_STEP and any remainder still failing is
# dropped rather than drawn, trading a sliver of under-coverage at a curved boundary for
# never drawing a hostile stripe on safe ground.
static func _union_cell(tris: PackedVector3Array, d: Dictionary, p: Vector3, half: float) -> void:
	var y: float = float((d["centre"] as Vector3).y) + UNION_LIFT
	var corners := [Vector3(p.x - half, y, p.z - half), Vector3(p.x + half, y, p.z - half),
		Vector3(p.x + half, y, p.z + half), Vector3(p.x - half, y, p.z + half)]
	var samples := corners + [Vector3(p.x, y, p.z - half), Vector3(p.x + half, y, p.z),
		Vector3(p.x, y, p.z + half), Vector3(p.x - half, y, p.z)]
	var fits := true
	for s in samples:
		if not _point_in_footprint(d, Vector3(s.x, 0.0, s.z)):
			fits = false
			break
	if fits:
		_quad(tris, corners[0], corners[1], corners[2], corners[3])
		return
	if half <= UNION_MIN_STEP:
		return
	var q := half * 0.5
	for dz in [-q, q]:
		for dx in [-q, q]:
			_union_cell(tris, d, Vector3(p.x + dx, 0.0, p.z + dz), q)


# One shared "fill_union" mark per group of more than cap_hostile_union() mutually
# overlapping hostile fills, covering their combined footprint at a flat FILL_ALPHA in
# white (the stripe texture carries the hostile read, same as a single fill), drawn at
# each member's own real ground height (abs=true, finding 6/14). Empty when no group
# exceeds the cap.
static func union_fill_marks_for(descriptors: Array) -> Array:
	var out: Array = []
	for group in _union_groups(descriptors):
		var members: Array = []
		for i in group:
			members.append(descriptors[i])
		out.append(_mark("fill_union", "stripe", Color(1.0, 1.0, 1.0, FILL_ALPHA), _union_footprint(members),
			{"members": group.size(), "abs": true}))
	return out


static func cap_hostile_union() -> int:
	return 4


# index into `descriptors` -> the roles that member should stop drawing because a shared
# union mark (above) replaces them. Edge, front, bracket, rail and owner marks are never
# in this list.
static func suppressed_roles(descriptors: Array) -> Dictionary:
	var out := {}
	for group in _union_groups(descriptors):
		for i in group:
			out[i] = SUPPRESSED_BY_UNION.duplicate()
	return out


# roles(d) with any union-suppressed role removed, for a descriptor at `index` in the
# same-frame `descriptors` list this member belongs to.
static func roles_after_union(descriptors: Array, index: int) -> Array:
	var d: Dictionary = descriptors[index]
	var all := roles(d)
	var suppressed: Dictionary = suppressed_roles(descriptors)
	if not suppressed.has(index):
		return all
	var drop: Array = suppressed[index]
	return all.filter(func(r): return not r in drop)


# --- Live union wiring (§1.3.1, finding 4) ---------------------------------------------
# telegraph.gd and hazard.gd (out of this unit's write set) already call Threat.marks() to
# get what their own Painter draws, every frame; marks() (above) reads this cache to know
# which roles this frame's union suppresses. vfx.gd (in this unit's write set) samples
# density once a frame with tree access and calls refresh_union() then, and owns the one
# Painter that actually draws union_marks_now() (see vfx.gd's `_union_painter`).
#
# A descriptor carries no stable id of its own, so the key is the fields that stay fixed
# for a committed threat's whole life -- the same geometry contains() reads -- never
# progress/front/live, so the same threat maps to the same key every frame regardless of
# how far its warning has run.
#
# fix round 2, finding 7: telegraph.gd only repaints STATIC_LAYERS once, at commit, so a
# member's "area" role (a STATIC_LAYERS mark) used to keep whatever suppression state
# existed when it committed -- a member that started or stopped being unioned after
# commit kept drawing (or stopped drawing) its own fill under the shared union mark,
# doubling the stripe's brightness (§6.1 forbids overlapping fills adding brightness).
# hazard.gd repaints STATIC_LAYERS on every reshape, so its "area" role mostly reacted
# there already, but not on a pure suppression change with no reshape. Neither file needs
# editing for this: both already expose painter() and descriptor() publicly (telegraph.gd
# and hazard.gd's own _build()/_repaint() call exactly this pattern), so refresh_union
# below calls back into a member's own painter to repaint STATIC_LAYERS whenever this
# frame's suppressed-role set for it changed from last frame -- the union painter "owns"
# each member's area layer in that sense, without this file's write set touching either
# caller's source.

static var _union_frame := -1
static var _union_suppressed := {}
static var _union_last_suppressed := {}
static var _union_marks: Array = []


static func _stable_key(d: Dictionary) -> String:
	if d["form"] == "lane":
		return "lane|%s|%s|%s|%s|%s" % [d["centre"], d["dir"], d["back"], d["length"], d["half_width"]]
	return "radial|%s|%s|%s|%s|%s" % [d["centre"], d["r_in"], d["r_out"], d["a0"], d["a1"]]


# Recomputes the union for this frame from every node in Threat.GROUP, once per frame no
# matter how many callers ask (vfx.gd and bolts.gd both sample density every frame).
# `in_view`, when a valid Callable, is (Vector3) -> bool built from the caller's own
# camera; this file cannot preload density.gd for Density.in_view (density.gd already
# preloads this file, and GDScript preload cannot cycle).
static func refresh_union(nodes: Array, in_view: Callable) -> void:
	var frame := Engine.get_process_frames()
	if frame == _union_frame:
		return
	_union_frame = frame
	var descs: Array = []
	var live_nodes: Array = []
	for node in nodes:
		if not is_instance_valid(node) or not node.has_method("descriptor"):
			continue
		var d: Dictionary = node.descriptor()
		if in_view.is_valid() and not in_view.call(_centre_of(d)):
			continue
		descs.append(d)
		live_nodes.append(node)
	# fix round 2, finding 13: one shared clustering pass for both the suppression map and
	# the union marks, instead of suppressed_roles() and union_fill_marks_for() each
	# redoing _union_groups() independently.
	var groups := _union_groups(descs)
	var next_suppressed := {}
	var marks_out: Array = []
	for group in groups:
		var members: Array = []
		for i in group:
			next_suppressed[_stable_key(descs[i])] = SUPPRESSED_BY_UNION.duplicate()
			members.append(descs[i])
		marks_out.append(_mark("fill_union", "stripe", Color(1.0, 1.0, 1.0, FILL_ALPHA), _union_footprint(members),
			{"members": group.size(), "abs": true}))
	for i in descs.size():
		var key := _stable_key(descs[i])
		if not next_suppressed.has(key):
			next_suppressed[key] = []
	_union_suppressed = next_suppressed
	_union_marks = marks_out
	for i in descs.size():
		var key := _stable_key(descs[i])
		var roles_now: Array = next_suppressed[key]
		if roles_now == _union_last_suppressed.get(key, []):
			continue
		var node: Node = live_nodes[i]
		if node.has_method("painter"):
			var painter = node.painter()
			if painter != null:
				painter.paint(marks(descs[i], false), STATIC_LAYERS)
	_union_last_suppressed = next_suppressed


static func active_suppressed_roles(d: Dictionary) -> Array:
	return _union_suppressed.get(_stable_key(d), [])


# This frame's fill_union marks, for the shared union painter to draw.
static func union_marks_now() -> Array:
	return _union_marks


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
		# fix round 2, finding 11/§1.1: P6 (hostile area fills, the "stripe"/"stripe_motion"
		# layers and the union's "fill" layer) sits below P5 (vfx.gd's glyphs and bursts,
		# P5_RENDER_PRIORITY = 20); everything else here (P1-P3 edges/fronts/brackets/rails)
		# stays at PRIORITY (40), above both.
		if layer in ["stripe", "stripe_motion", "fill"]:
			mat.render_priority = UNION_PRIORITY
		else:
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
