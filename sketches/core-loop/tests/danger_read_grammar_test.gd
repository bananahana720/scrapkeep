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
const Palette := preload("res://src/core/palette.gd")

# A first-timer can read when a ground hit will land (PF-16, PF-25; wave 36 unit danger). For
# the four hits that landed unread (silt boil, lobber shell, Brindle's slag, Brindle's charge)
# the pending fill is measured from what the painter holds: a driven telegraph's mesh tag and
# the clip set on its instance, a boss hazard's fill mesh. The fill grows from the shape's
# centre and its front meets the outline's inner face (read from the edge the painter drew) on
# the tick the damage lands, not before, and never draws under the outline. The outline's
# outer face is where contains() flips. A live hit draws exactly as before wave 36. The
# shell's trace is a thin dashed arc onto its landing, outlines are capped at EDGE_MAX and
# pending fills at FILL_CAP. Every check runs its own function on a broken copy, which must
# fail.

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
	_check_rule_controls()
	_check_silt_boil()
	_check_lobber()
	_check_slag()
	_check_charge()
	_check_live()
	_check_caps()
	print("danger_read_grammar_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_world.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# --- The fill rule ---------------------------------------------------------------------

# Shares of the room inside the outline, one per tick from commit, and the hit tick: 0 at the
# start, never falling, never past the outline, under 1 two ticks before the hit (the owners sum
# their clocks a tick at a time, so the tick before can stand at 0.99999) and 1 on it. A share
# below 0 is a fill that did not grow from the centre.
static func _fill_ok(series: Array, hit: int) -> bool:
	return _why(series, hit) == ""


static func _why(series: Array, hit: int) -> String:
	if hit < 2 or hit >= series.size():
		return "no hit tick (%d of %d)" % [hit, series.size()]
	if absf(series[0]) > 0.001:
		return "starts at %.4f" % series[0]
	for i in range(1, hit + 1):
		if series[i] < 0.0 or series[i] < series[i - 1] - 0.0001:
			return "tick %d: %.5f after %.5f" % [i, series[i], series[i - 1]]
		if series[i] > 1.0001:
			return "tick %d draws under the outline (%.4f)" % [i, series[i]]
	if not series[hit - 2] < 1.0 - 0.0001:
		return "touches the outline early (%.4f two ticks before)" % series[hit - 2]
	return "" if absf(series[hit] - 1.0) <= 0.001 else "%.4f on the hit" % series[hit]


func _check_rule_controls() -> void:
	var good := [0.0, 0.25, 0.5, 0.75, 1.0]
	var frozen := [0.0, 0.5, 0.5, 0.5, 0.5]
	var closing := [0.0, -1.0, -1.0, -1.0, 1.0]
	var early := [0.0, 0.5, 1.0, 1.0, 1.0]
	_report("planted: a frozen fill fails", _fill_ok(good, 4) and not _fill_ok(frozen, 4) and not _fill_ok(closing, 4) and not _fill_ok(early, 4),
		"a rising fill passes; one frozen at 0.5 (%s), one closing from the edge (%s) and one full early (%s) fail"
			% [_why(frozen, 4), _why(closing, 4), _why(early, 4)])


# The outline as the painter drew it (the "edge" marks of marks(d, false)), along the grow axis:
# inner faces lo and hi, outer faces out_lo and out_hi, and a lane's far cap inner face.
static func _outline(d: Dictionary) -> Dictionary:
	var c: Vector3 = d["centre"]
	var lane: bool = d["form"] == "lane"
	var side := Vector3.UP.cross(d.get("dir", Vector3.FORWARD) as Vector3).normalized()
	var mid := (float(d.get("r_in", 0.0)) + float(d.get("r_out", 0.0))) * 0.5
	var o := {"lo": 0.0, "hi": INF, "out_lo": 0.0, "out_hi": 0.0, "cap": INF}
	var band: bool = not lane and float(d["r_in"]) > 0.05
	if band:
		o["lo"] = -INF
		o["out_lo"] = INF
	for m in Threat.marks(d, false):
		if m["role"] != "edge":
			continue
		for v in m["tris"]:
			var flat := Vector3(v.x - c.x, 0.0, v.z - c.z)
			if lane:
				var along := flat.dot(d["dir"])
				var lat := absf(flat.dot(side))
				if along < float(d["length"]) - Threat.RAIL * 2.0 - 0.01:
					o["hi"] = minf(o["hi"], lat)
					o["out_hi"] = maxf(o["out_hi"], lat)
				else:
					# The far cap's inner face: the nearest edge vertex past the rails' run.
					o["cap"] = minf(o["cap"], along)
				continue
			var r := flat.length()
			if band and r < mid:
				o["lo"] = maxf(o["lo"], r)
				o["out_lo"] = minf(o["out_lo"], r)
			else:
				o["hi"] = minf(o["hi"], r)
				o["out_hi"] = maxf(o["out_hi"], r)
	return o


# The share of the room inside the outline a drawn fill covers: a disc from r 0, a band from its
# middle, a lane from its centre line along its whole length up to the cap. -1 when not so.
static func _share(d: Dictionary, o: Dictionary, fill: Dictionary) -> float:
	if not fill.has("hi"):
		return 0.0
	if d["form"] == "lane":
		if fill["along_lo"] > -float(d["back"]) + CM or fill["along_hi"] > o["cap"] + 0.001 or fill["along_hi"] < o["cap"] - CM:
			return -1.0
		return fill["hi"] / o["hi"]
	if o["lo"] <= 0.0:
		return fill["hi"] / o["hi"] if fill["lo"] <= CM else -1.0
	if absf((fill["lo"] + fill["hi"]) - (o["lo"] + o["hi"])) > 2.0 * CM:
		return -1.0
	return (fill["hi"] - fill["lo"]) / (o["hi"] - o["lo"])


# What the same series would have read under the old mapping, a fill that ran to the footprint's
# own edge: the planted control for the inner-face rule.
static func _old_share(d: Dictionary, o: Dictionary) -> float:
	var p := Threat.fill_share(d)
	if d["form"] == "lane":
		return p * float(d["half_width"]) / o["hi"]
	if o["lo"] <= 0.0:
		return p * float(d["r_out"]) / o["hi"]
	return p * (float(d["r_out"]) - float(d["r_in"])) / (o["hi"] - o["lo"])


# A driven telegraph's fill: the stripe_motion mesh must carry the drive tag the shader clips by
# (RADIAL or LANE) and the extent is that mesh's own range cut by the clip set on the instance.
static func _driven_fill(node: Node3D) -> Dictionary:
	var instance: MeshInstance3D = node.painter()._layers.get("stripe_motion")
	if instance == null or instance.mesh == null:
		return {"tag": false}
	var d: Dictionary = node.descriptor()
	var lane: bool = d["form"] == "lane"
	var arrays: Array = (instance.mesh as ArrayMesh).surface_get_arrays(0)
	var tags: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var want := float(Threat.Drive.LANE if lane else Threat.Drive.RADIAL)
	for i in range(0, tags.size(), 4):
		if tags[i] != want:
			return {"tag": false}
	var mesh := _extent(d, arrays[Mesh.ARRAY_VERTEX])
	var clip: Vector4 = instance.get_instance_shader_parameter("clip")
	var out := {"tag": true}
	if lane:
		var hi: float = minf(mesh["hi"], clip.w)
		if hi <= 0.0:
			return out
		out.merge({"lo": 0.0, "hi": hi, "along_lo": maxf(mesh["along_lo"], clip.x), "along_hi": minf(mesh["along_hi"], clip.y)})
		return out
	var lo: float = maxf(mesh["lo"], clip.x)
	var hi2: float = minf(mesh["hi"], clip.y)
	if hi2 <= lo:
		return out
	out.merge({"lo": lo, "hi": hi2})
	return out


# The range of a vertex list along the grow axis, and along a lane.
static func _extent(d: Dictionary, verts: PackedVector3Array) -> Dictionary:
	var c: Vector3 = d["centre"]
	var lane: bool = d["form"] == "lane"
	var side := Vector3.UP.cross(d.get("dir", Vector3.FORWARD) as Vector3).normalized()
	var e := {"lo": INF, "hi": -INF, "along_lo": INF, "along_hi": -INF}
	for v in verts:
		var flat := Vector3(v.x - c.x, 0.0, v.z - c.z)
		var r := absf(flat.dot(side)) if lane else flat.length()
		e["lo"] = minf(e["lo"], 0.0 if lane else r)
		e["hi"] = maxf(e["hi"], r)
		if lane:
			var along := flat.dot(d["dir"])
			e["along_lo"] = minf(e["along_lo"], along)
			e["along_hi"] = maxf(e["along_hi"], along)
	return e


# A boss hazard's fill: the painter's stripe_motion mesh as it stands this tick.
static func _hazard_fill(h: Node3D) -> Dictionary:
	var instance: MeshInstance3D = h.painter()._layers.get("stripe_motion")
	if instance == null or instance.mesh == null:
		return {}
	var d: Dictionary = h.descriptor()
	var e := _extent(d, (instance.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	if d["form"] == "lane" and e["hi"] <= 0.0005:
		return {}
	return e


# The outline's outer faces (a lane's rail centre lines) are where contains() flips, on the ground under the mark. `shift`
# moves the faces tested: the planted control passes 0.3 m, which must fail.
static func _footprint_ok(node: Node3D, o: Dictionary, shift := 0.0) -> bool:
	var d: Dictionary = node.descriptor()
	var c: Vector3 = d["centre"]
	var lane: bool = d["form"] == "lane"
	var axis: Vector3 = Vector3.UP.cross(d["dir"]).normalized() if lane else Vector3.RIGHT
	var along: Vector3 = (d["dir"] as Vector3) * float(d["length"]) * 0.5 if lane else Vector3.ZERO
	var at := func(r: float) -> Vector3: return c + along + axis * r + Vector3.UP * 0.5
	# A lane's rails straddle its edge (_edge_tris): their centre line is the damage edge.
	var hi: float = (o["hi"] + o["out_hi"]) * 0.5 + shift if lane else o["out_hi"] + shift
	var ok: bool = node.contains(at.call(hi - CM)) and not node.contains(at.call(hi + CM))
	if not lane and o["lo"] > 0.0:
		var lo: float = o["out_lo"] + shift
		ok = ok and node.contains(at.call(lo + CM)) and not node.contains(at.call(lo - CM))
	return ok


# Reports one hit: the rule on the drawn series, the old mapping as its planted control, the
# drive tag on every tick (driven only) and the footprint with its planted shift.
func _report_hit(label: String, node: Node3D, o: Dictionary, series: Array, old: Array, hit: int, tagged: bool) -> void:
	_report(label + " fill meets the outline on the hit tick", _fill_ok(series, hit) and tagged,
		"%s; %d ticks, %.3f two ticks before, %.3f on the hit; outline inner face %.2f m%s; drive tag on every tick %s"
			% [_why(series, hit) if _why(series, hit) != "" else "rule holds", series.size(),
				series[hit - 2] if hit >= 2 else -9.0, series[hit] if hit >= 0 else -9.0, o["hi"],
				(", band from %.2f m" % o["lo"]) if o["lo"] > 0.0 else "", tagged])
	_report("planted: " + label + " under the old mapping fails", not _fill_ok(old, hit),
		"a fill running to the footprint's edge: %s" % _why(old, hit))
	_report(label + " outline is the damage footprint", _footprint_ok(node, o) and not _footprint_ok(node, o, 0.3),
		"contains() flips at the outer face %.2f m; the planted face 0.3 m out does not" % o["out_hi"])


func _check_silt_boil() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 0.0), SiltBoil.RADIUS)
	var o := _outline(ring.descriptor())
	var tagged := true
	var f := _driven_fill(ring)
	var series := [_share(ring.descriptor(), o, f)]
	var old := [_old_share(ring.descriptor(), o)]
	var age := 0.0
	var hit := -1
	# silt_boil.gd: _ring_age += delta; set_progress(_ring_age / WARN); erupt once _ring_age >= WARN.
	while hit < 0 and series.size() < 1000:
		age += DT
		ring.set_progress(age / SiltBoil.WARN)
		f = _driven_fill(ring)
		tagged = tagged and f["tag"]
		series.append(_share(ring.descriptor(), o, f))
		old.append(_old_share(ring.descriptor(), o))
		if age >= SiltBoil.WARN:
			hit = series.size() - 1
	_report_hit("silt boil", ring, o, series, old, hit, tagged)
	ring.free()


func _check_lobber() -> void:
	var ball := Ball.new()
	var shell: Node3D = Projectile.new()
	_world.add_child(shell)
	shell.setup(ball, _ground, _world, Callable(), Vector3(18.0, 3.0, 60.0), Vector3(0.0, 0.0, 60.0), Lobber.FLIGHT)
	var ring: Node3D = shell.ring
	var landed := [false]
	shell.exploded.connect(func(_at: Vector3, _r: float, _hit: bool): landed[0] = true)
	var o := _outline(ring.descriptor())
	var tagged := true
	var series := [_share(ring.descriptor(), o, _driven_fill(ring))]
	var old := [_old_share(ring.descriptor(), o)]
	var hit := -1
	var points := PackedVector3Array()
	var tris := PackedVector3Array()
	for m in Threat.driven_marks(ring.descriptor()):
		if m["role"] == "trace":
			points = m["points"]
			tris = m["tris"]
	while hit < 0 and series.size() < 1000:
		shell._physics_process(DT)
		var f := _driven_fill(ring)
		tagged = tagged and f["tag"]
		series.append(_share(ring.descriptor(), o, f))
		old.append(_old_share(ring.descriptor(), o))
		if landed[0]:
			hit = series.size() - 1
	_report_hit("lobber shell", ring, o, series, old, hit, tagged)
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


func _hazard_run(label: String, h: Node3D) -> void:
	var o := _outline(h.descriptor())
	var series := [_share(h.descriptor(), o, _hazard_fill(h))]
	var old := [_old_share(h.descriptor(), o)]
	var hit := -1
	while hit < 0 and series.size() < 2000:
		h.step(DT)
		series.append(_share(h.descriptor(), o, _hazard_fill(h)))
		old.append(_old_share(h.descriptor(), o))
		if h.is_live():
			hit = series.size() - 1
	_report_hit(label, h, o, series, old, hit, true)


func _check_slag() -> void:
	var h: Node3D = Hazard.new()
	h.commit_annulus("slag_ring_a", Threat.Type.INSTANT, Vector3(0.0, 0.0, 200.0), Arena.RING_A, Rules.SLAG_REACH,
		Rules.SLAG_WARN, Rules.SLAG_LIVE)
	h.color = Palette.BRASS
	_world.add_child(h)
	_hazard_run("Brindle slag", h)
	h.free()


func _check_charge() -> void:
	var h: Node3D = Hazard.new()
	var half := Requisition.HULL.z * 0.5
	h.commit_lane("charge", Threat.Type.LANE, Vector3(0.0, 0.0, 300.0), Vector3(1.0, 0.0, 0.3), half, 40.0 + half,
		Requisition.HULL.x * 0.5 + 1.0, Requisition.HULL.y + 0.5, Rules.CHARGE_WARN, 40.0 / Rules.CHARGE_SPEED + 0.2)
	h.color = Palette.BRASS
	_world.add_child(h)
	_hazard_run("Brindle charge", h)
	h.free()


# --- A live hit draws as before wave 36 ------------------------------------------------

static func _stencil(instance: MeshInstance3D) -> int:
	var mat := instance.material_override as ShaderMaterial
	if mat == null:
		return 0
	var at := mat.shader.code.find("compare_not_equal, ")
	return int(mat.shader.code.substr(at + 19)) if at >= 0 else 0


# The live look of a mark as its painter holds it: the stripe_motion layer's stencil class,
# render priority and alpha scale, and the solid fill's tint.
static func _live_look(node: Node3D) -> Dictionary:
	var layers: Dictionary = node.painter()._layers
	var motion: MeshInstance3D = layers.get("stripe_motion")
	var look := {"stencil": -1, "priority": -1, "scale": 1.0, "tint": Color(0, 0, 0, 0)}
	if motion != null:
		look["stencil"] = _stencil(motion)
		look["priority"] = motion.material_override.render_priority
		var scale = motion.get_instance_shader_parameter("alpha_scale") if motion.material_override is ShaderMaterial else null
		look["scale"] = 1.0 if scale == null else float(scale)
	var fill: MeshInstance3D = layers.get("fill")
	if fill != null and fill.material_override is StandardMaterial3D:
		look["tint"] = (fill.material_override as StandardMaterial3D).albedo_color
	return look


# The base 501b2821a live look, per kind: a live ring and shell stay in the "fill" class (1) at
# PRIORITY under the scorch tint, a live lane moves to "live" (16) at LIVE_PRIORITY with the
# LIVE_ALPHA / RUN_ALPHA scale, and a boss slag repaints at PRIORITY under the scorch.
static func _live_ok(kind: String, look: Dictionary) -> bool:
	var scorch := Color(Palette.HAZARD.lerp(Palette.CHARCOAL, 0.4), 0.8)
	match kind:
		"ring":
			return look["stencil"] == 1 and look["priority"] == 40 and look["tint"].is_equal_approx(scorch)
		"shell":
			return look["stencil"] == 1 and look["priority"] == 40
		"lane":
			return look["stencil"] == 16 and look["priority"] == 41 and is_equal_approx(look["scale"], 0.8 / 0.35)
		"slag":
			return look["stencil"] == 0 and look["priority"] == 40 and look["tint"].is_equal_approx(scorch)
	return false


func _check_live() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, -100.0), 4.5)
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(20.0, 0.0, -100.0), Vector3.FORWARD, 11.0, 3.0)
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(40.0, 0.0, -100.0), 3.6)
	shell.set_flight(Vector3(52.0, 2.0, -100.0), Threat.lob_bump(26.0, 1.9))
	for node in [ring, lane, shell]:
		node.set_progress(1.0)
	var slag: Node3D = Hazard.new()
	slag.commit_annulus("slag_ring_b", Threat.Type.INSTANT, Vector3(60.0, 0.0, -100.0), Arena.RING_A, Rules.SLAG_REACH, 1.0, 6.0)
	slag.color = Palette.BRASS
	_world.add_child(slag)
	slag.step(1.01)
	var looks := {"ring": _live_look(ring), "lane": _live_look(lane), "shell": _live_look(shell), "slag": _live_look(slag)}
	var ok: bool = Threat.haze() and is_equal_approx(Threat.LIVE_ALPHA, 0.8) and is_equal_approx(Threat.LIVE_SCORCH_ALPHA, 0.8) \
		and is_equal_approx(Threat.AIR_LIVE_ALPHA, 0.61) and slag.is_live()
	for kind in looks:
		ok = ok and _live_ok(kind, looks[kind])
	_report("a live hit draws as base", ok, "haze %s, LIVE %.2f, scorch %.2f, air %.2f; %s" % [Threat.haze(), Threat.LIVE_ALPHA,
		Threat.LIVE_SCORCH_ALPHA, Threat.AIR_LIVE_ALPHA, looks])
	# The reverted bug: a live ring whose drive moved it into the "live" class.
	var bad: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(80.0, 0.0, -100.0), 4.5)
	bad.set_progress(1.0)
	var entry: Dictionary = Threat.drive(bad.descriptor())["stripe_motion"].duplicate()
	entry["live"] = true
	bad.painter().drive({"stripe_motion": entry})
	var bad_look := _live_look(bad)
	_report("planted: a live ring in the live class fails", not _live_ok("ring", bad_look), "%s" % [bad_look])
	for node in [ring, lane, shell, slag, bad]:
		node.free()


