extends SceneTree

# PARK-SEAT seat probe (from KD1-DRESS's read-only swap_probe, 2026-10-16): for a park stage, opts each candidate row in
# to the seat fit (park_recipes.gd seat_fit) with the named recipe, places it through park_recipes.gd place() on the
# committed bake's ground (terrain.gd's _park_floor_at over ground.bin, holes.bin and under.bin; a cave-in roof is not
# applied), and reports per row: the stretch, the gap between the GLB's authored entry and exit and the ground under
# them, the worst gap along the centre line between them, the GLB's width against the row's, whether every view and
# the collider sit on the one fit transform, or why the row stood in as greybox. Read-only: no park file is written.
#   godot --headless --path sketches/core-loop --script tools/seat_probe.gd -- <map_id> [row_id=recipe ...]
# With no row_id=recipe pairs the candidates are the stage's rows that already name a GLB recipe. Exit 0 when every
# candidate either seats within SEAT_TOLERANCE_M at entry and exit or states a refusal, 1 otherwise, 2 on bad input.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")

const SEAT_TOLERANCE_M := 1.0
const LINE_SAMPLES := 9


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("seat_probe: name a map id, e.g. -- park_dam canal_lips=canal_lip")
		quit(2)
		return
	var map_id := String(args[0])
	var park_path := "res://src/world/park/%s.json" % map_id
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(park_path)) if FileAccess.file_exists(park_path) else null
	var bake := ParkGraphTool.load_bake("res://assets/park/" + map_id)
	if not parsed is Dictionary or not (bake["errors"] as Array).is_empty():
		push_error("seat_probe: %s has no park file or bake (%s)" % [map_id, str(bake["errors"])])
		quit(2)
		return
	var park: Dictionary = parsed
	var ground := Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"])
	var rows := {}
	for r: Dictionary in park["park_rows"]:
		rows[r["id"]] = r
	var candidates := {}
	for k in range(1, args.size()):
		var pair := String(args[k]).split("=")
		candidates[pair[0]] = pair[1] if pair.size() > 1 else String(rows.get(pair[0], {}).get("recipe", ""))
	if candidates.is_empty():
		for id: String in rows:
			var recipe := String(rows[id]["recipe"])
			if recipe != "" and not recipe.begins_with(ParkRecipes.GREYBOX):
				candidates[id] = recipe
	var parent := Node3D.new()
	root.add_child(parent)
	var bad := 0
	print("seat_probe: %s, %d candidates, tolerance %.1f m" % [map_id, candidates.size(), SEAT_TOLERANCE_M])
	print("row | recipe | row L x W m | GLB L x W m | stretch | entry gap m | exit gap m | worst centre-line gap m | views and collider on fit | result")
	for id: String in candidates:
		if not rows.has(id):
			print("%s | %s | - | - | - | - | - | - | - | no such row" % [id, candidates[id]])
			bad += 1
			continue
		var row: Dictionary = rows[id].duplicate(true)
		row["recipe"] = candidates[id]
		row["fit"] = ParkRecipes.FIT_SEAT
		var line := _probe(row, parent, ground)
		print(line["text"])
		if not line["ok"]:
			bad += 1
	print("seat_probe: %d of %d candidates seated or refused with a reason" % [candidates.size() - bad, candidates.size()])
	parent.free()
	quit(0 if bad == 0 else 1)


func _probe(row: Dictionary, parent: Node3D, ground: Callable) -> Dictionary:
	var recipe := String(row["recipe"])
	var size: Array = row["size"]
	var head := "%s | %s | %.1f x %.1f" % [row["id"], recipe, float(size[0]), float(size[2])]
	var path := ParkRecipes.GLB_DIR + recipe + ".glb"
	if not ResourceLoader.exists(path):
		return {"ok": false, "text": head + " | - | - | - | - | - | - | no GLB at " + path}
	var scene: Node = (load(path) as PackedScene).instantiate()
	var ends := ParkRecipes.authored_ends(scene, ParkRecipes.origin(recipe) == ParkRecipes.ORIGIN_ENTRY_LIP)
	var col := _col_box(scene)
	var glb := " | %.1f x %.1f" % [float(ends.get("length", 0.0)), col.size.x]
	var node := ParkRecipes.place(row, parent, ground)
	if node == null:
		scene.free()
		return {"ok": false, "text": head + glb + " | - | - | - | - | - | placed nothing"}
	if node.has_meta("seat_refused"):
		var reason := String(node.get_meta("seat_refused"))
		scene.free()
		return {"ok": true, "text": head + glb + " | %.2f | - | - | - | - | greybox stand-in: %s" % [float(size[0]) / maxf(float(ends.get("length", 0.0)), 0.001), reason]}
	if not node.has_meta("seat_fit"):
		scene.free()
		return {"ok": false, "text": head + glb + " | - | - | - | - | - | placed without a seat fit"}
	var fit: Transform3D = node.get_meta("seat_fit")
	var world := parent.transform * node.transform * fit
	var e: Vector3 = ends["entry"]
	var x: Vector3 = ends["exit"]
	var gap := func(p: Vector3) -> float:
		var w := world * p
		return w.y - float(ground.call(w.x, w.z))
	var entry_gap: float = gap.call(e)
	var exit_gap: float = gap.call(x)
	var worst := 0.0
	for k in LINE_SAMPLES:
		var g: float = gap.call(e.lerp(x, k / float(LINE_SAMPLES - 1)))
		if absf(g) > absf(worst):
			worst = g
	var on_fit := _on_fit(node, scene, fit)
	scene.free()
	var ok := absf(entry_gap) <= SEAT_TOLERANCE_M and absf(exit_gap) <= SEAT_TOLERANCE_M and on_fit == ""
	var result := "seated" if ok else "NOT SEATED"
	if col.size.x > float(size[2]):
		result += "; note: GLB %.1f m wider than the row" % (col.size.x - float(size[2]))
	return {"ok": ok, "text": head + glb + " | %.2f | %+.2f | %+.2f | %+.1f | %s | %s" % [float(node.get_meta("seat_stretch")),
		entry_gap, exit_gap, worst, "yes" if on_fit == "" else on_fit, result]}


# "" when every base view of scene under node sits at fit times its place in the scene and the collider's faces are
# the -col trimesh's faces moved by fit, vertex for vertex (within 1 cm), else what is off.
func _on_fit(node: Node3D, scene: Node, fit: Transform3D) -> String:
	var want := PackedVector3Array()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null:
			continue
		var xf := fit * _relative(source, scene)
		if String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			want.append_array(xf * ParkRecipes._trimesh(source).get_faces())
			continue
		var view := node.get_node_or_null(NodePath(String(source.name))) as MeshInstance3D
		if view == null or not view.transform.is_equal_approx(xf):
			return "view %s off the fit" % source.name
	var got := PackedVector3Array()
	for shape: CollisionShape3D in node.get_node("Collider").get_children():
		got.append_array(shape.transform * (shape.shape as ConcavePolygonShape3D).get_faces())
	if got.size() != want.size() or got.is_empty():
		return "collider %d vertices vs mesh %d" % [got.size(), want.size()]
	var worst := 0.0
	for k in got.size():
		worst = maxf(worst, got[k].distance_to(want[k]))
	if worst > 0.01:
		return "collider off the mesh by %.3f m" % worst
	return ""


func _col_box(scene: Node) -> AABB:
	var out := AABB()
	var first := true
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh != null and String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			var box := _relative(source, scene) * source.mesh.get_aabb()
			out = box if first else out.merge(box)
			first = false
	return out


func _relative(n: Node, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = n
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
