extends Node3D

const Kinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Flood := preload("res://src/world/flood.gd")
const FloodCycle := preload("res://src/world/flood_cycle.gd")
const Gorge := preload("res://src/world/map_gorge.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Bank := preload("res://src/presentation/sfx_bank.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")

const KINDS := {
	"flood_fill": {}, "drain": {}, "cave_in": {}, "collapse": {}, "flash_flood": {},
	"impact": {"lift_mps": 8.0}, "lightning": {"lift_mps": 8.0},
}

var world
var active := {}
var _sites := {}
var _prepared := {}
var _original_map
var _overlay_map
var _water_field := WaterField.new()
var _original_flood
var _audio
var _world_sound := Callable()


class WaterClock:
	extends FloodCycle
	var metres := 0.0
	func depth(_full: float) -> float:
		return metres
	func klaxon() -> bool:
		return false


class WaterView:
	extends Flood
	var site := {}
	var geometry := {}
	var surface: WaterSurface
	var query_xz := Vector2.ZERO
	func in_basin(point: Vector3) -> bool:
		query_xz = Vector2(point.x, point.z)
		return visible and ParkMap.footprint_contains(geometry.site, query_xz, 0.0, Vector2.INF, geometry.half)
	func surface_y() -> float:
		return surface.height(query_xz) + cycle.metres
	func render() -> void:
		_plane.position = Vector3.UP * cycle.metres
	func external_accel(_point: Vector3, _velocity: Vector3) -> Vector3:
		return Vector3.ZERO


class WaterSurface:
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


# Terrain's material queries use the same surfaces the Flood nodes draw.
class WaterField:
	extends RefCounted
	var surfaces: Array = []
	var _surface_y := -INF
	func refresh() -> void:
		var top := {}
		for water in surfaces:
			water.visible = false
			top[water.site.id] = water
		for water in top.values():
			water.visible = true
			water.render()
	func in_basin(point: Vector3) -> bool:
		_surface_y = -INF
		for water in surfaces:
			if water.in_basin(point):
				_surface_y = maxf(_surface_y, water.surface_y())
		return _surface_y > -INF
	func surface_y() -> float:
		return _surface_y


# The existing terrain overlay API, with finished colliders parked between swaps.
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
		var local := (Vector2(x, z) - Vector2(float(p.site.at[0]), float(p.site.at[1]))).rotated(deg_to_rad(float(p.site.yaw_deg)))
		return float(p.height.call(local.x, local.y))


func setup(world_ref) -> void:
	world = world_ref
	name = "NaturalEvents"
	_original_map = world.terrain.map()
	_original_flood = world.terrain.flood
	for site in _original_map.park.park_rows:
		_sites[site.id] = site
	for row in _original_map.park.event_rows:
		if row.family != "natural" or not KINDS.has(row.kind):
			continue
		var site: Dictionary = _sites[row.site]
		var at := _at(site)
		var geometry := {"site": site, "at": at, "half": ParkMap.footprint_half_extents(site),
			"yaw": deg_to_rad(float(site.yaw_deg)), "strike_m": maxf(0.0, float(row.effect.get("strike_m", 0.0)))}
		if row.kind == "lightning":
			geometry.half = Vector2.ONE * geometry.strike_m
			geometry.yaw = 0.0
		var record := {"site": site, "at": at, "geometry": geometry, "overlay": null}
		if row.kind in ["flood_fill", "drain", "flash_flood"]:
			record.water_surface = _prepare_water(geometry)
		if row.kind in ["cave_in", "collapse", "impact"]:
			_prepare_overlay(row, record)
		_prepared[row.id] = record
	world.terrain.flood = _water_field
	# Replace the generic world's sound listener for this stage, preserving its other cues.
	var presentation = world.ctx.root.get("presentation")
	if presentation != null:
		_audio = presentation.audio
		for connection in world.ctx.events.get_signal_connection_list("world_fact"):
			if connection.callable.get_object() == _audio:
				_world_sound = connection.callable
				world.ctx.events.world_fact.disconnect(_world_sound)
				world.ctx.events.world_fact.connect(_on_world_sound)
				break


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	if not KINDS.has(row.kind):
		return
	match action:
		"telegraph":
			var state: Dictionary = _prepared[row.id].duplicate()
			state.merge({"phase": "telegraph", "hit": false, "elapsed_s": 0.0, "depth_m": 0.0,
				"water": null, "mark": _mark(row, state.geometry), "announced_s": ctx.clock_s}, true)
			active[row.id] = state
		"land":
			var state: Dictionary = active[row.id]
			state.phase = "land"
			if row.kind in ["flood_fill", "drain", "flash_flood"]:
				_land_water(row, state)
			if state.overlay != null:
				_set_overlay(row, true)
			_show_landing(row, state)
			_hazard(row, state, ctx)
		"step":
			var state: Dictionary = active[row.id]
			state.phase = "live"
			state.elapsed_s += float(ctx.delta_s)
			if state.water != null:
				var fill_s := maxf(0.0, float(row.effect.get("fill_s", 0.0)))
				var elapsed: float = state.elapsed_s if row.kind == "drain" else float(ctx.rise_s) + float(ctx.delta_s)
				var fraction := clampf(elapsed / fill_s, 0.0, 1.0) if fill_s > 0.0 else 1.0
				var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
				state.depth_m = lerpf(float(state.start_depth_m), 0.0 if row.kind == "drain" else depth, fraction)
				state.water.cycle.metres = state.depth_m
				state.water.render()
			_hazard(row, state, ctx)
		"end":
			_end(row)


func _process(_delta: float) -> void:
	for state in active.values():
		if state.phase != "telegraph" or not state.mark.has_node("DustCurtain"):
			continue
		var row: Dictionary = _original_map.park.event_rows.filter(func(r): return r.id == state.mark.get_meta("row_id"))[0]
		var progress := clampf((world.events.stage_time - float(state.announced_s)) / float(row.telegraph.lead_s), 0.001, 1.0)
		if int(progress * 30.0) == int(float(state.get("warning_progress", -1.0)) * 30.0):
			continue
		state.warning_progress = progress
		var spec: Dictionary = Kinds.world_row(row.telegraph.form)
		var half: Vector2 = state.geometry.half
		var dust = state.mark.get_node("DustCurtain")
		dust.mesh = _project_surface(state.geometry,
			[_rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)],
			func(local, _base): return float(spec.dust_height_m) * progress * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)).mesh
		var crack = state.mark.get_node("CrawlingCrack")
		crack.mesh = _project_surface(state.geometry,
			[_rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), Vector2(half.x, lerpf(-half.y, half.y, progress)))]).mesh


