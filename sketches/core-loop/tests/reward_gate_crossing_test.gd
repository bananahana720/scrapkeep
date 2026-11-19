extends SceneTree

# A ball that rolls between a reward arch's posts and under its crossbar takes that arch's part at any
# height, mid-jump included. Height is its own bound (the crossbar); it never counts as a sideways miss.
# Free-placed gates count a crossing from the near side only; gates on a map's slots count the far side too.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")

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
	gates.close()

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
