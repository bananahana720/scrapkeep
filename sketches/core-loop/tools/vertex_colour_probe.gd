extends SceneTree

# How this machine's renderer draws vertex colours, and which of the game's materials that
# changes (design-v3/SIGHT-PERSONA.md section 7, "Colour on the PC and in the cloud").
#   <godot> --path sketches/core-loop --script res://tools/vertex_colour_probe.gd \
#     -- --out=/abs/dir [--boss=0] [--plant=1]
# A display is needed (xvfb-run with --rendering-driver opengl3 works in the cloud). The stills
# are the window's own size; the counts are of the still's pixels, so compare runs of one size.
#
# The question. A material that takes its colour from the mesh (vertex_color_use_as_albedo) has
# a second switch, vertex_color_is_srgb. The PC's renderer (Forward+) reads a vertex colour as
# linear light unless that switch is on; the cloud's (Compatibility) ignores the switch and
# draws the number as it stands. So a palette colour written straight into a mesh by code is
# right in the cloud and paler on the PC, and a cast from Blender, whose colours are stored
# linear (tools/blender/common.py), is right on the PC and darker in the cloud.
#
# What it writes.
#   swatches.png  Palette tones, one row each. Columns: the tone as a plain material colour (the
#                 reference); the tone written into the mesh, switch off; the same, switch on;
#                 the tone stored linear, switch off; the same, switch on. Then three tones
#                 added at half strength over a charcoal strip (how the glows and halos are
#                 drawn): plain, switch off, switch on.
#   Three scenes, the game held for each: `lineup` (the Spillway's fourteen kinds standing at
#   the dam), `marks` (the same, with the ball's own marks drawn by the game's own calls: a
#   bolt in each weapon colour, and a ring, an arc, a spark and a beam of its attacks) and
#   `arena` (Brindle's arena; not with --boss=0). For each scene:
#     <scene>-as-is.png            as the game draws it
#     <scene>-<family>.png         the switch turned on for one family of candidates (a script,
#                                  and the view's name where the game gave it one), kept only
#                                  where the picture changed
#     <scene>-srgb.png             the switch turned on for every candidate
#   probe.json    The swatches' measured colours against the palette; per scene the census
#                 (every material that takes vertex colour, grouped by its owner: the nearest
#                 script above it in the scene, so the cable arcs and the aura's motes list
#                 under game.gd and the ball's trail and speed lines under player_ball.gd;
#                 where its mesh came from, the switch, how far the switch would move its stored
#                 colours) and, for each family of candidates, how many pixels the switch changed
#                 and their mean colour before and after, beside the scene's `noise` (what
#                 changes between two stills with nothing switched).
#
# A candidate is a material with the switch off on a mesh built in code that carries colours
# (a mesh with none draws white whatever the switch says). A mesh loaded from a file, or copied
# from one (it keeps the importer's names or its shadow mesh), is a cast and is left alone. Meshes that code merges out of casts (the far props) land among the
# candidates, so the list is where to look, not a verdict: read the script that writes the
# colour. `nearest` says whether the stored colours sit nearer the palette as written or as
# linear; near white and near black the two agree and it says nothing.
#
# The census reads what stands in the scene at that moment; an effect that is built when it
# fires is counted only if one is up. `marks` puts the bolts and the attack lines up itself
# (probe.json's `marks_shots` is how many bolts were in the air for the still); the ball's
# trail, its aura and a cable's arcs show only if the game happens to be drawing them.
# While a scene is held the clock runs at a thousandth, so water and mist stand still and
# `noise` should be next to nothing.
# --plant=1 greys each script's candidates instead of turning the switch on, to show that the
# count sees a change on a renderer that ignores the switch.
#
# Where the seven code-drawn player marks set their colour (W46-03's hand-off to W46-13): every run
# writes `mark_sites` into probe.json, and --sites=1 prints them alone, headless, and quits:
#   <godot> --headless --path sketches/core-loop --script res://tools/vertex_colour_probe.gd -- --sites=1 [--out=/abs/dir]
# Each row names the file, the line that builds the mark's material and whether that material
# turns vertex_color_is_srgb on, the line that writes the colour into the mesh, and where the
# colour comes from. The lines are found by MARK_SITES' text, so they follow the code as it moves;
# a row whose text is gone says so (tests/world_look_acts_test.gd fails on it).
#
# Whether each mark draws its own colour (W46-13): --marks=1 draws, on a display, one row per mark: the mark's tone as a
# plain material (the reference) beside the same tone written into a mesh with the switch as the mark's own material
# line sets it (read from the code, as above), added at half strength over charcoal for the marks that add their light.
# It writes marks-swatches.png and marks.json and prints one MARKSWATCH line per mark: the CIE76 distance between the
# two, which passes at MARK_DE_MAX or less. --plant-mark=<mark> draws that one mark with the switch off, the washed-out
# case, which must fail. Every full run writes the same rows into probe.json as `mark_swatches`.
#   <godot> --path sketches/core-loop --script res://tools/vertex_colour_probe.gd -- --marks=1 --out=/abs/dir [--plant-mark=trail]

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Bars := preload("res://src/core/defence_bars.gd")

