extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

# Stills of the spillway dam (landmark_dam, W1-25) from five fixed eyes in the running game, so two
# builds of the dam compare frame for frame: the Warden yard (as the 10 Nov PC still 02), the yard from
# the side, the approach, the mid view about 650 m out and the drop-in at the stage spawn (the far mesh,
# 1.33 km). The ball is frozen out of shot and the HUD hidden. Needs a rendered display:
#
#   xvfb-run -a -s "-screen 0 1920x1080x24" $GODOT_BIN --rendering-driver opengl3 --path sketches/core-loop \
#     --script res://tools/dam_look_capture.gd -- --out=<absolute dir> [--shots=yard,dropin]
#
# On the PC run it on the real renderer (drop --rendering-driver). Writes <out>/<shot>.png and shots.json.

const SIZE := Vector2i(1920, 1080)
const SHOTS := {
	"yard": {"eye": Vector3(0, 9, 548), "at": Vector3(0, 50, 640), "fov": 65.0},
	"yard_side": {"eye": Vector3(85, 22, 500), "at": Vector3(0, 62, 640), "fov": 65.0},
	"approach": {"eye": Vector3(-150, 40, 290), "at": Vector3(0, 78, 640), "fov": 65.0},
	"mid": {"eye": Vector3(-90, 170, -20), "at": Vector3(0, 95, 640), "fov": 50.0},
	"dropin": {"eye": Vector3(-150, 0, -690), "at": Vector3(0, 105, 640), "fov": 30.0},
}

var _out := ""
var _only: Array = []
var _game


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = Array(arg.trim_prefix("--shots=").split(","))
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		printerr("dam_look_capture: needs a rendered display and -- --out=<absolute dir>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(280928)
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await process_frame
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	var dam: Node = null
	for i in 900:
		await process_frame
		dam = root.find_child("Landmark_spillway_dam", true, false)
		if dam != null and _game.ctx.terrain.is_ready(1) and _game.flow.in_play() and i > 120:
			break
	if dam == null:
		printerr("dam_look_capture: the dam never built")
		quit(1)
		return
	_game.player.set_frozen(true)
	_game.player.body().global_position = Vector3(-400, 400, -400)
	_game.presentation.hide_ui()
	var cam := Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	_game.add_child(cam)
	cam.make_current()
	var record := {}
	for id: String in SHOTS:
		if not _only.is_empty() and not _only.has(id):
			continue
		var s: Dictionary = SHOTS[id]
		var eye: Vector3 = s["eye"]
		if id == "dropin":
			eye.y = _game.ctx.terrain.height(eye.x, eye.z) + 2.0
		cam.fov = s["fov"]
		cam.global_position = eye
		cam.look_at(s["at"])
		for f in 30:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png(_out.path_join(id + ".png"))
		record[id] = {"eye": [eye.x, eye.y, eye.z], "at": [s["at"].x, s["at"].y, s["at"].z], "fov": s["fov"]}
	var f := FileAccess.open(_out.path_join("shots.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(record, " "))
	f.close()
	quit(0)
