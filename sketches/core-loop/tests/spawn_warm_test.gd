extends SceneTree

# Rule (perf lane, #241): after a world 1 entry, bake_warm.gd builds each kind the stage can send once
# as a spawn builds it, out of sight for two frames (the second with its death debris, bake_warm_test), so the render pipelines its surfaces need
# compile then and not at the first spawn's first frame. The warm is only worth its frame if it
# draws what the spawn draws: for each kind, the warm view's meshes, the shader-relevant state of
# every surface's active material (the paint a spawn owns, its extras' materials) and its other
# drawn nodes match a live spawn's, built the way Combat.spawn_enemy builds one. Nothing in play
# can find the warm spawn: it is out of the enemy group, has no collision and never processes.

const T := preload("res://tests/support/t.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Director := preload("res://src/world/director.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")

var t := T.new("spawn_warm_test")


# The stage's ground as a kit reads it: flat, 40 m up.
class Ground:
	func height(_x: float, _z: float) -> float:
		return 40.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var target := Node3D.new()
	stage.add_child(target)
	var sent := _sent()
	var kits := BakeWarm.WORLD_KITS[1].filter(func(kit): return BakeWarm.kind_of(kit) in sent)
	t.check("every kind world 1 can send is a world 1 kit", kits.size() == sent.size() and sent.has("plated_brute") and sent.has("foreman"), "%d of %d: %s" % [kits.size(), sent.size(), sent])
	# Twice: as every headless run builds a kit, then as a display builds it, where a rigged kit
	# (the foreman, the dispatcher) seats its GLB's own scene (SpecialRig.seat) and the warm must
	# stand that one.
	for on_screen in [false, true]:
		EnemyMotion.headless_idle = on_screen
		var rig := " on screen" if on_screen else ""
		for kit in kits:
			var kind := BakeWarm.kind_of(kit) + rig
			var live: Node3D = kit.new()
			stage.add_child(live)
			# The spec keys Combat.spawn_enemy adds past the kind (fleet, holds, threat, pressure) change
			# health and behaviour for these kits, not their meshes or materials.
			live.setup(target, null, stage, func() -> bool: return false, 1.0, {"kind": BakeWarm.kind_of(kit)})
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
			# In a game the kit is handed the stage's ground, and a kit may seat itself on it (the
			# dispatcher climbs a mast it builds where it stands): the body and everything it built stay
			# under the holder, and no collider of theirs keeps a layer.
			var seated := BakeWarm.spawn_view(kit, stage, target, Ground.new())
			await process_frame
			var high := []
			var solid := []
			for node: Node3D in [seated.get_child(0)] + seated.find_children("*", "Node3D", true, false):
				# A world-space line mesh with nothing drawn into it (the foreman's tethers, redrawn each
				# tick it processes, which a stood one never does) is at the origin by design and draws nothing.
				var empty: bool = node is MeshInstance3D and (node.mesh == null or node.mesh.get_surface_count() == 0)
				if node.global_position.y > -1000.0 and not empty:
					high.append(str(seated.get_path_to(node)))
				if node is CollisionObject3D and (node.collision_layer != 0 or node.collision_mask != 0):
					solid.append(str(seated.get_path_to(node)))
			t.check("%s: handed a ground, it still stands out of sight with no collider in play" % kind, high.is_empty() and solid.is_empty(), "on the stage %s; solid %s" % [high, solid])
			seated.free()
	EnemyMotion.headless_idle = false
	stage.free()
	await process_frame
	quit(t.verdict())


# Every kind world 1's stages can send on the launch table (Director.kinds_sent): the list the warm
# stands.
func _sent() -> Array:
	var out := []
	for row: Dictionary in ParkDefs.DEFS:
		if int(row["world"]) == 1:
			for kind in Director.kinds_sent(row, ParkDefs):
				if not out.has(kind):
					out.append(kind)
	return out


# What a body draws, in tree order: each visual node's class and path; for a mesh, the mesh (a
# shared model mesh itself, one made per spawn by its kind), its skin, each surface's active
# material's shader-relevant state (class, every flag and mode, which textures are set, the bake
# look) and whether the body owns that material (owned_materials).
func _draws(body: Node) -> Array:
	var owned: Array = body.owned_materials() if body.has_method("owned_materials") else []
	var out := []
	for node: VisualInstance3D in body.find_children("*", "VisualInstance3D", true, false):
		var row := {"path": _steady(str(body.get_path_to(node))), "class": node.get_class(), "visible": node.is_visible_in_tree(), "owned": false}
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


# A path with the engine's counter taken off every unnamed node ("@MeshInstance3D@64" is
# "@MeshInstance3D"): the counter is the session's, so two builds of one kit never share it.
static func _steady(path: String) -> String:
	var parts := path.split("/")
	for i in parts.size():
		if parts[i].begins_with("@"):
			parts[i] = "@" + parts[i].get_slice("@", 1)
	return "/".join(parts)


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
