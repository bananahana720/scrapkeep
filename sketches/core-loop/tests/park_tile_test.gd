extends SceneTree

# 2026-10-16 (PARK-TILE, coordinator ruling TI1): a park row that says "fit": "tile" repeats its shorter GLB end to end,
# each copy seated on the ground at its own ends (park_recipes.gd tile_fit). On a sloped, rolling ground and a yawed
# row RATIO times the GLB's authored length:
# (a) the row draws N = round(RATIO) copies, read back from the placed base views (not the node's meta), each stretched
#     along its length only by row length / (N x authored length);
# (b) every copy's authored entry and exit sit within EPS_M of the ground, in plan at the copy's own ends along the row;
# (c) at every joint copy k's exit is copy k + 1's entry, and their collider cross-sections at the joint step at most
#     JOINT_M vertically; the chain follows the ground: a joint stands more than BEND_M off the straight entry-to-exit
#     line somewhere, so one seated piece could not have matched it;
# (d) the collider is every copy's -col trimesh moved by that copy's transform, vertex for vertex, on unstretched shapes,
#     and each copy carries the base's visibility range and its detail shells;
# (e) tileability is measured from the -col cross-sections: an in-memory box tiles, an in-memory taper does not, and a
#     tile row of a non-tileable recipe or of a stretch outside 0.75 to 1.5 stands in as greybox and says why, with
#     stands_in() agreeing; the same row without fit still places its one GLB at the entry-lip offset;
# (f) the schema takes "fit": "tile" on a GLB row and refuses it on a greybox row.
# Red before PARK-TILE: "tile" is no fit, so the row places one level GLB and (a) finds no copies.
# Evidence limit: transforms and collider faces only; no ball rolls the chain and no feel claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

const RECIPE := "slot_canyon_flow"
const RATIO := 4.2
const EPS_M := 0.05
const JOINT_M := 0.25
const BEND_M := 1.0
const SLICE_IN_M := 0.05
const SLOPE_Z := -0.2
const SLOPE_X := 0.05
const ROLL_M := 6.0
const ROLL_WAVE_M := 30.0

