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
	"res://assets/models/world_one/enemy_swatter.glb": {"tris": -1, "draws": -1},
	"res://assets/models/world_one/enemy_hooker.glb": {"tris": -1, "draws": -1},
	"res://assets/models/world_one/enemy_netcaster.glb": {"tris": -1, "draws": -1},
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
	"res://assets/models/park/props/dam/compressor_cart_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/compressor_cart_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/dam/compressor_cart_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/skiff_on_blocks_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/boom_crane_wreck_a_lod2.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/sluice_shed_a.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/sluice_shed_a_lod1.glb": {"tris": -1, "draws": -1},
	"res://assets/models/park/props/flume/sluice_shed_a_lod2.glb": {"tris": -1, "draws": -1},
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


# Ruling dr: a rejected sibling stays out under --models=tripo and loads under --models=tripo-all, and the
# registry rows say the same as ModelVariants.REJECTED.
func _check_accept(authored: String) -> void:
	var sibling := authored.get_basename() + "_tripo.glb"
	ModelVariants.set_rejected({sibling: "test"})
	_check(ModelVariants.path(authored) == authored, "a rejected sibling stays out with the switch on")
	_check(ModelVariants.only(sibling) == "", "a rejected part shape stays out with the switch on")
	ModelVariants.set_enabled(true, true)
	_check(ModelVariants.path(authored) == sibling, "--models=tripo-all loads a rejected sibling")
	_check(ModelVariants.only(sibling) == sibling, "--models=tripo-all loads a rejected part shape")
	ModelVariants.set_rejected()
	ModelVariants.set_enabled(true)
	_check(ModelVariants._rejected == ModelVariants.REJECTED and ModelVariants.accepted(sibling) == (not ModelVariants.REJECTED.has(sibling)),
		"the real list is back after the test")
	var rows := 0
	var said := {}
	var dir := DirAccess.open("res://assets/registry.d")
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/registry.d/" + file))
		for row in data["assets"]:
			var path := String(row["path"])
			if not path.ends_with("_tripo.glb"):
				continue
			rows += 1
			_check(row.has("accepted") and row["accepted"] is bool, "%s says whether it is accepted" % path.get_file())
			if row.get("accepted") == false:
				said[path] = String(row.get("accepted_why", ""))
				_check(said[path] != "", "%s gives the reason it is rejected" % path.get_file())
	_check(rows >= 74, "%d Tripo rows read from the registry (at least 74)" % rows)
	var listed: Array = ModelVariants.REJECTED.keys()
	var from_rows: Array = said.keys()
	listed.sort()
	from_rows.sort()
	_check(listed == from_rows, "ModelVariants.REJECTED %s matches the rejected registry rows %s" % [listed, from_rows])


func _run() -> void:
	ModelVariants.set_enabled(false)
	for authored in PAIRS:
		_check(ModelVariants.path(authored) == authored, "switch off keeps %s" % authored.get_file())
	ModelVariants.set_enabled(true)
	_check(ModelVariants.path("res://assets/models/camp/camp_bench.glb") == "res://assets/models/camp/camp_bench.glb",
		"switch on keeps a model that has no sibling")
	for authored in PAIRS:
		var alt := ModelVariants.path(authored)
		var sibling: String = authored.get_basename() + "_tripo.glb"
		if not ModelVariants.accepted(sibling):
			# a rejected sibling stays out of the game, but its file still ships and --models=tripo-all still loads it,
			# so it is held to the same contract below (ruling dr)
			_check(alt == authored, "switch on keeps the authored %s, its sibling is rejected" % authored.get_file())
			alt = sibling
		else:
			_check(alt == sibling, "switch on picks %s" % alt.get_file())
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
	_check(PAIRS.size() == 28, "28 authored-sibling pairs checked (%d)" % PAIRS.size())
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
	_check_accept(tender)
	ModelVariants.set_enabled(false)
	_check(_cast_tris(EnemyCasting.parts(tender, "tripo_test", true)) == _shape_of(tender).tris,
		"EnemyCasting.parts loads the authored boom tender with the switch off")
	_check(_mesh_tris(ParkProps._mesh(shed)) == _shape_of(shed).tris, "park_props loads the authored wheelhouse with the switch off")
	ParkProps.release_shared()
	_check_parts()
	_check_pilots()
	await _check_head_outfits()
	_check_poi_props()
	_check_tells()
	_check_bodies()
	_check_stand_ins()
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
		ModelVariants.set_enabled(true, true)  # every file is judged here, rejected or not (ruling dr)
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
		ModelVariants.set_enabled(true, true)  # every file is judged here, rejected or not (ruling dr)
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


