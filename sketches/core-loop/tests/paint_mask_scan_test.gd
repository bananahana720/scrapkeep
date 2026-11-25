extends SceneTree

# The paint shader reads vertex alpha as a take mask (step(0.05, alpha)): alpha 0 keeps a part's baked
# colour under any paint. This scan pins who may carry a mask. On every shipped shell_* and pilot_* GLB a paint
# vertex with alpha under 0.05 must be exactly 0 and sit in Sable's SpoolKit or Tally's DrumBrackets or Flywheel_R (its brass
# rims and index slot, wave 46 unit E2-05); every other paint vertex is 1 or one of Tally's window-index alphas. A planted
# vertex built in code proves the scan flags a stray mask.

const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ROOT := "res://assets/models"
const MASK_BELOW := 0.05
const WINDOWS := [0.2, 0.4, 0.6, 0.8]
const TOL := 0.01
const MIN_SURFACES := 40
const MIN_VERTICES := 1000

var _checks := 0
var _failures := 0


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


static func _allowed(a: float, mesh_name: String, path: String) -> bool:
	if a < MASK_BELOW:
		var file := path.get_file()
		return a == 0.0 and ((mesh_name == "SpoolKit" and file.begins_with("shell_sable"))
			or (mesh_name in ["DrumBrackets", "Flywheel_R"] and file.begins_with("shell_tally")))
	if absf(a - 1.0) < 0.001:
		return true
	return WINDOWS.any(func(w): return absf(a - w) < TOL)


# One entry per mesh with paint vertices that break the rule: "<file> <mesh>: <n> stray vertices".
# seen, when given, accumulates "surfaces" and "vertices" of paint scanned.
static func scan_mesh(path: String, mesh_name: String, mesh: Mesh, seen: Dictionary = {}) -> Array:
	var out := []
	if mesh == null:
		return ["%s %s: null mesh" % [path.get_file(), mesh_name]]
	var bad := 0
	for i in mesh.get_surface_count():
		if HeroAssets.slot_of(mesh, i) != "paint":
			continue
		seen["surfaces"] = seen.get("surfaces", 0) + 1
		var cols = mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]
		for c in Array(cols if cols != null else []):
			seen["vertices"] = seen.get("vertices", 0) + 1
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


func _planted(path: String, mesh_name: String, alpha: float) -> Array:
	var verts := PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0)])
	var cols := PackedColorArray([Color(1, 1, 1, alpha), Color.WHITE, Color.WHITE])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.resource_name = "paint"
	mesh.surface_set_material(0, mat)
	return scan_mesh(path, mesh_name, mesh)


func _initialize() -> void:
	var planted := _planted("res://assets/models/world_one/shell_sable.glb", "PlantedMesh", 0.0)
	_report("scan flags planted mask", planted.size() == 1 and "PlantedMesh" in planted[0] and "1 stray" in planted[0],
		"alpha-0 vertex on a non-Sable paint mesh gives %s" % [planted])
	var spool_elsewhere := _planted("res://assets/models/world_one/shell_tally.glb", "SpoolKit", 0.0)
	_report("scan flags SpoolKit outside Sable", spool_elsewhere.size() == 1 and "SpoolKit" in spool_elsewhere[0],
		"alpha-0 SpoolKit in a non-Sable file gives %s" % [spool_elsewhere])
	var ambiguous := _planted("res://assets/models/world_one/shell_sable.glb", "SpoolKit", 0.02)
	_report("scan flags alpha 0.02", ambiguous.size() == 1 and "1 stray" in ambiguous[0],
		"alpha 0.02 in Sable SpoolKit (not exactly 0) gives %s" % [ambiguous])
	var brackets_elsewhere := _planted("res://assets/models/world_one/shell_tarn.glb", "DrumBrackets", 0.0)
	_report("scan flags DrumBrackets outside Tally", brackets_elsewhere.size() == 1 and "DrumBrackets" in brackets_elsewhere[0],
		"alpha-0 DrumBrackets in a non-Tally file gives %s" % [brackets_elsewhere])
	var brackets_in_tally := _planted("res://assets/models/world_one/shell_tally.glb", "DrumBrackets", 0.0)
	_report("scan allows Tally DrumBrackets", brackets_in_tally.is_empty(), "alpha-0 DrumBrackets in shell_tally gives %s" % [brackets_in_tally])
	var null_mesh := scan_mesh("res://assets/models/world_one/shell_sable.glb", "Gone", null)
	_report("scan survives a null mesh", null_mesh.size() == 1 and "null mesh" in null_mesh[0], "null mesh records %s" % [null_mesh])
	var seen := {}
	var files := _files(ROOT)
	var stray := []
	var spool := 0
	var drum_brackets := 0
	for f in files:
		var packed := load(f) as PackedScene
		if packed == null:
			stray.append("%s did not load" % f.get_file())
			continue
		var root := packed.instantiate()
		for mi in _meshes(root):
			stray.append_array(scan_mesh(f, String(mi.name), mi.mesh, seen))
			if String(mi.name) == "SpoolKit":
				spool += 1
			if String(mi.name) == "DrumBrackets":
				drum_brackets += 1
		root.free()
	_report("shell GLBs scanned", files.size() >= 40 and spool == 2 and drum_brackets == 2,
		"%d shell/pilot GLBs, %d SpoolKit meshes, %d DrumBrackets meshes" % [files.size(), spool, drum_brackets])
	_report("paint scanned", seen.get("surfaces", 0) >= MIN_SURFACES and seen.get("vertices", 0) >= MIN_VERTICES,
		"%d paint surfaces, %d paint vertices scanned (floor %d and %d)" % [seen.get("surfaces", 0), seen.get("vertices", 0), MIN_SURFACES, MIN_VERTICES])
	_report("no stray paint mask", stray.is_empty(), "paint alpha under 0.05 only in Sable SpoolKit and Tally DrumBrackets and Flywheel_R, else 1 or a Tally window (%s)" % [stray])
	print("paint_mask_scan_test: %s, %d checks" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 else 1)
