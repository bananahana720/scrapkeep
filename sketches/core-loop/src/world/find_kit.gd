extends RefCounted


const ModelKit := preload("res://src/world/model_kit.gd")
const MODEL := "res://assets/models/world_one/find_kit.glb"
const REQUIRED := ["FindBoardFrame", "FindBoard", "FindAerial", "FindSeep"]


static func part(part_name: String, parent: Node3D) -> MeshInstance3D:
	return ModelKit.part(MODEL, REQUIRED, part_name, parent)
