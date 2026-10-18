extends SceneTree
# 2026-10-17 (placeholder units C and F, alpha-status/placeholders/BREAKDOWN.md): the sized kickers (tools/blender/park/
# kickers.py) and the lava channel half-pipe (tools/blender/park/lavachannels.py) place through park_recipes.gd and ride.
# Each GLB is one row size [L, H, W], because the seat fit stretches a GLB along its ride only (PARK-SEAT); its id says
# that size, and a seat-fit row seats any length from 0.75 to 1.5 L.
# (a) Each recipe ships its base GLB and two detail shells; the base holds the render mesh and its -col mesh only, and
#     the folded registry says origin entry_lip.
# (b) Budgets after import: base and -col within the landform class (8,000 triangles, two draws), each shell one draw
#     within the detail class.
# (c) Coverage: every greybox flume and pit kicker, every sinkhole lava_channel half-pipe, every crown kicker and every
#     islands shelf-edge step lip has a piece of its width and height (piece_for), and its seat fit is not refused.
# (d) Placed on a seat-fit row on flat ground, a piece's collider is the row's footprint: width W, lip height H (the
#     shelf edge's coping 0.06 m), centred on the row's at.
# (e) A ball runs off plate_kicker_12x2p5x14 on a seat-fit pit row, leaves the ground at the lip (StageMap.near_kicker_lip)
#     at the angle the row's height and length set, with no dead stop on the way.
# (f) A ball rolls the length of a seated lava_channel row with a sideways push: it pumps between the walls, stays inside
#     the channel, rolls out of the far end, and never dead-stops.
# Evidence limit: headless Jolt physics on a 1 m ball on flat ground (no park bake, so no stamp under the channel); no
# feel, look or camera claim.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const StageMap := preload("res://src/world/stage_map.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

const EPS := 0.03
const DEAD_SPEED := 2.0
const DEAD_FRAMES := 30
const LANDFORM_TRIS := 8000
const DETAIL_TRIS := 1500
const PARKS := ["res://src/world/park/park_flume.json", "res://src/world/park/park_pit.json", "res://src/world/park/park_sinkhole.json",
	"res://src/world/park/park_crown.json", "res://src/world/park/park_islands.json"]
# Each piece: [L, H, W] as authored.
const PIECES := {
	"plate_kicker_12x2p5x14": [12, 2.5, 14], "plate_kicker_12x2p5x30": [12, 2.5, 30], "plate_kicker_12x2p5x40": [12, 2.5, 40],
	"plate_kicker_10x3x8": [10, 3, 8], "plate_kicker_30x8x18": [30, 8, 18], "plate_kicker_28x14x34": [28, 14, 34],
	"plate_kicker_24x3x20": [24, 3, 20], "plate_kicker_24x4x18": [24, 4, 18], "plate_kicker_18x4x10": [18, 4, 10],
	"plate_kicker_16x6x24": [16, 6, 24], "plate_kicker_8x3x20": [8, 3, 20],
	"mesa_lip_kicker_24x6x36": [24, 6, 36], "mesa_lip_kicker_24x6x60": [24, 6, 60], "mesa_lip_kicker_24x6x90": [24, 6, 90],
	"mesa_lip_kicker_26x5x30": [26, 5, 30], "mesa_lip_kicker_60x32x36": [60, 32, 36], "mesa_lip_kicker_60x26x60": [60, 26, 60],
	"mesa_shelf_edge": [12, 0.01, 1600],
	"lava_channel": [58, 4, 28],
}
const SHELF_TOP := 0.06
const LAVA_LIFT := 0.12

