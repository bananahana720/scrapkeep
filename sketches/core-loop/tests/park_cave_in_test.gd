extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Natural := preload("res://src/world/events/natural.gd")
const Director := preload("res://src/world/event_director.gd")
const T := preload("res://tests/support/t.gd")

class Table:
	const DEFS := [{"map": "park_sinkhole", "stage": 1, "world": 1}]

class Context:
	extends RefCounted
	var root

class World:
	extends Node3D
	var terrain
	var ctx := Context.new()
	var events
	var presentation = null

var t := T.new("park_cave_in_test")
var w: World
var handler
var row: Dictionary
var descent: Dictionary
var site: Dictionary
var point: Vector2
const BASELINE_B3B840D := 1.363632
var before: float
var previous_drop := 0.0
var samples := []
var rim_points: Array[Vector2] = []
var roof_cells := {}
var ground_faces := PackedVector3Array()
var ground_collider_faces := PackedVector3Array()
var holes: PackedByteArray
var baseline_grid: PackedFloat32Array
var rim_baseline := {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	w = World.new()
	root.add_child(w)
	w.ctx.root = w
	var camera := Camera3D.new()
	w.add_child(camera)
	camera.position = Vector3(0, 200, 0)
	camera.current = true
	w.terrain = Terrain.new(Table)
	w.terrain.build(w)
	w.terrain.use(1)
	var park: Dictionary = w.terrain.map().park
	row = park.event_rows.filter(func(r): return r.id == "west_roof_cave_in")[0]
	site = park.park_rows.filter(func(r): return r.id == row.site)[0]
	point = Vector2(float(site.at[0]), float(site.at[1]))
	_prepare_rim(site)
	before = w.terrain.height(point.x, point.y)
	await _sample("stage load", 0.0, false)
	w.events = Director.new(823, {}, w.terrain.map(), 14.0, Callable(w.terrain, "height"))
	handler = Natural.new()
	w.add_child(handler)
	handler.setup(w)
	await _sample("before", 0.0, false)
	w.events.register_family("natural", Callable(handler, "handle"))
	descent = w.events._park_states.filter(func(s): return s.row.id == row.id)[0]
	var clear := Vector3(700, 200, 700)
	var ctx := {"clock_tier": int(row.trigger.value)}
	var facts: Array = []
	for tick in 1200:
		facts.append_array(w.events.advance(0.1, clear, Vector3.ZERO, ctx))
		if descent.phase == Director.ANNOUNCED:
			break
	t.check("director announces authored cave-in", facts.any(func(f): return f.kind == "announced" and f.id == row.id))
	await _sample("telegraph", 0.0, false)
	facts = w.events.advance(float(row.telegraph.lead_s) + 2.0, clear, Vector3.ZERO, ctx)
	t.check("director lands authored cave-in with ball clear", facts.any(func(f): return f.kind == "started" and f.id == row.id))
	await _sample("land", 0.0, true)
	var fill_s := float(row.effect.fill_s)
	w.events.advance(fill_s * 0.5, clear, Vector3.ZERO, ctx)
	await _sample(str(fill_s * 0.5), fill_s * 0.5, true)
	var yaw := deg_to_rad(float(site.yaw_deg))
	var half_x := float(site.size[2]) * 0.5
	var margin := float(row.hold_clear_m)
	var inside := point + Vector2(half_x + margin * 0.5, 0.0).rotated(-yaw)
	await _hold("inside authored margin", Vector3(inside.x, before + 1.2, inside.y), Vector3.ZERO, fill_s * 0.5, ctx)
	var distance := half_x + margin + 10.0
	var approaching := point + Vector2(distance, 0.0).rotated(-yaw)
	var travel := Vector2(-distance / 2.0, 0.0).rotated(-yaw)
	var outside := Vector3(approaching.x, before + 1.2, approaching.y)
	t.check("approach starts outside authored margin", distance > half_x + margin)
	t.near("approach two-second segment reaches site centre", (approaching + travel * 2.0).distance_to(point), 0.0)
	w.events.advance(0.0, outside, Vector3.ZERO, ctx)
	await _hold("approaching two-second segment", outside, Vector3(travel.x, 0.0, travel.y), fill_s * 0.5, ctx)
	w.events.advance(fill_s * 0.5, clear, Vector3.ZERO, ctx)
	await _sample(str(fill_s), fill_s, true)
	t.near("director descent resumes using only clear fill time", float(descent.collapse_s), fill_s)
	t.near("handler resumes without consuming held time", float(handler.active[row.id].elapsed_s), fill_s)
	w.events.advance(2.0, clear, Vector3.ZERO, ctx)
	await _sample(str(fill_s + 2.0), fill_s + 2.0, true)
	var out := FileAccess.open("user://cave-in-samples.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(samples, "  ") + "\n")
	out.close()
	w.events.end_all()
	await _sample("ended", fill_s + 2.0, true)
	handler.release()
	Natural.release_plans()
	w.free()
	var result := t.verdict()
	quit(result)

func _hold(label: String, ball: Vector3, velocity: Vector3, elapsed: float, ctx: Dictionary) -> void:
	for tick in 2:
		w.events.advance(float(row.effect.fill_s) * 0.5, ball, velocity, ctx)
		var phase := "%s tick %d" % [label, tick + 1]
		await _sample(phase, elapsed, true)
		var expected_y := BASELINE_B3B840D - float(row.effect.depth_m) * elapsed / float(row.effect.fill_s)
		var sample: Dictionary = samples[-1]
		t.near(phase + " terrain holds", float(sample.height), expected_y, 0.05)
		t.near(phase + " drawn roof holds", float(sample.drawn), expected_y, 0.05)
		t.near(phase + " exact collider holds", float(sample.ray), expected_y, 0.05)
		t.near(phase + " handler elapsed holds", float(handler.active[row.id].elapsed_s), elapsed)
		t.near(phase + " director clear-time holds", float(descent.collapse_s), elapsed)


func _sample(label: String, elapsed: float, landed: bool) -> void:
	await physics_frame
	await physics_frame
	var height: float = w.terrain.height(point.x, point.y)
	var drop := before - height
	var expected := float(row.effect.depth_m) * clampf(elapsed / float(row.effect.fill_s), 0.0, 1.0)
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, before + 100.0, point.y), Vector3(point.x, before - 200.0, point.y))
	var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(query)
	var body: Node3D = handler._prepared[row.id].overlay if handler != null else w.terrain.cave_roof(row.id).get("body") if w.terrain.has_method("cave_roof") else null
	var drawn := _mesh_height(body.get_child(0), point) if body != null and body.is_visible_in_tree() else INF
	var ray_y: float = hit.position.y if not hit.is_empty() else INF
	print("SAMPLE %s elapsed=%.2f pre=%.6f height=%.6f drop=%.6f expected=%.6f ray=%.6f drawn=%.6f" % [label, elapsed, before, height, drop, expected, ray_y, drawn])
	samples.append({"label": label, "elapsed": elapsed, "before": before, "height": height, "drop": drop, "expected": expected, "ray": ray_y, "drawn": drawn, "drawn_method": "visible mesh triangles"})
	t.near(label + " authored drop", drop, expected, 0.5 if is_equal_approx(elapsed, 1.5) else 0.25 if elapsed >= 3.0 else 0.05)
	t.check(label + " monotonic drop", drop >= previous_drop - 0.00001)
	t.check(label + " real downward ray hits", not hit.is_empty())
	t.near(label + " ray agrees", ray_y, height, 0.05)
	t.near(label + " drawn mesh agrees", drawn, height, 0.05)
	if landed and handler.active.has(row.id):
		var feedback := _mesh_height(handler.active[row.id].mark.get_node("Style"), point)
		t.near(label + " landing feedback follows roof", feedback, height + 0.15 + 0.3, 0.05)
	if not landed:
		t.near(label + " pre-event terrain baseline b3b840d", height, BASELINE_B3B840D, 0.05)
		t.near(label + " pre-event collider baseline b3b840d", ray_y, BASELINE_B3B840D, 0.05)
	_sample_rim(label, expected)
	previous_drop = drop

