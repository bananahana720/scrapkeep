extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Gorge := preload("res://src/world/map_gorge.gd")


class Surface:
	extends RefCounted
	var mesh: ArrayMesh
	var vertices := PackedVector3Array()
	var cells := {}
	func height(point: Vector2) -> float:
		var cell := Vector2i(floori(point.x / ParkTerrain.STEP), floori(point.y / ParkTerrain.STEP))
		var faces: Array = []
		for delta in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.UP, Vector2i(-1, -1)]:
			faces.append_array(cells.get(cell + delta, []))
		for k in faces:
			var a := vertices[k]
			var b := Vector2(vertices[k + 1].x - a.x, vertices[k + 1].z - a.z)
			var c := Vector2(vertices[k + 2].x - a.x, vertices[k + 2].z - a.z)
			var d := point - Vector2(a.x, a.z)
			var determinant := b.cross(c)
			if absf(determinant) < 0.0000001:
				continue
			var u := d.cross(c) / determinant
			var v := b.cross(d) / determinant
			if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
				return a.y + u * (vertices[k + 1].y - a.y) + v * (vertices[k + 2].y - a.y)
		return -INF


class OverlayMap:
	extends ParkMap
	var swaps := {}
	var profiles := {}
	var source
	func apply_swap(id: String, changed: bool) -> void:
		if not swaps.has(id):
			return
		var entry: Dictionary = swaps[id]
		entry.body.position = entry.home if changed else entry.home + Vector3.DOWN * Gorge.SWAP_PARK
		entry.body.visible = changed
		if is_instance_valid(entry.before):
			entry.before.position = entry.before_home + Vector3.DOWN * Gorge.SWAP_PARK if changed else entry.before_home
			entry.before.visible = false if changed else entry.before_visible
	func overlay_height(id: String, x: float, z: float, ground: float) -> float:
		if not profiles.has(id):
			return source.overlay_height(id, x, z, ground)
		var p: Dictionary = profiles[id]
		if not ParkMap.footprint_contains(p.site, Vector2(x, z)):
			return -INF
		return p.surface.height(Vector2(x, z))


static func _rectangle(low: Vector2, high: Vector2) -> Array:
	return [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]


