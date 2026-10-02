extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Interactables := preload("res://src/world/interactables.gd")
const WIND := Vector2(0.93, 0.367)

var ctx
var map_id := ""
var seed_value := 0
var batches: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _dust: MultiMeshInstance3D
var _clock := 0.0
var _active := true
var _ground: Callable
var _rng := RandomNumberGenerator.new()

func setup(context) -> void:
	ctx = context
	name = "TargetSetDressing"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_clear_stage)
	_build_stage()

func _stage_entered(_stage: int, _retry: bool) -> void:
	_active = true
	_build_stage()

func _clear_stage(_reason: String) -> void:
	_active = false
	visible = false

func _build_stage() -> void:
	for child in get_children():
		child.free()
	batches.clear()
	_materials.clear()
	_dust = null
	var stage: int = ctx.terrain.stage
	_active = ctx.terrain.geometry_root(stage).visible
	map_id = ctx.stages.of(stage).map
	seed_value = map_id.hash()
	_rng.seed = seed_value
	_ground = ctx.terrain.ground_callable(stage)
	var map = ctx.terrain.map_for(stage)
	if Preset.PRESETS.target.set_dressing:
		_build_props(map, stage)
	if Preset.PRESETS.target.air_motes:
		_build_dust()
	if Preset.PRESETS.target.air_streaks:
		_build_streaks(map)
	_update_protection()

func _build_props(map, stage: int) -> void:
	var pebble := SphereMesh.new()
	pebble.radius = 0.5
	pebble.height = 1.0
	pebble.radial_segments = 7
	pebble.rings = 3
	var flake := BoxMesh.new()
	flake.size = Vector3.ONE
	var tuft := _tuft_mesh()
	var meshes: Array[Mesh] = [pebble, flake, tuft]
	var lists := [[], [], []]
	var rect: Rect2 = map.play_rect
	for i in 1600:
		var x := _rng.randf_range(rect.position.x, rect.end.x)
		var z := _rng.randf_range(rect.position.y, rect.end.y)
		var at := Vector2(x, z)
		if _normal(x, z).y < 0.75 or _reserved(at, map, stage):
			continue
		var kind := i % 3
		var height := _rng.randf_range(0.045, 0.17) if kind != 1 else _rng.randf_range(0.01, 0.025)
		var width := _rng.randf_range(0.10, 0.26)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		var tr := Transform3D(basis, _ground.call(x, z, 0.0))
		# Bury the bottom on slopes. Check actual mesh vertices, not the nominal size.
		var protrusion := -INF
		for vertex in meshes[kind].get_faces():
			var point: Vector3 = tr * vertex
			protrusion = maxf(protrusion, point.y - (_ground.call(point.x, point.z, 0.0) as Vector3).y)
		tr.origin.y += height - protrusion
		lists[kind].append(tr)
	for i in 3:
		var color: Color = Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.38)
		if i == 1:
			color = Palette.CHARCOAL.lerp(Palette.SAND, 0.25)
		elif i == 2:
			color = Palette.SAND.lerp(Palette.CHARCOAL, 0.22)
		_batch(["Pebbles", "ScrapFlakes", "SandTufts"][i], meshes[i], lists[i], color, false)
	var rocks := []
	for i in 700:
		var x := _rng.randf_range(-192.0, 192.0)
		var z := _rng.randf_range(-192.0, 192.0)
		var at := Vector2(x, z)
		if rect.grow(10.0).has_point(at) or _normal(x, z).y >= Tuning.MAX_SLOPE_DOT:
			continue
		var size := _rng.randf_range(0.75, 1.9)
		var tr := Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) * Basis.from_scale(Vector3(size, size * 0.7, size * 0.8)), _ground.call(x, z, size * 0.15))
		rocks.append(tr)
	_batch("BrokenRock", _broken_mesh(pebble), rocks, Palette.SANDSTONE.lerp(Palette.CHARCOAL, 0.28), false)

func _reserved(at: Vector2, map, stage: int) -> bool:
	if at.distance_to(map.beacon) < 34.0 or at.distance_to(map.spawn) < 12.0 or at.distance_to(map.vault) < 10.0:
		return true
	for line in map.scrap_lines:
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, line[0], line[1])) < 7.0:
			return true
	for row in Interactables.PLACEMENTS.get(stage, []):
		if at.distance_to(row.at) < 12.0:
			return true
	return false

func _normal(x: float, z: float) -> Vector3:
	var dx: float = (_ground.call(x + 0.25, z, 0.0) as Vector3).y - (_ground.call(x - 0.25, z, 0.0) as Vector3).y
	var dz: float = (_ground.call(x, z + 0.25, 0.0) as Vector3).y - (_ground.call(x, z - 0.25, 0.0) as Vector3).y
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

