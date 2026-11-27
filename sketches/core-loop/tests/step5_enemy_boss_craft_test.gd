extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const Arena := preload("res://src/boss/arena.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const Target := preload("res://src/boss/boss_target.gd")
const Dispatcher := preload("res://src/combat/dispatcher.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Reactor := preload("res://src/combat/warden_reactor.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossHarness := preload("res://tests/doubles/boss_harness.gd")

var t := T.new("step5_enemy_boss_craft_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	EnemyBossCraft.reset_for_tests()
	UiTokens.reduced_motion = false
	EnemyMotion.motion_scale = 1.0
	_check_craft_library()
	_check_arena_and_vents()
	await _check_live_boss_dispatcher_miniboss_reactor()
	UiTokens.reduced_motion = false
	EnemyMotion.motion_scale = 1.0
	EnemyBossCraft.reset_for_tests()
	quit(t.verdict())


static func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)]


static func _ekey(a: String, b: String) -> String:
	return (a + "|" + b) if a < b else (b + "|" + a)


func _audit_mesh(label: String, mesh: ArrayMesh, require_rgb: bool, require_emissive: bool) -> void:
	t.check("%s is non-empty ArrayMesh" % label, mesh != null and mesh is ArrayMesh and mesh.get_surface_count() >= 1)
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var bad_winding := 0
	var bad_normal := 0
	var zero_area := 0
	var open_edges := 0
	var non_manifold := 0
	var missing_uv := 0
	var missing_tan := 0
	var missing_col := 0
	var max_r := 0.0
	var max_g := 0.0
	var max_b := 0.0
	var total_verts := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uvs = arr[Mesh.ARRAY_TEX_UV]
		var tans = arr[Mesh.ARRAY_TANGENT]
		var cols = arr[Mesh.ARRAY_COLOR]
		total_verts += verts.size()
		if uvs == null or (uvs as PackedVector2Array).size() != verts.size():
			missing_uv += 1
		if tans == null or (tans as PackedFloat32Array).size() != verts.size() * 4:
			missing_tan += 1
		if require_rgb:
			if cols == null or (cols as PackedColorArray).size() != verts.size():
				missing_col += 1
			else:
				for c: Color in cols as PackedColorArray:
					max_r = maxf(max_r, c.r)
					max_g = maxf(max_g, c.g)
					max_b = maxf(max_b, c.b)
		var edge_counts := {}
		var i := 0
		while i + 2 < verts.size():
			var a := verts[i]
			var b := verts[i + 1]
			var c := verts[i + 2]
			var n := norms[i]
			if not n.is_finite() or absf(n.length() - 1.0) > 0.03:
				bad_normal += 1
			var cross := (b - a).cross(c - a)
			if cross.length() < 1e-7:
				zero_area += 1
			if cross.dot(n) > 0.0002:
				bad_winding += 1
			var ka := _vkey(a)
			var kb := _vkey(b)
			var kc := _vkey(c)
			for e in [[ka, kb], [kb, kc], [kc, ka]]:
				var ek := _ekey(e[0], e[1])
				edge_counts[ek] = int(edge_counts.get(ek, 0)) + 1
			i += 3
		for ek in edge_counts:
			var cnt: int = edge_counts[ek]
			if cnt == 1:
				open_edges += 1
			elif cnt > 2:
				non_manifold += 1
	var rgb_ok := not require_rgb or (missing_col == 0 and max_r > 0.65 and max_g > 0.45 and (not require_emissive or max_b > 0.70))
	t.check("%s watertight outward manifold with UVs, tangents, RGB masks" % label,
		total_verts >= 12 and bad_winding == 0 and bad_normal == 0 and zero_area == 0
		and open_edges == 0 and non_manifold == 0 and missing_uv == 0 and missing_tan == 0 and rgb_ok,
		"v=%d wind=%d norm=%d deg=%d open=%d nm=%d uv=%d tan=%d col=%d rgb=(%.2f,%.2f,%.2f)" % [
			total_verts, bad_winding, bad_normal, zero_area, open_edges, non_manifold,
			missing_uv, missing_tan, missing_col, max_r, max_g, max_b])


func _check_basis_det_positive(label: String, node: Node) -> void:
	var bad := []
	for child in node.find_children("*", "Node3D", true, false):
		var n := child as Node3D
		if n.transform.basis.determinant() <= 0.0:
			bad.append(n.name)
	t.check("%s all node bases have det > 0" % label, bad.is_empty(), str(bad))


func _check_craft_library() -> void:
	var cases := [
		["brindle_hull_mesh", func(): return EnemyBossCraft.brindle_hull_mesh(Requisition.HULL), true, false],
		["brindle_armour_plate", func(): return EnemyBossCraft.brindle_armour_plate(Vector3(0.4, 3.2, 6.0)), true, false],
		["brindle_cockpit_canopy", func(): return EnemyBossCraft.brindle_cockpit_canopy(Vector3(3.0, 2.2, 3.0)), true, false],
		["brindle_cockpit_console", func(): return EnemyBossCraft.brindle_cockpit_console(Vector3(1.2, 1.0, 1.0)), true, true],
		["brindle_vent_cap", func(): return EnemyBossCraft.brindle_vent_cap(1.1, 0.8), true, false],
		["brindle_crane_post", func(): return EnemyBossCraft.brindle_crane_post(Vector3(0.8, 3.0, 0.8)), true, false],
		["brindle_magnet_housing", func(): return EnemyBossCraft.brindle_magnet_housing(1.4, 0.9), true, true],
		["quench_vent_basin", func(): return EnemyBossCraft.quench_vent_basin(3.5), true, true],
		["dispatch_mast_assembly", func(): return EnemyBossCraft.dispatch_mast_assembly(8.0, 1.6, Vector3(3.6, 0.3, 3.6)), true, false],
		["dispatch_pod", func(): return EnemyBossCraft.dispatch_pod(0.55, 1.65), true, true],
		["reactor_spillway_chute", func(): return EnemyBossCraft.reactor_spillway_chute(24.0, 16.0), true, true],
		["reward_canister_band", func(): return EnemyBossCraft.reward_canister_band(0.405, 0.12), true, false],
		["requisition_cable_mesh", func(): return Requisition._cable_mesh(), false, false],
	]
	for row in cases:
		var fn: Callable = row[1]
		var m: ArrayMesh = fn.call()
		_audit_mesh(String(row[0]), m, bool(row[2]), bool(row[3]))
	var before := EnemyBossCraft.dispatch_pod(0.55, 1.65)
	var again := EnemyBossCraft.dispatch_pod(0.55, 1.65)
	t.check("EnemyBossCraft caches built meshes", before == again)
	EnemyBossCraft.reset_for_tests()
	var after := EnemyBossCraft.dispatch_pod(0.55, 1.65)
	t.check("EnemyBossCraft.reset_for_tests clears cache", before != after)


func _check_arena_and_vents() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var prims := []
	var vents := []
	for mi: MeshInstance3D in arena.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh:
			prims.append(mi.name)
		if String(mi.name).begins_with("WaterVent"):
			vents.append(mi)
	t.check("Slag Bowl arena has 0 PrimitiveMesh across all meshes", prims.is_empty(), str(prims))
	t.check("Slag Bowl builds 4 sculpted WaterVent basins with ShaderMaterial",
		vents.size() == 4 and vents.all(func(v: MeshInstance3D): return v.mesh is ArrayMesh and v.material_override is ShaderMaterial),
		"vents=%d" % vents.size())
	_check_basis_det_positive("SlagBowl", arena)
	arena.free()


func _check_live_boss_dispatcher_miniboss_reactor() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await physics_frame
	game.ctx.spawner = game.combat
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	BossHarness.start_run(game)
	BossHarness.enter(game, Vector3(18.0, 0.0, 0.0))
	await physics_frame
	await physics_frame

	var ship = game.boss.ship
	var ship_prims := []
	for mi: MeshInstance3D in ship.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh:
			ship_prims.append(mi.name)
	t.check("live Brindle Requisition has 0 PrimitiveMesh across entire subtree", ship_prims.is_empty(), str(ship_prims))
	_check_basis_det_positive("Requisition", ship)

	var armour0 := ship.model.find_child("Armour0", true, false) as MeshInstance3D
	var plate_mat := armour0.get_surface_override_material(0) as StandardMaterial3D if armour0 != null else null
	t.check("Brindle Armour0 uses weathered plate material with triplanar texture, grain, and BakeLook edge lift",
		plate_mat != null and plate_mat.albedo_texture != null and plate_mat.normal_enabled and plate_mat.next_pass != null,
		"mat=%s" % [plate_mat])

	var cable0: MeshInstance3D = ship._cables[0]
	var cable_arr := (cable0.mesh as ArrayMesh).surface_get_arrays(0)
	t.check("Brindle cable mesh carries UVs and tangents",
		cable_arr[Mesh.ARRAY_TEX_UV] != null and cable_arr[Mesh.ARRAY_TANGENT] != null)

	var mag_target = ship.magnets[0]
	var mag_radius: float = mag_target.radius
	var mag_hh: float = mag_target.half_height
	var rig = ship.magnet_motion_rig(0)
	t.check("Brindle crane magnet binds PropMotionRig to visual child only",
		rig != null and rig.part_count() == 1 and rig.part("magnet_0").node != mag_target)
	var rest_basis: Basis = rig.part("magnet_0").rest_basis
	var p0: Vector3 = ship.magnet_rest(0)
	ship.set_magnet(0, p0, 0.0)
	ship.step_magnet_motion(1.0 / 60.0)
	var moved_pos: Vector3 = p0 + Vector3(1.8, 0.0, 0.0)
	for step_i in 12:
		var p_step: Vector3 = p0 + Vector3(float(step_i + 1) * 0.28, 0.0, 0.0)
		ship.set_magnet(0, p_step, 0.0)
		ship.step_magnet_motion(1.0 / 60.0)
		moved_pos = p_step
	var tilted_basis: Basis = rig.part("magnet_0").node.basis
	var tilt_angle := rest_basis.get_rotation_quaternion().angle_to(tilted_basis.get_rotation_quaternion())
	t.check("Brindle crane magnet visual swings with pendulum lag while Target hit-sphere stays exact",
		tilt_angle > 0.02 and mag_target.global_position.is_equal_approx(moved_pos)
		and is_equal_approx(mag_target.radius, mag_radius) and is_equal_approx(mag_target.half_height, mag_hh),
		"tilt=%.4f rad pos_ok=%s" % [tilt_angle, mag_target.global_position.is_equal_approx(moved_pos)])

	UiTokens.reduced_motion = true
	ship.step_magnet_motion(1.0 / 60.0)
	var calm_basis: Basis = rig.part("magnet_0").node.basis
	t.check("Brindle crane magnet pendulum resets cleanly under UiTokens.reduced_motion",
		rest_basis.get_rotation_quaternion().angle_to(calm_basis.get_rotation_quaternion()) < 0.001)
	UiTokens.reduced_motion = false
	game.boss.exit_arena()
	await physics_frame

	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	var disp_at := Vector3(spawn.x + 12.0, game.ctx.terrain.height(spawn.x + 12.0, spawn.z), spawn.z)
	var disp = game.combat.spawn_enemy("dispatcher", disp_at)
	disp.set_physics_process(false)
	var mast_prims := []
	for mi: MeshInstance3D in disp.mast.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh:
			mast_prims.append(mi.name)
	var mast_shapes: Array = disp.mast.find_children("*", "CollisionShape3D", true, false)
	t.check("Dispatcher mast has 0 PrimitiveMesh and preserves both layer-1 colliders",
		mast_prims.is_empty() and disp.mast.get_node_or_null("DispatchMastMesh") != null
		and mast_shapes.size() == 2 and disp.mast.collision_layer == 1,
		"prims=%s shapes=%d" % [mast_prims, mast_shapes.size()])
	_check_basis_det_positive("DispatchMast", disp.mast)

	disp._commit(Vector3(10.0, 0.0, 0.0))
	disp.phase = disp.Phase.WARN
	disp._t = Dispatcher.SUCK + 0.15
	disp._pose()
	t.check("Dispatcher DispatchPod is sculpted 2-surface ArrayMesh with det > 0",
		disp._pod != null and disp._pod.mesh is ArrayMesh and (disp._pod.mesh as ArrayMesh).get_surface_count() == 2
		and disp._pod.global_basis.determinant() > 0.0)
	disp.free()

	var mb_at := Vector3(spawn.x - 14.0, game.ctx.terrain.height(spawn.x - 14.0, spawn.z) + Miniboss.HALF_HEIGHT, spawn.z)
	var mb = game.combat.spawn_enemy("miniboss", mb_at)
	mb.set_physics_process(false)
	await process_frame
	var mb_prims := []
	for mi: MeshInstance3D in mb.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is PrimitiveMesh:
			mb_prims.append(mi.name)
	t.check("Miniboss has 0 PrimitiveMesh and preserves BakeLook edge lift on _model_plate_material",
		mb_prims.is_empty() and mb._model_plate_material != null and mb._model_plate_material.next_pass != null)
	var rig_skel: Skeleton3D = mb._pose_rig
	var body_bone := rig_skel.find_bone("MinibossBody")
	var fist_bone := rig_skel.find_bone("MinibossFistLeft")
	UiTokens.reduced_motion = true
	mb.state = Miniboss.State.STALK
	mb._clock = 0.0
	mb._model_pose(0.0)
	var base_body_y := rig_skel.get_bone_pose_position(body_bone).y
	var base_fist_pos := rig_skel.get_bone_pose_position(fist_bone)
	for _k in 20:
		mb._model_pose(1.0 / 60.0)
	var calm_body_y := rig_skel.get_bone_pose_position(body_bone).y
	var calm_fist_pos := rig_skel.get_bone_pose_position(fist_bone)
	t.check("Miniboss secondary breathing stays frozen under UiTokens.reduced_motion",
		is_equal_approx(calm_body_y, base_body_y) and calm_fist_pos.is_equal_approx(base_fist_pos))

	UiTokens.reduced_motion = false
	var max_body_delta := 0.0
	var max_fist_delta := 0.0
	for _k in 45:
		mb._model_pose(1.0 / 60.0)
		max_body_delta = maxf(max_body_delta, absf(rig_skel.get_bone_pose_position(body_bone).y - base_body_y))
		max_fist_delta = maxf(max_fist_delta, rig_skel.get_bone_pose_position(fist_bone).distance_to(base_fist_pos))
	t.check("Miniboss PropMotionRig drives visible breathing and fist liveliness",
		max_body_delta > 0.02 and max_fist_delta > 0.02,
		"body_dy=%.4f fist_d=%.4f" % [max_body_delta, max_fist_delta])

	mb.state = Miniboss.State.WEAK
	mb._clock = 0.0
	mb._model_pose(1.0 / 60.0)
	var mid_scale: float = mb._core.scale.x
	t.check("Miniboss _core smoothly interpolates without 1-frame snap",
		mid_scale > 0.85 and mid_scale < 1.40,
		"mid_scale=%.3f" % mid_scale)
	mb.free()

	var fake_warden := Node3D.new()
	var w_root := Node3D.new()
	root.add_child(w_root)
	var driver := Reactor.new()
	driver.sheet_dir = Vector3.FORWARD
	var mock := _MockReactorWarden.new()
	mock.world_root = w_root
	mock.home = Vector3.ZERO
	driver._show_sheet(mock, Reactor.SHEET_ALPHA)
	var sheet := w_root.get_node_or_null("ReactorSheet") as MeshInstance3D
	var sheet_aabb := sheet.mesh.get_aabb() if sheet != null and sheet.mesh != null else AABB()
	var sheet_cols := sheet.find_children("*", "CollisionObject3D", true, false) if sheet != null else []
	t.check("ReactorSheet is beveled spillway chute ArrayMesh with stepped lips and zero colliders",
		sheet != null and sheet.mesh is ArrayMesh and not (sheet.mesh is PrimitiveMesh)
		and sheet_aabb.size.y > 0.45 and sheet_cols.is_empty() and sheet.material_override is ShaderMaterial,
		"aabb=%s cols=%d" % [sheet_aabb, sheet_cols.size()])
	_check_basis_det_positive("ReactorSheet", w_root)
	UiTokens.reduced_motion = true
	var calm_sheet_mat := Reactor._make_sheet_material(Reactor.SHEET_ALPHA, true)
	t.check("ReactorSheet shader respects UiTokens.reduced_motion",
		is_equal_approx(float(calm_sheet_mat.get_shader_parameter("motion")), 0.0))
	UiTokens.reduced_motion = false
	driver._close_sheet()
	w_root.free()
	fake_warden.free()
	game.free()


class _MockReactorWarden extends RefCounted:
	var world_root: Node3D
	var home := Vector3.ZERO
	var terrain = null
