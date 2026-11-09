extends SceneTree
# Surface layers (park_recipes.gd surface_lifts; clip audit, 30 Oct): a wash liner and a grind line's pieces draw
# conformed to the ground or end to end, so two that overlap drew the same faces twice and z-fought (three flume canal
# liners at (-287, -250), flume siphon_span into flume_hollow_reach). surface_lifts gives each overlapping surface row
# the lowest layer no earlier overlapping one holds. Drape-fit rows are no surface rows: dam_dressing.py settles theirs.
# (a) per park, no two overlapping surface rows share a layer, every lift is a whole number of SURFACE_LAYER_M, and no
#     row stands more than MAX_LAYERS layers up (a drawn rail that far over the rail the ball rides would show);
# (b) the named overlap: the flume's three canal liners stand on three layers (the positive control), and no drape-fit
#     row lifts;
# (c) a lone surface row and a row that is no surface take no lift;
# (d) a lifted row's drawn views stand the lift up and its collider faces stay where they were.
# (e) the three canal liners of the flume junction draw each piece of ground once (flume_works.py flush_cut; clip audit,
#     9 Nov: their steep bank faces shared planes over 22 m2 whatever the layer, because each sheet drew the whole of a
#     cell that straddled the other's edge). Their near views are placed and sampled on a 0.25 m plan grid.
# Evidence limit: placement data and placed rows; the look is the clip audit's stills.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const PARKS := ["dam", "flume", "pit", "sinkhole", "islands", "crown"]
const MAX_LAYERS := 3

var _t := T.new("park_surface_layers_test")


func _initialize() -> void:
	call_deferred("_run")


