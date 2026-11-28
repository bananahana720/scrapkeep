extends SceneTree
# 2026-10-17 (dam kit): the drape recipes of park_dam (tools/blender/park/dam_dressing.py; design-v3/park/stages/1-park_dam.md
# section 15 and its dam-kit follow-up). Every park row whose recipe is `dam_<row id>` (the 40 ride-lip rows and eye_mouth) and the
# two dome-summit survey gates `dam_survey_gate_red` and `dam_survey_gate_blue`.
# (a) Each recipe ships its base GLB and the two detail shells park_recipes.gd names; the base with any -col mesh stays inside its
# class (landform 8,000 triangles, park_large 16,000 for the rows whose registry class says so) and each shell inside the detail
# class's 1,500 (the builder holds 1,000, three unwelded vertices a triangle inside the class's 3,000 vertices). No GLB carries
# a -col mesh except the Eye's arch and the spillway portal, and no shell ever does.
# (b) Placed through park_recipes.gd place_row with the real baked ground (assets/park/park_dam/ground.bin read as terrain.gd
# _grid_height reads it), every drawn vertex, triangle centre and edge midpoint of a drape's base and both shells stands
# between 0 and FLUSH (0.12 m) over the ground under it. The arch meshes (`<id>_arch`) are the two exceptions.
# (c) The node of a dressed row stands at the height of the greybox stand-in it replaces (seat(): ground less the row's own
# stamp's raise, rounded to 0.01 m), and its ride sensor is the same box at the same place.
# (d) The Eye's arch clears the ramp floor by 18 m everywhere over the ramp's footprint and stands on the two fins outside the
# ramp's width; the spillway portal clears the wash floor by 10 m across the full cut and stands outside it.
# (e) The survey gates stand their cairn's foot at local y 15.85, GATE_SINK under a `dome_N` row's 16 m spire summit, which
#     rides the shelf's fall: within the gate's 2.2 m reach the summit stays between the foot and GATE_SINK x 2 over it,
#     so no stone floats and the uphill ones bed into the rock.
# (f) Overlapping drapes draw each piece of ground once (dam_dressing.py covered_by, outside_of; clip audit, 30-31 Oct:
#     spillway_tunnel and cliff_rooms_west drew the same 3,570 m2 twice and z-fought): no base-skin triangle of a row has
#     its centre inside the footprint of a smaller dressed row it overlaps, beyond FRINGE_M2 in all (rounding at the cut
#     edges), and the dam has such overlaps (the positive control).
# Planted: a row whose y moved 1 m and a row with every vertex lifted 0.5 m each turn the checks red.
# Evidence limit: geometry against the baked ground and a headless scene; no look, feel or ride claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Terrain := preload("res://src/world/terrain.gd")
const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_dam.json"
const BAKE_DIR := "res://assets/park/park_dam"
const DIR := "res://assets/models/park/"
const FLUSH := 0.12
const FLUSH_SLACK := 0.0005
const BASE_CAP := {"landform": 8000, "park_large": 16000}
const SHELL_CAP := 1000
const DETAIL_CAP := 1500
const COL_RECIPES := ["dam_the_eye", "dam_spillway_tunnel"]
const GATES := ["dam_survey_gate_red", "dam_survey_gate_blue", "dam_survey_benchmark"]
const GATE_ROWS := 8
const BENCHMARK := "dam_survey_benchmark"
const DRESSED_COUNT := 41
const EYE_CLEAR_M := 18.0
const PORTAL_CLEAR_M := 10.0
const SEAT_TOL := 0.0101
const DOME_TOP_Y := 16.0
const GATE_SINK := 0.15
const GATE_FOOT_Y := DOME_TOP_Y - GATE_SINK
const GATE_REACH := 2.2

