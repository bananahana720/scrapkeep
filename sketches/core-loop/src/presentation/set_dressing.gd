extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Interactables := preload("res://src/world/interactables.gd")
const Features := preload("res://src/world/features.gd")
const Reach := preload("res://src/world/map_reach.gd")
const KIT_PATH := "res://assets/models/world_one/clutter_kit.glb"
const ROUTES := "res://src/world/reach_routes.json"
const KIT_ORDER := ["rock_a", "rock_b", "rock_c", "slab_a", "slab_b", "plate_a", "plate_b", "stub_a", "tuft_a", "tuft_b"]
const KIT_FOOTPRINT := {"rock_a": 0.48, "rock_b": 0.30, "rock_c": 0.58, "slab_a": 1.05, "slab_b": 0.79,
	"plate_a": 0.64, "plate_b": 0.50, "stub_a": 0.21, "tuft_a": 0.11, "tuft_b": 0.11}
const ANCHORS := ["rock_a", "rock_b", "rock_b", "rock_c", "slab_a", "slab_b", "slab_b", "plate_b", "stub_a"]
const ANCHOR_SCALE := {"rock_a": Vector2(6.0, 10.0), "rock_b": Vector2(6.0, 9.0), "rock_c": Vector2(6.0, 10.0),
	"slab_a": Vector2(3.5, 6.0), "slab_b": Vector2(4.0, 6.5), "plate_b": Vector2(5.0, 7.5), "stub_a": Vector2(5.0, 8.0)}
const SMALL := ["rock_a", "rock_c", "rock_c", "plate_a", "plate_b", "stub_a", "tuft_a", "tuft_a", "tuft_b", "tuft_b", "slab_a"]
const SMALL_SCALE := {"rock_a": Vector2(1.5, 3.0), "rock_c": Vector2(1.5, 3.0), "plate_a": Vector2(1.5, 3.0),
	"plate_b": Vector2(1.5, 3.0), "stub_a": Vector2(1.5, 3.0), "tuft_a": Vector2(2.2, 4.0),
	"tuft_b": Vector2(2.2, 4.0), "slab_a": Vector2(1.5, 2.5)}
const CLUSTER_SMALL := Vector2i(6, 12)
const WIND := Vector2(0.93, 0.367)
static var _route_warned := false

var ctx
var map_id := ""
var seed_value := 0
var batches: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _protected_count := -1
var _protected_rects: Array[Vector4] = []
var _protected_for: Array[ShaderMaterial] = []
var _dust: MultiMeshInstance3D
var _clock := 0.0
var _active := true
var _ground: Callable
var _built_for := []
var last_entry_usec := 0
var _prep := {}
var _kept := {}
const KEPT_PLANS := 3
var _dress_when_planned := false
var built_from_worker := false
var entry_deferred := false
var last_process_usec := 0
var last_process_frame := -1
var _kit := {}
var _kit_materials: Array[ShaderMaterial] = []
static var _broken_rock: ArrayMesh

class Plan:
	extends RefCounted
	var rng := RandomNumberGenerator.new()
	var ground: Callable
	var spacing := 0.0
	var stop: Array = []

	func stopped() -> bool:
		return not stop.is_empty() and stop[0]

func setup(context) -> void:
	ctx = context
	name = "TargetSetDressing"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_clear_stage)
	if ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	else:
		_dress_when_planned = true

func _stage_entered(_stage: int, _retry: bool) -> void:
	var started := Time.get_ticks_usec()
	_active = true
	entry_deferred = false
	_build_stage(true)
	last_entry_usec = Time.get_ticks_usec() - started

func _clear_stage(_reason: String) -> void:
	_active = false
	visible = false

