extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# The world box that holds everything a committed warning's Painter can draw at any progress
# (lighting L7, #297, proposal c). Telegraph and Hazard each compute it once, from the same
# descriptor numbers the Painter reads, and cache it; PlayerFx.warning_rects projects the box
# instead of walking every mesh on every impact-frame refresh. The box is conservative: it
# may be larger than the meshes, never smaller (tests/warning_bound_containment_test.gd holds
# it to the real meshes, per shape and type, on flat and bumpy ground).
#
# Reads only. It changes no damage, timing, contains() or look.

# Ground sampling for the y range. The Painter lifts each vertex to the ground under it
# (Painter.paint), so the box's y range is the ground's range over the footprint. Combat's
# ground is the stage heightfield, which is piecewise linear over STEP cells (terrain.gd STEP;
# the test checks this copy against it), so its extremes sit on the lattice and sampling the
# STEP lattice over the box finds them. A smoother ground (the boss bowl) can exceed its
# lattice samples between them by about (Dx + Dz) / 8, with Dx and Dz the largest second
# differences along each axis (the bilinear interpolation error bound, curvature estimated from
# the samples), so that is added to both ends: a bumpier ground widens its own margin.
const GROUND_STEP := 2.0
# Cost cap at commit: at most this many samples a side (1024 ground calls). A box wider than
# (LATTICE_MAX - 1) * GROUND_STEP samples at a coarser spacing, which raises the second
# differences and with them the margin.
const LATTICE_MAX := 32

# Mirrors of literals inside threat_grammar.gd's drawing, kept here because the grammar names
# no constant for them; the containment test fails if the grammar outgrows any of them.
# _owner_ticks: a tick runs to r + 0.4 and is 0.2 + grow wide (threat_grammar.gd _owner_ticks).
const OWNER_OUT := 0.4
const OWNER_HALF := 0.2
# _wave/_sweep_chevrons: the chevron tip stands WAVE_EDGE + 0.3 + CHEVRON_DEPTH ahead.
const CHEVRON_AHEAD_GAP := 0.3
# _pip: a cross 0.7 long, 0.12 wide, plus grow.
const PIP_ARM := 0.7
const PIP_HALF := 0.12
# _brackets: arms 0.14 + r * 0.015 wide, plus grow.
const BRACKET_HALF_BASE := 0.14
const BRACKET_HALF_PER_M := 0.015
# The keyline under a dot is DOT_SIZE + 0.08 (_projectile, _driven_projectile).
const KEYLINE_EXTRA := 0.08

# How far a line's charcoal underlay widens it (_lined's draw(UNDERLAY)).
const GROW := Threat.UNDERLAY

# Furthest any chevron reaches from a point of the footprint: the tip, then the line's half
# width (CHEVRON_LINE + 0.05 for the pull chevrons is inside it) and its underlay.
const CHEVRON_PAD := Threat.WAVE_EDGE + CHEVRON_AHEAD_GAP + Threat.CHEVRON_DEPTH + Threat.CHEVRON_LINE + GROW
# A lane's widest ink past its numbers: a rail (RAIL + grow) or an owner tick past the edge.
const LANE_PAD := maxf(Threat.RAIL + GROW, OWNER_OUT + OWNER_HALF + GROW)


# The box for a descriptor (Telegraph.descriptor() or Hazard.descriptor()). `ground` is the
# Painter's ground callable (Callable() draws flat at floor_y) and `lift` its lift.
static func box(d: Dictionary, ground: Callable, floor_y: float, lift: float) -> AABB:
	var c: Vector3 = d["centre"]
	var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
	if d["form"] == "lane":
		var heading: Vector3 = d["dir"]
		var side := Vector3.UP.cross(heading).normalized()
		var half: float = d["half_width"]
		for along in [-float(d["back"]), float(d["length"])]:
			for lateral in [-half, half]:
				var p: Vector3 = c + heading * (along as float) + side * (lateral as float)
				_grow(span, p.x, p.z)
		_pad(span, LANE_PAD)
	elif int(d["type"]) == Threat.Type.PROJECTILE:
		var r: float = d["r_out"]
		var reach_out := maxf(r + _rim_pad(d), maxf(Threat.BRACKET_OPEN * r + BRACKET_HALF_BASE + r * BRACKET_HALF_PER_M + GROW,
			PIP_ARM + PIP_HALF + GROW))
		_grow(span, c.x - reach_out, c.z - reach_out)
		_grow(span, c.x + reach_out, c.z + reach_out)
	else:
		_sector_span(d, span)
		var pad := _rim_pad(d)
		if int(d["type"]) == Threat.Type.WAVE or int(d["type"]) == Threat.Type.LANE:
			pad = maxf(pad, CHEVRON_PAD)
		_pad(span, pad)
	var lo: Vector2 = span[0]
	var hi: Vector2 = span[1]
	var range_y := _ground_range(ground, floor_y, lo, hi)
	var reach: float = d["reach"]
	# Vertex height is ground + lift + (0 .. reach + BAND_TOP + grow): the rail on top of a
	# fence is centred on reach and BAND_TOP + grow tall each way; a reach shorter than that
	# dips the rail's low edge below the ground (min with 0).
	var y_min := range_y.x + lift + minf(0.0, reach - Threat.BAND_TOP - GROW)
	var y_max := range_y.y + lift + reach + Threat.BAND_TOP + GROW
	var out := AABB(Vector3(lo.x, y_min, lo.y), Vector3(hi.x - lo.x, y_max - y_min, hi.y - lo.y))
	if d.has("launch"):
		out = out.merge(_flight_box(d, c))
	return out


