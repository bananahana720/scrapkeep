extends SceneTree

# 2026-10-16 (PARK-SEAT, coordinator ruling SE1): a park row that says "fit": "seat" seats its GLB on the ground at
# both ride ends (park_recipes.gd seat_fit). On a sloped ground and a yawed, stretched canal_lip row:
# (a) the GLB's authored entry and exit, read back from the placed base view (not the node's meta), sit within EPS_M of
#     the ground at ride_frame's entry and exit, in plan at those two points;
# (b) the stretch is along the GLB's length only: width and height axes stay unit, the length axis scales by the row's
#     length over the GLB's authored length;
# (c) the collider is the -col trimesh moved by the same transform, vertex for vertex, on an unstretched shape;
# (d) a fit row whose stretch is outside 0.75 to 1.5 stands in as its element's greybox and says why, and stands_in()
#     agrees; the same row without fit still places its GLB at the entry-lip offset, byte for byte as before;
# (e) the schema takes "fit": "seat" on a GLB row and refuses another value or a fit on a greybox row.
# Red before PARK-SEAT: no row field, so the GLB stays level at the centre and (a) misses by metres.
# Evidence limit: transforms and collider faces only; no ball rolls the seated piece and no feel claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")

const RECIPE := "canal_lip"
const EPS_M := 0.05
const SLOPE_Z := -0.3
const SLOPE_X := 0.05