func _build_stage(defer := false) -> void:
	_dress_when_planned = false
	var stage: int = ctx.terrain.stage
	var root: Node3D = ctx.terrain.geometry_root(stage)
	_active = root.visible
	var key := _key(stage, root)
	if key == _built_for and get_child_count() > 0:
		_update_protection()
		return
	if not _prep.is_empty() and _prep.key == key and not WorkerThreadPool.is_task_completed(_prep.task):
		_clear_children()
		_built_for = []
		_dress_when_planned = true
		entry_deferred = true
		return
	var from_worker: bool = not _prep.is_empty() and _prep.key == key
	var planned := _take_plan(key)
	built_from_worker = from_worker
	if not from_worker:
		planned = _kept.get(key, {})
	_clear_children()
	if planned.is_empty() and defer and not from_worker:
		_built_for = []
		_dress_when_planned = true
		entry_deferred = true
		return
	_built_for = key
	map_id = ctx.stages.of(stage).map
	seed_value = map_id.hash()
	_ground = ctx.terrain.ground_callable(stage)
	if planned.is_empty() and not from_worker:
		var map = ctx.terrain.map_for(stage)
		planned = plan(map_rows(map), keepouts(map, stage), _ground, seed_value, _flags())
	_keep(key, planned)
	if planned.has("rock"):
		_build_props(planned)
	if planned.has("dust"):
		_dust = _batch("DustMotes", _quad(Vector2.ONE), planned.dust, Palette.SAND, true)
		_dust.material_override.set_shader_parameter("opacity", 0.025)
	if planned.has("streaks"):
		var streaks := _batch("SandStreaks", _quad(Vector2(1.8, 0.10)), planned.streaks, Palette.SAND, true)
		streaks.material_override.set_shader_parameter("ground_streak", true)
		streaks.material_override.set_shader_parameter("opacity", 0.018)
	_update_protection()

func _keep(key: Array, planned: Dictionary) -> void:
	_kept.erase(key)
	_kept[key] = planned
	while _kept.size() > KEPT_PLANS:
		_kept.erase(_kept.keys()[0])

func _clear_children() -> void:
	for child in get_children():
		child.free()
	batches.clear()
	_materials.clear()
	_dust = null

func _key(stage: int, root: Node3D) -> Array:
	return [stage, ctx.stages.of(stage).map, Preset.current, root.get_instance_id()]

func _flags() -> Dictionary:
	var preset: Dictionary = Preset.PRESETS[Preset.current]
	return {"props": preset.get("set_dressing", false), "dust": preset.get("air_motes", false), "streaks": preset.get("air_streaks", false)}

static func map_rows(map) -> Dictionary:
	return {"play_rect": map.play_rect, "scatter": map.scatter.duplicate(true), "structures": structure_points(map)}

func _take_plan(key: Array) -> Dictionary:
	if _prep.is_empty() or _prep.key != key:
		return {}
	WorkerThreadPool.wait_for_task_completion(_prep.task)
	var planned: Dictionary = _prep.out
	_prep = {}
	return planned

func _prepare_next() -> void:
	var terrain = ctx.terrain
	if not "maps" in terrain or not terrain.has_method("is_ready") or not "stage" in terrain:
		return
	var next: int = terrain.stage + (0 if _dress_when_planned else 1)
	var key := _key(next, terrain.geometry_root(next)) if next <= terrain.maps.size() and terrain.is_ready(next) else []
	if not _prep.is_empty():
		if _prep.key != key and WorkerThreadPool.is_task_completed(_prep.task):
			WorkerThreadPool.wait_for_task_completion(_prep.task)
			_prep = {}
		return
	if key.is_empty() or key == _built_for:
		return
	var map = terrain.map_for(next)
	var rows := map_rows(map)
	var keep := keepouts(map, next)
	var ground: Callable = terrain.ground_callable(next)
	var seed_next: int = String(ctx.stages.of(next).map).hash()
	var flags := _flags()
	var out := {}
	var stop := [false]
	_prep = {"key": key, "out": out, "stop": stop,
		"task": WorkerThreadPool.add_task(func(): out.merge(plan(rows, keep, ground, seed_next, flags, stop)), false, "set dressing plan")}

