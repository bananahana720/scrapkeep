extends RefCounted

# Rivet's carve (rivet_kit._commit_terrain) subtracts one shadow per terrain face, so a flat floor
# of 2 m triangles costs hundreds of clips for one plane. merge() joins coplanar faces into convex
# polygons first (their hull when they tile it, else neighbours across shared edges): the union
# of their shadows is the same volume, so the carved shape and who it hits stay the same and only
# the scar's inner edge lines change (Andrew's "Fewer lines", 2026-10-17 21:30Z).

# Faces this close to one plane are coplanar; a vertex this close to the line through its
# neighbours is dropped, as the merged edge passes through it.
const PLANE_TOLERANCE := 0.0001
const LINE_TOLERANCE := 0.0001


# Faces in first-seen order of their planes; a face that cannot join stays as it was.
static func merge(faces: Array) -> Array:
	var groups := {}
	var keys: Array = []
	var merged: Array = []
	for face in faces:
		var normal: Vector3 = ((face[1] as Vector3) - face[0]).cross((face[2] as Vector3) - face[0])
		if normal.length_squared() < 1e-12:
			merged.append(face)
			continue
		normal = normal.normalized()
		var offset := normal.dot(face[0])
		var key := Vector4i(roundi(normal.x * 1000.0), roundi(normal.y * 1000.0), roundi(normal.z * 1000.0), roundi(offset * 1000.0))
		if not groups.has(key):
			groups[key] = {"normal": normal, "offset": offset, "faces": []}
			keys.append(key)
		var group: Dictionary = groups[key]
		if _on_plane(face, group["normal"], group["offset"]):
			(group["faces"] as Array).append(face)
		else:
			merged.append(face)
	for key in keys:
		var plane_faces: Array = groups[key]["faces"]
		var hull := _hull_union(plane_faces, groups[key]["normal"]) if plane_faces.size() > 1 else []
		if hull.is_empty():
			merged.append_array(_merge_plane(plane_faces, groups[key]["normal"]))
		else:
			merged.append(hull)
	return merged


# --- Level ground ---------------------------------------------------------------------------
# A park's ground is a heightfield of 2 m cells, never exactly coplanar, so merge() leaves a
# stand's 214 faces nearly as they are and a Breach there carves for five ticks. merge_level()
# is merge() and then flattens the near-level polygons: those within level_deg of straight up.
# A region grows from its first polygon across shared corners while each polygon's normal is
# within tolerance_deg of the first's and every corner is within deviation of the first
# polygon's plane. The region's corners then slide along the plane normal onto that plane (at
# most `deviation`), which makes its polygons exactly coplanar, and they merge as merge() does
# a coplanar group: their hull when they tile it, else convex pieces. Everything steeper, and a
# region of one polygon, is returned as it was, so a slope's faces, shadows and carve stay as
# merge() made them.
static func merge_level(faces: Array, level_deg: float, tolerance_deg: float, deviation: float) -> Array:
	var polys := merge(faces)
	var up_cos := cos(deg_to_rad(level_deg))
	var tol_cos := cos(deg_to_rad(tolerance_deg))
	var normals: Array = []
	var candidates: Array = []
	var by_vertex := {}
	for index in polys.size():
		var poly: Array = polys[index]
		var normal := Vector3.ZERO
		for k in range(1, poly.size() - 1):
			normal += ((poly[k] as Vector3) - poly[0]).cross((poly[k + 1] as Vector3) - poly[0])
		normal = normal.normalized() if normal.length_squared() > 1e-12 else Vector3.ZERO
		normals.append(normal)
		# Either winding is ground; a region keeps its first polygon's.
		if absf(normal.y) < up_cos:
			continue
		candidates.append(index)
		for v: Vector3 in poly:
			if not by_vertex.has(v):
				by_vertex[v] = []
			(by_vertex[v] as Array).append(index)
	var taken := {}
	var replaced := {}
	for seed: int in candidates:
		if taken.has(seed):
			continue
		taken[seed] = true
		var normal: Vector3 = normals[seed]
		var offset := normal.dot((polys[seed] as Array)[0])
		var members: Array = [seed]
		var next := 0
		while next < members.size():
			for v: Vector3 in polys[members[next]]:
				for q: int in by_vertex[v]:
					if not taken.has(q) and (normals[q] as Vector3).dot(normal) >= tol_cos and _within(polys[q], normal, offset, deviation):
						taken[q] = true
						members.append(q)
			next += 1
		if members.size() < 2:
			continue
		members.sort()
		var flat: Array = []
		for m: int in members:
			var snapped: Array = []
			for v: Vector3 in polys[m]:
				snapped.append(v - normal * (normal.dot(v) - offset))
			flat.append(snapped)
		var joined: Array = []
		var hull := _hull_union(flat, normal)
		if hull.is_empty():
			joined = _merge_plane(flat, normal)
		else:
			joined = [hull]
		replaced[members[0]] = joined
		for m: int in members.slice(1):
			replaced[m] = []
	var out: Array = []
	for index in polys.size():
		if not replaced.has(index):
			out.append(polys[index])
		else:
			out.append_array(replaced[index])
	return out


