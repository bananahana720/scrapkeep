# smoke: solo
extends SceneTree

# What the impact frame costs (lighting L7, #241). Inactive cost is provably zero: while no
# frame is alive the rect source is never called, no uniform is written and nothing redraws.
# A live frame's rect work (the refresh, the uniform upload and the shapes of one draw) is
# counted, more rects than the shader holds draw nothing, and the upload plus `_shapes` is
# micro-benched at 0, 4, 16 and 64 hostile rects. The bench prints its numbers but gates only
# on facts that cannot flake on a slow runner; the 0.2 ms per fired frame bar at 16 rects is
# judged from the printed line on a quiet box, never from cloud timing.
const T := preload("res://tests/support/t.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const CALLS := 1000
const WARM_UP := 50
const SCREEN := Vector2(1920.0, 1080.0)
# Far past any real runner; a hang or an accidental O(n^3) trips it, a slow box does not.
const SANITY_MEAN_USEC := 100000.0

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
	_bench()
	await _rects_bench()
	await _frames(2)
	quit(t.verdict())


func _planted(first: Vector4) -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(PlayerFx.ImpactFrame.MAX_RECTS)
	out[0] = first
	return out


func _inactive() -> void:
	var frame := PlayerFx.ImpactFrame.new()
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
	await _frames(PlayerFx.FRAME_FRAMES + 3)
	t.check("fired: the frame spent its frames", not frame.active() and not frame.visible)
	t.eq("fired: the rect source is called once per live frame", polled[0] - base_polled, PlayerFx.FRAME_FRAMES)
	t.eq("fired: one refresh per live frame is counted", frame.rect_calls, PlayerFx.FRAME_FRAMES)
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
	var frame := PlayerFx.ImpactFrame.new()
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
	var frame := PlayerFx.ImpactFrame.new()
	var count := [PlayerFx.ImpactFrame.MAX_RECTS + 1]
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
	await _frames(PlayerFx.FRAME_FRAMES + 2)
	count[0] = PlayerFx.ImpactFrame.MAX_RECTS
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(1)
	t.check("overflow: exactly %d rects still draw" % count[0], frame.drawn > 0, str(frame.drawn))
	t.eq("overflow: and are all sent", frame.material.get_shader_parameter("rect_count"), PlayerFx.ImpactFrame.MAX_RECTS)
	# Overflow part way through a live frame hides it, and fitting again shows it.
	count[0] = 3
	frame.fire(Vector2(900.0, 500.0), 1.0, 7, 0.9)
	await _frames(1)
	t.check("overflow: a fitting refresh shows the frame", frame.visible and frame.active())
	count[0] = PlayerFx.ImpactFrame.MAX_RECTS + 1
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


# A fire builds the shapes once and refreshes the rects on each of FRAME_FRAMES live frames,
# so the refresh (apply_rects, the function the live refresh uses, so the upload is timed)
# and `_shapes` are timed apart, and the per-fire figure is one shapes call plus
# FRAME_FRAMES refreshes. The rect source is not in this bench (see _rects_bench).
func _bench() -> void:
	var frame := PlayerFx.ImpactFrame.new()
	frame._focus = Vector2(960.0, 540.0)
	frame._strength = 1.0
	frame._heat = 0.9
	frame._seed = 5
	for count in [0, 4, 16, 64]:
		var rects := _hostile(count)
		frame.apply_rects(rects)
		t.eq("bench %d: the rects are written" % count, frame.material.get_shader_parameter("rect_count"), count)
		var shapes: Array = frame._shapes(SCREEN)
		t.check("bench %d: the frame is every wedge and the wash" % count, shapes.size() > 8, str(shapes.size()))
		for i in WARM_UP:
			frame.apply_rects(rects)
			frame._shapes(SCREEN)
		var refresh: Array = []
		var build: Array = []
		var both: Array = []
		for i in CALLS:
			var began := Time.get_ticks_usec()
			frame.apply_rects(rects)
			var mid := Time.get_ticks_usec()
			frame._shapes(SCREEN)
			var done := Time.get_ticks_usec()
			refresh.append(mid - began)
			build.append(done - mid)
			both.append(done - began)
		var line := "impact_frame_bench rects=%d calls=%d" % [count, CALLS]
		var means := {}
		for row in [["refresh", refresh], ["shapes", build], ["call", both]]:
			var usec: Array = row[1]
			usec.sort()
			var sum := 0
			for u in usec:
				sum += u
			var mean := float(sum) / float(CALLS)
			var p99: float = usec[int(ceil(0.99 * CALLS)) - 1]
			means[row[0]] = mean
			line += " %s_mean_us=%.1f %s_p99_us=%.1f %s_max_us=%d" % [row[0], mean, row[0], p99, row[0], usec.back()]
			t.eq("bench %d %s: %d samples taken" % [count, row[0], CALLS], usec.size(), CALLS)
			t.check("bench %d %s: p99 >= mean >= 0" % [count, row[0]], p99 >= mean and mean >= 0.0, "mean %.1f p99 %.1f" % [mean, p99])
			t.check("bench %d %s: mean is nowhere near a hang" % [count, row[0]], mean < SANITY_MEAN_USEC, "%.1f us" % mean)
		print(line + " per_fire_mean_us=%.1f" % (means["shapes"] + PlayerFx.FRAME_FRAMES * means["refresh"]))
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
# (conservative); both are timed over CALLS calls and printed, old first.
func _rects_bench() -> void:
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
		var grow := 0.0
		for k in mini(old.size(), now.size()):
			grow = maxf(grow, now[k].get_area() / maxf(old[k].get_area(), 1.0))
		print("warning_rects_bench marks=%d largest new/old area ratio=%.3f" % [count, grow])
		for pass_name in ["old", "new"]:
			for i in WARM_UP:
				_old_rects(tree, cam, margin) if pass_name == "old" else PlayerFx.warning_rects(tree, cam, margin)
			var usec: Array = []
			for i in CALLS:
				var began := Time.get_ticks_usec()
				if pass_name == "old":
					_old_rects(tree, cam, margin)
				else:
					PlayerFx.warning_rects(tree, cam, margin)
				usec.append(Time.get_ticks_usec() - began)
			usec.sort()
			var sum := 0
			for u in usec:
				sum += u
			var mean := float(sum) / float(CALLS)
			var p99: float = usec[int(ceil(0.99 * CALLS)) - 1]
			print("warning_rects_bench %s marks=%d calls=%d mean_us=%.1f p99_us=%.1f max_us=%d" % [pass_name, count, CALLS, mean, p99, usec.back()])
			t.check("rects %d %s: p99 >= mean >= 0 and no hang" % [count, pass_name], p99 >= mean and mean >= 0.0 and mean < SANITY_MEAN_USEC, "%.1f us" % mean)
		for mark in marks:
			mark.free()
		await _frames(1)
	world.free()
