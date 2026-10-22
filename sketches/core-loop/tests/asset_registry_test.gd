extends SceneTree
# 2026-10-09 (VX-WIRE): the scan also reads .hdr, so the registry row for the Poly Haven sky (assets/sky) is held to "listed and present".

# Alpha R12 AB. Every .glb and texture under assets/ is listed in assets/registry.json with a budget class from
# assets/asset_budgets.json. A shipped model fails on any triangle, vertex or draw (surface) count over its class,
# or over its own exception in the registry. Counts are taken after Godot import, the way the per-asset tests take
# them: surface index count / 3 triangles, surface vertex count, one draw per surface. Env SCRAPKEEP_AB_MEASURE=1
# prints the table and fails nothing on class caps, for deriving a cap from its members; the w13-PD draw
# ceiling below still runs in that mode.
const REGISTRY := "res://assets/registry.json"
const BUDGETS := "res://assets/asset_budgets.json"
const ROOT := "res://assets"
# Draw ceilings (baked-bracket card, MOTION-SPEC row 208, wave 19; coordinator rulings 6348145961, 6348389397 and
# 6348497831 on #241, and 6348855434 for the five layers). w13-PD (docs/decisions.tsv, 2026-10-10T21:29:13) sets
# 16 draws for a pilot shell, 2 for a class III layer and 1 for every other layer. An asset over its ceiling passes only when
# it is named here with its decided figure, and then only at or under that figure. A new entry needs its own
# docs/decisions.tsv row, not a quiet exception.
const SHELL_DRAW_CEILING := 16
const LAYER_DRAW_CEILING_III := 2
const LAYER_DRAW_CEILING := 1
const DECIDED_OVER_CEILING := {
	"shell_tarn": {"draws": 17, "why": "docs/decisions.tsv 2026-10-10T23:14 w13-PD (Tarn 17: four articulated two-surface jaws; row 2026-10-11T00:16)"},
	"shell_tarn_redjaw_teeth": {"draws": 17, "why": "docs/decisions.tsv 2026-10-10T23:14 w13-PD (Tarn 17, same machinery; row 2026-10-11T00:16)"},
	"shell_tarn_c3": {"draws": 3, "why": "ruling 6348497831 on #241: class III layer at 3, ClawHooks banks; docs/decisions.tsv 2026-10-22T18:42"},
	"shell_cannon_c5": {"draws": 2, "why": "ruling 6348855434 on #241: PortHoods banks (1 to 2); docs/decisions.tsv 2026-10-22T19:02"},
	"shell_tally_c4": {"draws": 2, "why": "ruling 6348855434 on #241: DrumHoods banks (1 to 2); docs/decisions.tsv 2026-10-22T19:02"},
	"shell_tally_c5": {"draws": 2, "why": "ruling 6348855434 on #241: HeavyDrums banks (1 to 2); docs/decisions.tsv 2026-10-22T19:02"},
	"shell_tarn_c4": {"draws": 2, "why": "ruling 6348855434 on #241: ClawHooks banks (1 to 2); docs/decisions.tsv 2026-10-22T19:02"},
	"shell_tarn_c5": {"draws": 2, "why": "ruling 6348855434 on #241: ClawHooks banks (1 to 2); docs/decisions.tsv 2026-10-22T19:02"},
}
var failures := 0
var _layer_rule := RegEx.new()


func _initialize() -> void:
	_layer_rule.compile("^shell_[a-z]+_c([0-9])$")
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


# The ceiling for an asset id and class, or -1 when none applies. Shells get 16. A shell_<pilot>_c<N> layer gets 2 at
# class III and 1 at every other N; any other shell_ detail asset gets 1. Outfits and trails share the detail class and
# are not heft layers.
func _ceiling(id: String, cls: String) -> int:
	if cls == "shell":
		return SHELL_DRAW_CEILING
	if cls == "detail" and id.begins_with("shell_"):
		var m := _layer_rule.search(id)
		if m != null:
			return LAYER_DRAW_CEILING_III if m.get_string(1) == "3" else LAYER_DRAW_CEILING
		return LAYER_DRAW_CEILING
	return -1


# True when draws are over the asset's ceiling and the asset is not a named, decided exception that holds them.
func _over_ceiling(id: String, cls: String, draws: int) -> bool:
	var ceiling := _ceiling(id, cls)
	if ceiling < 0 or draws <= ceiling:
		return false
	if DECIDED_OVER_CEILING.has(id):
		return draws > int(DECIDED_OVER_CEILING[id]["draws"])
	return true


