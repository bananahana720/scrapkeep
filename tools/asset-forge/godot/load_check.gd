extends SceneTree

# Loads a promoted GLB the way the game would and checks it: Godot headless imports it
# without error, has meshes, and every surface is named for a hero-asset slot.
# Run: godot --headless --path sketches/core-loop --script <this file> -- res://assets/models/<name>.glb

const HeroAssets := preload("res://src/presentation/hero_assets.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else ""
	var failures := 0
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		printerr("LOAD_FAIL append_from_file %s error %d" % [path, err])
		quit(1)
		return
	var scene := doc.generate_scene(state)
	if scene == null:
		printerr("LOAD_FAIL generate_scene returned null")
		quit(1)
		return
	var meshes := 0
	var tris := 0
	var bad := []
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is MeshInstance3D and n.mesh != null:
			meshes += 1
			for s in n.mesh.get_surface_count():
				var slot := HeroAssets.slot_of(n.mesh, s)
				if not HeroAssets.SLOTS.has(slot):
					bad.append(slot)
				var arrays: Array = n.mesh.surface_get_arrays(s)
				tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	var aabb := AABB()
	var first := true
	var stack2: Array[Node] = [scene]
	while not stack2.is_empty():
		var n2: Node = stack2.pop_back()
		stack2.append_array(n2.get_children())
		if n2 is MeshInstance3D and n2.mesh != null:
			var box: AABB = n2.global_transform * n2.get_aabb() if n2.is_inside_tree() else n2.transform * n2.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
	print("LOAD_OK %s meshes=%d tris=%d unknown_slots=%s aabb=%s" % [path, meshes, tris, bad, aabb])
	if meshes == 0 or bad.size() > 0:
		failures += 1
	scene.free()
	quit(failures)
