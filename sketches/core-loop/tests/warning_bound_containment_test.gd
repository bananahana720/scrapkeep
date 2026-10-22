extends SceneTree

# The cached warning box holds what the painter draws (lighting L7, #297). Every hostile mark
# computes one world box at commit (Telegraph/Hazard.screen_bound_box, WarningBound) and
# PlayerFx.warning_rects projects it instead of walking meshes, so the box must contain the
# merged mesh box at every progress, on flat and bumpy ground, and the box's screen rect must
# contain the mesh walk's. A planted shrunk box proves the check can fail. No clock is read.
const T := preload("res://tests/support/t.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const Palette := preload("res://src/core/palette.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")

# The slack the containment check allows (task: 1e-3), in metres.
const TOLERANCE := 1.0e-3
# And for the on-screen rect check, in pixels (the same figure; a sub-pixel miss is not seen).
const PIXEL_TOLERANCE := 1.0e-3

var t := T.new("warning_bound_containment_test")
var _world: Node3D
var _grounds := {}
# The quenched annulus case: true while its east half is quenched.
var _quench := [true]
var _cases := 0
var _slack_worst := INF
var _slack_label := ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


class Flat:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


# A uniform slope in both axes.
class Slope:
	extends RefCounted

	func height(x: float, z: float) -> float:
		return 0.2 * z - 0.1 * x


# Smooth bumps of 1.5 m, a wavelength of about 7 m: more curvature than the stage's ground.
class Bumpy:
	extends RefCounted

	func height_at(point: Vector3) -> float:
		return 1.5 * sin(point.x * 0.9) * cos(point.z * 0.7) + 0.2 * point.x


# Terrain's own shape: a 2 m heightfield, two triangles a cell split on the b-c diagonal
# (terrain.gd), with hashed heights up to 3 m, so it has kinks on every cell edge.
class Field:
	extends RefCounted

	func _h(i: int, j: int) -> float:
		return float((i * 73856093 ^ j * 19349663) % 7) * 0.5

	func height(x: float, z: float) -> float:
		var s := Terrain.STEP
		var i := int(floor(x / s))
		var j := int(floor(z / s))
		var fx := x / s - i
		var fz := z / s - j
		var a := _h(i, j)
		var b := _h(i + 1, j)
		var c := _h(i, j + 1)
		var d := _h(i + 1, j + 1)
		if fx + fz <= 1.0:
			return a + fx * (b - a) + fz * (c - a)
		return d + (1.0 - fx) * (c - d) + (1.0 - fz) * (b - d)


func _run() -> void:
	_grounds = {"flat": Flat.new(), "slope": Slope.new(), "bumpy": Bumpy.new(), "field": Field.new()}
	_world = Node3D.new()
	root.add_child(_world)
	for ground_name in _grounds:
		await _telegraphs(ground_name)
		await _hazards(ground_name)
	await _fallbacks()
	_planted()
	await _frames(2)
	print("warning_bound_containment: %d cases, tightest slack %.4f m (%s)" % [_cases, _slack_worst, _slack_label])
	_world.free()
	quit(t.verdict())


# --- Cases ---------------------------------------------------------------------------------

# Each telegraph shape and type, at its progress values; the callable builds it on `ground`.
func _telegraphs(ground_name: String) -> void:
	var ground = _grounds[ground_name]
	var at := Vector3(6.0, 0.0, -4.0)
	var heading := Vector3(0.6, 0.0, 0.8)
	var builds := {
		"ring INSTANT": func() -> Node3D: return Telegraph.ring(_world, ground, Threat.Type.INSTANT, at, 6.0),
		"ring INSTANT small": func() -> Node3D: return Telegraph.ring(_world, ground, Threat.Type.INSTANT, at, 0.8),
		"ring INSTANT big": func() -> Node3D: return Telegraph.ring(_world, ground, Threat.Type.INSTANT, at, 40.0, 3.5),
		"ring INSTANT tall": func() -> Node3D: return Telegraph.ring(_world, ground, Threat.Type.INSTANT, at, 6.0, 9.0),
		"ring PROJECTILE": func() -> Node3D: return Telegraph.ring(_world, ground, Threat.Type.PROJECTILE, at, 3.0),
		"ring PROJECTILE flight": func() -> Node3D:
			var ring: Node3D = Telegraph.ring(_world, ground, Threat.Type.PROJECTILE, at, 3.0)
			ring.set_flight(at + Vector3(-30.0, 14.0, 22.0), 9.0)
			return ring,
		"ring PROJECTILE flight down": func() -> Node3D:
			var ring: Node3D = Telegraph.ring(_world, ground, Threat.Type.PROJECTILE, at, 1.0)
			ring.set_flight(at + Vector3(10.0, 25.0, -8.0), 4.0)
			return ring,
		"ring WAVE": func() -> Node3D: return Telegraph.wave(_world, ground, at, 18.0, 12.0, 1.0),
		"lane LANE": func() -> Node3D: return Telegraph.lane(_world, ground, Threat.Type.LANE, at, heading, 24.0, 4.0),
		"lane INSTANT": func() -> Node3D: return Telegraph.lane(_world, ground, Threat.Type.INSTANT, at, heading, 10.0, 8.0),
		"wedge LANE": func() -> Node3D: return Telegraph.wedge(_world, ground, Threat.Type.LANE, at, heading, 22.0, 35.0),
		"wedge INSTANT wide": func() -> Node3D: return Telegraph.wedge(_world, ground, Threat.Type.INSTANT, at, heading, 12.0, 100.0),
	}
	for label in builds:
		var node: Node3D = builds[label].call()
		await _frames(1)
		var name := "%s / %s" % [label, ground_name]
		# Progress 0, half, 1 and "live": a WAVE's front at the middle and the end of its run.
		var steps: Array = [0.0, 0.5, 1.0]
		if node.type == Threat.Type.WAVE:
			steps = [0.0, 0.5, 1.0, 1.0 + 0.5 * node.radius / node.speed, 1.0 + node.radius / node.speed]
		for p in steps:
			if node.type == Threat.Type.WAVE:
				node.age = p * node.warn_seconds
				node.step(0.0)
			else:
				node.set_progress(p)
			_contained(node, "%s p=%.2f" % [name, p])
		_projected(node, name)
		node.free()
		await _frames(1)


func _hazards(ground_name: String) -> void:
	var ground = _grounds[ground_name]
	var at := Vector3(-8.0, 0.0, 5.0)
	var heading := Vector3(-0.8, 0.0, 0.6)
	var specs := {
		"sector WAVE": [func(h: Node3D) -> void: h.commit_sector("t_sw", Threat.Type.WAVE, at, Vector2(3.0, 28.0), 0.4, 2.2, 3.5, 1.0, 2.0)],
		"sector WAVE backwards": [func(h: Node3D) -> void: h.commit_sector("t_swb", Threat.Type.WAVE, at, Vector2(0.0, 12.0), 5.5, 3.0, 3.5, 1.0, 2.0)],
		"sector WAVE crossing axes": [func(h: Node3D) -> void: h.commit_sector("t_swx", Threat.Type.WAVE, at, Vector2(2.0, 20.0), -1.0, 4.5, 3.0, 1.0, 2.0)],
		"sector INSTANT": [func(h: Node3D) -> void: h.commit_sector("t_si", Threat.Type.INSTANT, at, Vector2(2.0, 15.0), 1.0, 2.0, 3.0, 1.0, 1.0)],
		"annulus INSTANT": [func(h: Node3D) -> void: h.commit_annulus("t_a", Threat.Type.INSTANT, at, Vector2(6.0, 14.0), 3.5, 1.0, 1.0)],
		"annulus INSTANT disc": [func(h: Node3D) -> void: h.commit_annulus("t_ad", Threat.Type.INSTANT, at, Vector2(0.0, 2.5), 0.0, 1.0, 1.0)],
		"annulus INSTANT quenched": [func(h: Node3D) -> void:
			h.commit_annulus("t_aq", Threat.Type.INSTANT, at, Vector2(6.0, 14.0), 3.5, 1.0, 1.0)
			h.excluded = func(point: Vector3) -> bool: return _quench[0] and point.x > at.x],
		"annulus LANE": [func(h: Node3D) -> void: h.commit_annulus("t_al", Threat.Type.LANE, at, Vector2(4.0, 16.0), 3.0, 1.0, 1.0)],
		"annulus PROJECTILE": [func(h: Node3D) -> void: h.commit_annulus("t_ap", Threat.Type.PROJECTILE, at, Vector2(0.0, 5.0), 3.0, 1.0, 1.0)],
		"lane LANE": [func(h: Node3D) -> void: h.commit_lane("t_l", Threat.Type.LANE, at, heading, 2.0, 30.0, 3.0, 3.0, 1.0, 1.0)],
		"lane INSTANT": [func(h: Node3D) -> void: h.commit_lane("t_li", Threat.Type.INSTANT, at, heading, 0.0, 12.0, 6.0, 3.0, 1.0, 1.0)],
	}
	for label in specs:
		# Plain, and again with the owner's brass rim ticks (Brindle's attacks).
		for owner in [false, true]:
			_quench[0] = label == "annulus INSTANT quenched"
			var hazard := Hazard.new()
			hazard.ground = func(point: Vector3) -> float: return ground.height_at(point) if ground.has_method("height_at") else ground.height(point.x, point.z)
			if owner:
				hazard.color = Palette.BRASS
			specs[label][0].call(hazard)
			_world.add_child(hazard)
			await _frames(1)
			var name := "hazard %s%s / %s" % [label, " brass" if owner else "", ground_name]
			var warn: float = hazard.warn_seconds
			var live: float = hazard.live_seconds
			# Progress 0, half, 1; then LIVE at the middle and just before it ends.
			var ages := [0.0, warn * 0.5, warn, warn + live * 0.5, warn + live * 0.99]
			var done_age := 0.0
			var quenched: bool = label == "annulus INSTANT quenched"
			if quenched:
				# It starts with spans quenched, so it has no full paint yet: no box (the rects
				# walk the meshes), until the quench lifts; then the box is cut, and a later
				# quench, which only removes drawn spans, stays inside it.
				hazard.step(0.0)
				t.eq("%s: no box while spans are quenched at the start" % name, hazard.screen_bound_box(), AABB())
				_quench[0] = false
				hazard.step(0.0)
				t.check("%s: boxed after its first full paint" % name, hazard.screen_bound_box().size != Vector3.ZERO)
			for age in ages:
				hazard.step(age - done_age)
				done_age = age
				if quenched and age == ages[2]:
					_quench[0] = true
				_contained(hazard, "%s age=%.2f" % [name, age])
			_projected(hazard, name)
			hazard.step(warn + live)
			t.check("%s: finished: no box, no rect (its painter is hidden)" % name, hazard.is_done() and hazard.screen_bound_box().size == Vector3.ZERO and PlayerFx.warning_rects(root.get_tree(), _camera(Vector3.ZERO, 0.0), 0.0).size() == 0)
			hazard.free()
			await _frames(1)


# A mark carried off its commit (the Warden's mounting moves a pulse ring) and a mark with no
# box fall back to the mesh walk, so the rect still comes.
func _fallbacks() -> void:
	var ground := Flat.new()
	var ring: Node3D = Telegraph.ring(_world, ground, Threat.Type.INSTANT, Vector3(2.0, 0.0, 2.0), 4.0)
	await _frames(1)
	t.check("fallback: a committed ring has a box", ring.screen_bound_box().size != Vector3.ZERO)
	ring.center += Vector3(3.0, 0.0, 0.0)
	ring.global_position += Vector3(3.0, 0.0, 0.0)
	t.eq("fallback: a ring carried off its commit has no box", ring.screen_bound_box(), AABB())
	var cam := _camera(ring.center, 0.0)
	var fallback := PlayerFx.warning_rects(root.get_tree(), cam, 0.0)
	var walked := PlayerFx.warning_rects(root.get_tree(), cam, 0.0, false)
	t.check("fallback: the carried ring still gets its mesh rect", fallback.size() == 1 and walked.size() == 1 and fallback[0].is_equal_approx(walked[0]), "%s vs %s" % [fallback, walked])
	ring.free()
	var amber: Node3D = Telegraph.ring(_world, ground, Threat.Type.INSTANT, Vector3(2.0, 0.0, 2.0), 4.0, 3.5, Palette.AMBER)
	await _frames(1)
	t.check("non-hostile: an amber ring is outside the group and has no box", not amber.is_in_group(Threat.GROUP) and amber.screen_bound_box() == AABB())
	amber.free()
	var bare := Node3D.new()
	bare.add_to_group(Threat.GROUP)
	_world.add_child(bare)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(4.0, 4.0)
	plane.mesh = mesh
	bare.add_child(plane)
	var meshes_only := PlayerFx.warning_rects(root.get_tree(), _camera(Vector3.ZERO, 0.0), 0.0)
	t.eq("fallback: a node with no screen_bound_box is walked", meshes_only.size(), 1)
	bare.free()
	await _frames(1)


# --- Checks --------------------------------------------------------------------------------

func _mesh_box(node: Node) -> AABB:
	var merged := [AABB(), false]
	PlayerFx._merge_meshes(node, merged)
	return merged[0] if merged[1] else AABB()


# How far inside `outer` the `inner` box sits on its tightest face; negative if it pokes out.
static func _slack(outer: AABB, inner: AABB) -> float:
	var lo := inner.position - outer.position
	var hi := outer.end - inner.end
	return minf(minf(lo.x, lo.y), minf(minf(lo.z, hi.x), minf(hi.y, hi.z)))


func _contained(node: Node3D, label: String) -> void:
	var bound: AABB = node.screen_bound_box()
	var mesh := _mesh_box(node)
	_cases += 1
	if bound.size == Vector3.ZERO or mesh.size == Vector3.ZERO:
		t.check("contained: %s" % label, false, "box %s, meshes %s" % [bound, mesh])
		return
	var slack := _slack(bound, mesh)
	if slack < _slack_worst:
		_slack_worst = slack
		_slack_label = label
	t.check("contained: %s" % label, bound.grow(TOLERANCE).encloses(mesh), "slack %.4f m, box %s, meshes %s" % [slack, bound, mesh])


# The box's screen rect holds the mesh walk's, through a chase-like camera over the mark's
# centre (the near plane crosses big marks) and a yawed one.
func _projected(node: Node3D, label: String) -> void:
	var centre: Vector3 = node.center if "center" in node else node.centre
	for yaw in [0.0, 2.3]:
		var cam := _camera(centre, yaw)
		var tree := root.get_tree()
		var boxed := PlayerFx.warning_rects(tree, cam, 0.0)
		var walked := PlayerFx.warning_rects(tree, cam, 0.0, false)
		var ok := boxed.size() == walked.size() and boxed.size() <= 1
		if ok and walked.size() == 1:
			# The shader only discards inside the viewport, so the rects are compared there: a
			# near-plane clip puts rect edges at 1e4 to 1e6 px, where float noise is larger
			# than TOLERANCE.
			var view := Rect2(Vector2.ZERO, cam.get_viewport().get_visible_rect().size)
			var seen: Rect2 = view.intersection(walked[0])
			ok = seen.size == Vector2.ZERO or (boxed[0] as Rect2).grow(PIXEL_TOLERANCE).encloses(seen)
		t.check("projected: %s yaw %.1f" % [label, yaw], ok, "box %s, walk %s" % [boxed, walked])
		cam.free()


# The chase camera's rig: arm 8 m, pitch from the rig, fov 65 (chase_camera.gd), over a ball
# resting at `ball`, turned `yaw` about +y.
func _camera(ball: Vector3, yaw: float) -> Camera3D:
	var rig := ChaseCamera.new()
	var pitch: float = rig.pitch
	rig.free()
	var cam := Camera3D.new()
	_world.add_child(cam)
	cam.fov = 65.0
	cam.far = 700.0
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	cam.basis = basis
	cam.position = ball + basis * Vector3(0.0, 0.0, 8.0)
	return cam


# A box shrunk to half its size must fail the same check, so a pass above means something.
func _planted() -> void:
	var ring: Node3D = Telegraph.ring(_world, Flat.new(), Threat.Type.INSTANT, Vector3(4.0, 0.0, 4.0), 6.0)
	var bound: AABB = ring.screen_bound_box()
	var mesh := _mesh_box(ring)
	t.check("planted: the true box contains the meshes", bound.grow(TOLERANCE).encloses(mesh))
	var shrunk := AABB(bound.position + bound.size * 0.25, bound.size * 0.5)
	t.check("planted: a box shrunk to half fails containment", not shrunk.grow(TOLERANCE).encloses(mesh), "slack %.3f m" % _slack(shrunk, mesh))
	var nudged := AABB(bound.position, bound.size - Vector3(0.0, 0.5, 0.0))
	t.check("planted: a box 0.5 m short in y fails containment", not nudged.grow(TOLERANCE).encloses(mesh), "slack %.3f m" % _slack(nudged, mesh))
	ring.free()
