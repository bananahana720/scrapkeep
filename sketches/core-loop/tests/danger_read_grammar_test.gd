extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const SiltBoil := preload("res://src/combat/silt_boil.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Rules := preload("res://src/boss/boss_rules.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const StageLocks := preload("res://src/world/stage_locks.gd")
const DangerMark := preload("res://src/ui/danger_mark.gd")
const Palette := preload("res://src/core/palette.gd")

# A first-timer can read where a hit will land, when, and where safe ground is (PF-16, PF-25,
# PF-27; wave 36 unit danger). For the four hits that landed unread (silt boil, lobber shell,
# Brindle's slag, Brindle's charge) the fill is measured from what is drawn (the shader's clip
# for a driven telegraph, the fill's triangles for a boss hazard): it grows from the shape's
# centre, is 0 at the warning's start, never falls, and covers the footprint on the tick the
# damage lands, the same footprint the node's contains() tests. Each attack runs on its own
# node, stepped the way its owner steps it (silt_boil.gd, projectile.gd's own physics step,
# hazard.gd step). Then: the bang never stands over the ball, the fence colour stays clear of
# the danger colour, the lobber's trace is a thin dashed arc onto the landing, and every mark
# hugs the ground with its fill under FILL_CAP. Each check has a planted control that must fail.

const DT := 1.0 / 90.0
const CM := 0.01


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


class Ball:
	var at := Vector3(500.0, 1.0, 500.0)

	func ball_position() -> Vector3:
		return at


var _failures := 0
var _world: Node3D
var _ground := FlatGround.new()


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_check_fill_controls()
	_check_silt_boil()
	_check_lobber()
	_check_slag()
	_check_charge()
	_check_off_reticle()
	_check_fence_colour()
	_check_ground_hugging()
	print("danger_read_grammar_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_world.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# --- The fill rule ---------------------------------------------------------------------

# A series of drawn shares, one per tick from commit, and the tick the damage lands: 0 at the
# start, never falling, under 1 before the hit and 1.0 on it. A share below 0 is a fill that
# did not grow from the centre.
static func _fill_ok(series: Array, hit: int) -> bool:
	if series.is_empty() or hit < 1 or hit >= series.size():
		return false
	if absf(series[0]) > 0.001:
		return false
	for i in range(1, hit + 1):
		if series[i] < 0.0 or series[i] < series[i - 1] - 0.0001:
			return false
	# Not full before the hit. The owners sum their clocks a tick at a time, so the tick before the
	# hit can stand at 0.99999 of the warning: the check is two ticks back.
	return hit >= 2 and series[hit - 2] < 1.0 - 0.0001 and absf(series[hit] - 1.0) <= 0.0001


# Where a series first breaks the rule, for the report: "" when it holds.
static func _why(series: Array, hit: int) -> String:
	if hit < 1 or hit >= series.size():
		return "no hit tick (%d of %d)" % [hit, series.size()]
	if absf(series[0]) > 0.001:
		return "starts at %.4f" % series[0]
	for i in range(1, hit + 1):
		if series[i] < 0.0 or series[i] < series[i - 1] - 0.0001:
			return "tick %d: %.5f after %.5f" % [i, series[i], series[i - 1]]
	if hit < 2 or not series[hit - 2] < 1.0 - 0.0001:
		return "full early"
	return "" if absf(series[hit] - 1.0) <= 0.0001 else "%.5f on the hit" % series[hit]


func _check_fill_controls() -> void:
	var good := [0.0, 0.25, 0.5, 0.75, 1.0]
	var frozen := [0.0, 0.5, 0.5, 0.5, 0.5]
	var closing := [0.0, -1.0, -1.0, -1.0, 1.0]
	var early := [0.0, 0.5, 1.0, 1.0, 1.0]
	_report("planted: a frozen fill fails", _fill_ok(good, 4) and not _fill_ok(frozen, 4) and not _fill_ok(closing, 4) and not _fill_ok(early, 4),
		"a rising fill passes; one frozen at 0.5, one closing from the edge and one full before the hit fail")


# A driven telegraph's drawn span, read from the clip the shader gets (threat_mark: radial keeps
# r in [clip.x, clip.y], a lane keeps |lateral| in [clip.z, clip.w]); [-1, -1] when there is none.
static func _clip_span(node: Node3D) -> Vector2:
	var d: Dictionary = node.descriptor()
	var drive: Dictionary = Threat.drive(d)
	if not drive.has("stripe_motion"):
		return Vector2(-1.0, -1.0)
	var clip: Vector4 = drive["stripe_motion"]["clip"]
	if d["form"] == "lane":
		return Vector2(maxf(0.0, clip.z), minf(clip.w, float(d["half_width"])))
	return Vector2(maxf(0.0, clip.x), minf(clip.y, float(d["r_out"])))


# A hazard's drawn span, from the fill's triangles as marks() hands them to the painter.
static func _tri_span(d: Dictionary) -> Vector2:
	var lo := INF
	var hi := -INF
	var c: Vector3 = d["centre"]
	var side := Vector3.UP.cross(d.get("dir", Vector3.FORWARD) as Vector3).normalized()
	var any := false
	for m in Threat.marks(d, true):
		if not m["role"] in ["fill", "run"]:
			continue
		for v in m["tris"]:
			any = true
			var flat := Vector3(v.x - c.x, 0.0, v.z - c.z)
			var r := absf(flat.dot(side)) if d["form"] == "lane" else flat.length()
			lo = minf(lo, r)
			hi = maxf(hi, r)
	if not any:
		return Vector2.ZERO
	if d["form"] == "lane":
		# A lane's fill must span the strip's whole length, from the source to the far end.
		var along_lo := INF
		var along_hi := -INF
		for m in Threat.marks(d, true):
			if m["role"] in ["fill", "run"]:
				for v in m["tris"]:
					var a := Vector3(v.x - c.x, 0.0, v.z - c.z).dot(d["dir"])
					along_lo = minf(along_lo, a)
					along_hi = maxf(along_hi, a)
		if along_lo > -float(d["back"]) + CM or along_hi < float(d["length"]) - CM:
			return Vector2(-1.0, -1.0)
		return Vector2(0.0, hi)
	return Vector2(lo, hi)


# The share a span covers, grown from the centre: a disc from r 0, a band from its middle, a
# lane from its centre line. -1 when the span is not centred so.
static func _share(d: Dictionary, span: Vector2) -> float:
	if span.x < 0.0:
		return -1.0
	if span == Vector2.ZERO:
		return 0.0
	if d["form"] == "lane":
		return span.y / float(d["half_width"])
	var r_in: float = d["r_in"]
	var r_out: float = d["r_out"]
	if r_in <= 0.05:
		return span.y / r_out if span.x <= CM else -1.0
	var mid := (r_in + r_out) * 0.5
	if absf((span.x + span.y) * 0.5 - mid) > CM:
		return -1.0
	return (span.y - span.x) / (r_out - r_in)


# On the hit tick the drawn span is the damage footprint: contains() is true just inside each
# drawn edge and false just outside it, on the ground under the mark.
static func _footprint_ok(node: Node3D, span: Vector2) -> bool:
	var d: Dictionary = node.descriptor()
	var c: Vector3 = d["centre"]
	var axis: Vector3 = Vector3.UP.cross(d["dir"]).normalized() if d["form"] == "lane" else Vector3.RIGHT
	var along: Vector3 = (d["dir"] as Vector3) * float(d["length"]) * 0.5 if d["form"] == "lane" else Vector3.ZERO
	var at := func(r: float) -> Vector3: return c + along + axis * r + Vector3.UP * 0.5
	var ok: bool = node.contains(at.call(span.y - CM)) and not node.contains(at.call(span.y + CM))
	if span.x > CM:
		ok = ok and node.contains(at.call(span.x + CM)) and not node.contains(at.call(span.x - CM))
	return ok


func _check_silt_boil() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 0.0), SiltBoil.RADIUS)
	var series := [_share(ring.descriptor(), _clip_span(ring))]
	var age := 0.0
	var hit := -1
	# silt_boil.gd: _ring_age += delta; set_progress(_ring_age / WARN); erupt once _ring_age >= WARN.
	while hit < 0 and series.size() < 1000:
		age += DT
		ring.set_progress(age / SiltBoil.WARN)
		series.append(_share(ring.descriptor(), _clip_span(ring)))
		if age >= SiltBoil.WARN:
			hit = series.size() - 1
	var span := _clip_span(ring)
	_report("silt boil fill", _fill_ok(series, hit) and _footprint_ok(ring, span) and is_equal_approx(span.y, ring.radius),
		"%s footprint %s; %d ticks, shares %.2f, %.2f, %.2f, ..., %.3f on the erupt tick; drawn reach %.2f m, the ring's contains() edge %.2f m"
			% [_why(series, hit), _footprint_ok(ring, span), series.size(), series[0], series[1], series[hit / 2], series[hit], span.y, ring.radius])
	ring.free()