# A PROJECTILE's trace is drawn in absolute world coordinates (no ground, no lift): the
# points run from launch to the landing along Threat.flight_point, a straight line plus
# bump * s * (1 - s) up, which peaks at bump / 4 (s = 1/2). The trace's first dot is after
# s = 0, so launch itself is included only for a bound.
static func _flight_box(d: Dictionary, c: Vector3) -> AABB:
	var launch: Vector3 = d["launch"]
	var bump: float = d["bump"]
	var pad := Threat.DOT_SIZE + KEYLINE_EXTRA
	var lo := Vector3(minf(launch.x, c.x), minf(launch.y, c.y) + minf(0.0, bump * 0.25), minf(launch.z, c.z)) - Vector3.ONE * pad
	var hi := Vector3(maxf(launch.x, c.x), maxf(launch.y, c.y) + maxf(0.0, bump * 0.25), maxf(launch.z, c.z)) + Vector3.ONE * pad
	return AABB(lo, hi - lo)


# How far the rim ink reaches past the footprint on the ground: the arcs (grow), an owner tick
# or a sector's side edge (half the edge width plus grow).
static func _rim_pad(d: Dictionary) -> float:
	return maxf(maxf(GROW, OWNER_OUT + OWNER_HALF + GROW), Threat.edge_width(d) * 0.5 + GROW)


# The ground box of a radial footprint: the arc's end points at both radii, and the outer
# radius at each axis direction the sweep crosses. A sweep of a full turn or more is the disc.
static func _sector_span(d: Dictionary, span: Array) -> void:
	var c: Vector3 = d["centre"]
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	var a0: float = d["a0"]
	var a1: float = d["a1"]
	if Threat.is_full(d):
		_grow(span, c.x - r_out, c.z - r_out)
		_grow(span, c.x + r_out, c.z + r_out)
		return
	for a in [a0, a1]:
		for r in [r_in, r_out]:
			_grow(span, c.x + cos(a) * r, c.z + sin(a) * r)
	var low := minf(a0, a1)
	var high := maxf(a0, a1)
	var k := int(ceil(low / (PI * 0.5)))
	while k * PI * 0.5 <= high:
		var axis := k * PI * 0.5
		_grow(span, c.x + cos(axis) * r_out, c.z + sin(axis) * r_out)
		k += 1


# The lowest and highest ground over the box, with the curvature margin (see GROUND_STEP).
static func _ground_range(ground: Callable, floor_y: float, lo: Vector2, hi: Vector2) -> Vector2:
	if not ground.is_valid():
		return Vector2(floor_y, floor_y)
	var x0 := floorf(lo.x / GROUND_STEP) * GROUND_STEP
	var x1 := ceilf(hi.x / GROUND_STEP) * GROUND_STEP
	var z0 := floorf(lo.y / GROUND_STEP) * GROUND_STEP
	var z1 := ceilf(hi.y / GROUND_STEP) * GROUND_STEP
	var nx := clampi(int(round((x1 - x0) / GROUND_STEP)) + 1, 3, LATTICE_MAX)
	var nz := clampi(int(round((z1 - z0) / GROUND_STEP)) + 1, 3, LATTICE_MAX)
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	var low := INF
	var high := -INF
	for j in nz:
		for i in nx:
			var h: float = ground.call(Vector3(lerpf(x0, x1, float(i) / (nx - 1)), floor_y, lerpf(z0, z1, float(j) / (nz - 1))))
			heights[j * nx + i] = h
			low = minf(low, h)
			high = maxf(high, h)
	var dx := 0.0
	var dz := 0.0
	for j in nz:
		for i in nx:
			if i > 0 and i < nx - 1:
				dx = maxf(dx, absf(heights[j * nx + i - 1] - 2.0 * heights[j * nx + i] + heights[j * nx + i + 1]))
			if j > 0 and j < nz - 1:
				dz = maxf(dz, absf(heights[(j - 1) * nx + i] - 2.0 * heights[j * nx + i] + heights[(j + 1) * nx + i]))
	var margin := (dx + dz) / 8.0
	return Vector2(low - margin, high + margin)


static func _grow(span: Array, x: float, z: float) -> void:
	span[0] = (span[0] as Vector2).min(Vector2(x, z))
	span[1] = (span[1] as Vector2).max(Vector2(x, z))


static func _pad(span: Array, by: float) -> void:
	span[0] = (span[0] as Vector2) - Vector2(by, by)
	span[1] = (span[1] as Vector2) + Vector2(by, by)
