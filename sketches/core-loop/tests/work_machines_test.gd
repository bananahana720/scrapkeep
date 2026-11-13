extends SceneTree

const WorkMachines := preload("res://src/presentation/work_machines.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Terrain := preload("res://src/world/terrain.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")

# Looping workers (work_machines.gd, BACKLOG W1-93). The placement: every footing stands at least
# LINE_CLEAR_M off every pilot line and the boom's tip never swings within TIP_CLEAR_M of one, so no
# fight lands under a machine and no line gains a wall; nothing stands inside a built park row. The
# cycle: periodic, inside its sweep and drop, and smooth at 60 Hz. The view: the real GLB builds
# with its named nodes, its footings are one world-layer body that watches nothing, the slew and the
# hoist move, and the module publishes no event and deals no damage.

const LINE_CLEAR_M := 25.0
const TIP_CLEAR_M := 20.0
const ROW_CLEAR_M := 4.0
# A machine is there to be seen from the ride: of the line within SIGHT_M of it, at least SIGHT_SHARE
# has a clear sight line over the baked ground from chase height to the machine's middle.
const HOME_CLEAR_M := 25.0
# A row this tall (masts, stacks, piers) hides a machine behind it, so none stands within TALL_CLEAR_M.
const TALL_M := 15.0
const TALL_CLEAR_M := 30.0
const RING_CLEAR_M := 40.0
const SIGHT_M := 160.0
const SIGHT_SHARE := 0.5
const EYE_M := 4.0
const MID_M := 12.0
# The baked ground under a machine's footings may differ by this much at most: it is seated on the
# lowest, so the highest footing is buried by the difference and none floats.
const FOOT_SPREAD_M := 2.5
const SOURCE := "res://src/presentation/work_machines.gd"
const BANNED := ["emit_signal", ".emit(", "damage", "add_to_group", "GameEvents", "collision_mask = 1"]

var _t := T.new("work_machines_test")


class FakeStage:
	extends RefCounted
	var map := "park_dam"


class FakeStages:
	extends RefCounted
	var stage := FakeStage.new()
	func of(_stage: int) -> FakeStage:
		return stage


class FakeTerrain:
	extends RefCounted
	var stage := 1
	func is_ready(_stage: int) -> bool:
		return true
	func ground_callable(_stage: int) -> Callable:
		return func(x: float, z: float, lift: float) -> Vector3: return Vector3(x, 3.0 + 0.01 * x + lift, z)


class FakeCtx:
	extends RefCounted
	var events: Node
	var stages := FakeStages.new()
	var terrain := FakeTerrain.new()


func _initialize() -> void:
	_main()


func _main() -> void:
	await process_frame
	if not _t.check("work_machines.gd compiles", (WorkMachines as GDScript).can_instantiate()):
		quit(_t.verdict())
		return
	_placement("park_dam")
	_placement("park_flume")
	_cycle()
	await _view()
	_source()
	quit(_t.verdict())


# The pilot lines as event_director.gd _park_read_lines resolves them.
func _lines(park: Dictionary) -> Array:
	var out := []
	var path := "res://assets/park/%s/lines.json" % park.get("map", "")
	var sites := {}
	for row in park.get("park_rows", []):
		sites[row.id] = row
	var read := ParkSchema.read_file(path)
	for pilot in read.data.get("pilots", {}).values():
		var points := []
		for point in pilot.get("waypoints", []):
			if point is Array:
				points.append(Vector2(float(point[0]), float(point[1])))
			elif point == "drop_in":
				points.append(Vector2(float(park.spawn.at[0]), float(park.spawn.at[1])))
			elif point == "landmark":
				points.append(Vector2(float(park.landmark.beacon[0]), float(park.landmark.beacon[1])))
			elif sites.has(point):
				points.append(Vector2(float(sites[point].at[0]), float(sites[point].at[1])))
			else:
				for activity in park.get("activity_rows", []):
					if activity.id == point:
						points.append(Vector2(float(activity.at[0]), float(activity.at[1])))
		out.append(points)
	return out


func _line_gap(at: Vector2, lines: Array) -> float:
	var best := INF
	for points in lines:
		for i in points.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])
			best = minf(best, at.distance_to(q))
	return best


# Distance from a point to a built row's footprint (its rotated rectangle); stamps of landform size
# and plain ground are the terrain itself and do not count.
func _row_gap(at: Vector2, row: Dictionary) -> float:
	var yaw := deg_to_rad(float(row.yaw_deg))
	var d := at - Vector2(float(row.at[0]), float(row.at[1]))
	var local := Vector2(d.x * cos(yaw) - d.y * sin(yaw), d.x * sin(yaw) + d.y * cos(yaw))
	var half := Vector2(float(row.size[0]), float(row.size[2])) / 2.0
	return Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0)).length()


