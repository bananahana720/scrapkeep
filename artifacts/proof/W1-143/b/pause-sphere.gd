extends SceneTree

const Game := preload("res://src/game.gd")
const Census := preload("res://tools/prim_census.gd")
var game


func _initialize() -> void:
	call_deferred("_run")


func _sample(tag: String) -> Dictionary:
	var pause = game.get_node("PauseMenu")
	var view = pause.find_child("BuildRead", true, false)
	var props := {}
	for geometry in view.find_children("*", "MeshInstance3D", true, false):
		if geometry.mesh is SphereMesh:
			var hidden := []
			var parent = geometry.get_parent()
			while parent != null:
				if parent is CanvasItem and not parent.is_visible_in_tree():
					hidden.append(String(parent.name))
				elif parent is CanvasLayer and not parent.visible:
					hidden.append(String(parent.name))
				parent = parent.get_parent()
			props = {"sphere_visible_in_3d": geometry.is_visible_in_tree(), "hidden_canvas_ancestors": hidden}
			break
	var has_sphere := func(row: Dictionary): return row.owner == "build_read.gd" and row.mesh == "SphereMesh"
	var sampled := {"moment": tag, "pause_open": pause.is_open(), "preview": props,
		"legacy_sphere_count": Census.new().scan(root, 30, 1).filter(has_sphere).size(),
		"station_sphere_count": Census.new().scan(pause, 30, 1, true).filter(has_sphere).size(),
		"has_fitted_core": view.find_child("HeroCore", true, false) != null}
	print("PAUSE_SPHERE ", JSON.stringify(sampled))
	return sampled


func _run() -> void:
	game = Game.new()
	game.table = "park"
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 30:
		await physics_frame
	var closed := _sample("on ride, before pause")
	var pause = game.get_node("PauseMenu")
	pause.open()
	await process_frame
	var opened := _sample("first open pause")
	pause.close()
	game.free()
	quit(0 if closed.legacy_sphere_count == 1 and closed.station_sphere_count == 0 and opened.pause_open
		and opened.has_fitted_core and opened.station_sphere_count == 0 else 1)