func _prepare_rim(site: Dictionary) -> void:
	holes = FileAccess.get_file_as_bytes("res://assets/park/park_sinkhole/holes.bin")
	var file := FileAccess.open_compressed("res://assets/park/park_sinkhole/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	baseline_grid = file.get_buffer(801 * 801 * 4).to_float32_array()
	file.close()
	var half := Vector2(float(site.size[2]), float(site.size[0])) * 0.5
	var yaw := deg_to_rad(float(site.yaw_deg))
	for j in 800:
		for i in 800:
			if holes[j * 800 + i] != 1:
				continue
			var centre := Vector2(-799 + i * 2, -799 + j * 2)
			var local := (centre - point).rotated(yaw)
			if absf(local.x) <= half.x and absf(local.y) <= half.y:
				roof_cells[Vector2i(i, j)] = true
	t.check("authored site selects committed roof hole cells", not roof_cells.is_empty())
	var unique := {}
	for cell: Vector2i in roof_cells:
		var at := Vector2(cell) * 2.0 - Vector2.ONE * 800.0
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if roof_cells.has(cell + direction):
				continue
			var start := at
			var along := Vector2.DOWN
			if direction == Vector2i.RIGHT:
				start += Vector2.RIGHT * 2.0
			elif direction == Vector2i.UP:
				along = Vector2.RIGHT
			elif direction == Vector2i.DOWN:
				start += Vector2.DOWN * 2.0
				along = Vector2.RIGHT
			for metre in 3:
				unique[start + along * metre] = true
	# Every 1 m point in all four cells incident to the gate's shared corner.
	for z in range(254, 259):
		for x in range(-226, -221):
			unique[Vector2(x, z)] = true
	for at: Vector2 in unique:
		rim_points.append(at)
	t.check("rim probes include shared corner [-224,256]", unique.has(Vector2(-224, 256)))
	var corner_cell := Vector2i(288, 528)
	for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
		var cell: Vector2i = corner_cell + delta
		t.eq("shared corner committed hole cell " + str(cell), int(holes[cell.y * 800 + cell.x]), 1 if delta == Vector2i.ZERO else 0)
	var retained := {}
	for at in rim_points:
		var cell := Vector2i(floori((at.x + 800.0) / 2.0), floori((at.y + 800.0) / 2.0))
		for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
			var adjacent: Vector2i = cell + delta
			if holes[adjacent.y * 800 + adjacent.x] == 0:
				retained[adjacent] = true
	var render = w.terrain.park_ground(1).terrain3d
	t.check("retained ground render is visible", render != null and render.is_visible_in_tree())
	var render_errors := 0
	for cell: Vector2i in retained:
		var at := Vector2(cell) * 2.0 - Vector2.ONE * 800.0
		var corners := PackedVector3Array()
		for delta in [Vector2.ZERO, Vector2(2, 0), Vector2(0, 2), Vector2(2, 2)]:
			var p: Vector2 = at + delta
			var location := Vector2i(floori(p.x / 1024.0), floori(p.y / 1024.0))
			var image: Image = render.data.get_region(location).get_height_map()
			var pixel := Vector2i(p) - location * 1024
			var y := image.get_pixel(pixel.x, pixel.y).r
			corners.append(Vector3(p.x, y, p.y))
			var k := int((p.y + 800.0) / 2.0) * 801 + int((p.x + 800.0) / 2.0)
			if absf(y - baseline_grid[k]) > 0.00001:
				render_errors += 1
		ground_faces.append_array(PackedVector3Array([corners[0], corners[1], corners[2], corners[1], corners[3], corners[2]]))
	t.eq("retained rendered vertices preserve committed ground", render_errors, 0)
	var low := Vector2.INF
	var high := -Vector2.INF
	for at in rim_points:
		low = low.min(at)
		high = high.max(at)
	for tile in w.terrain.park_ground(1).tiles:
		var collider: CollisionShape3D = tile.get_child(0)
		var vertices: PackedVector3Array = collider.shape.get_faces()
		for k in range(0, vertices.size(), 3):
			var face := PackedVector3Array()
			var face_low := Vector2.INF
			var face_high := -Vector2.INF
			for v in vertices.slice(k, k + 3):
				var p: Vector3 = collider.global_transform * v
				face.append(p)
				face_low = face_low.min(Vector2(p.x, p.z))
				face_high = face_high.max(Vector2(p.x, p.z))
			if face_high.x >= low.x and face_low.x <= high.x and face_high.y >= low.y and face_low.y <= high.y:
				ground_collider_faces.append_array(face)
	print("RIM COVERAGE %d authored hole cells, %d unique 1 m boundary/corner points, %d retained ground cells" % [roof_cells.size(), rim_points.size(), retained.size()])

func _sample_rim(label: String, expected_drop: float) -> void:
	var roof_body: Node3D = w.terrain.cave_roof(row.id).body
	var roof_view: MeshInstance3D = roof_body.get_child(0)
	var faces := PackedVector3Array()
	var collider_faces := ground_collider_faces.duplicate()
	for roof_collider in roof_body.get_children():
		if roof_collider is CollisionShape3D:
			for v in roof_collider.shape.get_faces():
				collider_faces.append(roof_collider.global_transform * v)
	if roof_body.is_visible_in_tree():
		var arrays := roof_view.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for k in arrays[Mesh.ARRAY_INDEX]:
			faces.append(roof_view.global_transform * vertices[k])
	var included: Array = w.terrain.park_ground(1).tiles.duplicate()
	included.append(roof_body)
	var excluded: Array[RID] = []
	for body in w.find_children("*", "CollisionObject3D", true, false):
		if not included.has(body):
			excluded.append(body.get_rid())
	var mesh_misses := 0
	var ray_misses := 0
	var collider_misses := 0
	var exact_ray_misses := 0
	var expected_misses := 0
	var pre_event_misses := 0
	var worst_ray := 0.0
	var first_bad := ""
	var space := w.get_world_3d().direct_space_state
	for at in rim_points:
		var ground := _faces_height(ground_faces, at)
		var drawn := maxf(ground, _faces_height(faces, at))
		var expected := maxf(ground, _baked_roof_height(at) - expected_drop)
		var height: float = w.terrain.height(at.x, at.y)
		var collider := _faces_height(collider_faces, at)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, expected + 20.0, at.y), Vector3(at.x, expected - 20.0, at.y), 0xFFFFFFFF, excluded))
		var ray := INF if hit.is_empty() else float(hit.position.y)
		if hit.is_empty() or absf(ray - collider) > 0.05 or absf(ray - height) > 0.05 or absf(ray - drawn) > 0.05:
			exact_ray_misses += 1
		var ray_error := absf(ray - drawn)
		worst_ray = maxf(worst_ray, ray_error)
		if absf(height - drawn) > 0.05:
			mesh_misses += 1
		if ray_error > 0.05 or absf(ray - height) > 0.05:
			ray_misses += 1
		if absf(collider - drawn) > 0.05 or absf(collider - height) > 0.05:
			collider_misses += 1
		if absf(drawn - expected) > 0.05:
			expected_misses += 1
		if label == "stage load":
			rim_baseline[at] = expected
		if expected_drop == 0.0 and (absf(height - float(rim_baseline[at])) > 0.05 or absf(ray - float(rim_baseline[at])) > 0.05):
			pre_event_misses += 1
		if first_bad.is_empty() and (absf(height - drawn) > 0.05 or ray_error > 0.05):
			first_bad = "%s terrain=%.6f drawn=%.6f ray=%.6f expected=%.6f" % [at, height, drawn, ray, expected]
		if at == Vector2(-224, 256):
			print("RIM CORNER %s terrain=%.6f drawn=%.6f ray=%.6f expected=%.6f" % [label, height, drawn, ray, expected])
	print("RIM SAMPLE %s points=%d terrain/drawn misses=%d ray misses=%d exact collider misses=%d exact ray edge misses=%d row-derived misses=%d worst ray/drawn=%.6f first=%s" % [label, rim_points.size(), mesh_misses, ray_misses, collider_misses, exact_ray_misses, expected_misses, worst_ray, first_bad])
	t.eq(label + " whole boundary exact downward rays agree with terrain, drawing and closed collider", exact_ray_misses, 0)
	t.eq(label + " whole boundary terrain agrees with uppermost drawn ground", mesh_misses, 0)
	t.eq(label + " whole boundary collider agrees with uppermost drawn ground and terrain", ray_misses, 0)
	t.eq(label + " whole boundary closed collider triangles agree at exact points", collider_misses, 0)
	t.eq(label + " whole boundary row-derived surface", expected_misses, 0)
	if expected_drop == 0.0:
		t.eq(label + " whole boundary pre-event height and collider unchanged", pre_event_misses, 0)

