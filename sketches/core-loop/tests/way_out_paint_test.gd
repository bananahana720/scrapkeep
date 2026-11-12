extends SceneTree

# W1-05 (PF-16, the telegraph half): a warning showed where the hit lands and not where to go. While
# the ball stands in a warning the dodge watch publishes the way out of it (near_miss.gd escape:
# the flat way to the nearest edge and how far it is), and the floor paint (way_out_paint.gd) lays
# bone chevrons from the ball to that edge, marching outward, and a bone bar just past it on the
# safe side. Brindle's ram keeps it up while the hull is still on its way (its lane is live before
# the nose arrives), and an air-only mark raises none, since its answer is to stay down.

const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const NearMiss := preload("res://src/combat/near_miss.gd")
const WayOutPaint := preload("res://src/presentation/way_out_paint.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("way_out_paint_test")


class _Bus:
	signal player_hit(amount: float, source: String)
	signal near_miss(kind: String, at: Vector3)


func _initialize() -> void:
	_reach()
	_strokes()
	_watched.call_deferred()


func _reach() -> void:
	var ring := {"form": "radial", "centre": Vector3.ZERO, "r_in": 0.0, "r_out": 6.0, "a0": 0.0, "a1": TAU}
	var way := NearMiss.way_out_reach(ring, Vector3(2.0, 0.0, 0.0))
	_t.near("a ring: the edge is 4 m out", way["metres"], 4.0)
	var lane := {"form": "lane", "centre": Vector3.ZERO, "dir": Vector3.RIGHT, "back": 0.0, "length": 30.0, "half_width": 2.0}
	way = NearMiss.way_out_reach(lane, Vector3(10.0, 0.0, 0.5))
	_t.near("a lane: 1.5 m to its nearer side", way["metres"], 1.5)
	way = NearMiss.way_out_reach(lane, Vector3(0.5, 0.0, 0.0))
	_t.near("a lane, at its start: 0.5 m back off the start", way["metres"], 0.5)
	_t.check("and way_out is the same direction", way["dir"].is_equal_approx(NearMiss.way_out(lane, Vector3(0.5, 0.0, 0.0))))
	_t.check("no shape: no way and no distance", NearMiss.way_out_reach({}, Vector3.ZERO)["dir"] == Vector3.ZERO and NearMiss.way_out_reach({}, Vector3.ZERO)["metres"] == 0.0)


func _strokes() -> void:
	var at := Vector3(5.0, 2.0, 5.0)
	var metres := 6.0
	var strokes := WayOutPaint.strokes_for(at, Vector3.RIGHT, metres, 0.0)
	var bar: Dictionary = strokes[-1]
	var bar_mid: Vector3 = (bar["from"] + bar["to"]) * 0.5
	_t.near("the bar lies just past the edge, on the safe side", bar_mid.x - at.x, metres + WayOutPaint.BAR_PAST_M)
	_t.check("across the way", absf(bar["from"].x - bar["to"].x) < 0.001 and absf(bar["from"].z - bar["to"].z) > 3.0, str(bar))
	var tips := _tips(strokes, at)
	_t.check("chevrons run from the ball to the edge", tips.size() >= 3 and tips.all(func(x): return x > 0.5 and x <= metres + 0.001), str(tips))
	var arms_back := strokes.slice(0, strokes.size() - 1).all(func(s): return s["from"].x < s["to"].x)
	_t.check("every chevron points along the way (its arms trail behind its tip)", arms_back)
	var later := _tips(WayOutPaint.strokes_for(at, Vector3.RIGHT, metres, 0.1), at)
	_t.check("they march outward", later.size() > 0 and tips.size() > 0 and later[0] > tips[0], "%s then %s" % [tips, later])
	var short := WayOutPaint.strokes_for(at, Vector3.RIGHT, 0.4, 0.0)
	_t.check("an edge right by the ball: the bar alone", short.size() == 1, str(short.size()))
	var paint = WayOutPaint.new()
	paint.paint({"dir": Vector3.BACK, "metres": 3.0}, at)
	_t.check("painted: shown, with a mesh", paint.visible and paint.mesh.get_surface_count() == 1)
	paint.paint({}, at)
	_t.check("no warning: gone", not paint.visible and paint.mesh.get_surface_count() == 0)
	paint.free()


static func _tips(strokes: Array, at: Vector3) -> Array:
	var out := []
	for i in range(0, strokes.size() - 1, 2):
		out.append(snappedf(strokes[i]["to"].x - at.x, 0.001))
	return out


# The dodge watch reads threats in the tree, which takes them only once _initialize returns.
func _watched() -> void:
	var at := [Vector3(1.0, 0.0, -20.0)]
	var bus := _Bus.new()
	var watch := NearMiss.new()
	watch.setup(bus, func(): return at[0])
	root.add_child(watch)
	var ram := Hazard.new()
	ram.commit_lane("charge", Threat.Type.LANE, Vector3.ZERO, Vector3(0, 0, -1), 3.0, 40.0, 4.0, 5.0, 1.0, 2.0)
	ram.lane_front = 3.0
	ram.state = Hazard.LIVE
	ram.add_to_group(Threat.GROUP)
	root.add_child(ram)
	watch.step(1.0 / 60.0)
	var escape: Dictionary = watch.escape()
	var half: float = ram.descriptor()["half_width"]
	_t.check("in the ram's lane with the hull on its way: a way out", not escape.is_empty() and escape["dir"].is_equal_approx(Vector3.RIGHT), str(escape))
	_t.near("to the nearer rail", float(escape.get("metres", -1.0)), half - 1.0)
	at[0] = Vector3(half + 2.0, 0.0, -20.0)
	watch.step(1.0 / 60.0)
	_t.check("out of the lane: none", watch.escape().is_empty())
	ram.free()
	var net := Node3D.new()
	net.set_script(_air_mark())
	net.add_to_group(Threat.GROUP)
	root.add_child(net)
	at[0] = Vector3.ZERO
	watch.step(1.0 / 60.0)
	_t.check("an air-only mark: none (stay down)", watch.escape().is_empty() and watch.standing_in() < 0.0)
	net.free()
	watch.free()
	quit(_t.verdict())


static func _air_mark() -> GDScript:
	var script := GDScript.new()
	script.source_code = """extends Node3D
func contains(_at: Vector3) -> bool:
	return true
func descriptor() -> Dictionary:
	return {"form": "radial", "centre": Vector3.ZERO, "r_in": 0.0, "r_out": 5.0, "a0": 0.0, "a1": TAU, "progress": 0.5, "live": false, "air": true}
"""
	script.reload()
	return script
