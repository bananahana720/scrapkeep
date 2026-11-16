extends SceneTree
# SCRATCH ONLY (PC lane job BI, 14 Nov 2026): never for the repo's tests or a game branch.
# The swatter and hooker look for PR 1021, set up as lobber_look.gd (job BH): slice table, frozen ball,
# one enemy --dist m off. (1) a close-up at rest; (2) the wind-up posed through _warn and _t at 0, 1/3, 2/3
# and 1, then the strike pose, then a live burst through a real attack; (3) play distance (22 m, chase fov).
# Run once with --models=tripo and once without; --tag names the files, --kind picks the enemy.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SIZE := Vector2i(1920, 1080)

var out := ""
var tag := ""
var kind := ""
var dist := 6.0
var game

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--kind="):
			kind = arg.trim_prefix("--kind=")
		elif arg.begins_with("--dist="):
			dist = float(arg.trim_prefix("--dist="))
	if out.is_empty() or tag.is_empty() or kind.is_empty():
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
	root.get_texture().get_image().save_png("%s/%s-%s-%s.png" % [out, kind, tag, name])
	print("STILL ", kind, "-", tag, "-", name)

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

func _pose_at(enemy, p: float) -> void:
	enemy._t = p * enemy.warn_seconds
	var tele = enemy.telegraph()
	if tele != null:
		tele.set_progress(enemy._warn_progress())
	enemy._pose()

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
	for e in get_nodes_in_group("enemy"):
		e.free()
	game.presentation.hide_ui()
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.visible = false
	var ball: Vector3 = game.player.ball_position()
	var at: Vector3 = ball + Vector3(dist, 0.0, 0.0)
	var enemy = game.combat.spawn_enemy(kind, game.ctx.terrain.drop_point(at.x, at.z, 2.1))
	for i in 90:
		if enemy.is_on_floor():
			break
		await _frames(1)
	enemy.hp = 100000.0
	enemy.set_physics_process(false)
	await _frames(5)
	var base: Vector3 = enemy.global_position
	var toward := (ball - base)
	toward.y = 0.0
	toward = toward.normalized()
	var side := toward.cross(Vector3.UP).normalized()
	var mid := base + Vector3.UP * 1.6
	for i in 30:
		enemy._pose()
	# (1) close-up at rest, from the ball's side a little off axis.
	var close := _cam(base + toward * 6.0 + side * 3.0 + Vector3.UP * 2.6, mid, 50.0)
	await _save("1-rest-close")
	# (2) the wind-up, posed: commit the lane toward the ball and step the wind-up clock.
	enemy._begin_windup(ball - base)
	for p in [0.0, 0.33, 0.66, 1.0]:
		enemy._clock = p * enemy.WINDUP
		for i in 30:
			enemy._pose()
		await _save("2-warn-%03d" % int(p * 100))
	# Side-on at full wind-up: the fin flare is the claim under test.
	var side_cam := _cam(base + side * 6.0 + Vector3.UP * 1.8, mid, 45.0)
	await _save("2-warn-100-side")
	var high := _cam(base + toward * 7.0 + side * 5.0 + Vector3.UP * 7.0, base + toward * 3.0, 55.0)
	await _save("2-warn-100-high")
	# (3) play distance: 22 m back from the ball side, chase height and field of view.
	var far := _cam(base + toward * 22.0 + Vector3.UP * 4.0, base + Vector3.UP * 1.5, 70.0)
	await _save("3-play-warn")
	enemy._end_attack(enemy.State.CHASE)
	for i in 30:
		enemy._pose()
	await _save("3-play-rest")
	quit(0)