# --- Caps -------------------------------------------------------------------------------

static func _edge_ok(width: float) -> bool:
	return width <= Threat.EDGE_MAX + 0.0001


# The most opaque PENDING fill (stripe layers, as drawn) in a set of marks, against FILL_CAP.
static func _pending_ok(all: Array) -> bool:
	for m in all:
		if m["layer"].begins_with("stripe") and (m["tone"] as Color).a > Threat.FILL_CAP + 0.0001:
			return false
	return true


func _check_caps() -> void:
	var wide := Threat.edge_width({"r_out": 30.0})
	_report("outline width capped", _edge_ok(wide) and not _edge_ok(30.0 * Threat.EDGE_PER_METRE),
		"a 30 m ring's edge %.2f m (cap %.2f); the uncapped %.2f m fails" % [wide, Threat.EDGE_MAX, 30.0 * Threat.EDGE_PER_METRE])
	var nodes := [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, -200.0), 30.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(0.0, 0.0, -250.0), Vector3.RIGHT, 20.0, 6.0),
		Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(0.0, 0.0, -350.0), 3.6),
	]
	nodes[2].set_flight(Vector3(15.0, 2.0, -350.0), Threat.lob_bump(26.0, 1.9))
	var ok := true
	for node in nodes:
		for progress in [0.0, 0.5, 0.95]:
			node.set_progress(progress)
			var d: Dictionary = node.descriptor()
			ok = ok and _pending_ok(Threat.all_marks(d)) and _pending_ok(Threat.driven_marks(d))
	var planted := [{"layer": "stripe_motion", "tone": Color(Palette.HAZARD, 0.9)}]
	_report("pending fill opacity capped", ok and not _pending_ok(planted),
		"ring, lane and shell at 0, 0.5 and 0.95: every pending fill at most %.2f; a planted 0.9 fill fails" % Threat.FILL_CAP)
	for node in nodes:
		node.free()