# A warning must never read weaker than the one it replaces (the board, 14 November 2026): a part that carries an
# enemy's tell is at least as large on the sibling as on the authored model. [authored file, part node].
const TELLS := [
	["res://assets/models/world_one/enemy_lobber.glb", "LobberBulb"],
	["res://assets/models/world_one/enemy_swatter.glb", "SwatterPaddle"],
	["res://assets/models/world_one/enemy_hooker.glb", "HookerHarpoonMesh"],
]


func _part_reach(path: String, part: String) -> float:
	var scene := load(path) as PackedScene
	if scene == null:
		return -1.0
	var node := scene.instantiate()
	var mi := node.find_child(part, true, false) as MeshInstance3D
	var reach := -1.0
	if mi != null:
		for s in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
				reach = maxf(reach, v.length())
	node.free()
	return reach


func _check_tells() -> void:
	for row in TELLS:
		var authored := _part_reach(row[0], row[1])
		var sibling := _part_reach((row[0] as String).replace(".glb", "_tripo.glb"), row[1])
		_check(authored > 0.0 and sibling >= 0.98 * authored, "%s on the sibling reaches as far as the authored one (%.3f, authored %.3f)" % [row[1], sibling, authored])


# A crew enemy's body must stand out against the dam rock as the authored one does (the board's PC look of the
# swatter and the hooker, 14 November 2026): the body's mean brightness, weighted by area, is at least 95 percent
# of the authored body's. Brightness is the slot colour times the vertex colour, as the game paints the crew.
# [authored file, body node].
const BODIES := [
	["res://assets/models/world_one/enemy_swatter.glb", "SwatterBody"],
	["res://assets/models/world_one/enemy_hooker.glb", "HookerBody"],
	["res://assets/models/world_one/enemy_netcaster.glb", "NetcasterBody"],
]


func _part_brightness(path: String, part: String) -> float:
	var scene := load(path) as PackedScene
	if scene == null:
		return -1.0
	var node := scene.instantiate()
	var mi := node.find_child(part, true, false) as MeshInstance3D
	var total := 0.0
	var area := 0.0
	if mi != null and mi.mesh != null:
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			var base := mat.albedo_color if mat != null else Color.WHITE
			if cols.size() != verts.size():  # the crew is painted from vertex colour; a body that lost it must not read as bright
				node.free()
				return -1.0
			var count := index.size() if not index.is_empty() else verts.size()
			for t in range(0, count - 2, 3):
				var ids := [t, t + 1, t + 2] if index.is_empty() else [index[t], index[t + 1], index[t + 2]]
				var a := 0.5 * (verts[ids[1]] - verts[ids[0]]).cross(verts[ids[2]] - verts[ids[0]]).length()
				var c := base.srgb_to_linear()  # glTF vertex colour is linear; the imported slot colour is sRGB
				c = c * ((cols[ids[0]] + cols[ids[1]] + cols[ids[2]]) / 3.0)
				c = c.linear_to_srgb()
				total += a * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
				area += a
	node.free()
	return total / area if area > 0.0 else -1.0