const KINDS := ["chaser", "lobber", "mag_trapper", "jolt_layer", "catch_trap", "hooker", "ramp_flipper", "boom_tender", "plated_brute",
	"splitter", "linker", "foreman", "dispatcher", "miniboss"]
const TONES := ["CHARCOAL", "VERDIGRIS", "RUST", "COPPER", "HAZARD", "AMBER", "BRASS", "SAND", "ANCIENT", "ARC", "COBALT"]
const GLOWS := ["AMBER", "ARC", "BRASS"]
const GLOW_ALPHA := 0.5
# Stored colours read from one mesh, and how much nearer one reading must be to count.
const SAMPLES := 240
const EDGE := 0.02
# A pixel that moved more than this (of 255, any channel) between the two stills changed.
const MOVED := 8
const WAIT_TICKS := 2400
const LANDED := 1.6
# The ball's marks: one bolt for each of these weapons' colours, MARKS_M in front of the camera,
# flown for MARK_TICKS before the game is held.
const MARK_WEAPONS := [Weapons.PYLON_TURRET, Weapons.ARC_CASTER, Weapons.RAPID_LASER, Weapons.STICKY_CHARGE, Weapons.CLAW_SWEEP,
	Weapons.LEDGER_READER, Weapons.CANNON_LANE]
const MARKS_M := 5.0
const MARK_TICKS := 4
# The seven marks: [anchor, text] finds the first line holding `text` at or after the first line holding `anchor`.
const MAT_LINE := ["", "vertex_color_use_as_albedo = true"]
const MARK_SITES := [
	{"mark": "bolts", "file": "res://src/combat/bolts.gd", "material": MAT_LINE,
		"colour": ["", "_multimesh.set_instance_color(i, drawn[1])"], "source": "tint(): the first shot bit's colour, else the weapon's", "tone": Palette.ARC, "add": false},
	{"mark": "attack lines and rings", "file": "res://src/combat/effects.gd", "material": MAT_LINE,
		"colour": ["func _line(a", "_mesh.surface_set_color(color)"], "source": "the caller's colour (arc, ring, spark, beam, shockwave)", "tone": Palette.VERDIGRIS, "add": false},
	{"mark": "trail", "file": "res://src/presentation/vfx.gd", "material": MAT_LINE,
		"colour": ["func _draw_trail(", "mesh.surface_set_color("], "source": "SpeedTier.COLORS[tier] (src/movement/speed_tier.gd)",
		"tone": SpeedTier.COLORS[2], "add": true},
	{"mark": "speed lines", "file": "res://src/presentation/vfx.gd", "material": MAT_LINE,
		"colour": ["func _draw_lines(", "mesh.surface_set_color("], "source": "SpeedTier.COLORS[tier] (src/movement/speed_tier.gd)",
		"tone": SpeedTier.COLORS[1], "add": true},
	{"mark": "aura motes", "file": "res://src/presentation/player_fx.gd", "material": MAT_LINE,
		"colour": ["", "mm.set_instance_color(i, c.lerp(Color.WHITE"], "source": "heat_tint(part_color()): ELEMENT_COLORS, leaning to HEAT_COLOR", "tone": Palette.ARC, "add": false},
	{"mark": "cable arcs", "file": "res://src/presentation/machine_fx.gd", "material": MAT_LINE,
		"colour": ["", "_cable_mesh.surface_set_color(color)"], "source": "Palette.SAND, its alpha the arc's life", "tone": Palette.SAND, "add": true},
	{"mark": "aim", "file": "res://src/movement/indicator.gd", "material": MAT_LINE,
		"colour": ["", "_tris.surface_set_color(color)"], "source": "the shape's colour: class_color(), SAND when blocked, CHARCOAL keyline", "tone": Palette.SAND, "add": false},
]
# Slower than any weapon's, so the bolts are still in view when the game is held; a bolt's
# colour does not change with its speed.
const MARK_SPEED := 20.0
const ROLL_TICKS := 60
# The clock while a scene is held, so shader time and particles stand still between stills.
const HELD := 0.001
const PLANT := Color(0.5, 0.5, 0.5)
# A mark drawn within this CIE76 of its plain tone draws its own colour. The switch off moves every mark's tone 10 or
# more on Forward+ (the planted run's numbers are on the W46-13 pull request); two stills of one tone differ by under 1.
const MARK_DE_MAX := 3.0

