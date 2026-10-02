extends SceneTree

const Game := preload("res://src/game.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const Dressing := preload("res://src/presentation/set_dressing.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Intent := preload("res://src/movement/intent.gd")
var failed := false

func check(ok: bool, what: String) -> void:
	failed = failed or not ok
	print(what, " -> ", "PASS" if ok else "FAIL")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Preset.apply("high")
	var game := Game.new()
	game.test_mode = true
	game.table = "default"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.source = Intent.Scripted.new()
	for i in 120:
		await physics_frame
	paused = true
	var original_nodes := _node_count(game)
	check(game.find_children("TargetSetDressing", "", true, false).is_empty(), "high has zero dressing and air nodes")
	Preset.apply("low")
	check(_node_count(game) == original_nodes and game.find_children("TargetSetDressing", "", true, false).is_empty(), "low has identical node count and zero dressing/air")
	Preset.apply("target")
	var dressing = game.presentation.set_dressing
	check(dressing != null and dressing.map_id == "spillway" and dressing.seed_value == "spillway".hash(), "target dressing seeded from map id")
	check(dressing.find_children("*", "MultiMeshInstance3D", true, false).size() == 6, "target has four prop batches and two air batches")
	check(dressing.find_children("*", "CollisionObject3D", true, false).is_empty() and dressing.find_children("*", "CollisionShape3D", true, false).is_empty(), "all dressing and air have no collision")
	var snapshot := _snapshot(dressing)
	var ground: Callable = game.ctx.terrain.ground_callable(1)
	var small_count := 0
	var maximum := -INF
	var large_count := 0
	for batch: MultiMeshInstance3D in dressing.batches:
		var multi := batch.multimesh
		check(batch.get_meta("instance_buffer").size() == multi.instance_count * 16, "exact submitted instance buffer covers every placement")
		check(batch.material_override.shader.get_shader_uniform_list().any(func(row): return row.name == "protected_count"), "engine parses dressing/air shader and protection include")
		check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "dressing cannot change gameplay shadows: " + String(batch.name))
		if batch.name in ["Pebbles", "ScrapFlakes", "SandTufts"]:
			for i in multi.instance_count:
				var tr := _instance(batch, i)
				for vertex in multi.mesh.get_faces():
					var point: Vector3 = tr * vertex
					maximum = maxf(maximum, point.y - (ground.call(point.x, point.z, 0.0) as Vector3).y)
				small_count += 1
		elif batch.name == "BrokenRock":
			for i in multi.instance_count:
				var tr := _instance(batch, i)
				var at := Vector2(tr.origin.x, tr.origin.z)
				check(not game.ctx.terrain.map().play_rect.grow(8.0).has_point(at) and _normal(ground, at).y < Tuning.MAX_SLOPE_DOT, "large rock on unclimbable ground outside playable apron")
				var low := Vector3(INF, INF, INF)
				var high := Vector3(-INF, -INF, -INF)
				for vertex in multi.mesh.get_faces():
					var point: Vector3 = tr * vertex
					low = low.min(point)
					high = high.max(point)
				var size := maxf(high.x - low.x, high.z - low.z)
				check(size >= 0.5 and size <= 2.0, "placed broken-rock extent in 0.5 to 2 m range")
				large_count += 1
		elif batch.name == "DustMotes":
			check(multi.instance_count == 160, "160 sparse motes")
			for i in multi.instance_count:
				check(-_instance(batch, i).origin.z < 30.0, "mote seeded in first 30 m ahead of camera")
		elif batch.name == "SandStreaks":
			check(multi.instance_count > 0, "open-ground sand streaks placed")
			for i in multi.instance_count:
				var tr := _instance(batch, i)
				check(tr.basis.x.normalized().dot(Vector3(Dressing.WIND.x, 0.0, Dressing.WIND.y).normalized()) > 0.999, "all streaks follow one wind direction")
	check(small_count > 500 and maximum <= 0.20001, "actual placed mesh vertices protrude at most 0.2 m above rollable ground")
	check(large_count > 0, "broken rocks exist on steep slopes")
	print("Placed ", small_count, " small props; highest actual protrusion ", maximum, " m; ", large_count, " broken rocks")
	Preset.apply("target")
	dressing = game.presentation.set_dressing
	check(_snapshot(dressing) == snapshot, "repeated preset produces identical seeded transforms, shades and phases")
	var cam: Camera3D = game.camera.cam
	cam.global_position = game.ctx.terrain.drop_point(-80, -101, 6.0)
	cam.look_at(game.ctx.terrain.drop_point(-80, -80, 1.0))
	var enemy = game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(-80, -80, 1.2))
	dressing._update_protection(cam)
	var protected: Array = dressing.batches[0].material_override.get_shader_parameter("protected_rects")
	var point := cam.unproject_position(enemy.global_position) / cam.get_viewport().get_visible_rect().size
	check(protected.any(func(rect): return point.x >= rect.x and point.y >= rect.y and point.x <= rect.z and point.y <= rect.w), "enemy feet are inside dressing/air screen exclusion")
	for batch in dressing.batches:
		check(batch.material_override.get_shader_parameter("protected_count") > 0, "every batch shares live gameplay exclusion")
	var shot_camera := Camera3D.new()
	game.add_child(shot_camera)
	shot_camera.global_transform = cam.global_transform.translated(Vector3(10, 3, 5))
	dressing.sync_camera(shot_camera)
	check(dressing._dust.global_transform == shot_camera.global_transform, "frozen capture camera refresh places motes at the active view")
	shot_camera.free()
	var crowd := []
	for i in 65:
		var actor := Node3D.new()
		game.add_child(actor)
		actor.global_position = enemy.global_position
		actor.add_to_group("enemy")
		crowd.append(actor)
	dressing.sync_camera(cam)
	check(not dressing.visible, "protection overflow hides all dressing and air")
	for actor in crowd:
		actor.free()
	dressing.sync_camera(cam)
	check(dressing.visible, "frozen camera refresh restores dressing after protection overflow clears")
	var tiny := Dressing.protection_rect(cam, cam.global_position + -cam.global_basis.z, 2.5)
	check(tiny == Vector4(0, 0, 1, 1), "near-camera overlap protects the entire screen")
	Preset.apply("high")
	# The enemy is the only deliberately added gameplay node in this test.
	enemy.free()
	check(game.find_children("TargetSetDressing", "", true, false).is_empty() and _node_count(game) == original_nodes, "target to high restores original node count")
	Preset.apply("target")
	Preset.apply("low")
	check(game.find_children("TargetSetDressing", "", true, false).is_empty() and _node_count(game) == original_nodes, "target to low restores original node count")
	game.free()
	Preset.apply("high")
	print("set_dressing_test: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _node_count(child)
	return count

func _snapshot(dressing: Node) -> Dictionary:
	var result := {}
	for batch: MultiMeshInstance3D in dressing.batches:
		result[batch.name] = batch.get_meta("instance_buffer")
	return result

func _normal(ground: Callable, at: Vector2) -> Vector3:
	var dx: float = (ground.call(at.x + 0.25, at.y, 0.0) as Vector3).y - (ground.call(at.x - 0.25, at.y, 0.0) as Vector3).y
	var dz: float = (ground.call(at.x, at.y + 0.25, 0.0) as Vector3).y - (ground.call(at.x, at.y - 0.25, 0.0) as Vector3).y
	return Vector3(-dx, 0.5, -dz).normalized()


func _instance(batch: MultiMeshInstance3D, index: int) -> Transform3D:
	var buffer: PackedFloat32Array = batch.get_meta("instance_buffer")
	var n := index * 16
	return Transform3D(Basis(Vector3(buffer[n], buffer[n + 4], buffer[n + 8]),
		Vector3(buffer[n + 1], buffer[n + 5], buffer[n + 9]),
		Vector3(buffer[n + 2], buffer[n + 6], buffer[n + 10])),
		Vector3(buffer[n + 3], buffer[n + 7], buffer[n + 11]))
