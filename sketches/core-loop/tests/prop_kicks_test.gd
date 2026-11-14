extends SceneTree

const T := preload("res://tests/support/t.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const PropKicks := preload("res://src/presentation/prop_kicks.gd")

# The ball meets the dam's dressing (thread "Make collisions feel physical", 13 Nov 2026;
# src/presentation/prop_kicks.gd). The real park_dam vignette file and kit, built as the game builds
# them (ParkProps.build_nodes), on the dam's committed ground. Covers: heroes and tall props are not
# indexed and every indexed prop owns its drawn copies; a ball at 14 m/s through a light prop throws
# it ahead, where it comes to rest on the ground; a heavier prop
# slides a little and stands; a plant bends and comes back to where it stood; a ball under KICK_SPEED
# moves nothing. Evidence limit: transforms in a headless run, not the look, which needs the PC.

const ID := "park_dam"
const RADIUS := 1.0

var t := T.new("prop_kicks_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := ParkProps.world_for(ID)
	var file := ParkProps.load_json(ParkProps.FILE_DIR + ID + ".json")
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	var list := ParkProps.expand(file, kit, world["map"], world["ground"], c)
	var built := ParkProps.build_nodes(list, kit)
	root.add_child(built)
	var views: Array = []
	_collect(built, views)
	var eligible := func(inst: Dictionary) -> bool: return inst["class"] != ParkProps.HERO and ParkProps.tier_of(inst) != "tall"
	var kicks := PropKicks.new()
	kicks.index(list, eligible, views)
	var ground: Callable = world["ground"]
	var height := func(x: float, z: float) -> float: return (ground.call(x, z, 0.0) as Vector3).y
	var heroes := list.filter(func(i: Dictionary) -> bool: return not eligible.call(i)).size()
	t.check("the dam's small props are indexed, heroes and tall ones are not", kicks.count() > 20 and kicks.count() == list.size() - heroes,
		"%d of %d indexed, %d standing" % [kicks.count(), list.size(), heroes])
	var orphan := 0
	for id in kicks.count():
		if kicks._props[id]["slots"].is_empty():
			orphan += 1
	t.check("every indexed prop owns its drawn copies (its LOD batches or its litter batch)", orphan == 0, "%d without a copy" % orphan)

	for mode in ["fly", "shove", "bend"]:
		var id := _first(kicks, mode)
		if id < 0:
			t.skip("a %s prop on the dam" % mode, "none in the file")
			continue
		var from: Transform3D = kicks.base_of(id)
		var at := from.origin
		# Too slow: rolling through at 3 m/s moves nothing.
		var slow := kicks.step(1.0 / 90.0, at + Vector3.UP * RADIUS, Vector3(3, 0, 0), RADIUS, height)
		t.check("%s: a ball under KICK_SPEED moves nothing" % mode, slow.is_empty() and kicks.live_count() == 0, "%d kicks" % slow.size())
		var got := kicks.step(1.0 / 90.0, at + Vector3.UP * RADIUS, Vector3(14, 0, 0), RADIUS, height)
		t.check("%s: a ball at 14 m/s kicks it once" % mode, got.size() >= 1 and got.any(func(k: Dictionary) -> bool: return k["mode"] == mode), str(got.map(func(k): return k["mode"])))
		var frames := 0
		while kicks.live_count() > 0 and frames < 600:
			kicks.step(1.0 / 90.0, Vector3(1e6, 0, 1e6), Vector3.ZERO, RADIUS, height)
			frames += 1
		var rest: Transform3D = kicks.base_of(id)
		var moved := rest.origin.distance_to(at)
		t.check("%s: comes to rest within %d frames" % [mode, frames], frames < 600, "%d frames" % frames)
		var ground_y: float = height.call(rest.origin.x, rest.origin.z)
		match mode:
			"fly":
				t.check("fly: thrown ahead along the push, at least 2 m", rest.origin.x - at.x >= 2.0, "%.1f m along, %.1f m in all" % [rest.origin.x - at.x, moved])
				t.check("fly: at rest on the ground, lying down", absf(rest.origin.y - ground_y) <= 1.0 and absf(rest.basis.y.normalized().y) < 0.5,
					"%.2f m over the ground, up %.2f" % [rest.origin.y - ground_y, rest.basis.y.normalized().y])
			"shove":
				t.check("shove: slides along the push, no more than SHOVE_MAX_M", rest.origin.x > at.x and moved <= PropKicks.SHOVE_MAX_M + 0.05, "%.2f m" % moved)
				t.check("shove: still standing", rest.basis.is_equal_approx(from.basis), "basis kept")
			"bend":
				t.check("bend: came back to where it stood", rest.is_equal_approx(from), "%.3f m off" % moved)
	built.free()
	quit(t.verdict())


func _collect(node: Node, out: Array) -> void:
	if node is MultiMeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _first(kicks, mode: String) -> int:
	for id in kicks.count():
		if kicks._props[id]["mode"] == mode and not kicks._props[id]["slots"].is_empty():
			return id
	return -1
