extends SceneTree

# Rule (the islands' collider-locked rows, coordinator on #149, 2026-10-19 02:18Z): park_islands' ore_adit, tram_head,
# keel_rib_w and keel_rib_e take drawn pieces (isle_adit_portal, isle_tram_head, isle_keel_rib; built by
# tools/blender/park/isle_pieces.py) while each keeps the collider its greybox row has now, exactly. Only the visual
# changes. Each row is placed through place_row twice, once as its element's greybox and once as its piece, both built
# in memory from the park file's row (so the test holds before and after Restart World switches the recipes in
# park_islands.json, which is that lane's to edit), and the two must agree on the node's place, the Collider (none for
# the two stamped rows, whose stamp collides; the same box for the ribs), the ride sensor and the stamp_replaces mark.
# The piece's views must be drawn meshes only, with no grey box left. Only the adit portal adds collision: its posts and
# side lagging, on a separate PieceCollider body whose every face stands outside the row's 14 m lane, so the pilots'
# lines through the lane meet nothing new (coordinator ruling pending on #149, 2026-10-19).

const T := preload("res://tests/support/t.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")

const MAP := "park_islands"
const PIECES := {"ore_adit": "isle_adit_portal", "tram_head": "isle_tram_head", "keel_rib_w": "isle_keel_rib",
	"keel_rib_e": "isle_keel_rib", "cloud_wash_west": "isle_ride_wash_west", "fin_chute": "isle_ride_fin_chute"}
# The stamped rows carry no collider of their own today: the stamped ground is their shape (place_row).
const STAMPED := ["ore_adit", "tram_head", "cloud_wash_west", "fin_chute"]
# The ride-surface sheet (tools/blender/park/isle_ride_pieces.py): the stamped ground is its whole collider, and every
# vertex of the drawn sheet must lie between MIN_LIFT and FLUSH over it (ghost solid, #183; no z-fight), measured against
# the game's own ground, Terrain._park_floor_at. fin_chute lies inside twin_fins, whose collapse drops the ground 8 m, so
# its row hides on that collapse and parks down with the fins (event_ground.gd hidden_rows).
const SHEETS := ["cloud_wash_west", "fin_chute"]
const HIDE_ON := {"fin_chute": "fin_rim_collapse"}
const FLUSH := 0.12
const MIN_LIFT := 0.03
# The piece whose GLB carries its own uprights' collider, and the least |x| any of its faces may reach in the row frame:
# the inner face of the portal posts (isle_pieces.py ADIT_POST_X - ADIT_POST / 2), outside the 7 m half width.
const PIECE_COLLIDER := {"ore_adit": 9.225}

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
	t.eq("the collider-locked rows are in the park", rows.keys().size(), PIECES.size())
	for id: String in HIDE_ON:
		t.eq("%s leaves with %s" % [id, HIDE_ON[id]], String(rows.get(id, {}).get("hide_on", "")), HIDE_ON[id])
	for recipe: String in PIECES.values():
		t.check("%s is an over-greybox recipe" % recipe, ParkRecipes.OVER_GREYBOX.has(recipe))
		t.check("%s's GLB has landed" % recipe, ResourceLoader.exists(ParkRecipes.paths(recipe, "landform")["base"]))

	var parent := Node3D.new()
	root.add_child(parent)
	for id: String in PIECES:
		var row: Dictionary = rows[id]
		t.check("%s's recipe is its greybox or its piece" % id, row["recipe"] == ParkRecipes.GREYBOX + String(row["element"])
			or row["recipe"] == PIECES[id], row["recipe"])
		var grey_row := row.duplicate(true)
		grey_row["recipe"] = ParkRecipes.GREYBOX + String(row["element"])
		var piece_row := row.duplicate(true)
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
			t.check("%s keeps its greybox's one box" % id, shapes.size() == 2 and shapes[1]["kind"] == "BoxShape3D", "%s" % [shapes])
		t.check("%s has no grey box" % id, piece.get_node_or_null("Greybox") == null)
		var views := piece.find_children("*", "MeshInstance3D", true, false)
		t.check("%s draws its piece" % id, views.size() > 0, "%d views" % views.size())
		var drawn := true
		for view: MeshInstance3D in views:
			drawn = drawn and not String(view.name).ends_with("-col") and view.mesh != null
		t.check("%s's views are drawn meshes only" % id, drawn)
		var extra := piece.get_node_or_null("PieceCollider") as StaticBody3D
		if not PIECE_COLLIDER.has(id):
			t.check("%s adds no collider of its own" % id, extra == null)
			t.eq("%s adds no collision shape (no trimesh from the GLB)" % id,
				ParkRecipes.collider_shapes(piece).size(),
				ParkRecipes.collider_shapes(grey).size())
		elif t.check("%s's piece carries its uprights' collider" % id, extra != null and extra.get_child_count() > 0):
			t.eq("%s's piece collider is on the world layer like the row's" % id, [extra.collision_layer, extra.collision_mask],
				[PhysicsLayers.WORLD_MASK, 0])
			var inner := INF
			var faces := 0
			for shape: Dictionary in ParkRecipes.collider_shapes(extra):
				for v in (shape.shape as ConcavePolygonShape3D).get_faces():
					inner = minf(inner, absf((extra.transform * shape.transform * v).x))
					faces += 1
			t.check("%s's piece collider stands outside the lane" % id, faces > 0 and inner >= PIECE_COLLIDER[id] - 0.001,
				"least |x| %.3f over %d face vertices" % [inner, faces])
		if SHEETS.has(id):
			var lo := INF
			var hi := -INF
			var verts := 0
			for view: MeshInstance3D in views:
				for surface in view.mesh.get_surface_count():
					for v: Vector3 in view.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
						var w := view.global_transform * v
						var off := w.y - float(ground.call(w.x, w.z))
						lo = minf(lo, off)
						hi = maxf(hi, off)
						verts += 1
			t.check("%s's sheet stands between +%.2f and +%.2f over the ground (%.3f .. %.3f over %d vertices)" % [id, MIN_LIFT, FLUSH, lo, hi, verts],
				verts > 0 and hi <= FLUSH and lo >= MIN_LIFT - 0.00001)
		t.check("%s's base view casts shadows" % id, views.any(func(v): return v.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF))
	parent.free()
	quit(t.verdict())


# The Collider body as comparable records, its layers and place first, then each shape's kind, size and transform in
# the row's node space; [] for none.
func _collider(node: Node3D) -> Array:
	var body := node.get_node_or_null("Collider") as StaticBody3D
	if body == null:
		return []
	var out := [{"layer": body.collision_layer, "mask": body.collision_mask, "at": body.transform}]
	for shape: Dictionary in ParkRecipes.collider_shapes(body):
		var rec := {"kind": shape.shape.get_class(), "at": body.transform * shape.transform}
		if shape.shape is BoxShape3D:
			rec["size"] = (shape.shape as BoxShape3D).size
		elif shape.shape is ConvexPolygonShape3D:
			rec["points"] = (shape.shape as ConvexPolygonShape3D).points
		out.append(rec)
	return out


# The ride sensor as a record: its mask and box; {} for none.
func _sensor(node: Node3D) -> Dictionary:
	var area := node.get_node_or_null("Ride") as Area3D
	if area == null:
		return {}
	var shape := area.get_child(0) as CollisionShape3D
	return {"mask": area.collision_mask, "size": (shape.shape as BoxShape3D).size, "at": shape.transform}