func _placement(map_id: String) -> void:
	var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
	var park: Dictionary = map.park
	var lines := _lines(park)
	_t.check("%s has pilot lines" % map_id, lines.size() >= 4, str(lines.size()))
	var heights := ParkTerrain._read_zstd(ParkTerrain.bake_dir(map_id) + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var rows := WorkMachines.rows_for(map_id)
	_t.check("%s stands two or three machines (%d)" % [map_id, rows.size()], rows.size() >= 2 and rows.size() <= 3)
	for row in rows:
		var j := _judge(row, park, lines, heights)
		_t.check("%s %s: ground under the footings spans %.2f m" % [map_id, row.id, j.spread], j.spread <= FOOT_SPREAD_M)
		_t.check("%s %s: footings %.1f m off every line" % [map_id, row.id, j.foot_gap], j.foot_gap >= LINE_CLEAR_M)
		if j.has("tip_gap"):
			_t.check("%s %s: the tip swings %.1f m off every line at worst" % [map_id, row.id, j.tip_gap], j.tip_gap >= TIP_CLEAR_M)
		_t.check("%s %s: %.0f m from the nearest enemy home's site" % [map_id, row.id, j.home_gap], j.home_gap >= HOME_CLEAR_M)
		_t.check("%s %s: outside the Warden's ring (%.0f m, ring %.0f m)" % [map_id, row.id, j.beacon_gap, j.ring], j.beacon_gap >= j.ring)
		_t.check("%s %s: seen from %d%% of the line within %d m (%d samples)" % [map_id, row.id, int(j.seen * 100.0), int(SIGHT_M), j.samples], j.samples > 0 and j.seen >= SIGHT_SHARE)
		_t.check("%s %s: clear of every built row" % [map_id, row.id], j.rows.is_empty(), str(j.rows))
		_t.check("%s %s: no tall row within %d m to hide it" % [map_id, row.id, int(TALL_CLEAR_M)], j.tall.is_empty(), str(j.tall))


# Every placement measure for a row: footing ground spread, gaps to the lines, enemy homes and the
# Warden's beacon, the share of nearby line that sees it, and the built and tall rows it crowds.
func _judge(row: Dictionary, park: Dictionary, lines: Array, heights: PackedFloat32Array) -> Dictionary:
	var foot := WorkMachines.footprint(row)
	var tips := WorkMachines.reach(row)
	var out := {"rows": [], "tall": []}
	var lo := INF
	var hi := -INF
	var foot_gap := INF
	for p in foot:
		foot_gap = minf(foot_gap, _line_gap(p, lines))
		var y := Terrain._grid_height(heights, p.x, p.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	out.spread = hi - lo
	out.foot_gap = foot_gap
	if not tips.is_empty():
		var tip_gap := INF
		for p in tips:
			tip_gap = minf(tip_gap, _line_gap(p, lines))
		out.tip_gap = tip_gap
	var home_gap := INF
	for home in park.home_rows:
		for park_row in park.park_rows:
			if park_row.id == home.site:
				for p in foot:
					home_gap = minf(home_gap, _row_gap(p, park_row))
	out.home_gap = home_gap
	var beacon := Vector2(float(park.landmark.beacon[0]), float(park.landmark.beacon[1]))
	out.beacon_gap = row.at.distance_to(beacon)
	out.ring = float(park.landmark.reach_m) + RING_CLEAR_M
	var seen := _seen_from_lines(row, lines, heights)
	out.seen = seen.x
	out.samples = int(seen.y)
	var all := Array(foot) + Array(tips)
	for park_row in park.park_rows:
		if park_row.element == "ground" or maxf(float(park_row.size[0]), float(park_row.size[2])) > 300.0:
			continue
		var near := INF
		for p in all:
			near = minf(near, _row_gap(p, park_row))
		if near < ROW_CLEAR_M:
			out.rows.append(park_row.id)
		elif float(park_row.size[1]) >= TALL_M and near < TALL_CLEAR_M:
			out.tall.append(park_row.id)
	return out


# (share of line samples within SIGHT_M that see the machine, sample count), every 4 m along each line.
func _seen_from_lines(row: Dictionary, lines: Array, heights: PackedFloat32Array) -> Vector2:
	var at: Vector2 = row.at
	var target := Vector3(at.x, Terrain._grid_height(heights, at.x, at.y) + MID_M, at.y)
	var total := 0
	var clear := 0
	for points in lines:
		for i in points.size() - 1:
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var n := maxi(1, int(a.distance_to(b) / 4.0))
			for k in n:
				var q := a.lerp(b, float(k) / n)
				if q.distance_to(at) > SIGHT_M:
					continue
				total += 1
				var eye := Vector3(q.x, Terrain._grid_height(heights, q.x, q.y) + EYE_M, q.y)
				var blocked := false
				var steps := int(eye.distance_to(target) / 2.0)
				for j in range(1, steps):
					var p := eye.lerp(target, float(j) / steps)
					if Terrain._grid_height(heights, p.x, p.z) > p.y:
						blocked = true
						break
				if not blocked:
					clear += 1
	return Vector2(float(clear) / maxi(total, 1), total)


# A channel's range over a kind's step targets (and its rest).
func _span(kind: String, channel: String) -> Vector2:
	var span := Vector2(INF, -INF)
	var start: Dictionary = WorkMachines.KINDS[kind].get("start", {})
	if start.has(channel):
		span = Vector2(start[channel], start[channel])
	for step in WorkMachines.KINDS[kind].steps:
		if step[1].has(channel):
			span = Vector2(minf(span.x, step[1][channel]), maxf(span.y, step[1][channel]))
	return span


# Per 60 Hz frame, at most this much of a channel: nothing snaps.
const STEP_MAX := {"slew_deg": 2.0, "drop_m": 0.25, "lift_m": 0.1, "run_m": 0.1}


func _cycle() -> void:
	for kind in WorkMachines.KINDS:
		var cycle := WorkMachines.cycle_s(kind)
		var a := WorkMachines.pose(kind, 0.0)
		var b := WorkMachines.pose(kind, cycle)
		var closes := true
		var wrap := float(WorkMachines.KINDS[kind].get("belt", {}).get("spacing_m", 0.0))
		for channel in a:
			var va := float(a[channel])
			var vb := float(b[channel])
			if channel == "run_m":
				va = fposmod(va, wrap)
				vb = fposmod(vb, wrap)
				closes = closes and (is_equal_approx(va, vb) or is_equal_approx(absf(va - vb), wrap))
			else:
				closes = closes and is_equal_approx(va, vb)
		_t.check("%s cycle closes (%.0f s)" % [kind, cycle], closes)
		var bounded := true
		var smooth := true
		var seen := {}
		var prev := a
		for i in range(1, int(cycle * 60.0) + 1):
			var p := WorkMachines.pose(kind, i / 60.0)
			for channel in p:
				var span := _span(kind, channel)
				var v := float(p[channel])
				bounded = bounded and v >= span.x - 1e-4 and v <= span.y + 1e-4
				var dv := absf(v - float(prev[channel]))
				if channel == "run_m":
					dv = minf(dv, absf(dv - _span(kind, channel).y))
				smooth = smooth and dv <= STEP_MAX.get(channel, 0.0)
				var got: Vector2 = seen.get(channel, Vector2(INF, -INF))
				seen[channel] = Vector2(minf(got.x, v), maxf(got.y, v))
			prev = p
		_t.check("%s stays inside its targets" % kind, bounded)
		_t.check("%s never snaps between frames" % kind, smooth)
		var full := true
		for channel in seen:
			full = full and seen[channel].is_equal_approx(_span(kind, channel))
		_t.check("%s works every channel's whole range" % kind, full, str(seen))


func _view() -> void:
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := FakeCtx.new()
	ctx.events = events
	var view := WorkMachines.new()
	root.add_child(view)
	view.setup(ctx)
	var rows := WorkMachines.rows_for("park_dam")
	_t.eq("one machine built per park_dam row", view.machines.size(), rows.size())
	if view.machines.is_empty():
		return
	var m: Dictionary = view.machines[0]
	_t.check("the derrick GLB carries Slew, Hook, Fall and Load", m.kind == "derrick" and m.nodes.has_all(["Slew", "Hook", "Fall", "Load"]))
	var bodies := view.find_children("*", "CollisionObject3D", true, false)
	var one_world_body := bodies.size() == rows.size()
	for body: CollisionObject3D in bodies:
		one_world_body = one_world_body and body is StaticBody3D and body.collision_layer == 1 and body.collision_mask == 0
		one_world_body = one_world_body and not m.nodes.Slew.is_ancestor_of(body)
	_t.check("each machine has one static world-layer body that watches nothing, off the moving parts", one_world_body, str(bodies.size()))
	var primitive := false
	for mesh_view: MeshInstance3D in view.find_children("*", "MeshInstance3D", true, false):
		primitive = primitive or mesh_view.mesh is PrimitiveMesh
	_t.check("no plain Godot shape is drawn", not primitive)
	var foot: Vector3 = ctx.terrain.ground_callable(1).call(rows[0].at.x, rows[0].at.y, 0.0)
	_t.check("seated at or under the ground at its pivot", m.root.global_position.y <= foot.y + 1e-4 and m.root.global_position.y > foot.y - 1.0)
	var slews := []
	var drops := []
	var sway := 0.0
	for i in 600:
		view._process(1.0 / 30.0)
		slews.append(m.nodes.Slew.rotation.y)
		drops.append(m.nodes.Load.position.y)
		sway = maxf(sway, absf(m.nodes.Hook.rotation.z))
	_t.check("the boom slews over 20 s", slews.max() - slews.min() > 1.0, str(slews.max() - slews.min()))
	_t.check("the bucket rises and falls", drops.max() - drops.min() > 4.0, str(drops.max() - drops.min()))
	_t.check("the hook sways on its rope, never against its stop (%.3f rad)" % sway, sway > 0.005 and sway < WorkMachines.SWAY_MAX * 0.8)
	# A derrick that starts mid-slew (a phase offset, a stage entry) takes no kick from the boom's rate.
	m.t = 9.5
	m.sway = 0.0
	m.sway_v = 0.0
	m.last_slew = NAN
	m.last_rate = NAN
	var start_sway := 0.0
	for i in 15:
		view._process(1.0 / 30.0)
		start_sway = maxf(start_sway, absf(m.nodes.Hook.rotation.z))
	_t.check("a derrick started mid-slew swings gently (%.3f rad in 0.5 s)" % start_sway, start_sway < 0.03)
	for sluice in view.machines.filter(func(x): return x.kind == "sluice"):
		var lifts := []
		var turns := []
		for i in 900:
			view._process(1.0 / 30.0)
			lifts.append(sluice.nodes.Gate.position.y)
			turns.append(sluice.nodes.Wheel.rotation.x)
		_t.check("%s: the leaf lifts and drops (%.1f m)" % [sluice.row.id, lifts.max() - lifts.min()], lifts.max() - lifts.min() > 3.5 and lifts.min() >= -1e-4)
		_t.check("%s: the handwheel turns with it" % sluice.row.id, turns.max() - turns.min() > 6.0)
	for conveyor in view.machines.filter(func(x): return x.kind == "conveyor"):
		var belt: Dictionary = WorkMachines.KINDS.conveyor.belt
		var count: int = conveyor.nodes.BeltFull.multimesh.instance_count
		_t.check("%s: %d buckets each way, one MultiMesh a run" % [conveyor.row.id, count], count >= 10 and conveyor.nodes.BeltEmpty.multimesh.instance_count == count)
		_t.check("%s: the template buckets are hidden" % conveyor.row.id, not conveyor.root.find_child("CupFull", true, false).visible)
	var belt: Dictionary = WorkMachines.KINDS.conveyor.belt
	var on_run := true
	var a := WorkMachines.buckets("conveyor", 0.0)
	var b := WorkMachines.buckets("conveyor", 0.5)
	var c := WorkMachines.buckets("conveyor", float(belt.spacing_m))
	for i in a.full.size():
		for t: Transform3D in [a.full[i], a.empty[i]]:
			on_run = on_run and t.origin.distance_to(Geometry3D.get_closest_point_to_segment(t.origin, belt.from, belt.to)) < 1.6
	_t.check("every bucket rides within 1.6 m of the belt", on_run)
	_t.check("half a metre of belt moves each bucket half a metre", is_equal_approx(a.full[0].origin.distance_to(b.full[0].origin), 0.5))
	var same := true
	for i in a.full.size():
		var found := false
		for j in c.full.size():
			found = found or a.full[i].origin.is_equal_approx(c.full[j].origin)
		same = same and found
	_t.check("a whole spacing of belt puts every bucket where another was", same)
	ctx.stages.stage.map = "park_flume"
	events.stage_entered.emit(2, false)
	_t.eq("a new park rebuilds its own machines", view.machines.size(), WorkMachines.rows_for("park_flume").size())
	events.stage_content_cleared.emit("clear")
	_t.eq("a cleared stage holds no machine", view.machines.size(), 0)
	await process_frame
	view.free()
	events.free()


func _source() -> void:
	var code := ""
	for line in FileAccess.get_file_as_string(SOURCE).split("\n"):
		code += line.split("#")[0] + "\n"
	for word in BANNED:
		_t.check("work_machines.gd has no %s" % word, not code.contains(word))
