extends SceneTree
# 2026-10-10 (w13 KC7): the crater family's two recipes, crater_event and crater_ending, as the section 4 / KC0 contract
# reads them (design-v3/PARK.md section 4; park_recipes.gd loads <id>.glb, <id>_detail1.glb and <id>_detail2.glb).
# (a) Files and budget: each id ships its base GLB with exactly one drawn mesh and one "<id>-col" mesh, plus two detail
# shell GLBs of one draw each; triangles and draws sit inside park_large (base 16,000 / 2 draws) and detail (1,500 / 1);
# no light nodes; the placed node carries the trimesh and no greybox stand-in.
# (b) Convention: +Y up, ride direction +Z, origin at the entry lip on the ground. The bowl's cut lip (stamp radius 0.8,
# park_stamps.gd "crater") is the origin at y 0; the floor is the recipe's depth below it; the rim crest stands 0.2 of
# the depth above the ground beside the lip; the far lip is on the ground again; the ejecta blanket ends flush with the
# ground. Sizes: crater_event crest 40 to 60 m, crater_ending 400 m.
# (c) The roll: placed through park_recipes.place, a ball dropped in at the lip publishes ride_bowl, and on two lines (down
# the fall line across the floor, and a tangent entry that carves the wall) its speed never stays under 2 m/s for 0.5 s.
# (d) The rim is clean: a roll starts inside the rim, nothing blocks the cut lip's width (checked by rays across x).
# Evidence limit: headless physics with a plain RigidBody3D sphere; no feel claim and no look claim (the blind pairs under
# artifacts/local/alpha/push/w13/park-recipes/crater carry the look).

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const IDS := ["crater_event", "crater_ending"]
# Per recipe: stamp footprint radius F (metres), depth h, and the crest-to-crest diameter the section 4 table names.
const SPEC := {
	"crater_event": {"f": 28.0, "h": 8.0, "crest_min": 40.0, "crest_max": 60.0, "enter": 14.0, "seconds": 9.0},
	"crater_ending": {"f": 235.0, "h": 60.0, "crest_min": 390.0, "crest_max": 410.0, "enter": 16.0, "seconds": 14.0},
}
const BASE_TRIS := 16000
const BASE_DRAWS := 2
const DETAIL_TRIS := 1500
const DETAIL_DRAWS := 1
const LIP := 0.8
const CREST := 0.85
const BLANKET := 1.5
const SLOW_MPS := 2.0
const SLOW_MAX_S := 0.5
const SPACING := 3000.0
const GROUND_TOL := 0.35

var _t := T.new("park_recipes_crater_test")
var _facts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var rides := []
	var i := 0
	for id: String in IDS:
		_check_registry(id)
		_check_files(id)
		var row := _row(id, Vector2(i * SPACING, 0.0))
		var node := ParkRecipes.place(row, parent, Callable(), func(kind: String, at: Vector3) -> void: _facts.append([kind, at]))
		_check_placed(id, node)
		rides.append({"id": id, "node": node, "x": i * SPACING})
		i += 1
	await physics_frame
	await physics_frame
	for ride in rides:
		_check_shape(ride["id"], ride["x"])
	await _check_roll(parent, rides)
	parent.free()
	quit(_t.verdict())


func _row(id: String, at: Vector2) -> Dictionary:
	var f: float = SPEC[id]["f"]
	var h: float = SPEC[id]["h"]
	return {"id": "row_" + id, "element": "crater_bowl", "at": [at.x, at.y], "y": 0.0, "size": [2.0 * f * LIP, h, 2.0 * f * LIP],
		"yaw_deg": 0.0, "ride_fact": "ride_bowl", "recipe": id, "budget": "park_large"}


func _check_registry(id: String) -> void:
	var row: Dictionary = ParkRecipes.ROWS.get(id, {})
	_t.check("(a) %s is a crater park_large registry row" % id, row.get("family", "") == "crater" and row.get("budget", "") == "park_large", str(row))


# Meshes of a loaded scene: [{name, tris, surfaces, aabb}] for every MeshInstance3D.
func _meshes(scene: Node) -> Array:
	var out := []
	for m: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null:
			continue
		var tris := 0
		for s in m.mesh.get_surface_count():
			var arrays := m.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
		out.append({"name": String(m.name), "tris": tris, "surfaces": m.mesh.get_surface_count(), "aabb": m.mesh.get_aabb()})
	return out