func _check_lobber() -> void:
	var ball := Ball.new()
	var shell: Node3D = Projectile.new()
	_world.add_child(shell)
	var landing := Vector3(0.0, 0.0, 60.0)
	shell.setup(ball, _ground, _world, Callable(), Vector3(18.0, 3.0, 60.0), landing, Lobber.FLIGHT)
	var ring: Node3D = shell.ring
	var landed := [false]
	shell.exploded.connect(func(_at: Vector3, _r: float, _hit: bool): landed[0] = true)
	var series := [_share(ring.descriptor(), _clip_span(ring))]
	var hit := -1
	var span := Vector2.ZERO
	var points := PackedVector3Array()
	var tris := PackedVector3Array()
	for m in Threat.driven_marks(ring.descriptor()):
		if m["role"] == "trace":
			points = m["points"]
			tris = m["tris"]
	while hit < 0 and series.size() < 1000:
		shell._physics_process(DT)
		series.append(_share(ring.descriptor(), _clip_span(ring)))
		if landed[0]:
			hit = series.size() - 1
			span = _clip_span(ring)
	_report("lobber shell fill", _fill_ok(series, hit) and _footprint_ok(ring, span) and is_equal_approx(span.y, ring.radius),
		"%d ticks, %.3f on the landing tick; drawn reach %.2f m, blast radius %.2f m"
			% [series.size(), series[hit] if hit > 0 else -9.0, span.y, ring.radius])
	var end_gap := points[points.size() - 1].distance_to(ring.center) if not points.is_empty() else INF
	_report("lobber trace is a dashed arc onto the landing", _thin(tris) and end_gap <= 0.5 and points.size() >= 6,
		"%d dashes, thin ribbons %s, the last dash ends %.2f m from the landing centre" % [points.size(), _thin(tris), end_gap])
	var square := PackedVector3Array()
	var s := Threat.DOT_SIZE
	square.append_array([Vector3(-s, -s, 0.0), Vector3(s, -s, 0.0), Vector3(s, s, 0.0), Vector3(-s, -s, 0.0), Vector3(s, s, 0.0), Vector3(-s, s, 0.0)])
	_report("planted: a square billboard fails", not _thin(square), "one DOT_SIZE square, the old trace's piece")
	ring.free()
	if is_instance_valid(shell):
		shell.free()