var out := ""
var boss := true
var plant := false
var game
var _stood := []
var failed := ""
var _tones := {}
var _tints := {}
var _report := {}
var _plant_mark := ""


func _initialize() -> void:
	var sites := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sites="):
			sites = arg.trim_prefix("--sites=") != "0"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--boss="):
			boss = arg.trim_prefix("--boss=") != "0"
		elif arg.begins_with("--plant="):
			plant = arg.trim_prefix("--plant=") != "0"
	var marks := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--marks="):
			marks = arg.trim_prefix("--marks=") != "0"
		elif arg.begins_with("--plant-mark="):
			_plant_mark = arg.trim_prefix("--plant-mark=")
	if sites:
		quit(_print_sites())
		return
	if marks:
		if out.is_empty() or DisplayServer.get_name() == "headless":
			push_error("usage: --marks=1 --out=/abs/dir [--plant-mark=<mark>], on a display")
			quit(2)
			return
		DirAccess.make_dir_recursive_absolute(out)
		_marks_only.call_deferred()
		return
	if out.is_empty() or DisplayServer.get_name() == "headless":
		push_error("usage: --script res://tools/vertex_colour_probe.gd -- --out=/abs/dir [--boss=0] [--plant=1], on a display")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var constants: Dictionary = (Palette as Script).get_script_constant_map()
	for key in constants:
		if constants[key] is Color:
			_tones[key] = constants[key]
	_run.call_deferred()


func _run() -> void:
	_report = {"tool": "vertex_colour_probe.gd", "method": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "planted": plant, "mark_sites": mark_sites()}
	await _swatches()
	_report["mark_swatches"] = await _mark_swatches()
	await _boot()
	if failed != "":
		return
	await _lineup()
	await _pair("lineup")
	await _marks()
	await _pair("marks")
	if boss and failed == "":
		game.flow.enter_stage(1, Vector3.ZERO, false)
		await _ticks(60)
		game.flow.enter_stage(2, Vector3.ZERO, false)
		await _ticks(60)
		game.flow.enter_boss(Vector3.ZERO)
		await _ticks(240)
		if game.ctx.boss == null or game.ctx.boss.get("ship") == null:
			return _fail("the boss fight did not build its ship")
		game.run.set_max_hp(999999.0)
		var ball: Vector3 = game.player.ball_position()
		var to_ship: Vector3 = game.ctx.boss.ship.global_position - ball
		game.camera.snap(Vector3(to_ship.x, 0.0, to_ship.z).normalized())
		await _frames(45)
		await _pair("arena")
	if failed != "":
		return
	var file := FileAccess.open(out.path_join("probe.json"), FileAccess.WRITE)
	if file == null:
		quit(3)
		return
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	quit(0)


# --- Where the marks set their colour ---------------------------------------------------------

