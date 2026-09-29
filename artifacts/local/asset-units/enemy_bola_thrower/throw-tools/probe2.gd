extends SceneTree
# Scratch readback: replays asset_capture's setup and --call chain (same parse_call, same callv), printing the thrower's state after every call.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Cap := preload("res://tools/asset_capture.gd")
var specs: Array = []
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--call="):
			specs.append(a.trim_prefix("--call="))
	call_deferred("_run")
func _state(tag: String, e, game) -> void:
	var ax: Vector3 = (e._bola.global_basis.y).normalized()
	var tele = e.telegraph()
	print("STATE ", tag, " phase=", e.phase, " _t=", snappedf(e._t, 0.000001), " _spin=", snappedf(float(e.get("_spin") if e.get("_spin") != null else -1.0), 0.000001), " bola_top=", e._bola.top_level, " bola_pos=", e._bola.global_position, " thrower=", e.global_position, " yaw=", snappedf(e.rotation.y, 0.0001), " floor=", e.is_on_floor(), " tele=", tele != null, " ball=", game.player.ball_position(), " axis=", ax, " expo_front_rear=", snappedf(absf(ax.z), 0.0001), " expo_side=", snappedf(absf(ax.x), 0.0001), " held=", e._holding(), " pvel=", game.player.planar_velocity(), " rigid_v=", game.player.body().linear_velocity, " rigid_frozen=", game.player.body().freeze)
func _run() -> void:
	seed(280928)
	var game = Game.new()
	game.name = "Game"
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	var e = game.combat.spawn_enemy("bola_thrower", Vector3(80, 29.74855, -100))
	e.name = "Spawn_bola_thrower"
	game.player.source = Intent.Scripted.new()
	print("player body path=", game.player.body().get_path())
	for i in 120:
		await physics_frame
	_state("settled", e, game)
	for spec: String in specs:
		var call := Cap.parse_call(spec)
		var node := root.get_node_or_null(call["path"])
		if not call["ok"] or node == null or not node.has_method(call["method"]):
			printerr("call target missing: ", spec)
			quit(2)
			return
		node.callv(call["method"], call["args"])
		for i in call["frames"]:
			await physics_frame
		_state(spec.get_slice(":", 1) + ":" + str(call["args"]), e, game)
	Cap.freeze_tree(self)
	game.player.body().freeze = true
	_state("frozen", e, game)
	quit()
