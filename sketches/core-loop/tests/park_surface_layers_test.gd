extends SceneTree
# Surface layers (park_recipes.gd surface_lifts; clip audit, 30 Oct): a drape-fit row, a wash liner and a grind line's
# pieces draw conformed to the ground or end to end, so two that overlap drew the same faces twice and z-fought (dam
# spillway_tunnel under cliff_rooms_west, three flume canal liners at (-287, -250), flume siphon_span into
# flume_hollow_reach). surface_lifts gives each overlapping surface row the lowest layer no earlier overlapping one holds.
# (a) per park, no two overlapping surface rows share a layer, and every lift is a whole number of SURFACE_LAYER_M;
# (b) the named overlaps: the flume's three canal liners stand on three layers, and the dam's cliff_rooms_west stands
#     over spillway_tunnel (the positive controls);
# (c) a lone surface row and a row that is no surface take no lift;
# (d) a lifted row's drawn views stand the lift up and its collider faces stay where they were.
# Evidence limit: placement data and one placed row; the look is the clip audit's stills.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const PARKS := ["dam", "flume", "pit", "sinkhole", "islands", "crown"]

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
		var plain := rows.filter(func(r: Dictionary) -> bool: return not ParkRecipes.is_surface(r))
		var stray := 0
		for i: int in lifts:
			stray += 0 if ParkRecipes.is_surface(rows[i]) else 1
		_t.check("(c) %s: only surface rows lift (%d other rows)" % [name, plain.size()], stray == 0)
		if name == "flume":
			var liners := ["main_canal", "butte_gap", "gap_wash"].map(func(id: String) -> float: return float(lifts.get(_index(rows, id), 0.0)))
			_t.check("(b) the flume's three canal liners stand on three layers %s" % str(liners),
				liners[0] != liners[1] and liners[1] != liners[2] and liners[0] != liners[2])
		if name == "dam":
			var tunnel := float(lifts.get(_index(rows, "spillway_tunnel"), 0.0))
			var rooms := float(lifts.get(_index(rows, "cliff_rooms_west"), 0.0))
			_t.check("(b) the dam's cliff_rooms_west stands over spillway_tunnel (%.3f over %.3f)" % [rooms, tunnel], rooms > tunnel)
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
	quit(_t.verdict())
