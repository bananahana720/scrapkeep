extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AppShell := preload("res://src/core/app_shell.gd")


const SIZE := Vector2i(800, 600)
const KINDS := ["chaser", "lobber", "swatter", "hooker", "netcaster", "boom_tender"]
const VIEWS := [Vector3(0.55, 0.3, 0.75), Vector3(-0.6, 0.3, -0.7)]
const DIFFERS := 0.06
const NEAR_BLACK := 0.08
const FLOOR := 0.8
const DARK_MORE := 0.15
const MIN_PIXELS := 2000
const PLANTS := ["dark_models"]

var game
var plant := OS.get_environment("RENDER_PLANT")
var out := ""
var compare := ""
var kinds: Array = KINDS
var camera: Camera3D


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--kinds="):
			kinds = Array(arg.trim_prefix("--kinds=").split(","))
			for kind in kinds:
				if not kind in KINDS:
					printerr("model_render_check: unknown kind %s (known: %s)" % [kind, ", ".join(KINDS)])
					quit(2)
					return
		elif arg.begins_with("--compare="):
			compare = arg.trim_prefix("--compare=")
		elif arg != "--models=tripo-all":
			printerr("model_render_check: unknown option %s" % arg)
			quit(2)
			return
	if out.is_empty():
		printerr("model_render_check: --out=<absolute dir> is needed")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	if not compare.is_empty():
		quit(_compare())
		return
	if not plant.is_empty() and (not plant in PLANTS or not "--models=tripo-all" in OS.get_cmdline_user_args()):
		printerr("model_render_check: RENDER_PLANT=%s plants only in a --models=tripo-all shoot (known: %s)" % [plant, ", ".join(PLANTS)])
		quit(2)
		return
	if AppShell.headless():
		printerr("model_render_check: a shoot needs a display (headless gamescope on the PC)")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_shoot.call_deferred()


