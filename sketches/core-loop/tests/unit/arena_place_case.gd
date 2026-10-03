extends RefCounted

const Arena := preload("res://src/boss/arena.gd")


class FakeTerrain:
	extends RefCounted
	var asked := []

	func beacon_point(index: int) -> Vector3:
		asked.append(index)
		return Vector3(index * 10.0, 0.0, 0.0)

	func height(_x: float, _z: float) -> float:
		return 0.0


func run(t) -> void:
	for stage in [1, 3, 6]:
		var terrain := FakeTerrain.new()
		Arena.place(terrain, stage)
		t.eq("arena floats over the finished stage's beacon: stage %d" % stage, terrain.asked, [stage])
