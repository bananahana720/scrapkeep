extends SceneTree
# smoke: timeout=360s

# The flume's crib piers and walls stand on the ground they cover (wave 37, PF-31). A crib was set on the ground at its
# centre, so over ground that falls away under its footprint its bottom floated: the siphon turn coping 2.4 m over the
# ground at its low end, four piers 0.6 to 1.6 m. A ball rolls in under such an edge and wedges against it (the park
# table bot on seed 4479 sat stuck under the coping with the wall's underside pressing down on it). The foot fit
# (park_recipes.gd foot_fit) stretches each crib down to the lowest ground under its footprint about its own top.
#
# For every crib row the flume places: around its footprint, 1 m inside the edge every 2 m, the collider's flat bottom is
# at most GAP_M over the ground (no gap a ball fits under); its collider top is where the GLB's authored top puts it;
# and its plan footprint is the authored one. A row that is not a crib keeps its plain place (no foot_stretch).
# Control: a planted box hung 1 m over the ground beside the coping reads as a gap, so a pass is the cribs' and not a
# blind measure. The places, sizes and the ground are read from the running game.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# A ball of radius 1 cannot enter a gap this low; a lower edge is a bevel it rolls past.
const GAP_M := 0.25
const INSET_M := 1.0
const STEP_M := 2.0
const TOP_M := 0.02
const PLAIN := "Park_flume_ride_pier_25"

var t := T.new("park_crib_foot_test")
var game


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 30:
		await physics_frame
	t.eq("real Game plays the flume on the park table", terrain.map().title, "park_flume")
	var cribs := []
	for node: Node3D in game.find_children("Park_*", "Node3D", true, false):
		if node.has_meta("park_recipe") and ParkRecipes.FOOTED.any(func(k): return String(node.get_meta("park_recipe")).begins_with(k)):
			cribs.append(node)
	t.check("the flume places its crib piers and walls", cribs.size() >= 5, "%d cribs" % cribs.size())
	var coping: Node3D = null
	for crib: Node3D in cribs:
		var recipe := String(crib.get_meta("park_recipe"))
		var authored := _aabb(ParkRecipes.col_faces(_scene(recipe)))
		var placed := _aabb(_faces(crib.get_node("Collider")))
		var gap := _worst_gap(crib.global_transform, placed, terrain)
		var stretch := float(crib.get_meta("foot_stretch", 1.0))
		print("  %s (%s) stretch %.3f, worst gap %.2f m at %s" % [crib.name, recipe, stretch, gap["gap"], gap["at"]])
		t.check("%s: no gap a ball fits under its edge" % crib.name, gap["gap"] <= GAP_M and gap["read"] >= 8, "%.2f m at %s, %d points read" % [gap["gap"], gap["at"], gap["read"]])
		t.check("%s: its top is the authored top" % crib.name, absf(placed.end.y - authored.end.y) <= TOP_M, "placed %.3f, authored %.3f" % [placed.end.y, authored.end.y])
		t.check("%s: its plan is the authored plan" % crib.name, Vector2(placed.size.x, placed.size.z).distance_to(Vector2(authored.size.x, authored.size.z)) <= TOP_M,
			"placed %s, authored %s" % [placed.size, authored.size])
		if String(crib.name) == "Park_siphon_turn_coping":
			coping = crib
	t.check("the siphon turn coping (where the bot sat stuck) is among them", coping != null)
	var plain: Array = game.find_children(PLAIN, "Node3D", true, false)
	t.check("a row that is not a crib keeps its plain place", plain.size() == 1 and not (plain[0] as Node).has_meta("foot_stretch"), str(plain))

	if coping != null:
		var c: Vector3 = coping.global_position + coping.global_basis.x * 12.0
		var g: float = terrain.height(c.x, c.z)
		var hung := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 2.0, 6.0)
		shape.shape = box
		hung.add_child(shape)
		game.add_child(hung)
		hung.global_position = Vector3(c.x, g + 1.0 + 1.0, c.z)
		await physics_frame
		await physics_frame
		var control := _worst_gap(hung.global_transform, AABB(-box.size * 0.5, box.size), terrain)
		t.check("control: a box hung 1 m over the ground reads as a gap", control["gap"] > GAP_M, "%.2f m, %d points read" % [control["gap"], control["read"]])
		hung.queue_free()
	game.free()
	quit(t.verdict())


func _scene(recipe: String) -> Node:
	var scene: Node = (load(ParkRecipes.GLB_DIR + recipe + ".glb") as PackedScene).instantiate()
	root.add_child(scene)
	scene.queue_free()
	return scene


# The collider's faces in its node's frame (the body sits at the row node's origin).
func _faces(body: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
		if s.shape is ConcavePolygonShape3D:
			out.append_array(s.transform * (s.shape as ConcavePolygonShape3D).get_faces())
	return out


func _aabb(faces: PackedVector3Array) -> AABB:
	var box := AABB(faces[0], Vector3.ZERO)
	for v in faces:
		box = box.expand(v)
	return box


# The highest clearance under a flat-bottomed collider round its footprint (box in the frame xf), INSET_M inside the
# edge every STEP_M: the collider's bottom less the ground there. A crib's collider is a box, so its bottom is flat.
func _worst_gap(xf: Transform3D, box: AABB, terrain) -> Dictionary:
	var worst := {"gap": -INF, "at": Vector3.ZERO, "read": 0}
	var bottom: float = (xf * box.position).y
	var lo := Vector2(box.position.x + INSET_M, box.position.z + INSET_M)
	var hi := Vector2(box.end.x - INSET_M, box.end.z - INSET_M)
	var points := []
	for i in ceili((hi.x - lo.x) / STEP_M) + 1:
		var x := minf(lo.x + i * STEP_M, hi.x)
		points.append(Vector2(x, lo.y))
		points.append(Vector2(x, hi.y))
	for k in ceili((hi.y - lo.y) / STEP_M) + 1:
		var z := minf(lo.y + k * STEP_M, hi.y)
		points.append(Vector2(lo.x, z))
		points.append(Vector2(hi.x, z))
	for p: Vector2 in points:
		var w := xf * Vector3(p.x, 0.0, p.y)
		var gap: float = bottom - float(terrain.height(w.x, w.z))
		worst["read"] += 1
		if gap > worst["gap"]:
			worst["gap"] = gap
			worst["at"] = Vector3(w.x, bottom, w.z).snapped(Vector3.ONE * 0.1)
	return worst
