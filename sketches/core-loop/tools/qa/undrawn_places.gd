extends RefCounted

static func cluster(samples_by_owner: Dictionary, step_m: float) -> Array:
	var places := []
	var owners := samples_by_owner.keys()
	owners.sort()
	for owner in owners:
		var samples: PackedVector3Array = samples_by_owner[owner]
		_cluster_owner(places, owner, samples, 2.0 * step_m)
	return places


static func _cluster_owner(places: Array, owner: String, samples: PackedVector3Array, reach: float) -> void:
	var cells := {}
	for i in samples.size():
		var cell := Vector3i((samples[i] / reach).floor())
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(i)

	var visited := PackedByteArray()
	visited.resize(samples.size())
	for start in samples.size():
		if visited[start]:
			continue
		var pending: Array[int] = [start]
		visited[start] = 1
		var bounds := AABB(samples[start], Vector3.ZERO)
		var count := 0
		while not pending.is_empty():
			var point := samples[pending.pop_back()]
			bounds = bounds.expand(point)
			count += 1
			var cell := Vector3i((point / reach).floor())
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					for dz in range(-1, 2):
						for i: int in cells.get(cell + Vector3i(dx, dy, dz), []):
							if not visited[i] and point.distance_squared_to(samples[i]) <= reach * reach:
								visited[i] = 1
								pending.append(i)
		var centre := bounds.get_center()
		places.append({"owner": owner, "samples": count,
			"position": [centre.x, centre.y, centre.z], "size": [bounds.size.x, bounds.size.y, bounds.size.z]})