func _shoot() -> void:
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
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(camera)
	var terrain = game.ctx.terrain
	var base: Vector3 = terrain.drop_point(-65.0, -130.0, 0.0)
	game.player.reset_to(base + Vector3(0, 0, -60))
	var stats := {}
	var files := {}
	var blind := false
	for i in kinds.size():
		var at: Vector3 = terrain.drop_point(base.x + i * 14.0, base.z, 1.2)
		var enemy = game.ctx.spawner.spawn_enemy(kinds[i], at)
		await process_frame
		await process_frame
		paused = true
		enemy.global_position = at
		var model := model_parts(enemy)
		var code_built: Array = enemy.find_children("*", "GeometryInstance3D", true, false).filter(func(g): return not g in model)
		var authored_path := "res://assets/models/world_one/enemy_%s.glb" % kinds[i]
		var loaded_path := ModelVariants.path(authored_path)
		files[kinds[i]] = {"authored": authored_path, "path": loaded_path, "loaded": load(loaded_path) is PackedScene,
			"parts": model.map(func(g): return String(g.name))}
		if plant == "dark_models":
			var black := StandardMaterial3D.new()
			black.albedo_color = Color(0.02, 0.02, 0.02)
			black.roughness = 1.0
			for drawn: GeometryInstance3D in model:
				drawn.material_override = black
		var views: Array = enemy.find_children("*", "MeshInstance3D", true, false)
		var box := AABB()
		var first := true
		for view: MeshInstance3D in views:
			if view.mesh == null or not view.is_visible_in_tree():
				continue
			var part: AABB = view.global_transform * view.mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		var centre := box.get_center()
		var reach := maxf(box.size.length() * 0.5, 0.5)
		stats[kinds[i]] = []
		for v in VIEWS.size():
			camera.look_at_from_position(centre + (VIEWS[v] as Vector3).normalized() * reach * 3.4, centre)
			enemy.visible = false
			var ground := await _still()
			enemy.visible = true
			for drawn: GeometryInstance3D in code_built:
				drawn.visible = false
			var shadows := {}
			for drawn: GeometryInstance3D in enemy.find_children("*", "GeometryInstance3D", true, false):
				shadows[drawn] = drawn.cast_shadow
				drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var bare := await _still()
			for drawn: GeometryInstance3D in shadows:
				drawn.cast_shadow = shadows[drawn]
			var lit := await _still()
			for drawn: GeometryInstance3D in code_built:
				drawn.visible = true
			var row := _measure(ground, bare, lit)
			blind = blind or int(row["pixels"]) < MIN_PIXELS
			stats[kinds[i]].append(row)
			if lit.save_png(out.path_join("%s_%d.png" % [kinds[i], v])) != OK:
				quit(3)
				return
			print("%s view %d: brightness %.3f, near-black %.3f, %d pixels" % [kinds[i], v, row["brightness"], row["near_black"], row["pixels"]])
		enemy.queue_free()
		paused = false
		await process_frame
	var file := FileAccess.open(out.path_join("stats.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [SIZE.x, SIZE.y], "models": "tripo-all" if "--models=tripo-all" in OS.get_cmdline_user_args() else "authored", "plant": plant, "files": files, "kinds": stats}, "\t"))
	file.close()
	if blind:
		printerr("model_render_check: a kind drew under %d pixels, so nothing was judged" % MIN_PIXELS)
	quit(2 if blind else 0)


func _still() -> Image:
	for f in 6:
		await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _measure(ground: Image, bare: Image, lit: Image) -> Dictionary:
	var pixels := 0
	var sum := 0.0
	var dark := 0
	var tint := Vector3.ZERO
	for y in ground.get_height():
		for x in ground.get_width():
			var g := ground.get_pixel(x, y)
			var b := bare.get_pixel(x, y)
			if maxf(absf(g.r - b.r), maxf(absf(g.g - b.g), absf(g.b - b.b))) < DIFFERS:
				continue
			var c := lit.get_pixel(x, y)
			var luma := c.get_luminance()
			pixels += 1
			sum += luma
			dark += 1 if luma < NEAR_BLACK else 0
			tint += Vector3(c.r, c.g, c.b)
	var n := maxf(pixels, 1.0)
	return {"pixels": pixels, "brightness": sum / n, "near_black": dark / n, "tint": [tint.x / n, tint.y / n, tint.z / n]}


func _read(dir: String) -> Dictionary:
	var file := FileAccess.open(dir.path_join("stats.json"), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func model_parts(enemy: Node) -> Array:
	var out := []
	for drawn: GeometryInstance3D in enemy.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		if drawn is MeshInstance3D:
			mesh = (drawn as MeshInstance3D).mesh
		elif drawn is MultiMeshInstance3D and (drawn as MultiMeshInstance3D).multimesh != null:
			mesh = (drawn as MultiMeshInstance3D).multimesh.mesh
		if mesh != null and not mesh is PrimitiveMesh:
			out.append(drawn)
	return out


static func judge(authored: Dictionary, tripo: Dictionary) -> Dictionary:
	var out := {"error": "", "judged": 0, "failed": [], "missing": [], "lines": []}
	if authored.get("models", "") != "authored" or tripo.get("models", "") != "tripo-all":
		out.error = "the first folder must be an authored shoot and the second a --models=tripo-all shoot"
		return out
	for kind in authored.get("kinds", {}):
		if not tripo.get("kinds", {}).has(kind):
			continue
		var file: Dictionary = tripo.get("files", {}).get(kind, {})
		if file.is_empty() or not file.get("loaded", false) or file.get("path", "") == file.get("authored", ""):
			out.missing.append(kind)
			out.lines.append("FAIL %s: no generated model was loaded (%s)" % [kind, file.get("path", "no record")])
			continue
		var ok := true
		var notes := []
		for v in authored["kinds"][kind].size():
			var a: Dictionary = authored["kinds"][kind][v]
			var t: Dictionary = tripo["kinds"][kind][v]
			if int(a["pixels"]) < MIN_PIXELS or int(t["pixels"]) < MIN_PIXELS:
				out.error = "%s view %d drew too few pixels to judge" % [kind, v]
				return out
			var ratio: float = float(t["brightness"]) / maxf(float(a["brightness"]), 0.001)
			var more: float = float(t["near_black"]) - float(a["near_black"])
			ok = ok and ratio >= FLOOR and more <= DARK_MORE
			notes.append("view %d brightness %.2f of authored (%.3f, authored %.3f), near-black %.2f (authored %.2f)" % [v, ratio, t["brightness"], a["brightness"], t["near_black"], a["near_black"]])
		out.judged += 1
		if not ok:
			out.failed.append(kind)
		out.lines.append("%s %s: %s" % ["PASS" if ok else "FAIL", kind, "; ".join(notes)])
	if out.judged == 0 and out.missing.is_empty():
		out.error = "no kind is in both shoots"
	return out


func _compare() -> int:
	var dirs := compare.split(",")
	if dirs.size() != 2:
		printerr("model_render_check: --compare=<authored dir>,<tripo dir>")
		return 2
	var authored := _read(dirs[0])
	var tripo := _read(dirs[1])
	var verdict := judge(authored, tripo)
	if not String(verdict.error).is_empty():
		printerr("model_render_check: " + verdict.error)
		return 2
	for line in verdict.lines:
		print(line)
	for kind in authored["kinds"]:
		var left := Image.load_from_file(dirs[0].path_join("%s_0.png" % kind))
		var right := Image.load_from_file(dirs[1].path_join("%s_0.png" % kind))
		if left != null and right != null:
			var sheet := Image.create(left.get_width() + right.get_width(), left.get_height(), false, left.get_format())
			right.convert(left.get_format())
			sheet.blit_rect(left, Rect2i(Vector2i.ZERO, left.get_size()), Vector2i.ZERO)
			sheet.blit_rect(right, Rect2i(Vector2i.ZERO, right.get_size()), Vector2i(left.get_width(), 0))
			sheet.save_png(out.path_join("%s_authored_left_tripo_right.png" % kind))
	var planted: String = str(tripo.get("plant", "")) + str(authored.get("plant", ""))
	var bad: int = verdict.failed.size() + verdict.missing.size()
	print("SUMMARY " + JSON.stringify({"judged": verdict.judged, "pinned": KINDS.size(), "failed": verdict.failed, "missing": verdict.missing, "plant": planted}))
	print("model_render_check: %s (%d kinds judged, %d missing, at least %.2f of the authored brightness, at most %.2f more near-black)" % ["PASS" if bad == 0 else "FAIL (%d)" % bad, verdict.judged, verdict.missing.size(), FLOOR, DARK_MORE])
	return 1 if bad > 0 else 0