var _t := T.new("park_recipes_dam_dressing_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var park = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	if not _t.check("the park file parses", park is Dictionary):
		quit(_t.verdict())
		return
	var heights := ParkTerrain._read_zstd(BAKE_DIR + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var ground := func(x: float, z: float) -> float: return Terrain.grid_height(heights, x, z)
	var rows := {}
	var dressed: Array = []
	var gated: Array = []
	for row: Dictionary in park["park_rows"]:
		rows[String(row["id"])] = row
		if GATES.has(String(row["recipe"])):
			gated.append(row)
		elif String(row["recipe"]).begins_with("dam_"):
			dressed.append(row)
	_t.eq("%d park rows name a dam_ drape recipe" % DRESSED_COUNT, dressed.size(), DRESSED_COUNT)
	for row: Dictionary in dressed:
		var id := String(row["recipe"])
		_t.eq("%s names dam_<its own id>" % row["id"], id, "dam_" + String(row["id"]))
		_t.check("%s fits drape, takes no y" % row["id"], ParkRecipes.fits_drape(row) and row["y"] == null)
		_t.check("%s does not stand in as greybox" % id, not ParkRecipes.stands_in(row))
		_check_files(id, String(row["budget"]), true)
		_t.check("%s budget %s is landform or park_large" % [row["id"], row["budget"]], BASE_CAP.has(String(row["budget"])))
	for id in GATES:
		_check_files(id, "landform", false)
		_check_gate(id)
	# The slalom gates (stage page section 16): each flag stands on a 16 m spire dome, seated on the dome's base so the
	# cairn foot authored at 16 m lands on the summit.
	_t.eq("%d dome rows carry a survey gate or the benchmark" % GATE_ROWS, gated.size(), GATE_ROWS)
	for row: Dictionary in gated:
		_t.check("%s: gate on a drape-fit 16 m spire dome with no y" % row["id"], ParkRecipes.fits_drape(row) and row["y"] == null
			and String(row["stamp"]) == "spire" and is_equal_approx(float(row["size"][1]), DOME_TOP_Y), str(row))
		var stats := row_misses(row, ground, 0.0)
		var seat: Array = (stats["misses"] as Array).filter(func(m): return not String(m).begins_with("flush"))
		_t.check("%s: gate seated and sensed like its stand-in dome" % row["id"], seat.is_empty(), "; ".join(seat))
		var summit := _summit_misses(row, ground)
		_t.check("%s: the summit within %.1f m of the pole lies 0 to %.2f m over the cairn's foot" % [row["id"], GATE_REACH, 2.0 * GATE_SINK], summit.is_empty(), "; ".join(summit))
	for row: Dictionary in dressed:
		var stats := row_misses(row, ground, 0.0)
		_t.check("%s: every drawn vertex between 0 and %.2f m over the ground, seated like its stand-in (%d samples, %.3f to %.3f m)" % [
			row["id"], FLUSH, stats["samples"], stats["lo"], stats["hi"]], stats["misses"].is_empty(), "; ".join(stats["misses"]))
	_check_eye(rows, ground)
	_check_portal(rows, ground)
	_check_overlaps(dressed, ground)
	# Planted stale cases.
	var plant: Dictionary = (rows["the_eye"] as Dictionary).duplicate(true)
	plant.erase("fit")
	var moved := row_misses(plant, ground, 0.0)
	_t.check("a row that drops its drape fit turns the seat check red", (moved["misses"] as Array).any(func(m): return String(m).begins_with("seat")), str(moved["misses"]))
	var lifted := row_misses(rows["shelf_lip"], ground, 0.5)
	_t.check("a row with every vertex lifted 0.5 m turns the flush check red", (lifted["misses"] as Array).any(func(m): return String(m).begins_with("flush")), str(lifted["misses"]))
	quit(_t.verdict())


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _tris(scene: Node, only_col: bool, any: bool) -> int:
	var n := 0
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or (not any and String(m.name).ends_with(ParkRecipes.COL_SUFFIX) != only_col):
			continue
		for s in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			n += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
	return n


func _col_nodes(scene: Node) -> int:
	var n := 0
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).ends_with(ParkRecipes.COL_SUFFIX):
			n += 1
	return n


func _check_files(id: String, budget: String, row_recipe: bool) -> void:
	var base := _scene(DIR + id + ".glb")
	if not _t.check("(a) %s.glb exists and loads" % id, base != null):
		return
	var cap: int = BASE_CAP[budget]
	var all := _tris(base, false, true)
	_t.check("(a) %s base with its -col mesh is inside the %s budget" % [id, budget], all > 0 and all <= cap, "%d of %d" % [all, cap])
	var cols := _col_nodes(base)
	var want_col := COL_RECIPES.has(id)
	_t.check("(a) %s %s a -col mesh" % [id, "carries" if want_col else "has no"], (cols > 0) == want_col, "%d -col nodes" % cols)
	if want_col:
		_t.check("(a) %s's -col mesh is named %s-col" % [id, id], base.find_child(id + "-col", true, false) != null)
		_t.check("(a) %s's arch is its own drawn node" % id, base.find_child(id + "_arch", true, false) != null)
	var shells: Array = ParkRecipes.paths(id, budget)["shells"]
	for k in shells.size():
		var shell := _scene(shells[k])
		var tris := _tris(shell, false, true) if shell != null else -1
		_t.check("(a) %s detail shell %d is inside the detail budget" % [id, k + 1], shell != null and tris > 0 and tris <= SHELL_CAP and tris <= DETAIL_CAP, "tris %d" % tris)
		if shell != null:
			_t.eq("(a) %s detail shell %d has no -col mesh" % [id, k + 1], _col_nodes(shell), 0)
			shell.free()
	base.free()


# A placed row's misses: node height against the greybox stand-in's seat, the ride sensor, and every sample of every drawn
# view against the ground. lift raises every sample (a planted stale vertex).
# The baked ground round the gate at its reach, against the cairn's foot: never under it, at most 2 x GATE_SINK over.
func _summit_misses(row: Dictionary, ground: Callable) -> Array:
	var misses: Array = []
	var holder := Node3D.new()
	root.add_child(holder)
	var node := ParkRecipes.place_row(row, holder, ground, func(_kind: String, _at: Vector3) -> void: pass)
	if node == null:
		misses.append("place: %s placed no node" % row["id"])
	else:
		for k in 16:
			var d := Vector2.from_angle(TAU * k / 16.0) * GATE_REACH
			var over: float = ground.call(node.position.x + d.x, node.position.z + d.y) - node.position.y - GATE_FOOT_Y
			if over < 0.0 or over > 2.0 * GATE_SINK:
				misses.append("summit %s: ground %.3f over the foot" % [d, over])
	holder.free()
	return misses


func row_misses(row: Dictionary, ground: Callable, lift: float) -> Dictionary:
	var misses: Array = []
	var holder := Node3D.new()
	root.add_child(holder)
	var publish := func(_kind: String, _at: Vector3) -> void: pass
	var node := ParkRecipes.place_row(row, holder, ground, publish)
	var stand_row: Dictionary = row.duplicate(true)
	stand_row["recipe"] = ParkRecipes.GREYBOX + String(row["element"])
	stand_row["y"] = null
	var stand := ParkRecipes.place_row(stand_row, holder, ground, publish)
	var lo := INF
	var hi := -INF
	var samples := 0
	if node == null or stand == null:
		misses.append("place: %s placed no node" % row["id"])
	else:
		if absf(node.position.y - stand.position.y) > SEAT_TOL:
			misses.append("seat: node y %.3f, the greybox stand-in's %.3f" % [node.position.y, stand.position.y])
		var ride := node.get_node_or_null("Ride") as Area3D
		var ride_stand := stand.get_node_or_null("Ride") as Area3D
		if (ride == null) != (ride_stand == null):
			misses.append("seat: ride sensor present %s, the stand-in's %s" % [ride != null, ride_stand != null])
		elif ride != null:
			var a := ride.get_child(0) as CollisionShape3D
			var b := ride_stand.get_child(0) as CollisionShape3D
			if (a.shape as BoxShape3D).size != (b.shape as BoxShape3D).size or absf(node.position.y + a.position.y - stand.position.y - b.position.y) > SEAT_TOL \
					or not node.position.is_equal_approx(Vector3(stand.position.x, node.position.y, stand.position.z)):
				misses.append("seat: ride sensor box or place differs from the stand-in's")
		if node.get_node_or_null("Greybox") != null:
			misses.append("place: a dressed row keeps its greybox")
		for view: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			var vname := String(view.name)
			if view.mesh == null or vname.ends_with(ParkRecipes.COL_SUFFIX) or vname.ends_with("_arch"):
				continue
			for s in view.mesh.get_surface_count():
				var arrays := view.mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var pts: Array[Vector3] = []
				for k in range(0, index.size() - 2, 3):
					var a := verts[index[k]]
					var b := verts[index[k + 1]]
					var c := verts[index[k + 2]]
					pts.append_array([a, b, c, (a + b + c) / 3.0, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5])
				for p in pts:
					var w: Vector3 = node.transform * (view.transform * p)
					var off := w.y + lift - float(ground.call(w.x, w.z))
					lo = minf(lo, off)
					hi = maxf(hi, off)
					samples += 1
		if samples == 0:
			misses.append("flush: no drawn vertex was sampled")
		elif lo <= 0.0 or hi > FLUSH + FLUSH_SLACK:
			misses.append("flush: drawn samples %.4f to %.4f m over the ground, want over 0 and at most %.2f" % [lo, hi, FLUSH])
	holder.free()
	return {"misses": misses, "lo": lo, "hi": hi, "samples": samples}


# Whether world (x, z) lies in a row's footprint, as dam_dressing.py footprint_of draws it (a 40-gon for a round stamp).
func _in_footprint(row: Dictionary, x: float, z: float) -> bool:
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var d := Vector2(x, z) - Vector2(float(row["at"][0]), float(row["at"][1]))
	var lx := d.x * cos(yaw) - d.y * sin(yaw)
	var lz := d.x * sin(yaw) + d.y * cos(yaw)
	var hl := float(row["size"][0]) * 0.5
	var hw := float(row["size"][2]) * 0.5
	if ["butte", "spire", "bowl", "crater", "sinkhole"].has(String(row["stamp"])):
		var ring := PackedVector2Array()
		for k in 40:
			ring.append(Vector2(hw * cos(TAU * k / 40), hl * sin(TAU * k / 40)))
		return Geometry2D.is_point_in_polygon(Vector2(lx, lz), ring)
	return absf(lx) <= hw and absf(lz) <= hl


func _area(row: Dictionary) -> float:
	var a := float(row["size"][0]) * float(row["size"][2])
	return a * PI / 4.0 if ["butte", "spire", "bowl", "crater", "sinkhole"].has(String(row["stamp"])) else a


const FRINGE_M2 := 0.1


func _check_overlaps(dressed: Array, ground: Callable) -> void:
	var pairs := 0
	var doubled := 0
	var area := 0.0
	var named := []
	for big: Dictionary in dressed:
		var smaller: Array = []
		for small: Dictionary in dressed:
			if small == big or _area(small) > _area(big) or (_area(small) == _area(big) and dressed.find(small) > dressed.find(big)):
				continue
			if ParkRecipes._rects_meet(ParkRecipes._footprint(big, 0.0), ParkRecipes._footprint(small, 0.0)):
				smaller.append(small)
		if smaller.is_empty():
			continue
		var placed := _place(big, ground)
		var node: Node3D = placed[1]
		var view := node.get_node_or_null(String(big["recipe"])) as MeshInstance3D
		if view != null:
			var faces := view.mesh.get_faces()
			for k in range(0, faces.size(), 3):
				var c: Vector3 = node.transform * view.transform * ((faces[k] + faces[k + 1] + faces[k + 2]) / 3.0)
				for small: Dictionary in smaller:
					if _in_footprint(small, c.x, c.z):
						doubled += 1
						area += 0.5 * (faces[k + 1] - faces[k]).cross(faces[k + 2] - faces[k]).length()
						if not named.has(big["id"]):
							named.append(big["id"])
						break
		pairs += smaller.size()
		(placed[0] as Node).free()
	_t.check("(f) the dam's dressed rows overlap (%d pairs)" % pairs, pairs > 0)
	_t.check("(f) base skins leave a smaller overlapping row's footprint (fringe at most %.1f m2)" % FRINGE_M2, area <= FRINGE_M2, "%d (%.1f m2) in %s" % [doubled, area, str(named)])


# The collider faces of a placed row's node, in the holder's space.
func _faces(node: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for cs: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		var shape := cs.shape as ConcavePolygonShape3D
		if shape != null:
			out.append_array(node.transform * (cs.transform * shape.get_faces()))
	return out


# The smallest height over the ground of the faces straight above (x, z), INF when none is.
func _under(faces: PackedVector3Array, g: float, x: float, z: float) -> float:
	var best := INF
	for k in range(0, faces.size() - 2, 3):
		var hit = Geometry3D.ray_intersects_triangle(Vector3(x, g + 0.02, z), Vector3.UP, faces[k], faces[k + 1], faces[k + 2])
		if hit is Vector3:
			best = minf(best, (hit as Vector3).y - g)
	return best


func _place(row: Dictionary, ground: Callable) -> Array:
	var holder := Node3D.new()
	root.add_child(holder)
	return [holder, ParkRecipes.place_row(row, holder, ground)]


func _check_eye(rows: Dictionary, ground: Callable) -> void:
	var eye: Dictionary = rows["the_eye"]
	var placed := _place(eye, ground)
	var faces := _faces(placed[1])
	_t.check("(d) the Eye arch has a collider", faces.size() > 0)
	var frame: Transform3D = ParkRecipes.row_transform(eye, ground)
	var worst := INF
	var covered := 0
	for lz in range(-24, 25, 2):
		for lx in range(-14, 15, 2):
			var w: Vector3 = frame * Vector3(lx, 0.0, lz)
			var g := float(ground.call(w.x, w.z))
			var up := _under(faces, g, w.x, w.z)
			if up < INF:
				covered += 1
				worst = minf(worst, up)
	_t.check("(d) the Eye arch spans the ramp (%d sample points under it)" % covered, covered >= 30)
	_t.check("(d) the Eye arch underside is at least %.0f m over the ramp floor everywhere (worst %.2f m)" % [EYE_CLEAR_M, worst], worst >= EYE_CLEAR_M)
	var ramp_half := float(eye["size"][2]) * 0.5
	var low_ok := true
	var feet_ok := true
	var fins := [rows["eye_fin_west"], rows["eye_fin_east"]]
	for p in faces:
		var g := float(ground.call(p.x, p.z))
		if absf(p.x) <= ramp_half and p.y - g < EYE_CLEAR_M:
			low_ok = false
		if p.y - g < 6.0:
			var on_fin := false
			for fin: Dictionary in fins:
				on_fin = on_fin or ParkMap.footprint_contains(fin, Vector2(p.x, p.z), 2.0)
			feet_ok = feet_ok and on_fin
	_t.check("(d) nothing of the Eye arch lies within %.0f m of the floor inside the ramp's width" % EYE_CLEAR_M, low_ok)
	_t.check("(d) the Eye arch's legs stand on the two fins", feet_ok)
	(placed[0] as Node3D).free()


func _check_portal(rows: Dictionary, ground: Callable) -> void:
	var tunnel: Dictionary = rows["spillway_tunnel"]
	var placed := _place(tunnel, ground)
	var faces := _faces(placed[1])
	_t.check("(d) the spillway portal has a collider", faces.size() > 0)
	var z0 := INF
	var z1 := -INF
	for p in faces:
		z0 = minf(z0, p.z)
		z1 = maxf(z1, p.z)
	var half := float(tunnel["size"][2]) * 0.5
	var cx := float(tunnel["at"][0])
	var worst := INF
	for k in range(0, 31):
		var x := cx - half + float(k) * 2.0 * half / 30.0
		for z in [z0 + 0.5, (z0 + z1) * 0.5, z1 - 0.5]:
			worst = minf(worst, _under(faces, float(ground.call(x, z)), x, z))
	_t.check("(d) the spillway portal underside is at least %.0f m over the wash floor across the full cut (worst %.2f m)" % [PORTAL_CLEAR_M, worst], worst >= PORTAL_CLEAR_M)
	var outside := true
	for p in faces:
		if absf(p.x - cx) < half and p.y - float(ground.call(p.x, p.z)) < PORTAL_CLEAR_M:
			outside = false
	_t.check("(d) the spillway portal's legs stand outside the cut", outside)
	(placed[0] as Node3D).free()


func _check_gate(id: String) -> void:
	var scene := _scene(DIR + id + ".glb")
	if scene == null:
		return
	var lo := INF
	var hi := -INF
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			for p: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = minf(lo, p.y)
				hi = maxf(hi, p.y)
	_t.check("(e) %s stands its cairn's foot at local y %.2f (lowest %.3f)" % [id, GATE_FOOT_Y, lo], absf(lo - GATE_FOOT_Y) < 0.02)
	if id == BENCHMARK:
		_t.check("(e) %s rises a 1.4 m stake over a 1.2 m cairn (top %.2f m over the foot)" % [id, hi - GATE_FOOT_Y], hi - GATE_FOOT_Y > 2.6 and hi - GATE_FOOT_Y < 3.0)
	else:
		_t.check("(e) %s rises a 6 m pole over a 1.2 m cairn (top %.2f m over the foot)" % [id, hi - GATE_FOOT_Y], hi - GATE_FOOT_Y > 7.0 and hi - GATE_FOOT_Y < 7.6)
	scene.free()
