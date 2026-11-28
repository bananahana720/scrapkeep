extends Node3D

const SurgeRun := preload("res://src/world/surge_run.gd")
const EventView := preload("res://src/world/event_view.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")


const RAY_ABOVE_M := 3.0
const RAY_BELOW_M := 60.0
const FRONT_SIZE := Vector3(12.0, 4.0, 3.0)
const FRONT_START := -40.0
const FRONT_SPEED := 1.0

var model
var _rows := PackedStringArray()
var _park := {}
var _ground := Callable()
var _gates: Array[MeshInstance3D] = []
var _front: MeshInstance3D


static func path(park: Dictionary, route_id: String, start: Vector2) -> Dictionary:
	var rows := {}
	for row in park.get("park_rows", []):
		rows[row.id] = row
	var via: Array = []
	for route in park.get("routes", []):
		if route.id == route_id:
			via = route.via
	var points := PackedVector2Array()
	var names := PackedStringArray()
	var last := start
	for id in via:
		if not rows.has(id) or String(rows[id].verb) != "grind":
			continue
		var row: Dictionary = rows[id]
		var at := Vector2(float(row.at[0]), float(row.at[1]))
		var half := ParkMap.yaw_dir(float(row.yaw_deg)) * float(row.size[0]) * 0.5
		var a := at - half
		var b := at + half
		if b.distance_to(last) < a.distance_to(last):
			var swap := a
			a = b
			b = swap
		if points.is_empty() or points[points.size() - 1].distance_to(a) > 0.5:
			if not points.is_empty():
				names.append(id)
			points.append(a)
		points.append(b)
		names.append(id)
		last = b
	return {"points": points, "rows": names}


static func heights(model_ref, rows: PackedStringArray, park: Dictionary, ground: Callable, space: PhysicsDirectSpaceState3D = null) -> Array[float]:
	var tops := {}
	for row in park.get("park_rows", []):
		if row.get("y") != null:
			tops[String(row.id)] = float(row.y) + float(row.size[1])
	var out: Array[float] = []
	var route = model_ref.route
	for i in model_ref.gates.size():
		var g: Vector2 = model_ref.gates[i]
		var segment := 0
		for k in range(1, route.lengths.size()):
			segment = k - 1
			if model_ref.gate_distances[i] <= route.lengths[k]:
				break
		var id: String = rows[segment] if segment < rows.size() else ""
		var y: float = tops[id] if tops.has(id) else (float(ground.call(g.x, g.y)) if ground.is_valid() else 0.0)
		if space != null:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(g.x, y + RAY_ABOVE_M, g.y), Vector3(g.x, y - RAY_BELOW_M, g.y), PhysicsLayers.WORLD_MASK))
			if not hit.is_empty():
				y = hit.position.y
		out.append(y)
	return out


func setup(site: Dictionary, cruise: float, park: Dictionary, ground: Callable) -> void:
	name = "SurgeCourse"
	top_level = true
	transform = Transform3D.IDENTITY
	var ring: Vector2 = site.ring
	var line := path(park, String(site.route), ring)
	model = SurgeRun.new({"ring": ring, "route": line.points}, cruise)
	model.front_start = FRONT_START
	model.front_speed = cruise * FRONT_SPEED
	_rows = line.rows
	_park = park
	_ground = ground
	model.gate_heights = heights(model, _rows, _park, _ground)
	for i in model.gates.size():
		var at := Vector3(model.gates[i].x, model.gate_heights[i], model.gates[i].y)
		var g := EventView.gate_ring(at, model.route.tangent(model.gate_distances[i]))
		g.visible = false
		add_child(g)
		_gates.append(g)
	_front = MeshInstance3D.new()
	_front.name = "SluiceFront"
	var water := Palette.VERDIGRIS.lerp(Palette.ARC, 0.5)
	_front.mesh = _breaking_front(water)
	var material := Palette.water(water)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_color = Color(1.0, 1.0, 1.0, material.albedo_color.a)
	_front.material_override = material
	_front.visible = false
	add_child(_front)


static func _breaking_front(water: Color) -> ArrayMesh:
	var crest_heights := [0.65, 0.88, 0.78, 1.0, 0.83, 0.92, 0.68]
	var profile := [Vector2(-0.5, 0), Vector2(-0.35, 0.7), Vector2(-0.42, 1),
		Vector2(-0.08, 0.86), Vector2(0.5, 0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in crest_heights.size():
		var x := FRONT_SIZE.x * (float(i) / (crest_heights.size() - 1) - 0.5)
		for j in profile.size():
			var p: Vector2 = profile[j]
			var y := FRONT_SIZE.y * (p.y * float(crest_heights[i]) - 0.5)
			surface.set_color(water.lerp(Palette.SAND, 0.78) if j == 2 else water)
			surface.add_vertex(Vector3(x, y, p.x * FRONT_SIZE.z))
			if i > 0 and j > 0:
				var right := i * profile.size() + j
				var left := right - profile.size()
				for index in [left - 1, right - 1, left, left, right - 1, right]:
					surface.add_index(index)
	surface.generate_normals()
	return surface.commit()


func settle() -> void:
	if not is_inside_tree():
		return
	model.gate_heights = heights(model, _rows, _park, _ground, get_world_3d().direct_space_state)
	for i in _gates.size():
		_gates[i].position.y = model.gate_heights[i] + EventView.GATE_RADIUS - 1.0


func show_live(live: bool, pulse: float) -> void:
	for i in _gates.size():
		var g := _gates[i]
		g.visible = live and i >= model.next_gate
		if g.visible:
			var next: bool = i == model.next_gate
			var mat: StandardMaterial3D = g.material_override
			mat.albedo_color = EventKinds.world_row("sluice_landed").color if next else Palette.SAND
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = FlashGuard.spike(1.2, 1.2 + pulse * 2.0) if next else 0.4
	_front.visible = live and model.front > 0.0
	if _front.visible:
		var d: float = maxf(model.front, 0.0)
		var p: Vector2 = model.front_point()
		var t: Vector2 = model.front_tangent()
		_front.position = Vector3(p.x, model.deck_height(d) + FRONT_SIZE.y * 0.5, p.y)
		_front.basis = Basis.looking_at(Vector3(t.x, 0.0, t.y), Vector3.UP)


func lead_point(ball: Vector3, ahead: float) -> Vector3:
	var flat := Vector2(ball.x, ball.z)
	var head: Vector2 = model.route.points[0]
	var t0: Vector2 = model.route.tangent(0.0)
	var behind := (flat - head).dot(t0)
	var d: float = (behind if behind < 0.0 else model.route.project(flat).x) + ahead
	var p: Vector2 = head + t0 * d if d < 0.0 else model.route.at(d)
	return Vector3(p.x, model.deck_height(maxf(d, 0.0)), p.y)


func next_gate_point() -> Vector3:
	var i: int = clampi(model.next_gate, 0, model.gates.size() - 1)
	return Vector3(model.gates[i].x, model.gate_heights[i], model.gates[i].y)
