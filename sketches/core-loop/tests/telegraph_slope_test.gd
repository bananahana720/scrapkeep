extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

# A combat telegraph on a slope is drawn on the ground under each mark, so its drawn
# height band ends where contains() ends, uphill and downhill.

const SLOPE := 0.2
const TOLERANCE := 0.8
const T := preload("res://tests/support/t.gd")

class Slope:
	func height(_x: float, z: float) -> float:
		return SLOPE * z

var _t := T.new("telegraph_slope_test")


func _initialize() -> void:
	_run.call_deferred()


func _drawn_gap(painter, lane, z: float) -> float:
	var gap := -INF
	for layer in painter._layers:
		var mi: MeshInstance3D = painter._layers[layer]
		if mi.mesh == null:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in verts:
			if absf(v.z - z) <= 1.0:
				var top := _contained_top(lane, v.z)
				if top > -INF:
					gap = maxf(gap, v.y - top)
	return gap


func _contained_top(lane, z: float) -> float:
	var top := -INF
	var y := -2.0
	while y < 12.0:
		if lane.contains(Vector3(0.0, y, z)):
			top = y
		y += 0.05
	return top


func _check(name: String, ok: bool, detail: String) -> void:
	_t.check(name, ok, detail)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var lane = Telegraph.lane(world, Slope.new(), Threat.Type.LANE, Vector3.ZERO, Vector3(0, 0, 1), 20.0, 3.0, 3.5)
	var painter = lane.painter()
	for z in [0.0, 20.0]:
		var gap := _drawn_gap(painter, lane, z)
		_check("slope z=%.0f" % z, absf(gap) <= TOLERANCE, "highest drawn mark vs contains top: %.2f" % gap)
	quit(_t.verdict())
