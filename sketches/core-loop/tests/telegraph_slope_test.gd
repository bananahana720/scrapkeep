extends SceneTree

const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

# A combat telegraph on a slope is drawn on the ground under each mark, uphill and downhill:
# every vertex near a sample sits at the slope's height there plus the telegraph's lift. Since
# wave 36 no mark stands up off the ground (PF-27), so a planted post at reach must fail.

const SLOPE := 0.2
const TOLERANCE := 0.8
const T := preload("res://tests/support/t.gd")

class Slope:
	func height(_x: float, z: float) -> float:
		return SLOPE * z

var _t := T.new("telegraph_slope_test")


func _initialize() -> void:
	_run.call_deferred()


# The worst distance of a drawn vertex near z from the ground under it plus the lift; -INF
# when nothing is drawn there.
func _drawn_gap(painter, z: float) -> float:
	var gap := -INF
	for layer in painter._layers:
		var mi: MeshInstance3D = painter._layers[layer]
		if mi.mesh == null:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		gap = maxf(gap, _gap(verts, z))
	return gap


static func _gap(verts: PackedVector3Array, z: float) -> float:
	var gap := -INF
	for v in verts:
		if absf(v.z - z) <= 1.0:
			gap = maxf(gap, absf(v.y - (SLOPE * v.z + Telegraph.LIFT)))
	return gap


func _check(name: String, ok: bool, detail: String) -> void:
	_t.check(name, ok, detail)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var lane = Telegraph.lane(world, Slope.new(), Threat.Type.LANE, Vector3.ZERO, Vector3(0, 0, 1), 20.0, 3.0, 3.5)
	var painter = lane.painter()
	for z in [0.0, 20.0]:
		var gap := _drawn_gap(painter, z)
		_check("slope z=%.0f" % z, gap > -INF and gap <= TOLERANCE, "worst drawn vertex off the ground under it: %.2f m" % gap)
	var post := PackedVector3Array([Vector3(0.0, Telegraph.LIFT, 0.0), Vector3(0.0, 3.5 + Telegraph.LIFT, 0.0), Vector3(0.1, Telegraph.LIFT, 0.0)])
	_check("planted: a post at reach fails", _gap(post, 0.0) > TOLERANCE, "a 3.5 m post: %.2f m off the ground" % _gap(post, 0.0))
	quit(_t.verdict())
