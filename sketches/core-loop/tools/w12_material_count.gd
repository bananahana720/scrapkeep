extends SceneTree
const Game := preload("res://src/game.gd")
const NAMES := {1: "Spillway", 4: "Dig deep", 5: "Highdraft"}
var game


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _count(root: Node) -> int:
	var seen := {}
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		var geo := node as GeometryInstance3D
		if not geo.is_visible_in_tree():
			continue
		if geo.material_override != null:
			seen[geo.material_override.get_instance_id()] = true
			continue
		if geo is MeshInstance3D and (geo as MeshInstance3D).mesh != null:
			var view := geo as MeshInstance3D
			for i in view.mesh.get_surface_count():
				var mat := view.get_active_material(i)
				if mat != null:
					seen[mat.get_instance_id()] = true
		elif geo is MultiMeshInstance3D and (geo as MultiMeshInstance3D).multimesh != null and (geo as MultiMeshInstance3D).multimesh.mesh != null:
			var mesh := (geo as MultiMeshInstance3D).multimesh.mesh
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				if mat != null:
					seen[mat.get_instance_id()] = true
	return seen.size()


func _run() -> void:
	var stages := [1, 4, 5]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stages="):
			stages = Array(a.trim_prefix("--stages=").split(",")).map(func(s): return int(s))
	seed(280928)
	game = Game.new()
	game.name = "Game"
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(60)
	for stage in stages:
		if stage != 1:
			game.flow.enter_stage(stage, Vector3.ZERO, false)
			await _frames(40)
		var stage_root: Node = game.ctx.terrain.geometry_root(stage)
		print("materials stage=%d name=%s stage_root=%d whole_tree=%d" % [stage, NAMES.get(stage, "?"), _count(stage_root), _count(root)])
	quit(0)