static func project_surface(world, geometry: Dictionary, shapes: Array, offset := Callable(), water := false, baseline: Surface = null, overlay_map: OverlayMap = null) -> Surface:
	if overlay_map == null and world.terrain.map() is OverlayMap:
		overlay_map = world.terrain.map()
	var surface := Surface.new()
	var centre := Vector2(geometry.at.x, geometry.at.z)
	var yaw: float = geometry.yaw
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	if geometry.has("source_surface"):
		var start: Surface = geometry.source_surface
		var target: Surface = geometry.target_surface
		surface.cells = start.cells
		for k in start.vertices.size():
			vertices.append(start.vertices[k].lerp(target.vertices[k], float(geometry.progress)))
		for k in range(0, vertices.size(), 3):
			var normal := (vertices[k + 2] - vertices[k]).cross(vertices[k + 1] - vertices[k]).normalized()
			normals.append_array([normal, normal, normal])
	else:
		for shape: Array in shapes:
			var polygon := shape.map(func(p): return p.rotated(-yaw) + centre)
			var low := Vector2.INF
			var high := -Vector2.INF
			for point: Vector2 in polygon:
				low = low.min(point)
				high = high.max(point)
			for j in range(floori(low.y / ParkTerrain.STEP), floori(high.y / ParkTerrain.STEP) + 1):
				for i in range(floori(low.x / ParkTerrain.STEP), floori(high.x / ParkTerrain.STEP) + 1):
					var cell := Vector2i(i, j)
					var a := Vector2(i, j) * ParkTerrain.STEP
					var b := a + Vector2.RIGHT * ParkTerrain.STEP
					var c := a + Vector2.DOWN * ParkTerrain.STEP
					var d := a + Vector2.ONE * ParkTerrain.STEP
					var heights := PackedFloat64Array()
					for point in [a, b, c, d]:
						var y: float = _water_ground(world, point) if water else world.terrain.height(point.x, point.y)
						if baseline == null and not water and "_heights" in world.terrain:
							y = maxf(y, world.terrain._grid_height(world.terrain._heights[world.terrain.stage - 1], point.x, point.y))
						heights.append(y)
					if water and "_holes" in world.terrain:
						var terrain = world.terrain
						var floor_y := ParkTerrain.hole_floor(terrain._holes[terrain.stage - 1], terrain._under[terrain.stage - 1], a.x + ParkTerrain.STEP * 0.5, a.y + ParkTerrain.STEP * 0.5)
						if not is_nan(floor_y):
							for k in 4:
								heights[k] = minf(heights[k], floor_y)
					for triangle in [[a, b, c], [b, d, c]]:
						var clipped: Array = polygon
						for edge in 3:
							clipped = _clip_edge(clipped, triangle[edge], triangle[(edge + 1) % 3])
						for k in range(1, clipped.size() - 1):
							var face := PackedVector3Array()
							for point: Vector2 in [clipped[0], clipped[k], clipped[k + 1]]:
								var f := (point - a) / ParkTerrain.STEP
								var y: float = heights[0] + (heights[1] - heights[0]) * f.x + (heights[2] - heights[0]) * f.y if triangle[0] == a else heights[3] + (heights[2] - heights[3]) * (1.0 - f.x) + (heights[1] - heights[3]) * (1.0 - f.y)
								if baseline != null:
									y = baseline.height(point)
								elif not water:
									y = maxf(y, world.terrain.height(point.x, point.y))
									if overlay_map != null:
										for id in world.terrain.overlays:
											if overlay_map.profiles.has(id):
												y = maxf(y, overlay_map.profiles[id].surface.height(point))
								if geometry.has("marker_surface"):
									y = maxf(y, geometry.marker_surface.height(point))
								if offset.is_valid():
									y += maxf(0.0, float(offset.call((point - centre).rotated(yaw), y)))
								face.append(Vector3(point.x, y, point.y))
							var normal := (face[2] - face[0]).cross(face[1] - face[0])
							if normal.length_squared() < 0.00000001:
								continue
							if not surface.cells.has(cell):
								surface.cells[cell] = []
							surface.cells[cell].append(vertices.size())
							vertices.append_array(face)
							normal = normal.normalized()
							normals.append_array([normal, normal, normal])
	surface.vertices = vertices
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var colors := PackedColorArray()
	colors.resize(vertices.size())
	colors.fill(Palette.SANDSTONE)
	arrays[Mesh.ARRAY_COLOR] = colors
	var indices := PackedInt32Array()
	for k in vertices.size():
		indices.append(k)
	arrays[Mesh.ARRAY_INDEX] = indices
	surface.mesh = ArrayMesh.new()
	if not vertices.is_empty():
		surface.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return surface


static func _clip_edge(polygon: Array, a: Vector2, b: Vector2) -> Array:
	var clipped := []
	if polygon.is_empty():
		return clipped
	var previous: Vector2 = polygon[-1]
	var previous_distance := (b - a).cross(previous - a)
	for point: Vector2 in polygon:
		var distance := (b - a).cross(point - a)
		if (distance >= 0.0) != (previous_distance >= 0.0):
			clipped.append(previous.lerp(point, previous_distance / (previous_distance - distance)))
		if distance >= 0.0:
			clipped.append(point)
		previous = point
		previous_distance = distance
	return clipped


static func _water_ground(world, point: Vector2) -> float:
	var ground: float = world.terrain.height(point.x, point.y)
	if world.terrain.has_method("_floor"):
		ground = world.terrain._floor(world.terrain._ensure(world.terrain.stage), point.x, point.y)
	# Lower shared seam vertices to either hole floor, so neither adjoining cell exceeds the cap.
	if "_holes" in world.terrain:
		var terrain = world.terrain
		for delta in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2.ONE]:
			var probe: Vector2 = point + delta * ParkTerrain.STEP * 0.5
			var floor_y := ParkTerrain.hole_floor(terrain._holes[terrain.stage - 1], terrain._under[terrain.stage - 1], probe.x, probe.y)
			if not is_nan(floor_y):
				ground = minf(ground, floor_y)
	return ground