# One row per MARK_SITES entry: {mark, file, material_line, srgb, colour_line, source}, or with "error" when its text is gone.
# srgb is whether the material's function turns vertex_color_is_srgb on.
static func mark_sites() -> Array:
	var rows := []
	for site: Dictionary in MARK_SITES:
		var lines := FileAccess.get_file_as_string(site.file).split("\n")
		var row := {"mark": site.mark, "file": String(site.file).trim_prefix("res://"), "source": site.source}
		var at := _find(lines, site.material)
		var write := _find(lines, site.colour)
		if at < 0 or write < 0:
			row["error"] = "the %s text is no longer in the file" % ("material" if at < 0 else "colour")
			rows.append(row)
			continue
		var srgb := false
		for i in range(at, lines.size()):
			if i > at and (lines[i].begins_with("func ") or lines[i].begins_with("static func ")):
				break
			srgb = srgb or lines[i].contains("vertex_color_is_srgb = true")
		row["material_line"] = at + 1
		row["srgb"] = srgb
		row["colour_line"] = write + 1
		rows.append(row)
	return rows


static func _find(lines: PackedStringArray, spec: Array) -> int:
	var from := 0
	if not String(spec[0]).is_empty():
		from = -1
		for i in lines.size():
			if lines[i].contains(spec[0]):
				from = i
				break
		if from < 0:
			return -1
	for i in range(from, lines.size()):
		if lines[i].contains(spec[1]):
			return i
	return -1


func _print_sites() -> int:
	var rows := mark_sites()
	var bad := 0
	for row: Dictionary in rows:
		if row.has("error"):
			bad += 1
			print("MARK %s  %s  %s" % [row.mark, row.file, row.error])
		else:
			print("MARK %s  material %s:%d (srgb %s)  colour %s:%d  from %s" % [row.mark, row.file, row.material_line,
				"on" if row.srgb else "off", row.file, row.colour_line, row.source])
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file := FileAccess.open(out.path_join("mark_sites.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(rows, "\t"))
	return 1 if bad > 0 else 0


# --- The marks' own colours -------------------------------------------------------------------

func _marks_only() -> void:
	var rows := await _mark_swatches()
	var bad := 0
	for row: Dictionary in rows:
		bad += 0 if row.ok else 1
		print("MARKSWATCH %s  srgb %s%s  tone %s  plain %s  drawn %s  CIE76 %.1f  %s" % [row.mark, "on" if row.srgb else "off",
			" (planted off)" if row.planted else "", row.tone, str(row.plain), str(row.drawn), row.de, "ok" if row.ok else "WASHED OUT"])
	var file := FileAccess.open(out.path_join("marks.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"method": RenderingServer.get_current_rendering_method(),
			"adapter": RenderingServer.get_video_adapter_name(), "plant_mark": _plant_mark, "max_de": MARK_DE_MAX, "rows": rows}, "\t"))
		file.close()
	quit(1 if bad > 0 else 0)


# One row per mark: its tone as a plain material, then written into a mesh with the switch its material line sets
# (an additive mark at half strength over charcoal, both columns). {mark, srgb, planted, tone, plain, drawn, de, ok}.
func _mark_swatches() -> Array:
	var sites := mark_sites()
	var stage := Node3D.new()
	stage.name = "MarkSwatches"
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.5, 0.5)
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var rows := MARK_SITES.size()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(rows) + 1.0
	camera.position = Vector3(0.5, (rows - 1) * 0.5, 5.0)
	stage.add_child(camera)
	camera.make_current()
	var cells := []
	for i in MARK_SITES.size():
		var site: Dictionary = MARK_SITES[i]
		var row: Dictionary = sites[i]
		var planted: bool = String(site.mark) == _plant_mark
		var srgb: bool = bool(row.get("srgb", false)) and not planted
		var add: bool = site.add
		var tone: Color = Color(site.tone, GLOW_ALPHA) if add else Color(site.tone, 1.0)
		var y := float(rows - 1 - i)
		if add:
			for x in 2:
				_quad(stage, Palette.CHARCOAL, false, false, Vector2(x, y), false, 1.0, -0.1)
		_quad(stage, tone, false, false, Vector2(0.0, y), add, 0.6 if add else 0.9)
		_quad(stage, tone, true, srgb, Vector2(1.0, y), add, 0.6 if add else 0.9)
		cells.append({"mark": site.mark, "srgb": srgb, "planted": planted, "tone": (site.tone as Color).to_html(false), "y": y})
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if not out.is_empty():
		image.save_png(out.path_join("marks-swatches.png"))
	var scale := Vector2(image.get_size()) / root.get_visible_rect().size
	var result := []
	for cell: Dictionary in cells:
		var plain := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(0.0, cell.y, 0.0)) * scale))
		var drawn := image.get_pixelv(Vector2i(camera.unproject_position(Vector3(1.0, cell.y, 0.0)) * scale))
		var de := Bars.cie76(plain, drawn)
		cell.erase("y")
		cell.merge({"plain": _rgb(plain), "drawn": _rgb(drawn), "de": snappedf(de, 0.1), "ok": de <= MARK_DE_MAX})
		result.append(cell)
	stage.free()
	return result


