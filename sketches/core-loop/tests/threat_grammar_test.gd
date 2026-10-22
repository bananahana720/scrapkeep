extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")

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
	_check_driven()
	_check_drive_layers()
	_check_no_rebuild()
	_check_fill_classes()
	_check_line_priority()
	_check_warm_up()
	_check_haze()
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


# E1: a combat telegraph draws from Threat.drive(d), not marks(d, true). Its numbers must
# be the ones marks() draws and contains() tests, at a quarter, half and 95% of the warning.
func _check_driven() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 200.0), 6.0)
	var slam: Node3D = Telegraph.lane(_world, _ground, Threat.Type.INSTANT, Vector3(20.0, 0.0, 200.0), Vector3.FORWARD, 12.0, 4.0)
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 200.0), Vector3.FORWARD, 11.0, 3.0)
	var pull: Node3D = Telegraph.wedge(_world, _ground, Threat.Type.LANE, Vector3(60.0, 0.0, 200.0), Vector3.FORWARD, 9.0, 30.0)
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 200.0), 3.5)
	shell.set_flight(Vector3(92.0, 1.5, 188.0), 6.0)
	var wave: Node3D = Telegraph.wave(_world, _ground, Vector3(100.0, 0.0, 200.0), 10.0, 6.0, 0.5)
	var rows: Array = []
	var agree := true
	for p in [0.25, 0.5, 0.95]:
		for node in [ring, slam, lane, pull, shell]:
			node.set_progress(p)
		wave.age = wave.warn_seconds + p * wave.radius / wave.speed
		wave.set_progress(wave.age / wave.warn_seconds)
		var pairs := [
			[_drive(ring, "stripe_motion").get("inner"), _mark(ring.descriptor(), "fill").get("inner")],
			[_drive(slam, "stripe_motion").get("inner"), _mark(slam.descriptor(), "fill").get("inner")],
			[_drive(lane, "stripe_motion").get("to"), _mark(lane.descriptor(), "run").get("to")],
			[_drive(pull, "stripe_motion").get("to"), _mark(pull.descriptor(), "run").get("to")],
			[_drive(shell, "motion").get("gap"), _mark(shell.descriptor(), "bracket").get("gap")],
			[_drive(wave, "motion").get("radius"), _mark(wave.descriptor(), "front").get("radius")],
			[_drive(wave, "motion").get("inner"), _mark(wave.descriptor(), "front").get("inner")],
			[_drive(wave, "motion").get("outer"), _mark(wave.descriptor(), "front").get("outer")],
		]
		for pair in pairs:
			agree = agree and pair[0] != null and pair[1] != null and is_equal_approx(float(pair[0]), float(pair[1]))
		var f: float = wave.front_radius()
		var clip: Vector4 = _drive(wave, "motion")["clip"]
		var c: Vector3 = wave.center
		var edge := Threat.WAVE_EDGE
		var outer := minf(wave.radius, f + edge)
		var flips: bool = wave.contains(c + Vector3(outer - 0.02, 1.0, 0.0)) and not wave.contains(c + Vector3(outer + 0.02, 1.0, 0.0)) \
			and (f - edge < 0.05 or (wave.contains(c + Vector3(f - edge + 0.02, 1.0, 0.0)) and not wave.contains(c + Vector3(f - edge - 0.02, 1.0, 0.0))))
		var drawn: bool = is_equal_approx(clip.y, minf(wave.radius, f + edge)) and is_equal_approx(clip.x, maxf(0.0, f - edge))
		var ring_clip: Vector4 = _drive(ring, "stripe_motion")["clip"]
		var ring_edge: bool = ring.contains(ring.center + Vector3(ring.radius - 0.01, 1.0, 0.0)) and not ring.contains(ring.center + Vector3(ring.radius + 0.01, 1.0, 0.0)) \
			and is_equal_approx(ring_clip.x, ring.radius * (1.0 - p)) and ring_clip.y >= ring.radius
		agree = agree and flips and drawn and ring_edge
		rows.append("p %.2f wave front %.2f clip [%.2f, %.2f] flips %s, ring inner %.2f" % [p, f, clip.x, clip.y, flips, ring_clip.x])
	lane.set_progress(1.0)
	var live: Dictionary = _drive(lane, "stripe_motion")
	var end_ok: bool = is_equal_approx(float(live["to"]), lane.length) and lane.contains(lane.center + lane.dir * (lane.length - 0.01) + Vector3.UP) \
		and not lane.contains(lane.center + lane.dir * (lane.length + 0.01) + Vector3.UP) and is_equal_approx(float(live["alpha"]), Threat.LIVE_ALPHA / Threat.RUN_ALPHA)
	_report("driven numbers", agree and end_ok,
		"drive(d) gives the numbers marks(d, true) draws, the wave clip is contains()'s front band and the fill ends on its edge: %s; a live lane runs to %.1f m, where contains() ends"
			% ["; ".join(rows), float(live["to"])])
	for node in [ring, slam, lane, pull, shell, wave]:
		node.free()