static func prepare_overlay(world, owner: Node, row: Dictionary, record: Dictionary, collapse_target := Callable()) -> OverlayMap:
	var id: String = str(row.effect.get("swap", row.id))
	if id == "":
		id = row.id
	var current = world.terrain.map()
	var overlay_map: OverlayMap = current if current is OverlayMap else null
	if overlay_map != null and overlay_map.swaps.has(id):
		record.overlay = overlay_map.swaps[id].body
		record.swap = id
		record.overlay_map = overlay_map
		return overlay_map
	if overlay_map == null:
		overlay_map = OverlayMap.new(current.path)
		for property in current.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
				overlay_map.set(property.name, current.get(property.name))
		overlay_map.source = current
		world.terrain.maps[world.terrain.stage - 1] = overlay_map
	var site: Dictionary = record.site
	var half: Vector2 = record.geometry.half
	var radius := minf(half.x, half.y)
	var at: Vector3 = record.at
	var yaw: float = record.geometry.yaw
	var terrain = world.terrain
	var kind: String = row.kind
	# Collider vertices and terrain.height use this identical surface function.
	var height := func(x: float, z: float) -> float:
		var world_xz := Vector2(x, z).rotated(-yaw) + Vector2(at.x, at.z)
		var base: float = terrain.height(world_xz.x, world_xz.y)
		if kind == "impact":
			return base + maxf(0.0, Gorge.crater_profile(Vector2(x, z).length() * Gorge.CRATER_OUT / radius))
		return base + Gorge.rubble_profile(Vector2(x, z).length() * Gorge.RUBBLE_RADIUS / radius)
	var surface := project_surface(world, record.geometry, [_rectangle(-half, half)],
		Callable() if kind == "collapse" else func(local, base): return float(height.call(local.x, local.y)) - base)
	var body := StaticBody3D.new()
	body.name = "Natural_" + row.id
	var view := MeshInstance3D.new()
	view.mesh = surface.mesh
	view.material_override = Palette.ground_material()
	var collider := CollisionShape3D.new()
	collider.shape = surface.mesh.create_trimesh_shape()
	body.add_child(view)
	body.add_child(collider)
	owner.add_child(body)
	var before: Node3D = null
	if world.terrain.has_method("geometry_root"):
		before = world.terrain.geometry_root(world.terrain.stage).find_child("Park_" + str(row.site), true, false) as Node3D
	overlay_map.swaps[id] = {"body": body, "home": body.position, "before": before,
		"before_home": before.position if is_instance_valid(before) else Vector3.ZERO,
		"before_visible": before.visible if is_instance_valid(before) else false, "owners": {},
		"baseline": surface, "geometry": record.geometry, "progress": 0.0, "collapse": kind == "collapse"}
	if kind == "collapse":
		overlay_map.swaps[id].target = collapse_target.call(row, record.geometry, surface)
	overlay_map.profiles[id + "_after"] = {"site": site, "surface": surface}
	body.position += Vector3.DOWN * Gorge.SWAP_PARK
	body.visible = false
	record.overlay = body
	record.swap = id
	record.overlay_map = overlay_map
	return overlay_map


static func install_surface(overlay_map: OverlayMap, id: String, surface: Surface) -> void:
	var body: StaticBody3D = overlay_map.swaps[id].body
	body.get_child(0).mesh = surface.mesh
	body.get_child(1).shape = surface.mesh.create_trimesh_shape()
	overlay_map.profiles[id + "_after"].surface = surface


static func set_overlay(world, row: Dictionary, record: Dictionary, changed: bool) -> void:
	var overlay_map: OverlayMap = record.overlay_map
	var id: String = record.swap
	var entry: Dictionary = overlay_map.swaps[id]
	var overlays = world.terrain.overlays
	if changed:
		if entry.owners.has(row.id):
			return
		if entry.owners.is_empty():
			entry.before_index = overlays.find(id + "_before")
			entry.had_after = overlays.has(id + "_after")
			if is_instance_valid(entry.before):
				entry.before_home = entry.before.position
				entry.before_visible = entry.before.visible
			overlay_map.apply_swap(id, true)
			overlays.erase(id + "_before")
			if not entry.had_after:
				overlays.append(id + "_after")
		entry.owners[row.id] = true
	else:
		if not entry.owners.has(row.id):
			return
		entry.owners.erase(row.id)
		if not entry.owners.is_empty():
			return
		overlay_map.apply_swap(id, false)
		entry.progress = 0.0
		if entry.get("collapse", false):
			install_surface(overlay_map, id, entry.baseline)
		if not entry.had_after:
			overlays.erase(id + "_after")
		if entry.before_index >= 0 and not overlays.has(id + "_before"):
			overlays.insert(mini(entry.before_index, overlays.size()), id + "_before")


static func restore_map(world, overlay_map: OverlayMap) -> void:
	if overlay_map == null or world.terrain.map() != overlay_map:
		return
	for entry in overlay_map.swaps.values():
		if not entry.owners.is_empty():
			return
	world.terrain.maps[world.terrain.stage - 1] = overlay_map.source

