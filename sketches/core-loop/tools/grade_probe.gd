extends SceneTree
# (PLAYER-FX.md, the capture note; Godot prints that volumetric fog needs Forward+). The numbers
const Game := preload("res://src/game.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const ThreatGrammar := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const AppShell := preload("res://src/core/app_shell.gd")
const SIZE := Vector2i(1000, 600)
const CELL := 200
const GRID_LAYER := 1 << 19
const GAP := 20.0
const GROUND := {"sand": Palette.SAND, "sandstone": Palette.SANDSTONE, "charcoal": Palette.CHARCOAL,
	"ledger": Palette.LEDGER, "verdigris": Palette.VERDIGRIS}
const MEANING := {"hazard": Palette.HAZARD, "arc": Palette.ARC, "brass": Palette.BRASS,
	"amber": Palette.AMBER, "slate": Palette.SLATE}
const PAIRS := [["hazard", "amber"], ["hazard", "brass"], ["slate", "hazard"], ["slate", "arc"], ["amber", "arc"]]
var out := ""
var gate := false
var stills := ""
var game
var cam: Camera3D
var grid: Node3D
var cells := {}
var report := {}
var red := []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a == "--gate":
			gate = true
		elif a.begins_with("--stills="):
			stills = a.trim_prefix("--stills=")
	if AppShell.headless() or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


static func places(stages) -> Array:
	var result := []
	for stage in range(1, stages.COUNT + 1):
		result.append({"id": "stage%d-%s" % [stage, WorldLook.time_id(stage)], "stage": stage})
		var world: int = stages.world_of(stage)
		if stages.BOSS != "" and (stage == stages.COUNT or stages.world_of(stage + 1) != world):
			result.append({"id": "arena-w%d" % world, "boss": world})
	result.append({"id": "camp", "look": WorldLook.CAMP, "slot": "camp"})
	return result


static func gaps(seen: Dictionary) -> Dictionary:
	var result := {}
	for pair in PAIRS:
		result["edge:%s~%s" % pair] = DefenceBars.cie76(seen["edge_" + pair[0]], seen["edge_" + pair[1]])
	for ground in GROUND:
		result["fill:hazard~" + ground] = DefenceBars.cie76(seen["fill_" + ground], seen[ground])
		result["live~pending:" + ground] = lstar_step(seen["fill_" + ground], seen["live_" + ground])
	return result


static func lstar_step(pending: Color, live: Color) -> float:
	return DefenceBars._lab(pending).x - DefenceBars._lab(live).x


static func gated(pair: String) -> bool:
	return pair.begins_with("edge:")


static func fill() -> Color:
	var tone: Color = ThreatGrammar._area_tone({"tone": Palette.HAZARD}, ThreatGrammar.FILL_ALPHA)
	return tone if ThreatGrammar.haze() else Color(Palette.HAZARD, tone.a)


static func live_fill() -> Color:
	return ThreatGrammar.fill_tint({"type": ThreatGrammar.Type.INSTANT, "live": true, "tone": Palette.HAZARD})


static func band() -> Color:
	return Color(Palette.CHARCOAL, ThreatGrammar.UNDERLAY_ALPHA)


static func raw() -> Dictionary:
	var seen := {}
	var over := func(under: Color, top: Color) -> Color: return under.lerp(Color(top, 1.0), top.a)
	for id in GROUND:
		seen[id] = GROUND[id]
		seen["fill_" + id] = over.call(GROUND[id], fill())
		seen["live_" + id] = over.call(seen["fill_" + id], live_fill())
	var keyline: Color = over.call(Palette.SANDSTONE, band())
	for id in MEANING:
		seen["edge_" + id] = over.call(keyline, Color(MEANING[id], ThreatGrammar.EDGE_ALPHA))
	return gaps(seen)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	seed(171022)
	game = Game.new()
	game.test_mode = true
	game.table = Game.LAUNCH_TABLE
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(999999.0)
	_build_grid()
	DirAccess.make_dir_recursive_absolute(out)
	report = {"tool": "grade_probe.gd", "adapter": RenderingServer.get_video_adapter_name(),
		"table": Game.LAUNCH_TABLE, "telegraph": "haze" if ThreatGrammar.haze() else "classic",
		"gap": GAP, "raw": raw(), "places": []}
	for place in places(game.ctx.stages):
		var owner: Node3D = null
		if place.has("stage"):
			game.flow.enter_stage(place.stage, Vector3.ZERO, false)
			await _frames(40)
		elif place.has("boss"):
			game.flow.enter_boss(Vector3.ZERO)
			await _frames(90)
		else:
			owner = Node3D.new()
			root.add_child(owner)
			GraphicsPreset.enter_world(owner, game.ctx.terrain.environment, place.look, place.slot)
			await _frames(4)
		await _probe(place.id)
		if owner != null:
			owner.free()
	if not stills.is_empty():
		report["stills"] = _stills(stills)
	report["red"] = red
	var f := FileAccess.open(out.path_join("grade_probe.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	f.close()
	for line in red:
		print("RED ", line)
	quit(1 if gate and not red.is_empty() else 0)


func _build_grid() -> void:
	grid = Node3D.new()
	grid.top_level = true
	root.add_child(grid)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(SIZE.y) / CELL
	cam.far = 400.0
	cam.cull_mask = GRID_LAYER
	grid.add_child(cam)
	var column := 0
	for id in GROUND:
		cells[id] = _plate(GROUND[id], 1.0, false, Vector2(column, 0), 0)
		_plate(GROUND[id], 1.0, false, Vector2(column, 1), 0)
		cells["fill_" + id] = _plate(fill(), fill().a, true, Vector2(column, 1), 1)
		cells["live_" + id] = _plate(live_fill(), live_fill().a, true, Vector2(column + 0.2, 1.2), 2, 0.15)
		column += 1
	column = 0
	for id in MEANING:
		_plate(Palette.SANDSTONE, 1.0, false, Vector2(column, 2), 0)
		_plate(band(), band().a, true, Vector2(column, 2), 1, 0.75)
		cells["edge_" + id] = _plate(MEANING[id], ThreatGrammar.EDGE_ALPHA, true, Vector2(column, 2), 2)
		column += 1


func _plate(colour: Color, alpha: float, unshaded: bool, at: Vector2, layer: int, size := 0.0) -> Vector2i:
	var mesh := PlaneMesh.new()
	var side := size if size > 0.0 else (0.9 if layer == 0 else 0.6)
	mesh.size = Vector2(side, side)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(colour, alpha)
	mat.roughness = 1.0
	mat.disable_receive_shadows = true
	mat.render_priority = layer
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plate := MeshInstance3D.new()
	plate.mesh = mesh
	plate.material_override = mat
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.layers = GRID_LAYER
	plate.position = Vector3(at.x + 0.5, 0.01 * layer, at.y + 0.5)
	grid.add_child(plate)
	return Vector2i(int((at.x + 0.5) * CELL), int((at.y + 0.5) * CELL))


func _probe(id: String) -> void:
	game.player.body().freeze = true
	var ball: Vector3 = game.player.ball_position()
	var game_cam: Camera3D = root.get_camera_3d()
	var reach: float = game_cam.global_position.distance_to(ball) if game_cam != null and game_cam != cam else 8.0
	grid.global_position = ball + Vector3(2.0, 0.0, 2.0)
	cam.global_position = grid.global_position + Vector3(float(SIZE.x) / CELL * 0.5, reach, float(SIZE.y) / CELL * 0.5)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cam.current = true
	paused = true
	var shown: Array = root.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.visible)
	for n in shown:
		n.visible = false
	var lights: Array = root.find_children("*", "Light3D", true, false)
	for light in lights:
		light.layers |= GRID_LAYER
	for i in 8:
		await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(id + ".png"))
	for light in lights:
		if is_instance_valid(light):
			light.layers &= ~GRID_LAYER
	for n in shown:
		n.visible = true
	cam.current = false
	if game_cam != null and game_cam != cam:
		game_cam.current = true
	paused = false
	game.player.body().freeze = false
	var env: Environment = game.ctx.terrain.environment
	var seen := {}
	for cell in cells:
		seen[cell] = _sample(image, cells[cell])
	var pairs := gaps(seen)
	var row := {"id": id, "camera_reach": reach, "exposure": env.tonemap_exposure,
		"saturation": env.adjustment_saturation, "agx_contrast": env.tonemap_agx_contrast, "seen": {}, "gaps": pairs}
	for cell in seen:
		row.seen[cell] = seen[cell].to_html(false)
	for pair in pairs:
		if gated(pair) and pairs[pair] < GAP:
			red.append("%s %s %.1f" % [id, pair, pairs[pair]])
	report.places.append(row)
	print("place %s hazard~amber %.1f fill~sandstone %.1f live~pending:sandstone %.1f reach %.1f" % [id, pairs["edge:hazard~amber"], pairs["fill:hazard~sandstone"], pairs["live~pending:sandstone"], reach])


static func _sample(image: Image, at: Vector2i) -> Color:
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(-10, 11):
		for x in range(-10, 11):
			sum += image.get_pixel(at.x + x, at.y + y)
			n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n)


static func _stills(dir: String) -> Array:
	var rows := []
	var names := Array(DirAccess.get_files_at(dir)).filter(func(n): return n.ends_with(".png"))
	names.sort()
	for name in names:
		var image := Image.load_from_file(dir.path_join(name))
		if image == null:
			continue
		image.convert(Image.FORMAT_RGB8)
		var total := 0.0
		var white := 0
		var black := 0
		var n := 0
		for y in range(0, image.get_height(), 4):
			for x in range(0, image.get_width(), 4):
				var c := image.get_pixel(x, y)
				total += DefenceBars._lab(c).x
				white += 1 if maxf(c.r, maxf(c.g, c.b)) >= 1.0 else 0
				black += 1 if minf(c.r, minf(c.g, c.b)) <= 0.0 else 0
				n += 1
		rows.append({"still": name, "mean_l": total / n, "channel_at_255": float(white) / n, "channel_at_0": float(black) / n})
	return rows
