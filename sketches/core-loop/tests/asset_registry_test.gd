extends SceneTree
# 2026-10-09 (VX-WIRE): the scan also reads .hdr, so the registry row for the Poly Haven sky (assets/sky) is held to "listed and present".

# Alpha R12 AB. Every .glb and texture under assets/ is listed in assets/registry.json with a budget class from
# assets/asset_budgets.json. A shipped model fails on any triangle, vertex or draw (surface) count over its class,
# or over its own exception in the registry. Counts are taken after Godot import, the way the per-asset tests take
# them: surface index count / 3 triangles, surface vertex count, one draw per surface. Env SCRAPKEEP_AB_MEASURE=1
# prints the table and fails nothing on caps, for deriving a cap from its members.
const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
const ROOT := "res://assets"
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _scan(dir: String, ext: Array, out: Array) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), ext, out)
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in ext:
			out.append(dir.path_join(f))


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _measure(path: String) -> Dictionary:
	var packed := load(path) as PackedScene
	if packed == null:
		return {}
	var node := packed.instantiate()
	var tris := 0
	var verts := 0
	var draws := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		# A "-col" mesh is the collision trimesh the park loader never draws (park_recipes.gd COL_SUFFIX), so it counts
		# toward triangles and vertices but not draws, as asset-inspect's collision_nodes (KC-INT, 2026-10-11).
		var collision := String(mi.name).ends_with("-col")
		for s in mi.mesh.get_surface_count():
			draws += 0 if collision else 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else pos.size()) / 3
			verts += pos.size()
	node.free()
	return {"tris": tris, "verts": verts, "draws": draws}


func _run() -> void:
	var measure_only := OS.get_environment("SCRAPKEEP_AB_MEASURE") == "1"
	var registry = _json(REGISTRY)
	var budgets = _json(BUDGETS)
	_check(registry is Dictionary and budgets is Dictionary, "registry and budget files parse")
	if failures > 0:
		quit(1)
		return
	var classes: Dictionary = budgets["classes"]
	var entries := {}
	for e in registry["assets"]:
		_check(not entries.has(e["path"]), "%s is listed once" % e["path"])
		entries[e["path"]] = e
		_check(classes.has(e["class"]) or e["class"] == "texture", "%s has a known class (%s)" % [e["path"], e["class"]])

	var found: Array = []
	_scan(ROOT, ["glb"], found)
	_scan(ROOT, ["webp", "png", "jpg", "jpeg", "hdr"], found)
	found.sort()
	for path in found:
		_check(entries.has(path), "%s is in the registry" % path)
	for path in entries:
		_check(path in found, "%s is listed and present" % path)
	var models := 0
	var textures := 0
	for path in found:
		if path.get_extension() == "glb":
			models += 1
		else:
			textures += 1
	print("found %d models, %d textures" % [models, textures])

	print("%-48s %-12s %-5s %7s %7s %5s | %7s %7s %5s" % ["asset", "class", "ships", "tris", "verts", "draws", "capT", "capV", "capD"])
	var max_side: int = int(budgets["texture"]["max_side"])
	for path in found:
		if not entries.has(path):
			continue
		var e: Dictionary = entries[path]
		if path.get_extension() != "glb":
			var img := Image.load_from_file(ProjectSettings.globalize_path(path))
			var side := maxi(img.get_width(), img.get_height()) if img != null else -1
			print("%-48s %-12s %-5s longest side %d, cap %d" % [path.trim_prefix(ROOT + "/"), "texture", str(e["ships"]), side, max_side])
			_check(side > 0 and side <= max_side, "%s longest side %d within %d" % [path, side, max_side])
			continue
		if not classes.has(e["class"]):
			continue
		var m := _measure(path)
		_check(not m.is_empty(), "%s imports as a scene" % path)
		if m.is_empty() or not e["ships"]:
			if not e["ships"]:
				print("%-48s %-12s %-5s (not shipped, not counted)" % [path.trim_prefix(ROOT + "/"), e["class"], "false"])
			continue
		var cap: Dictionary = classes[e["class"]].duplicate()
		var ex: Dictionary = e.get("exception", {})
		for k in ex:
			if cap.has(k):
				cap[k] = ex[k]
		print("%-48s %-12s %-5s %7d %7d %5d | %7d %7d %5d" % [path.trim_prefix(ROOT + "/"), e["class"], "true", m["tris"], m["verts"], m["draws"], cap["tris"], cap["verts"], cap["draws"]])
		if measure_only:
			continue
		_check(m["tris"] <= cap["tris"], "%s %d triangles within %d (%s)" % [path, m["tris"], cap["tris"], e["class"]])
		_check(m["verts"] <= cap["verts"], "%s %d vertices within %d (%s)" % [path, m["verts"], cap["verts"], e["class"]])
		_check(m["draws"] <= cap["draws"], "%s %d draws within %d (%s)" % [path, m["draws"], cap["draws"], e["class"]])
	print("asset_registry_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
