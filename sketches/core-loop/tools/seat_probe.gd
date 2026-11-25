extends SceneTree


const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")

const SEAT_TOLERANCE_M := 1.0
const LINE_SAMPLES := 9
const TILE_JOINT_M := 0.25
const FIT_ARG := "fit="


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
	var fit_kind := ParkRecipes.FIT_SEAT
	for k in range(1, args.size()):
		if String(args[k]).begins_with(FIT_ARG):
			fit_kind = String(args[k]).trim_prefix(FIT_ARG)
			if fit_kind != ParkRecipes.FIT_SEAT and fit_kind != ParkRecipes.FIT_TILE:
				push_error("seat_probe: fit %s is neither seat nor tile" % fit_kind)
				quit(2)
				return
			continue
		var pair := String(args[k]).split("=")
		candidates[pair[0]] = pair[1] if pair.size() > 1 else String(rows.get(pair[0], {}).get("recipe", ""))
	if candidates.is_empty():
		for id: String in rows:
			var recipe := String(rows[id]["recipe"])
			if recipe != "" and not recipe.begins_with(ParkRecipes.GREYBOX) and not ParkRecipes.ANCHOR_KITS.has(recipe):
				candidates[id] = recipe
	var parent := Node3D.new()
	root.add_child(parent)
	var bad := 0
	var tiling := fit_kind == ParkRecipes.FIT_TILE
	if tiling:
		_tileable_report()
	print("seat_probe: %s, fit %s, %d candidates, tolerance %.1f m" % [map_id, fit_kind, candidates.size(), SEAT_TOLERANCE_M])
	if tiling:
		print("row | recipe | row L x W m | GLB L x W m | N | stretch | worst joint step m | worst end gap m | worst centre-line gap m | copies on fit | nodes / draws added | result")
	else:
		print("row | recipe | row L x W m | GLB L x W m | stretch | entry gap m | exit gap m | worst centre-line gap m | views and collider on fit | result")
	for id: String in candidates:
		if not rows.has(id):
			print("%s | %s | - | - | - | - | - | - | - | no such row" % [id, candidates[id]])
			bad += 1
			continue
		var row: Dictionary = rows[id].duplicate(true)
		row["recipe"] = candidates[id]
		row["fit"] = fit_kind
		var line := _probe_tile(row, parent, ground) if tiling else _probe(row, parent, ground)
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


func _tileable_report() -> void:
	print("seat_probe: tileable report, match within %.2f m, cut %.2f m inside each end" % [ParkRecipes.TILE_MATCH_M, ParkRecipes.TILE_SLICE_IN_M])
	print("recipe | budget | GLB length m | entry W x H m | exit W x H m | tileable | reason")
	var yes := 0
	var total := 0
	for recipe: String in ParkRecipes.ROWS:
		var budget := String(ParkRecipes.ROWS[recipe]["budget"])
		if budget == "hero_landmark":
			continue
		total += 1
		if not ResourceLoader.exists(ParkRecipes.GLB_DIR + recipe + ".glb"):
			print("%s | %s | - | - | - | no | no GLB" % [recipe, budget])
			continue
		var ends := ParkRecipes.recipe_ends(recipe)
		var tile := ParkRecipes.recipe_tile(recipe)
		if tile.is_empty():
			print("%s | %s | - | - | - | no | no -col mesh" % [recipe, budget])
			continue
		var cut := func(c: Dictionary) -> String: return "-" if c.is_empty() else "%.2f x %.2f" % [float(c["width"]), float(c["height"])]
		if bool(tile["tileable"]):
			yes += 1
		print("%s | %s | %.1f | %s | %s | %s | %s" % [recipe, budget, float(ends.get("length", 0.0)), cut.call(tile["entry"]), cut.call(tile["exit"]),
			"yes" if bool(tile["tileable"]) else "no", tile["reason"]])
	print("seat_probe: %d of %d recipes tileable" % [yes, total])


