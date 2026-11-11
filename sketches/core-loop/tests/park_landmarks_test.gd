extends SceneTree

# Rule (design-v3/park/LANDMARK-CARDS.md port notes P1 to P3, shared test (d)): every park stage places its hero
# landmark once, after its rows, as Landmark_<id> under ParkRows, at its y datum: dam, tower and sinkhole 0, the
# headframe on the pit floor (-100), the spire on the bowl floor (-12) and the isle's pivot (200) PIVOT_HEIGHT above
# its tip, with the hand hanging under the tip. Until a landmark's GLB lands it stands in as a visual-only proxy: no
# collider of any kind, so no route, line or posture band moves. Five stages (all but the pit) carry one ancient beam:
# unshaded uranium green, fog off, no shadow, its bottom at least CLEAR_ABOVE_M over the Warden's anchor, its top over
# sight_top; past 80% of the far plane it draws as its impostor, scaled about the eye so it projects the same. The
# proxy headframe's legs reach the baked ground and keep out of the hive well, and the proxy spire keeps its 30 m waist
# to y 60 (the GLB recipe pins its own, tools/blender/park/landmarks.py).
# The rows themselves place exactly as before: ParkRows holds placed_rows plus the one landmark.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const WardenMind := preload("res://src/combat/warden_mind.gd")
const Palette := preload("res://src/core/palette.gd")

const MAPS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
# The card datums, measured against the committed bakes on cf63e622 and the GLB origins of PR #26.
const DATUM := {"park_dam": 0.0, "park_flume": 0.0, "park_pit": -100.0, "park_sinkhole": 0.0, "park_islands": 200.0, "park_crown": -12.0}
const WELL_HALF_M := 6.0
const WELL_TOP_M := 38.0
const LEG_HALF_M := 1.0
const FOOT_TOLERANCE_M := 0.5