func _exit_tree() -> void:
	if not _prep.is_empty():
		_prep.stop[0] = true
		WorkerThreadPool.wait_for_task_completion(_prep.task)
		_prep = {}

static func release_shared() -> void:
	_broken_rock = null

static func plan(map: Dictionary, rows: Array, ground: Callable, seed_number: int, flags: Dictionary, stop: Array = []) -> Dictionary:
	var p := Plan.new()
	p.rng.seed = seed_number
	p.ground = ground
	p.stop = stop
	var out := {}
	if p.stopped():
		return out
	if flags.props:
		var rect: Rect2 = map.play_rect
		var clusters := _cluster_centres(p, map, rect, rows)
		var lists := {}
		for kit_name in KIT_ORDER:
			lists[kit_name] = []
		for centre: Vector2 in clusters:
			if p.stopped():
				return out
			_place_cluster(p, centre, rect, rows, lists)
		out.clutter = {}
		for kit_name in KIT_ORDER:
			out.clutter[kit_name] = _instance_buffer(p, lists[kit_name], "")
		var rocks := []
		for i in 700:
			if p.stopped():
				return out
			var x := p.rng.randf_range(-192.0, 192.0)
			var z := p.rng.randf_range(-192.0, 192.0)
			var at := Vector2(x, z)
			if rect.grow(10.0).has_point(at) or _normal(p, x, z).y >= Tuning.MAX_SLOPE_DOT or not _near_flat(p, at):
				continue
			var size := p.rng.randf_range(0.75, 1.9)
			var tr := Transform3D(Basis(Vector3.UP, p.rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, size * 0.7, size * 0.8)), p.ground.call(x, z, size * 0.15))
			rocks.append(tr)
		out.rock = _instance_buffer(p, rocks, "shade")
	if flags.dust:
		var transforms := []
		for i in 160:
			var size := p.rng.randf_range(0.03, 0.07)
			transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), Vector3(p.rng.randf_range(-10.0, 10.0), p.rng.randf_range(-2.0, 5.0), -p.rng.randf_range(2.0, 29.0))))
		out.dust = _instance_buffer(p, transforms, "air")
	if flags.streaks:
		var transforms := []
		var rect: Rect2 = map.play_rect
		var wind_angle := atan2(-WIND.y, WIND.x)
		for i in 800:
			if p.stopped():
				return out
			var x := p.rng.randf_range(rect.position.x, rect.end.x)
			var z := p.rng.randf_range(rect.position.y, rect.end.y)
			if _normal(p, x, z).y < 0.98 or _normal(p, x + WIND.x * 4.0, z + WIND.y * 4.0).y < 0.98 or blocked(rows, Vector2(x, z), 0.0) != "":
				continue
			var basis := Basis(Vector3.UP, wind_angle) * Basis(Vector3.RIGHT, -PI / 2.0)
			transforms.append(Transform3D(basis, p.ground.call(x, z, 0.07)))
		out.streaks = _instance_buffer(p, transforms, "air")
	return out

static func _instance_buffer(p: Plan, transforms: Array, extra: String) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	for tr: Transform3D in transforms:
		buffer.append_array(PackedFloat32Array([
			tr.basis.x.x, tr.basis.y.x, tr.basis.z.x, tr.origin.x,
			tr.basis.x.y, tr.basis.y.y, tr.basis.z.y, tr.origin.y,
			tr.basis.x.z, tr.basis.y.z, tr.basis.z.z, tr.origin.z]))
		if extra == "air":
			buffer.append_array(PackedFloat32Array([p.rng.randf(), 0.0, 0.0, 0.0]))
		elif extra == "shade":
			var shade := p.rng.randf_range(0.85, 1.0)
			buffer.append_array(PackedFloat32Array([shade, shade, shade, 1.0]))
	return buffer

