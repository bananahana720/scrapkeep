extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Families := preload("res://src/world/events/families.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

var t := T.new("park_events_game_test")
var game
var announced := []
var started := []
var ended := []
var forms := []
var flood_surface_seen := false
var flood_material_seen := false
var flood_max_depth := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		var handlers = game.world.get("event_families") if game.world != null else null
		if handlers is Dictionary and handlers.has("natural"):
			var state: Dictionary = handlers.natural.active.get("plunge_pool_flood", {})
			if state.get("water") != null:
				flood_surface_seen = true
				flood_material_seen = flood_material_seen or game.ctx.terrain.material_at(state.at).get("material") == "water"
				flood_max_depth = maxf(flood_max_depth, float(state.depth_m))


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.events.event_announced.connect(func(id, _lead): announced.append(id))
	game.events.event_started.connect(func(id): started.append(id))
	game.events.event_ended.connect(func(id, _outcome): ended.append(id))
	game.events.world_fact.connect(func(kind, _at): forms.append(kind))
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(4)
	t.eq("real Game uses park_dam", game.ctx.terrain.map().title, "park_dam")
	game.player.set_frozen(true)
	Engine.time_scale = 10.0
	await _frames(900)
	Engine.time_scale = 1.0
	t.check("clock_tier flood telegraphs through the game loop", announced.has("plunge_pool_flood") and forms.has("flood_rising"), str(announced))
	t.check("clock_tier flood lands through the game loop", started.has("plunge_pool_flood") and forms.has("flood_landed"), str(started))
	t.check("clock_tier flood ends through the game loop", ended.has("plunge_pool_flood"), str(ended))
	t.check("real flood uses a live water surface", flood_surface_seen)
	t.check("real terrain resolves the flood as water", flood_material_seen)
	var flood_row: Dictionary = game.ctx.terrain.map().park.event_rows.filter(func(row): return row.id == "plunge_pool_flood")[0]
	var expected_depth := minf(float(flood_row.effect.depth_m), ParkSchema.MAX_EVENT_WATER_M)
	t.near("real flood reaches its capped requested depth", flood_max_depth, expected_depth)
	t.eq("one registration table names every family", Families.SCRIPTS.keys(), ["natural", "fleet", "ancient", "industrial"])
	var warden = game.flow.warden
	t.check("real park Warden exists", is_instance_valid(warden))
	if is_instance_valid(warden):
		game.run.set_max_hp(99999.0)
		var force := 1.0
		while game.combat.punch_of("ram", force) < float(warden.plating):
			force += 0.05
		for chunk in 2:
			for cycle in 2:
				for hit in 30:
					if warden.staggered():
						break
					game.combat.strike(warden, "ram", force)
					await _frames(2)
				game.combat.strike(warden, "ram", force, warden.family_point())
				await _frames(2)
				if warden.chunks_left() <= 3 - chunk:
					break
				Engine.time_scale = 10.0
				await _frames(45)
				Engine.time_scale = 1.0
		t.eq("real combat loses two Warden chunks", warden.chunks_left(), 2)
	Engine.time_scale = 10.0
	await _frames(150)
	Engine.time_scale = 1.0
	t.check("real Warden chunk_2 triggers the park row", announced.has("powerhouse_boiler") and forms.has("boiler_pressure"), str(announced))
	var handlers = game.world.get("event_families")
	t.check("stage owns the loaded natural family", handlers is Dictionary and handlers.has("natural"))
	if handlers is Dictionary and handlers.has("natural"):
		var old = game.world.events
		var first: WeakRef = weakref(handlers.natural)
		game.flow.retry_stage()
		await _frames(3)
		t.check("rebuild unregisters old stage handlers", old._park_families.is_empty(), str(old._park_families.keys()))
		t.check("rebuild releases old stage handlers", first.get_ref() == null)
		t.check("rebuild registers fresh handler", game.world.event_families.has("natural") and game.world.events._park_families.has("natural"))
	game.free()
	t.check("test executes its expected checks", t.checks >= 11, str(t.checks))
	quit(t.verdict())
