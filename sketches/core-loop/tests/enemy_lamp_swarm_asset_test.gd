# 2026-10-12, W13 smoke triage: class c re-pin for 5b903a3, bbe53ec, 17429d6.
# counter.gd SHA256 56b1e9fd180b0c5c06ba67013011c12a26d6f6f1989cb6c140620334b06f0cca -> 5e3d17ed123286ed2c22808f3051a76d450e56697828d7277cef3b8f0af7c554; merged pack stagger, rename and shared-recovery changes.
extends SceneTree

const Lamp := preload("res://src/combat/lamp_swarm.gd")
const T := preload("res://tests/support/t.gd")
const GLB := "res://assets/models/world_two/enemy_lamp_swarm.glb"
# 2026-11-25 (W48-COMBAT): re-pinned _commit, _go_live, _live, on_struck for Flash-Focus Beam secondary attack.
const BASE_FUNCTIONS := {
	"_configure": "f01911b7165177239f958af9bde28082fffba3b94b77af3e151f08d74bcbcf1a",
	"_lamp_rest": "b5089114393a2c564ef22e2d7b195ed18258800560c1b0c5dff80ded0ede4f18",
	"_commit": "6534338e25939ef14213776829b2adf724c92ffeb9b377f833a4128002309152",
	"_go_live": "3ba54f92ff1a6dbd87953d35a8f72f434aecd671a80678406c612ba10c954efc",
	"_live": "de7727cdedb16634cecfdfe676ac85a139e683248a9e74ce336333bb86aff8e8",
	"_meet_bloom": "ab5d59d60849a941ba50cc3dd4368691dc2bd66ddb0b6daa2e6e488a8521d44b",
	"on_struck": "26ef0f0456d7e5684a7593501559aa949e1e1b30cc6e91a60c78952b8fd781c9",
}
const BASE_CONSTS := {"HP": 35.0, "LAMP_COUNT": 3, "LAMP_RING": 1.3, "LAMP_HEIGHT": 1.6,
	"LAMP_RADIUS": 0.3, "BLOOM_RADIUS": 9.0, "BLOOM_SPEED": 6.0, "BLOOM_REACH": 3.0,
	"LURE": 6.0, "SCATTER_SPEED": 7.0}
var t := T.new("enemy_lamp_swarm_asset_test")
var fixture: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _measure(node: Node) -> Dictionary:
	var result := {"tris": 0, "vertices": 0, "draws": 0, "capsules": 0, "opaque": true}
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.mesh is CapsuleMesh:
			result.capsules += 1
		for surface in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var indices = a[Mesh.ARRAY_INDEX]
			result.tris += (indices.size() if indices != null else vertices.size()) / 3
			result.vertices += vertices.size()
			result.draws += 1
			var mat := mi.get_active_material(surface) as BaseMaterial3D
			result.opaque = result.opaque and mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
	return result


func _budget(node: Node, label: String) -> void:
	var count := _measure(node)
	t.check(label + " budget", count.tris > 0 and count.tris <= 10000 and count.vertices <= 19100
		and count.draws > 0 and count.draws <= 3 and count.opaque, str(count))
	t.eq(label + " no capsule mesh", count.capsules, 0)


func _spawn() -> Node3D:
	var unit := Lamp.new()
	fixture.add_child(unit)
	unit.setup(null, null, fixture, Callable(), 1.0, {"kind": "lamp_swarm"})
	unit.set_physics_process(false)
	return unit


func _run() -> void:
	# ResourceLoader.exists avoids a missing-path engine error while still failing loud.
	var exists := ResourceLoader.exists(GLB)
	t.check("GLB exists", exists, GLB)
	if not exists:
		quit(t.verdict())
		return
	var packed := load(GLB) as PackedScene
	t.check("GLB loads", packed != null)
	if packed == null:
		quit(t.verdict())
		return
	var scene := packed.instantiate() as Node3D
	_budget(scene, "export")
	var rigs := scene.find_children("*", "Skeleton3D", true, false)
	var rig := rigs[0] as Skeleton3D if rigs.size() == 1 else null
	t.check("rigid lamp skin", rig != null)
	var assembly := scene.find_child("LampAssembly", true, false) as MeshInstance3D
	t.check("one shared lamp mesh with skin", assembly != null and assembly.skin != null)
	t.check("named crew/head", scene.find_child("LampCrewBody", true, false) != null
		and scene.find_child("LampHead", true, false) != null)
	var body := scene.find_child("LampCrewBody", true, false) as MeshInstance3D
	if body != null:
		_check_core(body)
	if rig != null:
		t.check("lamp root", rig.find_bone("lamp_root") >= 0)
		for i in 3:
			for part in ["LampBulb", "LampHood", "LampShutter", "LampLens"]:
				t.check("named " + part + str(i), rig.find_bone(part + str(i)) >= 0)
			t.check("named arm " + str(i), scene.find_child("LampArm" + str(i), true, false) != null)
			var index := rig.find_bone("LampBulb" + str(i))
			if index >= 0:
				var angle := TAU * i / 3.0
				var rest := Vector3(cos(angle) * 1.3, 1.6, sin(angle) * 1.3)
				t.check("exact rest socket " + str(i), rig.get_bone_global_rest(index).origin.distance_to(rest) < 0.00001,
					str(rig.get_bone_global_rest(index)))
				if assembly != null and assembly.skin != null:
					_check_lamp_geometry(assembly, rig, i, rest)
	scene.free()
	fixture = Node3D.new()
	root.add_child(fixture)
	var unit = _spawn()
	_budget(unit, "live")
	t.check("model replaces capsule fallback", unit._crew == null and unit._lamp_rig != null
		and unit.lamps.size() == 3 and unit.find_child("LampCrewBody", true, false) != null)
	t.check("reaction pivot parents model", unit._lamp_rig != null and unit.reaction_pivot.is_ancestor_of(unit._lamp_rig))
	_check_base(unit)
	if unit._lamp_rig != null:
		_check_pose(unit)
		_check_cache(unit)
	fixture.free()
	quit(t.verdict())