static func _within(poly: Array, normal: Vector3, offset: float, deviation: float) -> bool:
	for v: Vector3 in poly:
		if absf(normal.dot(v) - offset) > deviation:
			return false
	return true




# The upward normal of the highest face under a point (at most `above` over its surface), or
# Vector3.ZERO when there is none: the ground a Breach lands on.
static func ground_normal(faces: Array, at: Vector3, above := 0.6) -> Vector3:
	var best := -INF
	var normal := Vector3.ZERO
	for face in faces:
		var a: Vector3 = face[0]
		var b: Vector3 = face[1]
		var c: Vector3 = face[2]
		var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(det) < 1e-9:
			continue
		var l1 := ((b.z - c.z) * (at.x - c.x) + (c.x - b.x) * (at.z - c.z)) / det
		var l2 := ((c.z - a.z) * (at.x - c.x) + (a.x - c.x) * (at.z - c.z)) / det
		var l3 := 1.0 - l1 - l2
		if l1 < -1e-6 or l2 < -1e-6 or l3 < -1e-6:
			continue
		var y := l1 * a.y + l2 * b.y + l3 * c.y
		if y > at.y + above or y <= best:
			continue
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		best = y
		normal = n.normalized() * signf(n.y)
	return normal


# A mesh's faces never overlap, so when their areas add up to their convex hull's they tile it
# and the hull is their union: one polygon, found without walking edges. [] otherwise.
const AREA_TOLERANCE := 0.001


static func _hull_union(faces: Array, normal: Vector3) -> Array:
	var at: Vector3 = faces[0][0]
	var u := (((faces[0][1] as Vector3) - at)).normalized()
	var w := normal.cross(u)
	var points := PackedVector2Array()
	var area := 0.0
	for face in faces:
		var flat := PackedVector2Array()
		for v: Vector3 in face:
			flat.append(Vector2((v - at).dot(u), (v - at).dot(w)))
		area += absf(_shoelace(flat))
		points.append_array(flat)
	var hull := Geometry2D.convex_hull(points)
	hull.resize(hull.size() - 1)
	if hull.size() < 3 or absf(absf(_shoelace(hull)) - area) > AREA_TOLERANCE + area * 0.000001:
		return []
	var polygon: Array = []
	for p in hull:
		polygon.append(at + u * p.x + w * p.y)
	return polygon


static func _shoelace(points: PackedVector2Array) -> float:
	var sum := 0.0
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		sum += float(a.x) * float(b.y) - float(b.x) * float(a.y)
	return sum * 0.5


static func _on_plane(face: Array, normal: Vector3, offset: float) -> bool:
	for v: Vector3 in face:
		if absf(normal.dot(v) - offset) > PLANE_TOLERANCE:
			return false
	return true


# Each polygon absorbs neighbours across shared edges (b -> a in one, a -> b in the other) while
# the union stays convex.
static func _merge_plane(faces: Array, normal: Vector3) -> Array:
	var polys: Array = []
	for face in faces:
		polys.append((face as Array).duplicate())
	var alive: Array = []
	alive.resize(polys.size())
	alive.fill(true)
	var edges := {}
	for p in polys.size():
		_index(edges, polys[p], p)
	for p in polys.size():
		if not alive[p]:
			continue
		var grew := true
		while grew:
			grew = false
			var poly: Array = polys[p]
			for k in poly.size():
				var a: Vector3 = poly[k]
				var b: Vector3 = poly[(k + 1) % poly.size()]
				var q: int = edges.get(b, {}).get(a, -1)
				if q < 0 or q == p or not alive[q]:
					continue
				var joined := _splice(poly, k, polys[q], normal)
				if joined.is_empty():
					continue
				_unindex(edges, poly, p)
				_unindex(edges, polys[q], q)
				alive[q] = false
				polys[p] = joined
				_index(edges, joined, p)
				grew = true
				break
	var out: Array = []
	for p in polys.size():
		if alive[p]:
			out.append(polys[p])
	return out


