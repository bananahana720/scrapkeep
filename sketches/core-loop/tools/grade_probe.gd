extends SceneTree
# What the post grade does to the colours that must read (G2, Grading lane, wave 18). The probe
# boots the game on the launch table (game.gd LAUNCH_TABLE), enters every stage and reads the
# environment and sun the stage left, then enters each arena row and the camp row over the last
# stage through GraphicsPreset.enter_world, as the arena dresses and camp_hub.gd do. Under each look
# it renders the Bible ground colours as lit plates and the meaning colours as unshaded swatches
# (telegraphs are unshaded, threat_grammar.gd) in its own world, reads the pixels back, and reports
# the graded colours and their CIE76 gaps. Needs a display:
#   godot --path sketches/core-loop --resolution 1000x400 --script res://tools/grade_probe.gd -- --out=<dir> [--gate]
# Writes <out>/grade_probe.json and <out>/<look>.png. --gate exits 1 when a graded HAZARD sits
# within GAP CIE76 of graded AMBER or BRASS, or of a graded ground plate, on any look.
#   --stills=<dir> also reports, for every PNG there (day_arc_capture.gd output), mean L* and the
#   share of pixels at L* 97 and up (clipped toward white) and at L* 8 and down (crushed).
# Evidence limit: llvmpipe GL Compatibility draws no glow; the numbers that count come from the
# PC render bench (Forward+). Frame cost is not measured here.
const Game := preload("res://src/game.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const SIZE := Vector2i(1000, 400)
# beacon_colour_test.gd's floor between a colour and the live or hazard colour.
const GAP := 20.0
const GROUND := {"sand": Palette.SAND, "sandstone": Palette.SANDSTONE, "charcoal": Palette.CHARCOAL,
	"ledger": Palette.LEDGER, "verdigris": Palette.VERDIGRIS}
const MEANING := {"hazard": Palette.HAZARD, "arc": Palette.ARC, "brass": Palette.BRASS,
	"amber": Palette.AMBER, "slate": Palette.SLATE}
const CELL := 200
var out := ""
var gate := false
var stills := ""
var game
var view: SubViewport
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var world: WorldEnvironment
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
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	_run.call_deferred()


# The probed looks: every stage of the table at its time of day, then the arena rows and the camp.
static func looks(stages) -> Array:
	var result := []
	for stage in range(1, stages.COUNT + 1):
		result.append({"id": "stage%d-%s" % [stage, WorldLook.time_id(stage)], "stage": stage})
	for arena in WorldLook.ARENAS:
		result.append({"id": "arena-" + arena, "look": WorldLook.ARENAS[arena], "slot": "arena"})
	result.append({"id": "camp", "look": WorldLook.CAMP, "slot": "camp"})
	return result


# The gaps one look's graded colours leave, as {pair: CIE76}.
static func gaps(seen: Dictionary) -> Dictionary:
	var result := {}
	for warm in ["amber", "brass"]:
		result["hazard~" + warm] = DefenceBars.cie76(seen.hazard, seen[warm])
	for ground in GROUND:
		result["hazard~" + ground] = DefenceBars.cie76(seen.hazard, seen[ground])
		result["arc~" + ground] = DefenceBars.cie76(seen.arc, seen[ground])
	return result


# The pairs --gate holds to GAP: HAZARD against the warm meaning colours and every ground.
static func gated(pair: String) -> bool:
	return pair.begins_with("hazard~")


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
	_build_view()
	DirAccess.make_dir_recursive_absolute(out)
	report = {"tool": "grade_probe.gd", "adapter": RenderingServer.get_video_adapter_name(),
		"table": Game.LAUNCH_TABLE, "gap": GAP, "raw": _raw(), "looks": []}
	var env: Environment = game.ctx.terrain.environment
	for entry in looks(game.ctx.stages):
		var owner: Node3D = null
		if entry.has("stage"):
			game.flow.enter_stage(entry.stage, Vector3.ZERO, false)
			await _frames(40)
		else:
			owner = Node3D.new()
			root.add_child(owner)
			GraphicsPreset.enter_world(owner, env, entry.look, entry.slot)
		await _probe(entry.id, env)
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


# The probe's own small world: an orthographic camera over the plates, lit by copies of the game's
# sun and sky fill, under the game's environment resource.
func _build_view() -> void:
	view = SubViewport.new()
	view.size = SIZE
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	world = WorldEnvironment.new()
	view.add_child(world)
	sun = DirectionalLight3D.new()
	fill = DirectionalLight3D.new()
	view.add_child(sun)
	view.add_child(fill)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(SIZE.y) / CELL
	cam.position = Vector3(float(SIZE.x) / CELL * 0.5, 10.0, float(SIZE.y) / CELL * 0.5)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	view.add_child(cam)
	cam.current = true
	var column := 0
	for id in GROUND:
		cells[id] = _plate(view, GROUND[id], false, Vector2(column, 0))
		column += 1
	column = 0
	for id in MEANING:
		cells[id] = _plate(view, MEANING[id], true, Vector2(column, 1))
		column += 1


func _copy_light(from: DirectionalLight3D, to: DirectionalLight3D) -> void:
	to.visible = from != null and from.visible
	if from == null:
		return
	to.light_color = from.light_color
	to.light_energy = from.light_energy
	to.light_specular = from.light_specular
	to.global_basis = from.global_basis
	to.shadow_enabled = false


func _probe(id: String, env: Environment) -> void:
	var game_sun: DirectionalLight3D = null
	for bound in GraphicsPreset._worlds:
		if bound.environment == env:
			game_sun = bound.sun.get_ref()
	_copy_light(game_sun, sun)
	_copy_light(game_sun.get_parent().get_node_or_null("SkyFill") if game_sun != null else null, fill)
	world.environment = env
	for i in 8:
		await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	image.save_png(out.path_join(id + ".png"))
	var seen := {}
	for cell in cells:
		seen[cell] = _sample(image, cells[cell])
	var pairs := gaps(seen)
	var row := {"id": id, "exposure": env.tonemap_exposure, "saturation": env.adjustment_saturation,
		"agx_contrast": env.tonemap_agx_contrast, "sun": sun.light_color.to_html(false) if sun.visible else "",
		"sun_energy": sun.light_energy if sun.visible else 0.0, "seen": {}, "gaps": pairs}
	for cell in seen:
		row.seen[cell] = seen[cell].to_html(false)
	for pair in pairs:
		if gated(pair) and pairs[pair] < GAP:
			red.append("%s %s %.1f" % [id, pair, pairs[pair]])
	report.looks.append(row)
	print("look %s hazard~amber %.1f hazard~brass %.1f" % [id, pairs["hazard~amber"], pairs["hazard~brass"]])


# The ungraded gaps, so a reader sees what the grade added or took away.
static func _raw() -> Dictionary:
	var seen := {}
	for id in GROUND:
		seen[id] = GROUND[id]
	for id in MEANING:
		seen[id] = MEANING[id]
	return gaps(seen)


func _plate(parent: Node, colour: Color, unshaded: bool, at: Vector2) -> Vector2i:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.9, 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var plate := MeshInstance3D.new()
	plate.mesh = mesh
	plate.material_override = mat
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.position = Vector3(at.x + 0.5, 0.0, at.y + 0.5)
	parent.add_child(plate)
	return Vector2i(int((at.x + 0.5) * CELL), int((at.y + 0.5) * CELL))


# The mean of a 21 px square at a cell's centre.
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
		var total := 0.0
		var bright := 0
		var dark := 0
		var n := 0
		var step := 4
		for y in range(0, image.get_height(), step):
			for x in range(0, image.get_width(), step):
				var l := DefenceBars._lab(image.get_pixel(x, y)).x
				total += l
				bright += 1 if l >= 97.0 else 0
				dark += 1 if l <= 8.0 else 0
				n += 1
		rows.append({"still": name, "mean_l": total / n, "clipped": float(bright) / n, "crushed": float(dark) / n})
	return rows
