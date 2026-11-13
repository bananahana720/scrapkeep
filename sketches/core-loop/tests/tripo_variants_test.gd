extends SceneTree
# The Tripo-generated siblings (tools/tripo/README.md) load only behind --models=tripo, and each one
# keeps the contract its authored model has: the same node and socket names, the same material
# slots, and counts inside the authored model's ceilings. ModelVariants keeps the authored path
# when the switch is off or a model has no sibling.

const ModelVariants := preload("res://src/presentation/model_variants.gd")
const EnemyCasting := preload("res://src/combat/enemy_casting.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Accretion := preload("res://src/build/accretion.gd")

# authored path -> {tris ceiling, draws ceiling}; -1 holds the sibling to the authored model's own count.
# The chaser's ceilings are enemy_chaser_asset_test.gd's; the pet's 2,000 is what the fitter targets
# (its enemy class allows 10,000). Scenery siblings must be no heavier than the authored prop, at every LOD.
const PAIRS := {
	"res://assets/models/world_one/enemy_chaser.glb": {"tris": 3400, "draws": 5},
	"res://assets/models/camp/camp_pet.glb": {"tris": 2000, "draws": 1},
	"res://assets/models/world_one/enemy_boom_tender.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/gate_wheelhouse_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/gate_wheelhouse_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/gate_wheelhouse_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/mixer_wreck_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/mixer_wreck_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/mixer_wreck_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/survey_tent_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/survey_tent_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/survey_tent_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a_lod2.glb": {"tris": -1, "draws": -1},
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


func _shape_of(path: String) -> Dictionary:
	var node := (load(path) as PackedScene).instantiate()
	var out := _shape(node)
	node.free()
	return out


func _mesh_tris(mesh: Mesh) -> int:
	var tris := 0
	if mesh == null:
		return -1
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris


func _cast_tris(parts: Array) -> int:
	var tris := 0
	for part in parts:
		tris += _mesh_tris(part.mesh)
	return tris


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
		var cap: Dictionary = PAIRS[authored].duplicate()
		if cap.tris < 0:
			cap.tris = a.tris
		if cap.draws < 0:
			cap.draws = a.draws
		_check(t.tris <= cap.tris, "%s sibling triangles %d <= %d (authored %d)" % [authored.get_file(), t.tris, cap.tris, a.tris])
		_check(t.draws <= cap.draws, "%s sibling draws %d <= %d (authored %d)" % [authored.get_file(), t.draws, cap.draws, a.draws])
		a_node.free()
		t_node.free()
	_check(PAIRS.size() == 18, "18 authored-sibling pairs checked (%d)" % PAIRS.size())
	# The game's own load sites must reach the sibling, not only ModelVariants.path: the shared enemy
	# caster and the park prop mesh cache, each compared by triangle count with the sibling file.
	var tender := "res://assets/models/world_one/enemy_boom_tender.glb"
	_check(_cast_tris(EnemyCasting.parts(tender, "tripo_test", true)) == _shape_of(ModelVariants.path(tender)).tris,
		"EnemyCasting.parts loads the boom tender sibling with the switch on")
	var shed := "res://assets/models/park/props/dam/gate_wheelhouse_a.glb"
	ParkProps.release_shared()
	_check(_mesh_tris(ParkProps._mesh(shed)) == _shape_of(ModelVariants.path(shed)).tris,
		"park_props loads the wheelhouse sibling with the switch on")
	ParkProps.release_shared()
	ModelVariants.set_enabled(false)
	_check(_cast_tris(EnemyCasting.parts(tender, "tripo_test", true)) == _shape_of(tender).tris,
		"EnemyCasting.parts loads the authored boom tender with the switch off")
	_check(_mesh_tris(ParkProps._mesh(shed)) == _shape_of(shed).tris, "park_props loads the authored wheelhouse with the switch off")
	ParkProps.release_shared()
	_check_parts()
	print("tripo_variants_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


# A ball part shows its own Tripo shape only with the switch on: one mesh under the cap and inside
# the part box, in the rarity material, on the tier foot. Off, or for a part with no file, the
# family primitive is drawn as before.
func _check_parts() -> void:
	var acc := Accretion.new()
	for id in ["slag_rounds", "focus_lens", "gatling_heart", "rime_heart"]:
		ModelVariants.set_enabled(true)
		var piece: Node3D = acc._piece(id)
		var own := piece.get_node_or_null("Own") as MeshInstance3D
		_check(own != null and own.material_override != null, "%s shows its own shape with the switch on" % id)
		if own != null:
			var box := own.mesh.get_aabb()
			_check(_mesh_tris(own.mesh) <= 1000, "%s shape is at most 1,000 triangles (%d)" % [id, _mesh_tris(own.mesh)])
			_check(box.position.y > -0.01 and box.end.y <= 0.66 and maxf(box.size.x, box.size.z) <= 0.61,
				"%s shape stands on the origin inside the part box (%s)" % [id, box.size])
			_check(own.mesh.get_surface_count() == 1, "%s shape is one draw" % id)
		piece.free()
		ModelVariants.set_enabled(false)
		piece = acc._piece(id)
		_check(piece.get_node_or_null("Own") == null and piece.get_child_count() > 0, "%s draws its family primitive with the switch off" % id)
		piece.free()
	ModelVariants.set_enabled(true)
	var plain: Node3D = acc._piece("double_feed")
	_check(plain.get_node_or_null("Own") == null and plain.get_child_count() > 0, "a part with no Tripo file keeps its family primitive with the switch on")
	plain.free()
	ModelVariants.set_enabled(false)
	acc.free()