# Every quad (two triangles) in the trace is a thin ribbon: its long side at least three times
# its short side. An empty trace fails.
static func _thin(tris: PackedVector3Array) -> bool:
	if tris.is_empty():
		return false
	for q in range(0, tris.size() - 5, 6):
		var a := tris[q].distance_to(tris[q + 1])
		var b := tris[q + 1].distance_to(tris[q + 2])
		if maxf(a, b) < 3.0 * minf(a, b):
			return false
	return true


func _hazard_series(h: Node3D) -> Dictionary:
	var series := [_share(h.descriptor(), _tri_span(h.descriptor()))]
	var hit := -1
	var span := Vector2.ZERO
	while hit < 0 and series.size() < 2000:
		h.step(DT)
		series.append(_share(h.descriptor(), _tri_span(h.descriptor())))
		if h.is_live():
			hit = series.size() - 1
			span = _tri_span(h.descriptor())
	return {"series": series, "hit": hit, "span": span}


func _check_slag() -> void:
	var h: Node3D = Hazard.new()
	h.commit_annulus("slag_ring_a", Threat.Type.INSTANT, Vector3(0.0, 0.0, 200.0), Arena.RING_A, Rules.SLAG_REACH,
		Rules.SLAG_WARN, Rules.SLAG_LIVE)
	h.color = Palette.BRASS
	_world.add_child(h)
	var got := _hazard_series(h)
	var span: Vector2 = got["span"]
	var series: Array = got["series"]
	var hit: int = got["hit"]
	_report("Brindle slag fill", _fill_ok(series, hit) and _footprint_ok(h, span)
			and absf(span.x - h.r_in) <= CM and absf(span.y - h.r_out) <= CM,
		"%s %d ticks, %.3f on the first live tick; drawn band %.2f to %.2f m, contains() band %.2f to %.2f m"
			% [_why(series, hit), series.size(), series[hit] if hit > 0 else -9.0, span.x, span.y, h.r_in, h.r_out])
	h.free()


func _check_charge() -> void:
	var h: Node3D = Hazard.new()
	var half := Requisition.HULL.z * 0.5
	h.commit_lane("charge", Threat.Type.LANE, Vector3(0.0, 0.0, 300.0), Vector3(1.0, 0.0, 0.3), half, 40.0 + half,
		Requisition.HULL.x * 0.5 + 1.0, Requisition.HULL.y + 0.5, Rules.CHARGE_WARN, 40.0 / Rules.CHARGE_SPEED + 0.2)
	h.color = Palette.BRASS
	_world.add_child(h)
	var got := _hazard_series(h)
	var span: Vector2 = got["span"]
	var series: Array = got["series"]
	var hit: int = got["hit"]
	_report("Brindle charge fill", _fill_ok(series, hit) and _footprint_ok(h, span) and absf(span.y - h.half_width) <= CM,
		"%s %d ticks, %.3f on the first live tick; drawn half width %.2f m, contains() half width %.2f m"
			% [_why(series, hit), series.size(), series[hit] if hit > 0 else -9.0, span.y, h.half_width])
	h.free()


