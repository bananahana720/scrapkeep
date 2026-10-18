extends SceneTree

const Game := preload("res://src/game.gd")
const Kite := preload("res://src/combat/kite_drone.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_three/enemy_kite_drone.glb"
var t := T.new("enemy_kite_drone_asset_test")
var game
var fixture: Node3D


func _initialize() -> void:
	if "--asset-fixture" in OS.get_cmdline_user_args():
		fixture = Node3D.new()
		root.add_child(fixture)
	else:
		game = Game.new()
		game.test_mode = true
		root.add_child(game)
	_run.call_deferred()


func _spawn(at: Vector3):
	if game != null:
		return game.ctx.spawner.spawn_enemy("kite_drone", at)
	var drone := Kite.new()
	fixture.add_child(drone)
	drone.position = at
	drone.setup(null, null, fixture, Callable(), 1.0, {"kind": "kite_drone"})
	return drone


func _material(mi: MeshInstance3D, surface: int) -> BaseMaterial3D:
	var mat := mi.get_surface_override_material(surface)
	if mat == null:
		mat = mi.material_override
	if mat == null:
		mat = mi.mesh.surface_get_material(surface)
	return mat as BaseMaterial3D


func _budget(node: Node, label: String) -> void:
	var vertices := 0
	var triangles := 0
	var draws := 0
	var opaque := true
	var emission := false
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			draws += 1
			var a := mi.mesh.surface_get_arrays(s)
			vertices += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			triangles += ((a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() if a[Mesh.ARRAY_INDEX] != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := _material(mi, s)
			opaque = opaque and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a >= 0.999
			emission = emission or (mat != null and mat.emission_enabled)
			if a[Mesh.ARRAY_COLOR] != null:
				for color in a[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and color.a >= 0.999
	print("%s: %d V, %d T, %d D" % [label, vertices, triangles, draws])
	t.check(label + " budget", vertices > 0 and vertices <= 19100 and triangles > 0 and triangles <= 10000 and draws == 3)
	t.check(label + " opaque unlit surfaces", opaque and not emission)


func _points(mi: MeshInstance3D, actor: Node3D, bone_names := [], posed := false) -> PackedVector3Array:
	var points := PackedVector3Array()
	var rig := mi.get_node_or_null(mi.skeleton) as Skeleton3D if mi.skin != null else null
	var mesh_xform := actor.global_transform.affine_inverse() * mi.global_transform
	for surface in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(surface)
		var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for v in vs.size():
			var point := mesh_xform * vs[v]
			var matched := bone_names.is_empty()
			if rig != null:
				var joints: PackedInt32Array = a[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
				var sum := 0.0
				for k in 4:
					var weight := weights[v * 4 + k]
					if weight < 0.001:
						continue
					sum += weight
					var bind := joints[v * 4 + k]
					var name := mi.skin.get_bind_name(bind)
					var bone := rig.find_bone(name) if name != &"" else mi.skin.get_bind_bone(bind)
					matched = matched or rig.get_bone_name(bone) in bone_names
					if posed:
						var rig_xform := actor.global_transform.affine_inverse() * rig.global_transform
						point = rig_xform * rig.get_bone_global_pose(bone) * mi.skin.get_bind_pose(bind) * vs[v]
				if not is_equal_approx(sum, 1.0):
					t.check("normalized rigid weight", false)
			if matched:
				points.append(point)
	return points


func _bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var bounds := AABB(points[0], Vector3.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	return bounds


func _geometry(drone: Node3D, pod: MeshInstance3D, sail: MeshInstance3D, chin: MeshInstance3D) -> void:
	var core := _points(pod, drone, ["PodRoot"])
	var radial := 0.0
	for p in core:
		# Suspension rods above the core are the specified visual overhangs.
		if p.y <= 1.1001:
			radial = maxf(radial, Vector2(p.x, p.z).length())
	var core_box := _bounds(core)
	t.check("core radial/height bounds", radial <= 0.8001 and absf(core_box.position.y + 1.1) < 0.001)
	var head_box := _bounds(_points(pod, drone, ["KiteHead"]))
	t.check("head and ears shared dimensions", head_box.size.x <= 0.761 and absf(head_box.end.y - 1.82) < 0.001)
	var hub_box := _bounds(_points(pod, drone, ["KiteHub"]))
	t.check("hub 1 m diameter and 0.9 m height", hub_box.size.x <= 1.001 and hub_box.size.z <= 1.001 and absf(hub_box.size.y - 0.9) < 0.001)
	var sail_box := _bounds(_points(sail, drone))
	print("sail dimensions %s, centre %s" % [sail_box.size, sail_box.get_center()])
	t.check("sail 3.2 x 0.7 x 0.12 m", sail_box.size.is_equal_approx(Vector3(3.2, 0.1202, 0.7)))
	t.check("sail root and nominal top", absf(sail_box.get_center().y - 1.5) < 0.001 and sail_box.end.y <= 1.561)
	var chin_box := _bounds(_points(chin, drone))
	t.check("chin blunt measured envelope", absf(chin_box.size.x - 0.35) < 0.001 and absf(chin_box.size.z - 0.5) < 0.001 and chin_box.size.y <= 0.203)
	t.check("chin centre and pivot", chin_box.get_center().distance_to(Vector3(0, -0.3, 0.45)) < 0.003 and chin.position.is_equal_approx(Vector3(0, -0.3, 0.3)))


func _poses(drone, pod: MeshInstance3D, sail: MeshInstance3D) -> void:
	var rig: Skeleton3D = drone._windup_rig
	var actor_transform: Transform3D = drone.transform
	for progress in [0.0, 0.5, 1.0]:
		drone.phase = drone.Phase.WARN
		drone._t = progress * drone.warn_seconds
		drone._pose()
		rig.force_update_all_bone_transforms()
		for i in drone._wing_bones.size():
			var bone: int = drone._wing_bones[i]
			var rest := rig.get_bone_rest(bone)
			var pose := rig.get_bone_pose(bone)
			var angle := rad_to_deg(rest.basis.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()))
			t.near("wing tension tracks WARN " + str(progress), angle, 5.0 * progress, 0.002)
		t.near("chin tracks WARN " + str(progress), drone._chin.rotation.x, deg_to_rad(12.0 * progress))
		t.check("WARN does not translate actor", drone.transform.is_equal_approx(actor_transform))
	var rest_sail := _bounds(_points(sail, drone))
	var tense_sail := _bounds(_points(sail, drone, [], true))
	t.check("skinned wing tips visibly lift", tense_sail.end.y > rest_sail.end.y + 0.07)
	var rest_paw := _bounds(_points(pod, drone, ["KitePawLeft"]))
	var tense_paw := _bounds(_points(pod, drone, ["KitePawLeft"], true))
	t.check("paws tuck up and back", tense_paw.get_center().distance_to(rest_paw.get_center() + Vector3(0, 0.08, -0.08)) < 0.001)
	drone.phase = drone.Phase.LIVE
	drone._t = 0.0
	drone._pose()
	t.near("LIVE holds chin", drone._chin.rotation.x, deg_to_rad(12.0))
	drone._end()
	drone._pose()
	rig.force_update_all_bone_transforms()
	t.near("climb resets chin", drone._chin.rotation.x, 0.0)
	t.check("climb resets sail geometry", _bounds(_points(sail, drone, [], true)).is_equal_approx(rest_sail))
	for bone in drone._wing_bones + drone._paw_bones:
		t.check("climb restores bone rest", rig.get_bone_pose(bone).is_equal_approx(rig.get_bone_rest(bone)))
	t.check("pose preserves actor and clock", drone.transform.is_equal_approx(actor_transform) and is_zero_approx(drone._t))


func _run() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	t.check("GLB loads", packed != null)
	if packed == null:
		quit(t.verdict())
		return
	var scene := packed.instantiate()
	_budget(scene, "asset")
	for name in ["KiteCrewPod", "KiteSail", "DiveChin", "KiteSpars", "sail_root", "hub_axis", "chin_pivot", "dive_actor"]:
		t.check("named part " + name, scene.find_child(name, true, false) != null)
	var source_rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	t.check("asset rig exists", source_rig != null)
	if source_rig != null:
		for name in ["KiteHead", "KiteHub", "PodRoot", "KiteWingLeft", "KiteWingRight", "KitePawLeft", "KitePawRight"]:
			t.check("named rigid bone " + name, source_rig.find_bone(name) >= 0)
	scene.free()
	if game != null:
		game.ctx.calm = true
	var drone = _spawn(Vector3(0, 30, 0))
	drone.set_physics_process(false)
	_budget(drone, "live assembly")
	var pod := drone.find_child("KiteCrewPod", true, false) as MeshInstance3D
	var sail := drone.find_child("KiteSail", true, false) as MeshInstance3D
	var chin := drone.find_child("DiveChin", true, false) as MeshInstance3D
	t.check("GLB replaces capsule fallback", pod != null and sail != null and chin != null and drone._crew == null)
	for item in drone.find_children("*", "MeshInstance3D", true, false):
		t.check("no CapsuleMesh fallback", not (item as MeshInstance3D).mesh is CapsuleMesh)
	var shapes := drone.find_children("*", "CollisionShape3D", true, false)
	var capsule := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	t.check("existing collider retained", capsule != null and is_equal_approx(capsule.radius, 0.8) and is_equal_approx(capsule.height, 2.2) and (shapes[0] as Node3D).transform.is_equal_approx(Transform3D.IDENTITY))
	t.check("no new collision objects/lights", drone.find_children("*", "CollisionObject3D", true, false).is_empty() and drone.find_children("*", "Light3D", true, false).is_empty())
	if pod != null and sail != null and chin != null and drone._windup_rig != null:
		for mi in [pod, sail, chin]:
			t.check("reaction pivot parents " + mi.name, mi.get_parent() == drone.reaction_pivot)
		for mi in [pod, sail]:
			t.check("rig binding " + mi.name, mi.skin != null and mi.get_node(mi.skeleton) == drone._windup_rig)
			t.check("flash registration " + mi.name, _material(mi, 0) == drone._material and drone._material.vertex_color_use_as_albedo)
		_geometry(drone, pod, sail, chin)
		_poses(drone, pod, sail)
		var other = _spawn(Vector3(5, 30, 0))
		other.set_physics_process(false)
		var other_pod := other.find_child("KiteCrewPod", true, false) as MeshInstance3D
		t.check("cached meshes and separate instance state", other_pod != null and pod.mesh == other_pod.mesh and drone._material != other._material and drone._windup_rig != other._windup_rig)
		drone.flash()
		drone._update_flash(0.0)
		t.check("existing flash fires independently", drone._material.emission_enabled and not other._material.emission_enabled)
		for i in 20:
			drone._update_flash(0.1)
		t.check("flash restores painted finish", drone._material.albedo_color.is_equal_approx(Color.WHITE) and not drone._material.emission_enabled)
		other.free()
	var verdict := t.verdict()
	if game != null:
		game.free()
	else:
		fixture.free()
	quit(verdict)