func _at(site: Dictionary) -> Vector3:
	var x := float(site.at[0])
	var z := float(site.at[1])
	return Vector3(x, float(site.y) if site.y != null else world.terrain.height(x, z), z)


func _land_water(row: Dictionary, state: Dictionary) -> void:
	var water := WaterView.new()
	add_child(water)
	water.setup()
	water.site = state.site
	water.geometry = state.geometry
	water.cycle = WaterClock.new()
	var depth := minf(ParkSchema.MAX_EVENT_WATER_M, maxf(0.0, float(row.effect.get("depth_m", 0.0))))
	state.start_depth_m = depth if row.kind == "drain" else 0.0
	for existing in _water_field.surfaces:
		if existing.site.id == state.site.id and existing.visible:
			state.start_depth_m = existing.cycle.metres
	state.depth_m = state.start_depth_m
	water.cycle.metres = state.depth_m
	var half: Vector2 = state.geometry.half
	var centre := Vector2(state.at.x, state.at.z)
	water.configure({"centre": centre, "radius": half.length(), "plane_centre": centre,
		"plane_size": half * 2.0, "depth": depth}, state.at.y, state.at)
	water.surface = state.water_surface
	water.query_xz = centre
	water._plane.mesh = water.surface.mesh
	water._mast.visible = false
	water._lamp_mesh.visible = false
	water.render()
	state.water = water
	_water_field.surfaces.append(water)
	_water_field.refresh()


func _rectangle(low: Vector2, high: Vector2) -> Array:
	return [low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)]


func _prepare_water(geometry: Dictionary) -> WaterSurface:
	return _project_surface(geometry, [_rectangle(-geometry.half, geometry.half)], Callable(), true)


# Clip each shape to the terrain's actual 2 m triangles before projecting. The resulting
# triangles, including their interiors, share terrain.gd's b-c diagonal and interpolation.
func _project_surface(geometry: Dictionary, shapes: Array, offset := Callable(), water := false) -> WaterSurface:
	var surface := WaterSurface.new()
	var centre := Vector2(geometry.at.x, geometry.at.z)
	var yaw: float = geometry.yaw
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
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
					var y: float = _water_ground(point) if water else world.terrain.height(point.x, point.y)
					if not water and "_heights" in world.terrain:
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
							if not water:
								y = maxf(y, world.terrain.height(point.x, point.y))
								if _overlay_map != null:
									for id in world.terrain.overlays:
										if _overlay_map.profiles.has(id):
											y = maxf(y, _overlay_map.profiles[id].surface.height(point))
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


