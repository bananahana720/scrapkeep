extends SceneTree
const Terrain := preload("res://src/world/terrain.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
func _init() -> void:
	print("PROBE parks=%d" % Terrain._read_parks_together(ParkDefs).size())
	quit(0)
