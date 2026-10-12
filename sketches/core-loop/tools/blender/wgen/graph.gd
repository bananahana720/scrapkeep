extends "res://tools/park_graph.gd"

func _initialize() -> void:
	preload("res://tools/blender/wgen/context.gd").install()
	super._initialize()
