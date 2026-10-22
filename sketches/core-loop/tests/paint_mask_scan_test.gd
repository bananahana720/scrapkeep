extends SceneTree

# The paint shader reads vertex alpha as a take mask (step(0.05, alpha)): alpha 0 keeps a part's baked
# colour under any paint. This scan pins who may carry a mask. On every shipped shell_* and pilot_* GLB a paint
# vertex with alpha under 0.05 must be exactly 0 and sit in Sable's SpoolKit; every other paint vertex is
# 1 or one of Tally's window-index alphas. A planted vertex built in code proves the scan flags a stray mask.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ROOT := "res://assets/models"
const MASK_BELOW := 0.05
const WINDOWS := [0.2, 0.4, 0.6, 0.8]
const TOL := 0.01

var _checks := 0
var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


static func _allowed(a: float, mesh_name: String, path: String) -> bool:
	if a < MASK_BELOW:
		return a == 0.0 and mesh_name == "SpoolKit" and path.get_file().begins_with("shell_sable")
	if absf(a - 1.0) < 0.001:
		return true
	return WINDOWS.any(func(w): return absf(a - w) < TOL)


# One entry per mesh with paint vertices that break the rule: "<file> <mesh>: <n> stray vertices".
static func scan_mesh(path: String, mesh_name: String, mesh: Mesh) -> Array:
	var out := []
	var bad := 0
	for i in mesh.get_surface_count():
		if HeroAssets.slot_of(mesh, i) != "paint":
			continue
		var cols = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
		for c in Array(cols if cols != null else []):
			if not _allowed(c.a, mesh_name, path):
				bad += 1
	if bad > 0:
		out.append("%s %s: %d stray vertices" % [path.get_file(), mesh_name, bad])
	return out


static func _files(dir: String, out: Array = []) -> Array:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") and (f.begins_with("shell_") or f.begins_with("pilot_")):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_files(dir.path_join(d), out)
	return out


static func _meshes(node: Node, out: Array = []) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_meshes(c, out)
	return out


func _planted() -> Array:
	var verts := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var cols := PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "paint"
	mesh.surface_set_material(0, mat)
	return scan_mesh("res://assets/models/world_one/shell_planted.glb", "PlantedMesh", mesh)


func _initialize() -> void:
	var planted := _planted()
	_report("scan flags planted mask", planted.size() == 1 and "PlantedMesh" in planted[0] and "1 stray" in planted[0],
		"alpha-0 vertex on a non-Sable paint mesh gives %s" % [planted])
	var files := _files(ROOT)
	var stray := []
	var spool := 0
	for f in files:
		var packed := load(f) as PackedScene
		if packed == null:
			stray.append("%s did not load" % f.get_file())
			continue
		var root := packed.instantiate()
		for mi in _meshes(root):
			stray.append_array(scan_mesh(f, String(mi.name), mi.mesh))
			if String(mi.name) == "SpoolKit":
				spool += 1
		root.free()
	_report("shell GLBs scanned", files.size() >= 40 and spool == 2, "%d shell/pilot GLBs, %d SpoolKit meshes" % [files.size(), spool])
	_report("no stray paint mask", stray.is_empty(), "paint alpha under 0.05 only in Sable SpoolKit, else 1 or a Tally window (%s)" % [stray])
	print("paint_mask_scan_test: %s, %d checks" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)
