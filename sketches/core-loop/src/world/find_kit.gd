extends RefCounted

# A field find's dressing as a model (W1-22): the crew notice board and its brass frame, the radio's
# whip aerial and one seep streak (tools/blender/world_one/find_kit.py). activities.gd places them;
# each part is built about its own origin. With the model missing every part is null and the caller
# keeps its plain shapes.

const ModelKit := preload("res://src/world/model_kit.gd")
const MODEL := "res://assets/models/world_one/find_kit.glb"
const REQUIRED := ["FindBoardFrame", "FindBoard", "FindAerial", "FindSeep"]


static func part(part_name: String, parent: Node3D) -> MeshInstance3D:
	return ModelKit.part(MODEL, REQUIRED, part_name, parent)
