extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# The flume's timber grapple posts collide as their drawn shaft, not as the 8 m box (tools/qa/invisible_walls.gd, 30 Oct):
# the crane booms (size 40) and hollow trestles (size 16) kept the box because their low band fitted it, while the drawn
# shaft above is about 4.5 m across, so a ball on the mesa rim beside a boom stopped in 1.75-2 m of visible air.
# anchor_fit.py now fits world 1 timber posts by their upper air too. On the built stage, a point 3 m off each post's
# axis at mid-shaft is clear of every collider on all four sides, and the axis itself still collides.

const ROWS := {"crane_booms": 40.0, "hollow_trestles": 16.0}
const OFF_M := 3.0
const SHAFT_R := 2.5

var _t := T.new("flume_post_walls_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_flume.json"))
	for row: Dictionary in park["park_rows"]:
		if ROWS.has(String(row["id"])):
			_t.eq("%s is a size %d timber field" % [row["id"], ROWS[row["id"]]], float(row["size"][1]), ROWS[row["id"]])
			var fit := ParkRecipes.anchor_fit_boxes(row)
			_t.check("%s has fitted post boxes (%d)" % [row["id"], fit.size()], fit.size() >= 4)
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(2) and terrain.is_ready(2) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	game.player.body().freeze = true
	game.player.body().global_position = Vector3(0.0, -5000.0, 0.0)
	for i in 3:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	for id: String in ROWS:
		var node := game.find_child("Park_" + id, true, false) as Node3D
		_t.check("%s is built" % id, node != null)
		if node == null:
			continue
		var tall := float(ROWS[id]) + ParkRecipes.ANCHOR_SINK_M
		var posts: Array = []
		var seen := {}
		for s: Dictionary in ParkRecipes.collider_shapes(node.get_node("Collider")):
			var at: Vector3 = (s["global_transform"] as Transform3D).origin
			var key := Vector2i(roundi(at.x * 10.0), roundi(at.z * 10.0))
			if s["shape"] is ConvexPolygonShape3D and not seen.has(key):
				seen[key] = true
				posts.append(at)
		_t.check("%s posts collide as hulls (%d posts)" % [id, posts.size()], posts.size() >= 4)
		var clear := 0
		var blocked: Array = []
		var axis_hits := 0
		for p: Vector3 in posts:
			# A hull's origin is the post foot (anchor_hulls: h metres above the ground sample).
			var mid := p + Vector3.UP * tall * 0.5
			axis_hits += 1 if _solid(space, mid) else 0
			for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
				var q: Vector3 = mid + d * OFF_M
				# A neighbour within a shaft's reach of the point (the trestles' doubled posts) is its own solid.
				if posts.any(func(o: Vector3) -> bool: return o != p and Vector2(o.x - q.x, o.z - q.z).length() < SHAFT_R):
					continue
				if _solid(space, q):
					blocked.append([snappedf(q.x, 0.1), snappedf(q.y, 0.1), snappedf(q.z, 0.1)])
				else:
					clear += 1
		_t.eq("%s: every post's axis collides at mid-shaft" % id, axis_hits, posts.size())
		_t.check("%s: %d points %.0f m off a post's axis at mid-shaft are clear (blocked: %s)" % [id, clear, OFF_M, str(blocked.slice(0, 4))],
			blocked.is_empty())
	game.free()
	quit(_t.verdict())


func _solid(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	# The ground can rise past mid-shaft beside a post on a slope; only placed colliders count.
	for hit in space.intersect_point(q, 8):
		var body = hit.get("collider")
		if body is Node and String((body as Node).get_parent().name) != "Tiles":
			return true
	return false
