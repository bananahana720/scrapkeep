extends SceneTree


const Game := preload("res://src/game.gd")
const AppShell := preload("res://src/core/app_shell.gd")

var game
var out := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or AppShell.headless():
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(3)
		return
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _shot(id: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(out.path_join("%s.png" % id)) != OK:
		push_error("detour_still: could not save %s" % id)
		quit(4)


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await _frames(60)
	var acts = game.world.activities
	acts.set_physics_process(false)
	for site in acts.sites:
		site.started = false
		if site.rule.finishes == "trade":
			site.visible = false
	var cage = game.world.rescue.cage("rivet")
	if cage != null:
		cage.fire()
		await _frames(int(ceil(1.5 * Engine.physics_ticks_per_second)) + 60)
	if game.hud.get("first_steps") != null:
		game.hud.first_steps.modulate.a = 0.0
	game.hud._engaged = false
	var ball: Vector3 = game.player.shown_position()
	var warden = game.flow.warden
	var best = null
	for site in game.hud.edge_markers.unfinished_sites():
		if site.rule.finishes == "trade":
			continue
		var ahead := Vector2(site.global_position.x - ball.x, site.global_position.z - ball.z).dot(Vector2(warden.global_position.x - ball.x, warden.global_position.z - ball.z)) > 0.0
		if ahead and (best == null or ball.distance_to(site.global_position) < ball.distance_to(best.global_position)):
			best = site
	game.hud._process(0.0)
	var named = game.hud.get("_detour_site")
	if is_instance_valid(named):
		best = named
	if best == null:
		push_error("detour_still: no site ahead")
		quit(5)
		return
	await _shot("1_named")
	best.started = true
	best.surge_live = true
	await _shot("2_live")
	best.surge_live = false
	best.done = true
	game.events.activity_done.emit(String(best.id), best.global_position)
	await _frames(2)
	await _shot("3_done")
	quit(0)
