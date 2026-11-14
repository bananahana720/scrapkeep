extends SceneTree
# SCRATCH ONLY (PC lane job BH, 14 Nov 2026): never for the repo's tests or a game branch.
# The lobber look for PR 1019, set up as enemy_lobber_windup_test does: slice table, frozen ball, one lobber 15 m off.
# (1) a close-up at rest; (2) the wind-up and bulb glow posed at 0, 1/3, 2/3 and 1 through _show_charge, then a
# live burst through a real shot (release); (3) one shot at play distance (22 m, chase field of view).
# Run once with --models=tripo and once without; --tag names the files.
#   gamescope ... -- <godot> --audio-driver Dummy --path sketches/core-loop --resolution 1920x1080 [--models=tripo] \
#     --script res://tools/lobber_look.gd -- --out=<abs dir> --tag=<tripo|authored> [--models=tripo]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1920, 1080)

var out := ""
var tag := ""
var game

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
	if out.is_empty() or tag.is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _save(name: String) -> void:
	for i in 2:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s-%s.png" % [out, tag, name])
	print("STILL ", tag, "-", name)

func _cam(at: Vector3, look: Vector3, fov: float) -> Camera3D:
	var c := Camera3D.new()
	c.fov = fov
	root.add_child(c)
	c.global_position = at
	c.look_at(look, Vector3.UP)
	c.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(c)
	return c

func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	game.player.reset_to(game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05))
	game.player.body().freeze = true
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = ball + Vector3(15.0, 0.0, 0.0)
	var enemy = game.combat.spawn_enemy("lobber", game.ctx.terrain.drop_point(at.x, at.z, 2.1))
	for i in 90:
		if enemy.is_on_floor():
			break
		await _frames(1)
	enemy.hp = 100000.0
	enemy._clock = 0.0
	enemy._show_charge(0.0)
	enemy.set_physics_process(false)
	await _frames(5)
	var base: Vector3 = enemy.global_position
	# The lobber faces the ball (-x from it); film from the ball's side, a little off axis.
	var toward := (ball - base)
	toward.y = 0.0
	toward = toward.normalized()
	var side := toward.cross(Vector3.UP).normalized()
	var mid := base + Vector3.UP * 2.4
	# (1) close-up at rest.
	var close := _cam(base + toward * 7.0 + side * 2.5 + Vector3.UP * 2.6, mid, 45.0)
	await _save("1-rest-close")
	# (2) wind-up and bulb glow, posed.
	for p in [0.33, 0.66, 1.0]:
		enemy._show_charge(p)
		await _save("2-charge-%d" % int(p * 100))
	enemy._show_charge(0.0)
	# The bulb at full glow, tight on the top of the tube.
	enemy._show_charge(1.0)
	var top := _cam(base + toward * 4.0 + side * 1.5 + Vector3.UP * 5.0, base + Vector3.UP * 4.4, 35.0)
	await _save("2-charge-100-top")
	enemy._show_charge(0.0)
	close.make_current()
	for t in root.find_children("*", "Terrain3D", true, false):
		t.set_camera(close)
	top.queue_free()
	# Live: let the lobber run its own clock and fire; a burst of frames through the release.
	enemy.set_physics_process(true)
	var shots := 0
	var t := 0.0
	var last_charge := 0.0
	var saved := 0
	while t < 12.0 and saved < 10:
		await physics_frame
		t += 1.0 / float(Engine.physics_ticks_per_second)
		var charge: float = enemy._muzzle.scale.x - 1.0
		if charge > 0.05 and int(t * 10.0) % 3 == 0 and saved < 6:
			await _save("2-live-%02d" % saved)
			saved += 1
		if last_charge > 0.5 and charge < 0.1:
			shots += 1
			await _save("2-live-release")
			for i in 4:
				await _frames(4)
				await _save("2-live-after-%d" % i)
			saved = 10
		last_charge = charge
	print("STILL live shots ", shots, " after ", snappedf(t, 0.1), " s")
	# (3) play distance: 22 m back, chase height and field of view, charge held at full and at rest.
	enemy.set_physics_process(false)
	enemy._show_charge(0.0)
	var far := _cam(base + toward * 22.0 + Vector3.UP * 4.0, base + Vector3.UP * 2.0, 70.0)
	await _save("3-play-rest")
	enemy._show_charge(1.0)
	await _save("3-play-charged")
	quit(0)