func _build_props(planned: Dictionary) -> void:
	var meshes := _kit_meshes()
	for kit_name in KIT_ORDER:
		_clutter_batch("Clutter_" + kit_name, meshes.get(kit_name), planned.clutter[kit_name])
	if _broken_rock == null:
		var pebble := SphereMesh.new()
		pebble.radius = 0.5
		pebble.height = 1.0
		pebble.radial_segments = 7
		pebble.rings = 3
		_broken_rock = _broken_mesh(pebble)
	_batch("BrokenRock", _broken_rock, planned.rock, Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.28), false)

static func _quad(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh

func _kit_meshes() -> Dictionary:
	if _kit.is_empty():
		var scene := (load(KIT_PATH) as PackedScene).instantiate()
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh := view.mesh.duplicate() as ArrayMesh
			for surface in mesh.get_surface_count():
				var material := Palette.target_clutter_material(view.mesh.surface_get_material(surface))
				if material not in _kit_materials:
					_kit_materials.append(material)
				mesh.surface_set_material(surface, material)
			_kit[String(view.name)] = mesh
		scene.free()
	for material in _kit_materials:
		if material not in _materials:
			_materials.append(material)
	return _kit

static func _cluster_centres(p: Plan, map: Dictionary, rect: Rect2, rows: Array) -> Array[Vector2]:
	var centres: Array[Vector2] = []
	p.spacing = float(map.scatter["spacing"])
	for point in map.structures:
		_try_centre(p, centres, point, rect, rows, 4.0)
	for row in rows:
		if not row.ride:
			continue
		var points: PackedVector2Array = row.points
		for i in points.size() - 1:
			var length := points[i].distance_to(points[i + 1])
			var steps := int(length / 9.0)
			var along := (points[i + 1] - points[i]).normalized()
			for k in steps:
				if p.rng.randf() > float(map.scatter["edge_share"]):
					continue
				var side := Vector2(-along.y, along.x) * (1.0 if p.rng.randf() < 0.5 else -1.0)
				var at: Vector2 = points[i] + along * (float(k) + p.rng.randf()) * 9.0 + side * (float(row.radius) + p.rng.randf_range(2.0, 5.0))
				_try_centre(p, centres, at, rect, rows, 4.0)
	var limit := centres.size() + int(map.scatter["clusters"])
	for i in 40000:
		if centres.size() >= limit or p.stopped():
			break
		var at := Vector2(p.rng.randf_range(rect.position.x, rect.end.x), p.rng.randf_range(rect.position.y, rect.end.y))
		if _at_cliff_foot(p, at):
			_try_centre(p, centres, at, rect, rows, 4.0)
	return centres

static func _try_centre(p: Plan, centres: Array[Vector2], at: Vector2, rect: Rect2, rows: Array, margin: float) -> void:
	if not rect.grow(-6.0).has_point(at) or _normal(p, at.x, at.y).y < 0.9 or blocked(rows, at, margin) != "":
		return
	for other in centres:
		if other.distance_to(at) < p.spacing:
			return
	centres.append(at)

static func _at_cliff_foot(p: Plan, at: Vector2) -> bool:
	if _normal(p, at.x, at.y).y < 0.93:
		return false
	for k in 8:
		for reach: float in [3.0, 5.0, 7.0]:
			var probe: Vector2 = at + Vector2.from_angle(k * TAU / 8.0) * reach
			if _normal(p, probe.x, probe.y).y < 0.6:
				return true
	return false

static func _place_cluster(p: Plan, centre: Vector2, rect: Rect2, rows: Array, lists: Dictionary) -> void:
	var placed: Array = []
	var anchor: String = ANCHORS[p.rng.randi() % ANCHORS.size()]
	_place_piece(p, anchor, centre, ANCHOR_SCALE[anchor], rect, rows, lists, placed)
	if placed.is_empty():
		return
	var reach: float = placed[0].z
	for i in p.rng.randi_range(CLUSTER_SMALL.x, CLUSTER_SMALL.y):
		var kit_name: String = SMALL[p.rng.randi() % SMALL.size()]
		for attempt in 4:
			var at := centre + Vector2.from_angle(p.rng.randf_range(0.0, TAU)) * (reach + p.rng.randf_range(0.2, 3.2))
			if _place_piece(p, kit_name, at, SMALL_SCALE[kit_name], rect, rows, lists, placed):
				break

static func _place_piece(p: Plan, kit_name: String, at: Vector2, span: Vector2, rect: Rect2, rows: Array, lists: Dictionary, placed: Array) -> bool:
	var size := p.rng.randf_range(span.x, span.y)
	var stretch := Vector3(p.rng.randf_range(0.9, 1.15), p.rng.randf_range(0.9, 1.15), p.rng.randf_range(0.9, 1.15)) * size
	var footprint: float = KIT_FOOTPRINT[kit_name] * size * 0.5
	if not rect.grow(-4.0).has_point(at) or _normal(p, at.x, at.y).y < 0.85 or blocked(rows, at, footprint) != "":
		return false
	for other: Vector3 in placed:
		if Vector2(other.x, other.y).distance_to(at) < (other.z + footprint) * 0.75:
			return false
	var basis := Basis(Vector3.UP, p.rng.randf_range(0.0, TAU))
	basis = basis * Basis(Vector3.RIGHT, p.rng.randf_range(-0.08, 0.08)) * Basis(Vector3.FORWARD, p.rng.randf_range(-0.08, 0.08))
	basis = basis.scaled_local(stretch)
	var low := INF
	for k in 8:
		var spot: Vector2 = at + Vector2.from_angle(k * TAU / 8.0) * footprint * 0.8
		low = minf(low, (p.ground.call(spot.x, spot.y, 0.0) as Vector3).y)
	low = minf(low, (p.ground.call(at.x, at.y, 0.0) as Vector3).y)
	lists[kit_name].append(Transform3D(basis, Vector3(at.x, low - 0.03 * size, at.y)))
	placed.append(Vector3(at.x, at.y, footprint))
	return true

static func keepouts(map, stage: int) -> Array:
	var rows := []
	rows.append(_row("spawn", [map.spawn], 6.0))
	rows.append(_row("warden bowl", [map.beacon], Features.BOWL_FLAT + 3.0))
	rows.append(_row("vault", [map.vault], 11.0))
	for line in map.scrap_lines:
		rows.append(_row("scrap line", line, 3.0, true))
	for kicker in map.kickers:
		var dir: Vector2 = kicker.dir
		rows.append(_row("kicker ramp", [kicker.at - dir * float(kicker.get("length", Reach.KICKER_LENGTH)), kicker.at + dir * 5.0], float(kicker.width) * 0.5 + 3.0, true))
	for slot in map.gate_slots:
		rows.append(_row("reward gate slot", [slot.at], 6.0))
	for site in map.activity_sites:
		rows.append(_row("activity site", [site.at], 11.0))
	for row in Interactables.PLACEMENTS.get(stage, []):
		rows.append(_row("device", [row.at], 7.0))
	if map.get_script() == Reach:
		rows.append_array(pilot_rows(load_routes()))
		rows.append(_arc_row("sweeper ramp", Reach.SWEEP_CENTRE, Reach.SWEEP_ARC, Reach.SWEEP_WIDTH + Reach.SWEEP_BANK, Reach.SWEEP_FROM, Reach.SWEEP_TO))
		rows.append(_arc_row("berm ramp", Reach.BERM_CENTRE, Reach.BERM_RADIUS, Reach.BERM_WIDTH + Reach.BERM_BANK, Reach.BERM_FROM, Reach.BERM_TO))
		var dive := PackedVector2Array([Reach.MOUTH + Reach.DIVE_DIR * Reach.DIVE_FROM, Reach.MOUTH + Reach.DIVE_DIR * (Reach.DIVE_TO + Reach.DIVE_OUT)])
		rows.append(_row("dive ramp", dive, Reach.DIVE_HALF + Reach.DIVE_SIDE + 3.0, true))
		rows.append(_row("cable line", [Reach.CABLE_FROM, Reach.CABLE_TO], Reach.CABLE_RADIUS + 3.0, true))
		rows.append(_row("skylight halfpipe", [Vector2(Reach.SKYLIGHT_X, Reach.SKYLIGHT_Z.x), Vector2(Reach.SKYLIGHT_X, Reach.SKYLIGHT_Z.y)], 9.0, true))
		for id in Reach.TUNNELS:
			rows.append(_row("tunnel floor " + String(id), Reach.TUNNELS[id], Reach.TUNNEL_HALF + 3.0, true))
		for thermal in [Reach.THERMAL_A, Reach.THERMAL_B]:
			rows.append(_row("thermal", [thermal], 8.0))
	return rows

static func load_routes() -> Variant:
	if not FileAccess.file_exists(ROUTES):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(ROUTES))

