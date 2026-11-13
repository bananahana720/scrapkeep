# smoke: solo timeout=300s
extends SceneTree

# VICTORY-SITES (perf lane, Dig entry): a world boss's victory starts the next world's first stage's activity sites,
# where stages are built on workers, as a launch does for the next park stage (flight_sites_test). That stage is
# entered from the arena with no launch, so its sites were built on the entry tick (about 5 ms of the Dig's, cloud,
# 13 Nov 2026). Plays the park table headless through the real flow with SimClock.ticks off, as a played game:
#   - the victory after stage 2 (world 1's last) builds stage 3's sites under a hidden, disabled holder;
#   - entering stage 3 takes every one of them;
#   - a victory after the run's last stage, and a bot run (SimClock.ticks), build nothing ahead.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

const SETTLE_TICKS := 30
const WAIT_TICKS_MAX := 3600

var _game
var _t := T.new("victory_sites_test")


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
	var flow = _game.flow
	var activities = _game.world.activities
	var terrain = _game.ctx.terrain
	flow.enter_stage(2, Vector3.ZERO, false)
	await _ticks(2)
	_t.check("stage 2 closes world 1", flow.stage() == 2 and _game.ctx.stages.is_world_last(2), "stage %d" % flow.stage())
	terrain.prepare(3)
	var waited := 0
	while not terrain.is_ready(3) and waited < WAIT_TICKS_MAX:
		await physics_frame
		waited += 1
	_t.check("stage 3's ground is ready by the victory, as in play", terrain.is_ready(3), "%d ticks" % waited)

	# As _on_boss_defeated opens it: the victory holds VICTORY_SECONDS before the next world's entry.
	flow._victory_left = flow.VICTORY_SECONDS
	flow._set_state(flow.VICTORY)
	var holder = activities._ahead.get("holder")
	_t.check("the victory starts stage 3's sites", int(activities._ahead.get("stage", 0)) == 3 and is_instance_valid(holder), "%s" % [activities._ahead.get("stage")])
	await _ticks(activities.AHEAD_PLAN_TICKS + 1)
	var plan_size: int = activities._ahead.plan.sites.size() if not activities._ahead.is_empty() else 0
	var ticks := 0
	while not activities._ahead.is_empty() and activities._ahead.built.size() < plan_size and ticks < 200:
		await physics_frame
		ticks += 1
	_t.check("the victory built every planned site", plan_size > 0 and activities._ahead.built.size() == plan_size,
		"%d of %d after %d ticks" % [activities._ahead.get("built", []).size(), plan_size, ticks])
	_t.check("the victory's sites are hidden and disabled", is_instance_valid(holder) and not holder.visible
		and holder.process_mode == Node.PROCESS_MODE_DISABLED and flow.state_name() == "victory", flow.state_name())
	while flow.state_name() == "victory" and ticks < WAIT_TICKS_MAX:
		await physics_frame
		ticks += 1
	_t.check("the run entered stage 3", flow.stage() == 3, "stage %d" % flow.stage())
	_t.check("the entry took every site the victory built", activities.last_entry_adopted == plan_size and activities.sites.size() == plan_size,
		"adopted %d of %d, sites %d" % [activities.last_entry_adopted, plan_size, activities.sites.size()])

	# The run's last stage has no next stage to build.
	var last: int = _game.ctx.stages.DEFS.size() if "DEFS" in _game.ctx.stages else 0
	_game.run.stage = last
	activities._on_flow_changed("victory")
	_t.check("a victory that ends the run builds nothing ahead", last == 0 or activities._ahead.is_empty(), "last stage %d" % last)
	_game.run.stage = 2
	SimClock.ticks = true
	activities._on_flow_changed("victory")
	_t.check("a bot run builds nothing ahead", activities._ahead.is_empty(), "")
	SimClock.ticks = false

	_game.queue_free()
	await process_frame
	quit(_t.verdict())


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame
