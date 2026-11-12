extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Families := preload("res://src/world/events/families.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")

var t := T.new("park_events_game_test")
var game
var announced := []
var places := {}
var started := []
var ended := []
var forms := []
var flood_surface_seen := false
var flood_material_seen := false
var flood_max_depth := 0.0
var flash_checked := false
var flash_expected_depth := 0.0


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
			var flash: Dictionary = handlers.natural.active.get("west_wash_flash_flood", {})
			if not flash_checked and flash.get("water") != null and float(flash.depth_m) >= flash_expected_depth - 0.0001:
				flash_checked = true
				_check_flash_surface(flash)


func _mesh_triangles(water) -> Array:
	var mesh: Mesh = water._plane.mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var triangles := []
	for k in range(0, indices.size(), 3):
		triangles.append([water._plane.global_transform * vertices[indices[k]],
			water._plane.global_transform * vertices[indices[k + 1]], water._plane.global_transform * vertices[indices[k + 2]]])
	return triangles


func _mesh_y(triangles: Array, point: Vector2) -> float:
	for triangle in triangles:
		var a: Vector3 = triangle[0]
		var b: Vector3 = triangle[1]
		var c: Vector3 = triangle[2]
		var edge_b := Vector2(b.x - a.x, b.z - a.z)
		var edge_c := Vector2(c.x - a.x, c.z - a.z)
		var offset := point - Vector2(a.x, a.z)
		var determinant := edge_b.cross(edge_c)
		if absf(determinant) < 0.0000001:
			continue
		var u := offset.cross(edge_c) / determinant
		var v := edge_b.cross(offset) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return a.y + u * (b.y - a.y) + v * (c.y - a.y)
	return -INF


func _check_flash_surface(state: Dictionary) -> void:
	var triangles := _mesh_triangles(state.water)
	var row: Dictionary = game.ctx.terrain.map().park.event_rows.filter(func(r): return r.id == "west_wash_flash_flood")[0]
	var expected_depth := minf(float(row.effect.depth_m), ParkSchema.MAX_EVENT_WATER_M)
	var terrain = game.ctx.terrain
	var max_depth := -INF
	for triangle in triangles:
		for vertex in triangle + [(triangle[0] + triangle[1] + triangle[2]) / 3.0]:
			max_depth = maxf(max_depth, vertex.y - terrain.height(vertex.x, vertex.z))
	t.check("real west_wash rendered local depth stays within schema cap", max_depth <= ParkSchema.MAX_EVENT_WATER_M + 0.0001, "maximum local depth %s" % max_depth)
	var regression := Vector2(-63, 74)
	t.near("real west_wash depth at (-63, 74) follows its capped request", _mesh_y(triangles, regression) - terrain.height(regression.x, regression.y), expected_depth)
	var half := Vector2(float(state.site.size[2]), float(state.site.size[0])) * 0.5
	var centre := Vector2(float(state.site.at[0]), float(state.site.at[1]))
	var checked := 0
	var agrees := true
	var bounded := true
	for j in 17:
		for i in 5:
			var point := Vector2(lerpf(-half.x, half.x, (i + 0.5) / 5.0), lerpf(-half.y, half.y, (j + 0.5) / 17.0)).rotated(-deg_to_rad(float(state.site.yaw_deg))) + centre
			var y := _mesh_y(triangles, point)
			bounded = bounded and is_finite(y) and y - terrain.height(point.x, point.y) <= ParkSchema.MAX_EVENT_WATER_M + 0.0001
			var material: Dictionary = terrain.material_at(Vector3(point.x, y, point.y))
			agrees = agrees and material.get("material") == "water" and absf(float(material.surface_y) - y) <= 0.0001
			checked += 1
	t.check("real west_wash footprint samples obey local depth cap", bounded and checked == 85, str(checked))
	t.check("real west_wash material queries agree with the rendered triangles", agrees)


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.events.event_announced.connect(func(id, _lead, at):
		announced.append(id)
		places[id] = at)
	game.events.event_started.connect(func(id): started.append(id))
	game.events.event_ended.connect(func(id, _outcome): ended.append(id))
	game.events.world_fact.connect(func(kind, _at): forms.append(kind))
	game.flow.press_start()
	game.flow.choose_class(1)
	await _frames(4)
	t.eq("real Game uses park_dam", game.ctx.terrain.map().title, "park_dam")
	var flash_row: Dictionary = game.ctx.terrain.map().park.event_rows.filter(func(row): return row.id == "west_wash_flash_flood")[0]
	flash_expected_depth = minf(float(flash_row.effect.depth_m), ParkSchema.MAX_EVENT_WATER_M)
	game.player.set_frozen(true)
	Engine.time_scale = 10.0
	for block in 120:
		await _frames(30)
		if ended.has("plunge_pool_flood") and flash_checked:
			break
	Engine.time_scale = 1.0
	t.check("clock_tier flood telegraphs through the game loop", announced.has("plunge_pool_flood") and forms.has("flood_rising"), str(announced))
	# The announcement carries where the event lands (PF-16), so the edge marker can point there.
	var flood_at: Vector3 = places.get("plunge_pool_flood", Vector3.INF)
	t.check("the flood's announcement carries its place", flood_at.is_finite()
		and game.ctx.terrain.map().play_rect.has_point(Vector2(flood_at.x, flood_at.z)), str(flood_at))
	t.check("clock_tier flood lands through the game loop", started.has("plunge_pool_flood") and forms.has("flood_landed"), str(started))
	t.check("clock_tier flood ends through the game loop", ended.has("plunge_pool_flood"), str(ended))
	t.check("real flood uses a live water surface", flood_surface_seen)
	t.check("real terrain resolves the flood as water", flood_material_seen)
	t.check("real clock_tier west_wash flash flood reaches full fill", flash_checked)
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
				for tick in 600:
					if not warden.staggered():
						break
					await _frames(1)
				Engine.time_scale = 1.0
				t.check("real Warden closes cracked stagger before the next cycle", not warden.staggered(), "stagger left %s" % warden.stagger_left())
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
