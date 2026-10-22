extends SceneTree

# Timing for the impact frame (lighting L7, #241); the checks live in tests/impact_frame_cost_test.gd,
# which may not read the clock. Headless, one run, numbers for a quiet box only (cloud timing
# does not count):
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/impact_frame_bench.gd
# It times the frame's refresh (apply_rects, the upload the live refresh uses) and `_shapes`
# apart at 0, 4, 16 and 64 hostile rects, with the per-fire figure (one shapes call plus
# FRAME_FRAMES refreshes, the rect source not in it), then warning_rects on 4 and 16 real
# hostile marks three ways: the old per-mesh projection, the per-warning mesh walk
# (use_bounds false, the fallback) and the cached box (the default, lighting L7 #297). At each
# count it also prints a per-fire figure that INCLUDES the rect walk: real ImpactFrame fires
# (rect_source = warning_rects, walk and box) over FIRES fires, each fire's shape and rect
# microseconds from the frame's own counters, and the refreshes counted per fire (rect_calls).
# A last section times the work screen_bound_box does at COMMIT (the descriptor, the ground
# lattice and the box; the whole commit beside it) on a typical ring, a lane and the largest
# hazards the repo commits, over the real park ground (Terrain.height of the park table's
# stage 1) built here. Exit 0, or 1 when a sanity check fails (sample count,
# p99 >= mean >= 0, mean under SANITY_MEAN_USEC); the 0.2 ms bar is judged from the lines.
const PlayerFx := preload("res://src/presentation/player_fx.gd")
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
	await _commit_bench()
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


func _rects_pass(pass_name: String, tree: SceneTree, cam: Camera3D, margin: float) -> void:
	if pass_name == "old":
		_old_rects(tree, cam, margin)
	else:
		PlayerFx.warning_rects(tree, cam, margin, pass_name == "box")


# Real fires of a live ImpactFrame over the scene's marks: per fire, the shapes it built
# plus the rect refreshes it made (the frame times both itself), so the walk is inside the
# figure. FRAME_FRAMES refreshes a fire: fire() sends once and each of the next
# FRAME_FRAMES - 1 live frames sends again; the count printed is measured, not assumed.
func _fire_bench(count: int, tree: SceneTree, cam: Camera3D, use_bounds: bool) -> void:
	var frame := PlayerFx.ImpactFrame.new()
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
		await _frames(PlayerFx.FRAME_FRAMES + 1)
		if i >= WARM_UP:
			usec.append((frame.shape_usec - shapes_before) + (frame.rect_usec - rects_before))
			refreshes = frame.rect_calls - calls_before
	var label := "box" if use_bounds else "walk"
	_check("fire %d %s: samples taken" % [count, label], usec.size() == FIRES, str(usec.size()))
	_check("fire %d %s: every fire refreshes FRAME_FRAMES times" % [count, label], refreshes == PlayerFx.FRAME_FRAMES, str(refreshes))
	usec.sort()
	var sum := 0
	for u in usec:
		sum += u
	var mean := float(sum) / float(maxi(usec.size(), 1))
	var p99: float = usec[int(ceil(0.99 * usec.size())) - 1] if not usec.is_empty() else 0.0
	print("impact_frame_fire_bench %s marks=%d fires=%d rect_refreshes_per_fire=%d per_fire_mean_us=%.1f per_fire_p99_us=%.1f per_fire_max_us=%d" % [label, count, usec.size(), refreshes, mean, p99, usec.back() if not usec.is_empty() else 0])
	frame.queue_free()
	await _frames(1)


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


# --- Commit cost ---------------------------------------------------------------------------

const COMMIT_CALLS := 1000
# Whole commits are built and freed, so fewer.
const WHOLE_CALLS := 200

# The cost of the box at commit. The ground is the real park terrain (stage 1 of ParkDefs, the
# table the game launches), so each lattice sample is the real Terrain.height. Cases, with the
# repo's own numbers:
#   ring INSTANT r 6   the stress and bench ring (stress_capture.gd _commit_threats)
#   lane 24 x 4        a lane from a Telegraph (the shipped ones run 14 to 24 long)
#   annulus r 44       the largest circle a hazard takes: MindAttacks clamps a band to its
#                      radius (mind_attacks.gd:155, :167), default Arena.FLOOR_R = 44 (arena.gd:14)
#   charge lane 105    the largest lane: Brindle's charge runs rim to rim, up to 2 x CHARGE_STOP_R
#                      (49, boss_rules.gd:101) plus the hull half length 7 behind and ahead of
#                      the run (boss.gd:737, Requisition.HULL 9 x 5 x 14, requisition.gd:14), half
#                      width 9 * 0.5 + 1
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
				WarningBound.box(node.descriptor(), node.painter().ground, node.centre.y, Hazard.DRAW_LIFT)
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
