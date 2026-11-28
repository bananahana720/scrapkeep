extends SceneTree

const PlayerFx := preload("res://src/presentation/player_fx.gd")
const ImpactFrame := preload("res://src/presentation/impact_frame.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningBound := preload("res://src/combat/warning_bound.gd")
const Terrain := preload("res://src/world/terrain.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

const CALLS := 1000
const WARM_UP := 50
const FIRES := 200
const SCREEN := Vector2(1920.0, 1080.0)
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
	await _commit_bench()
	await _read_bench()
	await _frames(2)
	print("impact_frame_bench: ", "PASS" if _failures == 0 else "FAIL (%d)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
		print("[%s] %s -> FAIL" % [label, detail])


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


func _bench() -> void:
	var frame := ImpactFrame.new()
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
		print(line + " per_fire_mean_us=%.1f" % (means["shapes"] + ImpactFrame.FRAMES * means["refresh"]))
	frame.free()


class FlatGround:
	extends RefCounted

	func height(_x: float, _z: float) -> float:
		return 0.0


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


func _rects_pass(pass_name: String, tree: SceneTree, cam: Camera3D, margin: float) -> void:
	if pass_name == "old":
		_old_rects(tree, cam, margin)
	else:
		PlayerFx.warning_rects(tree, cam, margin, pass_name == "box")


func _fire_bench(count: int, tree: SceneTree, cam: Camera3D, use_bounds: bool) -> void:
	var frame := ImpactFrame.new()
	frame.rect_source = func() -> Array[Rect2]: return PlayerFx.warning_rects(tree, cam, 0.0, use_bounds)
	root.add_child(frame)
	await _frames(2)
	var usec: Array = []
	var refreshes := 0
	for i in FIRES + WARM_UP:
		var shapes_before := frame.shape_usec
		var rects_before := frame.rect_usec
		var calls_before := frame.rect_calls
		frame.fire(Vector2(960.0, 540.0), 1.0, 7 + i, 0.9)
		await _frames(ImpactFrame.FRAMES + 1)
		if i >= WARM_UP:
			usec.append((frame.shape_usec - shapes_before) + (frame.rect_usec - rects_before))
			refreshes = frame.rect_calls - calls_before
	var label := "box" if use_bounds else "walk"
	_check("fire %d %s: samples taken" % [count, label], usec.size() == FIRES, str(usec.size()))
	_check("fire %d %s: every fire refreshes FRAME_FRAMES times" % [count, label], refreshes == ImpactFrame.FRAMES, str(refreshes))
	usec.sort()
	var sum := 0
	for u in usec:
		sum += u
	var mean := float(sum) / float(maxi(usec.size(), 1))
	var p99: float = usec[int(ceil(0.99 * usec.size())) - 1] if not usec.is_empty() else 0.0
	print("impact_frame_fire_bench %s marks=%d fires=%d rect_refreshes_per_fire=%d per_fire_mean_us=%.1f per_fire_p99_us=%.1f per_fire_max_us=%d" % [label, count, usec.size(), refreshes, mean, p99, usec.back() if not usec.is_empty() else 0])
	frame.queue_free()
	await _frames(1)


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
		for pass_name in ["old", "walk", "box"]:
			for i in WARM_UP:
				_rects_pass(pass_name, tree, cam, margin)
			var usec: Array = []
			for i in CALLS:
				var began := Time.get_ticks_usec()
				_rects_pass(pass_name, tree, cam, margin)
				usec.append(Time.get_ticks_usec() - began)
			var sum := _summary("rects %d %s" % [count, pass_name], usec)
			print("warning_rects_bench %s marks=%d calls=%d mean_us=%.1f p99_us=%.1f max_us=%d" % [pass_name, count, CALLS, sum[0], sum[1], sum[2]])
		for use_bounds in [false, true]:
			await _fire_bench(count, tree, cam, use_bounds)
		for mark in marks:
			mark.free()
		await _frames(1)
	world.free()


const COMMIT_CALLS := 1000
const WHOLE_CALLS := 200

func _commit_bench() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain := Terrain.new(ParkDefs)
	terrain.build(holder)
	terrain.use(1)
	await _frames(2)
	var spawn: Vector2 = terrain.map_for(1).spawn
	var at := Vector3(spawn.x, terrain.height(spawn.x, spawn.y), spawn.y)
	var world := Node3D.new()
	root.add_child(world)
	var half_hull := 7.0
	var cases := {
		"ring INSTANT r6": func() -> Node3D: return Telegraph.ring(world, terrain, Threat.Type.INSTANT, at, 6.0),
		"lane 24x4": func() -> Node3D: return Telegraph.lane(world, terrain, Threat.Type.LANE, at, Vector3.RIGHT, 24.0, 4.0),
		"hazard annulus r44": func() -> Node3D:
			var h := Hazard.new()
			h.ground = func(point: Vector3) -> float: return terrain.height(point.x, point.z)
			h.commit_annulus("bench_big", Threat.Type.INSTANT, at, Vector2(0.0, 44.0), 3.0, 1.0, 1.0)
			world.add_child(h)
			return h,
		"hazard charge lane 105": func() -> Node3D:
			var h := Hazard.new()
			h.ground = func(point: Vector3) -> float: return terrain.height(point.x, point.z)
			h.commit_lane("bench_charge", Threat.Type.LANE, at, Vector3.RIGHT, half_hull, 98.0 + half_hull, 5.5, 5.5, 1.0, 1.0)
			world.add_child(h)
			return h,
	}
	for label in cases:
		var node: Node3D = cases[label].call()
		await _frames(1)
		var box: AABB = node.screen_bound_box()
		_check("commit %s: has a box" % label, box.size != Vector3.ZERO)
		var usec: Array = []
		for i in WARM_UP + COMMIT_CALLS:
			var began := Time.get_ticks_usec()
			if node is Hazard:
				WarningBound.box(node.descriptor(), WarningBound.mesh_box(node.painter()))
			else:
				node._cut_bound()
			if i >= WARM_UP:
				usec.append(Time.get_ticks_usec() - began)
		var sum := _summary_n("commit box %s" % label, usec, COMMIT_CALLS)
		var whole: Array = []
		for i in WHOLE_CALLS:
			var began := Time.get_ticks_usec()
			var again: Node3D = cases[label].call()
			whole.append(Time.get_ticks_usec() - began)
			again.free()
		var all := _summary_n("commit whole %s" % label, whole, WHOLE_CALLS)
		print("commit_bench %s box_samples=%d box_mean_us=%.1f box_p99_us=%.1f box_max_us=%d whole_samples=%d whole_mean_us=%.1f whole_p99_us=%.1f box_size=(%.1f, %.1f, %.1f)" % [label, COMMIT_CALLS, sum[0], sum[1], sum[2], WHOLE_CALLS, all[0], all[1], box.size.x, box.size.y, box.size.z])
		node.free()
		await _frames(1)
	world.free()
	holder.free()


func _summary_n(label: String, usec: Array, want: int) -> Array:
	usec.sort()
	var sum := 0
	for u in usec:
		sum += u
	var mean := float(sum) / float(usec.size())
	var p99: float = usec[int(ceil(0.99 * usec.size())) - 1]
	_check(label + ": samples taken", usec.size() == want, str(usec.size()))
	_check(label + ": p99 >= mean >= 0", p99 >= mean and mean >= 0.0, "mean %.1f p99 %.1f" % [mean, p99])
	return [mean, p99, usec.back()]


func _read_bench() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ground := FlatGround.new()
	var ring: Node3D = Telegraph.ring(world, ground, Threat.Type.INSTANT, Vector3.ZERO, 6.0)
	for live in [1, 4]:
		var hazards: Array = []
		for k in live:
			var h := Hazard.new()
			h.ground = func(point: Vector3) -> float: return 0.0
			h.commit_annulus("read_%d" % k, Threat.Type.INSTANT, Vector3(10.0 * k, 0.0, 10.0), Vector2(0.0, 6.0), 3.5, 100.0, 1.0)
			world.add_child(h)
			hazards.append(h)
		var merges_before := 0
		for h in hazards:
			merges_before += h.bound_merges
		var usec: Array = []
		for i in WARM_UP + COMMIT_CALLS:
			for h in hazards:
				h.step(0.016)
			var began := Time.get_ticks_usec()
			for h in hazards:
				h.screen_bound_box()
			if i >= WARM_UP:
				usec.append(Time.get_ticks_usec() - began)
		var merged := 0
		for h in hazards:
			merged += h.bound_merges
		_check("read %d hazards: every read merged" % live, merged - merges_before == live * (WARM_UP + COMMIT_CALLS), str(merged - merges_before))
		var sum := _summary_n("read %d hazards" % live, usec, COMMIT_CALLS)
		print("read_bench hazards_stepped_between_reads=%d reads=%d per_pass_mean_us=%.1f per_pass_p99_us=%.1f per_read_mean_us=%.1f" % [live, COMMIT_CALLS, sum[0], sum[1], sum[0] / live])
		for h in hazards:
			h.free()
	var cached: Array = []
	for i in WARM_UP + COMMIT_CALLS:
		var began := Time.get_ticks_usec()
		ring.screen_bound_box()
		if i >= WARM_UP:
			cached.append(Time.get_ticks_usec() - began)
	var tsum := _summary_n("read telegraph", cached, COMMIT_CALLS)
	print("read_bench telegraph reads=%d per_read_mean_us=%.1f per_read_p99_us=%.1f" % [COMMIT_CALLS, tsum[0], tsum[1]])
	world.free()