static func _index(edges: Dictionary, poly: Array, p: int) -> void:
	for k in poly.size():
		var a: Vector3 = poly[k]
		if not edges.has(a):
			edges[a] = {}
		edges[a][poly[(k + 1) % poly.size()]] = p


static func _unindex(edges: Dictionary, poly: Array, p: int) -> void:
	for k in poly.size():
		var from: Dictionary = edges.get(poly[k], {})
		var b: Vector3 = poly[(k + 1) % poly.size()]
		if from.get(b, -1) == p:
			from.erase(b)


# poly's edge k (a -> b) meets other's b -> a: walk poly from b round to a, then other from a
# round to b, without repeating either. Empty when the union is not strictly convex.
static func _splice(poly: Array, k: int, other: Array, normal: Vector3) -> Array:
	var a: Vector3 = poly[k]
	var b: Vector3 = poly[(k + 1) % poly.size()]
	var j := -1
	for i in other.size():
		if other[i] == b and other[(i + 1) % other.size()] == a:
			j = i
			break
	if j < 0:
		return []
	var joined: Array = []
	for i in poly.size():
		joined.append(poly[(k + 1 + i) % poly.size()])
	for i in range(1, other.size() - 1):
		joined.append(other[(j + 1 + i) % other.size()])
	var trimmed := true
	while trimmed and joined.size() > 3:
		trimmed = false
		for i in joined.size():
			var before: Vector3 = joined[(i + joined.size() - 1) % joined.size()]
			var at: Vector3 = joined[i]
			var after: Vector3 = joined[(i + 1) % joined.size()]
			var line := after - before
			if line.length_squared() > 0.0 and (at - before).cross(line).length() / line.length() <= LINE_TOLERANCE:
				joined.remove_at(i)
				trimmed = true
				break
	for i in joined.size():
		var before: Vector3 = joined[(i + joined.size() - 1) % joined.size()]
		var at: Vector3 = joined[i]
		var after: Vector3 = joined[(i + 1) % joined.size()]
		if (at - before).cross(after - at).dot(normal) <= 0.0:
			return []
	return joined


# --- The per-shape cache --------------------------------------------------------------------
# A terrain shape's world-space faces and a bucket grid of their boxes, built once on a worker,
# so each carve reads only the faces near it instead of every triangle of a park tile. A carve
# uses the finished build, waiting for it if needed, so a bot replay never depends on timing.

const BUCKET := 16.0
# A build nobody has read for this many ticks is dropped. Parks share one Shape3D across many
# colliders and a moved body leaves its old placements behind, so entries are kept per shape
# and transform and aged out instead of replaced.
const STALE_TICKS := 450

# instance id -> {transform -> {shape (WeakRef), task, result: {faces, boxes, grid}, used}}
var _entries := {}
var _watched := {}
# Counters for a hitch guard: builds started (a cache miss) and cached() reads that found one.
var builds := 0
var hits := 0
# A planted control: the old keying, one build per shape, replaced when the shape is placed
# anywhere else. A park's shared shapes then rebuild every warm-up cycle (the 100-175 ms tick).
var keep_one_placement := false


# local_faces: the shape's faces in its own space, an Array of vertex Arrays, a
# PackedVector3Array of triangles (a trimesh), or a Callable the worker calls for either.
func request(shape: Shape3D, transform: Transform3D, local_faces) -> Dictionary:
	var id := shape.get_instance_id()
	var entry := cached(shape, transform)
	if not entry.is_empty():
		return entry
	if not _watched.has(id):
		_watched[id] = true
		shape.changed.connect(_forget.bind(id))
	builds += 1
	entry = {"shape": weakref(shape), "result": {}, "used": Engine.get_physics_frames()}
	var result: Dictionary = entry["result"]
	entry["task"] = WorkerThreadPool.add_task(func(): _build(_world(local_faces, transform), result), false, "rivet terrain faces")
	if keep_one_placement:
		_forget(id)
	if not _entries.has(id):
		_entries[id] = {}
	_entries[id][transform] = entry
	return entry


