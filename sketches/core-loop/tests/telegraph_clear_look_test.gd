extends SceneTree

const T := preload("res://tests/support/t.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The telegraph row's clear and edges looks (Andrew, 13 Nov 2026: the warnings hid the attack they
# warn of). Against haze, clear keeps every ground outline and keyline and contains(), and changes
# only what stood over the play: the fence's air rail has no charcoal keyline and is thin, the fence
# fades out further from the lens, a live lane's band is lighter, and the driven marks are depth
# tested so bodies draw over them. Edges also halves every area fill.

var _t := T.new("telegraph_clear_look_test")


class Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	_run.call_deferred()


func _lane(world: Node3D) -> Node3D:
	return Telegraph.lane(world, Flat.new(), Threat.Type.LANE, Vector3.ZERO, Vector3.FORWARD, 20.0, 3.0, 2.2)


func _by_role(marks: Array) -> Dictionary:
	var out := {}
	for m in marks:
		out[m["role"]] = m
	return out


func _height_span(tris: PackedVector3Array) -> float:
	var lo := INF
	var hi := -INF
	for v in tris:
		lo = minf(lo, v.y)
		hi = maxf(hi, v.y)
	return hi - lo


# Per layer: whether its material is depth tested, and its lens fade.
func _materials(painter) -> Dictionary:
	var out := {}
	for layer in painter._layers:
		var mat = painter._layers[layer].material_override
		if mat is ShaderMaterial:
			out[layer] = [mat.shader.code.contains("DEPTH_AWARE"), mat.get_shader_parameter("lens")]
		else:
			out[layer] = [not mat.no_depth_test, Vector2(mat.distance_fade_min_distance, mat.distance_fade_max_distance)]
	return out


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var looks := {}
	for name in ["haze", "clear", "edges"]:
		Threat.set_look(name)
		var lane := _lane(world)
		var d: Dictionary = lane.descriptor()
		var live := d.duplicate()
		live["live"] = true
		live["progress"] = 1.0
		looks[name] = {"static": _by_role(Threat.marks(d, false)), "under": Threat.marks(d, false).filter(func(m): return m["role"] == "band_top_under"),
			"live": Threat.drive(live)[Threat._area_layer(d, true)]["alpha"], "run": Threat._area_tone(d, Threat.RUN_ALPHA).a,
			"layers": lane.painter()._layers.keys(), "materials": _materials(lane.painter()), "inside": lane.contains(Vector3(0.0, 1.0, -10.0)), "outside": lane.contains(Vector3(3.0, 1.0, -10.0))}
		var mat: ShaderMaterial = Threat.Painter.mark_material("fill", false, Threat.PRIORITY, true)
		looks[name]["depth"] = mat.shader.code.contains("DEPTH_AWARE")
		lane.free()
	var haze: Dictionary = looks["haze"]
	var clear: Dictionary = looks["clear"]
	var edges: Dictionary = looks["edges"]
	_t.check("haze keeps its keylined rail on the base layer", haze["under"].size() == 1 and haze["static"]["band_top"]["layer"] == "base"
		and not "fence" in haze["layers"] and not haze["depth"], str(haze["layers"]))
	var rail: Dictionary = clear["static"]["band_top"]
	_t.check("clear's rail has no keyline and stands thin on the fence layer", clear["under"].is_empty() and rail["layer"] == "fence"
		and clear["static"]["band"]["layer"] == "fence" and "fence" in clear["layers"]
		and is_equal_approx(_height_span(rail["tris"]), Threat.CLEAR_RAIL_HALF * 2.0)
		and is_equal_approx(rail["tone"].a, Threat.CLEAR_RAIL_ALPHA), "rail %.2f m tall at alpha %.2f" % [_height_span(rail["tris"]), rail["tone"].a])
	var same := true
	for role in ["edge", "edge_under", "area"]:
		same = same and clear["static"][role]["tris"] == haze["static"][role]["tris"] and clear["static"][role]["tone"] == haze["static"][role]["tone"]
	_t.check("clear keeps the ground outline, its keyline and the area", same)
	_t.check("contains() is the same in every look", haze["inside"] and clear["inside"] and edges["inside"]
		and not haze["outside"] and not clear["outside"] and not edges["outside"])
	_t.near("clear's live lane band", clear["live"] * Threat.RUN_ALPHA, Threat.CLEAR_LIVE_ALPHA)
	_t.near("haze's live lane band is unchanged", haze["live"] * Threat.RUN_ALPHA, Threat.LIVE_ALPHA)
	_t.check("the soft looks draw driven marks depth tested", clear["depth"] and edges["depth"])
	var tested := true
	for layer in clear["materials"]:
		tested = tested and clear["materials"][layer][0]
	_t.check("clear draws every lane layer depth tested, the tinted fill too", tested, str(clear["materials"]))
	_t.check("haze draws no lane layer depth tested", haze["materials"].values().all(func(m): return not m[0]), str(haze["materials"]))
	_t.eq("clear's fence fades out further from the lens", clear["materials"].get("fence", [false, Vector2.ZERO])[1], Vector2(Threat.FENCE_CLEAR, Threat.FENCE_FULL))
	_t.near("edges halves the area fill", edges["run"], haze["run"] * Threat.EDGES_FILL)
	_t.near("clear keeps the area fill", clear["run"], haze["run"])
	Threat.set_look("haze")
	quit(_t.verdict())