# E1 fix round (finding 5b): drive() gives each layer one clip. A wave that is not
# hostile keeps its swept ground on "motion" with its front, so the swept clip would
# overwrite the front's; such a wave must stay on marks(). The control shows the
# overwrite is real, so the guard is load-bearing.
func _check_drive_layers() -> void:
	var node: Node3D = Telegraph.wave(_world, _ground, Vector3(0.0, 0.0, 250.0), 10.0, 6.0, 0.5)
	node.age = node.warn_seconds + 0.5 * node.radius / node.speed
	node.set_progress(node.age / node.warn_seconds)
	var hostile: Dictionary = node.descriptor()
	var rows: Array = []
	var ok: bool = Threat.can_drive(hostile) and float(Threat.drive(hostile)["motion"]["clip"].x) > 0.0
	rows.append("hostile wave drives %s, front clip from %.2f" % [Threat.can_drive(hostile), float(Threat.drive(hostile)["motion"]["clip"].x)])
	for tone in [Palette.AMBER, Palette.SAND]:
		var d := hostile.duplicate()
		d["tone"] = tone
		var clip: Vector4 = Threat.drive(d)["motion"]["clip"]
		var overwritten: bool = clip.x <= -Threat.FAR
		ok = ok and not Threat.can_drive(d) and (overwritten or Threat.stance(tone) == "neutral")
		rows.append("%s wave drives %s (its motion clip from %.0f would be the swept one: %s)" % [Threat.stance(tone), Threat.can_drive(d), clip.x, overwritten])
	var all_roles := {}
	for type in EXPECTED:
		for m in Threat.driven_marks(_descriptor_for(type)):
			all_roles[m["role"]] = true
	var unclassed: Array = []
	for role in all_roles:
		if not Density.CLASS_OF_ROLE.has(String(role).trim_suffix("_under")):
			unclassed.append(role)
	ok = ok and unclassed.is_empty() and not all_roles.is_empty()
	rows.append("every driven role has a class in Density.CLASS_OF_ROLE (%d roles, missing %s)" % [all_roles.size(), unclassed])
	node.free()
	_report("drive layers", ok, "; ".join(rows))


func _descriptor_for(type: int) -> Dictionary:
	var node: Node3D
	match type:
		Threat.Type.INSTANT:
			node = Telegraph.ring(_world, _ground, type, Vector3(0.0, 0.0, 260.0), 6.0)
		Threat.Type.LANE:
			node = Telegraph.lane(_world, _ground, type, Vector3(0.0, 0.0, 260.0), Vector3.FORWARD, 11.0, 3.0)
		Threat.Type.PROJECTILE:
			node = Telegraph.ring(_world, _ground, type, Vector3(0.0, 0.0, 260.0), 3.5)
			node.set_flight(Vector3(12.0, 1.5, 248.0), 6.0)
		_:
			node = Telegraph.wave(_world, _ground, Vector3(0.0, 0.0, 260.0), 10.0, 6.0, 0.5)
	node.set_progress(0.5)
	var d: Dictionary = node.descriptor()
	node.free()
	return d


func _drive(node: Node3D, layer: String) -> Dictionary:
	return Threat.drive(node.descriptor()).get(layer, {})


