extends SceneTree

# Rule (perf lane, #241): after a world 1 entry, bake_warm.gd builds each of stage 1's kinds once
# as a spawn builds it, out of sight for two frames (the second with its death debris, bake_warm_test), so the render pipelines its surfaces need
# compile then and not at the first spawn's first frame. The warm is only worth its frame if it
# draws what the spawn draws: for each kind, the warm view's meshes, the shader-relevant state of
# every surface's active material (the paint a spawn owns, its extras' materials) and its other
# drawn nodes match a live spawn's, built the way Combat.spawn_enemy builds one. Nothing in play
# can find the warm spawn: it is out of the enemy group, has no collision and never processes.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")

var t := T.new("spawn_warm_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var target := Node3D.new()
	stage.add_child(target)
	var kits := BakeWarm.WORLD_KITS[1].filter(func(kit): return BakeWarm.kind_of(kit) in BakeWarm.SPAWN_WARM)
	t.check("every stage 1 kind is a world 1 kit", kits.size() == BakeWarm.SPAWN_WARM.size(), "%d of %d" % [kits.size(), BakeWarm.SPAWN_WARM.size()])
	for kit in kits:
		var kind := BakeWarm.kind_of(kit)
		var live: Node3D = kit.new()
		stage.add_child(live)
		# The spec keys Combat.spawn_enemy adds past the kind (fleet, holds, threat, pressure) change
		# health and behaviour for these kits, not their meshes or materials.
		live.setup(target, null, stage, func() -> bool: return false, 1.0, {"kind": kind})
		var warm := BakeWarm.spawn_view(kit, stage, target, null)
		await process_frame
		var want := _draws(live)
		var got := _draws(warm.get_child(0))
		var painted := want.filter(func(row): return row.owned).size()
		t.check("%s: the warm view draws what a live spawn draws" % kind, got == want and not want.is_empty(), _diff(want, got))
		t.check("%s: its paint is its own, dressed in place" % kind, painted > 0, "%d owned surfaces of %d" % [painted, want.size()])
		var enemy := warm.get_child(0)
		var quiet: bool = not enemy.is_in_group("enemy") and warm.process_mode == Node.PROCESS_MODE_DISABLED \
				and (not enemy is CollisionObject3D or (enemy.collision_layer == 0 and enemy.collision_mask == 0))
		t.check("%s: nothing in play can find it, and it stands out of sight" % kind, quiet and warm.global_position.y < -1000.0)
		live.free()
		warm.free()
	stage.free()
	await process_frame
	quit(t.verdict())


# What a body draws, in tree order: each visual node's class and path; for a mesh, the mesh (a
# shared model mesh itself, one made per spawn by its kind), its skin, each surface's active
# material's shader-relevant state (class, every flag and mode, which textures are set, the bake
# look) and whether the body owns that material (owned_materials).
func _draws(body: Node) -> Array:
	var owned: Array = body.owned_materials() if body.has_method("owned_materials") else []
	var out := []
	for node: VisualInstance3D in body.find_children("*", "VisualInstance3D", true, false):
		var row := {"path": str(body.get_path_to(node)), "class": node.get_class(), "visible": node.is_visible_in_tree(), "owned": false}
		if node is MeshInstance3D and node.mesh != null:
			# A shared model mesh by identity; a mesh each spawn makes for itself (a mast) by its kind.
			row["mesh"] = node.mesh.get_instance_id() if node.mesh is ArrayMesh else node.mesh.get_class()
			row["skin"] = not node.skeleton.is_empty()
			row["surfaces"] = []
			for i in node.mesh.get_surface_count():
				var mat: Material = node.get_active_material(i)
				row.surfaces.append(_shader_state(mat))
				row.owned = row.owned or mat in owned
		out.append(row)
	return out


static func _shader_state(mat: Material) -> Dictionary:
	if mat == null:
		return {}
	var out := {"class": mat.get_class(), "bake_look": mat.get_meta("bake_look", false), "bake_smooth": mat.get_meta("bake_smooth", false)}
	if mat is ShaderMaterial:
		out["shader"] = mat.shader.get_instance_id() if mat.shader != null else 0
		return out
	for prop in mat.get_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		match prop.type:
			TYPE_BOOL, TYPE_INT:
				out[prop.name] = mat.get(prop.name)
			TYPE_OBJECT:
				if prop.hint == PROPERTY_HINT_RESOURCE_TYPE and String(prop.hint_string).contains("Texture"):
					out[prop.name] = mat.get(prop.name) != null
	return out


func _diff(want: Array, got: Array) -> String:
	if want.size() != got.size():
		return "%d drawn nodes live, %d warm" % [want.size(), got.size()]
	for i in want.size():
		if want[i] != got[i]:
			return "first difference at %s: live %s, warm %s" % [want[i].path, want[i], got[i]]
	return ""
