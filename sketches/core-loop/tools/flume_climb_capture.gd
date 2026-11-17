extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

# Stills of the flume's butte gap table (park_flume gap_table and gap_table_kicker, W1-102), from three fixed eyes in
# the running game, so the place before and after a change compares frame for frame: far from the weir bench (how it
# reads from a distance, map standard point 1), the approach down the mesa rim road (the kicker at its foot), and the
# gap floor under the flume's last reach looking back at the far lip. The ball is frozen out of shot and the HUD
# hidden. Each eye stands 2 m over the ground under it. Needs a rendered display:
#
#   $GODOT_BIN --path sketches/core-loop --script res://tools/flume_climb_capture.gd -- --out=<absolute dir> [--shots=far]
#
# Run it with a scratch HOME (macOS keeps user:// under HOME). Writes <out>/<shot>.png and shots.json.

const SIZE := Vector2i(1920, 1080)
const SHOTS := {
	"far": {"eye": Vector2(-440, -440), "rise": 22.0, "at": Vector3(-302, 58, -308), "fov": 50.0},
	"approach": {"eye": Vector2(-372, -352), "rise": 2.0, "at": Vector3(-310, 60, -312), "fov": 65.0},
	"lip": {"eye": Vector2(-262, -250), "rise": 2.0, "at": Vector3(-300, 62, -306), "fov": 65.0},
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
		printerr("flume_climb_capture: needs a rendered display and -- --out=<absolute dir>")
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
	_game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in 900:
		await process_frame
		if _game.ctx.terrain.is_ready(1) and _game.flow.in_play() and i > 120:
			break
	_game.player.set_frozen(true)
	_game.player.body().global_position = Vector3(-700, 400, 700)
	_game.presentation.hide_ui()
	var cam := Camera3D.new()
	cam.near = 0.5
	cam.far = 2000.0
	_game.add_child(cam)
	cam.make_current()
	# A free still camera takes the terrain's detail rings over from the chase camera (dam_look_capture.gd).
	for terrain in root.find_children("*", "Terrain3D", true, false):
		terrain.set_camera(cam)
	var record := {}
	for id: String in SHOTS:
		if not _only.is_empty() and not _only.has(id):
			continue
		var s: Dictionary = SHOTS[id]
		var foot: Vector2 = s["eye"]
		var eye := Vector3(foot.x, _game.ctx.terrain.height(foot.x, foot.y) + float(s["rise"]), foot.y)
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