# E1: after commit a driven telegraph never rebuilds a mesh. The same check on a telegraph
# forced back onto the per-frame path must see rebuilds, so the check can fail.
func _check_no_rebuild() -> void:
	var nodes: Array = [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 300.0), 6.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(20.0, 0.0, 300.0), Vector3.FORWARD, 11.0, 3.0),
		Telegraph.wave(_world, _ground, Vector3(40.0, 0.0, 300.0), 10.0, 6.0, 0.5),
	]
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(60.0, 0.0, 300.0), 3.5)
	shell.set_flight(Vector3(72.0, 1.5, 288.0), 6.0)
	nodes.append(shell)
	var control: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(80.0, 0.0, 300.0), 6.0)
	control.set("_driven", false)
	var before := {}
	for node in nodes + [control]:
		before[node] = _meshes(node)
	for i in 100:
		for node in nodes + [control]:
			if node.type == Threat.Type.WAVE:
				node.step(0.02)
			else:
				node.set_progress(0.95 * i / 99.0)
	var kept := true
	var counts: Array = []
	for node in nodes:
		kept = kept and _meshes(node) == before[node]
		counts.append("%s %d" % [Threat.kind(node.type), node.painter().vertex_count("stripe_motion") + node.painter().vertex_count("motion")])
	var rebuilt: bool = _meshes(control) != before[control]
	_report("no rebuild", kept and rebuilt,
		"100 frames of progress leave every driven layer's mesh and vertex count unchanged (%s); the per-frame path rebuilds (%s)"
			% [", ".join(counts), rebuilt])
	for node in nodes + [control]:
		node.free()


# The stencil value a driven layer's material writes and tests ("compare_not_equal, N").
func _stencil(node: Node3D, layer: String) -> int:
	var instance: MeshInstance3D = node.painter()._layers[layer]
	var code: String = (instance.material_override as ShaderMaterial).shader.code
	var at := code.find("compare_not_equal, ")
	return int(code.substr(at + 19)) if at >= 0 else 0


# What a fill layer draws its alpha at (vertex colours are 8-bit, so within about 0.004): the largest vertex alpha, times alpha_scale where the
# vertices ask for it (CUSTOM1.y), as the shader does.
func _fill_alpha(node: Node3D, layer: String) -> float:
	var instance: MeshInstance3D = node.painter()._layers[layer]
	var arrays: Array = (instance.mesh as ArrayMesh).surface_get_arrays(0)
	var alpha := 0.0
	for c in arrays[Mesh.ARRAY_COLOR]:
		alpha = maxf(alpha, c.a)
	var scaled: float = arrays[Mesh.ARRAY_CUSTOM1][1]
	var set_scale = instance.get_instance_shader_parameter("alpha_scale")
	var scale: float = 1.0 if set_scale == null else float(set_scale)
	return alpha * (scale if scaled > 0.5 else 1.0)