static func pilot_rows(routes: Variant) -> Array:
	var rows := []
	if not routes is Dictionary or not routes.get("pilots") is Dictionary:
		if not _route_warned:
			_route_warned = true
			push_warning("set_dressing: no pilot route file at " + ROUTES + "; clutter ignores the pilots' lines")
		return rows
	for pilot in routes.pilots:
		var line := PackedVector2Array()
		for pair in routes.pilots[pilot].get("waypoints", []):
			line.append(Vector2(float(pair[0]), float(pair[1])))
		if line.size() > 1:
			rows.append(_row("ride line " + String(pilot), line, 4.0, true))
	return rows

static func _arc_row(what: String, centre: Vector2, radius: float, band: float, from_deg: float, to_deg: float) -> Dictionary:
	var line := PackedVector2Array()
	var span := wrapf(to_deg - from_deg, 0.0, 360.0)
	for i in 24:
		var angle := deg_to_rad(from_deg + span * i / 23.0)
		line.append(centre + Vector2(cos(angle), sin(angle)) * (radius + band * 0.5))
	return _row(what, line, band * 0.5 + 3.0, true)

static func _row(what: String, points: Array, radius: float, ride := false) -> Dictionary:
	return {"what": what, "points": PackedVector2Array(points), "radius": radius, "ride": ride}

