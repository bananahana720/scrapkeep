extends SceneTree

const Game := preload("res://src/game.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Palette := preload("res://src/core/palette.gd")
const GLB := "res://assets/models/world_one/enemy_miniboss.glb"
const BASE_CONSTS := {
	"HP": 600.0, "DEFAULT_PLATING": 38.0, "SCRAP": 24, "WEIGHT": 5.0,
	"RADIUS": 2.3, "HALF_HEIGHT": 3.45, "WALK": 5.5, "STALK": 1.6,
	"SLAM_CROUCH": 0.5, "SLAM_LEAP": 0.9, "SLAM_RADIUS": 7.0, "SLAM_HEIGHT": 9.0,
	"SLAM_DAMAGE": 24.0, "SLAM_SHOVE": 9.0, "CHARGE_BRACE": 1.0,
	"CHARGE_LENGTH": 30.0, "CHARGE_WIDTH": 4.6, "CHARGE_TIME": 0.9,
	"CHARGE_DAMAGE": 20.0, "CHARGE_SHOVE": 10.0, "WEAK_SECONDS": 2.4,
}
# Source-body hashes at fb33d4b protect every existing gameplay function. Re-pinned 2026-10-26 for
# phase two (miniboss_phase_test): state_name, _physics_process, _land_slam, _open_weak_window. Re-pinned 2026-11-15 for PF-16 (body_run_warning_test):
# _physics_process and _begin_attack each tell the lane where the body is (Telegraph.run_body), and
# _check_charge reads the new HIT_REACH constant that run_body shares; the numbers are unchanged.
# Re-pinned 2026-11-17 for MG-11 (boss_lead_line_test): _begin_attack aims the slam ring and the
# charge lane through PackPressure.lead_aim, so a ball holding a line is led, and lands the slam only on
# ground it can reach (_slam_spot); tells and sizes unchanged.
const GAMEPLAY_HASHES := {
	"state_name": "f531faa43d6baa25b8c72491cb73b3c8df3af4a435809860053cf94d086a6856",
	"is_weak": "20e84d3101502a8331b833e1c201ef67fd3c48c74db4859292fcaa23dd44171f",
	"plating_now": "5859de0aae1e833816e5f753c9bda73835016977cbefe86914e61d51eccb60bb",
	"knock": "44e0e65b9157eae56a65fdcc63a1be99f30fddcf771575778b123f39c4629cd9",
	"_physics_process": "8223245a55c51c65cec4d29c941ab78fef21bb59fb9608bd3f40db777e1d572c",
	"_enter": "93ff6aafd23f4348ae2745de0415b4565647f6e4eff2157b87d933b36be437a8",
	"_begin_attack": "0890ce4012281b9ee9accb51ef5d38763bc53b0b29e56d04ef3dd25cec6c302b",
	"_land_slam": "b5f92d8417e046301d52a51be1b95371f573969e8eb1b7dd1018a6131868e5b6",
	"_check_charge": "e47c6804f609eac31da5adbaebfdae62399732a4ae06c4e2d056ac7705ffe180",
	"_open_weak_window": "8e91926c9080fa3f1812fce4fc5e5653d7290bf40f697736508698278bd0069a",
	"_fill": "0a687b6fb91080244f6ffa2e410601fd92f8ffe5351b7a2202787c6d6b66ac0b",
}
var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _finish() -> void:
	print("enemy_miniboss_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.free()
	quit(0 if failures == 0 else 1)


func _measure(node: Node) -> Dictionary:
	var tris := 0
	var vertices := 0
	var draws := 0
	var opaque := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh == null:
			opaque = false
			continue
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			vertices += vs.size()
			tris += (indices.size() if indices != null else vs.size()) / 3
			draws += 1
			var material := mi.material_override
			if material == null:
				material = mi.mesh.surface_get_material(s)
			if material is BaseMaterial3D:
				opaque = opaque and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a >= 0.999
			else:
				opaque = false
			if arrays[Mesh.ARRAY_COLOR] != null:
				for color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and color.a >= 0.999
	return {"tris": tris, "vertices": vertices, "draws": draws, "opaque": opaque}


func _budget(node: Node, label: String) -> void:
	var m := _measure(node)
	print("%s: %d T / %d V / %d D" % [label, m.tris, m.vertices, m.draws])
	_check(m.tris > 0 and m.tris <= 8800 and m.vertices > 0 and m.vertices <= 4900 and m.draws == 3,
		label + " fits shared enemy budget")
	_check(m.opaque, label + " opaque")


func _run() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	_check(packed != null, "GLB loads at required path")
	if packed == null:
		_finish()
		return
	var asset := packed.instantiate()
	_budget(asset, "asset")
	var rig := asset.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(rig != null, "GLB has rigid pose skeleton")
	if rig != null:
		for name in Miniboss.MODEL_BONES:
			_check(rig.find_bone(name) >= 0, "GLB named bone " + name)
	for name in Miniboss.MODEL_PARTS:
		var mi := asset.find_child(name, true, false) as MeshInstance3D
		_check(mi != null and mi.mesh is ArrayMesh, "GLB named mesh " + name)
		if mi != null and name != "MinibossCore":
			_check_skin(mi, rig)
	asset.free()
	game.ctx.calm = true
	var boss = game.ctx.spawner.spawn_enemy("miniboss", Vector3(0, 30, 0))
	boss.set_physics_process(false)
	_budget(boss, "live assembly")
	_check(boss._pose_rig != null and boss._plates.is_empty(), "GLB replaces box armour builder")
	var primitive := false
	for child in boss.find_children("*", "MeshInstance3D", true, false):
		primitive = primitive or child.mesh is PrimitiveMesh
	_check(not primitive, "capsule and box armour no longer render")
	_check(boss.find_children("*", "Light3D", true, false).is_empty(), "no added lights")
	_check(boss.find_children("*", "CollisionObject3D", true, false).is_empty(), "no added physics bodies or areas")
	var shapes: Array = boss.find_children("*", "CollisionShape3D", true, false)
	var capsule := shapes[0].shape as CapsuleShape3D if shapes.size() == 1 else null
	_check(capsule != null and is_equal_approx(capsule.radius, 2.3) and is_equal_approx(capsule.height, 6.9)
		and shapes[0].transform == Transform3D.IDENTITY, "unchanged centred collider 2.3 m / 6.9 m")
	_check(boss.hp == 600.0 and boss.max_hp == 600.0 and boss.weight == 5.0 and boss.scrap_value == 24
		and boss.radius == 2.3 and boss.half_height == 3.45 and boss.collision_layer == 4 and boss.collision_mask == 1,
		"health weight scrap dimensions and collision layers unchanged")
	var constants: Dictionary = (boss.get_script() as Script).get_script_constant_map()
	for name in BASE_CONSTS:
		_check(constants.get(name) == BASE_CONSTS[name], "unchanged constant " + name)
	var source := FileAccess.get_file_as_string("res://src/combat/miniboss.gd")
	for name in GAMEPLAY_HASHES:
		var body := source.get_slice("func " + name + "(", 1).get_slice("\nfunc ", 0).get_slice("\n\n#", 0).strip_edges()
		body = "func " + name + "(" + body
		_check(body.sha256_text() == GAMEPLAY_HASHES[name], "unchanged gameplay function " + name)
	if boss._pose_rig != null:
		_check_poses(boss, shapes[0])
		_check_cache(boss)
	_finish()


func _check_skin(mi: MeshInstance3D, rig: Skeleton3D) -> void:
	_check(mi.skin != null and rig != null and mi.get_node_or_null(mi.skeleton) == rig,
		String(mi.name) + " skin binds to named skeleton")
	if mi.skin == null or mi.mesh == null or rig == null:
		return
	var arrays := mi.mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
		_check(false, String(mi.name) + " has bone and weight attributes")
		return
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var rigid := bones.size() == vs.size() * 4 and weights.size() == bones.size()
	var used := {}
	if rigid:
		for vertex in vs.size():
			var total := 0.0
			var bound := 0
			for i in 4:
				var w := weights[vertex * 4 + i]
				total += w
				bound += 1 if w > 0.001 else 0
				if w > 0.001:
					var binding := bones[vertex * 4 + i]
					if binding < 0 or binding >= mi.skin.get_bind_count():
						rigid = false
						continue
					var bone_name := String(mi.skin.get_bind_name(binding))
					if bone_name.is_empty():
						var index := mi.skin.get_bind_bone(binding)
						bone_name = String(rig.get_bone_name(index)) if index >= 0 and index < rig.get_bone_count() else "invalid"
					used[bone_name] = true
			rigid = rigid and is_equal_approx(total, 1.0) and bound == 1
	_check(rigid, String(mi.name) + " has normalized rigid vertex weights")
	var expected := ["MinibossPlateLeft", "MinibossPlateRight"] if mi.name == "MinibossArmour" else [
		"MinibossBody", "MinibossFootLeft", "MinibossFootRight", "MinibossFistLeft", "MinibossFistRight", "MinibossHalo"]
	var drives_parts := used.size() == expected.size()
	for name in expected:
		drives_parts = drives_parts and used.has(name)
	_check(drives_parts, String(mi.name) + " vertices follow the named moving parts")


func _check_poses(boss, shape: CollisionShape3D) -> void:
	var rig: Skeleton3D = boss._pose_rig
	var body := rig.find_bone("MinibossBody")
	var fist := rig.find_bone("MinibossFistLeft")
	var left := rig.find_bone("MinibossPlateLeft")
	var right := rig.find_bone("MinibossPlateRight")
	var halo := rig.find_bone("MinibossHalo")
	var actor_transform: Transform3D = boss.transform
	var shape_transform := shape.transform
	boss.state = Miniboss.State.SLAM_CROUCH
	boss._clock = Miniboss.SLAM_CROUCH
	boss._model_pose(1.0)
	var crouch_y := rig.get_bone_pose_position(body).y
	_check(crouch_y < -0.5 and rig.get_bone_pose_scale(halo) == Vector3.ZERO,
		"crouch compresses press with halo hidden")
	boss.state = Miniboss.State.SLAM_LEAP
	boss._clock = 0.3
	boss._model_pose(1.0)
	var raised := rig.get_bone_pose_position(fist).y
	_check(raised > rig.get_bone_rest(fist).origin.y + 1.0, "leap raises heavy fists")
	boss._clock = Miniboss.SLAM_LEAP
	boss._model_pose(1.0)
	_check(rig.get_bone_pose_position(fist).y < raised - 1.0, "leap fists strike down before landing")
	boss.state = Miniboss.State.CHARGE_BRACE
	boss._clock = Miniboss.CHARGE_BRACE
	boss._model_pose(1.0)
	var brace := rig.get_bone_pose_position(fist)
	_check(brace.z < rig.get_bone_rest(fist).origin.z - 0.6, "brace pushes fists into forward wedge")
	boss.state = Miniboss.State.CHARGE
	boss._clock = 0.4
	boss._model_pose(1.0)
	_check(rig.get_bone_pose_position(fist).is_equal_approx(brace), "charge holds committed brace pose")
	boss.state = Miniboss.State.WEAK
	boss._clock = 0.8
	boss._model_pose(1.0)
	var lturn := rig.get_bone_pose_rotation(left) * rig.get_bone_rest(left).basis.get_rotation_quaternion().inverse()
	var rturn := rig.get_bone_pose_rotation(right) * rig.get_bone_rest(right).basis.get_rotation_quaternion().inverse()
	_check(lturn.get_axis().dot(rturn.get_axis()) < -0.9 and lturn.get_angle() > 0.9 and rturn.get_angle() > 0.9,
		"weak window swings both shutters outward")
	_check(boss._core.scale.x > 1.2 and boss._core_material.albedo_color == Palette.live()
		and boss._core_material.emission_enabled and rig.get_bone_pose_scale(halo) == Vector3.ONE,
		"vented opening enlarges mint core and shows halo")
	_check(boss.state == Miniboss.State.WEAK and boss._clock == 0.8 and boss.attacks == 0 and boss.weak_windows == 0
		and boss.transform == actor_transform and shape.transform == shape_transform,
		"poses leave state clock counters actor and collider untouched")
	boss.state = Miniboss.State.STALK
	boss._clock = 0.0
	boss._model_pose(1.0)
	_check(not boss._core_material.emission_enabled and boss._core.scale == Vector3.ONE * 0.8
		and boss._model_plate_material.albedo_color == Palette.SLATE and rig.get_bone_pose_scale(halo) == Vector3.ZERO,
		"closed shutters slate with dark core and no halo")
	_check(rig.get_bone_pose_rotation(left).is_equal_approx(rig.get_bone_rest(left).basis.get_rotation_quaternion()),
		"shutters return to closed rest")
	boss.flash()
	boss._update_flash(0.05)
	_check(boss._material.emission_enabled and boss._material.vertex_color_use_as_albedo, "body keeps inherited hit flash")
	boss._update_flash(1.0)
	_check(not boss._material.emission_enabled and boss._material.albedo_color == Color.WHITE, "flash restores vertex-colour finish")


func _check_cache(boss) -> void:
	var second = game.ctx.spawner.spawn_enemy("miniboss", Vector3(15, 30, 0))
	second.set_physics_process(false)
	var shared := true
	for name in Miniboss.MODEL_PARTS:
		var first_mesh := boss.find_child(name, true, false) as MeshInstance3D
		var second_mesh := second.find_child(name, true, false) as MeshInstance3D
		shared = shared and first_mesh != null and second_mesh != null and first_mesh.mesh == second_mesh.mesh
	_check(shared and boss._pose_rig != second._pose_rig and boss._material != second._material
		and boss._core_material != second._core_material and boss._model_plate_material != second._model_plate_material,
		"cached meshes share geometry with independent skeletons and materials")
	boss.state = Miniboss.State.WEAK
	boss._model_pose(1.0)
	_check(second._core.scale == Vector3.ONE * 0.8 and not second._core_material.emission_enabled,
		"one vented miniboss cannot vent another")