func _probe_tile(row: Dictionary, parent: Node3D, ground: Callable) -> Dictionary:
	var recipe := String(row["recipe"])
	var size: Array = row["size"]
	var length := float(size[0])
	var head := "%s | %s | %.1f x %.1f" % [row["id"], recipe, length, float(size[2])]
	var path := ParkRecipes.GLB_DIR + recipe + ".glb"
	if not ResourceLoader.exists(path):
		return {"ok": false, "text": head + " | - | - | - | - | - | - | - | - | no GLB at " + path}
	var scene: Node = (load(path) as PackedScene).instantiate()
	var ends := ParkRecipes.authored_ends(scene, ParkRecipes.origin(recipe) == ParkRecipes.ORIGIN_ENTRY_LIP)
	var authored := float(ends.get("length", 0.0))
	var col := _col_box(scene)
	var glb := " | %.1f x %.1f" % [authored, col.size.x]
	var node := ParkRecipes.place(row, parent, ground)
	if node == null:
		scene.free()
		return {"ok": false, "text": head + glb + " | - | - | - | - | - | - | - | placed nothing"}
	if node.has_meta("tile_refused"):
		var reason := String(node.get_meta("tile_refused"))
		var n0 := ParkRecipes.tile_count(length, maxf(authored, 0.001))
		scene.free()
		return {"ok": true, "text": head + glb + " | %d | %.2f | - | - | - | - | - | greybox stand-in: %s" % [n0, length / (n0 * maxf(authored, 0.001)), reason]}
	if not node.has_meta("tile_fit"):
		scene.free()
		return {"ok": false, "text": head + glb + " | - | - | - | - | - | - | - | placed without a tile fit"}
	var xfs: Array = node.get_meta("tile_fit")
	var n := xfs.size()
	var piece := length / n
	var stretch := float(node.get_meta("tile_stretch"))
	var to_world := parent.transform * node.transform
	var e: Vector3 = ends["entry"]
	var x: Vector3 = ends["exit"]
	var worst_end := 0.0
	var worst_line := 0.0
	for k in n:
		var world: Transform3D = to_world * (xfs[k] as Transform3D)
		var gap := func(p: Vector3) -> float:
			var w := world * p
			return w.y - float(ground.call(w.x, w.z))
		for g: float in [gap.call(e), gap.call(x)]:
			if absf(g) > absf(worst_end):
				worst_end = g
		for s in LINE_SAMPLES:
			var g: float = gap.call(e.lerp(x, s / float(LINE_SAMPLES - 1)))
			if absf(g) > absf(worst_line):
				worst_line = g
	var on_fit := ""
	var want := PackedVector3Array()
	var faces := ParkRecipes.col_faces(scene)
	for k in n:
		want.append_array((xfs[k] as Transform3D) * faces)
		for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			if source.mesh == null or String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
				continue
			var view := node.get_node_or_null(NodePath("%s_tile%d" % [source.name, k])) as MeshInstance3D
			if on_fit == "" and (view == null or not view.transform.is_equal_approx((xfs[k] as Transform3D) * _relative(source, scene))):
				on_fit = "copy %d view %s off its transform" % [k, source.name]
	var got := PackedVector3Array()
	var shapes := 0
	for shape: CollisionShape3D in node.get_node("Collider").get_children():
		got.append_array(shape.transform * (shape.shape as ConcavePolygonShape3D).get_faces())
		shapes += 1
	if on_fit == "" and (got.size() != want.size() or got.is_empty()):
		on_fit = "collider %d vertices vs meshes %d" % [got.size(), want.size()]
	elif on_fit == "":
		var off := 0.0
		for k in got.size():
			off = maxf(off, got[k].distance_to(want[k]))
		if off > 0.01:
			on_fit = "collider off the meshes by %.3f m" % off
	var worst_joint := 0.0
	var chunk := got.size() / n
	for k in range(1, n):
		var z := -length * 0.5 + k * piece
		var cut := ParkRecipes.TILE_SLICE_IN_M * stretch
		var before := ParkRecipes.cross_section(got.slice((k - 1) * chunk, k * chunk), z - cut)
		var after := ParkRecipes.cross_section(got.slice(k * chunk, (k + 1) * chunk), z + cut)
		if before.is_empty() or after.is_empty():
			worst_joint = INF
			continue
		worst_joint = maxf(worst_joint, maxf(absf((before["min"] as Vector2).y - (after["min"] as Vector2).y), absf((before["max"] as Vector2).y - (after["max"] as Vector2).y)))
	var views := 0
	var surfaces := 0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null and child.name != "Greybox":
			views += 1
			surfaces += (child as MeshInstance3D).mesh.get_surface_count()
	scene.free()
	var ok := absf(worst_end) <= SEAT_TOLERANCE_M and worst_joint <= TILE_JOINT_M and on_fit == ""
	var result := "tiled" if ok else "NOT TILED"
	if col.size.x > float(size[2]):
		result += "; note: GLB %.1f m wider than the row" % (col.size.x - float(size[2]))
	return {"ok": ok, "text": head + glb + " | %d | %.2f | %.3f | %+.2f | %+.1f | %s | %d views (%d x %d), %d surfaces, %d shapes | %s" % [n, stretch,
		worst_joint, worst_end, worst_line, "yes" if on_fit == "" else on_fit, views, n, views / n, surfaces, shapes, result]}


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
