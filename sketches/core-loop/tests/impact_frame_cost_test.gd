extends SceneTree

# What the impact frame costs (lighting L7, #241), minus the clock. Inactive cost is provably
# zero: while no frame is alive the rect source is never called, no uniform is written and
# nothing redraws. A fire builds its pieces once and refreshes the rects on every live frame,
# more rects than the shader holds draw nothing, and warning_rects keeps a rect for every
# mark that contains the old per-mesh one. Timing lives in tools/impact_frame_bench.gd; tests
# do not read the wall clock.
const T := preload("res://tests/support/t.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ImpactFrame := preload("res://src/presentation/impact_frame.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const ChaseCamera := preload("res://src/movement/chase_camera.gd")

const SCREEN := Vector2(1920.0, 1080.0)

var t := T.new("impact_frame_cost_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _inactive()
	await _moving()
	await _overflow()
	_placement()
	await _rects()
	await _near_plane()
	await _frames(2)
	quit(t.verdict())


func _planted(first: Vector4) -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(ImpactFrame.MAX_RECTS)
	out[0] = first
	return out


func _inactive() -> void:
	var frame := ImpactFrame.new()
	var polled := [0]
	var redraws := [0]
	frame.rect_source = func() -> Array[Rect2]:
		polled[0] += 1
		return [] as Array[Rect2]
	frame.draw.connect(func() -> void: redraws[0] += 1)
	root.add_child(frame)
	await _frames(2)
	var base_draws: int = redraws[0]
	var base_polled: int = polled[0]
	# The planted value lives in its own array, so a write by the frame cannot alias it.
	var marker := Vector4(7.0, 7.0, 7.0, 7.0)
	frame.material.set_shader_parameter("rects", _planted(marker))
	await _frames(120)
	t.check("inactive: the frame is not alive", not frame.active() and not frame.visible)
	t.eq("inactive: the rect source is never called in 120 frames", polled[0] - base_polled, 0)
	t.eq("inactive: nothing is timed in 120 frames", frame.rect_calls, 0)
	t.eq("inactive: nothing redraws in 120 frames", redraws[0] - base_draws, 0)
	t.eq("inactive: no rect time accrues", frame.rect_usec, 0)
	t.eq("inactive: no shapes are built", frame.shape_calls, 0)
	t.eq("inactive: no uniform is written (a planted value survives)", (frame.material.get_shader_parameter("rects") as PackedVector4Array)[0], marker)

	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(ImpactFrame.FRAMES + 3)
	t.check("fired: the frame spent its frames", not frame.active() and not frame.visible)
	t.eq("fired: the rect source is called once per live frame", polled[0] - base_polled, ImpactFrame.FRAMES)
	t.eq("fired: one refresh per live frame is counted", frame.rect_calls, ImpactFrame.FRAMES)
	t.eq("fired: the pieces are built once", frame.shape_calls, 1)
	t.eq("fired: and drawn once, not once per live frame", redraws[0] - base_draws, 1)
	t.check("fired: the frame drew", frame.drawn > 0, str(frame.drawn))
	t.check("fired: the worst call is within the sum", frame.rect_usec >= frame.rect_usec_max and frame.rect_usec_max >= 0)
	t.check("fired: the shapes were timed", frame.shape_usec >= frame.shape_usec_max and frame.shape_usec_max >= 0)
	t.check("fired: the upload replaced the planted uniform", (frame.material.get_shader_parameter("rects") as PackedVector4Array)[0] != marker)

	var spent_polled: int = polled[0]
	var spent_calls: int = frame.rect_calls
	var spent_shapes: int = frame.shape_calls
	var spent_draws: int = redraws[0]
	var spent_usec: int = frame.rect_usec
	var spent_marker := Vector4(9.0, 9.0, 9.0, 9.0)
	frame.material.set_shader_parameter("rects", _planted(spent_marker))
	await _frames(120)
	t.eq("spent: the rect source is not called again", polled[0] - spent_polled, 0)
	t.eq("spent: no new rect call", frame.rect_calls - spent_calls, 0)
	t.eq("spent: nothing redraws", redraws[0] - spent_draws, 0)
	t.eq("spent: no new shapes", frame.shape_calls - spent_shapes, 0)
	t.eq("spent: no new rect time", frame.rect_usec - spent_usec, 0)
	t.eq("spent: no uniform is written", (frame.material.get_shader_parameter("rects") as PackedVector4Array)[0], spent_marker)
	frame.queue_free()


# The pieces are drawn once per fire, but the rects go up on every live frame: a source that
# answers with a rect that moves is followed on frames 2 and 3, with no redraw.
func _moving() -> void:
	var frame := ImpactFrame.new()
	var calls := [0]
	frame.rect_source = func() -> Array[Rect2]:
		calls[0] += 1
		return [Rect2(100.0 * calls[0], 50.0, 30.0, 40.0)] as Array[Rect2]
	root.add_child(frame)
	await _frames(2)
	var seen := []
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	seen.append((frame.material.get_shader_parameter("rects") as PackedVector4Array)[0].x)
	for k in 2:
		await _frames(1)
		seen.append((frame.material.get_shader_parameter("rects") as PackedVector4Array)[0].x)
	t.eq("moving: each live frame sends the moved rect", seen, [100.0, 200.0, 300.0])
	t.eq("moving: and the pieces were still built once", frame.shape_calls, 1)
	frame.queue_free()


# More warnings than the shader holds: the frame cannot promise to stay off all of them, so
# it draws nothing for that refresh, counts it, and draws again once the rects fit.
func _overflow() -> void:
	var frame := ImpactFrame.new()
	var count := [ImpactFrame.MAX_RECTS + 1]
	frame.rect_source = func() -> Array[Rect2]:
		var out: Array[Rect2] = []
		for k in count[0]:
			out.append(Rect2(10.0 * k, 20.0, 8.0, 8.0))
		return out
	root.add_child(frame)
	await _frames(2)
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(1)
	t.eq("overflow: %d rects draw nothing" % count[0], frame.drawn, 0)
	t.check("overflow: the hide is counted", frame.overflow_hides >= 1, str(frame.overflow_hides))
	t.eq("overflow: the shader is sent no rects", frame.material.get_shader_parameter("rect_count"), 0)
	await _frames(ImpactFrame.FRAMES + 2)
	count[0] = ImpactFrame.MAX_RECTS
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(1)
	t.check("overflow: exactly %d rects still draw" % count[0], frame.drawn > 0, str(frame.drawn))
	t.eq("overflow: and are all sent", frame.material.get_shader_parameter("rect_count"), ImpactFrame.MAX_RECTS)
	# Overflow part way through a live frame hides it, and fitting again shows it.
	count[0] = 3
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(1)
	t.check("overflow: a fitting refresh shows the frame", frame.visible and frame.active())
	count[0] = ImpactFrame.MAX_RECTS + 1
	frame._refresh_rects()
	t.check("overflow: an overflowing refresh hides the live frame", not frame.visible)
	count[0] = 3
	frame._refresh_rects()
	t.check("overflow: a fitting refresh shows it again", frame.visible)
	frame.queue_free()


# Hostile rects hug the screen edge so each one reaches the edge band: `count` rects of
# 140 x 100 px, four to a side per 16, spread along the side and set 20 px in from the edge,
# overlapping as hostile marks do.
func _hostile(count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for i in count:
		var side := i % 4
		var u := float(i / 4) / maxf(1.0, float(count) / 4.0)
		match side:
			0:
				rects.append(Rect2(20.0, 40.0 + u * (SCREEN.y - 180.0), 140.0, 100.0))
			1:
				rects.append(Rect2(SCREEN.x - 160.0, 40.0 + u * (SCREEN.y - 180.0), 140.0, 100.0))
			2:
				rects.append(Rect2(40.0 + u * (SCREEN.x - 220.0), 20.0, 140.0, 100.0))
			_:
				rects.append(Rect2(40.0 + u * (SCREEN.x - 220.0), SCREEN.y - 120.0, 140.0, 100.0))
	return rects


# The hostile rects reach the shader whole: written by the same function the live refresh
# uses, and the frame is every wedge and the wash whatever the rect count.
func _placement() -> void:
	var frame := ImpactFrame.new()
	frame._focus = Vector2(960.0, 540.0)
	frame._strength = 1.0
	frame._heat = 0.9
	frame._seed = 5
	for count in [0, 4, 16, 64]:
		var rects := _hostile(count)
		frame.apply_rects(rects)
		t.eq("placement %d: the rects are written" % count, frame.material.get_shader_parameter("rect_count"), count)
		var shapes: Array = frame._shapes(SCREEN)
		t.check("placement %d: the frame is every wedge and the wash" % count, shapes.size() > 8, str(shapes.size()))
	frame.free()


class FlatGround:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


# warning_rects as it was before the per-warning merge (one projection of 8 corners per
# mesh), kept here as the before number and as the reference the new rects must contain.
static func _old_rects(tree: SceneTree, cam: Camera3D, margin: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in tree.get_nodes_in_group(Threat.GROUP):
		if not (node is Node3D) or not node.is_visible_in_tree():
			continue
		var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
		_old_project(node, cam, span)
		if span[0].x <= span[1].x:
			out.append(Rect2(span[0], span[1] - span[0]).grow(margin))
	return out


static func _old_project(node: Node, cam: Camera3D, span: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not child.visible:
			continue
		if child is VisualInstance3D:
			var box: AABB = child.get_aabb()
			if box.size != Vector3.ZERO:
				for c in 8:
					var corner: Vector3 = child.global_transform * (box.position + box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
					if cam.is_position_behind(corner):
						continue
					var at := cam.unproject_position(corner)
					span[0] = span[0].min(at)
					span[1] = span[1].max(at)
		_old_project(child, cam, span)


# warning_rects on a scene of real hostile marks: committed Telegraph rings and boss Hazard
# annuli on a ground grid in front of a camera. The new rects must contain the old ones
# (conservative), one rect per mark.
func _rects() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.position = Vector3(0.0, 30.0, 30.0)
	cam.look_at(Vector3.ZERO)
	var ground := FlatGround.new()
	var margin := 0.0
	for count in [4, 16]:
		var marks: Array = []
		for k in count:
			var at := Vector3((k % 4 - 1.5) * 9.0, 0.0, (k / 4 - 1.5) * 7.0)
			if k % 2 == 0:
				marks.append(Telegraph.ring(world, ground, Threat.Type.INSTANT, at, 2.0))
			else:
				var hazard := Hazard.new()
				hazard.commit_annulus("bench_%d" % k, Threat.Type.INSTANT, at, Vector2(0.0, 2.0), 3.5, 2.0, 1.0)
				world.add_child(hazard)
				marks.append(hazard)
		await _frames(2)
		var tree := root.get_tree()
		var old := _old_rects(tree, cam, margin)
		var now := PlayerFx.warning_rects(tree, cam, margin)
		var contained := now.size() >= old.size() and old.size() > 0
		for r in old:
			contained = contained and now.any(func(n: Rect2) -> bool: return n.grow(0.01).encloses(r))
		t.check("rects %d: a rect for every mark" % count, tree.get_nodes_in_group(Threat.GROUP).size() == count and now.size() == count, "%d marks, %d old, %d new" % [tree.get_nodes_in_group(Threat.GROUP).size(), old.size(), now.size()])
		t.check("rects %d: every old rect lies inside a new one" % count, contained)
		# The box path is the one taken for both classes (lighting L7, #297): every mark answers
		# with a box, and its rect is the box's projection, not the mesh walk's.
		var boxed := true
		var projected := true
		for k in marks.size():
			var box: AABB = marks[k].screen_bound_box()
			boxed = boxed and box.size != Vector3.ZERO
			var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
			PlayerFx._project_box(box, cam, span)
			projected = projected and now.size() == marks.size() and now[k].is_equal_approx(Rect2(span[0], span[1] - span[0]).grow(margin))
		t.check("rects %d: every telegraph and hazard answers with a box" % count, boxed)
		t.check("rects %d: warning_rects projects that box" % count, projected)
		var walked := PlayerFx.warning_rects(tree, cam, margin, false)
		var differs := false
		for k in mini(walked.size(), now.size()):
			differs = differs or not walked[k].is_equal_approx(now[k])
		t.check("rects %d: the forced mesh walk is a different, tighter path" % count, walked.size() == now.size() and differs)
		for mark in marks:
			mark.free()
		await _frames(1)
	world.free()


# A warning that crosses the camera's near plane reaches the screen edge nearest the camera,
# the bottom, where the frame's band draws; projecting only the corners in front of the
# lens left that part out. The camera sits where the chase camera puts it: the arm is 8 m
# (chase_camera.gd:80, spring_length) at the default pitch (chase_camera.gd:36, -0.30 rad),
# fov 65 (chase_camera.gd:92), over a ball resting on flat ground at the origin.
func _near_plane() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var rig := ChaseCamera.new()
	var pitch: float = rig.pitch
	rig.free()
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.fov = 65.0
	cam.far = 700.0
	cam.current = true
	cam.basis = Basis(Vector3.RIGHT, pitch)
	cam.position = Basis(Vector3.RIGHT, pitch) * Vector3(0.0, 0.0, 8.0)
	await _frames(2)
	var vp: Vector2 = cam.get_viewport().get_visible_rect().size
	var forward := -cam.global_transform.basis.z
	var tree := root.get_tree()
	var ground := FlatGround.new()
	# A big ring on the camera's foot (the ball): the camera sits above its edge, so its box
	# crosses the near plane.
	var big := Telegraph.ring(world, ground, Threat.Type.INSTANT, Vector3.ZERO, 20.0)
	await _frames(2)
	var rects := PlayerFx.warning_rects(tree, cam, 0.0)
	# A point of the ring's own box, at its mid height, on the plane just past the near plane
	# and on the view's centre line: it is on the ring's footprint and on screen only by way
	# of the near-plane clip.
	var merged_big := [AABB(), false]
	PlayerFx._merge_meshes(big, merged_big)
	var mid_y: float = (merged_big[0] as AABB).get_center().y
	var depth := cam.near + PlayerFx.NEAR_EPSILON
	var foot_z := cam.position.z + (depth - (mid_y - cam.position.y) * forward.y) / forward.z
	var just_in_front := Vector3(0.0, mid_y, foot_z)
	t.check("near plane: the probe point is inside the ring's box", (merged_big[0] as AABB).has_point(just_in_front), str(just_in_front))
	var behind := (just_in_front - cam.position).dot(forward)
	t.check("near plane: the probe point sits just past the near plane", absf(behind - depth) < 0.001, "%.4f m" % behind)
	t.check("near plane: the camera is above the ring and part of its box is behind it", cam.is_position_behind(Vector3(0.0, 0.0, 20.0)) and not cam.is_position_behind(Vector3(0.0, 0.0, -20.0)))
	var probe := cam.unproject_position(just_in_front)
	t.check("near plane: one rect for the ring", rects.size() == 1, str(rects.size()))
	if rects.size() == 1:
		t.check("near plane: the rect reaches the bottom of the viewport", rects[0].end.y >= vp.y - 1.0, "%s in %s" % [rects[0], vp])
		t.check("near plane: and covers the point just past the near plane", rects[0].has_point(probe), "%s in %s" % [probe, rects[0]])
	# The control: the old projection, which skipped corners behind, misses both.
	var skipped := _old_rects(tree, cam, 0.0)
	t.check("near plane control: the skip-only projection stops short of the bottom", skipped.size() == 1 and skipped[0].end.y < vp.y - 1.0 and not skipped[0].has_point(probe), str(skipped))
	big.free()
	await _frames(1)

	# A merge case: one warning of two small flat marks, each fully in front of the lens, whose
	# merged box (the high one over the low one) has a corner behind it. The rect must still
	# cover each mark's own projection.
	var warning := Node3D.new()
	warning.add_to_group(Threat.GROUP)
	world.add_child(warning)
	var own: Array[Rect2] = []
	for at in [Vector3(0.0, 0.0, 7.0), Vector3(0.0, 8.0, 4.0)]:
		var plane := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(2.0, 2.0)
		plane.mesh = mesh
		plane.position = at
		warning.add_child(plane)
		var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
		var behind_any := false
		for c in 8:
			var corner: Vector3 = plane.global_transform * (plane.get_aabb().position + plane.get_aabb().size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
			behind_any = behind_any or (corner - cam.position).dot(forward) <= cam.near
			span[0] = span[0].min(cam.unproject_position(corner))
			span[1] = span[1].max(cam.unproject_position(corner))
		t.check("merge: the mark at %s is fully in front" % at, not behind_any)
		own.append(Rect2(span[0], span[1] - span[0]))
	await _frames(1)
	var merged := [AABB(), false]
	PlayerFx._merge_meshes(warning, merged)
	var merged_behind := false
	var box: AABB = merged[0]
	for c in 8:
		merged_behind = merged_behind or ((box.position + box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1)) - cam.position).dot(forward) <= cam.near
	t.check("merge: the merged box has a corner behind the lens", merged_behind)
	var merged_rects := PlayerFx.warning_rects(tree, cam, 0.0)
	t.check("merge: one rect for the warning", merged_rects.size() == 1, str(merged_rects.size()))
	if merged_rects.size() == 1:
		t.check("merge: the rect covers both marks' own projections", merged_rects[0].grow(0.01).encloses(own[0]) and merged_rects[0].grow(0.01).encloses(own[1]), "%s vs %s" % [merged_rects[0], own])
	warning.free()
	world.free()