static func structure_points(map) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if map.get_script() != Reach:
		return result
	for post in Reach.POSTS:
		result.append(post.at + Vector2(3.0, 2.0))
	for wall in Reach.WALLS:
		result.append(wall.at + Vector2(0.0, 5.0))
	result.append(Vector2(Reach.TOWER.x, Reach.TOWER.z) + Vector2(Reach.TOWER_RADIUS + 5.0, 0.0))
	for sat in Reach.SATELLITES:
		result.append(sat.at + Vector2(float(sat.radius) + 4.0, 0.0))
	return result

static func blocked(rows: Array, at: Vector2, margin: float) -> String:
	for row in rows:
		if distance_to_row(row, at) < float(row.radius) + margin:
			return String(row.what)
	return ""

static func distance_to_row(row: Dictionary, at: Vector2) -> float:
	var points: PackedVector2Array = row.points
	if points.size() == 1:
		return at.distance_to(points[0])
	var best := INF
	for i in points.size() - 1:
		best = minf(best, at.distance_to(Geometry2D.get_closest_point_to_segment(at, points[i], points[i + 1])))
	return best

static func _near_flat(p: Plan, at: Vector2) -> bool:
	for k in 12:
		for reach: float in [3.0, 6.0]:
			var probe: Vector2 = at + Vector2.from_angle(k * TAU / 12.0) * reach
			if _normal(p, probe.x, probe.y).y > 0.8:
				return true
	return false