func _check_core(mi: MeshInstance3D) -> void:
	# Weld colour/normal seams, then measure the largest connected shell, the hull.
	var a := mi.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var welded := {}
	var points: Array[Vector3] = []
	var ids := PackedInt32Array()
	var edges: Array = []
	for v in vertices:
		var key := Vector3i(roundi(v.x * 100000), roundi(v.y * 100000), roundi(v.z * 100000))
		if not welded.has(key):
			welded[key] = points.size()
			points.append(v)
			edges.append({})
		ids.append(welded[key])
	for i in range(0, indices.size(), 3):
		for j in 3:
			var left := ids[indices[i + j]]
			var right := ids[indices[i + (j + 1) % 3]]
			edges[left][right] = true
			edges[right][left] = true
	var seen := {}
	var hull: Array[Vector3] = []
	var hull_span := -1.0
	for start in points.size():
		if seen.has(start):
			continue
		var group: Array[Vector3] = []
		var pending := [start]
		seen[start] = true
		while not pending.is_empty():
			var at: int = pending.pop_back()
			group.append(points[at])
			for next in edges[at]:
				if not seen.has(next):
					seen[next] = true
					pending.append(next)
		# The core is the tallest piece; polished heads can carry more vertices than it.
		var low := INF
		var high := -INF
		for p in group:
			low = minf(low, p.y)
			high = maxf(high, p.y)
		if high - low > hull_span:
			hull = group
			hull_span = high - low
	var bounds := AABB(hull[0], Vector3.ZERO)
	var radial := 0.0
	for p in hull:
		bounds = bounds.expand(p)
		radial = maxf(radial, Vector2(p.x, p.z).length())
	t.check("measured rounded core", hull.size() == 50 and absf(radial - 0.8) < 0.0001
		and absf(bounds.position.y + 1.1) < 0.0001 and absf(bounds.end.y - 1.1) < 0.0001, str(bounds))


func _weighted_points(mi: MeshInstance3D, rig: Skeleton3D, name: String) -> PackedVector3Array:
	var points := PackedVector3Array()
	var bone := rig.find_bone(name)
	for surface in mi.mesh.get_surface_count():
		var a := mi.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var ids: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var stride := ids.size() / vertices.size()
		for v in vertices.size():
			for influence in stride:
				var offset: int = v * stride + influence
				if weights[offset] < 0.999:
					continue
				var bind := ids[offset]
				var bind_name := mi.skin.get_bind_name(bind)
				var bound := rig.find_bone(bind_name) if bind_name != &"" else mi.skin.get_bind_bone(bind)
				if bound == bone:
					points.append(mi.transform * vertices[v])
	return points


func _check_lamp_geometry(mi: MeshInstance3D, rig: Skeleton3D, i: int, rest: Vector3) -> void:
	for part in ["LampBulb", "LampHood", "LampShutter", "LampShutterB"]:
		var name: String = "LampShutter%dB" % i if part == "LampShutterB" else part + str(i)
		var points := _weighted_points(mi, rig, name)
		t.check("rigid geometry " + name, not points.is_empty())
		if points.is_empty():
			continue
		var bounds := AABB(points[0], Vector3.ZERO)
		var radius := 0.0
		var formation := 0.0
		for p in points:
			bounds = bounds.expand(p)
			radius = maxf(radius, Vector2(p.x - rest.x, p.y - rest.y).length())
			formation = maxf(formation, Vector2(p.x, p.z).length())
		print("geometry %s: bounds %s, radius %.6f" % [name, bounds, radius])
		if part == "LampBulb":
			t.check("bulb 0.6 m diameter", absf(bounds.size.x - 0.6) < 0.0001 and absf(bounds.size.y - 0.6) < 0.0001)
			t.check("bulb top 1.9", absf(bounds.end.y - 1.9) < 0.0001)
		elif part == "LampHood":
			t.check("hood radius/depth", radius <= 0.30001 and absf(bounds.size.z - 0.18) < 0.0001)
		else:
			t.check("shutter 0.10 x 0.24 x 0.03", absf(bounds.size.x - 0.10) < 0.0001
				and absf(bounds.size.y - 0.24) < 0.0001 and bounds.size.z <= 0.0331)
		t.check("formation within 1.6 m", formation <= 1.60001, str(formation))


