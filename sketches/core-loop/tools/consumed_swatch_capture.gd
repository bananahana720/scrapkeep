extends SceneTree
# The consumed purple across the run's day (L-W19-consumed): one frame per stage time (dawn to
# dusk, each on its stage's park world row), then the Waking pit row and the Mind arena row. Each
# frame holds four balls on a grey floor: the true purple unlit (the target), the purple as a plain
# lit surface (the sun tints it), the purple as WorldLook.consumed_material dresses it, and a lilac
# life colour for the band it must stay apart from. Writes <out>/<n>-<look>.png and sheet.png.
# Needs a display (Xvfb with the opengl3 driver works):
#   godot --path sketches/core-loop --rendering-driver opengl3 --resolution 960x540 --script res://tools/consumed_swatch_capture.gd -- --out=<dir>
# Evidence limit: colour only, on the compatibility renderer; the 3060 bench has the last word.
const Model := preload("res://tests/consumed_light_test.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SIZE := Vector2i(960, 540)
const LIFE := Color("b89ad6")
var out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


func _looks() -> Array:
	var result := []
	for stage in range(1, 7):
		var world := ParkDefs.world_of(stage)
		result.append({"id": "stage%d-%s-w%d" % [stage, WorldLook.time_id(stage), world], "look": WorldLook.stage_look(stage, world, String(ParkDefs.of(stage).get("map", "")))})
	result.append({"id": "arena-waking", "look": WorldLook.ARENAS.waking})
	result.append({"id": "arena-mind", "look": WorldLook.ARENAS.mind})
	return result


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "SkyFill"
	root.add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(40, 40)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color("8a8a86")
	floor_mesh.material_override = grey
	root.add_child(floor_mesh)
	var unlit := StandardMaterial3D.new()
	unlit.albedo_color = Model.CONSUMED
	unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bare := StandardMaterial3D.new()
	bare.albedo_color = Model.CONSUMED
	var life := StandardMaterial3D.new()
	life.albedo_color = LIFE
	var mats := [unlit, bare, WorldLook.consumed_material(Model.CONSUMED), life]
	for i in mats.size():
		var ball := MeshInstance3D.new()
		ball.mesh = SphereMesh.new()
		ball.material_override = mats[i]
		ball.position = Vector3(-4.5 + i * 3.0, 1.0, 0.0)
		root.add_child(ball)
	var cam := Camera3D.new()
	root.add_child(cam)
	var shots := []
	var n := 0
	for entry in _looks():
		var look: Dictionary = entry.look
		var e := Environment.new()
		for key in WorldLook.environment(look, false):
			e.set(key, WorldLook.environment(look, false)[key])
		e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.environment = e
		for row in WorldLook.lights(look, sun) + WorldLook.sky_rows(look):
			for key in row.values:
				row.object.set(key, row.values[key])
		sun.visible = true  # the Waking hides its sun in game; here the row's sun stands in for its key
		fill.visible = true
		cam.position = Vector3(0.0, 2.2, 6.0)
		cam.look_at(Vector3(0.0, 1.0, 0.0))
		cam.current = true
		for i in 10:
			await RenderingServer.frame_post_draw
		n += 1
		var img := root.get_texture().get_image()
		img.save_png(out.path_join("%d-%s.png" % [n, entry.id]))
		shots.append(img)
		print("snap ", entry.id)
	var sheet := Image.create(SIZE.x * 2, SIZE.y * 4, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, SIZE), Vector2i((i % 2) * SIZE.x, (i / 2) * SIZE.y))
	sheet.save_png(out.path_join("sheet.png"))
	quit(0)
