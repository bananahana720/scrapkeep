extends "res://tools/qa/collision_sweep.gd"

func _add_fixture_wall(label: String, x: float, mesh_offset_z: float, drawn: bool) -> void:
	super._add_fixture_wall(label, x, mesh_offset_z, drawn)
	if label == "Park_QAWall_Matched":
		for mesh in game.get_node(label).find_children("*", "MeshInstance3D", true, false):
			mesh.layers = 0
			print("LAYER_CONTROL layers=", mesh.layers, " visible_in_tree=", mesh.is_visible_in_tree())
