extends SceneTree

# A ball that rolls between a reward arch's posts and under its crossbar takes that arch's part at any
# height, mid-jump included. Height is its own bound (the crossbar); it never counts as a sideways miss.
# Free-placed gates count a crossing from the near side only; gates on a map's slots count the far side too.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Fabricators := preload("res://src/build/fabricators.gd")

var t := T.new("reward_gate_crossing_test")


class StubTerrain:
	func height(_x: float, _z: float) -> float:
		return 0.0

	func drop_point(x: float, z: float, _lift: float) -> Vector3:
		return Vector3(x, 0.0, z)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()

	var gates := RewardGates.new()
	holder.add_child(gates)
	gates.setup(StubTerrain.new())
	for h: float in [0.0, 1.2, 5.2, 6.5]:
		t.check("free gate: a pass %.1f m up between the posts chooses the part" % h, _cross(gates, h, 0.0, false), "")
	t.check("free gate: a ball flying over the crossbar (9 m up) chooses nothing", not _cross(gates, 9.0, 0.0, false), "")
	t.check("free gate: a ground pass 6 m to the side chooses nothing", not _cross(gates, 0.0, 6.0, false), "")
	t.check("free gate: a high pass 6 m to the side chooses nothing", not _cross(gates, 5.2, 6.0, false), "")
	t.check("free gate: a pass 4.5 m to the side, within the posts' margin, chooses", _cross(gates, 5.2, 4.5, false), "")
	t.check("free gate: a crossing from the far side chooses nothing", not _cross(gates, 1.2, 0.0, true), "")
	t.check("free gate: a pass just under the crossbar chooses", _cross(gates, RewardGates.HEIGHT - 0.1, 0.0, false), "")
	t.check("free gate: a pass just over the crossbar chooses nothing", not _cross(gates, RewardGates.HEIGHT + 0.1, 0.0, false), "")
	t.check("free gate: a pass on the slope just inside SLOPE_BELOW chooses", _cross(gates, -RewardGates.SLOPE_BELOW + 0.1, 0.0, false), "")
	t.check("free gate: a pass just past SLOPE_BELOW chooses nothing", not _cross(gates, -RewardGates.SLOPE_BELOW - 0.1, 0.0, false), "")
	t.check("free gate: a pass at the edge of the posts' margin chooses", _cross(gates, 0.0, RewardGates.WIDTH * 0.5 + 0.9, false), "")
	t.check("free gate: a pass just past the posts' margin chooses nothing", not _cross(gates, 0.0, RewardGates.WIDTH * 0.5 + 1.1, false), "")
	gates.close()
	for h: float in [-RewardGates.SLOPE_BELOW + 0.1, 0.0, 5.2, RewardGates.HEIGHT - 0.1]:
		for lateral: float in [0.0, 4.5, 6.0]:
			var rel := Vector3(lateral, h, 0.0)
			t.eq("inside_arch agrees with a crossing %.1f m up, %.1f m across" % [h, lateral],
				RewardGates.inside_arch(rel, Vector3.FORWARD), lateral < 5.0)
	t.near("sideways ignores height", RewardGates.sideways(Vector3(3.0, 5.2, -7.0), Vector3.FORWARD), 3.0)
	_fabricator(holder)

	var terrain = Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": "park_dam"}]})
	terrain.build(holder)
	terrain.use(1)
	gates.setup(terrain)
	t.check("slot gate: a near-side pass 5.2 m up chooses", _cross(gates, 5.2, 0.0, false), "")
	t.check("slot gate: a crossing from the far side chooses", _cross(gates, 1.2, 0.0, true), "")
	t.check("slot gate: a ball flying over the crossbar chooses nothing", not _cross(gates, 9.0, 0.0, true), "")

	holder.queue_free()
	await process_frame
	quit(t.verdict())


func _fabricator(holder: Node3D) -> void:
	var fabs := Fabricators.new()
	holder.add_child(fabs)
	var top := Fabricators.RING * 2.0 - Fabricators.SINK
	var reach := Fabricators.WIDTH * 0.5 + 0.5
	for h: float in [0.0, 1.2, 5.2, top - 0.1]:
		t.check("fabricator: a pass %.1f m up through the hoop's middle crosses" % h, _fab_cross(fabs, h, 0.0, false), "")
	t.check("fabricator: a pass from the far side crosses", _fab_cross(fabs, 1.2, 0.0, true), "")
	t.check("fabricator: a high pass at the edge of its reach crosses", _fab_cross(fabs, 5.2, reach - 0.1, false), "")
	t.check("fabricator: a high pass just past its reach crosses nothing", not _fab_cross(fabs, 5.2, reach + 0.1, false), "")
	t.check("fabricator: a ground pass just past its reach crosses nothing", not _fab_cross(fabs, 0.0, reach + 0.1, false), "")
	t.check("fabricator: a pass over the hoop's top crosses nothing", not _fab_cross(fabs, top + 0.1, 0.0, false), "")
	t.check("fabricator: a pass 1.4 m under its base crosses", _fab_cross(fabs, -1.4, 0.0, false), "")
	t.check("fabricator: a pass 1.6 m under its base crosses nothing", not _fab_cross(fabs, -1.6, 0.0, false), "")
	var fab: Dictionary = fabs.add_at(Vector3(40.0, 0.0, 0.0), Vector3.FORWARD, "impact_driver")
	fabs.sold(fab)
	fabs.step(Vector3(40.0, 1.2, 3.0), 0.0, 0, [])
	t.eq("fabricator: a restocking hoop crosses nothing", fabs.step(Vector3(40.0, 1.2, -3.0), 0.0, 0, []).size(), 0)
	fabs.clear()


func _fab_cross(fabs, height: float, lateral: float, from_far: bool) -> bool:
	var at := Vector3(0.0, 0.0, 0.0)
	var facing := Vector3.FORWARD
	var fab: Dictionary = fabs.add_at(at, facing, "impact_driver")
	var across := Vector3.UP.cross(facing).normalized()
	var lead := 3.0 * (1.0 if from_far else -1.0)
	var base := at + across * lateral + Vector3.UP * height
	fabs.step(base + facing * lead, 0.0, 0, [])
	var crossings: Array = fabs.step(base - facing * lead, 0.0, 0, [])
	fabs.clear()
	return crossings.size() == 1 and crossings[0] == fab


# Opens one gate, then moves the ball through its plane at `height` over the gate's base and `lateral`
# metres across the way through; returns whether the part was chosen.
func _cross(gates, height: float, lateral: float, from_far: bool) -> bool:
	var picked := []
	var take := func(id: String) -> void: picked.append(id)
	gates.chosen.connect(take)
	gates.open(["impact_driver"], Vector3(0.0, 0.0, 500.0), Vector3.FORWARD)
	var offer: Dictionary = gates.offers[0]
	var at: Vector3 = offer["at"]
	var facing: Vector3 = offer["facing"]
	var across := Vector3.UP.cross(facing).normalized()
	var lead := 3.0 * (1.0 if from_far else -1.0)
	var base := at + across * lateral + Vector3.UP * height
	gates.step(base + facing * lead, Vector3.FORWARD)
	gates.step(base - facing * lead, Vector3.FORWARD)
	gates.chosen.disconnect(take)
	gates.close()
	return picked.size() == 1
