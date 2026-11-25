extends SceneTree

# get_faces() and create_trimesh_shape() read the vertex buffer back from the renderer; on Vulkan
# that waits for every frame in flight, and the headless dummy renderer does it for free, so only a

const ARMS := [0, 1, 4, 16]
const WARM_FRAMES := 60
const RECORD_FRAMES := 180
const BOXES := 40000

var _out := ""
var _arm := 0
var _frame := 0
var _last_usec := 0
var _mesh: ArrayMesh
var _reads := 0
var _vertices := 0
var _samples := {}


func _initialize() -> void:
	var settings := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			settings[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--"):
			settings[arg.substr(2)] = "1"
	_out = String(settings.get("out", ""))
	if not _out.is_absolute_path() or not _out.ends_with(".json"):
		printerr("readback_bench: needs -- --out=<absolute .json path>")
		quit(2)
		return
	if not settings.has("vsync"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_build(int(settings.get("boxes", str(BOXES))))
	process_frame.connect(_on_frame)


func _build(boxes: int) -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	camera.transform = Transform3D.IDENTITY.looking_at(Vector3(0.0, -8.0, -40.0)).translated(Vector3(0.0, 8.0, 40.0))
	scene.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = boxes
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in boxes:
		multi.set_instance_transform(i, Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)),
			Vector3(rng.randf_range(-40.0, 40.0), rng.randf_range(0.0, 20.0), rng.randf_range(-60.0, 20.0))))
	var view := MultiMeshInstance3D.new()
	view.multimesh = multi
	scene.add_child(view)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 48
	sphere.rings = 32
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())


func _on_frame() -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_usec) / 1000.0 if _last_usec > 0 else 0.0
	_last_usec = now
	var count: int = ARMS[_arm]
	var started := Time.get_ticks_usec()
	for i in count:
		var arrays := _mesh.surface_get_arrays(0)
		_vertices = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		_reads += 1
	var read_ms := (Time.get_ticks_usec() - started) / 1000.0
	_frame += 1
	if _frame > WARM_FRAMES:
		var arm: Dictionary = _samples.get(count, {"read_ms": [], "frame_ms": []})
		arm.read_ms.append(read_ms)
		arm.frame_ms.append(frame_ms)
		_samples[count] = arm
	if _frame >= WARM_FRAMES + RECORD_FRAMES:
		_frame = 0
		_arm += 1
		if _arm >= ARMS.size():
			process_frame.disconnect(_on_frame)
			_finish()


func _finish() -> void:
	var arms := []
	for count in ARMS:
		var arm: Dictionary = _samples[count]
		arms.append({"reads_per_frame": count, "read_ms": _stats(arm.read_ms), "frame_ms": _stats(arm.frame_ms)})
	var result := {"tool": "readback_bench", "adapter": RenderingServer.get_video_adapter_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(), "vsync": DisplayServer.window_get_vsync_mode(),
		"reads": _reads, "vertices": _vertices, "arms": arms}
	var file := FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	for arm in arms:
		print("readback_bench: %d reads a frame: read_ms %s frame_ms %s" % [arm.reads_per_frame, arm.read_ms, arm.frame_ms])
	quit(0 if _reads > 0 and _vertices > 0 else 1)


static func _stats(values: Array) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	if sorted.is_empty():
		return {}
	return {"median": snappedf(sorted[sorted.size() / 2], 0.01), "p90": snappedf(sorted[int(sorted.size() * 0.9)], 0.01),
		"max": snappedf(sorted[-1], 0.01)}
