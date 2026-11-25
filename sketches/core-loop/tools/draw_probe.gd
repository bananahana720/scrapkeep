extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")


const SETTLE := 120
const HIDDEN_SETTLE := 10
const SAMPLES := 60
const CAP_S := 285.0
const EXIT_GRACE_MS := 15000

var _stage := 1
var _seed := 31
var _dist := 120.0
var _at := Vector3(0, 41, -3)
var _game
var _done := false
var _backstop := Thread.new()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--stage="):
			_stage = int(v)
		elif arg.begins_with("--seed="):
			_seed = int(v)
		elif arg.begins_with("--dist="):
			_dist = float(v)
		elif arg.begins_with("--at="):
			var p := v.split(",")
			_at = Vector3(float(p[0]), float(p[1]), float(p[2]))
	create_timer(CAP_S, true, false, true).timeout.connect(func():
		if not _done:
			print("draw_probe: timed out after %d s" % int(CAP_S))
			_finish(2))
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
	_game.ctx.run.run_seed_override = _seed
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_game.flow.enter_stage(_stage, Vector3.ZERO, false)
	await physics_frame
	var stage_root: Node3D = _game.ctx.terrain.geometry_root(_stage)
	var landmark: Node3D = null
	for i in 1200:
		var rows := stage_root.get_node_or_null("ParkRows")
		if rows != null and rows.get("landmark") is Node3D:
			landmark = rows.get("landmark")
			break
		await process_frame
	if landmark == null:
		print("draw_probe: no landmark on stage %d" % _stage)
		_finish(1)
		return
	for i in 30:
		await process_frame
	var target := landmark.global_transform * _at
	var eye := target + (landmark.global_transform.basis * Vector3(0.6, 0.0, 1.0)).normalized() * _dist
	eye.y = maxf(target.y + _dist * 0.25, _game.ctx.terrain.height(eye.x, eye.z) + 6.0)
	_game.ctx.camera.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera3D.new()
	cam.far = 4000.0
	cam.fov = 70.0
	root.add_child(cam)
	cam.global_position = eye
	cam.look_at(target, Vector3.UP)
	var fx := stage_root.get_node_or_null("SpillwayScenery/SpillwayFx")
	_report("all", await _sample(cam))
	if fx != null:
		fx.visible = false
		for a: Node3D in fx.placed:
			a.visible = false
		_report("spillway_fx_hidden", await _sample(cam, HIDDEN_SETTLE))
	_finish(0)


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_backstop.start(func():
		OS.delay_msec(EXIT_GRACE_MS)
		OS.kill(OS.get_process_id()))
	if is_instance_valid(_game):
		_game.queue_free()
	quit(code)


func _report(label: String, sample: Dictionary) -> void:
	sample.merge({"probe": label, "stage": _stage, "seed": _seed, "driver": RenderingServer.get_current_rendering_driver_name()})
	print("draw_probe: ", JSON.stringify(sample))


func _sample(cam: Camera3D, settle := SETTLE) -> Dictionary:
	var draws: Array = []
	var objects: Array = []
	for i in settle + SAMPLES:
		cam.make_current()
		await process_frame
		if i >= settle:
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	draws.sort()
	objects.sort()
	var emitting := 0
	for p: GPUParticles3D in root.find_children("*", "GPUParticles3D", true, false):
		if p.is_visible_in_tree() and p.emitting:
			emitting += 1
	return {"draws_median": draws[SAMPLES / 2], "draws_max": draws[-1], "objects_median": objects[SAMPLES / 2], "emitting": emitting}
