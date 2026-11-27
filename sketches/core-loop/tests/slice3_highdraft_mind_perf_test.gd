extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChunkCraft := preload("res://src/presentation/world23_chunk_craft.gd")
const ArenaChunkSocket := preload("res://src/experimental/arena_chunk_socket.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const QuietGun := preload("res://src/presentation/quiet_gun.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const HighdraftFx := preload("res://src/presentation/highdraft_fx.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const KiteDrone := preload("res://src/combat/kite_drone.gd")
const GapNet := preload("res://src/combat/gap_net.gd")
const GyroJammer := preload("res://src/combat/gyro_jammer.gd")
const Deflector := preload("res://src/combat/deflector.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const CustomizePage := preload("res://src/ui/customize_page.gd")
const EndingSequence := preload("res://src/ui/ending_sequence.gd")
const Palette := preload("res://src/core/palette.gd")

const COMPACTOR_PATH := "res://src/experimental/compactor_canyon_chunk.tscn"
const ORBITAL_PATH := "res://src/experimental/orbital_graveyard_chunk.tscn"

var _t := T.new("slice3_highdraft_mind_perf_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_w3_assets_and_enemies()
	_check_chunk(COMPACTOR_PATH, "compactor_canyon_v1", ChunkCraft.COMPACTOR_CANYON_SPECS.size(), ChunkCraft.COMPACTOR_WALKABLE_PATHS)
	_check_chunk(ORBITAL_PATH, "orbital_graveyard_v1", ChunkCraft.ORBITAL_GRAVEYARD_SPECS.size(), ChunkCraft.ORBITAL_WALKABLE_PATHS)
	_check_perf_fixes()
	ChunkCraft.reset_for_tests()
	quit(_t.verdict())


func _is_flat_bare_standard(mat: Material) -> bool:
	if not (mat is StandardMaterial3D):
		return false
	var sm := mat as StandardMaterial3D
	if sm.albedo_texture == null and not sm.normal_enabled and sm.roughness_texture == null and not sm.vertex_color_use_as_albedo:
		return true
	return false


func _audit_manifold(mesh: ArrayMesh) -> Dictionary:
	var open_edges := 0
	var non_manifold := 0
	var bad_winding := 0
	var total_tris := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		total_tris += tri_count
		var edge_counts := {}
		for ti in tri_count:
			var i0 := idx[ti * 3] if idx.size() > 0 else ti * 3
			var i1 := idx[ti * 3 + 1] if idx.size() > 0 else ti * 3 + 1
			var i2 := idx[ti * 3 + 2] if idx.size() > 0 else ti * 3 + 2
			var v0 := verts[i0]
			var v1 := verts[i1]
			var v2 := verts[i2]
			var k0 := _vkey(v0)
			var k1 := _vkey(v1)
			var k2 := _vkey(v2)
			for pair in [[k0, k1], [k1, k2], [k2, k0]]:
				var a := String(pair[0])
				var b := String(pair[1])
				var ek := (a + "|" + b) if a < b else (b + "|" + a)
				edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
			if norms.size() == verts.size():
				var gn := (v2 - v0).cross(v1 - v0)
				if gn.length_squared() > 1e-10:
					var vn := (norms[i0] + norms[i1] + norms[i2]).normalized()
					if gn.normalized().dot(vn) < 0.0:
						bad_winding += 1
		for c in edge_counts.values():
			if int(c) == 1:
				open_edges += 1
			elif int(c) > 2:
				non_manifold += 1
	return {
		"ok": open_edges == 0 and non_manifold == 0 and bad_winding == 0 and total_tris > 0,
		"open": open_edges,
		"non_manifold": non_manifold,
		"bad_winding": bad_winding,
		"tris": total_tris,
	}


func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0)]


func _check_tree_craft(label: String, node: Node, allow_no_light: bool = false) -> void:
	var prims: Array[String] = []
	var bare_mats: Array[String] = []
	var bad_basis: Array[String] = []
	var lights := 0
	var meshes_checked := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Light3D:
			lights += 1
		if cur is Node3D and (cur as Node3D).transform.basis.determinant() <= 0.0:
			bad_basis.append(String(cur.name))
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				meshes_checked += 1
				if mi.mesh is PrimitiveMesh:
					prims.append(String(mi.name) + ":" + mi.mesh.get_class())
				if mi.material_override != null:
					if _is_flat_bare_standard(mi.material_override):
						bare_mats.append(String(mi.name) + ":override")
				elif mi.mesh is ArrayMesh:
					var am := mi.mesh as ArrayMesh
					for s in am.get_surface_count():
						var sm := mi.get_surface_override_material(s)
						if sm == null:
							sm = am.surface_get_material(s)
						if sm == null or _is_flat_bare_standard(sm):
							bare_mats.append("%s:s%d" % [String(mi.name), s])
		for child in cur.get_children():
			stack.append(child)
	_t.check("%s has zero PrimitiveMesh (%d checked)" % [label, meshes_checked], prims.is_empty() and meshes_checked > 0, str(prims))
	_t.check("%s has zero bare flat StandardMaterial3D" % label, bare_mats.is_empty(), str(bare_mats))
	_t.check("%s has positive basis determinant everywhere" % label, bad_basis.is_empty(), str(bad_basis))
	if allow_no_light:
		_t.eq("%s has zero Light3D nodes" % label, lights, 0)


func _check_w3_assets_and_enemies() -> void:
	var saved_housing := QuietGun.housing_path
	QuietGun.housing_path = "res://tests/no_quiet_gun_housing.glb"
	var gun = QuietGun.make("pylon_engineer")
	QuietGun.housing_path = saved_housing
	root.add_child(gun)
	_check_tree_craft("QuietGun cold", gun, true)
	gun.light_next()
	_check_tree_craft("QuietGun lit", gun, true)
	_t.eq("QuietGun fallback barrel preserves VERDIGRIS material color", gun.barrel.get_node("BarrelHousing").mesh.material.albedo_color, Palette.VERDIGRIS)
	_t.eq("QuietGun lit band preserves ANCIENT color", gun.bands[0].mesh.surface_get_material(0).albedo_color, Palette.ANCIENT)
	gun.free()

	var panel := MindDress.build_takeover_panel()
	root.add_child(panel)
	_check_tree_craft("MindDress TakeoverPanel", panel, true)
	panel.free()

	var aura := GapNet.ElectricAura.new()
	root.add_child(aura)
	aura.setup(null, 2.0, 4.0, 5.0)
	_check_tree_craft("GapNet ElectricAura", aura, true)
	aura.free()

	var w3_meshes := {
		"quiet_gun_cradle": ChunkCraft.get_quiet_gun_cradle_mesh(),
		"quiet_gun_barrel": ChunkCraft.get_quiet_gun_barrel_mesh(),
		"quiet_gun_band_cold": ChunkCraft.get_quiet_gun_band_mesh(false, 0.34),
		"quiet_gun_band_lit": ChunkCraft.get_quiet_gun_band_mesh(true, 0.34),
		"quiet_gun_plug": ChunkCraft.get_quiet_gun_plug_mesh(),
		"takeover_bezel": ChunkCraft.get_takeover_bezel_mesh(),
		"takeover_plate": ChunkCraft.get_takeover_plate_mesh(),
		"cloud_sea": ChunkCraft.get_cloud_sea_mesh(1600.0),
		"thermal_mote": ChunkCraft.get_thermal_mote_mesh(),
		"mind_hand_foot": ChunkCraft.get_mind_hand_foot_mesh(),
		"mind_hand_rod": ChunkCraft.get_mind_hand_rod_mesh(0.14, 0.18, 1.6),
		"mind_hand_lens": ChunkCraft.get_mind_hand_lens_mesh(0.5),
		"kite_chassis": ChunkCraft.get_kite_chassis_mesh(),
		"kite_wake": ChunkCraft.get_kite_wake_mesh(12.0),
		"gap_net_aura": ChunkCraft.get_gap_net_aura_mesh(1.52),
		"gap_net_post": ChunkCraft.get_gap_net_post_mesh(3.2),
		"gap_net_panel": ChunkCraft.get_gap_net_panel_mesh(8.0, 4.0),
		"gyro_jammer_chassis": ChunkCraft.get_gyro_jammer_chassis_mesh(),
		"deflector_vault_rim": ChunkCraft.get_deflector_vault_rim_mesh(1.6, 0.12),
	}
	var bad_topo: Array[String] = []
	for key in w3_meshes:
		var rep := _audit_manifold(w3_meshes[key] as ArrayMesh)
		if not bool(rep["ok"]):
			bad_topo.append("%s:%s" % [key, str(rep)])
	_t.check("all 19 W3/Mind/Enemy procedural ArrayMeshes are watertight closed manifolds", bad_topo.is_empty(), str(bad_topo))

	var saved_mh := MindHand.model_path
	MindHand.model_path = "res://tests/no_mind_hand.glb"
	var mh := MindHand.new()
	root.add_child(mh)
	mh._build_crew()
	MindHand.model_path = saved_mh
	var mh_prims := mh.find_children("*", "MeshInstance3D", true, false).filter(func(m: MeshInstance3D) -> bool: return m.mesh is PrimitiveMesh)
	_t.eq("MindHand fallback has zero PrimitiveMesh", mh_prims.size(), 0)
	mh.free()

	var defl := Deflector.new()
	root.add_child(defl)
	defl._build_rim(ChunkCraft.get_kite_chassis_mesh())
	_t.check("Deflector VaultRim uses sculpted ArrayMesh + textured PBR", defl._rim != null and defl._rim.mesh is ArrayMesh and not _is_flat_bare_standard(defl._rim_material))
	defl.free()


func _check_chunk(path: String, expected_id: String, expected_meshes: int, walkable_paths: Array) -> void:
	var packed := load(path) as PackedScene
	if not _t.check("chunk scene loads: " + expected_id, packed != null):
		return
	var chunk := packed.instantiate()
	root.add_child(chunk)
	_t.eq(expected_id + " chunk_id metadata", String(chunk.get_meta("chunk_id", "")), expected_id)
	_check_tree_craft(expected_id, chunk, true)

	var dressed_count := 0
	var bad_manifold: Array[String] = []
	for mi: MeshInstance3D in chunk.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is ArrayMesh:
			dressed_count += 1
			var rep := _audit_manifold(mi.mesh as ArrayMesh)
			if not bool(rep["ok"]):
				bad_manifold.append("%s:%s" % [String(mi.name), str(rep)])
	_t.check("%s dresses all %d sculpted meshes" % [expected_id, expected_meshes], dressed_count >= expected_meshes, "got %d" % dressed_count)
	_t.check("%s every mesh is watertight closed manifold" % expected_id, bad_manifold.is_empty(), str(bad_manifold))

	var flat_ok := true
	var flat_err := ""
	for rel: String in walkable_paths:
		var mi := chunk.get_node_or_null(rel) as MeshInstance3D
		if mi == null or not (mi.mesh is ArrayMesh):
			flat_ok = false
			flat_err = "missing deck " + rel
			break
		var am := mi.mesh as ArrayMesh
		var arrays := am.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var max_y := -INF
		for v in verts:
			max_y = maxf(max_y, v.y)
		var top_tris := 0
		var tri_count := idx.size() / 3 if idx.size() > 0 else verts.size() / 3
		for ti in tri_count:
			var i0 := idx[ti * 3] if idx.size() > 0 else ti * 3
			var i1 := idx[ti * 3 + 1] if idx.size() > 0 else ti * 3 + 1
			var i2 := idx[ti * 3 + 2] if idx.size() > 0 else ti * 3 + 2
			if verts[i0].y >= max_y - 0.005 and verts[i1].y >= max_y - 0.005 and verts[i2].y >= max_y - 0.005:
				top_tris += 1
				var gn := (verts[i2] - verts[i0]).cross(verts[i1] - verts[i0]).normalized()
				if gn.dot(Vector3.UP) < 0.9999:
					flat_ok = false
					flat_err = "%s skewed geo normal %s" % [rel, str(gn)]
					break
				for vi in [i0, i1, i2]:
					if norms[vi].dot(Vector3.UP) < 0.999:
						flat_ok = false
						flat_err = "%s skewed vert normal %s" % [rel, str(norms[vi])]
						break
		if top_tris == 0:
			flat_ok = false
			flat_err = "no top tris on " + rel
	_t.check("%s walkable combat decks are geometrically flat (+Y)" % expected_id, flat_ok, flat_err)

	var report := ArenaChunkSocket.validate_chunk(chunk)
	_t.check("%s passes 10-point ArenaChunkSocket validation" % expected_id, bool(report["ok"]), str(report["errors"]))
	_t.check("%s has >= 18 sockets across 3 tiers with 0 floating nav polys" % expected_id,
		int(report["metrics"]["socket_count"]) >= 18
		and int(report["metrics"]["populated_tiers"]) == 3
		and int(report["metrics"]["nav_floating_polygons"]) == 0
		and bool(report["metrics"]["has_three_tier_cycle"]),
		str(report["metrics"]))

	var sp := DynamicSetpieces.new()
	chunk.add_child(sp)
	var wired := sp.setup_from_chunk(chunk)
	_t.check("%s wires cleanly into DynamicSetpieces" % expected_id,
		wired.has("crane_id") and wired.has("furnace_id") and wired.has("compactor_id") and wired.has("cryo_pipe_id") and int(wired.get("cover_slot_count", 0)) >= 3,
		str(wired))
	chunk.free()


func _check_perf_fixes() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var row := {
		"id": "perf_anchor_test",
		"element": "anchor_field",
		"at": [0.0, 0.0],
		"y": 0.0,
		"size": [48.0, 14.0, 24.0],
		"yaw_deg": 0.0,
		"recipe": "",
		"stamp": "",
		"budget": "detail",
	}
	var placed := ParkRecipes.place_anchor_field(row, holder)
	var posts := placed.get_node_or_null("Posts") as MultiMeshInstance3D
	_t.check("ParkRecipes Posts MultiMesh has visibility_range_end in 240..300m, begin_margin=0, cast_shadow=OFF",
		posts != null
		and posts.visibility_range_end >= 240.0 and posts.visibility_range_end <= 300.0
		and posts.visibility_range_begin_margin == 0.0
		and posts.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"end=%.1f bm=%.1f sh=%d" % [posts.visibility_range_end, posts.visibility_range_begin_margin, posts.cast_shadow] if posts != null else "null")
	holder.free()

	var cp = CustomizePage.new()
	cp.visible = false
	root.add_child(cp)
	_t.eq("CustomizePage hidden SubViewport starts UPDATE_DISABLED", cp._viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	cp.show()
	cp._sync_viewport_update_mode()
	_t.eq("CustomizePage visible SubViewport uses UPDATE_WHEN_VISIBLE", cp._viewport.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE)
	cp.hide()
	_t.eq("CustomizePage re-hidden SubViewport returns to UPDATE_DISABLED", cp._viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	cp.free()

	var seq = EndingSequence.new()
	root.add_child(seq)
	seq.visible = false
	seq._build_view()
	_t.eq("EndingSequence hidden SubViewport starts UPDATE_DISABLED", seq.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	seq.active = true
	seq.visible = true
	_t.eq("EndingSequence active+visible SubViewport uses UPDATE_WHEN_VISIBLE", seq.viewport.render_target_update_mode, SubViewport.UPDATE_WHEN_VISIBLE)
	seq.cancel()
	_t.eq("EndingSequence cancel disables SubViewport", seq.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	seq.free()

	_t.check("BakeWarm includes World 3 kits and Mind rigs",
		BakeWarm.WORLD_KITS.has(3) and BakeWarm.WORLD_RIGS.has(3))
	BakeWarm.warm_mind_shaders()
	_t.check("BakeWarm.warm_mind_shaders runs cleanly", BakeWarm._warm.has("mind_shaders_cpu"))
	BakeWarm.settle()
	ParkRecipes._reset()
	ChunkCraft._reset()
	_t.check("ParkRecipes._reset and ChunkCraft._reset clear static caches", ParkRecipes._anchor_lod_cache.is_empty() and ChunkCraft._mesh_cache.is_empty())