static func _normal(p: Plan, x: float, z: float) -> Vector3:
	var dx: float = (p.ground.call(x + 0.25, z, 0.0) as Vector3).y - (p.ground.call(x - 0.25, z, 0.0) as Vector3).y
	var dz: float = (p.ground.call(x, z + 0.25, 0.0) as Vector3).y - (p.ground.call(x, z - 0.25, 0.0) as Vector3).y
	return Vector3(-dx, 0.5, -dz).normalized()

static func _broken_mesh(source: Mesh) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for vertex in source.get_faces():
		var worn := 0.90 + 0.10 * sin(vertex.x * 17.0 + vertex.y * 11.0 + vertex.z * 23.0)
		st.add_vertex(vertex * worn)
	st.generate_normals()
	return st.commit()

static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle in [0.0, PI / 3.0, PI * 2.0 / 3.0]:
		var side := Vector3(cos(angle), 0.0, sin(angle)) * 0.5
		st.add_vertex(-side + Vector3.DOWN * 0.5)
		st.add_vertex(Vector3(0.08, 0.5, 0.0))
		st.add_vertex(side + Vector3.DOWN * 0.5)
	st.generate_normals()
	return st.commit()

func _batch(label: String, mesh: Mesh, buffer: PackedFloat32Array, color: Color, air: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not air
	multi.use_custom_data = air
	multi.mesh = mesh
	multi.instance_count = buffer.size() / 16
	multi.buffer = buffer
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/target_air.gdshader") if air else preload("res://assets/shaders/target_dressing.gdshader")
	material.set_shader_parameter("base_color", color)
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = multi
	# Godot headless Dummy renderer has no MultiMesh buffer readback.
	view.set_meta("instance_buffer", buffer)
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Godot measures visibility_range from the MultiMesh bounds center, not per instance.
	view.visibility_range_end = 50.0 if air and label == "DustMotes" else 0.0
	add_child(view)
	batches.append(view)
	_materials.append(material)
	return view

func _clutter_batch(label: String, mesh: Mesh, buffer: PackedFloat32Array) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = buffer.size() / 12
	multi.buffer = buffer
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = multi
	view.set_meta("instance_buffer", buffer)
	view.set_meta("clutter", true)
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
	batches.append(view)
	return view

func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_work(delta)
	last_process_usec = Time.get_ticks_usec() - started
	last_process_frame = Engine.get_process_frames()

func _work(delta: float) -> void:
	_prepare_next()
	if _dress_when_planned and not _prep.is_empty() and WorkerThreadPool.is_task_completed(_prep.task):
		_build_stage(true)
	visible = _active and ctx.flow.in_play()
	if not visible:
		return
	_clock += delta
	for material in _materials:
		if material.shader == preload("res://assets/shaders/target_air.gdshader"):
			material.set_shader_parameter("effect_clock", _clock)
	sync_camera(_active_camera())

func _active_camera() -> Camera3D:
	var camera := get_viewport().get_camera_3d()
	return camera if camera != null else ctx.camera.cam

func sync_camera(camera: Camera3D) -> void:
	visible = _active and ctx.flow.in_play()
	if _dust != null:
		_dust.global_transform = camera.global_transform
	_update_protection(camera)

func _update_protection(camera: Camera3D = null) -> void:
	if camera == null:
		camera = _active_camera()
	var rects: Array[Vector4] = []
	var objects := get_tree().get_nodes_in_group("enemy")
	objects.append_array(get_tree().get_nodes_in_group("telegraph"))
	objects.append(ctx.player.body())
	var scrap := []
	if ctx.build != null and ctx.build.get("scrap") != null:
		scrap = ctx.build.scrap.get_children()
	for object in objects:
		_add_rect(rects, camera, object)
	if rects.size() > 64:
		visible = false
		return
	var eye := camera.global_position
	var pieces: Array[Node3D] = []
	var distances := PackedFloat64Array()
	for piece in scrap:
		if piece is Node3D and piece.is_visible_in_tree():
			pieces.append(piece)
			distances.append(piece.global_position.distance_squared_to(eye))
	var ranked := distances.duplicate()
	if pieces.size() > 64 - rects.size():
		ranked.sort()
	else:
		ranked = PackedFloat64Array([INF])
	var taken_upto := -INF
	var r := 0
	while rects.size() < 64 and r < ranked.size():
		var upto := ranked[mini(r + 64 - rects.size(), ranked.size()) - 1]
		for k in pieces.size():
			if rects.size() >= 64:
				break
			if distances[k] > taken_upto and distances[k] <= upto:
				_add_rect(rects, camera, pieces[k])
		taken_upto = upto
		r = ranked.bsearch(upto, false)
	var count := rects.size()
	while rects.size() < 64:
		rects.append(Vector4(-1.0, -1.0, -1.0, -1.0))
	if count == _protected_count and rects == _protected_rects and _materials == _protected_for:
		return
	_protected_count = count
	_protected_rects = rects
	_protected_for = _materials.duplicate()
	for material in _materials:
		material.set_shader_parameter("protected_count", count)
		material.set_shader_parameter("protected_rects", rects)

func _add_rect(rects: Array[Vector4], camera: Camera3D, object: Node) -> void:
	if not object is Node3D or not object.is_visible_in_tree():
		return
	if object.is_in_group("telegraph"):
		_add_telegraph(rects, camera, object)
		return
	var area := protection_rect(camera, object.global_position, 2.5)
	if area.z >= 0.0:
		rects.append(area)

func _add_telegraph(rects: Array[Vector4], camera: Camera3D, object: Node) -> void:
	var middle: Vector3 = object.center
	var reach := 3.0
	var points: Array[Vector3] = []
	if object.is_hostile() or object.shape != 0:
		reach = maxf(3.0, maxf(object.radius, object.length + object.width))
		points.append(middle)
	else:
		var steps := clampi(int(TAU * object.radius / 5.0), 8, 20)
		for k in steps:
			points.append(middle + Vector3(cos(k * TAU / steps), 0.0, sin(k * TAU / steps)) * object.radius)
	for point in points:
		var area := protection_rect(camera, point, reach)
		if area.z >= 0.0:
			rects.append(area)

static func protection_rect(camera: Camera3D, at: Vector3, reach: float) -> Vector4:
	if camera.is_position_behind(at):
		return Vector4(-1.0, -1.0, -1.0, -1.0)
	var size := camera.get_viewport().get_visible_rect().size
	var low := camera.unproject_position(at) / size
	var high := low
	var straddles := false
	for x in [-reach, reach]:
		for y in [-0.5, reach * 2.0]:
			for z in [-reach, reach]:
				var corner := at + Vector3(x, y, z)
				if camera.is_position_behind(corner):
					var side := camera.global_transform.affine_inverse() * corner
					straddles = true
					low.x = 0.0 if side.x < 0.0 else low.x
					high.x = 1.0 if side.x > 0.0 else high.x
					low.y = 0.0 if side.y > 0.0 else low.y
					high.y = 1.0 if side.y < 0.0 else high.y
					continue
				var point := camera.unproject_position(corner) / size
				low = low.min(point)
				high = high.max(point)
	low -= Vector2(0.015, 0.015)
	high += Vector2(0.015, 0.015)
	if high.x < 0.0 or high.y < 0.0 or low.x > 1.0 or low.y > 1.0:
		return Vector4(-1.0, -1.0, -1.0, -1.0)
	if straddles:
		return Vector4(maxf(low.x, 0.0), maxf(low.y, 0.0), minf(high.x, 1.0), minf(high.y, 1.0))
	return Vector4(low.x, low.y, high.x, high.y)
