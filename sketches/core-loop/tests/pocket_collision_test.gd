extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Library := preload("res://src/world/pockets/pocket_library.gd")
var t := T.new("pocket_collision_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.body().freeze = true
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	await physics_frame
	var entry: Dictionary = Library.rows().filter(func(row): return row.id == "runner_yard")[0]
	var site = acts._build(entry.activity, Vector2(200, 200), Library.site_spec(entry))
	acts.sites.append(site)
	var interior = site.get_node("Interior_runner_yard")
	t.eq("terrain meshes are visible before entry", _meshes(interior), 4)
	t.eq("unvisited interior creates no physics bodies", _bodies(interior), 0)
	var ball = game.player.body()
	ball.global_position = site.global_position + Vector3(30.01, 1, 0)
	acts._physics_process(0.0)
	await physics_frame
	t.eq("outside word reach still creates no physics bodies", _bodies(interior), 0)
	ball.global_position = site.global_position + Vector3(20, 1, 0)
	acts._physics_process(0.0)
	await physics_frame
	t.eq("reading the word outside the pocket creates no physics bodies", _bodies(interior), 0)
	var block: Dictionary = entry.terrain[0]
	var center: Vector3 = site.to_global(Vector3(block.at[0], block.size[1] * 0.5, block.at[1]))
	var start := center - Vector3(float(block.size[0]) * 0.5 + 0.5, 0, 0)
	var end := center + Vector3(float(block.size[0]) * 0.5 + 0.5, 0, 0)
	t.check("unvisited block cannot intercept an enemy or bot", _ray(site, start, end).is_empty())
	ball.global_position = site.global_position + Vector3(16, 1, 0)
	acts._physics_process(0.0)
	await physics_frame
	t.eq("at the authored pocket boundary both blocks become solid", _bodies(interior), 2)
	var hit := _ray(site, start, end)
	t.check("entered terrain blocks the physical collision layer", not hit.is_empty() and interior.is_ancestor_of(hit.get("collider")), str(hit))
	acts._spawn_pocket_pack(site, ["chaser"])
	var enemy = site.pack[0]
	for actor in [ball, enemy]:
		var query := PhysicsRayQueryParameters3D.create(start, end, actor.collision_mask)
		var actor_hit: Dictionary = site.get_world_3d().direct_space_state.intersect_ray(query)
		t.check("entered block collides with " + actor.get_class(), not actor_hit.is_empty() and interior.is_ancestor_of(actor_hit.get("collider")))
	ball.global_position = site.global_position + Vector3(50, 1, 0)
	acts._physics_process(0.0)
	acts._physics_process(0.0)
	t.eq("collision persists and activates only once", _bodies(interior), 2)
	t.eq("activation preserves the visible terrain", _meshes(interior), 4)
	acts.clear()
	await physics_frame
	t.check("stage clear removes activated terrain", not is_instance_valid(site))
	game.free()
	quit(t.verdict())

func _ray(site: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	return site.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1))

func _bodies(node: Node) -> int:
	var count := 1 if node is PhysicsBody3D else 0
	for child in node.get_children():
		count += _bodies(child)
	return count

func _meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D and node.visible else 0
	for child in node.get_children():
		count += _meshes(child)
	return count
