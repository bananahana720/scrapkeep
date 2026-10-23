extends SceneTree

# Stills of the Slag Bowl's Fleet yard (world 1 unit 9): the stands, furnaces, ladles and ledger from the floor and
# from a crane mast, in each of Brindle's three phases (the turns mid-cheer). Needs a rendered display:
#
#   xvfb-run -s "-screen 0 1920x1080x24" <godot> --path sketches/core-loop --script res://tools/arb_yard_stills.gd \
#     -- --out=<absolute dir>

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/boss_harness.gd")
const Intent := preload("res://src/movement/intent.gd")

# name, eye (arena angle degrees, radius, height), look-at (angle, radius, height)
const VIEWS := [
	["floor_to_stand_a", [120.0, 20.0, 5.0], [300.0, 72.0, 20.0]],
	["floor_to_ledger", [0.0, 24.0, 6.0], [180.0, 76.0, 23.0]],
	["floor_to_stand_b", [270.0, 22.0, 5.0], [95.0, 72.0, 19.0]],
	["bank_to_furnace", [320.0, 52.0, 9.0], [140.0, 84.0, 26.0]],
	["mast_high", [45.0, 27.0, 22.0], [225.0, 60.0, 8.0]],
	["bank_to_stand_a", [262.0, 57.0, 16.0], [300.0, 73.0, 22.0]],
	["ladle_close", [345.0, 55.0, 19.0], [15.0, 75.0, 21.0]],
]

var game
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	Harness.start_run(game)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	Harness.enter(game, Vector3(18, 0, 0))
	for i in 30:
		await physics_frame
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	var camera := Camera3D.new()
	camera.fov = 62.0
	camera.far = 900.0
	root.add_child(camera)
	camera.make_current()
	for phase in [1, 2, 3]:
		if phase >= 2:
			game.boss.jump_to_phase(phase)
		var yard = game.boss.arena.get_node("ArenaBowlDress/FleetYard")
		# Mid-cheer for the turns, settled for the rest.
		for i in (40 if phase >= 2 else 150):
			await process_frame
		for view in VIEWS:
			if phase != 1 and not view[0] in ["floor_to_stand_a", "bank_to_furnace", "ladle_close"]:
				continue
			camera.global_position = _at(view[1])
			camera.look_at(_at(view[2]))
			await process_frame
			await process_frame
			var image := root.get_texture().get_image()
			var label := "p%d" % phase
			image.save_png(out.path_join("%s_%s.png" % [label, view[0]]))
			print("STILL %s %s cheering=%s" % [label, view[0], yard.cheering()])
	quit(0)


# A point in the bowl's frame: arena angle in degrees, radius, height above the bowl floor.
func _at(spot: Array) -> Vector3:
	var arena = game.boss.arena
	return arena.global_position + arena.dir(deg_to_rad(spot[0])) * spot[1] + Vector3.UP * spot[2]
