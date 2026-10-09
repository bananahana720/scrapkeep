extends SceneTree

# W12 P-FX capture: one event fired at a known physics tick in a small staged scene,
# then eight frames, one every 3 ticks, each taken with the tree paused on its tick so
# particles hold still. GPU display only.
#   -- --out=<abs dir> --event=dust|sparks|slam|latch|crack
# Writes <out>/f0..f7.png and prints the device line. Fires bus facts only, so it runs
# on any tree that has the bus (the before captures run it on BASE).
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

const EVENTS := ["dust", "sparks", "slam", "latch", "crack"]
const T0 := 60
const STEP := 3
const SHOTS := 8
const SETTLE_FRAMES := 3

var game
var out := ""
var event := "slam"
var ticks := 0
var cam: Camera3D
var source := Intent.Scripted.new()
var site := Vector3.ZERO
var enemy: Node3D
var shot := 0
var waiting := -1
var done := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
		elif arg.begins_with("--event="):
			event = arg.substr(8)
	if out == "" or event not in EVENTS:
		printerr("w12_fx_capture: -- --out=<abs dir> --event=", "|".join(EVENTS))
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("FXCAP renderer: ", RenderingServer.get_video_adapter_name(), " | ", RenderingServer.get_current_rendering_method())
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_drawn)


func _physics_process(_delta: float) -> bool:
	if game == null or game.flow == null or done:
		return false
	ticks += 1
	if ticks == 1:
		_stage()
	elif ticks == T0 - 20 and event == "dust":
		game.player.reset_to(game.ctx.terrain.drop_point(site.x - 14.0, site.z, 1.0), Vector3(24, 0, 0))
	elif ticks == T0:
		_fire()
	if event == "dust" and ticks >= T0 - 20:
		source.hold = {"move": Vector2(0, -1)}
	if ticks >= T0 and (ticks - T0) % STEP == 0 and shot < SHOTS:
		paused = true
		waiting = SETTLE_FRAMES
	return false


func _stage() -> void:
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = source
	source.hold = {"brake_held": true}
	var bowl: Vector3 = game.ctx.terrain.beacon_point(1) + Vector3(10, 0, 8)
	site = game.ctx.terrain.drop_point(bowl.x, bowl.z, 0.0)
	game.player.reset_to(game.ctx.terrain.drop_point(bowl.x - 3.0, bowl.z + 1.5, 1.2))
	if event in ["sparks", "latch"]:
		enemy = game.ctx.spawner.spawn_enemy("chaser", game.ctx.terrain.drop_point(site.x + 1.5, site.z - 1.0, 1.2))
	cam = Camera3D.new()
	game.add_child(cam)
	cam.fov = 50.0
	cam.current = true
	game.hud.visible = false
	cam.global_position = site + Vector3(7.5, 5.0, 9.0)
	cam.look_at(site + Vector3(0, 0.8, 0))


func _fire() -> void:
	var events = game.ctx.events
	match event:
		"dust":
			pass
		"sparks":
			if is_instance_valid(enemy):
				events.enemy_struck.emit(enemy, "ram", 24.0)
		"slam":
			game.player.reset_to(game.ctx.terrain.drop_point(site.x, site.z, 1.0))
			events.slammed.emit(game.ctx.terrain.drop_point(site.x, site.z, 0.0), 1.0, 1.0)
		"latch":
			if is_instance_valid(enemy):
				events.harpoon_bit.emit(enemy, enemy.global_position + Vector3.UP * 0.6)
		"crack":
			events.world_fact.emit("wall_crumbled", site + Vector3(1.5, 1.0, -1.0))
	print("FXCAP fired ", event, " at tick ", ticks, " ball ", game.player.ball_position(), " speed ", game.player.planar_velocity().length())


func _drawn() -> void:
	if done or waiting < 0:
		return
	waiting -= 1
	if waiting > 0:
		return
	var path := "%s/f%d.png" % [out, shot]
	root.get_texture().get_image().save_png(path)
	print("FXCAP saved ", path, " tick ", ticks)
	shot += 1
	waiting = -1
	paused = false
	if shot >= SHOTS:
		done = true
		quit(0)
