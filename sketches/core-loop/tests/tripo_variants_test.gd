extends SceneTree
# The Tripo-generated siblings (tools/tripo/README.md) load only behind --models=tripo, and each one
# keeps the contract its authored model has: the same node and socket names, the same material
# slots, and counts inside the authored model's ceilings. ModelVariants keeps the authored path
# when the switch is off or a model has no sibling.

const ModelVariants := preload("res://src/presentation/model_variants.gd")
const EnemyCasting := preload("res://src/combat/enemy_casting.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Accretion := preload("res://src/build/accretion.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")

# authored path -> {tris ceiling, draws ceiling}; -1 holds the sibling to the authored model's own count.
# The chaser's ceilings are enemy_chaser_asset_test.gd's; the pet's 2,000 is what the fitter targets
# (its enemy class allows 10,000). Scenery siblings must be no heavier than the authored prop, at every LOD.
const PAIRS := {
	"res://assets/models/world_one/enemy_chaser.glb": {"tris": 3400, "draws": 5},
	"res://assets/models/camp/camp_pet.glb": {"tris": 2000, "draws": 1},
	"res://assets/models/world_one/enemy_lobber.glb": {"tris": -1, "draws": -1},
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


# A node's transform up to (not including) the scene root, so an offset on a parent node counts.
func _to_root(n: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var at: Node = n
	while at != null and at != root:
		if at is Node3D:
			xf = (at as Node3D).transform * xf
		at = at.get_parent()
	return xf


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
	_check(PAIRS.size() == 19, "19 authored-sibling pairs checked (%d)" % PAIRS.size())
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
	_check_pilots()
	await _check_head_outfits()
	_check_poi_props()
	print("tripo_variants_test: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


# A ball part shows its own Tripo shape only with the switch on: one mesh under the cap and inside
# the part box, in the rarity material, on the tier foot. Off, or for a part with no file, the
# family primitive is drawn as before.
func _check_parts() -> void:
	var acc := Accretion.new()
	for id in ["slag_rounds", "focus_lens", "gatling_heart", "rime_heart", "sunforged_core", "horizon_optic", "tempest_core", "scrap_gravity",
			"magnet_spool", "storm_mast", "arc_coil", "long_barrel", "hot_rivets", "double_feed", "rime_rounds", "rivet_plating",
			"grounding_spike", "breaker_drive", "drop_weight", "relay_convergence", "galvanic_rounds", "tread_plating", "spark_tread", "ram_plow",
			"grip_tread", "long_spool", "spring_shims", "boost_coil", "slack_coil", "dash_vane", "frost_vane", "live_line",
			"winch_pawl", "riveted_shell", "cracked_plating", "thin_pickings", "load_dividend", "vent_baffle", "bladestorm_rotor", "spiral_wave",
			"runner_overclock", "pylon_capacitor", "spare_cell", "chain_arc", "cross_split", "loose_trigger"]:
		ModelVariants.set_enabled(true)
		var piece: Node3D = acc._piece(id)
		var own := piece.get_node_or_null("Own") as MeshInstance3D
		_check(own != null and own.material_override != null, "%s shows its own shape with the switch on" % id)
		ModelVariants.set_enabled(false)
		var plain_piece: Node3D = acc._piece(id)
		ModelVariants.set_enabled(true)
		var feet := func(node: Node3D) -> Array:
			var out := []
			for child in node.get_children():
				if String(child.name).begins_with("Foot_"):
					out.append(String(child.name))
			return out
		_check(feet.call(piece) == feet.call(plain_piece), "%s stands on the same tier foot as its primitive (%s)" % [id, feet.call(piece)])
		var rarity_mat := own.material_override as StandardMaterial3D if own != null else null
		var want: Color = Accretion.RARITY_COLORS.get(Accretion.ItemGen.resolve_rarity(Accretion.Parts.def(id).rarity), Color.BLACK)
		_check(rarity_mat != null and rarity_mat.albedo_color.is_equal_approx(want), "%s shape wears its rarity colour" % id)
		plain_piece.free()
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
	var plain: Node3D = acc._piece("admirals_crest")
	_check(plain.get_node_or_null("Own") == null and plain.get_child_count() > 0, "a part with no Tripo file keeps its family primitive with the switch on")
	plain.free()
	ModelVariants.set_enabled(false)
	acc.free()


# A pilot's Tripo sibling sits on the authored skeleton: the same bones (outfits mount on them and
# the glance turns three of them), the same clips, a skinned Pilot mesh, at most 10,000 triangles in all, and a
# rest shape inside the cockpit limits the ball look work measured on 13 November 2026 (head top
# +0.57, feet -0.59, half width 0.43, nothing forward of 0.58; tools/tripo/README.md, Pilots).
# Tarn's sibling keeps his cap as its own Cap mesh, as the authored model does, so his Steady Cap outfit's Replace_Cap
# hides it; a sibling may have no skinned mesh the authored model does not name. A sibling whose head is a different size
# carries a MountFit_head node that re-seats head outfits (hero_assets.gd, _mount_fit).
const PILOT_SIBLINGS := [
	"res://assets/models/pilot_rivet_anim.glb",
	"res://assets/models/pilot_sable_anim.glb",
	"res://assets/models/pilot_kest_anim.glb",
	"res://assets/models/pilot_tarn_anim.glb",
	"res://assets/models/pilot_tally_anim.glb",
	"res://assets/models/pilot_cannon_anim.glb",
]


func _check_pilots() -> void:
	_check(PILOT_SIBLINGS.size() == 6, "six pilot siblings (%d)" % PILOT_SIBLINGS.size())
	for authored in PILOT_SIBLINGS:
		var stem := String(authored).get_file()
		ModelVariants.set_enabled(false)
		_check(ModelVariants.path(authored) == authored, "switch off keeps %s" % stem)
		ModelVariants.set_enabled(true)
		var alt := ModelVariants.path(authored)
		_check(alt != authored, "switch on swaps %s for its sibling" % stem)
		var old := (load(authored) as PackedScene).instantiate()
		var new := (load(alt) as PackedScene).instantiate()
		var bones := func(root: Node) -> Array:
			var sk := root.find_children("*", "Skeleton3D", true, false)
			var out := []
			if not sk.is_empty():
				for i in (sk[0] as Skeleton3D).get_bone_count():
					out.append((sk[0] as Skeleton3D).get_bone_name(i))
			out.sort()
			return out
		var clips := func(root: Node) -> Array:
			var ap := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var out := Array(ap.get_animation_list()) if ap != null else []
			out.sort()
			return out
		var new_bones: Array = bones.call(new)
		_check(new_bones.size() == 25 and new_bones == bones.call(old), "%s sibling keeps the 25 bones (%d)" % [stem, new_bones.size()])
		var new_clips: Array = clips.call(new)
		_check(not new_clips.is_empty() and new_clips == clips.call(old), "%s sibling keeps every clip (%d)" % [stem, new_clips.size()])
		var skinned := []
		var authored_names := []
		for mi in old.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).skin != null:
				authored_names.append(String(mi.name))
		var strangers := []
		var tris := 0
		var draws_ok := true
		var box := AABB()
		for mi in new.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).skin == null:
				continue
			var part: Mesh = (mi as MeshInstance3D).mesh
			if not authored_names.has(String(mi.name)):
				strangers.append(String(mi.name))
			tris += _mesh_tris(part)
			draws_ok = draws_ok and part.get_surface_count() == 1
			box = part.get_aabb() if skinned.is_empty() else box.merge(part.get_aabb())
			skinned.append(mi)
		var body := new.find_child("Pilot", true, false) as MeshInstance3D
		_check(body != null and skinned.has(body) and strangers.is_empty(), "%s sibling has a skinned Pilot mesh and no skinned mesh the authored model lacks (%s)" % [stem, strangers])
		if body != null:
			_check(tris <= 10000, "%s sibling is at most 10,000 triangles (%d)" % [stem, tris])
			_check(draws_ok, "%s sibling is one draw a mesh (%d)" % [stem, skinned.size()])
			var slot := body.mesh.surface_get_material(0)
			_check(slot != null and slot.resource_name == "pilot", "%s sibling wears the pilot material slot (%s)" % [stem, slot.resource_name if slot != null else "none"])
			_check(box.end.y <= 0.575 and box.position.y >= -0.595 and maxf(absf(box.position.x), absf(box.end.x)) <= 0.435 and box.position.z >= -0.585,
				"%s sibling rests inside the cockpit limits (%s to %s)" % [stem, box.position, box.end])
		old.free()
		new.free()
	ModelVariants.set_enabled(false)


# A head outfit is built for the authored head. On a sibling with a bigger head it was buried (PC check of
# 14 November 2026: the Steady Cap changed 794 pixels and the Eyeshade 492). The sibling's MountFit_head node
# re-seats it: bigger by the node's size, and reaching past the skin around it. A sibling with no node (Rivet,
# whose hood already showed) mounts its outfit exactly as the authored pilot does.
const HEAD_OUTFITS := [
	{"pilot": "tarn", "outfit": "res://assets/cosmetics/outfits/outfit_tarn_steady_cap.glb", "mesh": "SteadyCap*", "fit": true},
	{"pilot": "tally", "outfit": "res://assets/cosmetics/outfits/outfit_tally_eyeshade.glb", "mesh": "Eyeshade*", "fit": true},
	{"pilot": "rivet", "outfit": "res://assets/cosmetics/outfits/outfit_rivet_hood.glb", "mesh": "HoodShell*", "fit": false},
]


func _check_head_outfits() -> void:
	for row in HEAD_OUTFITS:
		var boxes := {}
		var scale := 1.0
		for suffix in ["", "_tripo"]:
			var rig := (load("res://assets/models/pilot_%s_anim%s.glb" % [row.pilot, suffix]) as PackedScene).instantiate() as Node3D
			root.add_child(rig)
			var hero := HeroAssets.new()
			var mounts := hero.fit_outfit_scene(rig, row.outfit, {})
			await process_frame
			var worn := mounts[0].find_child(row.mesh, true, false) as MeshInstance3D if not mounts.is_empty() else null
			_check(worn != null, "%s%s wears its head outfit" % [row.pilot, suffix])
			if worn != null:
				boxes[suffix] = worn.global_transform * worn.get_aabb()
			var mark := rig.find_child("MountFit_head", true, false) as Node3D
			if suffix == "_tripo":
				_check((mark != null) == bool(row.fit), "%s sibling %s MountFit_head node" % [row.pilot, "carries a" if row.fit else "has no"])
				if mark != null:
					var sizes := mark.transform.basis.get_scale()
					scale = sizes.y
					_check(absf(sizes.x - sizes.y) < 0.005 * sizes.y and absf(sizes.z - sizes.y) < 0.005 * sizes.y, "%s sibling's MountFit_head node is one size on every axis (%s)" % [row.pilot, sizes])
				var cap := rig.find_child("Cap", true, false) as MeshInstance3D
				if row.pilot == "tarn":
					_check(cap != null and cap.layers == 0, "the Steady Cap hides the sibling's modelled Cap")
					if cap != null and worn != null:
						var under: AABB = cap.global_transform * cap.get_aabb()
						var over: AABB = boxes[suffix]
						_check(over.grow(0.01).encloses(AABB(Vector3(under.position.x, over.position.y, under.position.z), Vector3(under.size.x, 0.0, under.size.z))),
							"the Steady Cap covers where the modelled Cap sat (cap %s, steady %s)" % [under, over])
						_check(over.end.y > under.end.y - 0.01 and over.end.y < under.end.y + 0.03,
							"the Steady Cap's crown sits at the modelled Cap's crown, neither sunk nor floating (cap top %.3f, steady top %.3f)" % [under.end.y, over.end.y])
				if row.pilot == "tally" and worn != null:
					var skin := rig.find_child("Pilot", true, false) as MeshInstance3D
					var body: AABB = skin.global_transform * skin.get_aabb()
					var shade: AABB = boxes[suffix]
					_check(shade.position.z < body.position.z + 0.14 and shade.position.y > 0.3,
						"the Eyeshade's brim reaches the front of the sibling's head, above the glasses (front %.3f, body front %.3f, height %.3f)" % [shade.position.z, body.position.z, shade.position.y])
			hero.remove_outfit(rig)
			rig.queue_free()
			hero.free()
		if boxes.size() == 2:
			var ratio: float = (boxes["_tripo"] as AABB).size.x / (boxes[""] as AABB).size.x
			if row.fit:
				_check(scale > 1.05 and absf(ratio - scale) < 0.05 * scale, "%s's head outfit grows by the node's size (%.2f, node %.2f)" % [row.pilot, ratio, scale])
			else:
				_check((boxes["_tripo"] as AABB).is_equal_approx(boxes[""]), "%s's head outfit mounts as on the authored pilot" % row.pilot)


# The world 1 point of interest props have no authored twin (tools/tripo/README.md, "New props"). The loader that places them
# sets vertex colour as albedo, so each must be one mesh that carries COLOR_0, stands on its origin, and is the size its
# placement was planned for: [stem, tall in metres, longer ground side in metres, has LOD files].
const POI_PROPS := [
	["poi_tally_stand", 4.0, 3.0, true],
	["poi_yard_gate", 4.0, 8.0, true],
	["poi_camp_tally_post", 2.5, 1.2, true],
	["poi_fence_panel", 2.5, 6.2, false],
	["poi_survey_stake", 3.16, 0.88, false],
]


func _check_poi_props() -> void:
	for row in POI_PROPS:
		var tris := []
		for suffix in (["", "_lod1", "_lod2"] if row[3] else [""]):
			var scene := load("res://assets/models/world_one/%s%s.glb" % [row[0], suffix]) as PackedScene
			_check(scene != null, "%s%s loads" % [row[0], suffix])
			if scene == null:
				continue
			var node := scene.instantiate()
			var meshes := node.find_children("*", "MeshInstance3D", true, false)
			_check(meshes.size() == 1 and (meshes[0] as MeshInstance3D).mesh.get_surface_count() == 1, "%s%s is one mesh and one draw" % [row[0], suffix])
			if meshes.size() == 1:
				var mi := meshes[0] as MeshInstance3D
				var arrays := mi.mesh.surface_get_arrays(0)
				_check(arrays[Mesh.ARRAY_COLOR] != null and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() > 0, "%s%s carries vertex colours" % [row[0], suffix])
				_check(arrays[Mesh.ARRAY_TEX_UV] == null, "%s%s ships no texture coordinates" % [row[0], suffix])
				var box: AABB = _to_root(mi, node) * mi.mesh.get_aabb()
				tris.append(_mesh_tris(mi.mesh))
				if suffix == "":
					var mid := box.get_center()
					# the stake's pennant hangs to one side of its foot, so only the fitted props are held to the centre
					_check(absf(box.position.y) < 0.02 and (not row[3] or (absf(mid.x) < 0.05 and absf(mid.z) < 0.05)), "%s stands on its origin (base %.3f, centre %.3f, %.3f)" % [row[0], box.position.y, mid.x, mid.z])
					_check(absf(box.size.y - row[1]) < 0.1 and absf(maxf(box.size.x, box.size.z) - row[2]) < 0.1,
						"%s is the planned size (%.2f tall, %.2f across)" % [row[0], box.size.y, maxf(box.size.x, box.size.z)])
			node.free()
		if row[3] and tris.size() == 3:
			_check(tris[0] > tris[1] and tris[1] > tris[2], "%s LOD files step down (%s)" % [row[0], tris])

