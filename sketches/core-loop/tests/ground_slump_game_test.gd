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
var announced_s := -1.0
var started_s := -1.0
var warning_samples := []
var forms := []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("named KD3 park_pit export is present", FileAccess.file_exists("res://src/world/park/park_pit.json")):
		quit(t.verdict())
		return
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.events.event_announced.connect(func(id, _lead):
		announced.append(id)
		if id == "tailings_slump": announced_s = game.world.events.stage_time)
	game.events.event_started.connect(func(id):
		started.append(id)
		if id == "tailings_slump": started_s = game.world.events.stage_time)
	game.events.world_fact.connect(func(kind, _at): forms.append(kind))
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
	if not states.any(func(state): return state.row.id == "tailings_slump"):
		game.free()
		quit(t.verdict())
		return
	var authored: Dictionary = states.filter(func(state): return state.row.id == "tailings_slump")[0].row
	t.eq("authored lead remains six seconds", authored.telegraph.lead_s, 6.0)
	t.check("authored landing remains on bar", authored.telegraph.on_bar)
	t.eq("authored slump riser is preserved", authored.music_cue.telegraph, "riser_natural")
	t.eq("authored slump drop is preserved", authored.music_cue.land, "drop_collapse")
	game.player.set_frozen(true)
	Engine.time_scale = 10.0
	for block in 100:
		for frame in 30:
			await physics_frame
			var live: Dictionary = game.world.event_families.natural.active.get("tailings_slump", {})
			if live.get("phase", "") == "telegraph":
				_warning(live)
		if started.has("tailings_slump"):
			break
	Engine.time_scale = 1.0
	t.check("tailings_slump telegraphs through real Game loop", announced.has("tailings_slump"), str(announced))
	t.check("tailings_slump lands through real Game loop", started.has("tailings_slump"), str(started))
	t.check("slump lead precedes landing", started_s - announced_s >= float(authored.telegraph.lead_s), str(started_s - announced_s))
	t.near("slump lands on the canonical downbeat", fposmod(started_s, Director.PARK_BAR_S), 0.0, 0.2)
	t.check("slump sight and sound facts read canonical forms", forms.has(authored.telegraph.form) and forms.has(Director.PARK_LAND_FACTS[authored.telegraph.form]), str(forms))
	t.check("slump warning has dust and crack meshes", warning_samples.size() > 2)
	if warning_samples.size() > 2:
		t.check("dust curtain lifts during authored warning", warning_samples[-1][0] > warning_samples[0][0] + 0.5, str([warning_samples[0], warning_samples[-1]]))
		t.check("crack crawls during authored warning", warning_samples[-1][1] > warning_samples[0][1] + 10.0, str([warning_samples[0], warning_samples[-1]]))
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


func _warning(state: Dictionary) -> void:
	var dust = state.mark.get_node_or_null("DustCurtain")
	var crack = state.mark.get_node_or_null("CrawlingCrack")
	if dust == null or crack == null:
		return
	var height := -INF
	var low := INF
	var high := -INF
	for vertex in dust.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point: Vector3 = dust.global_transform * vertex
		height = maxf(height, point.y - game.ctx.terrain.height(point.x, point.z))
	for vertex in crack.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point: Vector3 = crack.global_transform * vertex
		low = minf(low, point.z)
		high = maxf(high, point.z)
	warning_samples.append([height, high - low])