# --- The bang leaves the lock-on --------------------------------------------------------

func _check_off_reticle() -> void:
	var mark = DangerMark.new()
	mark.avoid = Rect2(762.0, 520.0, 76.0, 76.0)
	mark.show_run(0.5)
	mark.follow(Vector2(800.0, 601.0))
	_report("no bang over the ball or the reticle", not mark.shown() and mark.rect() == Rect2(),
		"mid-warning the HUD mark shows %s with box %s" % [mark.shown(), mark.rect()])
	mark.free()


# --- The fence is not the danger --------------------------------------------------------

static func _cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var lin := [c.r, c.g, c.b].map(func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4))
	var x: float = (lin[0] * 0.4124 + lin[1] * 0.3576 + lin[2] * 0.1805) / 0.95047
	var y: float = lin[0] * 0.2126 + lin[1] * 0.7152 + lin[2] * 0.0722
	var z: float = (lin[0] * 0.0193 + lin[1] * 0.1192 + lin[2] * 0.9505) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _colour_ok(fence: Color, danger: Color) -> bool:
	return fence == Palette.FENCE and danger == Palette.HAZARD and _cie76(fence, danger) >= Palette.FENCE_GAP


func _check_fence_colour() -> void:
	var fence := StageLocks.fence_tone()
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, -100.0), 4.0)
	var danger: Color = ring.color
	_report("fence colour clear of danger", _colour_ok(fence, danger),
		"fence %s from Palette.FENCE, danger %s from Palette.HAZARD, CIE76 %.1f (at least %.0f)"
			% [fence.to_html(false), danger.to_html(false), _cie76(fence, danger), Palette.FENCE_GAP])
	_report("planted: a fence in the danger colour fails", not _colour_ok(Palette.HAZARD, danger),
		"CIE76 %.1f" % _cie76(Palette.HAZARD, danger))
	ring.free()


# --- Ground-hugging, capped marks --------------------------------------------------------

# Every grounded vertex of every mark stands within 5 cm of the ground (the trace is drawn in
# the air on purpose and is thin), and no fill is more opaque than FILL_CAP.
static func _hugs(all: Array) -> bool:
	for m in all:
		if m["abs"]:
			continue
		for v in m["tris"]:
			if v.y > 0.05:
				return false
	return true


func _check_ground_hugging() -> void:
	var nodes := [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, -200.0), 30.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(0.0, 0.0, -250.0), Vector3.RIGHT, 20.0, 6.0),
		Telegraph.wave(_world, _ground, Vector3(0.0, 0.0, -300.0), 20.0, 8.0, 0.2),
	]
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(0.0, 0.0, -350.0), 3.6)
	shell.set_flight(Vector3(15.0, 2.0, -350.0), Threat.lob_bump(26.0, 1.9))
	nodes.append(shell)
	var ok := true
	var opacity := 0.0
	for node in nodes:
		for progress in [0.0, 0.5, 1.0]:
			node.set_progress(progress)
			if node.type == Threat.Type.WAVE:
				node.step(0.5)
			var d: Dictionary = node.descriptor()
			ok = ok and _hugs(Threat.all_marks(d)) and _hugs(Threat.driven_marks(d))
			# A driven layer's tone is scaled by the frame's alpha (threat_mark); a repainted one is not.
			for m in Threat.all_marks(d):
				if m["layer"].begins_with("stripe"):
					opacity = maxf(opacity, (m["tone"] as Color).a)
			for m in Threat.driven_marks(d):
				if m["layer"].begins_with("stripe"):
					opacity = maxf(opacity, (m["tone"] as Color).a * float(Threat.drive(d).get(m["layer"], {}).get("alpha", 1.0)))
			opacity = maxf(opacity, Threat.fill_tint(d).a)
	var wide := Threat.edge_width({"r_out": 30.0})
	_report("marks hug the ground, capped", ok and opacity <= Threat.FILL_CAP + 0.001 and wide <= Threat.EDGE_MAX,
		"ring, lane, wave and shell at three progresses: grounded %s, the most opaque fill %.3f (cap %.2f), a 30 m ring's edge %.2f m (cap %.2f)"
			% [ok, opacity, Threat.FILL_CAP, wide, Threat.EDGE_MAX])
	var tall := [{"abs": false, "tris": PackedVector3Array([Vector3.ZERO, Vector3(0.0, 3.5, 0.0), Vector3(1.0, 0.0, 0.0)])}]
	_report("planted: a post at reach fails", not _hugs(tall), "one triangle 3.5 m tall")
	for node in nodes:
		node.free()
