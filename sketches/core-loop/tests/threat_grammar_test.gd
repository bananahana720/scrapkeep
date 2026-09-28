extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Palette := preload("res://src/core/palette.gd")

# The four attack types draw four different grammars, each from the descriptor its node
# builds out of the same fields contains() reads. A wave's drawn front is its damage
# front at every time sampled, and a shell's reticle and flight trace end on the landing
# point it committed, along the path the shell actually flies. Hostile areas are
# striped, the player's own and harmless fields are not, and a boss marks its own.

const DT := 1.0 / 90.0
const EXPECTED := {
	Threat.Type.INSTANT: ["area", "band", "band_top", "edge", "fill", "solid"],
	Threat.Type.WAVE: ["band", "band_top", "chevrons", "front", "outline"],
	Threat.Type.PROJECTILE: ["area", "band", "band_top", "bracket", "edge", "pip", "trace"],
	Threat.Type.LANE: ["area", "band", "band_top", "edge", "run"],
}


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


class FarBall:
	func ball_position() -> Vector3:
		return Vector3(500.0, 1.0, 500.0)


var _failures := 0
var _world: Node3D
var _ground := FlatGround.new()


func _initialize() -> void:
	_world = Node3D.new()
	root.add_child(_world)


func _process(_delta: float) -> bool:
	_check_grammars()
	_check_stances()
	_check_wave()
	_check_sweep()
	_check_projectile()
	_check_union()
	print("threat_grammar_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_world.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _mark(d: Dictionary, role: String) -> Dictionary:
	for m in Threat.all_marks(d):
		if m["role"] == role:
			return m
	return {}


func _check_grammars() -> void:
	var instant: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 0.0), 6.0)
	var wave: Node3D = Telegraph.wave(_world, _ground, Vector3(40.0, 0.0, 0.0), 20.0, 8.0, 1.0)
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 0.0), 3.6)
	shell.set_flight(Vector3(95.0, 2.0, 0.0), Threat.lob_bump(26.0, 1.9))
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(0.0, 0.0, 40.0), Vector3(1.0, 0.0, 0.0), 11.0, 3.0)
	var nodes := [instant, wave, shell, lane]
	var seen: Array = []
	for node in nodes:
		var d: Dictionary = node.descriptor()
		var roles := Threat.roles(d)
		var want: Array = EXPECTED[node.type]
		var row := Threat.row(node.type)
		var striped: int = node.painter().vertex_count("stripe") + node.painter().vertex_count("stripe_motion")
		_report("grammar %s" % Threat.kind(node.type), roles == want and not roles in seen and node.is_in_group(Threat.GROUP)
				and node.painter().vertex_count("base") > 0 and node.painter().vertex_count("under") > 0 and (striped > 0 or node.type == Threat.Type.WAVE) and row.get("sound", "") != "",
			"draws %s (want %s), in group %s, %d base, %d keyline and %d striped vertices (an arming wave has swept nothing yet), sound %s, shape %s"
				% [roles, want, Threat.GROUP, node.painter().vertex_count("base"), node.painter().vertex_count("under"), striped,
					row.get("sound", ""), row.get("shape", "")])
		seen.append(roles)
	var sounds := {}
	var shapes := {}
	for type in Threat.KINDS.size():
		sounds[Threat.row(type)["sound"]] = true
		shapes[Threat.row(type)["shape"]] = true
	_report("four sounds and glyphs", sounds.size() == 4 and shapes.size() == 4,
		"the four event_kinds rows name %d sound ids and %d glyph shapes" % [sounds.size(), shapes.size()])

	var d: Dictionary = instant.descriptor()
	var edge := _mark(d, "edge")
	var inside: bool = instant.contains(Vector3(5.95, 1.0, 0.0))
	var outside: bool = instant.contains(Vector3(6.05, 1.0, 0.0))
	_report("instant edge", is_equal_approx(edge.get("r_out", -1.0), instant.radius) and inside and not outside,
		"the edge is drawn at r %.2f and contains() flips there: 5.95 %s, 6.05 %s" % [edge.get("r_out", -1.0), inside, outside])
	instant.set_progress(0.25)
	var early: float = _mark(instant.descriptor(), "fill").get("inner", -1.0)
	instant.set_progress(0.75)
	var late: float = _mark(instant.descriptor(), "fill").get("inner", -1.0)
	var fill_layer: String = _mark(instant.descriptor(), "fill").get("layer", "")
	var band: float = _mark(instant.descriptor(), "band_top").get("height", -1.0)
	var before := _world.get_child_count()
	instant.set_progress(1.0)
	var flashed := _world.get_child_count() == before + 1
	_report("instant fill", is_equal_approx(early, 4.5) and is_equal_approx(late, 1.5) and fill_layer == "stripe_motion" and flashed
			and is_equal_approx(band, instant.reach_up),
		"the striped fill closes in from the edge (inner edge %.2f m at a quarter, %.2f m at three quarters of a 6 m ring), the landing leaves a solid flash (%s), and the height rail stands at %.1f m, the reach"
			% [early, late, flashed, band])

	lane.set_progress(0.5)
	var ld: Dictionary = lane.descriptor()
	var run := _mark(ld, "run")
	var rails := _mark(ld, "edge")
	var in_lane: bool = lane.contains(Vector3(10.9, 1.0, 41.45))
	var off_lane: bool = lane.contains(Vector3(10.9, 1.0, 41.55))
	_report("lane run", is_equal_approx(run.get("to", -1.0), 5.5) and is_equal_approx(rails.get("half_width", -1.0), lane.width * 0.5)
			and is_equal_approx(rails.get("length", -1.0), lane.length) and in_lane and not off_lane,
		"the fill runs from the source to %.2f of %.1f m at half the wind-up; rails at half width %.2f, contains() %s inside, %s outside"
			% [run.get("to", -1.0), lane.length, rails.get("half_width", -1.0), in_lane, off_lane])

	var pd: Dictionary = shell.descriptor()
	var bracket := _mark(pd, "bracket")
	var pip := _mark(pd, "pip")
	_report("projectile reticle", bracket.get("centre") == shell.center and pip.get("centre") == shell.center and shell.contains(shell.center + Vector3.UP),
		"brackets and pip centre on %s, the committed landing contains() tests" % [shell.center])
	for node in nodes:
		node.free()