var _t := T.new("park_seat_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var ground := func(x: float, z: float) -> float: return 40.0 + SLOPE_Z * z + SLOPE_X * x
	var scene: Node = (load(ParkRecipes.GLB_DIR + RECIPE + ".glb") as PackedScene).instantiate()
	_check_seat(parent, ground, scene)
	_check_refusal(parent, ground, scene)
	_check_schema()
	scene.free()
	parent.free()
	quit(_t.verdict())


func _row(id: String, length: float) -> Dictionary:
	return {"id": id, "element": "grind_line", "at": [30.0, 20.0], "y": null, "size": [length, 3.0, 8.0], "yaw_deg": 30.0,
		"ride_fact": "", "recipe": RECIPE, "budget": "landform", "stamp": "", "fit": "seat"}


# The GLB-to-node transform the placed base view carries: its transform times its source's place in the scene, undone.
func _view_fit(node: Node3D, scene: Node) -> Variant:
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh == null or String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			continue
		var view := node.get_node_or_null(NodePath(String(source.name))) as MeshInstance3D
		if view != null:
			return view.transform * _relative(source, scene).affine_inverse()
	return null


func _check_seat(parent: Node3D, ground: Callable, scene: Node) -> void:
	var ends := _ends(scene)
	_t.check("the %s GLB has authored ends" % RECIPE, float(ends.get("length", 0.0)) > 100.0, str(ends))
	var length := float(ends["length"]) * 1.25
	var row := _row("seated", length)
	var node := ParkRecipes.place(row, parent, ground)
	if not _t.check("the seat row places a node", node != null and not node.has_meta("seat_refused")):
		return
	var fit = _view_fit(node, scene)
	if not _t.check("the seat row draws its GLB", fit is Transform3D):
		return
	var world: Transform3D = node.transform * (fit as Transform3D)
	var frame := ParkRecipes.ride_frame(row)
	var ride_entry: Vector3 = node.transform * (frame["entry"] as Vector3)
	var ride_exit: Vector3 = node.transform * (frame["exit"] as Vector3)
	var entry := world * (ends["entry"] as Vector3)
	var exit := world * (ends["exit"] as Vector3)
	var g_entry := float(ground.call(entry.x, entry.z))
	var g_exit := float(ground.call(exit.x, exit.z))
	print("park_seat_test: row %.1f m on a %.0f%% slope at yaw 30; GLB entry y %.2f over ground %.2f, exit y %.2f over ground %.2f (fall %.1f m)"
		% [length, absf(SLOPE_Z) * 100.0, entry.y, g_entry, exit.y, g_exit, g_entry - g_exit])
	_t.near("(a) the GLB's entry sits on the ground", entry.y, g_entry, EPS_M)
	_t.near("(a) the GLB's exit sits on the ground", exit.y, g_exit, EPS_M)
	_t.check("(a) the entry is at ride_frame's entry in plan", Vector2(entry.x, entry.z).distance_to(Vector2(ride_entry.x, ride_entry.z)) < EPS_M,
		"%s vs %s" % [entry, ride_entry])
	_t.check("(a) the exit is at ride_frame's exit in plan", Vector2(exit.x, exit.z).distance_to(Vector2(ride_exit.x, ride_exit.z)) < EPS_M,
		"%s vs %s" % [exit, ride_exit])
	_t.check("(a) the row falls more than 20 m end to end", g_entry - g_exit > 20.0, "%.1f m" % (g_entry - g_exit))
	var b: Basis = (fit as Transform3D).basis
	_t.check("(b) the width axis is unstretched", b.x.is_equal_approx(Vector3.RIGHT), str(b.x))
	_t.check("(b) the height axis is unstretched", b.y.is_equal_approx(Vector3.UP), str(b.y))
	_t.near("(b) the length axis stretches by row over GLB length", b.z.z, 1.25, 0.001)
	# (c) The collider: every -col face moved by the view's transform, on a shape with no transform of its own.
	var want := PackedVector3Array()
	for source: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if source.mesh != null and String(source.name).ends_with(ParkRecipes.COL_SUFFIX):
			want.append_array(((fit as Transform3D) * _relative(source, scene)) * ParkRecipes._trimesh(source).get_faces())
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
	print("park_seat_test: collider %d vertices, mesh %d, worst %.4f m" % [got.size(), want.size(), worst])
	_t.check("(c) the collider is the -col mesh on the fit, vertex for vertex", worst < 0.01, "worst %.4f m" % worst)
	_t.check("(c) the collision shapes carry no stretch", plain)


func _check_refusal(parent: Node3D, ground: Callable, scene: Node) -> void:
	var ends := _ends(scene)
	var row := _row("short", float(ends["length"]) * 0.5)
	var node := ParkRecipes.place(row, parent, ground)
	var reason := String(node.get_meta("seat_refused", "")) if node != null else ""
	print("park_seat_test: a half-length fit row: %s" % reason)
	_t.check("(d) a half-length fit row stands in as greybox", node != null and node.get_node_or_null("Greybox") != null and _view_fit(node, scene) == null)
	_t.check("(d) it says why", reason.begins_with("length ratio 0.50"), reason)
	_t.check("(d) stands_in agrees", ParkRecipes.stands_in(row))
	var long := _row("long", float(ends["length"]) * 1.6)
	_t.check("(d) a stretch over 1.5 is refused too", _refusal(long, ends).begins_with("length ratio 1.60"), _refusal(long, ends))
	var plain := row.duplicate()
	plain.erase("fit")
	var unfit := ParkRecipes.place(plain, parent, ground)
	var fit = _view_fit(unfit, scene) if unfit != null else null
	var want := Transform3D(Basis.IDENTITY, ParkRecipes.ride_frame(plain)["origin"])
	_t.check("(d) without fit the row places its GLB at the entry-lip offset, as before", fit is Transform3D and (fit as Transform3D).is_equal_approx(want)
		and not unfit.has_meta("seat_fit") and not ParkRecipes.stands_in(plain), str(fit))


func _check_schema() -> void:
	var row := _row("schema", 120.0)
	row.merge({"home": "", "routes": [], "society": "", "fragment": ""})
	var out := []
	ParkSchema._park_row(out, "schema", row, {}, {})
	_t.eq("(e) fit seat on a GLB row is clean", out, [])
	var odd := row.duplicate()
	odd["fit"] = "stretch"
	out = []
	ParkSchema._park_row(out, "odd", odd, {}, {})
	_t.check("(e) another fit value is an enum error", out.size() == 1 and str(out[0]).contains("enum"), str(out))
	var grey := row.duplicate()
	grey["recipe"] = "greybox:grind_line"
	out = []
	ParkSchema._park_row(out, "grey", grey, {}, {})
	_t.check("(e) a fit on a greybox row is refused", out.size() == 1 and str(out[0]).contains("fit"), str(out))


# The test's own reading of the GLB's authored ride ends (park_recipes.gd header): its socket_entry, else its origin;
# its socket_exit, else the far end of its -col box on the centre line. Kept here so the test runs, red, on a loader
# that has no seat fit.
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


func _refusal(row: Dictionary, ends: Dictionary) -> String:
	var script: Script = ParkRecipes
	var named := script.get_script_method_list().any(func(m: Dictionary) -> bool: return m["name"] == "seat_refusal")
	return String(script.call("seat_refusal", row, ends)) if named else "no seat_refusal"


func _relative(n: Node, top: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = n
	while walk != null and walk != top:
		if walk is Node3D:
			xf = (walk as Node3D).transform * xf
		walk = walk.get_parent()
	return xf