var t := T.new("park_landmarks_test")
var _recipes = load("res://src/world/park/park_recipes.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("park_recipes places landmarks", (_recipes as Script).get_script_method_list().any(func(m): return m["name"] == "place_landmark")):
		quit(t.verdict())
		return
	var parent := Node3D.new()
	root.add_child(parent)
	for map_id: String in MAPS:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
		var bake := ParkGraphTool.load_bake("res://assets/park/" + map_id)
		var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
		var mark: Dictionary = park["landmark"]
		var node: Node3D = _recipes.place_landmark(park, parent, ground)
		if not t.check("%s places its landmark" % map_id, node != null):
			continue
		t.eq("%s landmark is named for its id" % map_id, String(node.name), "Landmark_" + String(mark["id"]))
		t.near("%s landmark stands on its datum" % map_id, node.position.y, DATUM[map_id], 0.001)
		_proxy(map_id, mark, node)
		_beam(map_id, mark, node)
		if map_id == "park_pit" and node.get_meta("landmark_proxy", false):
			_headframe(node, ground)
		elif map_id == "park_islands":
			var tip := node.position.y - WardenMind.PIVOT_HEIGHT
			t.check("park_islands hand hangs under the tip", tip >= float(mark["warden"]["anchor"][1]), "tip %.1f" % tip)
		elif map_id == "park_crown" and node.get_meta("landmark_proxy", false):
			var lower := node.get_node_or_null("LowerShaft") as MeshInstance3D
			t.check("park_crown spire keeps its 30 m waist to y 60", lower != null and (lower.mesh as CylinderMesh).top_radius <= 15.0
				and lower.position.y + (lower.mesh as CylinderMesh).height * 0.5 >= 60.0)
		node.free()
	_impostor()
	_placer(parent)
	quit(t.verdict())


func _proxy(map_id: String, mark: Dictionary, node: Node3D) -> void:
	var glb: String = ParkRecipes.paths(String(mark["recipe"]), "hero_landmark")["base"]
	var views := node.find_children("*", "MeshInstance3D", true, false).filter(func(v): return not v.get_parent().name == "Column")
	if ResourceLoader.exists(glb):
		t.check("%s landmark GLB places views" % map_id, not node.get_meta("landmark_proxy", false) and views.size() > 0)
		return
	t.check("%s landmark stands in as its proxy" % map_id, node.get_meta("landmark_proxy", false) and views.size() >= 2, "%d views" % views.size())
	t.eq("%s proxy has no collider" % map_id, node.find_children("*", "CollisionObject3D", true, false).size() + node.find_children("*", "CollisionShape3D", true, false).size(), 0)


func _beam(map_id: String, mark: Dictionary, node: Node3D) -> void:
	var beam = node.get_node_or_null("AncientBeam")
	if String(mark.get("light", "")) != ParkRecipes.ANCIENT_BEAM:
		t.check("%s has no beam (its light is %s)" % [map_id, JSON.stringify(mark.get("light", ""))], beam == null)
		return
	if not t.check("%s carries the ancient beam" % map_id, beam != null):
		return
	var anchor_y := float(mark["warden"]["anchor"][1])
	t.check("%s beam starts clear of the fight" % map_id, beam.bottom.y >= anchor_y + beam.CLEAR_ABOVE_M - 0.001, "bottom %.1f, anchor %.1f" % [beam.bottom.y, anchor_y])
	t.check("%s beam rises past sight_top" % map_id, beam.top_y > float(mark["sight_top"][1]))
	var core := beam.get_node("Column/Core") as MeshInstance3D
	var material := core.material_override as ShaderMaterial
	var tint: Color = material.get_shader_parameter("tint")
	t.check("%s beam is unshaded uranium green with fog off and no shadow" % map_id, material.shader.code.contains("unshaded")
		and material.shader.code.contains("fog_disabled") and core.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and tint.is_equal_approx(Palette.ANCIENT))


func _headframe(node: Node3D, ground: Callable) -> void:
	var legs := node.find_children("*Leg*", "MeshInstance3D", false, false)
	t.eq("park_pit headframe has four front and two back legs", legs.size(), 6)
	var worst_foot := 0.0
	var in_well := 0
	for leg: MeshInstance3D in legs:
		var half := (leg.mesh as BoxMesh).size.y * 0.5
		var axis := leg.basis.y.normalized()
		var foot := node.transform * (leg.position - axis * half)
		worst_foot = maxf(worst_foot, absf(foot.y - float(ground.call(foot.x, foot.z))))
		for k in 41:
			var p := leg.position + axis * lerpf(-half, half, k / 40.0)
			if p.y <= WELL_TOP_M and absf(p.x) < WELL_HALF_M + LEG_HALF_M and absf(p.z) < WELL_HALF_M + LEG_HALF_M:
				in_well += 1
	t.check("park_pit legs reach the baked ground", worst_foot <= FOOT_TOLERANCE_M, "worst %.2f m" % worst_foot)
	t.eq("park_pit legs keep out of the hive well", in_well, 0)


# The impostor: 1.3 km off with a 700 m far plane, the column scales about the eye to 560 m and projects the same,
# its top inside the far plane.
func _impostor() -> void:
	var holder := Node3D.new()
	var beam = ParkRecipes.LandmarkBeam.make(holder, Vector3(0, 50, 0), 141.0, 0.0)
	var eye := Vector3(0, 150, -1300)
	var xf: Transform3D = beam.impostor(eye, 700.0)
	t.near("impostor moves the column to 80% of the far plane", Vector2(xf.origin.x - eye.x, xf.origin.z - eye.z).length(), 560.0, 0.01)
	t.near("impostor scales by reach over distance", xf.basis.get_scale().x, 560.0 / 1300.0, 0.0001)
	t.check("impostor's top stays inside the far plane", ((xf * Vector3(0, beam.height(), 0)) - eye).length() < 700.0)
	var top := Vector3(0, beam.top_y, 0)
	var seen := (top - eye).normalized()
	var drawn := ((xf * Vector3(0, beam.height(), 0)) - eye).normalized()
	t.check("impostor's top projects where the column's does", seen.is_equal_approx(drawn))
	t.check("a near column draws as built", beam.impostor(Vector3(0, 10, -100), 700.0).is_equal_approx(Transform3D(Basis.IDENTITY, beam.bottom)))
	holder.free()


# The Placer places the landmark once, after the rows, and the rows are as before.
func _placer(parent: Node3D) -> void:
	for map_id: String in ["park_dam", "park_pit"]:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % map_id))
		var bake := ParkGraphTool.load_bake("res://assets/park/" + map_id)
		var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
		var rows: Node3D = ParkRecipes.build_placed(parent, park, ground, Callable(), false)
		var id := "Landmark_" + String(park["landmark"]["id"])
		var marks := rows.get_children().filter(func(n): return String(n.name).begins_with("Landmark_"))
		t.check("%s ParkRows holds its one landmark" % map_id, rows.is_ready() and marks.size() == 1 and marks[0].name == id and rows.landmark == marks[0])
		var placed := 0
		for row: Dictionary in ParkRecipes.placed_rows(park):
			if rows.get_node_or_null("Park_" + String(row["id"])) != null:
				placed += 1
			# A row's rider (the dam's crest crane) stands beside it.
			if row.has("rider") and rows.get_node_or_null("Park_%s_rider" % row["id"]) != null:
				placed += 1
		t.eq("%s rows place as before" % map_id, rows.get_child_count(), placed + 1)
		rows.free()
