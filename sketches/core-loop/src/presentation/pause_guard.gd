extends Node

var root: Node3D

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	if root != null and is_instance_valid(root):
		root.visible = not get_tree().paused