# Fills unioned in one stencil class draw once, so one class must mean one alpha (an
# overlap shows whichever drew first, which flips with camera depth); and a live lane
# batches after a pending one, a fill and a swept ring, so its band always wins. Under the
# default haze every hostile fill alpha is scaled by HAZE_FILL (1.15): 0.4025 pending, 0.92 live. The 8-bit vertex colour
# truncates the pending alpha by up to one step (1/255), and the live alpha is that stored value times
# LIVE_ALPHA / RUN_ALPHA, so live may fall short of its target by that step times the ratio (0.0090) and
# never exceeds it. Measured under haze (Godot 4.7.2 headless): pending 0.4000 and live 0.9143 (0.0025 and 0.0057 short of
# 0.4025 and 0.92). The pending INSTANT fill measures 0.4000 too, so HAZE_SOLID 0.61 leaves a live-over-pending
# step of 0.21, checked below against ATTACK-READS.md:27 and ruling 6331787112 (at least 0.2). The classic alphas are not checked here.
func _check_fill_classes() -> void:
	var ring: Node3D = Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 400.0), 6.0)
	var wedge: Node3D = Telegraph.wedge(_world, _ground, Threat.Type.LANE, Vector3(20.0, 0.0, 400.0), Vector3.FORWARD, 9.0, 30.0)
	var lane: Node3D = Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 400.0), Vector3.FORWARD, 11.0, 3.0)
	var wave: Node3D = Telegraph.wave(_world, _ground, Vector3(60.0, 0.0, 400.0), 10.0, 6.0, 0.5)
	var shell: Node3D = Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 400.0), 3.5)
	shell.set_flight(Vector3(92.0, 1.5, 388.0), 6.0)
	var nodes: Array = [ring, wedge, lane, wave, shell]
	for node in [ring, wedge, lane, shell]:
		node.set_progress(0.5)
	wave.step(1.0)
	var alphas := {}
	for node in nodes:
		for layer in ["stripe", "stripe_motion"]:
			var instance: MeshInstance3D = node.painter()._layers.get(layer)
			if instance == null or instance.mesh == null:
				continue
			var key := _stencil(node, layer)
			var alpha := snappedf(_fill_alpha(node, layer), 0.001)
			if not alphas.has(key):
				alphas[key] = []
			if not alpha in alphas[key]:
				alphas[key].append(alpha)
	var one_alpha := true
	for key in alphas:
		one_alpha = one_alpha and alphas[key].size() == 1
	var reach_apart: bool = _stencil(shell, "stripe") != _stencil(ring, "stripe")
	# A pending lane, then the same lane live: the class and the batch move it after the rest.
	var pending_class := _stencil(lane, "stripe_motion")
	var pending_sort: float = lane.painter()._layers["stripe_motion"].sorting_offset
	var pending_alpha := _fill_alpha(lane, "stripe_motion")
	lane.set_progress(1.0)
	var live_class := _stencil(lane, "stripe_motion")
	var live_sort: float = lane.painter()._layers["stripe_motion"].sorting_offset
	var live_alpha := _fill_alpha(lane, "stripe_motion")
	var swept_sort: float = wave.painter()._layers["stripe_motion"].sorting_offset
	var live_priority: int = (lane.painter()._layers["stripe_motion"].material_override as ShaderMaterial).render_priority
	var after_all: bool = live_sort > pending_sort and live_sort > swept_sort and live_sort > Threat.FILL_SORT["fill"] \
		and live_priority > Threat.PRIORITY
	lane.set_progress(0.5)
	var back_to_run: bool = _stencil(lane, "stripe_motion") == pending_class
	# The live slag (HAZE_SOLID) over the pending INSTANT fill, which the ring drew just above.
	var instant_pending := _fill_alpha(ring, "stripe_motion")
	var slag_step: float = Threat.HAZE_SOLID - instant_pending
	_report("live slag over pending fill", Threat.haze() and instant_pending > 0.39 and slag_step >= 0.2 - 0.0001,
		"pending INSTANT fill alpha %.4f measured, live slag alpha %.2f, step %.4f (at least 0.2, ruling 6331787112; ATTACK-READS.md:27)"
			% [instant_pending, Threat.HAZE_SOLID, slag_step])
	var step := 1.0 / 255.0
	var pending_target: float = Threat.RUN_ALPHA * Threat.HAZE_FILL
	var live_target: float = Threat.LIVE_ALPHA * Threat.HAZE_FILL
	var live_short: float = step * Threat.LIVE_ALPHA / Threat.RUN_ALPHA
	var pending_in: bool = pending_alpha <= pending_target + 0.0005 and pending_alpha > pending_target - step - 0.0005
	var live_in: bool = live_alpha <= live_target + 0.0005 and live_alpha > live_target - live_short - 0.0005
	_report("fill classes", one_alpha and reach_apart and live_class != pending_class and after_all and back_to_run
			and Threat.haze() and pending_in and absf(live_alpha - pending_alpha * Threat.LIVE_ALPHA / Threat.RUN_ALPHA) < 0.001 and live_in,
		"stencil value -> alphas drawn %s (one alpha each: %s); the projectile's footprint is its own class (%s); a lane goes from class %d (alpha %.2f, sort %.0f) to class %d (alpha %.2f, sort %.0f, after the swept ring at %.0f, priority %d over the fills' %d) live, and back on a retarget (%s); pending %.4f against %.4f and live %.4f against %.4f, each at most 0.0005 over and at most one 8-bit step (%.4f) or that step times LIVE_ALPHA / RUN_ALPHA (%.4f) short"
			% [alphas, one_alpha, reach_apart, pending_class, pending_alpha, pending_sort, live_class, live_alpha, live_sort, swept_sort, live_priority, Threat.PRIORITY, back_to_run, pending_alpha, pending_target, live_alpha, live_target, step, live_short])
	for node in nodes:
		node.free()


