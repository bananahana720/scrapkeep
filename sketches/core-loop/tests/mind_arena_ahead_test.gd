extends SceneTree

# The Mind's boss entry (4080, scrapkeep#241: 254 to 274 ms): the stage exit compiled mind.gd
# (89 ms on the cloud), then loaded the arena kit and the Mind's GLBs and painted the sky
# panorama (80 to 150 ms). Flow now reads the boss script on a loader thread while the world's
# last stage is in its gates, and the script's prepare_arena asks for the kit and GLBs on loader
# threads (real renderers only) and paints the panorama on a worker; its warm_arena then rebuilds
# the kit a part a tick on the main thread. Checked: the script is read, prepare_arena ran and the
# kit was rebuilt ahead before the module exists; headless (this test), no GLB goes to a loader
# thread; entering the arena takes the kit and the worker's panorama, and that panorama equals one
# painted on the main thread.

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
	_t.check("headless, prepare_arena asks no loader thread for a GLB (the dummy rasterizer's mesh RIDs are not thread-safe)",
		requested.is_empty(), str(requested))
	var sizes := [Dress._kit_ahead.size()]
	waited = 0
	while Dress._kit_ahead.size() < Dress.PARTS.size() and waited < WAIT_TICKS_MAX:
		await physics_frame
		sizes.append(Dress._kit_ahead.size())
		waited += 1
	var steps := range(1, sizes.size()).map(func(i): return sizes[i] - sizes[i - 1])
	_t.check("the gates rebuilt every kit part ahead, at most one a tick, before the module exists",
		Dress._kit_ahead.size() == Dress.PARTS.size() and steps.all(func(d): return d <= 1) and not Dress._kit_ahead.values().has(null) and not flow._row_modules.has(MIND),
		"%d ticks, last sizes %s" % [sizes.size() - 1, sizes.slice(-8)])
	_t.check("prepare_arena paints the sky panorama on a worker", Dress._panorama_task >= 0, str(Dress._panorama_task))
	if Dress._panorama_task >= 0:
		WorkerThreadPool.wait_for_task_completion(Dress._panorama_task)
		# Waited here, so the dress only takes the image it left.
		Dress._panorama_task = -1
		var painted: Image = Dress._panorama_out.get("image")
		var here := Dress._paint_panorama()
		_t.check("the worker's panorama equals one painted on the main thread", painted != null and painted.get_data() == here.get_data())
	var ahead_meshes: Array = Dress._kit_ahead.values()
	flow.enter_boss(Vector3.ZERO)
	var mod = Harness.module(_game, WORLD)
	var left := paths.filter(func(p): return ResourceLoader.load_threaded_get_status(p) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE)
	_t.check("entering the arena took every file read ahead and every kit part rebuilt ahead", left.is_empty() and Dress._kit_ahead.is_empty(), "%s, %d parts left" % [left, Dress._kit_ahead.size()])
	var used := _dress_meshes(mod.pad.get_node_or_null(Dress.NODE_NAME) if mod != null else null)
	var unused := ahead_meshes.filter(func(m): return not used.has(m))
	_t.check("the dress draws every kit part rebuilt ahead (none rebuilt again at the entry)", not ahead_meshes.is_empty() and unused.is_empty(),
		"%d of %d ahead parts not drawn" % [unused.size(), ahead_meshes.size()])
	_t.check("entering the arena took the worker's panorama", Dress._panorama_task == -1 and Dress._panorama_out.is_empty() and Dress._sky_material != null)
	_t.check("the arena and the Mind are dressed", mod != null and mod.pad.get_node_or_null(Dress.NODE_NAME) != null and mod._dress != null)
	_game.queue_free()
	await physics_frame
	quit(_t.verdict())


# Every mesh the dress draws, from its mesh views and its multimeshes.
func _dress_meshes(dress: Node) -> Array:
	var out := []
	if dress == null:
		return out
	for view in dress.find_children("*", "MeshInstance3D", true, false):
		out.append(view.mesh)
	for view in dress.find_children("*", "MultiMeshInstance3D", true, false):
		if view.multimesh != null:
			out.append(view.multimesh.mesh)
	return out


func _ahead_paths() -> Array:
	var out := []
	for key in Dress.PARTS:
		out.append(Dress.dir.path_join(Dress.PARTS[key][0]))
	out.append(MindDress.base_path)
	out.append(MindDress.kit_path)
	return out