# --- Swatches ---------------------------------------------------------------------------------

func _swatches() -> void:
	var stage := Node3D.new()
	stage.name = "Swatches"
	root.add_child(stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.5, 0.5, 0.5)
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)
	var rows := TONES.size() + GLOWS.size()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(rows) + 1.0
	camera.position = Vector3(2.0, (rows - 1) * 0.5, 5.0)
	stage.add_child(camera)
	camera.make_current()
	var cells := []
	for i in TONES.size():
		var tone: Color = _tones[TONES[i]]
		var y := float(rows - 1 - i)
		_quad(stage, tone, false, false, Vector2(0.0, y))
		_quad(stage, tone, true, false, Vector2(1.0, y))
		_quad(stage, tone, true, true, Vector2(2.0, y))
		_quad(stage, tone.srgb_to_linear(), true, false, Vector2(3.0, y))
		_quad(stage, tone.srgb_to_linear(), true, true, Vector2(4.0, y))
		cells.append({"tone": TONES[i], "y": y, "columns": ["plain", "written_off", "written_on", "linear_off", "linear_on"]})
	for i in GLOWS.size():
		var tone := Color(_tones[GLOWS[i]], GLOW_ALPHA)
		var y := float(GLOWS.size() - 1 - i)
		for x in 3:
			_quad(stage, _tones["CHARCOAL"], false, false, Vector2(x, y), false, 1.0, -0.1)
		_quad(stage, tone, false, false, Vector2(0.0, y), true, 0.6)
		_quad(stage, tone, true, false, Vector2(1.0, y), true, 0.6)
		_quad(stage, tone, true, true, Vector2(2.0, y), true, 0.6)
		cells.append({"tone": GLOWS[i] + " added over CHARCOAL", "y": y, "columns": ["plain", "written_off", "written_on"]})
	await _frames(6)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(out.path_join("swatches.png")) != OK:
		return _fail("could not save swatches.png")
	var scale := Vector2(image.get_size()) / root.get_visible_rect().size
	var rows_out := []
	for cell in cells:
		var row := {"tone": cell["tone"]}
		if _tones.has(cell["tone"]):
			row["palette"] = _rgb(_tones[cell["tone"]])
		var columns: Array = cell["columns"]
		for x in columns.size():
			var at := camera.unproject_position(Vector3(x, cell["y"], 0.0)) * scale
			row[columns[x]] = _rgb(image.get_pixelv(Vector2i(at)))
		rows_out.append(row)
	_report["swatches"] = rows_out
	stage.free()


func _quad(parent: Node3D, color: Color, vertex: bool, srgb: bool, at: Vector2, add := false, size := 0.9, depth := 0.0) -> void:
	var half := size * 0.5
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-half, -half, 0.0), Vector3(half, -half, 0.0), Vector3(half, half, 0.0),
			Vector3(-half, -half, 0.0), Vector3(half, half, 0.0), Vector3(-half, half, 0.0)]:
		if vertex:
			tool.set_color(color)
		tool.add_vertex(point)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if vertex:
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = srgb
	else:
		material.albedo_color = color
	if add:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var view := MeshInstance3D.new()
	view.mesh = tool.commit()
	view.material_override = material
	view.position = Vector3(at.x, at.y, depth)
	parent.add_child(view)


# --- The game ---------------------------------------------------------------------------------

