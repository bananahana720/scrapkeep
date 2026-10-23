extends SceneTree
# Times a runtime glTF import and counts nodes and meshes. Usage: godot --headless --path . --script res://import_probe.gd -- <glb>
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var t0 := Time.get_ticks_usec()
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	var root := doc.generate_scene(st)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var nodes := 0
	var meshes := 0
	var stack: Array = [root]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		nodes += 1
		if n is MeshInstance3D:
			meshes += 1
		stack.append_array(n.get_children())
	print("IMPORT ", JSON.stringify({"err": err, "ms": ms, "nodes": nodes, "meshes": meshes}))
	quit()
