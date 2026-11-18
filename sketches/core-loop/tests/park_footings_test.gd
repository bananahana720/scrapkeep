extends SceneTree

# The footing module decides from the ground, not from a row id: a piece of any listed recipe gets a
# footing where the ground under a sole falls away by more than OFF_GROUND_M, and none where the sole
# sits on the ground or hangs less than the entry's own gap. This is the check a new row of a listed recipe relies on.
const T := preload("res://tests/support/t.gd")
const Footings := preload("res://src/world/park/footings.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const TILE_LENGTH_M := 120.0
const PROBE_M := 0.05
# The recipes the table holds today. The loop below covers whatever the table lists; this count makes an
# entry that goes missing fail, and a new recipe a deliberate edit here.
const RECIPE_COUNT := 3

var t := T.new("park_footings_test")


func _initialize() -> void:
	t.eq("the footing table holds the recipes this test covers", Footings.TABLE.size(), RECIPE_COUNT)
	for recipe: String in Footings.TABLE:
		_check_recipe(recipe, Footings.TABLE[recipe])
	var flat := func(_x: float, _z: float) -> float: return 0.0
	t.check("a recipe with no table entry gets no footing", Footings.fit({"recipe": "crib_pier_2", "size": [10.0, 5.0, 2.0]}, Transform3D.IDENTITY, Transform3D.IDENTITY, [] as Array[Transform3D], flat).is_empty())
	_check_yield()
	quit(t.verdict())


# A sole an authored line passes stays bare, and the module asks with a reach that covers its base and a ball.
func _check_yield() -> void:
	for recipe: String in Footings.TABLE:
		var entry: Dictionary = Footings.TABLE[recipe]
		var row := {"recipe": recipe, "size": [TILE_LENGTH_M, 10.0, 8.0]}
		var tiles: Array[Transform3D] = []
		if entry["tiled"]:
			tiles.append(Transform3D.IDENTITY)
		var deep: float = float(entry["y"]) - 20.0
		var ground := func(_x: float, _z: float) -> float: return deep
		var reaches: Array[float] = []
		var none_ridden := func(_at: Vector2, reach: float) -> bool:
			reaches.append(reach)
			return false
		var all_ridden := func(_at: Vector2, _reach: float) -> bool: return true
		var footed := Footings.fit(row, Transform3D.IDENTITY, Transform3D.IDENTITY, tiles, ground, none_ridden)
		t.check("%s over a deep gap with no line near: footed" % recipe, not footed.is_empty())
		t.check("%s asks about every sole with a reach past a ball's radius and the clearance" % recipe,
				not reaches.is_empty() and reaches.min() > Tuning.RADIUS + Footings.LINE_CLEARANCE_M, "%d asks, least reach %.2f m" % [reaches.size(), reaches.min() if not reaches.is_empty() else 0.0])
		var bare := Footings.fit(row, Transform3D.IDENTITY, Transform3D.IDENTITY, tiles, ground, all_ridden)
		t.check("%s over a deep gap with a line at every sole: bare" % recipe, bare.is_empty())
		for node: Node in footed.values() + bare.values():
			node.free()


func _check_recipe(recipe: String, entry: Dictionary) -> void:
	var row := {"recipe": recipe, "size": [TILE_LENGTH_M, 10.0, 8.0]}
	var tiles: Array[Transform3D] = []
	if entry["tiled"]:
		tiles.append(Transform3D.IDENTITY)
		tiles.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, TILE_LENGTH_M)))
	var sole_y: float = entry["y"]
	var gap: float = entry.get("min_gap", Footings.OFF_GROUND_M)
	var cases := {
		"on the ground": sole_y,
		"just inside the threshold": sole_y - gap + PROBE_M,
		"just past the threshold": sole_y - gap - PROBE_M,
		"over a deep gap": sole_y - 20.0,
	}
	for label: String in cases:
		var level: float = cases[label]
		var ground := func(_x: float, _z: float) -> float: return level
		var footing := Footings.fit(row, Transform3D.IDENTITY, Transform3D.IDENTITY, tiles, ground)
		var wants := level < sole_y - gap
		t.check("%s %s: %s" % [recipe, label, "footed" if wants else "bare"], footing.is_empty() != wants)
		if wants and not footing.is_empty():
			var view := footing["view"] as MeshInstance3D
			var shape := footing["shape"] as CollisionShape3D
			t.check("%s %s: the view and the collision shape draw the same faces" % [recipe, label],
					(shape.shape as ConcavePolygonShape3D).get_faces() == view.mesh.get_faces())
			t.check("%s %s: the concrete reaches the ground" % [recipe, label], view.mesh.get_aabb().position.y <= level)
		for node: Node in footing.values():
			node.free()