func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	var waited := 0
	while game.flow == null and waited < 600:
		waited += 1
		await physics_frame
	if game.flow == null:
		return _fail("the game never built its flow")
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	# The run opens with the ball on its drop.
	var ground = game.ctx.spawner.ground
	var down := 0
	for i in WAIT_TICKS:
		await physics_frame
		var p: Vector3 = game.player.ball_position()
		down = down + 1 if p.y - Telegraph.ground_under(ground, p) < LANDED else 0
		if down >= 30:
			break
	if down < 30:
		return _fail("the ball never landed")
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0


# The fourteen kinds in two rows ahead of the ball, then held where they stand.
func _lineup() -> void:
	var ground = game.ctx.spawner.ground
	var spot: Vector3 = game.player.ball_position()
	var ahead := Vector3.BACK
	if is_instance_valid(game.flow.beacon):
		var to: Vector3 = game.flow.beacon.global_position - spot
		ahead = Vector3(to.x, 0.0, to.z).normalized()
	var side := ahead.cross(Vector3.UP).normalized()
	game.player.reset_to(spot)
	await _ticks(2)
	game.player.body().freeze = true
	game.camera.snap(ahead)
	var stood := []
	for i in KINDS.size():
		var kind: String = KINDS[i]
		if not (kind in ["chaser", "lobber", "miniboss"] or game.combat.fleet.makes(kind)):
			continue
		var at: Vector3 = spot + ahead * (9.0 + 5.0 * (i / 7)) + side * ((i % 7) - 3.0) * 3.2
		at.y = Telegraph.ground_under(ground, at) + 1.0
		var enemy = game.combat.spawn_enemy(kind, at)
		if enemy != null:
			stood.append(kind)
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
			_stood.append(enemy)
	_report["lineup"] = stood
	await _frames(60)


# The ball's own marks, put up by the game's own calls where the camera looks. The ball rolls
# first, so its trail is drawn if the game draws one at that speed. The bolts fly across the
# view for a few ticks, then the attack lines go up and the clock all but stops, so the short
# ones (an arc lives a sixth of a second) are whole in every still.
func _marks() -> void:
	if failed != "":
		return
	game.player.body().freeze = false
	game.player.source.hold = {"move": Vector2(0.0, 1.0)}
	await _ticks(ROLL_TICKS)
	game.player.source.hold = {}
	var view: Transform3D = root.get_camera_3d().global_transform
	var across := view.basis.x
	var centre := view.origin - view.basis.z * MARKS_M
	var pattern: Resource = game.combat.pattern(Weapons.PYLON_TURRET)
	for i in MARK_WEAPONS.size():
		var weapon: String = MARK_WEAPONS[i]
		game.combat.bolts.fire({
			"origin": centre + across * 1.4 + view.basis.y * (1.6 - 0.35 * i), "dir": across, "speed": MARK_SPEED,
			"max_dist": 40.0, "damage": 0.0, "kind": Weapons.strike_kind(weapon), "weapon_id": weapon,
			"radius": pattern.bolt_radius, "knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.0,
			"lattice_chain_falloff": 0.0, "color": Weapons.color(weapon), "wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0,
			"source": "persistent_actor",
		})
	await _ticks(MARK_TICKS)
	Engine.time_scale = HELD
	var effects = game.combat.effects
	var low := centre - view.basis.y * 1.6
	effects.ring(low - across * 1.6, 0.9, Palette.VERDIGRIS)
	effects.arc(low - across * 0.4, low + across * 0.8 + view.basis.y * 0.5, Palette.ARC)
	effects.spark(low + across * 1.4, Palette.VERDIGRIS)
	effects.beam(low + across * 2.0 - view.basis.y * 0.4, low + across * 2.0 + view.basis.y * 0.8, Palette.AMBER, 2.0)
	await _frames(2)
	_report["marks_shots"] = game.combat.bolts.live()


