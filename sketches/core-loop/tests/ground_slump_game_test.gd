extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Kinds := preload("res://src/core/event_kinds.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Director := preload("res://src/world/event_director.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("ground_slump_game_test")
var game
var announced := []
var started := []
var announced_s := -1.0
var started_s := -1.0
# Music bar grid the director booked the landing on, read at the announcement (KE8 moved landings onto it).
var landing_grid := {}
var warning_samples := []
var forms := []
var geometry_samples := []
var low_tread := -40.0
var fill_s := 4.0
var collapse_depth := 20.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var has_pit := FileAccess.file_exists("res://src/world/park/park_pit.json")
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.events.event_announced.connect(func(id, _lead, _at):
		announced.append(id)
		if id == "tailings_slump":
			announced_s = game.world.events.stage_time
			landing_grid = game.presentation.audio._park_transport_snapshot.duplicate())
	game.events.event_started.connect(func(id):
		started.append(id)
		if id == "tailings_slump":
			started_s = game.world.events.stage_time
			# Freeze event updates on the landing callback so the physics server can sync the first collider.
			game.world.set_physics_process(false))
	game.events.world_fact.connect(func(kind, _at): forms.append(kind))
	game.flow.press_start()
	game.flow.choose_class(1)
	var terrain = game.ctx.terrain
	var index := 2 if has_pit else 0
	var map = terrain.maps[index]
	var park: Dictionary = map.park
	var row: Dictionary
	if has_pit:
		row = park.event_rows.filter(func(r): return r.id == "tailings_slump")[0]
	else:
		row = park.event_rows[0].duplicate(true)
		row.merge({"id": "tailings_slump", "kind": "collapse", "family": "natural", "site": "bench_fixture",
			"trigger": {"on": "clock_tier", "value": 0}, "telegraph": {"lead_s": 6.0, "form": "ground_slump", "on_bar": true},
			"effect": {"depth_m": 20.0, "fill_s": 4.0, "swap": "tailings_slide_ramp"}, "live_s": 0.0,
			"route_change": {"closes": [], "opens": []}, "music_cue": {"telegraph": "riser_natural", "land": "drop_collapse"}}, true)
		park.event_rows = [row]
		low_tread = 300.0
		# Known stepped-bench fixture mirrors KD3's 374..376 face. No authored park data is edited.
		var site: Dictionary = park.park_rows[0].duplicate(true)
		site.merge({"id": "bench_fixture", "at": [337.5, 110], "y": null, "size": [140, 0.1, 40], "yaw_deg": 0}, true)
		park.park_rows.append(site)
		for j in range(ceili((30.0 + ParkTerrain.HALF) / ParkTerrain.STEP), floori((190.0 + ParkTerrain.HALF) / ParkTerrain.STEP) + 1):
			for i in range(ceili((340.0 + ParkTerrain.HALF) / ParkTerrain.STEP), floori((390.0 + ParkTerrain.HALF) / ParkTerrain.STEP) + 1):
				var x := -ParkTerrain.HALF + i * ParkTerrain.STEP
				terrain._heights[index][j * ParkTerrain.SIDE + i] = low_tread + float(row.effect.depth_m) * clampf((x - 374.0) / 2.0, 0.0, 1.0)
	# Runtime proposal only. The coordinator owns addition of effect.face to KD3's park row.
	row.effect.face = {"at": [365.0, 110.0], "size": [140.0, 20.0, 22.0], "yaw_deg": 0.0}
	fill_s = float(row.effect.fill_s)
	collapse_depth = float(row.effect.depth_m)
	game.flow.enter_stage(index + 1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	t.eq("real Game uses named park or stepped-bench fixture", game.ctx.terrain.map().title, "park_pit" if has_pit else "park_dam")
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
	for frame in 3000:
		await physics_frame
		var live: Dictionary = game.world.event_families.natural.active.get("tailings_slump", {})
		if live.get("phase", "") == "telegraph":
			await process_frame
			if live.phase == "telegraph":
				_warning(live)
		if started.has("tailings_slump"):
			break
	Engine.time_scale = 1.0
	t.check("tailings_slump telegraphs through real Game loop", announced.has("tailings_slump"), str(announced))
	t.check("tailings_slump lands through real Game loop", started.has("tailings_slump"), str(started))
	t.check("slump lead precedes landing", started_s - announced_s >= float(authored.telegraph.lead_s), str(started_s - announced_s))
	# Since KE8 (1f09c265) the director books park landings on the live music bar grid, whose origin is the
	# audio clock's next bar, not stage time zero. The downbeat is judged on the grid as booked at the
	# announcement: at Engine.time_scale 10 the audio clock does not speed up, so the grid read later drifts.
	t.check("landing read the music bar grid", landing_grid.has("bar_s") and landing_grid.has("bar_origin_s"), str(landing_grid))
	var grid_bar := float(landing_grid.get("bar_s", Director.PARK_BAR_S))
	var grid_phase := fposmod(started_s - float(landing_grid.get("bar_origin_s", 0.0)), grid_bar)
	t.near("slump lands on the canonical downbeat", minf(grid_phase, grid_bar - grid_phase), 0.0, 0.2)
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
	if has_pit:
		t.check("authored tailings_slide route opens as a scheduling fact", open.has("tailings_slide"), str(open))
	await _geometry(state)
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


func _sample_geometry(state: Dictionary, label: String, elapsed: float) -> void:
	# Endpoints specified independently of the handler: (354, low) to (376, low+depth).
	var points := [Vector2(354, 110), Vector2(360, 110), Vector2(366, 110), Vector2(372, 110), Vector2(376, 110)]
	var vertices: PackedVector3Array = state.overlay.get_child(0).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var progress := clampf(elapsed / fill_s, 0.0, 1.0)
	for point in points:
		var original := low_tread + collapse_depth * clampf((point.x - 374.0) / 2.0, 0.0, 1.0)
		var ramp: float = low_tread + collapse_depth * (point.x - 354.0) / (376.0 - 354.0)
		var expected := lerpf(original, ramp, progress)
		t.near(label + " independent height at " + str(point), game.ctx.terrain.height(point.x, point.y), expected)
		var matching := []
		for v in vertices:
			var p: Vector3 = state.overlay.global_transform * v
			if absf(p.x - point.x) < 0.0001 and absf(p.z - point.y) < 0.0001:
				matching.append(p.y)
		t.check(label + " mesh at " + str(point), not matching.is_empty() and matching.all(func(y): return absf(y - expected) < 0.0001), str(matching))
		t.near(label + " collider triangles at " + str(point), _collider_y(state.overlay, point), expected, 0.001)
	t.near(label + " lower tread outside footprint", game.ctx.terrain.height(352, 110), low_tread)
	t.near(label + " upper tread outside footprint", game.ctx.terrain.height(378, 110), low_tread + collapse_depth)

func _collider_y(body: Node3D, point: Vector2) -> float:
	var vertices: PackedVector3Array = body.get_child(1).shape.get_faces()
	for k in range(0, vertices.size(), 3):
		var a: Vector3 = body.global_transform * vertices[k]
		var b: Vector3 = body.global_transform * vertices[k + 1]
		var c: Vector3 = body.global_transform * vertices[k + 2]
		var ba := Vector2(b.x - a.x, b.z - a.z)
		var ca := Vector2(c.x - a.x, c.z - a.z)
		var pa := point - Vector2(a.x, a.z)
		if absf(ba.cross(ca)) < 0.0000001: continue
		var u := pa.cross(ca) / ba.cross(ca)
		var v := ba.cross(pa) / ba.cross(ca)
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return -INF

func _real_ray(label: String, progress: float) -> void:
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(366, low_tread + collapse_depth + 10, 110), Vector3(366, low_tread - 10, 110))
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	var expected := low_tread + collapse_depth * (366.0 - 354.0) / 22.0 * progress
	t.check(label + " real physics ray hits", not hit.is_empty())
	if not hit.is_empty(): t.near(label + " real ray matches independent ramp", hit.position.y, expected, 0.001)

func _geometry(state: Dictionary) -> void:
	var dstate: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "tailings_slump")[0]
	t.near("first landing probe is at zero elapsed", float(dstate.live_elapsed_s), 0.0)
	_sample_geometry(state, "first landing frame", 0.0)
	await _real_ray("first landing frame", 0.0)
	for target in [fill_s * 0.5, fill_s]:
		game.world.set_physics_process(true)
		while float(dstate.live_elapsed_s) < target - 0.000001:
			await physics_frame
		game.world.set_physics_process(false)
		t.near("authored duration probe is at requested elapsed", float(dstate.live_elapsed_s), target)
		_sample_geometry(state, "elapsed %s" % target, target)
		await _real_ray("elapsed %s" % target, target / fill_s)
