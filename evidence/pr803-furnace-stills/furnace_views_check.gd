extends SceneTree
# Scratch check for PR 803 (not for the stage): the furnace column on the flume, seen from the drop-in and from the
# bend overlook. For each view it saves the still with the column and without it, marks the pixels the column changes,
# and casts a ray through every 4th such pixel. Terrain or a collider hit between PULL_M (520 m) and the 700 m far
# plane on that ray is ground the pulled-in column paints over, because the column is drawn at 520 m.
#
#   <godot> --path sketches/core-loop --script res://tools/furnace_views_check.gd -- --out=<abs dir>

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EYE_M := 4.0
const SETTLE_FRAMES := 90
const FAR := 700.0
const STEP := 4
const DIFF := 0.06

var game
var out := ""
var lines: PackedStringArray = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		print("furnace_views_check: needs --out=<dir> and a rendered display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.run.set_max_hp(999999.0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in SETTLE_FRAMES:
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = FAR
	root.add_child(camera)
	camera.make_current()
	var markers = game.presentation.site_markers
	var foot := Vector3.INF
	var height := 0.0
	for key in markers.views.keys():
		var view: MeshInstance3D = markers.views[key]
		if String(view.get_meta("kind")) == "furnace":
			foot = view.get_meta("at")
			height = float(markers.KINDS["furnace"]["height"])
	if foot == Vector3.INF:
		lines.append("NO_FURNACE on %s" % String(game.ctx.terrain.map().title))
		_finish()
		return
	var look := foot + Vector3.UP * height * 0.4
	var drop: Vector3 = game.ctx.player.ball_position()
	var terrain = game.ctx.terrain
	var bend := Vector3(150.0, terrain.height(150.0, -60.0) + EYE_M, -60.0)
	lines.append("FURNACE foot %s height %.0f" % [foot.snapped(Vector3.ONE * 0.1), height])
	await _view(camera, markers, "dropin", drop + Vector3.UP * EYE_M, look)
	await _view(camera, markers, "bend_overlook", bend, look)
	_finish()


func _finish() -> void:
	var f := FileAccess.open(out.path_join("check.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	for line in lines:
		print(line)
	game.free()
	quit(0)


func _grab(camera: Camera3D, markers, shown: bool) -> Image:
	markers.visible = shown
	for i in 6:
		await process_frame
	return root.get_texture().get_image()


func _view(camera: Camera3D, markers, label: String, eye: Vector3, look: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(look)
	var on: Image = await _grab(camera, markers, true)
	var off: Image = await _grab(camera, markers, false)
	var off2: Image = await _grab(camera, markers, false)
	var on2: Image = await _grab(camera, markers, true)
	markers.visible = true
	on.save_png(out.path_join(label + "_column.png"))
	off.save_png(out.path_join(label + "_control.png"))
	var mask := Image.create(on.get_width(), on.get_height(), false, Image.FORMAT_RGBA8)
	var column_px := 0
	var sampled := 0
	var bands := {"none": 0, "under_520": 0, "520_700": 0}
	var nearest := 1.0e9
	var space := root.get_world_3d().direct_space_state
	var terrain = game.ctx.terrain
	var size := Vector2(on.get_width(), on.get_height())
	var vp := Vector2(root.get_visible_rect().size)
	for y in range(0, on.get_height(), STEP):
		for x in range(0, on.get_width(), STEP):
			var a := on.get_pixel(x, y)
			var b := off.get_pixel(x, y)
			# The column's pixel: it changes with the column both times, and holds still between grabs of one state,
			# so dust, comic words and other moving things are left out.
			var a2 := on2.get_pixel(x, y)
			var b2 := off2.get_pixel(x, y)
			if _d(a, b) < DIFF or _d(a2, b2) < DIFF or _d(a, a2) > DIFF * 0.5 or _d(b, b2) > DIFF * 0.5:
				continue
			column_px += 1
			var screen := Vector2(x, y) * vp / size
			var origin := camera.project_ray_origin(screen)
			var dir := camera.project_ray_normal(screen)
			var hit := _first_hit(space, terrain, origin, dir)
			sampled += 1
			if hit > 0.0:
				nearest = minf(nearest, hit)
			var band := "none"
			if hit < 0.0:
				band = "none"
			elif hit <= 520.0:
				band = "under_520"
			else:
				band = "520_700"
			bands[band] += 1
			if hit > 0.0:
				lines.append("HIT %s px %d,%d %.0f m" % [label, x, y, hit])
			var c := Color(0.2, 0.9, 0.3) if band == "none" else (Color(1, 0.2, 0.1) if band == "520_700" else Color(0.2, 0.4, 1))
			for dy in STEP:
				for dx in STEP:
					if x + dx < mask.get_width() and y + dy < mask.get_height():
						mask.set_pixel(x + dx, y + dy, c)
	var overlay := on.duplicate()
	overlay.convert(Image.FORMAT_RGBA8)
	overlay.blend_rect(mask, Rect2i(Vector2i.ZERO, mask.get_size()), Vector2i.ZERO)
	overlay.save_png(out.path_join(label + "_mask.png"))
	var d := Vector2(eye.x - look.x, eye.z - look.z).length()
	lines.append("VIEW %s eye %s distance_to_column %.0f m column_px(step %d) %d sky_or_beyond_700 %d terrain_under_520 %d terrain_520_to_700 %d nearest_terrain_behind_column_px %.0f m" % [
		label, eye.snapped(Vector3.ONE * 0.1), d, STEP, column_px, bands["none"], bands["under_520"], bands["520_700"], nearest])


func _d(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


# Distance to the first ground or collider along the ray, inside FAR; -1 when none.
func _first_hit(space, terrain, origin: Vector3, dir: Vector3) -> float:
	var best := -1.0
	var ray := PhysicsRayQueryParameters3D.create(origin, origin + dir * FAR)
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		best = origin.distance_to(hit["position"])
	var t := 1.0
	while t < FAR and (best < 0.0 or t < best):
		var p := origin + dir * t
		if terrain.height(p.x, p.z) > p.y:
			return t
		t += 1.0
	return best
