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

# instance id -> {shape (WeakRef), transform, task, result: {faces, boxes, grid}}
var _entries := {}
var _watched := {}


# local_faces: the shape's faces in its own space, an Array of vertex Arrays, or a
# PackedVector3Array of triangles (a trimesh).
func request(shape: Shape3D, transform: Transform3D, local_faces) -> Dictionary:
	var id := shape.get_instance_id()
	var entry := cached(shape, transform)
	if not entry.is_empty():
		return entry
	# A moved shape's old build is waited for before its entry is replaced: every task is
	# waited for once.
	if (_entries.get(id, {}) as Dictionary).has("task"):
		WorkerThreadPool.wait_for_task_completion(_entries[id]["task"])
	if not _watched.has(id):
		_watched[id] = true
		shape.changed.connect(_forget.bind(id))
	var world
	if local_faces is PackedVector3Array:
		world = transform * (local_faces as PackedVector3Array)
	else:
		world = (local_faces as Array).map(func(face): return (face as Array).map(func(v): return transform * v))
	entry = {"shape": weakref(shape), "transform": transform, "result": {}}
	var result: Dictionary = entry["result"]
	entry["task"] = WorkerThreadPool.add_task(func(): _build(world, result), false, "rivet terrain faces")
	_entries[id] = entry
	return entry


# The entry for this shape at this transform, or {} when it has none yet.
func cached(shape: Shape3D, transform: Transform3D) -> Dictionary:
	var entry: Dictionary = _entries.get(shape.get_instance_id(), {})
	if not entry.is_empty() and entry["shape"].get_ref() == shape and entry["transform"] == transform:
		return entry
	return {}


# The faces whose box meets box, in the shape's order.
func faces_near(entry: Dictionary, box: AABB) -> Array:
	if entry.has("task"):
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		entry.erase("task")
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


# Waits for every build, so none runs past its kit.
func finish() -> void:
	for entry in _entries.values():
		if entry.has("task"):
			WorkerThreadPool.wait_for_task_completion(entry["task"])
			entry.erase("task")


# Drops shapes that are gone, so freed stages do not pin their faces.
func prune() -> void:
	for id in _entries.keys():
		var entry: Dictionary = _entries[id]
		if entry["shape"].get_ref() == null and not entry.has("task"):
			_entries.erase(id)
			_watched.erase(id)


func _forget(id: int) -> void:
	var entry: Dictionary = _entries.get(id, {})
	if entry.has("task"):
		WorkerThreadPool.wait_for_task_completion(entry["task"])
	_entries.erase(id)


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
