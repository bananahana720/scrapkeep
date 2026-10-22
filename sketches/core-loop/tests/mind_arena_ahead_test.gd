extends SceneTree

# The Mind's boss entry (4080, scrapkeep#241: 254 to 274 ms): the stage exit compiled mind.gd
# (89 ms on the cloud), then loaded the arena kit and the Mind's GLBs and painted the sky
# panorama (80 to 150 ms). Flow now reads the boss script on a loader thread while the world's
# last stage is in its gates, and the script's prepare_arena asks for the kit and GLBs on loader
# threads and paints the panorama on a worker. Checked: the script is read and prepare_arena ran
# before the module exists; entering the arena takes every file read ahead and the worker's
# panorama, and that panorama equals one painted on the main thread.

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Dress := preload("res://src/presentation/arena_mind_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const T := preload("res://tests/support/t.gd")

const MIND := "res://src/boss/mind.gd"
const WORLD := 3
const WAIT_TICKS_MAX := 600

var _t := T.new("mind_arena_ahead_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	Harness.boot(_game)
	var flow = _game.flow
	flow.enter_stage(_game.ctx.stages.last_of(WORLD), Vector3.ZERO, false)
	_t.eq("the Mind's row names its own script", String(flow.boss_row(WORLD).get("script", "")), MIND)
	flow._set_state(flow.GATES)
	var waited := 0
	while not flow._boss_reads.get(MIND) is Script and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1
	_t.check("the last stage's gates read mind.gd on a loader thread before the module exists",
		flow._boss_reads.get(MIND) is Script and not flow._row_modules.has(MIND), "after %d ticks: %s" % [waited, flow._boss_reads])
	var paths := _ahead_paths()
	var requested := paths.filter(func(p): return ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_t.check("prepare_arena asked for the arena kit and the Mind's GLBs on loader threads", requested.size() == paths.size(),
		"%d of %d: %s" % [requested.size(), paths.size(), requested])
	_t.check("prepare_arena paints the sky panorama on a worker", Dress._panorama_task >= 0, str(Dress._panorama_task))
	if Dress._panorama_task >= 0:
		WorkerThreadPool.wait_for_task_completion(Dress._panorama_task)
		# Waited here, so the dress only takes the image it left.
		Dress._panorama_task = -1
		var painted: Image = Dress._panorama_out.get("image")
		var here := Dress._paint_panorama()
		_t.check("the worker's panorama equals one painted on the main thread", painted != null and painted.get_data() == here.get_data())
	flow.enter_boss(Vector3.ZERO)
	var mod = Harness.module(_game, WORLD)
	var left := paths.filter(func(p): return ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_t.check("entering the arena took every file read ahead", left.is_empty(), str(left))
	_t.check("entering the arena took the worker's panorama", Dress._panorama_task == -1 and Dress._panorama_out.is_empty() and Dress._sky_material != null)
	_t.check("the arena and the Mind are dressed", mod != null and mod.pad.get_node_or_null(Dress.NODE_NAME) != null and mod._dress != null)
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


func _ahead_paths() -> Array:
	var out := []
	for key in Dress.PARTS:
		out.append(Dress.dir.path_join(Dress.PARTS[key][0]))
	out.append(MindDress.base_path)
	out.append(MindDress.kit_path)
	return out