# The mean above passed a hooker barrel the PC look of 14 November 2026 showed as a thin dark figure: a mean over the
# whole node is diluted by the authored mast, and it says nothing about how much of the body faces the camera. This
# measures the light the body sends to a chase camera instead: over every face turned to the camera, its area as the
# camera sees it times its painted brightness times a simple light (a key light from over the camera's shoulder and
# 0.35 of ambient). It is taken from four sides, looking 25 degrees down, and the worst side counts. Nothing hides
# anything here, so a face inside the body is counted too; it is a floor on a body that is too dark or too thin, not
# a render. The floor sits between what that PC look failed and passed: the failed hooker barrel sent 0.48 of the
# authored body's light, the swatter it passed 0.71 and the netcaster it passed 0.81. Three bodies set it, so a new
# body that lands near the floor still needs the PC look. It is not proof of brightness: the second hooker barrel
# measured 0.72 here and the PC look still showed it near-black, so that barrel was rejected (ruling dr)
# and a retry is judged from a lit render, not from this number. That render check is tools/model_render_check.gd;
# it also failed the netcaster this test had passed at 0.81. The cause was outside what this test reads: the
# generated faces read as fully in shadow in the second UV set (tools/tripo/README.md, "The bake"). Both bodies
# were refitted and pass the render check.
const SEEN_FLOOR := 0.65


func _part_seen(path: String, part: String) -> float:
	var scene := load(path) as PackedScene
	if scene == null:
		return -1.0
	var node := scene.instantiate()
	var mi := node.find_child(part, true, false) as MeshInstance3D
	var worst := -1.0
	if mi != null and mi.mesh != null:
		var to_root := _to_root(mi, node)
		for side in 4:
			var to_cam := Vector3(0.0, sin(deg_to_rad(25.0)), cos(deg_to_rad(25.0))).rotated(Vector3.UP, side * PI / 2.0)
			var to_light := (to_cam + Vector3(0.0, 0.8, 0.0)).normalized()
			var seen := 0.0
			for s in mi.mesh.get_surface_count():
				var arrays := mi.mesh.surface_get_arrays(s)
				var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
				var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
				var base := (mat.albedo_color if mat != null else Color.WHITE).srgb_to_linear()
				if cols.size() != verts.size() or normals.size() != verts.size():
					node.free()
					return -1.0
				var count := index.size() if not index.is_empty() else verts.size()
				for t in range(0, count - 2, 3):
					var ids := [t, t + 1, t + 2] if index.is_empty() else [index[t], index[t + 1], index[t + 2]]
					var a := 0.5 * (to_root.basis * (verts[ids[1]] - verts[ids[0]])).cross(to_root.basis * (verts[ids[2]] - verts[ids[0]])).length()
					var n := (to_root.basis * (normals[ids[0]] + normals[ids[1]] + normals[ids[2]])).normalized()
					var facing := n.dot(to_cam)
					if facing <= 0.0:
						continue
					var c := (base * ((cols[ids[0]] + cols[ids[1]] + cols[ids[2]]) / 3.0)).linear_to_srgb()
					seen += a * facing * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) * (0.35 + 0.65 * maxf(0.0, n.dot(to_light)))
			worst = seen if worst < 0.0 else minf(worst, seen)
	node.free()
	return worst


func _check_bodies() -> void:
	_check(BODIES.size() == 3, "3 crew bodies checked for brightness (%d)" % BODIES.size())
	for row in BODIES:
		var twin := (row[0] as String).replace(".glb", "_tripo.glb")
		var authored := _part_brightness(row[0], row[1])
		var sibling := _part_brightness(twin, row[1])
		_check(authored > 0.0 and sibling >= 0.95 * authored, "%s on the sibling is as bright as the authored one (%.3f, authored %.3f)" % [row[1], sibling, authored])
		var seen_authored := _part_seen(row[0], row[1])
		var seen := _part_seen(twin, row[1])
		_check(seen_authored > 0.0 and seen >= SEEN_FLOOR * seen_authored,
			"%s on the sibling sends the chase camera at least %.2f of the authored body's light from its worst side (%.2f, authored %.2f)" % [row[1], SEEN_FLOOR, seen, seen_authored])
		var lit_authored := _part_bake(row[0], row[1])
		var lit := _part_bake(twin, row[1])
		_check(lit_authored > 0.0 and lit >= 0.8 * lit_authored,
			"%s on the sibling is no deeper in baked shadow than the authored one (worst surface %.2f out of shadow, authored %.2f)" % [row[1], lit, lit_authored])


