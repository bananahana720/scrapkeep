extends RefCounted

const PLANE_TOLERANCE := 0.0001
const LINE_TOLERANCE := 0.0001


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

const BUCKET := 16.0
const STALE_TICKS := 450

var _entries := {}
var _watched := {}
var builds := 0
var hits := 0
var keep_one_placement := false


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


func cached(shape: Shape3D, transform: Transform3D) -> Dictionary:
	var entry: Dictionary = (_entries.get(shape.get_instance_id(), {}) as Dictionary).get(transform, {})
	if entry.is_empty() or entry["shape"].get_ref() != shape:
		return {}
	entry["used"] = Engine.get_physics_frames()
	hits += 1
	return entry


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


func readable(entry: Dictionary) -> bool:
	_wait(entry)
	return not (entry["result"]["faces"] as Array).is_empty()


func _wait(entry: Dictionary) -> void:
	if entry.has("task"):
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		entry.erase("task")


func finish() -> void:
	for placements in _entries.values():
		for entry in placements.values():
			if entry.has("task"):
				WorkerThreadPool.wait_for_task_completion(entry["task"])
				entry.erase("task")


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