# A P1 line is never covered by a fill (FEEL-READABILITY.md section 1.1), so every hot line
# layer of every telegraph draws above the live lane's band, and each keyline stays under
# the fills (lifting it changes the look); and the class
# sort offsets sit at least 1000 apart, more than the camera far plane's 700 m.
func _check_line_priority() -> void:
	var nodes: Array = [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 400.0), 6.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 400.0), Vector3.FORWARD, 11.0, 3.0),
		Telegraph.wave(_world, _ground, Vector3(60.0, 0.0, 400.0), 10.0, 6.0, 0.5),
		Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 400.0), 3.5),
	]
	nodes[1].set_progress(1.0)
	nodes[3].set_flight(Vector3(92.0, 1.5, 388.0), 6.0)
	nodes[0].set_progress(0.5)
	nodes[3].set_progress(0.5)
	nodes[2].step(1.0)
	var live_priority := Threat.LIVE_PRIORITY
	var seen := 0
	var above := true
	var ordered := true
	for node in nodes:
		var layers: Dictionary = node.painter()._layers
		for layer in ["base", "motion"]:
			if not layers.has(layer):
				continue
			var priority: int = layers[layer].material_override.render_priority
			seen += 1
			above = above and priority > live_priority
		for layer in ["under", "motion_under"]:
			if layers.has(layer):
				ordered = ordered and layers[layer].material_override.render_priority < Threat.PRIORITY
	var sorts: Array = Threat.FILL_SORT.values()
	sorts.sort()
	var spaced := true
	for i in range(1, sorts.size()):
		spaced = spaced and sorts[i] - sorts[i - 1] >= 1000.0
	_report("P1 lines above the live band", seen >= 8 and above and ordered and spaced,
		"%d hot line layers across INSTANT, LANE, WAVE and PROJECTILE all render above the live band (priority %d): %s, keylines under the fills: %s; class sort offsets %s at least 1000 apart: %s"
			% [seen, live_priority, above, ordered, sorts, spaced])
	for node in nodes:
		node.free()


# Every mark pipeline is compiled before play: after warm_up the shared material cache
# holds exactly warm_keys(), and driving every threat type through its states (a live lane,
# a projectile with a flight, a wave, an owned and a neutral fill) creates no new key.
func _check_warm_up() -> void:
	var holder := Threat.Painter.warm_up(_world)
	var keys := Threat.Painter.warm_keys()
	var cache: Dictionary = Threat.Painter._materials
	var listed := true
	for key in keys:
		listed = listed and cache.has("%s/%s/%d/%s" % [key[0], key[1], key[2], key[3]])
	var warmed_size := cache.size()
	var built := Threat.Painter.materials_built
	var nodes: Array = [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 400.0), 6.0),
		Telegraph.wedge(_world, _ground, Threat.Type.LANE, Vector3(20.0, 0.0, 400.0), Vector3.FORWARD, 9.0, 30.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 400.0), Vector3.FORWARD, 11.0, 3.0),
		Telegraph.wave(_world, _ground, Vector3(60.0, 0.0, 400.0), 10.0, 6.0, 0.5),
		Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(80.0, 0.0, 400.0), 3.5),
	]
	nodes[4].set_flight(Vector3(92.0, 1.5, 388.0), 6.0)
	for p in [0.25, 0.5, 0.95, 1.0]:
		for node in nodes:
			if node.type != Threat.Type.WAVE:
				node.set_progress(p)
		nodes[3].step(0.5)
	var stable: bool = cache.size() == warmed_size and Threat.Painter.materials_built == built
	_report("warm-up covers every mark key", holder != null and listed and warmed_size == keys.size() and stable,
		"warm_up built %d materials, exactly warm_keys() (%d listed, all present: %s); five telegraphs through 25%%, 50%%, 95%% and live built %d more" % [warmed_size, keys.size(), listed, Threat.Painter.materials_built - built])
	for node in nodes:
		node.free()
	if holder != null:
		holder.free()


func _meshes(node: Node3D) -> Dictionary:
	var out := {}
	var layers: Dictionary = node.painter()._layers
	for layer in layers:
		var mesh: Mesh = layers[layer].mesh
		out[layer] = [mesh.get_instance_id() if mesh != null else 0, node.painter().vertex_count(layer)]
	return out


# --telegraph=haze: a hostile fill is a red haze without stripes; every P1 line, the
# geometry, contains() and the drive are the classic ones. Fails if a fill draws at or above
# a P1 line's priority, a fill carries stripes or the wrong alpha, a line changes, or a
# hit test differs between the modes.
func _haze_nodes() -> Array:
	var nodes: Array = [
		Telegraph.ring(_world, _ground, Threat.Type.INSTANT, Vector3(0.0, 0.0, 400.0), 6.0),
		Telegraph.wedge(_world, _ground, Threat.Type.LANE, Vector3(40.0, 0.0, 400.0), Vector3.FORWARD, 9.0, 30.0),
		Telegraph.lane(_world, _ground, Threat.Type.LANE, Vector3(80.0, 0.0, 400.0), Vector3.FORWARD, 11.0, 3.0),
		Telegraph.wave(_world, _ground, Vector3(120.0, 0.0, 400.0), 10.0, 6.0, 0.5),
		Telegraph.ring(_world, _ground, Threat.Type.PROJECTILE, Vector3(160.0, 0.0, 400.0), 3.5),
	]
	nodes[4].set_flight(Vector3(172.0, 1.5, 388.0), 6.0)
	return nodes


