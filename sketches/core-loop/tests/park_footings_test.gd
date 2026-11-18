extends SceneTree

# The footing module decides from the ground, not from a row id: a piece of any listed recipe gets a
# footing where the ground under a sole falls away by more than OFF_GROUND_M, and none where the sole
# sits on the ground. This is the check a new row of a listed recipe relies on.
const T := preload("res://tests/support/t.gd")
const Footings := preload("res://src/world/park/footings.gd")
const TILE_LENGTH_M := 120.0
const PROBE_M := 0.05

var t := T.new("park_footings_test")


func _initialize() -> void:
	for recipe: String in Footings.TABLE:
		_check_recipe(recipe, Footings.TABLE[recipe])
	var flat := func(_x: float, _z: float) -> float: return 0.0
	t.check("a recipe with no table entry gets no footing", Footings.fit({"recipe": "crib_pier_2", "size": [10.0, 5.0, 2.0]}, Transform3D.IDENTITY, Transform3D.IDENTITY, [] as Array[Transform3D], flat).is_empty())
	quit(t.verdict())


func _check_recipe(recipe: String, entry: Dictionary) -> void:
	var row := {"recipe": recipe, "size": [TILE_LENGTH_M, 10.0, 8.0]}
	var tiles: Array[Transform3D] = []
	if entry["tiled"]:
		tiles.append(Transform3D.IDENTITY)
		tiles.append(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, TILE_LENGTH_M)))
	var sole_y: float = entry["y"]
	var cases := {
		"on the ground": sole_y,
		"just inside the threshold": sole_y - Footings.OFF_GROUND_M + PROBE_M,
		"just past the threshold": sole_y - Footings.OFF_GROUND_M - PROBE_M,
		"over a deep gap": sole_y - 20.0,
	}
	for label: String in cases:
		var level: float = cases[label]
		var ground := func(_x: float, _z: float) -> float: return level
		var footing := Footings.fit(row, Transform3D.IDENTITY, Transform3D.IDENTITY, tiles, ground)
		var wants := level < sole_y - Footings.OFF_GROUND_M
		t.check("%s %s: %s" % [recipe, label, "footed" if wants else "bare"], footing.is_empty() != wants)
		if wants and not footing.is_empty():
			var view := footing["view"] as MeshInstance3D
			var shape := footing["shape"] as CollisionShape3D
			t.check("%s %s: the view and the collision shape draw the same faces" % [recipe, label],
					(shape.shape as ConcavePolygonShape3D).get_faces() == view.mesh.get_faces())
			t.check("%s %s: the concrete reaches the ground" % [recipe, label], view.mesh.get_aabb().position.y <= level)
		for node: Node in footing.values():
			node.free()