# The census, the still as the game draws it, then the switch turned on for one family of
# candidates at a time, then for all of them. The game is held and its clock all but stopped
# throughout. Every count is still taken against a still from a few frames before, and `noise`
# is the count between two such stills with nothing switched.
func _pair(label: String) -> void:
	if failed != "":
		return
	paused = true
	Engine.time_scale = HELD
	var candidates := {}
	_report[label + "_census"] = _census(candidates)
	var first := await _still(label + "-as-is.png")
	var again := await _still("")
	if first == null or again == null:
		return
	var noise := _moved(first, again)
	var rows := []
	var owners := candidates.keys()
	owners.sort()
	for owner in owners:
		var before := await _still("")
		_switch(candidates[owner], true)
		var file := "%s-%s.png" % [label, owner]
		var after := await _still(file)
		_switch(candidates[owner], false)
		if before == null or after == null:
			return
		var row := _moved(before, after)
		row["family"] = owner
		row["materials"] = candidates[owner].size()
		if row["pixels"] <= noise["pixels"]:
			DirAccess.remove_absolute(out.path_join(file))
		rows.append(row)
	var before_all := await _still("")
	for owner in owners:
		_switch(candidates[owner], true)
	var all := await _still(label + "-srgb.png")
	for owner in owners:
		_switch(candidates[owner], false)
	Engine.time_scale = 1.0
	paused = false
	if before_all == null or all == null:
		return
	_report[label + "_noise"] = noise
	_report[label + "_switched"] = rows
	_report[label + "_changed"] = _moved(before_all, all)


# The switch on or off for a set of materials; with --plant, a grey tint in its place, and the
# material's own tint put back after.
func _switch(materials: Array, on: bool) -> void:
	for material in materials:
		if not plant:
			material.vertex_color_is_srgb = on
		elif on:
			_tints[material.get_instance_id()] = material.albedo_color
			material.albedo_color = PLANT
		elif _tints.has(material.get_instance_id()):
			material.albedo_color = _tints[material.get_instance_id()]
			_tints.erase(material.get_instance_id())


# How many pixels moved between two stills, and their mean colour in each.
static func _moved(before: Image, after: Image) -> Dictionary:
	var a := before.get_data()
	var b := after.get_data()
	var moved := 0
	var was := Vector3.ZERO
	var now := Vector3.ZERO
	for i in range(0, a.size(), 3):
		if absi(a[i] - b[i]) > MOVED or absi(a[i + 1] - b[i + 1]) > MOVED or absi(a[i + 2] - b[i + 2]) > MOVED:
			moved += 1
			was += Vector3(a[i], a[i + 1], a[i + 2])
			now += Vector3(b[i], b[i + 1], b[i + 2])
	var row := {"pixels": moved, "of": a.size() / 3}
	if moved > 0:
		was /= moved
		now /= moved
		row["mean_before"] = [roundi(was.x), roundi(was.y), roundi(was.z)]
		row["mean_after"] = [roundi(now.x), roundi(now.y), roundi(now.z)]
	return row


# The picture on screen, saved under `file` unless that is empty.
func _still(file: String) -> Image:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if file != "" and image.save_png(out.path_join(file)) != OK:
		_fail("could not save %s" % file)
		return null
	image.convert(Image.FORMAT_RGB8)
	return image


# Every material in the scene that takes vertex colour, grouped. `candidates` collects, by
# family, the ones with the switch off on a mesh built in code that carries colours.
func _census(candidates: Dictionary) -> Array:
	var groups := {}
	var seen := {}
	for view in root.find_children("*", "GeometryInstance3D", true, false):
		if not view.is_visible_in_tree():
			continue
		var mesh: Mesh = null
		var colours := PackedColorArray()
		if view is MeshInstance3D:
			mesh = view.mesh
		elif view is MultiMeshInstance3D and view.multimesh != null:
			mesh = view.multimesh.mesh
			if view.multimesh.use_colors:
				var count: int = view.multimesh.visible_instance_count
				for i in mini(count if count >= 0 else view.multimesh.instance_count, SAMPLES):
					colours.append(view.multimesh.get_instance_color(i))
		if mesh == null:
			continue
		var materials := []
		if view.material_override != null:
			materials.append(view.material_override)
		else:
			for surface in mesh.get_surface_count():
				var material: Material = view.get_surface_override_material(surface) if view is MeshInstance3D else null
				materials.append(material if material != null else mesh.surface_get_material(surface))
		var origin := _origin(mesh)
		var stored := {}
		for material in materials:
			if not material is BaseMaterial3D or not material.vertex_color_use_as_albedo:
				continue
			if stored.is_empty():
				stored = _stored(mesh, colours)
			var owner := _owner(view)
			var key := "%s | %s | %s | %s | %s | %s" % [owner, origin, material.vertex_color_is_srgb,
				material.shading_mode, material.blend_mode, stored["nearest"]]
			if not groups.has(key):
				groups[key] = {"owner": owner, "mesh": origin, "switch": material.vertex_color_is_srgb,
					"lit": material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "added": material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD,
					"nearest": stored["nearest"], "switch_moves": stored["moves"], "views": 0, "example": str(view.get_path())}
			groups[key]["views"] += 1
			groups[key]["switch_moves"] = maxi(groups[key]["switch_moves"], stored["moves"])
			var coloured: bool = stored["nearest"] != "not read" or mesh is ImmediateMesh
			if not material.vertex_color_is_srgb and origin == "built in code" and coloured and not seen.has(material.get_instance_id()):
				seen[material.get_instance_id()] = true
				var family := _family(owner, view)
				if not candidates.has(family):
					candidates[family] = []
				candidates[family].append(material)
	var rows := groups.values()
	rows.sort_custom(func(a, b): return str(a["owner"]) + str(a["mesh"]) < str(b["owner"]) + str(b["mesh"]))
	return rows