# v3 F1a §1.3.1: past four overlapping hostile fills, they union into one shared mark
# and each member keeps only its edge/front/bracket/rail; contains() (the damage test)
# never changes, since the union functions are pure over descriptors and never touch a
# threat node.
func _check_union() -> void:
	var at := Vector3(200.0, 0.0, 0.0)
	var five: Array = []
	for i in 5:
		five.append(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, at, 6.0))
	var descs: Array = five.map(func(n): return n.descriptor())
	var before_contains: bool = five[0].contains(at)
	var union_marks := Threat.union_fill_marks_for(descs)
	var suppressed := Threat.suppressed_roles(descs)
	var after_contains: bool = five[0].contains(at)
	var kept: Array = Threat.roles_after_union(descs, 0)
	var expect_kept := ["band", "band_top", "edge", "solid"]
	_report("five overlapping fills union", union_marks.size() == 1 and union_marks[0]["role"] == "fill_union"
			and union_marks[0].get("members", 0) == 5 and suppressed.size() == 5 and kept == expect_kept
			and before_contains and after_contains,
		"5 overlapping INSTANT hostile fills at %s produce %d union mark(s) covering %s member(s); each keeps only %s; contains() reads %s before and %s after"
			% [at, union_marks.size(), union_marks[0].get("members", -1) if not union_marks.is_empty() else -1, kept, before_contains, after_contains])
	for n in five:
		n.free()

	var four: Array = []
	for i in 4:
		four.append(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, at, 6.0))
	var four_descs: Array = four.map(func(n): return n.descriptor())
	var no_union := Threat.union_fill_marks_for(four_descs)
	var no_suppression := Threat.suppressed_roles(four_descs)
	_report("four overlapping fills do not union", no_union.is_empty() and no_suppression.is_empty(),
		"the union rule is 'past four', so 4 overlapping fills draw as before: %d union marks, %d suppressed members"
			% [no_union.size(), no_suppression.size()])
	for n in four:
		n.free()

	# v3 F1a fix round 1, finding 5a: a hostile threat with no fill/area/swept/run role
	# yet (a WAVE still arming) never counts toward "more than four overlapping fills",
	# even five of them stacked on the same point.
	var arming: Array = []
	for i in 5:
		arming.append(Telegraph.wave(_world, _ground, at, 20.0, 8.0, 1.0))
	var arming_descs: Array = arming.map(func(n): return n.descriptor())
	var arming_roles: Array = Threat.roles(arming_descs[0])
	var no_fill_role := true
	for role in ["area", "fill", "swept", "run"]:
		if role in arming_roles:
			no_fill_role = false
	var arming_union := Threat.union_fill_marks_for(arming_descs)
	_report("arming waves have no fill role to union", no_fill_role and arming_union.is_empty(),
		"5 stacked arming WAVEs draw %s (no fill/area/swept/run role yet), so they union %d mark(s)"
			% [arming_roles, arming_union.size()])
	for n in arming:
		n.free()

	# Finding 5b: a chain of fills that each only overlap their immediate neighbour (no
	# point sits under more than two) must not union just because the chain is one
	# connected blob; only a group that all pairwise overlap does.
	var chain: Array = []
	for i in 5:
		chain.append(Telegraph.ring(_world, _ground, Threat.Type.INSTANT, at + Vector3(10.0 * i, 0.0, 0.0), 6.0))
	var chain_descs: Array = chain.map(func(n): return n.descriptor())
	var chain_union := Threat.union_fill_marks_for(chain_descs)
	var chain_suppressed := Threat.suppressed_roles(chain_descs)
	_report("a chain of pairwise overlaps does not union", chain_union.is_empty() and chain_suppressed.is_empty(),
		"5 rings 10 m apart (radius 6 m: each touches only its neighbour) produce %d union mark(s), %d suppressed members"
			% [chain_union.size(), chain_suppressed.size()])
	for n in chain:
		n.free()


func _check_stances() -> void:
	var lift: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, -90.0), 30.0, 8.0, Palette.SAND)
	var before := _world.get_child_count()
	lift.set_progress(1.0)
	var lift_roles := Threat.roles(lift.descriptor())
	_report("harmless field", lift_roles == ["outline"] and not lift.is_in_group(Threat.GROUP) and _world.get_child_count() == before
			and lift.contains(Vector3(20.0, 1.0, -90.0)),
		"a bone ring draws only %s, joins no threat group, leaves no flash, and still answers contains() for its lift" % [lift_roles])
	var mine: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(30.0, 0.0, -90.0), 3.6, 3.5, Palette.AMBER)
	var mine_striped: int = mine.painter().vertex_count("stripe") + mine.painter().vertex_count("stripe_motion")
	_report("player's own", mine_striped == 0 and not mine.is_in_group(Threat.GROUP) and mine.painter().vertex_count("base") > 0,
		"an amber ring draws clean (%d striped vertices) and joins no threat group" % mine_striped)
	var h: Node3D = Hazard.new()
	h.ground = func(_p: Vector3) -> float: return 0.0
	h.color = Palette.BRASS
	h.commit_annulus("slag_test", Threat.Type.INSTANT, Vector3(60.0, 0.0, -90.0), Vector2(8.0, 14.0), 1.8, 2.5, 6.0)
	_world.add_child(h)
	var hd: Dictionary = h.descriptor()
	var owner := _mark(hd, "owner")
	_report("boss owner mark", hd["tone"] == Palette.HAZARD and owner.get("owner") == Palette.BRASS and owner.get("tone") == Color(Palette.BRASS, 1.0)
			and h.is_in_group(Threat.GROUP) and h.painter().vertex_count("stripe") > 0,
		"a brass boss hazard draws its danger in HAZARD stripes and marks its owner with brass rim ticks")
	for node in [lift, mine, h]:
		node.free()


func _check_wave() -> void:
	var at := Vector3(0.0, 0.0, -40.0)
	var wave: Node3D = Telegraph.wave(_world, _ground, at, 20.0, 8.0, 1.0, 3.5)
	var clock := 0.0
	var arming_ok := true
	while clock < 0.95:
		wave.step(DT)
		clock += DT
		for r in [0.5, 5.0, 12.0]:
			arming_ok = arming_ok and not wave.contains(at + Vector3(r, 1.0, 0.0))
	_report("wave arming", arming_ok and wave.front_radius() < 0.0 and not _mark(wave.descriptor(), "front").is_empty(),
		"while it arms the front is drawn at its origin and contains() is false everywhere")
	var rows: Array = []
	var agree := true
	for t in [1.25, 1.5, 2.0, 2.75, 3.25]:
		while clock < t - DT * 0.5:
			wave.step(DT)
			clock += DT
		var d: Dictionary = wave.descriptor()
		var front := _mark(d, "front")
		var band := _mark(d, "band")
		var f: float = wave.front_radius()
		var drawn: float = front.get("radius", -1.0)
		var on: bool = wave.contains(at + Vector3(f, 1.0, 0.0))
		var ahead: bool = wave.contains(at + Vector3(f + Threat.WAVE_EDGE + 0.3, 1.0, 0.0))
		var behind: bool = f > Threat.WAVE_EDGE + 0.3 and wave.contains(at + Vector3(f - Threat.WAVE_EDGE - 0.3, 1.0, 0.0))
		var above: bool = wave.contains(at + Vector3(f, 3.6, 0.0))
		var ok: bool = absf(drawn - f) < 0.0001 and absf(f - 8.0 * (clock - 1.0)) < 0.001 and on and not ahead and not behind and not above \
			and is_equal_approx(band.get("height", -1.0), 3.5) and _mark(d, "swept").get("layer", "") == "stripe_motion"
		agree = agree and ok
		rows.append("t %.2f drawn %.2f damage %.2f" % [clock, drawn, f])
	_report("wave front", agree,
		"the drawn front is the damage front, speed x elapsed, with a 3.5 m band a jump clears and stripes on the swept ground: %s" % ", ".join(rows))
	wave.free()


