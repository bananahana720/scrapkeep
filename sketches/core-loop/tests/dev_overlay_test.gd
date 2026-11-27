extends SceneTree

const Game := preload("res://src/game.gd")
const DevConsole := preload("res://src/dev/dev_console.gd")
const DevOverlay := preload("res://src/dev/dev_overlay.gd")
const DevLens := preload("res://src/dev/dev_lens.gd")
const FrameRead := preload("res://src/presentation/frame_read.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

const GRIDS := {1: Vector2i(1, 1), 2: Vector2i(2, 1), 3: Vector2i(3, 1), 4: Vector2i(4, 1), 5: Vector2i(5, 1), 6: Vector2i(3, 2),
	7: Vector2i(4, 2), 8: Vector2i(4, 2), 9: Vector2i(3, 3), 10: Vector2i(5, 2), 11: Vector2i(4, 3), 12: Vector2i(4, 3)}

var _t := T.new("dev_overlay_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_frame_reads()
	_sheet_grids()

	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var console := DevConsole.new()
	game.add_child(console)
	console.setup(game)
	var overlay: DevOverlay = console.overlay
	_t.check("the console mounts the overlay", overlay != null and overlay.is_inside_tree(), "")
	_t.eq("the overlay starts with every layer off", overlay.any_active(), false)

	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	await process_frame

	_commands(console, overlay)
	_perf_table(overlay)
	await _telegraphs(game, overlay)
	await _lens_round_trip(game, console)

	var shipped_cam: Camera3D = game.get_viewport().get_camera_3d()
	console.lens.use("orbit")
	await process_frame
	_t.check("orbit takes the view before teardown", game.get_viewport().get_camera_3d() != shipped_cam, "")
	console.free()
	_t.eq("freeing the console in a dev camera hands the view back", game.get_viewport().get_camera_3d(), shipped_cam)

	Engine.time_scale = 1.0
	game.free()
	quit(_t.verdict())


func _frame_reads() -> void:
	var none := FrameRead.metrics(null)
	_t.check("a missing image reads as an empty dead frame", none.dead and none.reason == "empty", str(none))
	var black := Image.create(64, 36, false, Image.FORMAT_RGB8)
	black.fill(Color(0.02, 0.02, 0.02))
	var m := FrameRead.metrics(black)
	_t.check("a black frame is dead for black", FrameRead.is_dead(m) and m.reason == "black", str(m))
	_t.check("a black frame names its black share", FrameRead.note(m).begins_with("black "), FrameRead.note(m))
	var sky := Image.create(960, 540, false, Image.FORMAT_RGBA8)
	sky.fill(Color(0.55, 0.72, 0.95))
	m = FrameRead.metrics(sky)
	_t.check("a uniform sky is dead for sky", FrameRead.is_dead(m) and m.reason == "sky", str(m))
	_t.near("a uniform sky is one colour", float(m.top_share), 1.0)
	_t.eq("a big frame keeps its own size in the read", [m.width, m.height], [960, 540])
	var varied := Image.create(160, 90, false, Image.FORMAT_RGB8)
	for y in varied.get_height():
		for x in varied.get_width():
			varied.set_pixel(x, y, Color(float(x) / 160.0, float(y) / 90.0, float((x * 7 + y * 13) % 64) / 64.0))
	m = FrameRead.metrics(varied)
	_t.check("a varied frame is alive", not FrameRead.is_dead(m) and m.reason == "", str(m))
	_t.check("a varied frame has many colours", int(m.unique_colours) > 100, str(m.unique_colours))
	_t.check("is_dead reads a bare share row", FrameRead.is_dead({"width": 4, "black_share": 0.9}), "")


func _sheet_grids() -> void:
	for n in range(1, 13):
		var grid := DevConsole.sheet_grid(n)
		_t.eq("sheet_grid(%d)" % n, grid, GRIDS[n])
		_t.check("sheet_grid(%d) holds every tile" % n, grid.x * grid.y >= n and grid.x * (grid.y - 1) < n, str(grid))
	_t.eq("the presets sheet is five by two", DevConsole.sheet_grid(DevConsole.sheet_ids("presets").size()), Vector2i(5, 2))
	_t.eq("the camera sheet starts on the game camera", DevConsole.sheet_ids("cams")[0], "game")
	_t.eq("the quality sheet has three levels", DevConsole.sheet_ids("quality").size(), 3)


func _commands(console, overlay: DevOverlay) -> void:
	var reply: String = console.commands.run_one("overlay bounds")
	_t.check("overlay bounds answers", not reply.begins_with("!"), reply)
	_t.eq("a bare layer name turns on that layer alone", overlay.active_layers(),
		{"bounds": true, "telegraphs": false, "vel": false, "perf": "off"})
	console.commands.run_one("debug +vel +perf")
	_t.eq("debug is the same command and takes several words", overlay.active_layers(),
		{"bounds": true, "telegraphs": false, "vel": true, "perf": "auto"})
	console.commands.run_one("overlay perf on")
	_t.eq("overlay perf on pins the strip", overlay.active_layers().perf, "on")
	console.commands.run_one("overlay -bounds")
	_t.check("a minus drops one layer", not overlay.active_layers().bounds and overlay.active_layers().vel, str(overlay.active_layers()))
	_t.check("an unknown layer is refused", console.commands.run_one("overlay glow").begins_with("!"), "")
	_t.check("a bad perf mode is refused", console.commands.run_one("overlay perf loud").begins_with("!"), "")
	console.commands.run_one("overlay all")
	_t.check("all lights every 3D layer", overlay.any_3d_active() and overlay.active_layers().telegraphs, "")
	console.commands.run_one("overlay off")
	_t.check("off clears every layer and the strip", not overlay.any_active(), str(overlay.active_layers()))
	var parsed = JSON.parse_string(console.commands.run_one("help json"))
	_t.check("help json is JSON with ok and data", parsed is Dictionary and parsed.ok and parsed.data.size() > 0, str(parsed))
	_t.check("help json lists the overlay command", parsed is Dictionary and "overlay" in str(parsed.data), "")


func _perf_table(overlay: DevOverlay) -> void:
	for mode in ["auto", "on", "off"]:
		for hud in [true, false]:
			overlay.set_perf_mode(mode)
			overlay.hud_shown(hud)
			var want: bool = mode == "on" or (mode == "auto" and hud)
			_t.eq("perf %s with the HUD %s" % [mode, "shown" if hud else "hidden"], overlay.perf_visible(), want)
	overlay.hud_shown(true)
	overlay.set_perf_mode("auto")
	overlay.set_capture_hide(false, true)
	_t.eq("a still hides an auto strip", overlay.perf_visible(), false)
	overlay.set_capture_hide(false, false)
	_t.eq("the strip comes back after the still", overlay.perf_visible(), true)
	overlay.set_perf_mode("off")


func _telegraphs(game, overlay: DevOverlay) -> void:
	var ball: Vector3 = game.player.ball_position()
	var tele: Node3D = Telegraph.aerial_ring(game.ctx.root, game.ctx.terrain, Threat.Type.INSTANT, ball - Vector3.UP * 2.0, 3.0, 4.0)
	await process_frame
	ball = game.player.ball_position()
	tele.center = ball - Vector3.UP * 2.0
	overlay.set_mode("telegraphs")
	overlay.redraw()
	var reads: Array = overlay.reads()
	_t.eq("the overlay reads the one telegraph", reads.size(), 1)
	if reads.size() == 1:
		_t.check("a ring on the ball reads inside", reads[0].inside, str(reads[0]))
		_t.eq("inside draws in ledger cream", reads[0].colour, Palette.LEDGER_CREAM)
		_t.near("inside draws 4 px wide", reads[0].px, 4.0)
		_t.eq("an armed ring is dashed", reads[0].pattern, "dash")
	_t.check("the overlay builds geometry within budget", overlay.vertex_count() > 0 and overlay.vertex_count() <= DevOverlay.VERTEX_BUDGET,
		str(overlay.vertex_count()))
	tele.center += Vector3(8.0, 0.0, 0.0)
	tele.progress = 1.0
	overlay.redraw()
	reads = overlay.reads()
	if reads.size() == 1:
		_t.check("a ring moved off the ball reads outside", not reads[0].inside, str(reads[0]))
		_t.eq("outside draws in arc", reads[0].colour, Palette.ARC)
		_t.near("outside draws 2 px wide", reads[0].px, 2.0)
		_t.eq("a live ring is solid", reads[0].pattern, "solid")
	_t.eq("the overlay never merges the warning bound", tele.bound_merges, 0)
	var calm := DevOverlay.telegraph_style(true, true, false)
	_t.check("a non-hostile ring is dotted steel", calm.pattern == "dot" and calm.colour == Palette.STEEL, str(calm))
	overlay.set_mode("all")
	overlay.set_capture_hide(true, true)
	_t.eq("a sheet capture hides the 3D layers", overlay.vertex_count(), 0)
	overlay.set_capture_hide(false, false)
	overlay.set_mode("off")
	tele.queue_free()
	await process_frame


func _lens_round_trip(game, console) -> void:
	var lens: DevLens = console.lens
	var chase: Camera3D = game.get_viewport().get_camera_3d()
	lens.use("iso")
	lens.set_knob("size", 41.0)
	lens.set_knob("yaw", 30.0)
	var held := lens.snapshot()
	lens.use("hero")
	lens.restore(held)
	await process_frame
	_t.eq("restore brings the camera mode back", lens.mode, "iso")
	_t.near("restore brings a knob back", lens.ortho_size, 41.0)
	_t.near("restore brings the yaw back", lens.yaw, 30.0)
	_t.check("restore keeps the dev camera on", game.get_viewport().get_camera_3d() == lens.get_node("DevCamera"), "")
	lens.use("game")
	var shipped := lens.snapshot()
	lens.use("top")
	lens.restore(shipped)
	await process_frame
	_t.eq("restoring a game snapshot hands the view back", game.get_viewport().get_camera_3d(), chase)
	lens.restore(held)
	_t.eq("a live snapshot from the chase camera takes the view again", lens.mode, "iso")
	lens.use("game")
