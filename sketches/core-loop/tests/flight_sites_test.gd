# smoke: solo timeout=300s
extends SceneTree

# FLIGHT-SITES (perf lane, flume entry): where stages build on workers (a played game, a frame-capture bot run),
# the launch toward the next park stage builds that stage's activity sites during the flight, under a hidden and
# disabled holder, and the entry takes every one it would build again (activities._on_launched, _adopt). The 4080
# probe on c3abb730 (scrapkeep#512) had the flume entry's sites at 37 ms of 105.
#
# Plays the park table headless through the real flow with SimClock.ticks off, as a played game, and checks:
#   - the launch's own tick plans nothing; the flight plans, then builds the flume's sites, with no body in the physics
#     space and nothing shown;
#   - the entry takes all of them, shows them, and Interact knows their devices and posts;
#   - the taken sites equal a stage 2 retry's own build node for node (class, name, place) and read the same graph;
#   - a run change in the flight (parts, health, class) leaves them untaken;
#   - a retry of stage 1 during the flight drops the flight's sites and builds stage 1 as before;
#   - a bot run (SimClock.ticks) builds nothing ahead.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600

var _game
var _t := T.new("flight_sites_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	SimClock.ticks = false
	seed(11)
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	await physics_frame
	await physics_frame
	_game.run.run_seed_override = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _ticks(SETTLE_TICKS)
	_t.check("the run is on park stage 1", _game.flow.stage() == 1, "stage %d" % _game.flow.stage())
	var activities = _game.world.activities
	var terrain = _game.ctx.terrain
	terrain.prepare(2)
	var waited := 0
	while not terrain.is_ready(2) and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1
	_t.check("stage 2's ground is ready before the launch, as in play", terrain.is_ready(2), "%d ticks" % waited)

	# A retry of stage 1 in the flight: the flight's sites go, stage 1 builds as before.
	_launch()
	await _ticks(20)
	var holder = activities._ahead.get("holder")
	_t.check("the flight starts stage 2's sites", is_instance_valid(holder) and activities._ahead.built.size() > 0,
		"%s" % [activities._ahead.get("built", []).size()])
	_game.flow.retry_stage()
	await _ticks(2)
	_t.check("a retry in the flight drops the flight's sites", not is_instance_valid(holder) or holder.is_queued_for_deletion(), "")
	_t.check("the retry built stage 1 itself", _game.flow.stage() == 1 and activities.last_entry_adopted == 0 and not activities.sites.is_empty(),
		"stage %d adopted %d sites %d" % [_game.flow.stage(), activities.last_entry_adopted, activities.sites.size()])

	# The launch: stage 2's sites are built in the flight and taken whole at the entry.
	_launch()
	_t.check("the launch's own tick plans nothing (the kick's frame)", not activities._ahead.is_empty() and activities._ahead.plan.is_empty(), "")
	await _ticks(activities.AHEAD_PLAN_TICKS + 1)
	print("flight_sites_test: the flight's plan took %.1f ms" % (activities.last_ahead_plan_usec / 1000.0))
	var plan_size: int = activities._ahead.plan.sites.size() if not activities._ahead.is_empty() else 0
	var ticks := 0
	while activities._ahead.get("built", []).size() < plan_size and _game.flow.state_name() == "launch" and ticks < 200:
		await physics_frame
		ticks += 1
	holder = activities._ahead.get("holder")
	print("flight_sites_test: the flight's builds [%s]" % ", ".join(activities.last_ahead_steps))
	_t.check("the flight built every planned site before the entry", plan_size > 0 and activities._ahead.built.size() == plan_size
		and _game.flow.state_name() == "launch", "%d of %d, %s after %d ticks" % [activities._ahead.get("built", []).size(), plan_size, _game.flow.state_name(), ticks])
	_t.check("the flight's sites are hidden and out of the physics space", is_instance_valid(holder) and not holder.visible
		and holder.process_mode == Node.PROCESS_MODE_DISABLED and _bodies_in_space(holder) == 0, "%d bodies in space" % _bodies_in_space(holder))
	# A run change in the flight (a part, a health step) moves prices and rewards: no site is taken then.
	var max_hp: float = _game.run.max_hp
	_game.run.max_hp += 10
	var stale = activities._adopt(activities._ahead, 0, activities._ahead.plan.sites[0])
	_game.run.max_hp = max_hp
	_t.check("a run change in the flight leaves the flight's sites untaken", stale == null, "%s" % [stale])
	while _game.flow.state_name() == "launch" and ticks < WAIT_TICKS_MAX:
		await physics_frame
		ticks += 1
	_t.check("the launch entered stage 2", _game.flow.stage() == 2, "stage %d %s" % [_game.flow.stage(), _game.flow.state_name()])
	_t.check("the entry took every site the flight built", activities.last_entry_adopted == plan_size and activities.sites.size() == plan_size,
		"adopted %d of %d, sites %d" % [activities.last_entry_adopted, plan_size, activities.sites.size()])
	_t.check("the taken sites show and run", is_instance_valid(holder) and holder.visible and holder.process_mode == Node.PROCESS_MODE_INHERIT
		and activities.sites.all(func(s): return s.is_visible_in_tree()), "")
	var interact = _game.ctx.root.get_node("Interact")
	var armed := true
	var devices := 0
	for s in activities.sites:
		for device in s.trade_devices:
			armed = armed and interact.devices.has(device)
			devices += 1
		if s.stake_post != null:
			armed = armed and interact.devices.has(s.stake_post)
			devices += 1
	_t.check("Interact knows the taken sites' devices and posts", armed and devices > 0, "%d devices" % devices)
	var taken := _signature(activities.sites)
	await _ticks(2)
	_t.check("the taken sites' bodies are in the physics space", _bodies_in_space(holder) > 0, "%d" % _bodies_in_space(holder))

	# A retry builds stage 2 at the entry, from the same plan: the same nodes in the same places.
	_game.flow.retry_stage()
	await _ticks(2)
	_t.check("the stage 2 retry built its own sites", _game.flow.stage() == 2 and activities.last_entry_adopted == 0, "adopted %d" % activities.last_entry_adopted)
	var built := _signature(activities.sites)
	_t.check("the taken sites equal the entry's own build node for node", taken == built and taken.size() > plan_size,
		"%d vs %d nodes, first difference %s" % [taken.size(), built.size(), _first_difference(taken, built)])

	# A bot run builds nothing ahead.
	SimClock.ticks = true
	activities._on_launched(Vector3.ZERO)
	_t.check("a bot run builds nothing ahead", activities._ahead.is_empty(), "")
	SimClock.ticks = false

	_game.queue_free()
	await process_frame
	quit(_t.verdict())


func _launch() -> void:
	_game.player.reset_to(_game.ctx.terrain.spawn_point(_game.flow.stage()) + Vector3.UP * 2.0, Vector3(0.0, 0.0, 6.0))
	_game.flow._set_state(_game.flow.GATES)
	_game.ctx.events.launched.emit(Vector3(0.0, 8.0, 12.0))


func _bodies_in_space(node: Node) -> int:
	if not is_instance_valid(node):
		return 0
	var n := 0
	if node is CollisionObject3D and PhysicsServer3D.body_get_space(node.get_rid()).is_valid():
		n += 1
	for child in node.get_children():
		n += _bodies_in_space(child)
	return n


# Every node under the sites, in order: class, name without Godot's @ suffix, and place to the centimetre.
func _signature(sites: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for s in sites:
		out.append("graph %s" % [s.graph.get_instance_id() if s.graph != null else 0])
		_walk(s, out)
	return out


func _walk(node: Node, out: PackedStringArray) -> void:
	var line := "%s %s" % [node.get_class(), String(node.name).get_slice("@", 0) if not String(node.name).begins_with("@") else String(node.name).get_slice("@", 1)]
	if node is Node3D:
		line += " %s" % [(node as Node3D).global_position.snapped(Vector3.ONE * 0.01)]
	out.append(line)
	for child in node.get_children():
		_walk(child, out)


static func _first_difference(a: PackedStringArray, b: PackedStringArray) -> String:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return "%d: %s | %s" % [i, a[i], b[i]]
	return "none" if a.size() == b.size() else "length"


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