func _load_scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _check_files(id: String) -> void:
	var p := ParkRecipes.paths(id, "park_large")
	var base := _load_scene(p["base"])
	if not _t.check("(a) %s base GLB exists and loads" % id, base != null, p["base"]):
		return
	var meshes := _meshes(base)
	var col := meshes.filter(func(m): return String(m["name"]).ends_with(ParkRecipes.COL_SUFFIX))
	var drawn := meshes.filter(func(m): return not String(m["name"]).ends_with(ParkRecipes.COL_SUFFIX))
	_t.check("(a) %s has one drawn mesh and one %s%s mesh" % [id, id, ParkRecipes.COL_SUFFIX],
		col.size() == 1 and drawn.size() == 1 and col[0]["name"] == id + ParkRecipes.COL_SUFFIX, str(meshes.map(func(m): return m["name"])))
	var tris := 0
	var draws := 0
	for m in meshes:
		tris += int(m["tris"])
		draws += int(m["surfaces"])
	_t.check("(a) %s is inside park_large: %d tris / %d draws" % [id, tris, draws], tris <= BASE_TRIS and draws <= BASE_DRAWS and tris > 0)
	_t.check("(a) %s has no light nodes" % id, base.find_children("*", "Light3D", true, false).is_empty())
	base.free()
	for k in 2:
		var shell := _load_scene(p["shells"][k])
		if not _t.check("(a) %s detail shell %d exists and loads" % [id, k + 1], shell != null, p["shells"][k]):
			continue
		var sm := _meshes(shell)
		var st := 0
		var sd := 0
		for m in sm:
			st += int(m["tris"])
			sd += int(m["surfaces"])
		_t.check("(a) %s shell %d is inside detail: %d tris / %d draws" % [id, k + 1, st, sd], st <= DETAIL_TRIS and sd <= DETAIL_DRAWS and st > 0)
		_t.check("(a) %s shell %d has no -col mesh and no lights" % [id, k + 1],
			sm.all(func(m): return not String(m["name"]).ends_with(ParkRecipes.COL_SUFFIX)) and shell.find_children("*", "Light3D", true, false).is_empty())
		shell.free()


func _check_placed(id: String, node: Node3D) -> void:
	if not _t.check("(a) %s places" % id, node != null):
		return
	_t.check("(a) %s placed as a GLB, no greybox stand-in" % id, node.get_node_or_null("Greybox") == null)
	var shapes := node.find_children("*", "CollisionShape3D", true, false).filter(func(s): return s.get_parent() is StaticBody3D)
	_t.check("(a) %s collider is one trimesh" % id, shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D, "%d shapes" % shapes.size())
	var views := node.find_children("*", "MeshInstance3D", true, false)
	_t.check("(a) %s draws base plus two shells and never the -col" % id, views.size() == 3
		and views.all(func(v): return not String(v.name).ends_with(ParkRecipes.COL_SUFFIX)), "%d views" % views.size())


# Ground height under (x, z) in world space by a ray from above; NAN when nothing is hit.
func _ground(x: float, z: float) -> float:
	var space := root.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400.0, z), Vector3(x, -400.0, z))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	return float(hit["position"].y) if not hit.is_empty() else NAN


func _near_or_fail(label: String, got: float, want: float, tol: float) -> void:
	_t.check(label, not is_nan(got) and absf(got - want) <= tol, "got %s, want %s +- %s" % [got, want, tol])