var _t := T.new("park_tile_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var ground := func(x: float, z: float) -> float: return 40.0 + SLOPE_Z * z + SLOPE_X * x + ROLL_M * sin(z / ROLL_WAVE_M)
	var scene: Node = (load(ParkRecipes.GLB_DIR + RECIPE + ".glb") as PackedScene).instantiate()
	_check_tile(parent, ground, scene)
	_check_tileable(parent, ground, scene)
	_check_schema()
	scene.free()
	parent.free()
	quit(_t.verdict())


func _row(id: String, length: float, recipe := RECIPE) -> Dictionary:
	return {"id": id, "element": "flow_line", "at": [30.0, 20.0], "y": null, "size": [length, 2.0, 30.0], "yaw_deg": 20.0,
		"ride_fact": "", "recipe": recipe, "budget": "landform", "stamp": "", "fit": "tile"}


func _check_tile(parent: Node3D, ground: Callable, scene: Node) -> void:
	var ends := _ends(scene)
	var authored := float(ends.get("length", 0.0))
	_t.check("the %s GLB has authored ends" % RECIPE, authored > 10.0, str(ends))
	var length := authored * RATIO
	var n := roundi(RATIO)
	var row := _row("tiled", length)
	var node := ParkRecipes.place(row, parent, ground)
	if not _t.check("the tile row places a node", node != null and not node.has_meta("tile_refused"), str(node.get_meta("tile_refused", "")) if node != null else "null"):
		return
	# (a) The copies, from the views: each base mesh drawn once per copy, named <mesh>_tile<k>. Odd copies draw
	# SURFACE_LAYER_M up so the joints' shared faces do not z-fight (clip audit, 30 Oct); the fit is the view less it.
	var copies := []
	while true:
		var fit = _view_fit(node, scene, "_tile%d" % copies.size())
		if not fit is Transform3D:
			break
		var lift := ParkRecipes.SURFACE_LAYER_M * float(copies.size() % 2)
		copies.append((fit as Transform3D).translated(Vector3(0.0, -lift, 0.0)))
	print("park_tile_test: row %.1f m of a %.1f m GLB on a rolling %.0f%% slope at yaw 20: %d copies" % [length, authored, absf(SLOPE_Z) * 100.0, copies.size()])
	if not _t.eq("(a) the row draws round(row / GLB) copies", copies.size(), n):
		return
	var stretch := length / (n * authored)
	var piece := length / n
	var all_unit := true
	var all_stretch := true
	for fit: Transform3D in copies:
		all_unit = all_unit and fit.basis.x.is_equal_approx(Vector3.RIGHT) and fit.basis.y.is_equal_approx(Vector3.UP)
		all_stretch = all_stretch and absf(fit.basis.z.z - stretch) < 0.001
	_t.check("(a) every copy keeps its width and height axes unstretched", all_unit)
	_t.check("(a) every copy stretches by row / (N x GLB) = %.3f along its length" % stretch, all_stretch)
	# (b) Each copy's ends on the ground at its own ends along the row.
	var worst_y := 0.0
	var worst_plan := 0.0
	var joints: Array[Vector3] = []
	for k in n:
		var world: Transform3D = node.transform * (copies[k] as Transform3D)
		var want_entry := node.transform * Vector3(0, 0, -length * 0.5 + k * piece)
		var want_exit := node.transform * Vector3(0, 0, -length * 0.5 + (k + 1) * piece)
		for pair in [[world * (ends["entry"] as Vector3), want_entry], [world * (ends["exit"] as Vector3), want_exit]]:
			var got: Vector3 = pair[0]
			var want: Vector3 = pair[1]
			worst_y = maxf(worst_y, absf(got.y - float(ground.call(got.x, got.z))))
			worst_plan = maxf(worst_plan, Vector2(got.x, got.z).distance_to(Vector2(want.x, want.z)))
		if k == 0:
			joints.append(world * (ends["entry"] as Vector3))
		joints.append(world * (ends["exit"] as Vector3))
	print("park_tile_test: worst end gap to ground %.4f m, worst end off its plan place %.4f m" % [worst_y, worst_plan])
	_t.check("(b) every copy's entry and exit sit on the ground", worst_y < EPS_M, "%.4f m" % worst_y)
	_t.check("(b) every copy's ends are at its own ends along the row", worst_plan < EPS_M, "%.4f m" % worst_plan)
	# (c) The joints meet, and the chain bends with the ground.
	var worst_meet := 0.0
	for k in range(1, n):
		var exit_k: Vector3 = (node.transform * (copies[k - 1] as Transform3D)) * (ends["exit"] as Vector3)
		var entry_k: Vector3 = (node.transform * (copies[k] as Transform3D)) * (ends["entry"] as Vector3)
		worst_meet = maxf(worst_meet, exit_k.distance_to(entry_k))
	_t.check("(c) each copy's exit is the next copy's entry", worst_meet < EPS_M, "%.4f m" % worst_meet)
	var bend := 0.0
	for k in range(1, n):
		bend = maxf(bend, absf(joints[k].y - lerpf(joints[0].y, joints[n].y, k / float(n))))
	print("park_tile_test: chain falls %.1f m end to end; worst joint off the straight line %.2f m" % [joints[0].y - joints[n].y, bend])
	_t.check("(c) the chain follows the rolling ground, not one straight line", bend > BEND_M, "%.2f m" % bend)
	# (d) The collider: every copy's -col faces moved by its transform, on shapes with no transform of their own.
	var col := _col_faces(scene)
	var want := PackedVector3Array()
	for fit: Transform3D in copies:
		want.append_array(fit * col)
	var got := PackedVector3Array()
	var plain := true
	for shape: CollisionShape3D in node.get_node("Collider").get_children():
		plain = plain and shape.transform.is_equal_approx(Transform3D.IDENTITY)
		got.append_array(shape.transform * (shape.shape as ConcavePolygonShape3D).get_faces())
	var worst := INF
	if got.size() == want.size() and not got.is_empty():
		worst = 0.0
		for k in got.size():
			worst = maxf(worst, got[k].distance_to(want[k]))
	print("park_tile_test: collider %d vertices, meshes %d, worst %.4f m" % [got.size(), want.size(), worst])
	_t.check("(d) the collider is every copy's -col mesh on its transform, vertex for vertex", worst < 0.01, "worst %.4f m" % worst)
	_t.check("(d) the collision shapes carry no stretch", plain)
	var step := 0.0
	if worst < 0.01:
		var chunk := got.size() / n
		for k in range(1, n):
			var z := -length * 0.5 + k * piece
			var before := _cut(got.slice((k - 1) * chunk, k * chunk), z - SLICE_IN_M * stretch)
			var after := _cut(got.slice(k * chunk, (k + 1) * chunk), z + SLICE_IN_M * stretch)
			if before.is_empty() or after.is_empty():
				step = INF
				continue
			step = maxf(step, maxf(absf(before[0] - after[0]), absf(before[1] - after[1])))
		print("park_tile_test: worst collider step at a joint %.3f m" % step)
		_t.check("(c) the colliders step at most %.2f m at every joint" % JOINT_M, step <= JOINT_M, "%.3f m" % step)
	var r := ParkRecipes.ranges("landform")
	var ranged := true
	var shells := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			var v := child as MeshInstance3D
			if String(v.name).contains("_tile") and v.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
				ranged = ranged and is_equal_approx(v.visibility_range_end, float(r.get("base_end", 0.0)))
			elif String(v.name).contains("_tile"):
				shells += 1
	var shell_files := 0
	for p: String in ParkRecipes.paths(RECIPE, "landform")["shells"]:
		if ResourceLoader.exists(p):
			shell_files += 1
	_t.check("(d) every copy's base views carry the base visibility range", ranged)
	_t.check("(d) every detail shell is drawn once per copy", shell_files == 0 or (shells > 0 and shells % n == 0), "%d shell views, %d shell files" % [shells, shell_files])


func _check_tileable(parent: Node3D, ground: Callable, scene: Node) -> void:
	var box := _raw_scene(Vector2(10, 2), Vector2(10, 2), 60.0)
	var taper := _raw_scene(Vector2(10, 2), Vector2(6, 4), 60.0)
	var box_tile = _call("tile_ends", [box, true])
	var taper_tile = _call("tile_ends", [taper, true])
	print("park_tile_test: box %s; taper %s" % [str(box_tile), str(taper_tile)])
	_t.check("(e) an in-memory box tiles", box_tile is Dictionary and bool(box_tile.get("tileable", false)))
	_t.check("(e) an in-memory taper does not, and says why", taper_tile is Dictionary and not bool(taper_tile.get("tileable", true))
		and String(taper_tile.get("reason", "")).contains("differ"))
	box.free()
	taper.free()
	var ends := _ends(scene)
	var refused = _call("tile_refusal", [_row("x", 100.0), ends, taper_tile if taper_tile is Dictionary else {}])
	_t.check("(e) a non-tileable recipe refuses the tile fit", refused is String and String(refused).begins_with("not tileable"), str(refused))
	var short := _row("short", float(ends["length"]) * 1.2)
	var node := ParkRecipes.place(short, parent, ground)
	var reason := String(node.get_meta("tile_refused", "")) if node != null else ""
	print("park_tile_test: a 1.2 x GLB tile row: %s" % reason)
	_t.check("(e) a tile row whose copies would stretch 0.60 stands in as greybox", node != null and node.get_node_or_null("Greybox") != null
		and _view_fit(node, scene, "_tile0") == null and _view_fit(node, scene, "") == null)
	_t.check("(e) it says why", reason.begins_with("2 copies stretch 0.60"), reason)
	_t.check("(e) stands_in agrees", ParkRecipes.stands_in(short))
	var plain := _row("plain", float(ends["length"]) * RATIO)
	plain.erase("fit")
	var unfit := ParkRecipes.place(plain, parent, ground)
	var fit = _view_fit(unfit, scene, "") if unfit != null else null
	var want := Transform3D(Basis.IDENTITY, ParkRecipes.ride_frame(plain)["origin"])
	_t.check("(e) without fit the row places its one GLB at the entry-lip offset, as before", fit is Transform3D and (fit as Transform3D).is_equal_approx(want)
		and _view_fit(unfit, scene, "_tile0") == null and not unfit.has_meta("tile_fit") and not ParkRecipes.stands_in(plain), str(fit))


func _check_schema() -> void:
	var row := _row("schema", 200.0)
	row.merge({"home": "", "routes": [], "society": "", "fragment": ""})
	var out := []
	ParkSchema._park_row(out, "schema", row, {}, {})
	_t.eq("(f) fit tile on a GLB row is clean", out, [])
	var grey := row.duplicate()
	grey["recipe"] = "greybox:flow_line"
	out = []
	ParkSchema._park_row(out, "grey", grey, {}, {})
	_t.check("(f) a tile fit on a greybox row is refused for its recipe", out.size() == 1 and str(out[0]).contains("needs a GLB recipe"), str(out))


# The GLB-to-node transform of the placed base view named <mesh><suffix>: its transform times its source's place in the
# scene, undone; null when no such view.
func _view_fit(node: Node3D, scene: Node, suffix: String) -> Variant:
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null or String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			continue
		var view := node.get_node_or_null(NodePath(String(source.name) + suffix)) as MeshInstance3D
		if view != null:
			return view.transform * _relative(source, scene).affine_inverse()
	return null


# A raw recipe scene: one "<name>-col" mesh, a frustum along +Z from a near cross-section (width, height) to a far one.
func _raw_scene(near: Vector2, far: Vector2, length: float) -> Node3D:
	var top := Node3D.new()
	var corners := func(c: Vector2, z: float) -> Array: return [Vector3(-c.x * 0.5, 0, z), Vector3(c.x * 0.5, 0, z), Vector3(c.x * 0.5, c.y, z), Vector3(-c.x * 0.5, c.y, z)]
	var a: Array = corners.call(near, 0.0)
	var b: Array = corners.call(far, length)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		for v: Vector3 in [a[k], a[(k + 1) % 4], b[(k + 1) % 4], a[k], b[(k + 1) % 4], b[k]]:
			st.add_vertex(v)
	for cap: Array in [a, b]:
		for v: Vector3 in [cap[0], cap[1], cap[2], cap[0], cap[2], cap[3]]:
			st.add_vertex(v)
	var mesh := MeshInstance3D.new()
	mesh.name = "raw-col"
	mesh.mesh = st.commit()
	top.add_child(mesh)
	return top


# The test's own -col faces and cross-section cut (park_recipes.gd col_faces and cross_section), kept here so the test
# runs, red, on a loader that has no tile fit. _cut returns [lowest y, highest y] on the plane z = z0, [] when none.
func _col_faces(scene: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh != null and String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			out.append_array(_relative(source, scene) * ParkRecipes._trimesh(source).get_faces())
	return out


func _cut(faces: PackedVector3Array, z0: float) -> Array:
	var lo := INF
	var hi := -INF
	for t in range(0, faces.size() - 2, 3):
		for k in 3:
			var a := faces[t + k]
			var b := faces[t + (k + 1) % 3]
			var da := a.z - z0
			var db := b.z - z0
			if da == 0.0:
				lo = minf(lo, a.y)
				hi = maxf(hi, a.y)
			elif da * db < 0.0:
				var y := lerpf(a.y, b.y, da / (da - db))
				lo = minf(lo, y)
				hi = maxf(hi, y)
	return [] if lo == INF else [lo, hi]


# The authored ride ends (park_recipes.gd authored_ends), kept here for the same reason.
func _ends(scene: Node) -> Dictionary:
	var entry := Vector3.ZERO
	var exit = null
	var far := -INF
	for n: Node3D in scene.find_children("*", "Node3D", true, false):
		if n.name == "socket_entry":
			entry = _relative(n, scene).origin
		elif n.name == "socket_exit":
			exit = _relative(n, scene).origin
		elif n is MeshInstance3D and String(n.name).ends_with(ParkRecipes.COL_SUFFIX):
			far = maxf(far, (_relative(n, scene) * (n as MeshInstance3D).mesh.get_aabb()).end.z)
	if exit == null:
		exit = Vector3(0, entry.y, far)
	return {"entry": entry, "exit": exit, "length": (exit as Vector3).z - entry.z}


# A park_recipes.gd static by name, null when the loader has none (the red run before PARK-TILE).
func _call(method: String, args: Array) -> Variant:
	var script: Script = ParkRecipes
	if not script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == method):
		return null
	return script.callv(method, args)


func _relative(n: Node, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = n
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
