extends SceneTree

# Timing for the impact frame (lighting L7, #241); the checks live in tests/impact_frame_cost_test.gd,
# which may not read the clock. Headless, one run, numbers for a quiet box only (cloud timing
# does not count):
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/impact_frame_bench.gd
# It times the frame's refresh (apply_rects, the upload the live refresh uses) and `_shapes`
# apart at 0, 4, 16 and 64 hostile rects, with the per-fire figure (one shapes call plus
# FRAME_FRAMES refreshes), then warning_rects on 4 and 16 real hostile marks against the
# per-mesh version it replaced. Exit 0, or 1 when a sanity check fails (sample count,
# p99 >= mean >= 0, mean under SANITY_MEAN_USEC); the 0.2 ms bar is judged from the lines.
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

const CALLS := 1000
const WARM_UP := 50
const SCREEN := Vector2(1920.0, 1080.0)
# Far past any real run; a hang or an accidental O(n^3) trips it, a slow box does not.
const SANITY_MEAN_USEC := 100000.0

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	_bench()
	await _rects_bench()
	await _frames(2)
	print("impact_frame_bench: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
		print("[%s] %s -> FAIL" % [label, detail])


# Sorted samples to [mean, p99, max], failing the sanity checks.
func _summary(label: String, usec: Array) -> Array:
	usec.sort()
	var sum := 0
	for u in usec:
		sum += u
	var mean := float(sum) / float(usec.size())
	var p99: float = usec[int(ceil(0.99 * usec.size())) - 1]
	_check(label + ": samples taken", usec.size() == CALLS, str(usec.size()))
	_check(label + ": p99 >= mean >= 0", p99 >= mean and mean >= 0.0, "mean %.1f p99 %.1f" % [mean, p99])
	_check(label + ": mean is nowhere near a hang", mean < SANITY_MEAN_USEC, "%.1f us" % mean)
	return [mean, p99, usec.back()]


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
# so the refresh and `_shapes` are timed apart, and the per-fire figure is one shapes call
# plus FRAME_FRAMES refreshes. The rect source is not in this bench (see _rects_bench).
func _bench() -> void:
	var frame := PlayerFx.ImpactFrame.new()
	frame._focus = Vector2(960.0, 540.0)
	frame._strength = 1.0
	frame._heat = 0.9
	frame._seed = 5
	for count in [0, 4, 16, 64]:
		var rects := _hostile(count)
		frame.apply_rects(rects)
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
			var sum := _summary("bench %d %s" % [count, row[0]], row[1])
			means[row[0]] = sum[0]
			line += " %s_mean_us=%.1f %s_p99_us=%.1f %s_max_us=%d" % [row[0], sum[0], row[0], sum[1], row[0], sum[2]]
		print(line + " per_fire_mean_us=%.1f" % (means["shapes"] + PlayerFx.FRAME_FRAMES * means["refresh"]))
	frame.free()


class FlatGround:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


# warning_rects as it was before the per-warning merge (one projection of 8 corners per
# mesh), kept here as the before number (the test keeps its own copy as the containment
# reference).
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
# annuli on a ground grid in front of a camera, both versions timed over CALLS calls and
# printed, old first.
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
		_check("rects %d: a rect for every mark" % count, now.size() == count and old.size() == count, "%d old, %d new" % [old.size(), now.size()])
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
			var sum := _summary("rects %d %s" % [count, pass_name], usec)
			print("warning_rects_bench %s marks=%d calls=%d mean_us=%.1f p99_us=%.1f max_us=%d" % [pass_name, count, CALLS, sum[0], sum[1], sum[2]])
		for mark in marks:
			mark.free()
		await _frames(1)
	world.free()