func _check_sweep() -> void:
	var h: Node3D = Hazard.new()
	h.ground = func(_p: Vector3) -> float: return 0.0
	h.commit_sector("crane_test", Threat.Type.WAVE, Vector3(0.0, 0.0, 80.0), Vector2(3.0, 20.0), 0.2, 1.6, 5.0, 1.0, 1.2)
	_world.add_child(h)
	var rows: Array = []
	var agree := true
	var clock := 0.0
	for t in [1.1, 1.4, 1.8, 2.1]:
		while clock < t - DT * 0.5:
			h.step(DT)
			clock += DT
		var d: Dictionary = h.descriptor()
		var front := _mark(d, "front")
		var angle: float = front.get("angle", INF)
		var span: float = absf(h.a_to - h.a_from)
		var point: Vector3 = h.centre + Vector3(cos(angle), 0.0, sin(angle)) * 11.0
		var offset: float = h.sweep_offset(point)
		var ok: bool = h.is_live() and absf(angle - lerpf(h.a_from, h.a_to, h.live_fraction())) < 0.0001 and absf(offset - span * h.live_fraction()) < 0.0001
		agree = agree and ok
		rows.append("t %.2f drawn %.3f rad, sweep %.3f" % [clock, offset, span * h.live_fraction()])
	_report("crane sweep front", agree,
		"the drawn spoke sits at the sweep offset the boss's swept test reads (span x live fraction): %s" % ", ".join(rows))
	h.free()


func _check_projectile() -> void:
	var from := Vector3(10.0, 3.0, 120.0)
	var to := Vector3(-4.0, 0.0, 126.0)
	var shell: Node3D = Projectile.new()
	_world.add_child(shell)
	shell.setup(FarBall.new(), _ground, _world, Callable(), from, to, 1.9)
	var ring: Node3D = shell.ring
	var d: Dictionary = ring.descriptor()
	var trace := _mark(d, "trace")
	var points: PackedVector3Array = trace.get("points", PackedVector3Array())
	var landing := Vector3(to.x, 0.0, to.z)
	_report("shell reticle", ring.type == Threat.Type.PROJECTILE and ring.center.is_equal_approx(landing)
			and _mark(d, "bracket").get("centre") == ring.center and not points.is_empty() and points[points.size() - 1].is_equal_approx(ring.center),
		"the lobber's shell draws a %s reticle centred on %s, and its %d-dot trace ends at %s"
			% [Threat.kind(ring.type), ring.center, points.size(), points[points.size() - 1] if not points.is_empty() else Vector3.INF])
	var worst := 0.0
	var eaten := true
	var last_count := points.size()
	for i in int(1.8 / DT):
		shell._physics_process(DT)
		var s: float = shell._age / shell.flight
		worst = maxf(worst, shell.position.distance_to(Threat.flight_point(d["launch"], ring.center, d["bump"], s)))
		if i % 30 == 29:
			var now: PackedVector3Array = _mark(ring.descriptor(), "trace").get("points", PackedVector3Array())
			eaten = eaten and now.size() <= last_count and now[now.size() - 1].is_equal_approx(ring.center)
			last_count = now.size()
	var gap: float = _mark(ring.descriptor(), "bracket").get("gap", -1.0)
	_report("shell flight", worst < 0.001 and eaten and gap < ring.radius * 0.8,
		"the shell flies the drawn trace (worst %.5f m), the trace is eaten behind it and still ends on the landing, and the brackets closed to %.2f m (blast %.1f m)"
			% [worst, gap, ring.radius])
	shell.bat()
	var back: Node3D = shell.ring
	var bd: Dictionary = back.descriptor()
	var back_points: PackedVector3Array = _mark(bd, "trace").get("points", PackedVector3Array())
	_report("batted shell", back.type == Threat.Type.PROJECTILE and back.color == Palette.AMBER and not back_points.is_empty()
			and back_points[back_points.size() - 1].is_equal_approx(back.center),
		"a batted shell draws its own amber projectile reticle and trace to its new landing %s" % [back.center])
	shell.free()