func _check_shape(id: String, x0: float) -> void:
	var spec: Dictionary = SPEC[id]
	var f: float = spec["f"]
	var h: float = spec["h"]
	var centre := LIP * f
	# The entry lip is the origin on the ground; the floor is h below the bowl's centre.
	_near_or_fail("(b) %s origin is the entry lip on the ground" % id, _ground(x0, 0.0), 0.0, GROUND_TOL)
	_near_or_fail("(b) %s floor is %.0f m under the lip at the bowl's centre" % [id, h], _ground(x0, centre), -h, 0.15 * h)
	_near_or_fail("(b) %s far lip is on the ground" % id, _ground(x0, 2.0 * centre), 0.0, GROUND_TOL)
	# The rim crest stands 0.2 h above the ground, 0.05 F outside the lip, on both sides (the stamp's rim ring).
	var crest_back := _ground(x0, -(CREST - LIP) * f)
	var crest_front := _ground(x0, 2.0 * centre + (CREST - LIP) * f)
	_near_or_fail("(b) %s near rim crest is 0.2 of the depth up" % id, crest_back, 0.2 * h, 0.1 * h)
	_near_or_fail("(b) %s far rim crest is 0.2 of the depth up" % id, crest_front, 0.2 * h, 0.1 * h)
	# The ejecta blanket ends flush with the ground on every side.
	_near_or_fail("(b) %s blanket ends flush (near side)" % id, _ground(x0, centre - (BLANKET * f - 0.5)), 0.0, 0.6)
	_near_or_fail("(b) %s blanket ends flush (far side)" % id, _ground(x0, centre + (BLANKET * f - 0.5)), 0.0, 0.6)
	_near_or_fail("(b) %s blanket ends flush (+x)" % id, _ground(x0 + (BLANKET * f - 0.5), centre), 0.0, 0.6)
	_near_or_fail("(b) %s blanket ends flush (-x)" % id, _ground(x0 - (BLANKET * f - 0.5), centre), 0.0, 0.6)
	# The bowl is round: the wall at the same radius reads the same height on the +x and -x sides.
	var r := 0.5 * LIP * f
	var left := _ground(x0 - r, centre)
	var right := _ground(x0 + r, centre)
	_t.check("(b) %s is symmetric across x" % id, not is_nan(left) and not is_nan(right) and absf(left - right) <= 0.05 * h, "%s vs %s" % [left, right])
	# Nothing outside the footprint: the blanket stops short of 1.6 F from the centre.
	_t.check("(b) %s stops inside %.1f F of the centre" % [id, BLANKET + 0.1], is_nan(_ground(x0 + (BLANKET + 0.1) * f, centre)) and is_nan(_ground(x0, centre + (BLANKET + 0.1) * f)))
	var crest_d := 2.0 * CREST * f
	_t.check("(b) %s crest diameter %.1f m is in %s to %s m" % [id, crest_d, spec["crest_min"], spec["crest_max"]], crest_d >= spec["crest_min"] and crest_d <= spec["crest_max"])
	# (d) the cut lip is open across its whole chord: no ray along x at the lip hits a step above the plane.
	var worst := 0.0
	for k in range(-10, 11):
		var u := float(k) / 10.0 * 0.9 * f * 0.4
		var y := _ground(x0 + u, 0.0)
		if not is_nan(y):
			worst = maxf(worst, absf(y))
	_t.check("(d) %s lip is clean across its chord (worst %.2f m off the ground)" % [id, worst], worst <= 0.5 + 0.02 * f)


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	parent.add_child(ball)
	return ball


func _check_roll(parent: Node3D, rides: Array) -> void:
	var lines := []
	for ride in rides:
		var spec: Dictionary = SPEC[ride["id"]]
		var f: float = spec["f"]
		var centre := LIP * f
		var x0: float = ride["x"]
		# Line A: down the fall line from the lip. Line B: a tangent entry on the wall at 0.45 of the cut radius.
		var a := _ball(parent, Vector3(x0, Tuning.RADIUS + 0.2, 0.0), Vector3(0, 0, spec["enter"]))
		var bx := 0.45 * LIP * f
		var b := _ball(parent, Vector3(x0 + bx, _ground(x0 + bx, 0.5) + Tuning.RADIUS + 0.2, 0.5), Vector3(0, 0, spec["enter"]))
		lines.append({"id": ride["id"], "name": "fall line", "ball": a, "slow": 0.0, "worst": 0.0, "min": INF})
		lines.append({"id": ride["id"], "name": "tangent entry", "ball": b, "slow": 0.0, "worst": 0.0, "min": INF})
	var dt := 1.0 / float(Engine.physics_ticks_per_second)
	var seconds := 0.0
	var longest := 0.0
	for s: Dictionary in SPEC.values():
		longest = maxf(longest, s["seconds"])
	var frames := int(longest / dt)
	for n in frames:
		await physics_frame
		seconds += dt
		for line in lines:
			if seconds > SPEC[line["id"]]["seconds"]:
				continue
			var speed: float = (line["ball"] as RigidBody3D).linear_velocity.length()
			line["min"] = minf(line["min"], speed)
			if speed < SLOW_MPS:
				line["slow"] += dt
				line["worst"] = maxf(line["worst"], line["slow"])
			else:
				line["slow"] = 0.0
	for line in lines:
		var ball: RigidBody3D = line["ball"]
		_t.check("(c) %s %s: speed under %.0f m/s for at most %.1f s (longest %.2f s, min %.1f m/s)" % [line["id"], line["name"], SLOW_MPS, SLOW_MAX_S, line["worst"], line["min"]],
			line["worst"] <= SLOW_MAX_S and line["min"] < INF)
		_t.check("(c) %s %s: the ball is still on the bowl, not through it" % [line["id"], line["name"]], ball.position.y > -SPEC[line["id"]]["h"] - 3.0, "y %.1f" % ball.position.y)
	for ride in rides:
		var near := _facts.filter(func(e): return absf(e[1].x - ride["x"]) < SPACING * 0.5)
		_t.check("(c) %s rolled publishes ride_bowl" % ride["id"], near.size() >= 1 and near.all(func(e): return e[0] == "ride_bowl"), str(near.map(func(e): return e[0])))