var _t := T.new("park_recipes_kickers_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_files()
	_check_budgets()
	_check_coverage()
	_check_placed()
	await _check_kicker_roll()
	await _check_channel_roll()
	quit(_t.verdict())


func _row(id: String, element: String, at: Vector2, y: Variant, size: Array, recipe: String, fact: String) -> Dictionary:
	return {"id": id, "element": element, "at": [at.x, at.y], "y": y, "size": size.duplicate(), "yaw_deg": 0.0,
		"ride_fact": fact, "recipe": recipe, "budget": "landform", "fit": "seat"}


func _scene(path: String) -> Node:
	if not ResourceLoader.exists(path):
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() if packed != null else null


func _check_files() -> void:
	for id: String in PIECES:
		var p := ParkRecipes.paths(id, "landform")
		_t.check("(a) %s base GLB ships" % id, ResourceLoader.exists(p["base"]), p["base"])
		for shell: String in p["shells"]:
			_t.check("(a) %s shell ships" % id, ResourceLoader.exists(shell), shell)
		_t.eq("(a) %s registry origin" % id, ParkRecipes.origin(id), ParkRecipes.ORIGIN_ENTRY_LIP)
		var scene := _scene(p["base"])
		if scene == null:
			continue
		var names: Array = scene.find_children("*", "MeshInstance3D", true, false).map(func(m): return String(m.name))
		_t.check("(a) %s base holds the render mesh and its -col mesh only" % id, names.has(id) and names.has(id + ParkRecipes.COL_SUFFIX)
			and names.size() == 2, str(names))
		scene.free()


func _measure(path: String) -> Dictionary:
	var node := _scene(path)
	if node == null:
		return {}
	var tris := 0
	var draws := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var idx = arrays[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	node.free()
	return {"tris": tris, "draws": draws}


func _check_budgets() -> void:
	for id: String in PIECES:
		var p := ParkRecipes.paths(id, "landform")
		var m := _measure(p["base"])
		_t.check("(b) %s base and -col: two draws within %d triangles" % [id, LANDFORM_TRIS], not m.is_empty() and m["tris"] <= LANDFORM_TRIS
			and m["draws"] == 2, str(m))
		for shell: String in p["shells"]:
			var s := _measure(shell)
			_t.check("(b) %s: one draw within %d triangles" % [shell.get_file(), DETAIL_TRIS], not s.is_empty() and s["tris"] <= DETAIL_TRIS
				and s["draws"] == 1, str(s))


# The piece a park row takes: the same height and width, and the row's length within the seat's stretch of its own.
static func piece_for(row: Dictionary) -> String:
	var size: Array = row["size"]
	for id: String in PIECES:
		var want: Array = PIECES[id]
		var stretch := float(size[0]) / float(want[0])
		if absf(float(size[1]) - float(want[1])) < 1e-3 and absf(float(size[2]) - float(want[2])) < 1e-3 \
				and stretch >= ParkRecipes.STRETCH_MIN and stretch <= ParkRecipes.STRETCH_MAX:
			return id
	return ""


# The rows these pieces exist for: greybox kickers in the flume, pit, crown and islands, and the sinkhole's lava channels.
static func _target(park: String, row: Dictionary) -> bool:
	if String(row.get("recipe", "")) != "greybox:" + String(row["element"]):
		return false
	if park.ends_with("park_sinkhole.json"):
		return row["element"] == "half_pipe" and String(row["id"]).begins_with("lava_channel_")
	if park.ends_with("park_islands.json"):
		return row["element"] == "kicker" and String(row["id"]).contains("step_lip")
	return row["element"] == "kicker"


func _check_coverage() -> void:
	var covered := 0
	var total := 0
	for path: String in PARKS:
		var park = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not park is Dictionary:
			_t.check("(c) %s parses" % path.get_file(), false)
			continue
		var missing := []
		for row: Dictionary in park["park_rows"]:
			if not _target(path, row):
				continue
			total += 1
			var id := piece_for(row)
			if id == "":
				missing.append("%s %s" % [row["id"], row["size"]])
				continue
			var seated := row.duplicate(true)
			seated["recipe"] = id
			seated["fit"] = ParkRecipes.FIT_SEAT
			var refusal := ParkRecipes.seat_refusal(seated, ParkRecipes.recipe_ends(id))
			if refusal != "":
				missing.append("%s: %s" % [row["id"], refusal])
				continue
			covered += 1
		_t.check("(c) %s: every target row has a piece that seats it" % path.get_file(), missing.is_empty(), str(missing))
	# 2026-10-18: 64 target rows, was 73. The #112 pit authored pass seated the pit's nine greybox kickers on the
	# plate_kicker pieces themselves (park_pit.json recipe plate_kicker_12x2p5x*), so they are no longer greybox targets.
	_t.check("(c) the pieces seat all 64 target rows (9 flume kickers, 21 lava channels, 16 crown kickers, 18 step lips)",
		covered == total and total == 64, "%d of %d" % [covered, total])


# The collider's AABB in the node's space.
func _collider_box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for s: CollisionShape3D in node.find_children("*", "CollisionShape3D", true, false):
		if not s.shape is ConcavePolygonShape3D:
			continue
		for v in (s.shape as ConcavePolygonShape3D).get_faces():
			var p := s.transform * v
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box


func _check_placed() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var x := 0.0
	for id: String in PIECES:
		var size: Array = PIECES[id]
		var element := "half_pipe" if id == "lava_channel" else "kicker"
		var node := ParkRecipes.place(_row(id, element, Vector2(x, 0), 0.0, size, id, ""), parent)
		x += float(size[2]) + 20.0
		if not _t.check("(d) %s places as its GLB, not a greybox" % id, node != null and not node.has_meta("seat_refused")
				and node.get_node_or_null("Greybox") == null, str(node)):
			continue
		var box := _collider_box(node)
		var top := SHELF_TOP if id == "mesa_shelf_edge" else (LAVA_LIFT if id == "lava_channel" else float(size[1]))
		var half := float(size[0]) * 0.5
		_t.check("(d) %s collider is %.0f m wide, tops at %.2f m, from -L/2 to L/2 on its centre" % [id, float(size[2]), top],
			absf(box.size.x - float(size[2])) <= EPS and absf(box.end.y - top) <= EPS and absf(box.position.x + float(size[2]) * 0.5) <= EPS
			and box.position.z <= -half + EPS and box.end.z >= half - EPS, str(box))
	parent.free()


func _ball(parent: Node3D, at: Vector3, velocity: Vector3) -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.can_sleep = false
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.set_collision_layer_value(2, true)
	ball.set_collision_mask_value(1, true)
	ball.gravity_scale = Tuning.new().f("gravity") / 9.8
	# the game ball's own damping and surface (rigid_ball.gd), rolling without slip at the start
	ball.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.linear_damp = 0.0
	ball.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	ball.angular_damp = 0.25
	var surface := PhysicsMaterial.new()
	surface.friction = 0.9
	surface.bounce = 0.25
	ball.physics_material_override = surface
	ball.angular_velocity = Vector3(velocity.z, 0.0, -velocity.x) / Tuning.RADIUS
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Tuning.RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.position = at
	ball.linear_velocity = velocity
	parent.add_child(ball)
	return ball


func _dead_run(speeds: Array) -> int:
	var best := 0
	var run := 0
	for v: float in speeds:
		run = run + 1 if v < DEAD_SPEED else 0
		best = maxi(best, run)
	return best


func _check_kicker_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	ParkRecipes.place(_row("runway", "ground", Vector2(0, -30), -1.0, [60, 1, 40], "greybox:ground", ""), parent)
	var kicker_row := _row("k", "kicker", Vector2(0, 6), 0.0, [12, 2.5, 14], "plate_kicker_12x2p5x14", "kicker_launch")
	ParkRecipes.place(kicker_row, parent)
	var map := StageMap.new()
	var lip: Dictionary = ParkMap.kicker_lip(kicker_row)
	map.kickers = [lip]
	var ball := _ball(parent, Vector3(0, 1.05, -50), Vector3(0, 0, 20))
	var speeds: Array = []
	var launched := false
	var angle := -1.0
	var grounded_before := false
	for f in 600:
		await physics_frame
		var p := ball.position
		var grounded := ball.get_contact_count() > 0
		if not launched and grounded_before and not grounded and map.near_kicker_lip(Vector2(p.x, p.z)):
			launched = true
			var v := ball.linear_velocity
			angle = rad_to_deg(atan2(v.y, Vector2(v.x, v.z).length()))
		grounded_before = grounded
		if p.z < 12.0:
			speeds.append(ball.linear_velocity.length())
	var want := rad_to_deg(atan2(2.0 * 2.5, 12.0))
	_t.check("(e) the ball leaves plate_kicker_12x2p5x14 at its lip at the angle the row sets", launched and absf(angle - want) <= 6.0,
		"left at %.1f degrees, row sets %.1f" % [angle, want])
	_t.check("(e) no dead stop up the ramp", _dead_run(speeds) <= DEAD_FRAMES, "%d frames under 2 m/s" % _dead_run(speeds))
	parent.free()


func _check_channel_roll() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	# a 59.5 m row, the lava channels' typical length: the GLB stretches 1.03 and runs z -29.75..29.75
	var row := _row("c", "half_pipe", Vector2(0, 0), 0.0, [59.5, 4, 28], "lava_channel", "ride_chute")
	ParkRecipes.place(row, parent)
	ParkRecipes.place(_row("apron_in", "ground", Vector2(0, -45), -1.0, [30, 1, 40], "greybox:ground", ""), parent)
	ParkRecipes.place(_row("apron_out", "ground", Vector2(0, 45), -1.0, [30, 1, 40], "greybox:ground", ""), parent)
	var ball := _ball(parent, Vector3(0, 1.05, -42), Vector3(4, 0, 14))
	var speeds: Array = []
	var widest := 0.0
	var lowest := 0.0
	var crossings := 0
	var side := 0
	for f in 600:
		await physics_frame
		var p := ball.position
		if p.z > -29.75 and p.z < 29.75:
			widest = maxf(widest, absf(p.x))
			lowest = minf(lowest, p.y)
			var s := signi(int(signf(p.x)))
			if s != 0 and side != 0 and s != side:
				crossings += 1
			if s != 0:
				side = s
		if p.z < 40.0:
			speeds.append(ball.linear_velocity.length())
	_t.check("(f) the ball pumps across the floor between the walls", crossings >= 1, "%d crossings" % crossings)
	_t.check("(f) the ball stays inside the channel's 28 m", widest < 13.5, "widest %.2f m" % widest)
	_t.check("(f) the ball drops into the channel floor", lowest < -2.5, "lowest %.2f m" % lowest)
	_t.check("(f) the ball rolls out of the far end", ball.position.z > 30.0 and ball.position.y > -1.0, str(ball.position))
	_t.check("(f) no dead stop through the channel", _dead_run(speeds) <= DEAD_FRAMES, "%d frames under 2 m/s" % _dead_run(speeds))
	parent.free()
