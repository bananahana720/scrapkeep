extends SceneTree

const View := preload("res://src/presentation/cosmetic_presentation.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fua_trail_transparency_test")
	var view := View.new()
	view.trail = Node3D.new()
	view.add_child(view.trail)
	var node := Node3D.new()
	for i in 2:
		var mesh := MeshInstance3D.new()
		mesh.mesh = QuadMesh.new()
		node.add_child(mesh)
		mesh.owner = node
	var packed := PackedScene.new()
	t.eq("trail fixture packs", packed.pack(node), OK)
	node.free()
	var row := {"resource": packed}
	var card := view._take_card(row, "test_trail")
	for stale in [1.0, 0.6]:
		for mesh in card.meshes:
			mesh.transparency = stale
		view._retire(card)
		var reused := view._take_card(row, "test_trail")
		t.check("trail reuses the same card", reused.node == card.node)
		for mesh in reused.meshes:
			t.near("reused card clears transparency before next frame", mesh.transparency, 0.0)
		card = reused
	view.free()
	quit(t.verdict())
