extends RefCounted

const Threat := preload("res://src/combat/threat_grammar.gd")

# The world box that holds everything a committed warning's Painter can draw at any progress
# (lighting L7, #297, proposal c). Telegraph and Hazard each compute it once, from the same
# descriptor numbers the Painter reads, and cache it; PlayerFx.warning_rects projects the box
# instead of walking every mesh on every impact-frame refresh. A telegraph walks no meshes on a
# read; a hazard stepped since its last read walks its own painter's meshes once on the read
# (Hazard.screen_bound_box). The box is conservative: it
# may be larger than the meshes, never smaller (tests/warning_bound_containment_test.gd holds
# it to the real meshes, per shape and type, on flat and bumpy ground).
#
# Reads only. It changes no damage, timing, contains() or look.

# Mirrors of literals inside threat_grammar.gd's drawing, kept here because the grammar names
# no constant for them; the containment test fails if the grammar outgrows any of them.
# _owner_ticks: a tick runs to r + 0.4 and is 0.2 + grow wide (threat_grammar.gd _owner_ticks).
const OWNER_OUT := 0.4
const OWNER_HALF := 0.2
# _wave/_sweep_chevrons: the chevron tip stands WAVE_EDGE + 0.3 + CHEVRON_DEPTH ahead.
const CHEVRON_AHEAD_GAP := 0.3
# _brackets: arms 0.14 + r * 0.015 wide, plus grow.
const BRACKET_HALF_BASE := 0.14
const BRACKET_HALF_PER_M := 0.015
# The keyline under a dot is DOT_SIZE + 0.08 (_projectile, _driven_projectile).
const KEYLINE_EXTRA := 0.08

# Test-only: scales every ground pad of a footprint (a lane's, a rim's, a sweep's), so a test
# can plant a box that is too tight and watch the containment check fail. 1.0 in play; nothing
# in src/ sets it.
static var test_pad_scale := 1.0
# Test-only: true makes a Hazard skip the read-time merge of its repainted meshes, leaving its
# build-time box, so a test can show that merge is what holds hazards on real ground. False in
# play; nothing in src/ sets it.
static var test_skip_hazard_merge := false


static func reset_for_tests() -> void:
	test_pad_scale = 1.0
	test_skip_hazard_merge = false

# How far a line's charcoal underlay widens it (_lined's draw(UNDERLAY)).
const GROW := Threat.UNDERLAY

# Furthest any chevron reaches from a point of the footprint: the tip, then the line's half
# width (CHEVRON_LINE + 0.05 for the pull chevrons is inside it) and its underlay.
const CHEVRON_PAD := Threat.WAVE_EDGE + CHEVRON_AHEAD_GAP + Threat.CHEVRON_DEPTH + Threat.CHEVRON_LINE + GROW
# A lane's widest ink past its numbers: a rail (RAIL + grow) or an owner tick past the edge.
const LANE_PAD := maxf(Threat.RAIL + GROW, OWNER_OUT + OWNER_HALF + GROW)


# The y range comes from the painter's own meshes, read once after the first full paint
# (mesh_box): the area footprint, the edge and the fence are all drawn full-extent at build, and
# each is draped on the ground under it, so their y range already holds the ground under the
# footprint. No ground function is called. A WAVE's curtain, which is not drawn at build, is
# added from its numbers: reach + BAND_TOP + underlay above the ground, and a short reach dips
# its low edge below it.
# Marks drawn between or beyond the build-time vertices (a lane's run strip, a sweep's chevrons,
# brackets) stand on ground the meshes did not sample. Their ground can differ from the
# sampled ground; Y_ALLOWANCE covers that, and the containment test holds the box to those
# marks on bumpy and heightfield ground. It is an allowance, not a bound: a cliff between a
# sampled vertex and an unsampled one (the park heightfields have rises of 17 m and more
# between neighbouring 2 m vertices, measured) can exceed it. So a mark that REPAINTS on
# ground the build did not sample (a Hazard, which is never driven) does not rely on it: a
# step only flags its box stale (Hazard._grow_bound), and the next screen_bound_box() read
# merges the painter's current meshes' box into the cached one, so the cache holds each mesh
# it has been read over. On the real park ground, with only the allowance, such
# hazards missed by up to 16.4 m (tests/warning_bound_park_ground_test.gd), and the footprint
# relief did not predict the misses (a 3.0 m relief missed by 4.9 m, a 17 m relief held), so a
# relief threshold could not be derived. Driven telegraphs build every mark at full extent, so
# they have no such gap, and held on every real-ground case.
const Y_ALLOWANCE := Threat.UNDERLAY

# The merged world box of every visible mesh under `node` (the painter's layers, which are
# top-level, so their boxes are already world boxes). AABB() when there is none.
static func mesh_box(node: Node) -> AABB:
	var merged := [AABB(), false]
	_merge(node, merged)
	return merged[0] if merged[1] else AABB()


static func _merge(node: Node, merged: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not child.visible:
			continue
		if child is VisualInstance3D:
			var box: AABB = child.get_aabb()
			if box.size != Vector3.ZERO:
				var world: AABB = child.global_transform * box
				merged[0] = world.merge(merged[0]) if merged[1] else world
				merged[1] = true
		_merge(child, merged)


# The box for a descriptor (Telegraph.descriptor() or Hazard.descriptor()) and the box of the
# painter's meshes after its first full paint. AABB() when there are no meshes to read.
static func box(d: Dictionary, meshes: AABB) -> AABB:
	if meshes.size == Vector3.ZERO:
		return AABB()
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
		var reach_out := maxf(r + _rim_pad(d), Threat.BRACKET_OPEN * r + BRACKET_HALF_BASE + r * BRACKET_HALF_PER_M + GROW)
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
	var reach: float = d["reach"]
	# A WAVE draws no fence at build: its curtain (reach tall) appears with its front, on ground
	# the build meshes did not sample, so it adds the full reach. Every other type's fence is in
	# the build meshes (static layers, built whole), tops included.
	var wave := int(d["type"]) == Threat.Type.WAVE
	var up := (reach + Threat.BAND_TOP + GROW) if wave else 0.0
	var y_min := meshes.position.y + (minf(0.0, reach - Threat.BAND_TOP - GROW) if wave else 0.0) - Y_ALLOWANCE
	var y_max := meshes.end.y + up + Y_ALLOWANCE
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


static func _grow(span: Array, x: float, z: float) -> void:
	span[0] = (span[0] as Vector2).min(Vector2(x, z))
	span[1] = (span[1] as Vector2).max(Vector2(x, z))


static func _pad(span: Array, by: float) -> void:
	by *= test_pad_scale
	span[0] = (span[0] as Vector2) - Vector2(by, by)
	span[1] = (span[1] as Vector2) + Vector2(by, by)
