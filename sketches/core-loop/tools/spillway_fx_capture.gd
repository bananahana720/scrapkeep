extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")


const SIM_FRAMES := 90
const LANDMARK_FRAMES := 900

var _out := ""
var _seeds: Array = [31, 32]
var _game


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--seeds="):
			_seeds = Array(arg.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await process_frame
	await process_frame
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.ctx.run.run_seed_override = _seeds[0]
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	for k in _seeds.size():
		if k > 0:
			_game.ctx.run.run_seed_override = _seeds[k]
			_game.ctx.run.begin(_game.ctx.run.class_def)
		for stage in [1, 2]:
			_game.flow.enter_stage(stage, Vector3.ZERO, false)
			await physics_frame
			var fx: Node3D = _game.ctx.terrain.geometry_root(stage).get_node("SpillwayScenery/SpillwayFx")
			for i in LANDMARK_FRAMES:
				if not fx.is_processing():
					break
				await process_frame
			for a: Node3D in fx.placed:
				if k > 0 and a.set_id != "landmark_dam":
					continue
				await _shoot(a, "s%d_seed%d_%s" % [stage, _seeds[k], a.set_id])
			if k == 0 and stage == 1:
				await _wake()
	_game.queue_free()
	await process_frame
	quit(0)


func _shoot(a: Node3D, label: String) -> void:
	var size: float = {"landmark_dam": 120.0, "landmark_penstock_tower": 90.0, "spill_falls": 45.0}.get(a.set_id, 35.0)
	var at := a.global_position
	var out: Vector3 = (a.global_transform.basis * Vector3(0.6, 0.0, 1.0)).normalized() * size
	var eye := at + out
	var ground: float = _game.ctx.terrain.height(eye.x, eye.z)
	eye.y = maxf(at.y + size * 0.25, ground + 6.0)
	await _frame(eye, at, func(): a.set_range(0.0, true), label)


func _frame(eye: Vector3, target: Vector3, each: Callable, label: String) -> void:
	var rig: Node = _game.ctx.camera
	rig.process_mode = Node.PROCESS_MODE_DISABLED
	var fx = WorldFx.current
	var ctx = fx._ctx
	fx._ctx = null
	var cam := Camera3D.new()
	cam.far = 4000.0
	cam.fov = 60.0
	root.add_child(cam)
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	cam.make_current()
	for i in SIM_FRAMES:
		each.call()
		cam.make_current()
		await process_frame
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(_out.path_join(label + ".png"))
	print("spillway_fx_capture: %s eye %s target %s" % [label, eye, target])
	cam.queue_free()
	fx._ctx = ctx
	rig.process_mode = Node.PROCESS_MODE_INHERIT
	await process_frame


func _wake() -> void:
	var fx = WorldFx.current
	var ball: Vector3 = _game.player.ball_position()
	var heading := Vector3(1, 0, 0)
	var water := ball.y - 0.9
	var eye := ball - heading * 9.0 + Vector3(2.5, 3.0, 4.0)
	var steer := func():
		fx.steer_wake(ball, water, heading * 14.0)
	await _frame(eye, ball, steer, "s1_seed%d_wake" % _seeds[0])
