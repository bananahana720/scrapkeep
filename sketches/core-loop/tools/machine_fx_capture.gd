extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")


var game
var fx
var out := ""
var camera: Camera3D
var ball := Vector3.ZERO


class Body extends Node3D:
	signal attack_phase(facts: Dictionary)
	signal special_tell(moment: String)
	signal died(at: Vector3, scrap_value: int)
	var kind := "foreman"
	var faction := "fleet"
	var half_height := 1.2
	func cable_ends() -> Array:
		return [global_position + Vector3(0, 3, 0), global_position + Vector3(7, 2, 3)]


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	if out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1600, 900)
	_run.call_deferred()


func _run() -> void:
	seed(1017)
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(999999.0)
	game.player.source = Intent.Scripted.new()
	for i in 120:
		await physics_frame
	game.player.body().freeze = true
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false
	fx = game.find_children("MachineFx", "", true, false)[0]
	camera = Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.far = 1800.0
	ball = game.player.ball_position()
	game.player._visual_root.visible = false
	Density.live().force(0.0)

	var crew: Array = []
	for i in 6:
		var at: Vector3 = _ground(ball + Vector3(cos(i * 0.55 - 1.4) * 14.0, 0, 10 + sin(i * 0.55 - 1.4) * 6.0))
		var enemy: Node3D = game.ctx.spawner.spawn_enemy(["chaser", "lobber", "mag_trapper"][i % 3], at)
		crew.append(enemy)
	await _wait(0.6)
	for enemy in crew:
		if is_instance_valid(enemy):
			_freeze(enemy)
			enemy.attack_phase.emit({"phase": "windup", "progress": 0.8, "row": "", "at": enemy.global_position})
	for id in fx._windups.keys():
		fx._windups[id]["emitter"].amount_ratio = 0.9
	fx._windups.clear()
	var mid: Vector3 = crew[2].global_position
	await _shot("1-pack-windup", mid + Vector3(-4, 4, -9), mid + Vector3(0, 2, 0), 62.0, 0.9)

	var target: Node3D = crew[0]
	game.ctx.events.enemy_struck.emit(target, "ram", 60.0)
	await _shot("2-heavy-hit", target.global_position + Vector3(-5, 3, -6), target.global_position + Vector3(0, 2.5, 0), 55.0, 0.12)

	var elite: Node3D = crew[1]
	elite.set_meta("elite_affix", "stamp")
	var elite_at := elite.global_position
	elite.died.emit(elite_at, 8)
	elite.visible = false
	await _shot("3-elite-clocked-out", elite_at + Vector3(-7, 4, -8), elite_at + Vector3(0, 3, 0), 55.0, 0.35)
	for enemy in crew:
		if is_instance_valid(enemy):
			enemy.queue_free()
	fx.clear()
	await _wait(0.4)

	var foreman := _body("foreman", ball + Vector3(4, 0, 14))
	game.ctx.events.enemy_spawned.emit(foreman, "lobber")
	await _wait(0.8)
	foreman.special_tell.emit("tell")
	await _shot("4-foreman-tell", foreman.global_position + Vector3(-8, 5, -10), foreman.global_position + Vector3(0, 3, 0), 60.0, 0.22)
	foreman.died.emit(foreman.global_position, 6)
	foreman.visible = false
	await _shot("5-foreman-shift-over", foreman.global_position + Vector3(-8, 5, -10), foreman.global_position + Vector3(0, 3, 0), 60.0, 0.3)
	foreman.queue_free()
	fx.clear()

	var linker := _body("linker", ball + Vector3(-4, 0, 14))
	fx.special_moment("linker", "tell", linker)
	await _shot("6-linker-tell", linker.global_position + Vector3(-6, 5, -9), linker.global_position + Vector3(3, 3, 1), 60.0, 0.08)
	linker.queue_free()
	fx.clear()

	var far := _ground(ball + Vector3(0, 0, 22))
	fx.boss_phase("waking", far)
	await _shot("7-waking-phase", far + Vector3(-10, 6, -14), far + Vector3(0, 4, 0), 62.0, 0.18)
	fx.clear()
	await _wait(0.4)

	var dazed := _body("chaser", ball + Vector3(0, 0, 12))
	dazed.faction = "reactor"
	fx.follow("arc_crawl", dazed, 10, 1.2, 4.0)
	fx.follow("daze_halo", dazed, 6, 3.4, 4.0, Color.TRANSPARENT, 4.0)
	fx.word("KRNK", dazed.global_position + Vector3.UP * 4.4, Palette.ANCIENT, true)
	await _shot("8-stagger", dazed.global_position + Vector3(-5, 4, -7), dazed.global_position + Vector3(0, 2.5, 0), 55.0, 0.3)
	dazed.queue_free()
	fx.clear()

	var hull := _ground(ball + Vector3(0, 0, 26))
	fx.boss_fall("brindle", hull)
	await _shot("9-brindle-fall", hull + Vector3(-12, 10, -16), hull + Vector3(0, 4, 0), 62.0, 0.75)
	await _shot("10-end-of-shift", hull + Vector3(-12, 10, -16), hull + Vector3(0, 6, 0), 62.0, 1.05)
	quit(0)


func _flat_spot(start: Vector3) -> Vector3:
	var best := start
	var best_spread := INF
	for gx in range(-4, 5):
		for gz in range(-4, 5):
			var c := start + Vector3(gx * 20.0, 0, gz * 20.0)
			var lo := INF
			var hi := -INF
			for sx in range(-3, 4):
				for sz in range(-3, 4):
					var y: float = _ground(c + Vector3(sx * 5.0, 0, sz * 5.0)).y
					lo = minf(lo, y)
					hi = maxf(hi, y)
			if hi - lo < best_spread:
				best_spread = hi - lo
				best = _ground(c)
	print("flat spot ", best, " spread ", best_spread)
	return best


func _body(kind: String, near: Vector3) -> Body:
	var body := Body.new()
	body.kind = kind
	game.ctx.root.add_child(body)
	body.global_position = _ground(near)
	return body


func _freeze(enemy: Node3D) -> void:
	enemy.process_mode = Node.PROCESS_MODE_DISABLED


func _ground(at: Vector3) -> Vector3:
	return game.ctx.terrain.drop_point(at.x, at.z, 0.0)


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _shot(id: String, eye: Vector3, look: Vector3, fov: float, settle: float) -> void:
	eye.y = maxf(eye.y, _ground(eye).y + 3.0)
	camera.global_position = eye
	camera.look_at(look, Vector3.UP)
	camera.fov = fov
	await _wait(settle)
	for label in root.find_children("*", "Label3D", true, false):
		if not fx.root.is_ancestor_of(label):
			label.visible = false
	for node in root.find_children("*", "CanvasItem", true, false):
		node.visible = false
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(id + ".png"))
	print("shot ", id)
