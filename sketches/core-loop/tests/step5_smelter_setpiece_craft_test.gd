extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChunkSockets := preload("res://src/experimental/arena_chunk_socket.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const SetpieceCraft := preload("res://src/presentation/craft/experimental_setpiece_craft.gd")
const Lookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")

const CHUNK_PATH := "res://src/experimental/smelter_crane_chunk.tscn"
const DT := 1.0 / 30.0

var t := T.new("step5_smelter_setpiece_craft_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SetpieceCraft.reset_for_tests()
	await _check_chunk_craft_and_flat_floors()
	await _check_dynamic_setpieces_craft_and_topology()
	await _check_cargo_pendulum_sway_and_reduced_motion()
	SetpieceCraft.reset_for_tests()
	UiTokens.reduced_motion = false
	quit(t.verdict())


func _check_chunk_craft_and_flat_floors() -> void:
	var packed := load(CHUNK_PATH) as PackedScene
	t.check("chunk_scene_loaded", packed != null, CHUNK_PATH)
	if packed == null:
		return
	var chunk := packed.instantiate() as Node3D
	t.check("chunk_dressed_immediately_on_instantiate", chunk != null, "instantiated")
	root.add_child(chunk)
	await process_frame

	var val := ChunkSockets.validate_chunk(chunk)
	t.check("chunk_validator_passes", bool(val["ok"]), str(val["errors"]))
	t.eq("chunk_zero_lights", chunk.find_children("*", "Light3D", true, false).size(), 0)
	t.eq("chunk_18_sockets", ChunkSockets.discover_sockets(chunk).size(), 18)

	var audit := _audit_subtree(chunk, true)
	t.check("chunk_has_21_mesh_instances", int(audit["mesh_count"]) >= 21, "meshes=%d" % int(audit["mesh_count"]))
	t.eq("chunk_zero_primitive_meshes", int(audit["primitive_meshes"]), 0)
	t.eq("chunk_zero_bare_flat_standard_mats", int(audit["bare_flat_std_mats"]), 0)
	t.eq("chunk_zero_null_meshes", int(audit["null_meshes"]), 0)
	t.eq("chunk_zero_bad_basis_det", int(audit["bad_basis_det"]), 0)
	t.eq("chunk_zero_topology_errors", (audit["topology_errors"] as Array).size(), 0)
	if not (audit["topology_errors"] as Array).is_empty():
		print("CHUNK_TOPOLOGY_ERRORS: ", audit["topology_errors"])

	for deck_path: String in SetpieceCraft.WALKABLE_DECK_PATHS:
		var mi := chunk.get_node_or_null(deck_path) as MeshInstance3D
		t.check("walkable_deck_exists_" + deck_path.get_file(), mi != null and mi.mesh is ArrayMesh, deck_path)
		if mi == null or not (mi.mesh is ArrayMesh):
			continue
		var am := mi.mesh as ArrayMesh
		var mat := mi.get_surface_override_material(0) as ShaderMaterial
		t.check("walkable_deck_uses_combat_floor_shader_" + deck_path,
			mat != null and mat.shader != null and mat.shader.resource_path == Lookdev.FLOOR_SHADER_PATH,
			deck_path)
		var deck_check := _verify_flat_top_deck(am)
		t.check("walkable_deck_geometrically_flat_" + deck_path,
			bool(deck_check["ok"]),
			"path=%s detail=%s" % [deck_path, String(deck_check["detail"])])

	var crucible := chunk.get_node_or_null("Tier0_Basin/CrucibleWellRing") as MeshInstance3D
	t.check("crucible_ring_top_interior_calm_wear", crucible != null and _verify_crucible_calm_top(crucible.mesh as ArrayMesh), "flat ring top avoids high edge wear")

	root.remove_child(chunk)
	chunk.free()
	await process_frame


func _check_dynamic_setpieces_craft_and_topology() -> void:
	var chunk := (load(CHUNK_PATH) as PackedScene).instantiate() as Node3D
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	var info := setpieces.setup_from_chunk(chunk, {"seed": 5050})
	setpieces.trigger_setpiece(String(info["crane_id"]), "player")
	setpieces.trigger_setpiece(String(info["furnace_id"]), "player")
	setpieces.trigger_setpiece(String(info["compactor_id"]), "player")

	var checked_states := 0
	var worst_prims := 0
	var worst_bare := 0
	var worst_det := 0
	var topo_errors: Array[String] = []
	var saw_berms := false
	var saw_brittle_berms := false
	var saw_molten := false
	var saw_bridge := false

	for i in 220:
		setpieces.step(DT, Vector3(28.0, 0.5, 28.0), Vector3(15.0, 0.0, 0.0), 2)
		var snap := setpieces.snapshot()
		if bool(snap["crane"]["harpoon_bridge_open"]):
			saw_bridge = true
		if bool(snap["furnace"]["molten_active"]):
			saw_molten = true
		if int(snap["furnace"]["intact_berms"]) > 0:
			saw_berms = true
		if i == 0 or i == 55 or i == 110 or i == 185:
			var a := _audit_subtree(setpieces, false)
			checked_states += 1
			worst_prims = maxi(worst_prims, int(a["primitive_meshes"]))
			worst_bare = maxi(worst_bare, int(a["bare_flat_std_mats"]))
			worst_det = maxi(worst_det, int(a["bad_basis_det"]))
			for e: String in a["topology_errors"]:
				if not topo_errors.has(e):
					topo_errors.append(e)

	setpieces.trigger_setpiece(String(info["furnace_id"]), "player")
	for _j in 60:
		setpieces.step(DT, Vector3(28.0, 0.5, 28.0), Vector3.ZERO, 1)
	setpieces.trigger_setpiece(String(info["cryo_pipe_id"]), "player")
	if int(setpieces.snapshot()["furnace"]["intact_berms"]) > 0:
		saw_brittle_berms = true
		var ab := _audit_subtree(setpieces, false)
		worst_prims = maxi(worst_prims, int(ab["primitive_meshes"]))
		worst_bare = maxi(worst_bare, int(ab["bare_flat_std_mats"]))
		worst_det = maxi(worst_det, int(ab["bad_basis_det"]))
		for e: String in ab["topology_errors"]:
			if not topo_errors.has(e):
				topo_errors.append(e)

	t.check("setpieces_exercised_all_visual_states",
		checked_states >= 4 and saw_bridge and saw_molten and saw_berms and saw_brittle_berms,
		"states=%d bridge=%s molten=%s berms=%s brittle=%s" % [checked_states, saw_bridge, saw_molten, saw_berms, saw_brittle_berms])
	t.eq("setpieces_zero_primitive_meshes", worst_prims, 0)
	t.eq("setpieces_zero_bare_flat_standard_mats", worst_bare, 0)
	t.eq("setpieces_zero_bad_basis_det", worst_det, 0)
	t.eq("setpieces_zero_topology_errors", topo_errors.size(), 0)
	if not topo_errors.is_empty():
		print("SETPIECE_TOPOLOGY_ERRORS: ", topo_errors)

	var pool_mi := setpieces.find_child("MoltenSlagPool", true, false) as MeshInstance3D
	var pool_mat := pool_mi.get_active_material(0) as ShaderMaterial if pool_mi != null else null
	t.check("slag_pool_uses_dedicated_convection_shader",
		pool_mat != null and pool_mat.shader != null and pool_mat.shader.code.find("slag_fbm") != -1 and pool_mat.shader.code.find("vent_ribs") == -1,
		"organic convection shader with zero linear scanlines")

	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _check_cargo_pendulum_sway_and_reduced_motion() -> void:
	var chunk := (load(CHUNK_PATH) as PackedScene).instantiate() as Node3D
	var setpieces := DynamicSetpieces.new()
	root.add_child(chunk)
	root.add_child(setpieces)
	await process_frame

	UiTokens.reduced_motion = false
	var info := setpieces.setup_from_chunk(chunk, {"seed": 6060})
	setpieces.trigger_setpiece(String(info["crane_id"]), "player")

	var hull_body := setpieces.find_child("SalvageCargoHull", true, false) as StaticBody3D
	var hull_pivot := setpieces.find_child("CargoVisualPivot", true, false) as Node3D
	var hoist_root := setpieces.find_child("CargoHoistRigging", true, false) as Node3D
	t.check("cargo_visual_pivot_is_non_collider_child",
		hull_body != null and hull_pivot != null and hull_pivot.get_parent() == hull_body and not (hull_pivot is CollisionObject3D),
		"pivot under hull_body")
	t.check("cargo_hoist_rigging_hidden_when_idle_and_zero_colliders",
		hoist_root != null and not hoist_root.visible and hoist_root.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"hoist hidden at idle with zero colliders")

	var max_sway_rad := 0.0
	var warn_elapsed := 0.0
	var saw_hoist_visible := false
	for _i in 95:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
		var csnap: Dictionary = setpieces.snapshot()["crane"]
		if String(csnap["state"]) == "sweep_active":
			warn_elapsed = float(csnap["warn_elapsed"])
			if hoist_root.visible:
				saw_hoist_visible = true
			var ang := hull_pivot.basis.get_euler().length()
			max_sway_rad = maxf(max_sway_rad, ang)
			t.check("cargo_body_basis_stays_identity", hull_body.basis.is_equal_approx(Basis.IDENTITY), "collider untouched")

	t.check("cargo_hoist_rigging_visible_during_sweep", saw_hoist_visible, "hoist cables + trolley active")
	t.check("cargo_sway_active_under_normal_motion", max_sway_rad > 0.015 and max_sway_rad < 0.65, "max_sway=%.4f rad" % max_sway_rad)
	t.check("cargo_warn_floor_preserved", warn_elapsed >= DynamicSetpieces.MIN_WARN_FLOOR_S, "warn=%.2f s" % warn_elapsed)

	UiTokens.reduced_motion = true
	for _j in 4:
		setpieces.step(DT, Vector3(30.0, 0.5, 30.0), Vector3.ZERO, 2)
	var calm_rot := hull_pivot.basis.get_euler().length()
	var calm_pos := hull_pivot.position.length()
	t.check("cargo_reduced_motion_holds_exact_rest", calm_rot < 0.0001 and calm_pos < 0.0001,
		"rot=%.5f pos=%.5f" % [calm_rot, calm_pos])

	UiTokens.reduced_motion = false
	setpieces.teardown()
	root.remove_child(setpieces)
	root.remove_child(chunk)
	setpieces.free()
	chunk.free()
	await process_frame


func _audit_subtree(node_root: Node, require_shader_only: bool) -> Dictionary:
	var mesh_count := 0
	var prim_count := 0
	var null_count := 0
	var bare_std := 0
	var bad_det := 0
	var topo_errors: Array[String] = []
	var audited_meshes := {}

	var stack: Array[Node] = [node_root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Node3D:
			if (cur as Node3D).transform.basis.determinant() <= 0.0:
				bad_det += 1
		if cur is MeshInstance3D:
			mesh_count += 1
			var mi := cur as MeshInstance3D
			if mi.mesh == null:
				null_count += 1
			elif mi.mesh is PrimitiveMesh:
				prim_count += 1
			elif mi.mesh is ArrayMesh:
				var am := mi.mesh as ArrayMesh
				var mid := am.get_instance_id()
				if not audited_meshes.has(mid):
					audited_meshes[mid] = true
					var errs := _check_mesh_manifold(mi.name, am)
					topo_errors.append_array(errs)
				var scount := am.get_surface_count()
				for si in scount:
					var mat := mi.get_active_material(si)
					if mat == null:
						bare_std += 1
					elif mat is StandardMaterial3D:
						var sm := mat as StandardMaterial3D
						if require_shader_only or (sm.albedo_texture == null and not sm.normal_enabled):
							bare_std += 1
		for ch in cur.get_children():
			stack.append(ch)

	return {
		"mesh_count": mesh_count,
		"primitive_meshes": prim_count,
		"null_meshes": null_count,
		"bare_flat_std_mats": bare_std,
		"bad_basis_det": bad_det,
		"topology_errors": topo_errors,
	}


func _check_mesh_manifold(label: String, am: ArrayMesh) -> Array[String]:
	var errs: Array[String] = []
	var scount := am.get_surface_count()
	if scount <= 0:
		errs.append("%s: zero surfaces" % label)
		return errs
	for si in scount:
		var sname := am.surface_get_name(si)
		var fmt := am.surface_get_format(si)
		if (fmt & Mesh.ARRAY_FORMAT_COLOR) == 0:
			errs.append("%s[%s]: missing ARRAY_COLOR mask" % [label, sname])
		var arr := am.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT]
		var indices: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if verts.size() < 3 or norms.size() != verts.size() or uvs.size() != verts.size() or tangents.size() != verts.size() * 4:
			errs.append("%s[%s]: invalid vertex streams" % [label, sname])
			continue
		var tri_count := (indices.size() / 3) if not indices.is_empty() else (verts.size() / 3)
		var bad_winding := 0
		var bad_normal := 0
		var zero_area := 0
		var edge_counts := {}
		for ti in tri_count:
			var ia := indices[ti * 3] if not indices.is_empty() else ti * 3
			var ib := indices[ti * 3 + 1] if not indices.is_empty() else ti * 3 + 1
			var ic := indices[ti * 3 + 2] if not indices.is_empty() else ti * 3 + 2
			var a := verts[ia]
			var b := verts[ib]
			var c := verts[ic]
			var n := norms[ia]
			if not n.is_finite() or absf(n.length() - 1.0) > 0.02:
				bad_normal += 1
			var cross := (b - a).cross(c - a)
			if cross.length() < 1e-7:
				zero_area += 1
			if cross.dot(n) > 0.0001:
				bad_winding += 1
			var ka := _vkey(a)
			var kb := _vkey(b)
			var kc := _vkey(c)
			for e in [[ka, kb], [kb, kc], [kc, ka]]:
				var ek := _ekey(e[0], e[1])
				edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
		var open_edges := 0
		var non_manifold := 0
		for ek in edge_counts:
			var cnt: int = edge_counts[ek]
			if cnt == 1:
				open_edges += 1
			elif cnt > 2:
				non_manifold += 1
		if bad_winding > 0 or bad_normal > 0 or zero_area > 0 or open_edges > 0 or non_manifold > 0:
			errs.append("%s[%s]: winding=%d norm=%d zero=%d open=%d non_manifold=%d" % [
				label, sname, bad_winding, bad_normal, zero_area, open_edges, non_manifold
			])
	return errs


func _verify_flat_top_deck(am: ArrayMesh) -> Dictionary:
	var overall_max_y := -INF
	for si in am.get_surface_count():
		var verts: PackedVector3Array = am.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
		for v in verts:
			overall_max_y = maxf(overall_max_y, v.y)

	var deck_arr := am.surface_get_arrays(0)
	var dverts: PackedVector3Array = deck_arr[Mesh.ARRAY_VERTEX]
	var dnorms: PackedVector3Array = deck_arr[Mesh.ARRAY_NORMAL]
	var dind: PackedInt32Array = deck_arr[Mesh.ARRAY_INDEX] if deck_arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var deck_max_y := -INF
	for v in dverts:
		deck_max_y = maxf(deck_max_y, v.y)
	if overall_max_y > deck_max_y + 0.001:
		return {"ok": false, "detail": "protrusion above deck max_y=%.4f > deck=%.4f" % [overall_max_y, deck_max_y]}

	var top_tris := 0
	var bad_top_normals := 0
	var tri_count := (dind.size() / 3) if not dind.is_empty() else (dverts.size() / 3)
	for ti in tri_count:
		var ia := dind[ti * 3] if not dind.is_empty() else ti * 3
		var ib := dind[ti * 3 + 1] if not dind.is_empty() else ti * 3 + 1
		var ic := dind[ti * 3 + 2] if not dind.is_empty() else ti * 3 + 2
		var a := dverts[ia]
		var b := dverts[ib]
		var c := dverts[ic]
		if a.y >= deck_max_y - 0.002 and b.y >= deck_max_y - 0.002 and c.y >= deck_max_y - 0.002:
			top_tris += 1
			var geo_n := (c - a).cross(b - a).normalized()
			if geo_n.dot(Vector3.UP) < 0.9999 or dnorms[ia].dot(Vector3.UP) < 0.999 or dnorms[ib].dot(Vector3.UP) < 0.999 or dnorms[ic].dot(Vector3.UP) < 0.999:
				bad_top_normals += 1
	return {
		"ok": top_tris >= 2 and bad_top_normals == 0,
		"detail": "top_tris=%d bad_normals=%d deck_y=%.3f overall_y=%.3f" % [top_tris, bad_top_normals, deck_max_y, overall_max_y],
	}


func _verify_crucible_calm_top(am: ArrayMesh) -> bool:
	if am == null or am.get_surface_count() == 0:
		return false
	var arr := am.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	var interior_top := 0
	var noisy_top := 0
	for i in verts.size():
		var v := verts[i]
		var r := Vector2(v.x, v.z).length()
		if v.y > 0.19 and r > 11.02 and r < 12.08:
			interior_top += 1
			if cols[i].r > 0.25:
				noisy_top += 1
	return interior_top >= 24 and noisy_top == 0


static func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]


static func _ekey(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)
