extends RefCounted

const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Gorge := preload("res://src/world/map_gorge.gd")


class Surface:
	extends RefCounted
	var mesh: ArrayMesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var cells := {}
	var arrays := []
	func finish() -> Surface:
		if mesh == null:
			mesh = ArrayMesh.new()
		if not arrays.is_empty() and not vertices.is_empty():
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		arrays = []
		return self
	func copy() -> Surface:
		var out := Surface.new()
		out.vertices = vertices.duplicate()
		out.normals = normals.duplicate()
		out.cells = cells.duplicate(true)
		return out
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
	var surface_moved := Callable()
	func moved() -> void:
		if surface_moved.is_valid():
			surface_moved.call()
	func apply_swap(id: String, changed: bool) -> void:
		if not swaps.has(id):
			return
		var entry: Dictionary = swaps[id]
		entry.body.position = entry.home if changed else entry.home + Vector3.DOWN * Gorge.SWAP_PARK
		entry.body.visible = changed
		if is_instance_valid(entry.before):
			entry.before.position = entry.before_home + Vector3.DOWN * Gorge.SWAP_PARK if changed else entry.before_home
			entry.before.visible = false if changed else entry.before_visible
		for hidden in entry.get("hidden", []):
			if is_instance_valid(hidden.node):
				hidden.node.position = hidden.home + Vector3.DOWN * Gorge.SWAP_PARK if changed else hidden.home
				hidden.node.visible = false if changed else hidden.visible
		moved()
	func cave_height(x: float, z: float) -> float:
		for entry in swaps.values():
			if entry.get("cave", false):
				var y: float = entry.roof.surface.height(Vector2(x, z))
				if y > -INF:
					return y
		return -INF
	func overlay_height(id: String, x: float, z: float, ground: float) -> float:
		if not profiles.has(id):
			return source.overlay_height(id, x, z, ground)
		var p: Dictionary = profiles[id]
		if not ParkMap.footprint_contains(p.site, Vector2(x, z)):
			return -INF
		return p.surface.height(Vector2(x, z))


class Ground:
	extends RefCounted
	var stage := 1
	var overlays: Array[String] = []
	var _heights: Array = []
	var _holes: Array = []
	var _under: Array = []
	var _roofs: Array = []
	var _profiles: Array = []
	var _terrain: Script
	func map() -> RefCounted:
		return null
	func height(x: float, z: float) -> float:
		var h := _floor(0, x, z)
		for profile: Dictionary in _profiles:
			if ParkMap.footprint_contains(profile.site, Vector2(x, z)):
				h = maxf(h, profile.surface.height(Vector2(x, z)))
		return h
	func floor_height(x: float, z: float) -> float:
		return _floor(0, x, z)
	func bare_grid_height(x: float, z: float) -> float:
		return _terrain.grid_height(_heights[0], x, z)
	func hole_floor(x: float, z: float) -> float:
		return ParkTerrain.hole_floor(_holes[0], _under[0], x, z)
	func copy_roofs() -> void:
		_roofs = _roofs.map(func(roof: Surface) -> Surface: return roof.copy())
	func with_profile(profile: Dictionary) -> Ground:
		var ground := Ground.new()
		ground._heights = _heights
		ground._holes = _holes
		ground._under = _under
		ground._roofs = _roofs
		ground._profiles = _profiles + [profile]
		ground._terrain = _terrain
		return ground
	func _floor(_i: int, x: float, z: float) -> float:
		var roof_y := -INF
		for roof: Surface in _roofs:
			roof_y = maxf(roof_y, roof.height(Vector2(x, z)))
		if roof_y > -INF:
			return maxf(roof_y, _terrain.retained_park_height(_heights[0], _holes[0], x, z))
		return _terrain.park_height(_heights[0], _holes[0], _under[0], x, z)


class Snapshot:
	extends RefCounted
	var terrain: Ground
	var _copied := true
	func copy_roofs() -> void:
		if _copied:
			return
		terrain.copy_roofs()
		_copied = true
	func with_profile(profile: Dictionary) -> Snapshot:
		var out := Snapshot.new()
		out.terrain = terrain.with_profile(profile)
		out._copied = _copied
		return out