# The entry for this shape at this transform, or {} when it has none yet.
func cached(shape: Shape3D, transform: Transform3D) -> Dictionary:
	var entry: Dictionary = (_entries.get(shape.get_instance_id(), {}) as Dictionary).get(transform, {})
	if entry.is_empty() or entry["shape"].get_ref() != shape:
		return {}
	entry["used"] = Engine.get_physics_frames()
	hits += 1
	return entry


# The faces whose box meets box, in the shape's order.
func faces_near(entry: Dictionary, box: AABB) -> Array:
	_wait(entry)
	var result: Dictionary = entry["result"]
	var picks := {}
	var grid: Dictionary = result["grid"]
	var low := _bucket(box.position)
	var high := _bucket(box.end)
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			for index in grid.get(Vector2i(x, z), []):
				picks[index] = true
	var order: Array = picks.keys()
	order.sort()
	var faces: Array = result["faces"]
	var boxes: Array = result["boxes"]
	var near: Array = []
	for index in order:
		if box.intersects(boxes[index]):
			near.append(faces[index])
	return near


# False when the shape gave no faces the carve can read (a build from a Callable can only tell
# once it has run).
func readable(entry: Dictionary) -> bool:
	_wait(entry)
	return not (entry["result"]["faces"] as Array).is_empty()


func _wait(entry: Dictionary) -> void:
	if entry.has("task"):
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		entry.erase("task")


# Waits for every build, so none runs past its kit.
func finish() -> void:
	for placements in _entries.values():
		for entry in placements.values():
			if entry.has("task"):
				WorkerThreadPool.wait_for_task_completion(entry["task"])
				entry.erase("task")


# Drops builds whose shape is gone, so freed stages do not pin their faces, and builds nobody
# has read for STALE_TICKS. A build still running is left for a later prune.
func prune() -> void:
	var now := Engine.get_physics_frames()
	for id in _entries.keys():
		var placements: Dictionary = _entries[id]
		for transform in placements.keys():
			var entry: Dictionary = placements[transform]
			if entry["shape"].get_ref() != null and now - int(entry["used"]) <= STALE_TICKS:
				continue
			if entry.has("task"):
				if not WorkerThreadPool.is_task_completed(entry["task"]):
					continue
				WorkerThreadPool.wait_for_task_completion(entry["task"])
				entry.erase("task")
			placements.erase(transform)
		if placements.is_empty():
			_entries.erase(id)
			if not is_instance_id_valid(id):
				_watched.erase(id)


func _forget(id: int) -> void:
	for entry in (_entries.get(id, {}) as Dictionary).values():
		if entry.has("task"):
			WorkerThreadPool.wait_for_task_completion(entry["task"])
			entry.erase("task")
	_entries.erase(id)


# The shape's faces in world space. local_faces is a PackedVector3Array of triangles, an Array
# of polygons, or a Callable that returns either (a search too slow for the main thread).
static func _world(local_faces, transform: Transform3D):
	if local_faces is Callable:
		local_faces = (local_faces as Callable).call()
	if local_faces is PackedVector3Array:
		return transform * (local_faces as PackedVector3Array)
	return (local_faces as Array).map(func(face): return (face as Array).map(func(v): return transform * v))


static func _build(world, result: Dictionary) -> void:
	var faces: Array = []
	if world is PackedVector3Array:
		var points: PackedVector3Array = world
		for i in range(0, points.size(), 3):
			faces.append([points[i], points[i + 1], points[i + 2]])
	else:
		faces = world
	var boxes: Array = []
	var grid := {}
	for index in faces.size():
		var face: Array = faces[index]
		var box := AABB(face[0], Vector3.ZERO)
		for v in face:
			box = box.expand(v)
		boxes.append(box)
		var low := _bucket(box.position)
		var high := _bucket(box.end)
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var key := Vector2i(x, z)
				if not grid.has(key):
					grid[key] = []
				(grid[key] as Array).append(index)
	result["faces"] = faces
	result["boxes"] = boxes
	result["grid"] = grid


static func _bucket(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / BUCKET), floori(at.z / BUCKET))
