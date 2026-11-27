extends SceneTree


const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const AppShell := preload("res://src/core/app_shell.gd")

var game
var fx
var out := ""
var pilot := 0
var shots: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--pilot="):
			pilot = int(arg.trim_prefix("--pilot="))
	if out.is_empty() or AppShell.headless():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	_run.call_deferred()


func _run() -> void:
	seed(1717)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(pilot)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 90:
		await physics_frame
	game.player.body().freeze = true
	fx = game.presentation.player_fx
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = layer.name == "ImpactFrameLayer"
	Engine.time_scale = 0.15
	var ball: Vector3 = game.player.ball_position()
	var chase: Camera3D = game.camera.cam
	var back: Vector3 = chase.global_basis.z
	back.y = 0.0
	back = back.normalized()
	var cam := Camera3D.new()
	game.add_child(cam)
	cam.fov = 60.0
	cam.far = 1500.0
	cam.current = true
	cam.look_at_from_position(ball + back * 7.5 + Vector3.UP * 3.2 + back.cross(Vector3.UP) * 1.5, ball + Vector3.UP * 0.8)
	fx.camera = {"cam": cam}
	var side: Vector3 = cam.global_basis.x
	var enemy = game.ctx.spawner.spawn_enemy("chaser", ball + side * 4.5 - cam.global_basis.z * 3.0)
	await _frames(10)

	_reset()
	game.events.enemy_struck.emit(enemy, "claw", 20.0)
	game.events.harpoon_smashed.emit(enemy, enemy.global_position, 25.0)
	await _frames(4)
	await _shot("hit-small")

	for id in ["frost_vane", "arc_coil", "chain_arc", "frost_vane", "hot_rivets", "arc_coil",
			"long_spool", "frost_vane", "tread_plating", "chain_arc", "boost_coil", "arc_coil"]:
		game.run.parts.append(id)
	fx._evolutions = 3
	fx.refresh_might()
	fx.might = 1.0
	await _frames(6)
	_reset()
	game.events.enemy_struck.emit(enemy, "claw", 20.0)
	await _frames(3)
	fx._last_frame = -1.0e9
	game.events.harpoon_smashed.emit(enemy, enemy.global_position, 25.0)
	await _shot("hit-mighty")
	await _frames(3)
	await _shot("hit-mighty-after")

	_reset()
	fx.pose = {"velocity": side * 65.0}
	_stream([fx._flecks, fx._embers], side * 65.0)
	await _shot("overdrive-ignite")
	await _frames(25)
	await _shot("overdrive")

	_reset()
	_stream([fx._flecks, fx._embers], Vector3.ZERO)
	fx.pose = {"velocity": side * 30.0, "normal": Vector3(0.0, 0.7, 0.71).normalized(), "grounded": true}
	_stream([fx._carve], side * 30.0)
	await _frames(25)
	await _shot("carve")

	_reset()
	fx.column(Palette.BRASS)
	fx.word("heft_up", fx._beside_ball())
	await _frames(2)
	await _shot("heft-up")

	_reset()
	for node in get_nodes_in_group("telegraph") + get_nodes_in_group(Threat.GROUP):
		if node is Node3D:
			node.visible = false
	fx.pose = {"velocity": -back * 20.0}
	game.player.dunk.store(30.0, "still", game.player.class_def.id, game.player.class_color())
	await _frames(4)
	await _shot("dunk-charge")
	var until: float = game.player.dunk.charge["until"]
	game.player.dunk.clock = until - game.player.dunk.WINDOW * 0.2
	await _frames(2)
	await _shot("dunk-charge-late")
	chase.current = true
	game.player.dunk.clock = until - game.player.dunk.WINDOW * 0.95
	await _frames(4)
	await _shot("dunk-charge-play")
	game.player.dunk.clock = until - game.player.dunk.WINDOW * 0.2
	await _frames(2)
	await _shot("dunk-charge-play-late")
	cam.current = true
	game.player.dunk.clear("reset")

	var file := FileAccess.open(out.path_join("shots.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"pilot": pilot, "adapter": RenderingServer.get_video_adapter_name(), "shots": shots,
		"spawned": fx.spawned, "limits": "Compatibility renderer on llvmpipe, clock at 0.15x, frozen ball posed through PlayerFx.pose."}, "\t"))
	quit()


func _stream(emitters: Array, velocity: Vector3) -> void:
	for p: GPUParticles3D in emitters:
		var pm := p.process_material as ParticleProcessMaterial
		pm.gravity = Vector3(0, pm.gravity.y, 0) - velocity * 6.0
		p.restart()


func _reset() -> void:
	fx.pose = {}
	fx.clear()
	fx._last_word = -1.0e9
	fx._word_seen.clear()
	fx._last_frame = -1.0e9
	fx._last_boon = -1.0e9


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _shot(id: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join(id + ".png")
	if image.save_png(path) != OK:
		quit(3)
	shots.append({"id": id, "sha256": FileAccess.get_sha256(path)})