func _baked_roof_height(at: Vector2) -> float:
	var result := -INF
	for cell: Vector2i in roof_cells:
		var low := Vector2(cell) * 2.0 - Vector2.ONE * 800.0
		if at.x < low.x or at.x > low.x + 2.0 or at.y < low.y or at.y > low.y + 2.0:
			continue
		var k := cell.y * 801 + cell.x
		var a := Vector3(low.x, baseline_grid[k], low.y)
		var b := Vector3(low.x + 2, baseline_grid[k + 1], low.y)
		var c := Vector3(low.x, baseline_grid[k + 801], low.y + 2)
		var d := Vector3(low.x + 2, baseline_grid[k + 802], low.y + 2)
		result = maxf(result, _faces_height(PackedVector3Array([a, b, c, b, d, c]), at))
	return result

func _faces_height(faces: PackedVector3Array, at: Vector2) -> float:
	var result := -INF
	for k in range(0, faces.size(), 3):
		var a := faces[k]
		var b := faces[k + 1]
		var c := faces[k + 2]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var ap := at - Vector2(a.x, a.z)
		var det := ab.cross(ac)
		if absf(det) < 0.0000001:
			continue
		var u := ap.cross(ac) / det
		var v := ab.cross(ap) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			result = maxf(result, a.y + u * (b.y - a.y) + v * (c.y - a.y))
	return result

func _mesh_height(view: MeshInstance3D, at: Vector2) -> float:
	var arrays := view.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in range(0, indices.size(), 3):
		var a: Vector3 = view.global_transform * vertices[indices[k]]
		var b: Vector3 = view.global_transform * vertices[indices[k + 1]]
		var c: Vector3 = view.global_transform * vertices[indices[k + 2]]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var ac := Vector2(c.x - a.x, c.z - a.z)
		var ap := at - Vector2(a.x, a.z)
		var det := ab.cross(ac)
		if absf(det) < 0.0000001:
			continue
		var u := ap.cross(ac) / det
		var v := ab.cross(ap) / det
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return INF