# The cap a registry row resolves to: its budget class with the row's own exception merged over it.
func _merged_cap(entry: Dictionary, classes: Dictionary) -> Dictionary:
	var cap: Dictionary = classes[entry["class"]].duplicate()
	var ex: Dictionary = entry.get("exception", {})
	for k in ex:
		if cap.has(k):
			cap[k] = ex[k]
	return cap


# The draw count a row is held to: a shell at its merged cap; a layer at what it draws or at its exception if higher, so the
# detail class cap of 2 does not loosen the layer rule.
func _held_draws(entry: Dictionary, classes: Dictionary, measured: int) -> int:
	var cap := _merged_cap(entry, classes)
	if entry["class"] == "shell":
		return int(cap["draws"])
	return maxi(measured, int(entry.get("exception", {}).get("draws", 0)))


func _self_check_ceiling() -> void:
	_check(_over_ceiling("planted_unnamed_shell", "shell", 17), "ceiling self-check: an unnamed shell at 17 draws is over")
	_check(not _over_ceiling("shell_tarn", "shell", 17), "ceiling self-check: named shell_tarn at 17 draws is not over")
	_check(_over_ceiling("shell_tarn", "shell", 18), "ceiling self-check: named shell_tarn at 18 draws is over")
	_check(not _over_ceiling("planted_unnamed_shell", "shell", 16), "ceiling self-check: an unnamed shell at 16 draws is not over")
	_check(_over_ceiling("shell_planted_c3", "detail", 3), "ceiling self-check: an unnamed class III layer at 3 draws is over")
	_check(not _over_ceiling("shell_planted_c3", "detail", 2), "ceiling self-check: an unnamed class III layer at 2 draws is not over")
	_check(_over_ceiling("shell_planted_c4", "detail", 2), "ceiling self-check: an unnamed class IV layer at 2 draws is over")
	_check(not _over_ceiling("shell_planted_c4", "detail", 1), "ceiling self-check: an unnamed class IV layer at 1 draw is not over")
	_check(not _over_ceiling("outfit_planted", "detail", 3), "ceiling self-check: a non-shell detail asset is outside the layer rule")
	_check(_over_ceiling("shell_planted_extra", "detail", 2), "ceiling self-check: an unnamed shell_ detail asset outside the layer pattern at 2 draws is over")
	_check(not _over_ceiling("shell_tarn_c3", "detail", 3), "ceiling self-check: named shell_tarn_c3 at 3 draws is not over")
	_check(_over_ceiling("shell_tarn_c3", "detail", 4), "ceiling self-check: named shell_tarn_c3 at 4 draws is over")
	_check(not _over_ceiling("shell_tarn_c4", "detail", 2), "ceiling self-check: named shell_tarn_c4 at 2 draws is not over")
	_check(_over_ceiling("shell_tarn_c4", "detail", 3), "ceiling self-check: named shell_tarn_c4 at 3 draws is over")
	# The control goes through the cap-merge code the scan uses: a layer row whose exception raises its draws to 2.
	var classes: Dictionary = _json(BUDGETS)["classes"]
	var planted := {"id": "shell_planted_c4", "path": "res://planted.glb", "class": "detail", "exception": {"draws": 2}}
	_check(_over_ceiling(planted["id"], planted["class"], _held_draws(planted, classes, 1)), "ceiling self-check: an unnamed class IV layer row with a 2-draw exception is over through the cap merge")


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
	_self_check_ceiling()
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
		var cap := _merged_cap(e, classes)
		var asset_id := String(e.get("id", path.get_file().get_basename()))
		var held := _held_draws(e, classes, int(m["draws"]))
		_check(not _over_ceiling(asset_id, e["class"], held), "%s %d draws within the %s ceiling or its named decision" % [asset_id, held, e["class"]])
		print("%-48s %-12s %-5s %7d %7d %5d | %7d %7d %5d" % [path.trim_prefix(ROOT + "/"), e["class"], "true", m["tris"], m["verts"], m["draws"], cap["tris"], cap["verts"], cap["draws"]])
		if measure_only:
			continue
		_check(m["tris"] <= cap["tris"], "%s %d triangles within %d (%s)" % [path, m["tris"], cap["tris"], e["class"]])
		_check(m["verts"] <= cap["verts"], "%s %d vertices within %d (%s)" % [path, m["verts"], cap["verts"], e["class"]])
		_check(m["draws"] <= cap["draws"], "%s %d draws within %d (%s)" % [path, m["draws"], cap["draws"], e["class"]])
	print("asset_registry_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