func _clip_edge(polygon: Array, a: Vector2, b: Vector2) -> Array:
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


func _water_ground(point: Vector2) -> float:
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


func _prepare_overlay(row: Dictionary, record: Dictionary) -> void:
	var id: String = str(row.effect.get("swap", row.id))
	if id == "":
		id = row.id
	if _overlay_map != null and _overlay_map.swaps.has(id):
		record.overlay = _overlay_map.swaps[id].body
		record.swap = id
		return
	if _overlay_map == null:
		_overlay_map = OverlayMap.new(_original_map.path)
		for property in _original_map.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
				_overlay_map.set(property.name, _original_map.get(property.name))
		_overlay_map.source = _original_map
		world.terrain.maps[world.terrain.stage - 1] = _overlay_map
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
		if kind == "collapse":
			return base + 2.0 * clampf((z + half.y) / (2.0 * half.y), 0.0, 1.0)
		return base + Gorge.rubble_profile(Vector2(x, z).length() * Gorge.RUBBLE_RADIUS / radius)
	var surface := _project_surface(record.geometry, [_rectangle(-half, half)],
		func(local, base): return float(height.call(local.x, local.y)) - base)
	var sampled := func(x: float, z: float) -> float:
		return surface.height(Vector2(x, z).rotated(-yaw) + Vector2(at.x, at.z))
	var body := StaticBody3D.new()
	body.name = "Natural_" + row.id
	var view := MeshInstance3D.new()
	view.mesh = surface.mesh
	view.material_override = Palette.ground_material()
	var collider := CollisionShape3D.new()
	collider.shape = surface.mesh.create_trimesh_shape()
	body.add_child(view)
	body.add_child(collider)
	add_child(body)
	var before: Node3D = null
	if world.terrain.has_method("geometry_root"):
		before = world.terrain.geometry_root(world.terrain.stage).find_child("Park_" + str(row.site), true, false) as Node3D
	_overlay_map.swaps[id] = {"body": body, "home": body.position, "before": before,
		"before_home": before.position if is_instance_valid(before) else Vector3.ZERO,
		"before_visible": before.visible if is_instance_valid(before) else false, "owners": {}}
	_overlay_map.profiles[id + "_after"] = {"site": site, "height": sampled, "surface": surface}
	body.position += Vector3.DOWN * Gorge.SWAP_PARK
	body.visible = false
	record.overlay = body
	record.swap = id


func _set_overlay(row: Dictionary, changed: bool) -> void:
	var id: String = _prepared[row.id].swap
	var entry: Dictionary = _overlay_map.swaps[id]
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
			_overlay_map.apply_swap(id, true)
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
		_overlay_map.apply_swap(id, false)
		if not entry.had_after:
			overlays.erase(id + "_after")
		if entry.before_index >= 0 and not overlays.has(id + "_before"):
			overlays.insert(mini(entry.before_index, overlays.size()), id + "_before")


func _hazard(row: Dictionary, state: Dictionary, ctx: Dictionary) -> void:
	if row.kind not in ["impact", "lightning"] or state.hit:
		return
	var radius: float = state.geometry.strike_m
	var at: Vector3 = state.geometry.at
	if Vector2(ctx.ball.x - at.x, ctx.ball.z - at.z).length() > radius or absf(ctx.ball.y - at.y) > radius:
		return
	state.hit = true
	var amount := maxi(0, ceili(float(row.effect.get("damage", 0.0))))
	var taken: int = world.ctx.run.lose_scrap(amount, ctx.ball, row.kind)
	if taken < amount or amount == 0:
		var velocity: Vector3 = world.ctx.player.state.velocity
		velocity.y = maxf(velocity.y, float(KINDS[row.kind].lift_mps))
		world.ctx.player.set_velocity_now(velocity, "natural_event")


