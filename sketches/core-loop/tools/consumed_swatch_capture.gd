extends SceneTree
# The consumed purple across the run's day (L-W19-consumed): one frame per stage time (dawn to
# dusk, each on its stage's park world row), then the Waking pit row and the Mind arena row, under the game's AgX tonemap and glow. Each
# frame holds four balls on a grey floor: the true purple unlit (the target), the purple as a plain
# lit surface (the sun tints it), the purple as WorldLook.consumed_material dresses it, and a lilac
# life colour for the band it must stay apart from. Writes <out>/<n>-<look>.png, sheet.png and
# hues.json, the on-screen median hue and saturation of each ball's centre patch.
# Needs a display (Xvfb with the opengl3 driver works):
#   godot --path sketches/core-loop --rendering-driver opengl3 --resolution 960x540 --script res://tools/consumed_swatch_capture.gd -- --out=<dir>
# Evidence limit: colour only, on the compatibility renderer; the 3060 bench has the last word.
const Model := preload("res://tests/consumed_light_test.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const SIZE := Vector2i(960, 540)
const LIFE := Color("b89ad6")
const BALLS := ["true", "sun_tinted", "held", "life"]
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
	var reads := []
	var n := 0
	for entry in _looks():
		var look: Dictionary = entry.look
		var e := Environment.new()
		for key in WorldLook.environment(look, false):
			e.set(key, WorldLook.environment(look, false)[key])
		# The game's tonemap and glow (graphics_preset.gd), so the on-screen hue includes AgX's compression.
		e.tonemap_mode = Environment.TONE_MAPPER_AGX
		e.tonemap_agx_white = 16.29
		e.tonemap_agx_contrast = 1.25
		e.glow_enabled = true
		e.glow_intensity = 0.18
		e.glow_hdr_threshold = 1.5
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
		var read := {"id": entry.id}
		for i in BALLS.size():
			read[BALLS[i]] = _disc_hue(img, cam.unproject_position(Vector3(-4.5 + i * 3.0, 1.0, 0.0)))
		reads.append(read)
		print("snap %s %s" % [entry.id, JSON.stringify(read)])
	var sheet := Image.create(SIZE.x * 2, SIZE.y * 4, false, shots[0].get_format())
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, SIZE), Vector2i((i % 2) * SIZE.x, (i / 2) * SIZE.y))
	sheet.save_png(out.path_join("sheet.png"))
	var f := FileAccess.open(out.path_join("hues.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"tool": "consumed_swatch_capture.gd", "adapter": RenderingServer.get_video_adapter_name(), "reads": reads}, "\t"))
	f.close()
	quit(0)


# The on-screen hue of a ball: the median hue and saturation over a 9 x 9 pixel patch at its centre,
# with the darkest and brightest hue spread across the patch. {hue, sat, lo, hi}.
func _disc_hue(img: Image, at: Vector2) -> Dictionary:
	var hues := []
	var sats := []
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var c := img.get_pixel(clampi(int(at.x) + dx * 3, 0, SIZE.x - 1), clampi(int(at.y) + dy * 3, 0, SIZE.y - 1))
			hues.append(c.h * 360.0)
			sats.append(c.s)
	hues.sort()
	sats.sort()
	return {"hue": snappedf(hues[hues.size() / 2], 0.1), "sat": snappedf(sats[sats.size() / 2], 0.001),
		"lo": snappedf(hues[0], 0.1), "hi": snappedf(hues[-1], 0.1)}
