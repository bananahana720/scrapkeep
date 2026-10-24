extends "res://src/world/terrain.gd"
# The matchup lab's terrain for a pocket duel (--pocket=<shape>). The lab swaps the live Terrain instance's script for
# this one (set_script on the same object), so every holder of ctx.terrain, and every enemy handed it at spawn, reads
# the pocket: `height`, `drop_point` (through height), `spawn_point`, `entry_heading`, `contains` and `rescue_point`.
# Everything else (map(), world(), overlays, the park surfaces) stays the legacy map's, which is only a host.
# Nothing here ships: the lab is the only caller.

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


# A ball or enemy out of the pocket is put back at the entry. The lab counts these in the row (`rescues`).
func rescue_point(_near: Vector3) -> Vector3:
	arena.rescues += 1
	return arena.start_point()
