extends SceneTree

const Sequence := preload("res://src/ui/ending_sequence.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")

# Cold crater GLBs allocate dummy-renderer mesh RIDs on loader threads while
# the live effect and ending snapshot use the same owner on the main thread.
const COLD_ENDINGS := 128


func _initialize() -> void:
	if "--child" in OS.get_cmdline_user_args():
		_child.call_deferred()
	else:
		_parent.call_deferred()


func _parent() -> void:
	var t := T.new("ending_rid_test")
	var jobs := []
	for i in 4:
		jobs.append({"script": "res://tests/ending_rid_test.gd", "args": ["--child"]})
	var results := ChildRuns.run(jobs, 90.0)
	for i in results.size():
		var result: Dictionary = results[i]
		var summary := ChildRuns.summary(result)
		t.check("cold ending %d has no engine errors" % i, summary["errors"].is_empty(), str(summary["errors"]))
		t.check("cold ending %d completes its snapshots" % i,
			not result["timed_out"] and summary["verdict"] == "ending_rid_child: PASS", str(summary["verdict"]))
		if not summary["errors"].is_empty():
			print(result["log"])
	quit(t.verdict())


func _child() -> void:
	var t := T.new("ending_rid_child")
	var source := load("res://assets/models/world_one/shell_cannon.glb").instantiate() as Node3D
	root.add_child(source)
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	t.check("source has cannon meshes", not meshes.is_empty())
	var effect := MeshInstance3D.new()
	effect.name = "LiveEffect"
	source.add_child(effect)
	for i in COLD_ENDINGS:
		var seq := Sequence.new()
		root.add_child(seq)
		seq._scene = Node3D.new()
		seq.add_child(seq._scene)
		seq._build_crater()
		for j in 64:
			effect.mesh = BoxMesh.new()
			var copy := Node3D.new()
			seq._scene.add_child(copy)
			seq._snapshot(source, copy, true)
			copy.free()
		while not seq._place_crater():
			await process_frame
		t.check("cold crater %d has draw meshes" % i,
			not seq.crater.find_children("*", "MeshInstance3D", true, false).is_empty())
		var invalid := _invalid_meshes(seq.crater)
		invalid.append_array(_invalid_meshes(source))
		if not invalid.is_empty():
			t.check("cold ending %d keeps mesh RID surfaces" % i, false, str(invalid))
		seq.free()
	source.free()
	quit(t.verdict())


func _invalid_meshes(parent: Node) -> Array:
	var invalid := []
	for view: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		if view.mesh != null and RenderingServer.mesh_get_surface_count(view.mesh.get_rid()) != view.mesh.get_surface_count():
			invalid.append("%s mesh=%s resource=%s rid=%s skin=%s skeleton=%s" % [view.get_path(),
				view.mesh.get_class(), view.mesh.resource_path, view.mesh.get_rid(), view.skin, view.skeleton])
	return invalid
