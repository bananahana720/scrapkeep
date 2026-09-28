extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const Scenery := preload("res://src/presentation/spillway_scenery.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new()
	terrain.build(world)
	var scenery := Scenery.build(terrain.geometry_root(1))
	var triangles := 0
	var checked := 0
	var bounds_ok := true
	var materials_ok := true
	var nodes_ok := scenery.transform == Transform3D.IDENTITY and scenery.get_script() == null and not scenery.is_processing() and not scenery.is_physics_processing()
	for child in scenery.get_children():
		nodes_ok = nodes_ok and child is MeshInstance3D and child.get_child_count() == 0
		nodes_ok = nodes_ok and child.transform == Transform3D.IDENTITY and child.get_script() == null and not child.is_processing() and not child.is_physics_processing()
		if not child is MeshInstance3D:
			continue
		var mesh: Mesh = child.mesh
		nodes_ok = nodes_ok and mesh.get_surface_count() == 1
		var mat: StandardMaterial3D = child.material_override
		materials_ok = materials_ok and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
		materials_ok = materials_ok and not mat.emission_enabled and not mat.no_depth_test
		materials_ok = materials_ok and child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += indices.size() / 3
			for i in range(0, indices.size(), 3):
				checked += 1
				var bounds := AABB(vertices[indices[i]], Vector3.ZERO)
				bounds = bounds.expand(vertices[indices[i + 1]])
				bounds = bounds.expand(vertices[indices[i + 2]])
				var outside := bounds.end.x < -200.0 or bounds.position.x > 200.0 or bounds.end.z < -200.0 or bounds.position.z > 200.0
				if not outside:
					print("OVERLAP %s triangle %d %s" % [child.name, i / 3, bounds])
				bounds_ok = bounds_ok and outside
	_check(bounds_ok, "all %d triangle AABBs outside terrain footprint" % checked)
	_check(nodes_ok, "only inert mesh nodes, no collision/navigation/gameplay nodes")
	_check(materials_ok, "opaque nonemissive depth-tested materials; shadows disabled")
	_check(triangles > 0 and triangles <= 25000 and scenery.get_child_count() <= 20,
		"geometry budget: %d triangles, %d single-surface batches (not measured draw calls)" % [triangles, scenery.get_child_count()])
	_check(scenery.is_visible_in_tree(), "visible under stage 1")
	terrain.use(2)
	_check(not scenery.is_visible_in_tree() and scenery.global_position.y == -Terrain.PARK_DEPTH, "stage 2 hides and parks scenery")
	terrain.use(1)
	_check(scenery.is_visible_in_tree() and scenery.global_position == Vector3.ZERO, "stage 1 restores scenery")
	terrain.park_all()
	_check(not scenery.is_visible_in_tree() and not scenery.can_process(), "arena parking hides and disables scenery")
	terrain.use(1)
	_check(scenery.is_visible_in_tree(), "return from arena restores scenery")
	world.free()
	print("spillway_scenery_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
