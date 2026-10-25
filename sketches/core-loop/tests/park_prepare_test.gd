extends SceneTree

# Rule (KB4b, the KB4 merge's follow-up in docs/decisions.tsv): the next park stage's build
# starts when the current stage's Warden is engaged (world.gd hears warden_engaged and calls
# terrain.prepare(stage + 1)), not on the landing, so the launch finds it built and the landing
# starts no second build; a stage with no Warden starts it when its gates open. When terrain
# frees a park stage, world.gd drops that stage's cached Contraptions node, so the next park
# stage and a rebuilt stage each get a fresh one.
# Fixture: a three-stage table of park_test (park_swap_test's), a World node wired to the
# terrain and a real event bus without the rest of the game. No check here is timed.

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const World := preload("res://src/world/world.gd")
const Context := preload("res://src/core/context.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const RunState := preload("res://src/core/run_state.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const TABLE := {"DEFS": [{"stage": 1, "world": 1, "map": "park_test"}, {"stage": 2, "world": 1, "map": "park_test"},
	{"stage": 3, "world": 1, "map": "park_test"}]}
const BUILD_FRAMES_MAX := 6000

var t := T.new("park_prepare_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera; without one it prints an ERROR line.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var events := GameEvents.new()
	root.add_child(events)
	var ctx := Context.new()
	ctx.events = events
	ctx.run = RunState.new(events)
	ctx.tuning = Tuning.new()
	var terrain = Terrain.new(TABLE)
	SimClock.ticks = false
	terrain.build(holder)
	ctx.terrain = terrain
	var first_scatter = terrain.geometry_root(1).get_node_or_null("GroundScatter")
	t.check("played: stage 1's scatter builds on worker threads", first_scatter != null and not first_scatter.is_ready())
	for n in 3:
		await process_frame
	var world := World.new()
	world.ctx = ctx
	world.terrain = terrain
	# Without the hooks the checks below still run, so a red run names each broken rule.
	if t.check("world.gd wires the terrain's prepare and free hooks", world.has_method("_wire_terrain") and terrain.has_signal("stage_freed")):
		world._wire_terrain()

	# Landing on stage 1 builds nothing for stage 2 yet.
	ctx.run.stage = 1
	terrain.use(1)
	world._add_contraptions()
	var first: Node = world.contraptions.get(1)
	t.check("stage 1 carries its contraptions", first != null and is_instance_valid(first))
	t.check("landing on stage 1 does not start stage 2's build", terrain.park_ground(2) == null)

	# The Warden wakes on stage 1: stage 2's build starts at that moment.
	events.warden_engaged.emit(1)
	var second_ground = terrain.park_ground(2)
	t.check("warden_engaged on stage 1 starts stage 2's build", second_ground != null and holder.get_node_or_null("Stage2") != null)
	t.check("stage 2 builds on worker threads (not done on the spot)", second_ground != null and not second_ground.is_ready())
	events.warden_engaged.emit(1)
	t.check("a second engage starts no second build", terrain.park_ground(2) == second_ground)
	await _wait_ready(terrain, 2)
	t.check("stage 2 finished before the launch", terrain.is_ready(2))
	# Built ahead on worker threads, its contraptions follow the ground a device a frame
	# (world._process), so none of them lands in the entry frame.
	t.check("stage 2's contraptions start once its ground is built", world._building.has(2) and not world.contraptions.has(2))
	var ahead: Node = world._building.get(2)
	var calls := 0
	while world._building.has(2) and calls < 100:
		world._process(0.0)
		calls += 1
	t.check("stage 2's contraptions add a device a frame, then join the cache",
		ahead != null and world.contraptions.get(2) == ahead and calls == ahead.map.contraptions.size() + 1, "%d frames" % calls)

	# The launch lands on stage 2: the ground already built is the one used, and no build of
	# stage 3 starts on the landing.
	ctx.run.stage = 2
	terrain.use(2)
	t.check("landing on stage 2 uses the ground built at the engage", terrain.park_ground(2) == second_ground)
	t.check("landing on stage 2 starts no build of stage 3", terrain.park_ground(3) == null)
	t.check("stage 1 left memory", terrain.park_ground(1) == null)
	t.check("the freed stage 1's Contraptions node left the cache", not world.contraptions.has(1) and world.contraptions.get(1) == null)
	world._add_contraptions()
	var second: Node = world.contraptions.get(2)
	t.check("stage 2 has its own fresh Contraptions node", second != null and is_instance_valid(second) and second != first
		and terrain.geometry_root(2).is_ancestor_of(second))

	# A second consecutive park stage: a stage with no Warden starts the next build when its
	# gates open, and freeing stage 2 drops its node too.
	events.flow_changed.emit("gates")
	var third_ground = terrain.park_ground(3)
	t.check("the gates opening on stage 2 start stage 3's build", third_ground != null)
	await _wait_ready(terrain, 3)
	ctx.run.stage = 3
	terrain.use(3)
	t.check("landing on stage 3 uses the ground built before the launch", terrain.park_ground(3) == third_ground)
	t.check("the freed stage 2's Contraptions node left the cache", not world.contraptions.has(2))
	var pending: Node = world._building.get(3)
	world._add_contraptions()
	var third: Node = world.contraptions.get(3)
	t.check("stage 3 has a fresh Contraptions node", third != null and is_instance_valid(third) and third != second and third != first)
	t.check("landing finishes the contraptions still building ahead", pending != null and third == pending and not third.unbuilt()
		and not world._building.has(3))
	events.warden_engaged.emit(3)
	t.check("engaging on the table's last stage asks for no stage past it", terrain.range_errors.is_empty(), str(terrain.range_errors.keys()))

	# A new run back on stage 1 rebuilds stage 1: its contraptions are rebuilt, never the freed node.
	await process_frame
	ctx.run.stage = 1
	terrain.use(1)
	t.check("the new run frees stage 3 and drops its node", terrain.park_ground(3) == null and not world.contraptions.has(3))
	world._add_contraptions()
	var again: Node = world.contraptions.get(1)
	t.check("the rebuilt stage 1 has a fresh, live Contraptions node", again != null and is_instance_valid(again) and again != first
		and terrain.geometry_root(1).is_ancestor_of(again))
	await _check_tick_builds(holder)
	_finish(holder, events, world)


# A bot run (SimClock.ticks) builds a prepared park stage whole in the frame prepare() is called,
# so the tick it lands on is the same on every run whatever the CPU load.
func _check_tick_builds(holder: Node3D) -> void:
	SimClock.ticks = true
	var ticked = Terrain.new(TABLE)
	var parent := Node3D.new()
	holder.add_child(parent)
	ticked.build(parent)
	var scatter = ticked._roots[0].get_node_or_null("GroundScatter")
	t.check("ticks: stage 1's scatter is built at setup", scatter != null and scatter.is_ready())
	ticked.prepare(2)
	var ground = ticked.park_ground(2)
	# _roots, not geometry_root(): geometry_root() finishes a build still in progress.
	var root = ticked._roots[1]
	var rows = root.get_node_or_null("ParkRows") if root != null else null
	var scatter2 = root.get_node_or_null("GroundScatter") if root != null else null
	t.check("ticks: prepare(2) builds stage 2's ground on the spot", ground != null and ground.is_ready())
	t.check("ticks: prepare(2) places stage 2's rows on the spot", rows != null and rows.is_ready(), str(rows))
	t.check("ticks: prepare(2) attaches stage 2's scatter on the spot", scatter2 != null and scatter2.is_ready())
	t.check("ticks: stage 2 is not built threaded, so its contraptions wait for the entry", not ticked.built_threaded(2))
	SimClock.ticks = false
	await process_frame
	parent.queue_free()


func _wait_ready(terrain, index: int) -> void:
	var frames := 0
	while not terrain.is_ready(index) and frames < BUILD_FRAMES_MAX:
		await process_frame
		frames += 1


func _finish(holder: Node, events: Node, world: Node) -> void:
	for n in 3:
		await process_frame
	world.free()
	holder.queue_free()
	events.queue_free()
	await process_frame
	quit(t.verdict())
