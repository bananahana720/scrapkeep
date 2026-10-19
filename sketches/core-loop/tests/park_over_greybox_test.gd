extends SceneTree

# Rule (the islands' collider-locked rows, coordinator on #149, 2026-10-19 02:18Z): park_islands' ore_adit, tram_head,
# keel_rib_w and keel_rib_e take drawn pieces (isle_adit_portal, isle_tram_head, isle_keel_rib; built by
# tools/blender/park/isle_pieces.py) while each keeps the collider its greybox row has now, exactly. Only the visual
# changes. Each row is placed through place_row twice, once as its greybox recipe and once with the piece's recipe in
# memory (park_islands.json itself is Restart World's to edit), and the two must agree on the node's place, the
# Collider (none for the two stamped rows, whose stamp collides; the same box for the ribs), the ride sensor and the
# stamp_replaces mark. The piece's views must be drawn meshes only: no trimesh from the GLB, no grey box left.

const T := preload("res://tests/support/t.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")

const MAP := "park_islands"
const PIECES := {"ore_adit": "isle_adit_portal", "tram_head": "isle_tram_head", "keel_rib_w": "isle_keel_rib",
	"keel_rib_e": "isle_keel_rib"}
# The stamped rows carry no collider of their own today: the stamped ground is their shape (place_row).
const STAMPED := ["ore_adit", "tram_head"]

var t := T.new("park_over_greybox_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % MAP))
	var bake := ParkGraphTool.load_bake("res://assets/park/" + MAP)
	var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
	var publish := func(_kind: String, _at: Vector3) -> void: pass
	var rows := {}
	for row: Dictionary in park["park_rows"]:
		if PIECES.has(String(row.get("id", ""))):
			rows[String(row["id"])] = row
	t.eq("the four collider-locked rows are in the park", rows.keys().size(), PIECES.size())
	for recipe: String in PIECES.values():
		t.check("%s is an over-greybox recipe" % recipe, ParkRecipes.OVER_GREYBOX.has(recipe))
		t.check("%s's GLB has landed" % recipe, ResourceLoader.exists(ParkRecipes.paths(recipe, "landform")["base"]))

	var parent := Node3D.new()
	root.add_child(parent)
	for id: String in PIECES:
		var grey_row: Dictionary = rows[id]
		t.check("%s is a greybox row today" % id, String(grey_row["recipe"]).begins_with(ParkRecipes.GREYBOX), grey_row["recipe"])
		var piece_row := grey_row.duplicate(true)
		piece_row["recipe"] = PIECES[id]
		var grey: Node3D = ParkRecipes.place_row(grey_row, parent, ground, publish)
		var piece: Node3D = ParkRecipes.place_row(piece_row, parent, ground, publish)
		if not t.check("%s places both ways" % id, grey != null and piece != null):
			continue
		t.check("%s is drawn over its greybox" % id, piece.get_meta("over_greybox", false))
		t.check("%s stands where its greybox stood" % id, piece.transform.is_equal_approx(grey.transform),
			"%s against %s" % [piece.transform, grey.transform])
		t.eq("%s keeps the stamp_replaces mark" % id, piece.get_meta("stamp_replaces", false), grey.get_meta("stamp_replaces", false))
		t.eq("%s's collider is unchanged" % id, _collider(piece), _collider(grey))
		t.eq("%s's ride sensor is unchanged" % id, _sensor(piece), _sensor(grey))
		if STAMPED.has(id):
			t.check("%s keeps no collider of its own (the stamp collides)" % id, piece.get_node_or_null("Collider") == null)
		else:
			var shapes: Array = _collider(piece)
			t.check("%s keeps its greybox's one box" % id, shapes.size() == 1 and shapes[0]["kind"] == "BoxShape3D", "%s" % [shapes])
		t.check("%s has no grey box" % id, piece.get_node_or_null("Greybox") == null)
		var views := piece.find_children("*", "MeshInstance3D", true, false)
		t.check("%s draws its piece" % id, views.size() > 0, "%d views" % views.size())
		var drawn := true
		for view: MeshInstance3D in views:
			drawn = drawn and not String(view.name).ends_with("-col") and view.mesh != null
		t.check("%s's views are drawn meshes only" % id, drawn)
		var grey_shapes := grey.find_children("*", "CollisionShape3D", true, false).size()
		t.eq("%s adds no collision shape (no trimesh from the GLB)" % id,
			piece.find_children("*", "CollisionShape3D", true, false).size(), grey_shapes)
		t.check("%s's base view casts shadows" % id, views.any(func(v): return v.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	parent.free()
	quit(t.verdict())


# The Collider body's shapes as comparable records: kind, size and transform in the row's node space; [] for none.
func _collider(node: Node3D) -> Array:
	var body := node.get_node_or_null("Collider") as StaticBody3D
	if body == null:
		return []
	var out := [{"layer": body.collision_layer, "mask": body.collision_mask, "at": body.transform}]
	for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
		var rec := {"kind": shape.shape.get_class(), "at": body.transform * shape.transform}
		if shape.shape is BoxShape3D:
			rec["size"] = (shape.shape as BoxShape3D).size
		elif shape.shape is ConvexPolygonShape3D:
			rec["points"] = (shape.shape as ConvexPolygonShape3D).points
		out.append(rec)
	return out.slice(1) if out.size() > 1 else out


# The ride sensor as a record: its mask and box; {} for none.
func _sensor(node: Node3D) -> Dictionary:
	var area := node.get_node_or_null("Ride") as Area3D
	if area == null:
		return {}
	var shape := area.get_child(0) as CollisionShape3D
	return {"mask": area.collision_mask, "size": (shape.shape as BoxShape3D).size, "at": shape.transform}
