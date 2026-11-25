extends "res://src/world/terrain.gd"

var arena


func height(x: float, z: float) -> float:
	return arena.height(x, z)


func _floor(_i: int, x: float, z: float) -> float:
	return arena.height(x, z)


func spawn_point(_index: int) -> Vector3:
	return arena.start_point()


func entry_heading(_index: int) -> Vector3:
	return Vector3.RIGHT


func contains(point: Vector3) -> bool:
	return arena.inside(point)


func rescue_point(_near: Vector3) -> Vector3:
	arena.rescues += 1
	return arena.start_point()
