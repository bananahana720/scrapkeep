# smoke: solo timeout=360s (259 s alone uncapped on a 4-core cloud box at stage/alpha-w23 74f5cff5, 20 checks PASS; killed at the 180 s default cap in every gate chunk w20 to w23)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Director := preload("res://src/world/event_director.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("park_permanent_capacity_test")
var game
var started := []
var fill_s := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var park: Dictionary = game.ctx.terrain.maps[0].park
	var template: Dictionary = park.event_rows.filter(func(row): return row.kind == "flood_fill")[0].duplicate(true)
	fill_s = float(template.effect.fill_s)
	var site: Dictionary = park.park_rows[0].duplicate(true)
	site.merge({"id": "fill_fixture", "at": [340, 110], "y": null, "size": [20, 0.1, 10], "yaw_deg": 0}, true)
	park.park_rows.append(site)
	park.event_rows = []
	for i in Director.PARK_GROUND_CAP + 1:
		var row: Dictionary = template.duplicate(true)
		row.id = "permanent_fill_" + str(i)
		row.site = site.id
		row.live_s = 0.0
		row.trigger = {"on": "clock_tier", "value": 0}
		row.route_change = {"opens": [], "closes": []}
		park.event_rows.append(row)
	game.events.event_started.connect(func(id):
		if id.begins_with("permanent_fill_"):
			started.append(id)
			if started.size() == Director.PARK_GROUND_CAP:
				game.world.set_physics_process(false))
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	game.player.set_frozen(true)
	var safe_position: Vector3 = game.player.ball_position()
	Engine.time_scale = 10.0
	for frame in 3000:
		await physics_frame
		if started.size() >= Director.PARK_GROUND_CAP:
			break
	Engine.time_scale = 1.0
	t.eq("real Game lands the owned ground-cap count while clear", started.size(), Director.PARK_GROUND_CAP)
	var states: Array = game.world.events._park_states
	var live: Array = states.filter(func(s): return not s.weather and s.phase == Director.LIVE)
	var pending: Array = states.filter(func(s): return not s.weather and s.phase != Director.LIVE)
	if live.size() != Director.PARK_GROUND_CAP or pending.size() != 1:
		t.check("stepped capacity fixture has live fills and one waiting row", false)
		game.free()
		quit(t.verdict())
		return
	var candidate: Dictionary = pending[0]
	var before := []
	for state in live:
		before.append(float(state.rise_s))
	game.player._rigid.global_position = Vector3(340, game.ctx.terrain.height(340, 110) + 10, 110)
	game.player.state.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	await _advance_for(live[0], fill_s + 1.0)
	for i in live.size():
		var state: Dictionary = live[i]
		t.check("unsafe fill wall time exceeds authored duration " + state.row.id, state.live_elapsed_s > fill_s)
		# The ball hangs over the site, so the water waits PARK_FLOOD_HOLD_CAP_S for it (W1-148) and then rises around it.
		t.near("unsafe fill delivers only the rise past the wait " + state.row.id, float(state.rise_s), before[i] + fill_s + 1.0 - Director.PARK_FLOOD_HOLD_CAP_S, 0.2)
		t.eq("unsafe permanent fill remains LIVE " + state.row.id, state.phase, Director.LIVE)
		t.eq("permanent fill preserves authored lifetime " + state.row.id, state.row.live_s, 0.0)
	t.check("unsafe permanent fills retain all ground slots beyond fill_s", not game.world.events._park_capacity(candidate))
	t.eq("unsafe capacity prevents extra landing", started.size(), Director.PARK_GROUND_CAP)
	game.player._rigid.global_position = safe_position
	await physics_frame
	await physics_frame
	await _advance_for(live[0], fill_s + 1.0 / Engine.physics_ticks_per_second)
	for state in live:
		t.near("clear fill completes by delivered rise " + state.row.id, float(state.rise_s), fill_s)
		t.eq("settled permanent fill keeps LIVE geometry " + state.row.id, state.phase, Director.LIVE)
		var natural: Dictionary = game.world.event_families.natural.active[state.row.id]
		t.near("settled fill actually reaches authored water depth " + state.row.id, float(natural.depth_m), float(template.effect.depth_m))
	t.check("completed permanent fills release scheduling capacity", game.world.events._park_capacity(candidate))
	# Capacity is now free; the pending on-bar row lands through the ordinary loop.
	await _advance_for(live[0], Director.PARK_BAR_S + 1.0)
	t.eq("pending fill starts only after the original fills settle", started.size(), Director.PARK_GROUND_CAP + 1)
	# Timed rows retain occupancy after transformation; compare the same completed rows.
	for state in live:
		state.row.live_s = float(state.live_elapsed_s) + fill_s
	t.check("completed timed fills keep ground occupancy", not game.world.events._park_capacity(candidate))
	game.free()
	quit(t.verdict())

func _advance_for(state: Dictionary, seconds: float) -> void:
	var target := float(state.live_elapsed_s) + seconds
	game.world.set_physics_process(true)
	while float(state.live_elapsed_s) < target - 0.000001:
		await physics_frame
	game.world.set_physics_process(false)