func _hit_map(nodes: Array, progress: float) -> String:
	var out := ""
	for node in nodes:
		if node.type == Threat.Type.WAVE:
			node.step(0.4)
		else:
			node.set_progress(progress)
		var c: Vector3 = node.descriptor()["centre"]
		for ix in range(-16, 17):
			for iz in range(-16, 17):
				out += "1" if node.contains(c + Vector3(ix * 0.75, 0.0, iz * 0.75)) else "0"
	return out


func _check_haze() -> void:
	Threat.set_haze(false)
	var classic_drive = Threat.drive(_descriptor_for(Threat.Type.LANE))
	var classic_hits := {}
	var classic_nodes := _haze_nodes()
	for p in [0.25, 0.5, 0.95]:
		classic_hits[p] = _hit_map(classic_nodes, p)
	var classic_marks := {}
	for i in classic_nodes.size():
		classic_marks[i] = Threat.all_marks(classic_nodes[i].descriptor())
		classic_nodes[i].free()
	Threat.set_haze(true)
	var hits_same := true
	var lines_same := true
	var fills_red := true
	var fills_seen := 0
	var no_stripes := true
	var lines_above := true
	var alive := true
	var nodes := _haze_nodes()
	for p in [0.25, 0.5, 0.95]:
		hits_same = hits_same and _hit_map(nodes, p) == classic_hits[p]
		for node in nodes:
			var layers: Dictionary = node.painter()._layers
			var fill_top := 0
			var line_bottom := 1000
			for layer in layers:
				var instance: MeshInstance3D = layers[layer]
				if instance.mesh == null:
					continue
				var mat := instance.material_override
				var priority: int = mat.render_priority
				if layer.begins_with("stripe"):
					fills_seen += 1
					fill_top = maxi(fill_top, priority)
					no_stripes = no_stripes and mat is ShaderMaterial and not "#define STRIPES" in (mat as ShaderMaterial).shader.code
					var alpha := _fill_alpha(node, layer)
					alive = alive and alpha > 0.03 and alpha < 0.5
				elif layer in ["base", "motion"]:
					line_bottom = mini(line_bottom, priority)
			lines_above = lines_above and line_bottom > fill_top
	for i in nodes.size():
		for m in Threat.all_marks(nodes[i].descriptor()):
			var was: Dictionary = {}
			for c in classic_marks[i]:
				if c["role"] == m["role"] and c["layer"] == m["layer"]:
					was = c
			if was.is_empty():
				continue
			if m["role"] in ["area", "fill", "swept", "run"]:
				var tone: Color = m["tone"]
				fills_red = fills_red and tone.is_equal_approx(Color(Palette.HAZARD, was["tone"].a * Threat.HAZE_FILL)) \
					and m["tris"] == was["tris"]
			else:
				lines_same = lines_same and m["tone"] == was["tone"] and m["tris"] == was["tris"] and m["layer"] == was["layer"]
	var live_desc := _descriptor_for(Threat.Type.INSTANT)
	live_desc["live"] = true
	var solid_alpha := Threat.fill_tint(live_desc).a
	var drive_same: bool = Threat.drive(_descriptor_for(Threat.Type.LANE)) == classic_drive
	_report("haze look", hits_same and lines_same and fills_red and fills_seen >= 8 and no_stripes and lines_above and alive
			and absf(solid_alpha - Threat.HAZE_SOLID) < 0.001 and drive_same,
		"contains() over 5 telegraphs x 3 progress samples equals classic (%s); every P1 line mark is unchanged (%s); every fill is HAZARD at %.2f of its classic alpha with the same tris (%s, %d fill layers seen); no fill layer carries stripes (%s); every fill renders under every P1 line (%s); each fill draws visibly at 25/50/95%% (%s); live slag alpha %.2f"
			% [hits_same, lines_same, Threat.HAZE_FILL, fills_red, fills_seen, no_stripes, lines_above, alive, solid_alpha])
	for node in nodes:
		node.free()
	Threat.set_haze(false)