func _batch(label: String, mesh: Mesh, transforms: Array, color: Color, air: bool) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not air
	multi.use_custom_data = air
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	var buffer := PackedFloat32Array()
	for tr: Transform3D in transforms:
		buffer.append_array(PackedFloat32Array([
			tr.basis.x.x, tr.basis.y.x, tr.basis.z.x, tr.origin.x,
			tr.basis.x.y, tr.basis.y.y, tr.basis.z.y, tr.origin.y,
			tr.basis.x.z, tr.basis.y.z, tr.basis.z.z, tr.origin.z]))
		if air:
			buffer.append_array(PackedFloat32Array([_rng.randf(), 0.0, 0.0, 0.0]))
		else:
			var shade := _rng.randf_range(0.85, 1.0)
			buffer.append_array(PackedFloat32Array([shade, shade, shade, 1.0]))
	multi.buffer = buffer
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/target_air.gdshader") if air else preload("res://assets/shaders/target_dressing.gdshader")
	material.set_shader_parameter("base_color", color)
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = multi
	# Retain the exact submitted buffer: the headless dummy server has no readback.
	view.set_meta("instance_buffer", buffer)
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.visibility_range_end = 50.0 if label != "BrokenRock" else 130.0
	add_child(view)
	batches.append(view)
	_materials.append(material)
	return view

func _build_dust() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var transforms := []
	for i in 160:
		var size := _rng.randf_range(0.03, 0.07)
		transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), Vector3(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-2.0, 5.0), -_rng.randf_range(2.0, 29.0))))
	_dust = _batch("DustMotes", mesh, transforms, Palette.SAND, true)
	_dust.material_override.set_shader_parameter("opacity", 0.025)

func _build_streaks(map) -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.8, 0.10)
	var transforms := []
	var rect: Rect2 = map.play_rect
	var wind_angle := atan2(-WIND.y, WIND.x)
	for i in 260:
		var x := _rng.randf_range(rect.position.x, rect.end.x)
		var z := _rng.randf_range(rect.position.y, rect.end.y)
		# Both ends of the 3 m drift remain on open, almost level ground.
		if _normal(x, z).y < 0.98 or _normal(x + WIND.x * 4.0, z + WIND.y * 4.0).y < 0.98 or _reserved(Vector2(x, z), map, ctx.terrain.stage):
			continue
		var basis := Basis(Vector3.UP, wind_angle) * Basis(Vector3.RIGHT, -PI / 2.0)
		transforms.append(Transform3D(basis, _ground.call(x, z, 0.07)))
	var streaks := _batch("SandStreaks", mesh, transforms, Palette.SAND, true)
	streaks.material_override.set_shader_parameter("ground_streak", true)
	streaks.material_override.set_shader_parameter("opacity", 0.018)

func _process(delta: float) -> void:
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

# Capture cameras can refresh the view while the staged simulation stays frozen.
func sync_camera(camera: Camera3D) -> void:
	visible = _active and ctx.flow.in_play()
	if _dust != null:
		_dust.global_transform = camera.global_transform
	_update_protection(camera)

# Clear a padded screen rectangle around every pickup, actor and committed threat.
# Overflow hides the dressing rather than dropping a gameplay read from the mask.
func _update_protection(camera: Camera3D = null) -> void:
	if camera == null:
		camera = _active_camera()
	var rects: Array[Vector4] = []
	var objects := get_tree().get_nodes_in_group("enemy")
	objects.append_array(get_tree().get_nodes_in_group("telegraph"))
	objects.append(ctx.player.body())
	if ctx.build != null and ctx.build.get("scrap") != null:
		objects.append_array(ctx.build.scrap.get_children())
	for object in objects:
		if not object is Node3D or not object.is_visible_in_tree():
			continue
		var reach := 2.5
		if object.is_in_group("telegraph"):
			reach = maxf(3.0, maxf(object.radius, object.length + object.width))
		var area := protection_rect(camera, object.global_position, reach)
		if area.z >= 0.0:
			rects.append(area)
	if rects.size() > 64:
		visible = false
		return
	var count := rects.size()
	while rects.size() < 64:
		rects.append(Vector4(-1.0, -1.0, -1.0, -1.0))
	for material in _materials:
		material.set_shader_parameter("protected_count", count)
		material.set_shader_parameter("protected_rects", rects)

static func protection_rect(camera: Camera3D, at: Vector3, reach: float) -> Vector4:
	if camera.is_position_behind(at):
		return Vector4(-1.0, -1.0, -1.0, -1.0)
	var size := camera.get_viewport().get_visible_rect().size
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x in [-reach, reach]:
		for y in [-0.5, reach * 2.0]:
			for z in [-reach, reach]:
				var corner := at + Vector3(x, y, z)
				if camera.is_position_behind(corner):
					return Vector4(0.0, 0.0, 1.0, 1.0)
				var point := camera.unproject_position(corner) / size
				low = low.min(point)
				high = high.max(point)
	return Vector4(low.x - 0.015, low.y - 0.015, high.x + 0.015, high.y + 0.015)