# Where a mesh came from: a file, a copy of an imported mesh, or code. The importer names a
# mesh and its surfaces and may give it a shadow mesh; a copy keeps all three, and a mesh built
# here by code has none of them.
static func _origin(mesh: Mesh) -> String:
	if mesh.resource_path != "" and not mesh.resource_path.begins_with("local://"):
		return "cast"
	if mesh.resource_name != "":
		return "cast, copied"
	if mesh is ArrayMesh:
		if mesh.shadow_mesh != null:
			return "cast, copied"
		for surface in mesh.get_surface_count():
			if mesh.surface_get_name(surface) != "":
				return "cast, copied"
	return "built in code"


# A candidate's family: its owner and, where the game named the view, that name, so two effects
# under one script (the cable arcs and the aura's motes under game.gd) are switched apart.
static func _family(owner: String, view: Node) -> String:
	var named := str(view.name)
	return owner.get_basename() if named.begins_with("@") else "%s-%s" % [owner.get_basename(), named]


# The script that owns a view: its own, or its nearest ancestor's.
static func _owner(view: Node) -> String:
	var node := view
	while node != null:
		var script: Script = node.get_script()
		if script != null and script.resource_path != "":
			return script.resource_path.get_file()
		node = node.get_parent()
	return "(no script)"


# What a mesh's stored colours look like. `nearest`: "written" (nearer the palette as it stands),
# "linear" (nearer the palette turned linear), "unplaced" or "not read". `moves`: how far the
# switch would move the mean stored colour, of 255; white and black do not move.
func _stored(mesh: Mesh, colours: PackedColorArray) -> Dictionary:
	if colours.is_empty() and mesh is ArrayMesh:
		for surface in mesh.get_surface_count():
			if mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				var arrays := mesh.surface_get_arrays(surface)
				var found = arrays[Mesh.ARRAY_COLOR]
				if found is PackedColorArray:
					var step := maxi(1, found.size() / SAMPLES)
					for i in range(0, found.size(), step):
						colours.append(found[i])
	if colours.is_empty():
		return {"nearest": "not read", "moves": 0}
	var written := 0
	var linear := 0
	var moves := 0.0
	for colour in colours:
		moves += _apart(colour, colour.srgb_to_linear())
		var as_written := INF
		var as_linear := INF
		for key in _tones:
			var tone: Color = _tones[key]
			as_written = minf(as_written, _apart(colour, tone))
			as_linear = minf(as_linear, _apart(colour, tone.srgb_to_linear()))
		if as_written + EDGE < as_linear:
			written += 1
		elif as_linear + EDGE < as_written:
			linear += 1
	var nearest := "unplaced"
	if written > 0 or linear > 0:
		nearest = "written" if written >= linear else "linear"
	return {"nearest": nearest, "moves": roundi(255.0 * moves / colours.size())}


static func _apart(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


static func _rgb(color: Color) -> Array:
	return [color.r8, color.g8, color.b8]


func _fail(why: String) -> void:
	failed = why
	push_error("vertex_colour_probe: " + why)
	quit(4)


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame
