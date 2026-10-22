extends SceneTree
# What the post grade does to the colours that must read (G2, Grading lane, wave 18). The probe
# boots the game on the launch table (game.gd LAUNCH_TABLE) and enters every stage, and after each
# world's last stage that world's boss arena (flow.enter_boss, so the arena dress lights it). In
# each place it lays a grid of plates beside the ball, in the game's own world and lights, and looks
# straight down from the live chase camera's distance to the ball, so fog, lamps and arena keys
# reach the plates as they reach the floor. The camp row is entered last through enter_world on
# the "camp" slot, as camp_hub.gd does, over the last place's lights.
#   row 0  the Bible ground colours, lit
#   row 1  the same grounds under a hostile fill as threat_grammar paints it (fill()): under the
#          default haze look HAZARD at FILL_ALPHA * HAZE_FILL; under classic the HAZARD stripe
#          of the striped fill, HAZARD at FILL_ALPHA (unshaded, alpha)
#   row 2  the meaning colours at EDGE_ALPHA over threat_grammar's charcoal under-band at
#          UNDERLAY_ALPHA, both unshaded, on lit sandstone
# It reads the pixels back and reports the graded colours and their CIE76 gaps. Needs a display:
#   godot --path sketches/core-loop --resolution 1000x600 --script res://tools/grade_probe.gd -- --out=<dir> [--gate]
# Writes <out>/grade_probe.json and <out>/<place>.png. --gate exits 1 when a gated pair falls
# under GAP on any place. GAP is beacon_colour_test.gd's floor between a colour and the live
# (ARC) or hazard colour; the probe holds its pairs (edges against edges) to it. The fill-over-
# ground gaps are reported, not gated: no ruling sets their floor.
#   --stills=<dir> also reports, for every PNG there (day_arc_capture.gd output), mean L* and the
#   share of pixels with a channel at 0 or at 255 in sRGB.
# Evidence limit: llvmpipe GL Compatibility shows colour, not Forward+ glow or volumetric air
# (PLAYER-FX.md, the capture note; Godot prints that volumetric fog needs Forward+). The numbers
# that count come from the PC render bench. Frame cost is not measured here.
const Game := preload("res://src/game.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const ThreatGrammar := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const SIZE := Vector2i(1000, 600)
const CELL := 200
# Visual layer 20, which no game node uses.
const GRID_LAYER := 1 << 19
const GAP := 20.0
const GROUND := {"sand": Palette.SAND, "sandstone": Palette.SANDSTONE, "charcoal": Palette.CHARCOAL,
	"ledger": Palette.LEDGER, "verdigris": Palette.VERDIGRIS}
const MEANING := {"hazard": Palette.HAZARD, "arc": Palette.ARC, "brass": Palette.BRASS,
	"amber": Palette.AMBER, "slate": Palette.SLATE}
# beacon_colour_test.gd's pairs (the state colours against live and hazard), and HAZARD against
# the warm meaning colours it must never be read as.
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
	if DisplayServer.get_name() == "headless" or out == "":
		printerr("needs a display and --out")
		quit(2)
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()


# The probed places, in run order: each stage at its time of day, the boss arena after its world's
# last stage when the table names a boss, then the camp.
static func places(stages) -> Array:
	var result := []
	for stage in range(1, stages.COUNT + 1):
		result.append({"id": "stage%d-%s" % [stage, WorldLook.time_id(stage)], "stage": stage})
		var world: int = stages.world_of(stage)
		if stages.BOSS != "" and (stage == stages.COUNT or stages.world_of(stage + 1) != world):
			result.append({"id": "arena-w%d" % world, "boss": world})
	result.append({"id": "camp", "look": WorldLook.CAMP, "slot": "camp"})
	return result


# The gaps one place's graded colours leave, as {pair: CIE76}. "edge:" pairs are meaning colours
# against each other; "fill:" pairs are a HAZARD fill against the ground it lies on.
static func gaps(seen: Dictionary) -> Dictionary:
	var result := {}
	for pair in PAIRS:
		result["edge:%s~%s" % pair] = DefenceBars.cie76(seen["edge_" + pair[0]], seen["edge_" + pair[1]])
	for ground in GROUND:
		result["fill:hazard~" + ground] = DefenceBars.cie76(seen["fill_" + ground], seen[ground])
	return result


static func gated(pair: String) -> bool:
	return pair.begins_with("edge:")


# A hostile area's fill as the painter tints it on the live telegraph look. Classic tints white
# over the HAZARD and charcoal stripe texture; its HAZARD stripe is HAZARD at the same alpha.
static func fill() -> Color:
	var tone: Color = ThreatGrammar._area_tone({"tone": Palette.HAZARD}, ThreatGrammar.FILL_ALPHA)
	return tone if ThreatGrammar.haze() else Color(Palette.HAZARD, tone.a)


# The keyline band under every line.
static func band() -> Color:
	return Color(Palette.CHARCOAL, ThreatGrammar.UNDERLAY_ALPHA)


# The same gaps with no grade or light: the palette as authored, alpha-mixed as the painter mixes.
static func raw() -> Dictionary:
	var seen := {}
	var over := func(under: Color, top: Color) -> Color: return under.lerp(Color(top, 1.0), top.a)
	for id in GROUND:
		seen[id] = GROUND[id]
		seen["fill_" + id] = over.call(GROUND[id], fill())
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


# The grid sits on its own visual layer and the probe camera sees only that layer, so a bump in
# the floor, a ring or a prop never cuts a cell. A camera's cull mask also culls lights by their
# layers, so _probe lends the grid layer to every light for the shot. Plates take no shadow, so a
# cell reads the place's light rather than whatever casts on that spot.
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
	# The live chase camera's distance to the ball; without one, the arm's rest length (chase_camera.gd).
	var reach: float = game_cam.global_position.distance_to(ball) if game_cam != null and game_cam != cam else 8.0
	# Beside the ball at its centre height, above the floor, clear of its body and shadow.
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
	print("place %s hazard~amber %.1f fill~sandstone %.1f reach %.1f" % [id, pairs["edge:hazard~amber"], pairs["fill:hazard~sandstone"], reach])


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