func _check_base(unit: Node3D) -> void:
	var shapes := unit.find_children("*", "CollisionShape3D", true, false)
	var cap := (shapes[0] as CollisionShape3D).shape as CapsuleShape3D if shapes.size() == 1 else null
	t.check("collider unchanged", cap != null and is_equal_approx(cap.radius, 0.8) and is_equal_approx(cap.height, 2.2))
	t.check("no added collider", unit.find_children("*", "CollisionObject3D", true, false).is_empty())
	t.check("no added lights", unit.find_children("*", "Light3D", true, false).is_empty())
	var constants: Dictionary = unit.get_script().get_script_constant_map()
	for key in BASE_CONSTS:
		t.check("base constant " + key, constants.has(key) and is_equal_approx(constants[key], BASE_CONSTS[key]))
	var source := FileAccess.get_file_as_string("res://src/combat/lamp_swarm.gd")
	for name in BASE_FUNCTIONS:
		var block: String = "func " + name + source.get_slice("func " + name, 1).get_slice("\n\n", 0)
		t.check("base gameplay " + name, block.strip_edges().sha256_text() == BASE_FUNCTIONS[name])
	# Shared combat files are not pinned here; the merge-time fence owns shared-file changes (2026-10-13, ENEMY-PINS).


func _check_pose(unit: Node3D) -> void:
	var rig: Skeleton3D = unit._lamp_rig
	rig.force_update_all_bone_transforms()
	for i in 3:
		t.check("assembled bone at socket", rig.get_bone_global_pose(unit._lamp_bones[i]).origin.distance_to(unit._lamp_rest(i)) < 0.00001,
			str(rig.get_bone_global_pose(unit._lamp_bones[i])))
	for phase in [unit.Phase.ROAM, unit.Phase.WARN, unit.Phase.LIVE]:
		unit.phase = phase
		for progress in [0.0, 0.5, 1.0]:
			unit._t = unit.warn_seconds * progress
			var clock: float = unit._t
			unit._pose()
			var amount: float = progress if phase == unit.Phase.WARN else (1.0 if phase == unit.Phase.LIVE else 0.0)
			for i in 3:
				t.near("lens uses attack clock", rig.get_bone_pose_scale(unit._lens_bones[i]).x, lerpf(0.001, 1, amount))
				var q := rig.get_bone_pose_rotation(unit._shutter_bones[i * 2])
				t.check("shutter uses attack clock", q.is_equal_approx(Quaternion(Vector3.UP, -deg_to_rad(100) * amount)))
				t.check("lamp proxy stays at socket", unit.lamps[i].position.is_equal_approx(unit._lamp_rest(i)))
			t.near("visual pose does not advance clock", unit._t, clock)
	unit.lamps[1].position += Vector3(1, 2, 3)
	unit._pose_lamps()
	rig.force_update_all_bone_transforms()
	t.check("scatter proxy drives corresponding bone", rig.get_bone_global_pose(unit._lamp_bones[1]).origin.is_equal_approx(unit._lamp_rest(1) + Vector3(1, 2, 3)))
	t.check("other lamp stays independent", rig.get_bone_global_pose(unit._lamp_bones[0]).origin.is_equal_approx(unit._lamp_rest(0)))
	unit._on_end()
	for i in 3:
		t.check("reset exact socket", unit.lamps[i].position.is_equal_approx(unit._lamp_rest(i)))
		t.check("reset closes shutter", rig.get_bone_pose_rotation(unit._shutter_bones[i * 2]).is_equal_approx(Quaternion.IDENTITY))
		t.near("reset dark lens", rig.get_bone_pose_scale(unit._lens_bones[i]).x, 0.001)


func _check_cache(unit: Node3D) -> void:
	var other = _spawn()
	var body := unit.find_child("LampCrewBody", true, false) as MeshInstance3D
	var second := other.find_child("LampCrewBody", true, false) as MeshInstance3D
	t.check("meshes cached", body.mesh == second.mesh and Lamp._parts() == Lamp._parts())
	t.check("pose and flash independent", unit._lamp_rig != other._lamp_rig and unit._material != other._material)
	unit.flash()
	unit._update_flash(0)
	t.check("body flash retained", unit._material.emission_enabled and not other._material.emission_enabled)
	unit._update_flash(1)
	t.check("flash settles to vertex paint", not unit._material.emission_enabled and unit._material.vertex_color_use_as_albedo)
	other.free()
