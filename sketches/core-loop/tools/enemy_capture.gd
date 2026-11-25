extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")


const SIZE := Vector2i(800, 600)
const KINDS := ["chaser", "lobber", "catch_trap", "deflector", "plated_brute", "mag_trapper", "swatter", "netcaster", "foreman", "miniboss"]

var game
var out := ""
var kinds: Array = KINDS
var camera: Camera3D
var records := []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _run() -> void:
	seed(280928)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 60:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.fov = 40.0
	var terrain = game.ctx.terrain
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	game.player.reset_to(base + Vector3(0, 0, -30))
	for i in kinds.size():
		var at: Vector3 = terrain.drop_point(base.x + i * 9.0, base.z, 1.2)
		var enemy = game.ctx.spawner.spawn_enemy(kinds[i], at)
		await process_frame
		await process_frame
		paused = true
		enemy.global_position = at
		var dressed := 0
		for view: MeshInstance3D in enemy.find_children("*", "MeshInstance3D", true, false):
			for s in (view.mesh.get_surface_count() if view.mesh != null else 0):
				var mat := view.get_active_material(s)
				if mat != null and (mat.get_meta("bake_look", false) or mat.get_meta("bake_smooth", false)):
					dressed += 1
		var centre: Vector3 = at + Vector3.UP * 1.0
		camera.look_at_from_position(centre + Vector3(3.2, 1.6, 4.2), centre)
		for f in 8:
			await RenderingServer.frame_post_draw
		var path := out.path_join(kinds[i] + ".png")
		if root.get_texture().get_image().save_png(path) != OK:
			quit(3)
		records.append({"kind": kinds[i], "dressed_surfaces": dressed})
		enemy.queue_free()
		paused = false
		await process_frame
	var file := FileAccess.open(out.path_join("frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [SIZE.x, SIZE.y], "frames": records}, "\t"))
	quit()
