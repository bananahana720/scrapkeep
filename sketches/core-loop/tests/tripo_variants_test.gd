extends SceneTree
# The Tripo-generated siblings (tools/tripo/README.md) load only behind --models=tripo, and each one
# keeps the contract its authored model has: the same node and socket names, the same material
# slots, and counts inside the authored model's ceilings. ModelVariants keeps the authored path
# when the switch is off or a model has no sibling.

const ModelVariants := preload("res://src/presentation/model_variants.gd")

# authored path -> {tris ceiling, draws ceiling} (the chaser's from enemy_chaser_asset_test.gd,
# the pet's from its enemy class in assets/asset_budgets.json, held to the 2,000 the fitter targets)
const PAIRS := {
	"res://assets/models/world_one/enemy_chaser.glb": {"tris": 3400, "draws": 5},
	"res://assets/models/camp/camp_pet.glb": {"tris": 2000, "draws": 1},
}

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _shape(node: Node) -> Dictionary:
	var names := {}
	var slots := {}
	var tris := 0
	var draws := 0
	for child in node.find_children("*", "", true, false):
		names[String(child.name)] = true
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var own := []
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := mi.mesh.surface_get_material(s)
			own.append(mat.resource_name if mat != null else "")
		own.sort()
		slots[String(child.name)] = own
	return {"names": names, "slots": slots, "tris": tris, "draws": draws}


func _run() -> void:
	ModelVariants.set_enabled(false)
	for authored in PAIRS:
		_check(ModelVariants.path(authored) == authored, "switch off keeps %s" % authored.get_file())
	ModelVariants.set_enabled(true)
	_check(ModelVariants.path("res://assets/models/camp/camp_bench.glb") == "res://assets/models/camp/camp_bench.glb",
		"switch on keeps a model that has no sibling")
	for authored in PAIRS:
		var alt := ModelVariants.path(authored)
		_check(alt == authored.get_basename() + "_tripo.glb", "switch on picks %s" % alt.get_file())
		var a_scene := load(authored) as PackedScene
		var t_scene := load(alt) as PackedScene
		_check(a_scene != null and t_scene != null, "%s and its sibling load" % authored.get_file())
		if a_scene == null or t_scene == null:
			continue
		var a_node := a_scene.instantiate()
		var t_node := t_scene.instantiate()
		var a := _shape(a_node)
		var t := _shape(t_node)
		var missing := []
		for n in a.names:
			if not t.names.has(n):
				missing.append(n)
		_check(missing.is_empty(), "%s sibling keeps every node and socket name (missing %s)" % [authored.get_file(), missing])
		var slot_diff := []
		for n in a.slots:
			if t.slots.has(n) and t.slots[n] != a.slots[n]:
				slot_diff.append("%s %s vs %s" % [n, t.slots[n], a.slots[n]])
		_check(slot_diff.is_empty(), "%s sibling keeps each part's material slots %s" % [authored.get_file(), slot_diff])
		var cap: Dictionary = PAIRS[authored]
		_check(t.tris <= cap.tris, "%s sibling triangles %d <= %d (authored %d)" % [authored.get_file(), t.tris, cap.tris, a.tris])
		_check(t.draws <= cap.draws, "%s sibling draws %d <= %d (authored %d)" % [authored.get_file(), t.draws, cap.draws, a.draws])
		a_node.free()
		t_node.free()
	ModelVariants.set_enabled(false)
	print("tripo_variants_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