static func snapshot(terrain, index: int, copy_now := true) -> Snapshot:
	var grid: Dictionary = terrain.park_stage_grid(index)
	var ground := Ground.new()
	ground._heights = [grid.get("heights", PackedFloat32Array())]
	ground._holes = [grid.get("holes", PackedByteArray())]
	ground._under = [grid.get("under", PackedFloat32Array())]
	for roof in terrain.cave_roofs(index).values():
		ground._roofs.append(roof.surface.copy() if copy_now else roof.surface)
	ground._terrain = terrain.get_script()
	var out := Snapshot.new()
	out.terrain = ground
	out._copied = copy_now
	return out


static func pristine(terrain, index: int) -> bool:
	for roof in terrain.cave_roofs(index).values():
		if roof.surface != roof.baseline:
			return false
	return true


static func rectangle(low: Vector2, high: Vector2) -> Array:
	return [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]


static func project_surface(world, geometry: Dictionary, shapes: Array, offset := Callable(), water := false, baseline: Surface = null, overlay_map: OverlayMap = null, mesh: ArrayMesh = null, deferred := false) -> Surface:
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
		var corners := {}
		var grounds := {}
		var markers := {}
		var marker: Surface = geometry.get("marker_surface")
		var span: bool = geometry.get("span", false)
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
					var triangles := [[a, b, c], [b, d, c]]
					var clips := []
					for triangle in triangles:
						var clipped: Array = polygon
						for edge in 3:
							clipped = _clip_edge(clipped, triangle[edge], triangle[(edge + 1) % 3])
						clips.append(clipped)
					if clips[0].size() < 3 and clips[1].size() < 3:
						continue
					var heights := PackedFloat64Array()
					if baseline == null:
						for point in [a, b, c, d]:
							if not corners.has(point):
								var y: float = _water_ground(world, point) if water else world.terrain.height(point.x, point.y)
								if not water and world.terrain.has_method("bare_grid_height"):
									y = maxf(y, world.terrain.bare_grid_height(point.x, point.y))
								corners[point] = y
							heights.append(corners[point])
						if water and world.terrain.has_method("hole_floor"):
							var floor_y: float = world.terrain.hole_floor(a.x + ParkTerrain.STEP * 0.5, a.y + ParkTerrain.STEP * 0.5)
							if not is_nan(floor_y):
								for k in 4:
									heights[k] = minf(heights[k], floor_y)
					for t in 2:
						var triangle: Array = triangles[t]
						var clipped: Array = clips[t]
						for k in range(1, clipped.size() - 1):
							var face := PackedVector3Array()
							for point: Vector2 in [clipped[0], clipped[k], clipped[k + 1]]:
								var y: float
								if baseline != null:
									if not grounds.has(point):
										grounds[point] = baseline.height(point)
									y = grounds[point]
								else:
									var f := (point - a) / ParkTerrain.STEP
									y = heights[0] + (heights[1] - heights[0]) * f.x + (heights[2] - heights[0]) * f.y if triangle[0] == a else heights[3] + (heights[2] - heights[3]) * (1.0 - f.x) + (heights[1] - heights[3]) * (1.0 - f.y)
									if not water:
										if not grounds.has(point):
											var ground: float = world.terrain.height(point.x, point.y)
											if overlay_map != null:
												for id in world.terrain.overlays:
													if overlay_map.profiles.has(id):
														ground = maxf(ground, overlay_map.profiles[id].surface.height(point))
											grounds[point] = ground
										y = maxf(y, grounds[point])
								if marker != null:
									if not markers.has(point):
										markers[point] = marker.height(point)
									y = markers[point] if span else maxf(y, markers[point])
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
	return mesh_surface(surface, normals, mesh, deferred)


static func mesh_surface(surface: Surface, normals: PackedVector3Array, mesh: ArrayMesh = null, deferred := false) -> Surface:
	var vertices := surface.vertices
	surface.normals = normals
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
	surface.arrays = arrays
	surface.mesh = mesh
	return surface if deferred else surface.finish()


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
	var ground: float = world.terrain.floor_height(point.x, point.y) if world.terrain.has_method("floor_height") else world.terrain.height(point.x, point.y)
	if world.terrain.has_method("hole_floor"):
		for delta in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2.ONE]:
			var probe: Vector2 = point + delta * ParkTerrain.STEP * 0.5
			var floor_y: float = world.terrain.hole_floor(probe.x, probe.y)
			if not is_nan(floor_y):
				ground = minf(ground, floor_y)
	return ground


