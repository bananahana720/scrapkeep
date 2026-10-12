extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const Director := preload("res://src/world/event_director.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("ground_slump_game_test")
var game
var announced := []
var started := []

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
	game.events.event_announced.connect(func(id, _lead): announced.append(id))
	game.events.event_started.connect(func(id): started.append(id))
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(3, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	t.eq("real Game uses exported park_pit", game.ctx.terrain.map().title, "park_pit")
	t.check("ground_slump exists in WORLD_ROWS", not Kinds.world_row("ground_slump").is_empty())
	t.check("ground_slump has its canonical landing mapping", Director.PARK_LAND_FACTS.has("ground_slump"))
	var states: Array = game.world.events._park_states
	t.check("real Game director accepts authored tailings_slump", states.any(func(state): return state.row.id == "tailings_slump"))
	game.player.set_frozen(true)
	Engine.time_scale = 10.0
	for block in 100:
		for frame in 30:
			await physics_frame
		if started.has("tailings_slump"):
			break
	Engine.time_scale = 1.0
	t.check("tailings_slump telegraphs through real Game loop", announced.has("tailings_slump"), str(announced))
	t.check("tailings_slump lands through real Game loop", started.has("tailings_slump"), str(started))
	var state: Dictionary = game.world.event_families.natural.active.get("tailings_slump", {})
	t.check("tailings slide has a landed terrain effect", state.get("overlay") != null and state.get("phase", "") in ["land", "live"])
	var open := {}
	for row_state in game.world.events._park_states:
		if row_state.phase == Director.LIVE and not row_state.weather:
			for route in row_state.row.route_change.opens:
				open[route] = true
	t.check("authored tailings_slide route opens", open.has("tailings_slide"), str(open))
	game.free()
	quit(t.verdict())