# The share of a body out of baked shadow: the mean x of the second UV set (the polish bake bake_look.gd multiplies
# the paint by), on the surface where it is lowest. A surface with no second set is not shaded and counts as 1. The
# hooker barrel and the netcaster torso of 14 November 2026 read 0.00 on their rust paint and rendered near-black
# while the two checks above passed them.
func _part_bake(path: String, part: String) -> float:
	var scene := load(path) as PackedScene
	if scene == null:
		return -1.0
	var node := scene.instantiate()
	var mi := node.find_child(part, true, false) as MeshInstance3D
	var worst := -1.0
	if mi != null and mi.mesh != null:
		worst = 1.0
		for s in mi.mesh.get_surface_count():
			var uv2 = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV2]
			if uv2 == null or (uv2 as PackedVector2Array).is_empty():
				continue
			var sum := 0.0
			for uv in (uv2 as PackedVector2Array):
				sum += uv.x
			worst = minf(worst, sum / (uv2 as PackedVector2Array).size())
	node.free()
	return worst


# A prop kind's variants are placed at random (park_props.gd expand), and only variant a has a generated sibling, so a
# same-sized sister stands in for b and c with the switch on (park_props.gd _stand_in). The PC look of 14 November 2026
# found the nearest sluice shed, a variant b, unchanged by the switch.
func _check_stand_ins() -> void:
	var flume := ParkProps.load_json("res://assets/models/park/props/flume/manifest.json")
	var dam := ParkProps.load_json("res://assets/models/park/props/dam/manifest.json")
	var shed_a: Array = flume["kinds"]["sluice_shed"]["variants"]["a"]["lod"]
	var shed_b: Array = flume["kinds"]["sluice_shed"]["variants"]["b"]["lod"]
	var tent_b: Array = dam["kinds"]["survey_tent"]["variants"]["b"]["lod"]
	ModelVariants.set_rejected({})  # the rule is tested on the sluice shed whether or not its generated model is accepted today
	ModelVariants.set_enabled(false)
	_check(ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "b"}) == shed_b, "switch off: a variant b sluice shed draws its own model")
	ParkProps.release_shared()
	var authored_tris := _mesh_tris(ParkProps._mesh(ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "b"})[0]))
	ModelVariants.set_enabled(true)
	ParkProps.release_shared()
	for v in ["a", "b", "c"]:
		var lods: Array = ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": v})
		_check(lods == shed_a, "switch on: a variant %s sluice shed draws variant a's models" % v)
		var tris := _mesh_tris(ParkProps._mesh(lods[0]))
		_check(tris == _shape_of(ModelVariants.path(shed_a[0])).tris and (v == "a" or tris != authored_tris),
			"switch on: the variant %s sluice shed's mesh is the generated one (%d triangles, authored b %d)" % [v, tris, authored_tris])
	_check(ParkProps._lod_paths(dam, {"kind": "survey_tent", "v": "b"}) == tent_b, "switch on: the low survey tent b keeps its own model, variant a is too tall to stand in")
	ModelVariants.set_rejected({ModelVariants.path(shed_a[0]): "test"})
	_check(ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "b"}) == shed_b, "a rejected sibling does not stand in for its sisters")
	ModelVariants.set_rejected({ModelVariants.path(shed_a[2]): "test"})
	_check(ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "b"}) == shed_b and ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "a"}) == shed_a,
		"a sister with one far detail level rejected does not stand in")
	ModelVariants.set_rejected({})
	_check(ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": "b"}) == shed_a, "the kept answer is dropped when the rejected list changes back")
	# the width rule, on a made-up kind: a sister 1.2 times as wide stays out, one 1.05 times as wide stands in
	var wide := {"a": {"lod": shed_a, "radius": 6.0, "height": 5.0}, "b": {"lod": shed_b, "radius": 5.0, "height": 5.0}}
	_check(ParkProps._find_stand_in(wide, "b") == shed_b, "a sister 1.2 times as wide does not stand in")
	wide["a"]["radius"] = 5.25
	_check(ParkProps._find_stand_in(wide, "b") == shed_a, "a sister 1.05 times as wide stands in")
	ModelVariants.set_rejected()
	var shed_rejected := false
	for lod in shed_a:
		shed_rejected = shed_rejected or not ModelVariants.accepted(String(lod).get_basename() + ModelVariants.SUFFIX + ".glb")
	if shed_rejected:
		var kept := true
		for v in ["a", "b", "c"]:
			kept = kept and ParkProps._lod_paths(flume, {"kind": "sluice_shed", "v": v}) == flume["kinds"]["sluice_shed"]["variants"][v]["lod"]
		_check(kept, "with the shipped rejected list, no sluice shed variant draws another variant's model")
	ParkProps.release_shared()
	ModelVariants.set_enabled(false)


# The world 1 point of interest props have no authored twin (tools/tripo/README.md, "New props"). The loader that places them
# sets vertex colour as albedo, so each must be one mesh that carries COLOR_0, stands on its origin, and is the size its
# placement was planned for: [stem, tall in metres, longer ground side in metres, has LOD files]. A fifth true marks a
# piece that is thrown and spun, so its origin is its centre and not its foot.
const POI_PROPS := [
	["poi_tally_stand", 4.0, 3.0, true],
	["poi_yard_gate", 4.0, 8.0, true],
	["poi_camp_tally_post", 2.5, 1.2, true],
	["poi_fence_panel", 2.5, 6.2, false],
	["poi_survey_stake", 3.16, 0.88, false],
	["poi_weighbridge_gantry", 7.0, 12.0, true],
	["poi_ring_flag", 2.0, 1.27, false],
	["poi_siren_mast", 6.0, 2.66, false],
	["poi_furnace_stacks", 60.2, 46.6, false],
	["poi_tagged_crate", 1.2, 1.27, false],
	["poi_tagged_crate_piece_a", 0.8, 0.71, false, true],
	["poi_tagged_crate_piece_b", 0.66, 0.94, false, true],
	["poi_tagged_crate_piece_c", 0.1, 0.96, false, true],
	["poi_tagged_crate_piece_d", 0.52, 0.46, false, true],
	["poi_req_locker", 2.5, 3.0, false],
	["poi_req_locker_door", 1.8, 2.56, false],
	["poi_tag_rack", 3.03, 3.0, false],
	["poi_tag_rack_leaning", 3.66, 4.57, false],
	["poi_scooter_shed", 3.0, 4.0, false],
	["poi_scooter", 1.04, 1.61, false],
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
					if row.size() > 4 and row[4]:
						_check(mid.length() < 0.1 and absf(mid.y) < 0.04, "%s turns about its centre (%.3f from its origin)" % [row[0], mid.length()])
					else:
						_check(absf(box.position.y) < 0.02 and (not row[3] or (absf(mid.x) < 0.05 and absf(mid.z) < 0.05)), "%s stands on its origin (base %.3f, centre %.3f, %.3f)" % [row[0], box.position.y, mid.x, mid.z])
					_check(absf(box.size.y - row[1]) < 0.1 and absf(maxf(box.size.x, box.size.z) - row[2]) < 0.1,
						"%s is the planned size (%.2f tall, %.2f across)" % [row[0], box.size.y, maxf(box.size.x, box.size.z)])
			node.free()
		if row[3] and tris.size() == 3:
			_check(tris[0] > tris[1] and tris[1] > tris[2], "%s LOD files step down (%s)" % [row[0], tris])