static func cave_roof(heights: PackedFloat32Array, holes: PackedByteArray, site: Dictionary, owner: Node) -> Dictionary:
	var surface := Surface.new()
	var retained := {}
	var normals := PackedVector3Array()
	var half := ParkMap.footprint_half_extents(site).length() + ParkTerrain.STEP
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var low := Vector2i((centre - Vector2.ONE * half + Vector2.ONE * ParkTerrain.HALF) / ParkTerrain.STEP)
	var high := Vector2i((centre + Vector2.ONE * half + Vector2.ONE * ParkTerrain.HALF) / ParkTerrain.STEP)
	for j in range(low.y, high.y + 1):
		for i in range(low.x, high.x + 1):
			var at := Vector2(i, j) * ParkTerrain.STEP - Vector2.ONE * ParkTerrain.HALF
			if holes[j * ParkTerrain.CELLS + i] != 1 or not ParkMap.footprint_contains(site, at + Vector2.ONE * ParkTerrain.STEP * 0.5):
				continue
			var k := j * ParkTerrain.SIDE + i
			var a := Vector3(at.x, heights[k], at.y)
			var b := Vector3(at.x + ParkTerrain.STEP, heights[k + 1], at.y)
			var c := Vector3(at.x, heights[k + ParkTerrain.SIDE], at.y + ParkTerrain.STEP)
			var d := Vector3(b.x, heights[k + ParkTerrain.SIDE + 1], c.z)
			surface.cells[Vector2i(floori(at.x / ParkTerrain.STEP), floori(at.y / ParkTerrain.STEP))] = [surface.vertices.size(), surface.vertices.size() + 3]
			for face in [[a, b, c], [b, d, c]]:
				surface.vertices.append_array(PackedVector3Array(face))
				var normal: Vector3 = (face[2] - face[0]).cross(face[1] - face[0]).normalized()
				normals.append_array([normal, normal, normal])
			for delta in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
				var cell: Vector2i = Vector2i(i, j) + delta
				if cell.x < 0 or cell.y < 0 or cell.x >= ParkTerrain.CELLS or cell.y >= ParkTerrain.CELLS:
					continue
				if holes[cell.y * ParkTerrain.CELLS + cell.x] == 0:
					retained[cell] = true
	var roof := roof_body(owner, mesh_surface(surface, normals), false)
	for k in range(0, surface.vertices.size(), 6):
		roof.body.add_child(_roof_cell_collider(surface.vertices.slice(k, k + 6)))
	for cell: Vector2i in retained:
		var at := Vector2(cell) * ParkTerrain.STEP - Vector2.ONE * ParkTerrain.HALF
		var k := cell.y * ParkTerrain.SIDE + cell.x
		var a := Vector3(at.x, heights[k], at.y)
		var b := Vector3(at.x + ParkTerrain.STEP, heights[k + 1], at.y)
		var c := Vector3(at.x, heights[k + ParkTerrain.SIDE], at.y + ParkTerrain.STEP)
		var d := Vector3(b.x, heights[k + ParkTerrain.SIDE + 1], c.z)
		var collider := _roof_cell_collider(PackedVector3Array([a, b, c, b, d, c]))
		collider.set_meta("retained", true)
		roof.body.add_child(collider)
	return roof


static func _roof_cell_collider(faces: PackedVector3Array) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	var origin := faces[0]
	# Cell-local meshes keep Jolt's compressed vertices aligned on shared grid edges.
	var local := PackedVector3Array()
	for vertex in faces:
		local.append(vertex - origin)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(local)
	collider.shape = shape
	collider.position = origin
	collider.set_meta("home", origin)
	return collider


static func roof_body(owner: Node, surface: Surface, single_collider := true) -> Dictionary:
	var body := StaticBody3D.new()
	var view := MeshInstance3D.new()
	view.mesh = surface.mesh
	view.material_override = Palette.ground_material()
	body.add_child(view)
	if single_collider:
		var collider := CollisionShape3D.new()
		collider.shape = trimesh(surface)
		body.add_child(collider)
	owner.add_child(body)
	return {"body": body, "baseline": surface, "surface": surface}


const TRIMESH_SNAP := Vector3(0.0001, 0.0001, 0.0001)

# Mesh.create_trimesh_shape() stalls real GPUs waiting on in-flight frames; build ConcavePolygonShape3D with Godot's 0.1 mm trimesh snap instead.
static func trimesh(surface: Surface) -> ConcavePolygonShape3D:
	if surface.vertices.is_empty():
		return null
	var faces := PackedVector3Array()
	faces.resize(surface.vertices.size())
	for k in surface.vertices.size():
		faces[k] = surface.vertices[k].snapped(TRIMESH_SNAP)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


static func lower_roof(roof: Dictionary, drop: float) -> void:
	var surface := Surface.new()
	surface.cells = roof.baseline.cells
	var normals: PackedVector3Array = roof.baseline.normals
	for vertex: Vector3 in roof.baseline.vertices:
		surface.vertices.append(vertex + Vector3.DOWN * drop)
	roof.surface = mesh_surface(surface, normals)
	roof.body.get_child(0).mesh = surface.mesh
	for collider in roof.body.get_children():
		if collider is CollisionShape3D:
			if collider.has_meta("home"):
				collider.position = collider.get_meta("home") + (Vector3.ZERO if collider.has_meta("retained") else Vector3.DOWN * drop)
			else:
				collider.shape = trimesh(surface)
	var moved: Callable = roof.get("moved", Callable())
	if moved.is_valid():
		moved.call()


static func hidden_rows(world, event_id: String) -> Array:
	var out := []
	var park = world.terrain.map().get("park")
	if not park is Dictionary or not world.terrain.has_method("geometry_root"):
		return out
	var root: Node = world.terrain.geometry_root(world.terrain.stage)
	for park_row in park.get("park_rows", []):
		if String(park_row.get("hide_on", "")) != event_id:
			continue
		var node := root.find_child("Park_" + str(park_row.id), true, false) as Node3D
		if node != null:
			out.append({"node": node, "home": node.position, "visible": node.visible})
	return out


static func _share_hidden(entry: Dictionary, found: Array, id: String) -> void:
	if not entry.has("hidden") or found.is_empty():
		return
	if not entry.owners.is_empty():
		push_warning("event_ground: swap %s is live, so its new hide_on rows are skipped" % id)
		return
	for item in found:
		if not entry.hidden.any(func(have): return have.node == item.node):
			entry.hidden.append(item)


static func prepare_overlay(world, owner: Node, row: Dictionary, record: Dictionary, collapse_target := Callable(), prepared := {}) -> OverlayMap:
	var id: String = str(row.effect.get("swap", row.id))
	if id == "":
		id = row.id
	var current = world.terrain.map()
	var overlay_map: OverlayMap = current if current is OverlayMap else null
	if overlay_map != null and overlay_map.swaps.has(id):
		_share_hidden(overlay_map.swaps[id], hidden_rows(world, str(row.id)), id)
		record.overlay = overlay_map.swaps[id].body
		record.swap = id
		record.overlay_map = overlay_map
		return overlay_map
	if overlay_map == null:
		overlay_map = OverlayMap.new("")
		for property in current.get_property_list():
			if int(property.usage) & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE) and property.name != "script":
				var value = current.get(property.name)
				overlay_map.set(property.name, value.duplicate(true) if value is Dictionary or value is Array else value)
		overlay_map.source = current
		if world.terrain.has_method("surface_moved"):
			overlay_map.surface_moved = world.terrain.surface_moved
		world.terrain.maps[world.terrain.stage - 1] = overlay_map
	if row.kind == "cave_in":
		var roof: Dictionary = world.terrain.cave_roof(row.id) if world.terrain.has_method("cave_roof") else {}
		if roof.is_empty():
			roof = roof_body(owner, project_surface(world, record.geometry, [rectangle(-record.geometry.half, record.geometry.half)]))
		roof.body.name = "Natural_" + row.id
		roof["moved"] = overlay_map.moved
		overlay_map.swaps[id] = {"body": roof.body, "roof": roof, "cave": true, "owners": {}, "progress": 0.0}
		record.overlay = roof.body
		record.swap = id
		record.overlay_map = overlay_map
		return overlay_map
	var geometry: Dictionary = record.geometry
	var site: Dictionary = record.site
	if kind_of_span(row):
		site = span_site(current.park, record.site)
		geometry = record.geometry.duplicate()
		geometry.site = site
		geometry.at = Vector3(float(site.at[0]), float(site.y), float(site.at[1]))
		geometry.span = true
		record.geometry = geometry
		record.at = geometry.at
	var kind: String = row.kind
	var surface: Surface
	if geometry.get("span", false):
		surface = prepared.span if prepared.has("span") else span_surface(site, 0.0)
		geometry.marker_surface = surface
	elif prepared.has("surface"):
		surface = prepared.surface
	else:
		surface = overlay_surface(world, kind, geometry)
	var body := StaticBody3D.new()
	body.name = "Natural_" + row.id
	var view := MeshInstance3D.new()
	view.mesh = surface.mesh
	view.material_override = Palette.ground_material()
	var collider := CollisionShape3D.new()
	collider.shape = prepared.get("shape", null) if prepared.has("shape") else trimesh(surface)
	if not prepared.is_empty():
		prepared["shape"] = collider.shape
	body.add_child(view)
	body.add_child(collider)
	owner.add_child(body)
	var before: Node3D = null
	if world.terrain.has_method("geometry_root"):
		before = world.terrain.geometry_root(world.terrain.stage).find_child("Park_" + str(site.id), true, false) as Node3D
	overlay_map.swaps[id] = {"body": body, "home": body.position, "before": before,
		"before_home": before.position if is_instance_valid(before) else Vector3.ZERO,
		"before_visible": before.visible if is_instance_valid(before) else false, "owners": {},
		"hidden": hidden_rows(world, str(row.id)),
		"baseline": surface, "geometry": geometry, "progress": 0.0, "collapse": kind == "collapse"}
	if kind == "collapse":
		overlay_map.swaps[id].target = prepared.target if prepared.has("target") else collapse_target.call(row, geometry, surface)
	overlay_map.profiles[id + "_after"] = {"site": site, "surface": surface}
	body.position += Vector3.DOWN * Gorge.SWAP_PARK
	body.visible = false
	record.overlay = body
	record.swap = id
	record.overlay_map = overlay_map
	return overlay_map


static func overlay_surface(world, kind: String, geometry: Dictionary, deferred := false) -> Surface:
	var half: Vector2 = geometry.half
	var radius := minf(half.x, half.y)
	var at: Vector3 = geometry.at
	var yaw: float = geometry.yaw
	var terrain = world.terrain
	var height := func(x: float, z: float) -> float:
		var world_xz := Vector2(x, z).rotated(-yaw) + Vector2(at.x, at.z)
		var base: float = terrain.height(world_xz.x, world_xz.y)
		if kind == "impact":
			return base + maxf(0.0, Gorge.crater_profile(Vector2(x, z).length() * Gorge.CRATER_OUT / radius))
		return base + Gorge.rubble_profile(Vector2(x, z).length() * Gorge.RUBBLE_RADIUS / radius)
	return project_surface(world, geometry, [rectangle(-half, half)],
		Callable() if kind == "collapse" else func(local, base): return float(height.call(local.x, local.y)) - base,
		false, null, null, null, deferred)


static func plan_overlays(world, items: Array) -> Dictionary:
	var terrain = world.terrain
	if items.is_empty() or not terrain.has_method("park_stage_grid") or not terrain.overlays.is_empty():
		return {}
	var stage: int = terrain.stage
	if terrain.park_stage_grid(stage).is_empty():
		return {}
	var ground := snapshot(terrain, stage, false)
	var out := {}
	var work := func() -> void:
		for item: Dictionary in items:
			out[item.id] = overlay_surface(ground, item.kind, item.geometry, true)
	var reach := {}
	for item: Dictionary in items:
		reach[item.id] = _rect_bounds(item.geometry.at, item.geometry.half, item.geometry.yaw)
	return {"task": WorkerThreadPool.add_task(work, true, "event overlays"), "out": out, "stage": stage,
		"roofs": terrain.cave_roofs(stage).values().map(func(roof): return roof.surface), "reach": reach}


static func planned_overlay(world, plan: Dictionary, id: String) -> Dictionary:
	var terrain = world.terrain
	if plan.is_empty() or terrain.stage != plan.stage or not plan.get("reach", {}).has(id) or _overlay_under(world, plan.reach[id]):
		return {}
	if terrain.cave_roofs(plan.stage).values().map(func(roof): return roof.surface) != plan.roofs:
		return {}
	settle_overlays(plan)
	if not plan.out.has(id):
		return {}
	var surface: Surface = plan.out[id]
	if surface.mesh == null:
		surface.finish()
	return {"surface": surface}


static func _overlay_under(world, reach: Rect2) -> bool:
	var m = world.terrain.map()
	for overlay: String in world.terrain.overlays:
		var p: Dictionary = m.profiles.get(overlay, {}) if m is OverlayMap else {}
		if p.is_empty():
			return true
		var site: Dictionary = p.site
		var bounds := _rect_bounds(Vector3(float(site.at[0]), 0.0, float(site.at[1])), ParkMap.footprint_half_extents(site),
			deg_to_rad(float(site.yaw_deg)))
		if bounds.grow(2.0 * ParkTerrain.STEP).intersects(reach, true):
			return true
	return false


static func _rect_bounds(at: Vector3, half: Vector2, yaw: float) -> Rect2:
	var centre := Vector2(at.x, at.z)
	var bounds := Rect2(centre, Vector2.ZERO)
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		bounds = bounds.expand(corner.rotated(-yaw) + centre)
	return bounds


static func settle_overlays(plan: Dictionary) -> void:
	if plan.get("task", -1) >= 0:
		WorkerThreadPool.wait_for_task_completion(plan.task)
		plan.task = -1


static func install_surface(overlay_map: OverlayMap, id: String, surface: Surface) -> void:
	var body: StaticBody3D = overlay_map.swaps[id].body
	body.get_child(0).mesh = surface.mesh
	body.get_child(1).shape = trimesh(surface)
	overlay_map.profiles[id + "_after"].surface = surface
	overlay_map.moved()


static func set_overlay(world, row: Dictionary, record: Dictionary, changed: bool) -> void:
	var overlay_map: OverlayMap = record.overlay_map
	var id: String = record.swap
	var entry: Dictionary = overlay_map.swaps[id]
	if entry.get("cave", false):
		if changed:
			entry.owners[row.id] = true
		else:
			entry.owners.erase(row.id)
		return
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
			for hidden in entry.get("hidden", []):
				if is_instance_valid(hidden.node):
					hidden.home = hidden.node.position
					hidden.visible = hidden.node.visible
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


static func kind_of_span(row: Dictionary) -> bool:
	return row.kind == "collapse" and row.effect.get("swap", "") == "trestle_ramp"


static func span_site(park: Dictionary, event_site: Dictionary) -> Dictionary:
	var span: Dictionary = park.park_rows.filter(func(r): return r.id == "flume_hollow_reach")[0]
	var site := event_site.duplicate(true)
	site.id = span.id
	site.y = float(span.y) + float(span.size[1])
	return site


static func span_surface(site: Dictionary, depth_m: float, deferred := false) -> Surface:
	var surface := Surface.new()
	var half := ParkMap.footprint_half_extents(site)
	var centre := Vector2(float(site.at[0]), float(site.at[1]))
	var yaw := deg_to_rad(float(site.yaw_deg))
	var corners := PackedVector3Array()
	var low := Vector2.INF
	var high := -Vector2.INF
	for local: Vector2 in rectangle(-half, half):
		var point := local.rotated(-yaw) + centre
		corners.append(Vector3(point.x, float(site.y) - depth_m * (local.y + half.y) / (2.0 * half.y), point.y))
		low = low.min(point)
		high = high.max(point)
	var normals := PackedVector3Array()
	for face in [[0, 1, 3], [1, 2, 3]]:
		var a := corners[face[0]]
		var b := corners[face[1]]
		var c := corners[face[2]]
		surface.vertices.append_array(PackedVector3Array([a, b, c]))
		var normal := (c - a).cross(b - a).normalized()
		normals.append_array([normal, normal, normal])
	for j in range(floori(low.y / ParkTerrain.STEP), floori(high.y / ParkTerrain.STEP) + 1):
		for i in range(floori(low.x / ParkTerrain.STEP), floori(high.x / ParkTerrain.STEP) + 1):
			surface.cells[Vector2i(i, j)] = [0, 3]
	return mesh_surface(surface, normals, null, deferred)
