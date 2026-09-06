extends Node

var process_calls: int = 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	process_calls += 1