func _park(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_%s.json" % name))


func _index(rows: Array, id: String) -> int:
	for i in rows.size():
		if String(rows[i].get("id", "")) == id:
			return i
	return -1


func _run() -> void:
	var step := ParkRecipes.SURFACE_LAYER_M
	for name: String in PARKS:
		var rows := ParkRecipes.placed_rows(_park(name))
		var lifts := ParkRecipes.surface_lifts(rows)
		var surfaces: Array[int] = []
		for i in rows.size():
			if ParkRecipes.is_surface(rows[i]) and rows[i].has("size"):
				surfaces.append(i)
		var shared := 0
		var odd := 0
		for a in surfaces.size():
			var la := float(lifts.get(surfaces[a], 0.0))
			odd += 0 if absf(la / step - roundf(la / step)) < 0.001 else 1
			for b in range(a + 1, surfaces.size()):
				var meet := ParkRecipes._rects_meet(ParkRecipes._footprint(rows[surfaces[a]], ParkRecipes.SURFACE_MARGIN_M),
					ParkRecipes._footprint(rows[surfaces[b]], ParkRecipes.SURFACE_MARGIN_M))
				if meet and absf(la - float(lifts.get(surfaces[b], 0.0))) < 0.001:
					shared += 1
		print("park_surface_layers_test: %s %d surface rows, %d lifted" % [name, surfaces.size(), lifts.size()])
		_t.check("(a) %s: no two overlapping surface rows share a layer" % name, shared == 0, "%d pairs" % shared)
		_t.check("(a) %s: every lift is whole layers" % name, odd == 0, "%d off" % odd)
		var top := 0.0
		var draped := 0
		for i: int in lifts:
			top = maxf(top, float(lifts[i]))
			draped += 1 if ParkRecipes.fits_drape(rows[i]) else 0
		_t.check("(a) %s: the top layer is at most %d (%.3f m)" % [name, MAX_LAYERS, top], top <= MAX_LAYERS * step + 0.0001)
		_t.check("(b) %s: no drape-fit row lifts" % name, draped == 0, "%d lift" % draped)
		var plain := rows.filter(func(r: Dictionary) -> bool: return not ParkRecipes.is_surface(r))
		var stray := 0
		for i: int in lifts:
			stray += 0 if ParkRecipes.is_surface(rows[i]) else 1
		_t.check("(c) %s: only surface rows lift (%d other rows)" % [name, plain.size()], stray == 0)
		if name == "flume":
			var liners := ["main_canal", "butte_gap", "gap_wash"].map(func(id: String) -> float: return float(lifts.get(_index(rows, id), 0.0)))
			_t.check("(b) the flume's three canal liners stand on three layers %s" % str(liners),
				liners[0] != liners[1] and liners[1] != liners[2] and liners[0] != liners[2])
	var lone := [{"id": "lone", "element": "flow_line", "recipe": "liner_lone", "at": [0, 0], "size": [40, 3, 10], "yaw_deg": 0}]
	_t.eq("(c) a lone surface row takes no lift", ParkRecipes.surface_lifts(lone), {})
	# (d) One real grind line (it carries its own collider) placed with and without a lift.
	var rows := ParkRecipes.placed_rows(_park("flume"))
	var row: Dictionary = rows[_index(rows, "hollow_intake")]
	var flat := func(_x: float, _z: float) -> float: return 0.0
	var base := Node3D.new()
	var lifted := Node3D.new()
	root.add_child(base)
	root.add_child(lifted)
	var a := ParkRecipes.place_row(row, base, flat)
	var b := ParkRecipes.place_row(row, lifted, flat, Callable(), [], null, step)
	var views := 0
	var off := 0
	for view: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		var twin := b.get_node_or_null(a.get_path_to(view)) as MeshInstance3D
		views += 1
		off += 0 if twin != null and absf(twin.global_position.y - view.global_position.y - step) < 0.0001 else 1
	_t.check("(d) every drawn view stands the lift up (%d views)" % views, views > 0 and off == 0, "%d off" % off)
	var moved := 0
	var mine := a.find_children("*", "CollisionShape3D", true, false)
	var theirs := b.find_children("*", "CollisionShape3D", true, false)
	var shapes := mine.size()
	moved += absi(theirs.size() - shapes)
	for k in mini(shapes, theirs.size()):
		moved += 0 if (theirs[k] as Node3D).global_transform.is_equal_approx((mine[k] as Node3D).global_transform) else 1
	_t.check("(d) the collider stays (%d shapes)" % shapes, shapes > 0 and moved == 0, "%d moved" % moved)
	base.free()
	lifted.free()
	_check_junction(rows, flat)
	quit(_t.verdict())


# (e) Plan grid points under the drawn near view of more than one of the junction's liners.
func _check_junction(rows: Array, ground: Callable) -> void:
	const GRID := 0.25
	const DOUBLED_MAX_M2 := 0.5
	var holder := Node3D.new()
	root.add_child(holder)
	var seen := {}
	var ids := ["main_canal", "butte_gap", "gap_wash"]
	for k in ids.size():
		var placed := ParkRecipes.place_row(rows[_index(rows, ids[k])], holder, ground)
		for view: MeshInstance3D in placed.find_children("*", "MeshInstance3D", true, false):
			if view.visibility_range_begin > 0.0 or view.mesh == null:
				continue
			for surface in view.mesh.get_surface_count():
				var arrays := view.mesh.surface_get_arrays(surface)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var index = arrays[Mesh.ARRAY_INDEX]
				var count: int = index.size() if index != null and index.size() > 0 else verts.size()
				for t in range(0, count, 3):
					var p: Array[Vector2] = []
					for c in 3:
						var w := view.global_transform * verts[index[t + c] if index != null and index.size() > 0 else t + c]
						p.append(Vector2(w.x, w.z))
					var d := (p[1].y - p[2].y) * (p[0].x - p[2].x) + (p[2].x - p[1].x) * (p[0].y - p[2].y)
					if absf(d) < 1.0e-9:
						continue
					for gx in range(ceili(minf(p[0].x, minf(p[1].x, p[2].x)) / GRID), floori(maxf(p[0].x, maxf(p[1].x, p[2].x)) / GRID) + 1):
						for gz in range(ceili(minf(p[0].y, minf(p[1].y, p[2].y)) / GRID), floori(maxf(p[0].y, maxf(p[1].y, p[2].y)) / GRID) + 1):
							var q := Vector2(gx * GRID, gz * GRID)
							var u := ((p[1].y - p[2].y) * (q.x - p[2].x) + (p[2].x - p[1].x) * (q.y - p[2].y)) / d
							var v := ((p[2].y - p[0].y) * (q.x - p[2].x) + (p[0].x - p[2].x) * (q.y - p[2].y)) / d
							if minf(u, minf(v, 1.0 - u - v)) > 1.0e-4:
								var key := Vector2i(gx, gz)
								seen[key] = int(seen.get(key, 0)) | (1 << k)
	var drawn := [0, 0, 0]
	var doubled := 0
	for key: Vector2i in seen:
		var mask: int = seen[key]
		for k in 3:
			drawn[k] += 1 if mask & (1 << k) else 0
		doubled += 1 if mask & (mask - 1) else 0
	var area := doubled * GRID * GRID
	print("park_surface_layers_test: junction liners drawn %s grid points, %d under two (%.2f m2)" % [str(drawn), doubled, area])
	_t.check("(e) each junction liner draws a near view", drawn.min() > 1000, str(drawn))
	_t.check("(e) the junction's liners draw each piece of ground once (at most %.1f m2 doubled)" % DOUBLED_MAX_M2, area <= DOUBLED_MAX_M2, "%.2f m2" % area)
	holder.free()
