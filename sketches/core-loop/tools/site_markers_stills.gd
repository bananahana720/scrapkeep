extends SceneTree

# Stills of the site markers (src/presentation/site_markers.gd): every plume on the dam (stage 1) and the flume
# (stage 2) of the park table, each from FAR_M, MID_M and NEAR_M away at a rider's eye height, looking at the plume,
# plus one control still from MID_M with the plumes hidden. A reader is asked "what is over there?" and whether it is
# something to pick up or something to fight. Needs a rendered display:
#
#   xvfb-run -s "-screen 0 1920x1080x24" <godot> --path sketches/core-loop --script res://tools/site_markers_stills.gd \
#     -- --out=<absolute dir> [--stages=1,2]
#
# Each still is <stage>_<kind>_<site>_<distance>.png; one line a still goes to stills.txt. The eye stands on the side of
# the site toward the stage's drop-in, the way a rider meets it.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const FAR_M := 300.0
const MID_M := 130.0
const NEAR_M := 45.0
const EYE_M := 4.0
const SETTLE_FRAMES := 90

var game
var out := ""
var stages: Array = [1, 2]
var _lines: PackedStringArray = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--stages="):
			stages = Array(arg.trim_prefix("--stages=").split(",")).map(func(v): return int(v))
	if out.is_empty() or DisplayServer.get_name() == "headless":
		print("site_markers_stills: needs --out=<dir> and a rendered display")
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
	var camera := Camera3D.new()
	camera.fov = 65.0
	camera.far = 700.0
	root.add_child(camera)
	for stage in stages:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
		for i in SETTLE_FRAMES:
			game.player.set_velocity_now(Vector3.ZERO)
			await physics_frame
		for node in root.find_children("*", "CanvasLayer", true, false):
			node.visible = false
		camera.make_current()
		var map_id := String(game.ctx.terrain.map().title)
		var markers = game.presentation.site_markers
		var drop: Vector3 = game.ctx.player.ball_position()
		for key in markers.views.keys():
			var view: MeshInstance3D = markers.views[key]
			var kind := String(view.get_meta("kind"))
			var foot := view.global_position
			var toward := Vector2(drop.x - foot.x, drop.z - foot.z)
			toward = toward.normalized() if toward.length() > 1.0 else Vector2(0.0, 1.0)
			var look := foot + Vector3.UP * float(markers.KINDS[kind]["height"]) * 0.4
			for d in [FAR_M, MID_M, NEAR_M]:
				await _shot(camera, markers, foot, toward, d, look, "%s_%s_%s_%03d" % [map_id, kind, String(key).get_slice(":", 1), int(d)], true)
			await _shot(camera, markers, foot, toward, MID_M, look, "%s_%s_%s_control" % [map_id, kind, String(key).get_slice(":", 1)], false)
	var f := FileAccess.open(out.path_join("stills.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	game.free()
	quit(0)


func _shot(camera: Camera3D, markers, foot: Vector3, toward: Vector2, d: float, look: Vector3, label: String, shown: bool) -> void:
	var x := foot.x + toward.x * d
	var z := foot.z + toward.y * d
	camera.global_position = Vector3(x, game.ctx.terrain.height(x, z) + EYE_M, z)
	camera.look_at(look)
	markers.visible = shown
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	markers.visible = true
	var line := "STILL %s eye %s foot %s" % [label, camera.global_position.snapped(Vector3.ONE * 0.1), foot.snapped(Vector3.ONE * 0.1)]
	_lines.append(line)
	print(line)