func _mark(row: Dictionary, geometry: Dictionary, landed := false) -> Node3D:
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	add_child(mark)
	mark.position = Vector3.UP * 0.15
	var form: String = row.telegraph.form
	var spec: Dictionary = Kinds.world_row(world.events.PARK_LAND_FACTS[form] if landed else form)
	var half: Vector2 = geometry.half
	var mesh := MeshInstance3D.new()
	mesh.name = "Style"
	mesh.set_meta("shape", spec.shape)
	var shapes := []
	var offset := Callable()
	if spec.get("pattern", "") == "dust_crack":
		mesh.name = "DustCurtain"
		shapes = [_rectangle(Vector2(half.x - float(spec.crack_width_m), -half.y), half)]
		offset = func(local, _base): return float(spec.dust_height_m) * clampf((local.x - half.x + float(spec.crack_width_m)) / float(spec.crack_width_m), 0.0, 1.0)
		var crack := MeshInstance3D.new()
		crack.name = "CrawlingCrack"
		crack.mesh = _project_surface(geometry, shapes).mesh
		crack.material_override = Palette.unshaded(spec.color)
		mark.add_child(crack)
	elif spec.shape == "cross":
		shapes = [_rectangle(Vector2(-half.x, -0.15), Vector2(half.x, 0.15)),
			_rectangle(Vector2(-0.15, -half.y), Vector2(0.15, half.y))]
	elif spec.shape == "wave":
		shapes = [_rectangle(-half, half)]
		offset = func(local, _base): return 0.2 * (1.0 + sin((local.y / (half.y * 2.0) + 0.5) * TAU * 3.0))
	else:
		var segments := 32
		for k in segments:
			var a := Vector2(cos(TAU * k / segments), sin(TAU * k / segments)) * half
			var b := Vector2(cos(TAU * (k + 1) / segments), sin(TAU * (k + 1) / segments)) * half
			shapes.append([Vector2.ZERO, a, b] if spec.shape == "burst" else [a, b, b * 0.97, a * 0.97])
		if spec.shape == "burst":
			offset = func(local, _base): return 0.3 * maxf(0.0, 1.0 - (local / half).length_squared())
	mesh.mesh = _project_surface(geometry, shapes, offset).mesh
	mesh.material_override = Palette.unshaded(spec.color)
	mark.add_child(mesh)
	if row.kind != "lightning":
		var boundary := Node3D.new()
		boundary.name = "Footprint"
		mark.add_child(boundary)
		var outline := MeshInstance3D.new()
		outline.mesh = _footprint_mesh(geometry)
		outline.material_override = Palette.unshaded(spec.color)
		boundary.add_child(outline)
	return mark


func _footprint_mesh(geometry: Dictionary) -> ArrayMesh:
	var half: Vector2 = geometry.half
	var inset := (half - Vector2.ONE * 0.3).max(Vector2.ZERO)
	return _project_surface(geometry, [
		_rectangle(-half, Vector2(half.x, -inset.y)),
		_rectangle(Vector2(-half.x, inset.y), half),
		_rectangle(Vector2(-half.x, -inset.y), Vector2(-inset.x, inset.y)),
		_rectangle(Vector2(inset.x, -inset.y), Vector2(half.x, inset.y))]).mesh


func _show_landing(row: Dictionary, state: Dictionary) -> void:
	state.mark.free()
	state.mark = _mark(row, state.geometry, true)


func _on_world_sound(kind: String, at: Vector3) -> void:
	var cues: Dictionary = world.events.PARK_LAND_FACTS
	if not cues.has(kind) and not cues.values().has(kind):
		_world_sound.call(kind, at)
		return
	var entry: Dictionary = Kinds.world_row(kind)
	var sound := Rows.heard(entry, _audio.cue_context())
	var pitch := Harmony.ratio(_audio.live_key())
	if _audio._admit("world_fact", sound, pitch):
		_audio._start("world_fact", sound, Bank.stream(sound),
			Bank.trim_db(sound) + Audio.PRIORITY_DB[Rows.priority("world_fact")], pitch, "SFX")


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	var state: Dictionary = active[row.id]
	if state.water != null:
		_water_field.surfaces.erase(state.water)
		state.water.free()
		_water_field.refresh()
	if state.overlay != null:
		_set_overlay(row, false)
	state.mark.free()
	active.erase(row.id)


func release() -> void:
	for id in active.keys():
		_end({"id": id})
	if world != null:
		if _world_sound.is_valid():
			world.ctx.events.world_fact.disconnect(_on_world_sound)
			world.ctx.events.world_fact.connect(_world_sound)
		world.terrain.flood = _original_flood
		if _overlay_map != null:
			world.terrain.maps[world.terrain.stage - 1] = _original_map
	_water_field.surfaces.clear()
	_prepared.clear()
	_overlay_map = null
	_original_map = null
	_audio = null
	_world_sound = Callable()
	world = null
