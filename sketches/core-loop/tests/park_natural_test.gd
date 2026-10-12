extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const T := preload("res://tests/support/t.gd")
const Events := preload("res://src/core/game_events.gd")
const Audio := preload("res://src/presentation/audio.gd")
const LocalMesh := preload("res://src/world/local_mesh.gd")
const KINDS := ["flood_fill", "drain", "cave_in", "collapse", "impact", "flash_flood", "lightning"]
const FORMS := ["flood_rising", "flood_rising", "cave_in_crumble", "cave_in_crumble", "impact_incoming", "flood_rising", "lightning_charge"]
const FAR := Vector3(100, 1, 100)

class Player:
	extends RefCounted
	var state := {"velocity": Vector3(17, -2, 9), "grounded": true}
	var chain := {"combo": 1}
	var kit := {"line_state": 0}
	func set_velocity_now(v: Vector3, _cause := "") -> void:
		state.velocity = v

class Run:
	extends RefCounted
	var mass := 20
	func lose_scrap(amount: int, _at: Vector3, _cause: String) -> int:
		var lost := mini(amount, mass)
		mass -= lost
		return lost

class Context:
	extends RefCounted
	var player := Player.new()
	var run := Run.new()
	var root: Node3D
	var events: Node
	var spawner = null

class Terrain:
	extends RefCounted
	var maps: Array = []
	var stage := 1
	var flood = null
	var overlays: Array[String] = []
	var geometry: Node3D
	func geometry_root(_stage: int) -> Node3D:
		return geometry
	func map():
		return maps[stage - 1]
	func height(x: float, z: float) -> float:
		var h := 0.0
		for id in overlays:
			h = maxf(h, map().overlay_height(id, x, z, 0.0))
		return h


class FixtureMap:
	extends ParkMap
	func overlay_height(id: String, x: float, z: float, ground: float) -> float:
		if id == "rubble_ramp_before" and ParkMap.footprint_contains(park.park_rows[0], Vector2(x, z)):
			return 1.5
		return super.overlay_height(id, x, z, ground)

class World:
	extends Node3D
	var ctx := Context.new()
	var terrain := Terrain.new()
	var events
	var flood = null
	var terrain_view = null
	var presentation: Node

class Presentation:
	extends Node
	var audio

var t := T.new("park_natural_test")


func _initialize() -> void:
	_run.call_deferred()


func _row(kind: String, form: String) -> Dictionary:
	var water := kind in ["flood_fill", "drain", "flash_flood"]
	var effect := {"depth_m": ParkSchema.MAX_EVENT_WATER_M * 2.0, "fill_s": 2.0, "material": "water"} if water else {"swap": "rubble_ramp", "strike_m": 6.0, "damage": 8.0}
	if kind == "lightning":
		effect.erase("swap")
	return {"id": kind, "kind": kind, "family": "natural", "site": "site",
		"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
		"telegraph": {"lead_s": 5.0, "form": form, "on_bar": false},
		"live_s": 8.0, "effect": effect, "route_change": {"closes": [], "opens": []},
		"hold_clear_m": 1.0, "cooldown_s": 10.0, "once": true,
		"music_cue": {"telegraph": "riser_natural", "land": "drop_natural"}}


func _fixture(row: Dictionary, sound := false, more_rows: Array = [], site_override: Dictionary = {}, with_before := false) -> Array:
	var w := World.new()
	root.add_child(w)
	w.ctx.root = w
	if sound:
		w.ctx.events = Events.new()
		w.add_child(w.ctx.events)
		w.presentation = Presentation.new()
		w.add_child(w.presentation)
		w.presentation.audio = Audio.new()
		w.presentation.add_child(w.presentation.audio)
		w.presentation.audio.setup(w.ctx)
		w.presentation.audio.bake_now()
	var map := FixtureMap.new()
	map.park = {"map": "fixture", "park_rows": [{"id": "site", "at": [0, 0], "y": 0,
		"size": [20, 2, 10], "yaw_deg": 30}], "event_rows": [row] + more_rows, "weather_rows": [],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}]}
	map.park.park_rows[0].merge(site_override, true)
	w.terrain.maps = [map]
	w.terrain.geometry = w
	if with_before:
		w.terrain.overlays.append("rubble_ramp_before")
		var body := LocalMesh.grid(w, "Park_site", Vector2(10, 20), 1.0,
			func(_x, _z): return 1.5, func(_x, _z): return Color.WHITE)
		body.rotation.y = deg_to_rad(30.0)
	w.events = Director.new(823, {}, map, 14.0, Callable(w.terrain, "height"))
	var script: Script = load("res://src/world/events/natural.gd")
	var handler = script.new()
	w.add_child(handler)
	handler.setup(w)
	w.events.register_family("natural", Callable(handler, "handle"))
	return [w, handler]


func _run() -> void:
	if not t.check("natural family exists", FileAccess.file_exists("res://src/world/events/natural.gd")):
		quit(t.verdict())
		return
	for k in KINDS.size():
		var kind: String = KINDS[k]
		var row := _row(kind, FORMS[k])
		var fixture := _fixture(row)
		var w = fixture[0]
		var handler = fixture[1]
		var facts := []
		for i in 52:
			facts.append_array(w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}))
		t.eq(kind + " one telegraph", facts.filter(func(f): return f.kind == "announced").size(), 1)
		t.eq(kind + " one landing", facts.filter(func(f): return f.kind == "started").size(), 1)
		var state: Dictionary = handler.active.get(kind, {})
		t.check(kind + " persistent warning and feedback", state.has("mark") and is_instance_valid(state.get("mark")))
		if kind in ["flood_fill", "drain", "flash_flood"]:
			for i in 25:
				w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true})
			var depth: float = float(state.get("depth_m", -INF))
			var expected_depth := 0.0 if kind == "drain" else minf(float(row.effect.depth_m), ParkSchema.MAX_EVENT_WATER_M)
			t.near(kind + " committed water depth", depth, expected_depth)
			t.check(kind + " uses Flood rendering", state.get("water") != null)
			if state.get("water") != null:
				t.near(kind + " rendered surface agrees", state.water.surface_y(), depth)
				t.eq(kind + " water never brakes", state.water.external_accel(Vector3.ZERO, Vector3(17, 0, 9)), Vector3.ZERO)
		elif kind != "lightning":
			var probe := Vector2(2.37, 0.19).rotated(-deg_to_rad(30.0)) if kind == "impact" else Vector2.ZERO
			t.check(kind + " uses live terrain overlay", w.terrain.overlays.has("rubble_ramp_after") and w.terrain.height(probe.x, probe.y) > 0.0, str(w.terrain.overlays))
			t.check(kind + " prebuilt collider lands", state.get("overlay") != null and state.overlay.visible)
			await physics_frame
			await physics_frame
			var query := PhysicsRayQueryParameters3D.create(Vector3(probe.x, 100, probe.y), Vector3(probe.x, -100, probe.y))
			var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(query)
			t.check(kind + " real collider ray hits", hit.get("collider") == state.get("overlay"), str(hit))
			if not hit.is_empty():
				t.near(kind + " collider and terrain height agree", hit.position.y, w.terrain.height(probe.x, probe.y), 0.001)
		if kind in ["impact", "lightning"]:
			var before: Vector3 = w.ctx.player.state.velocity
			w.events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1, "grounded": true})
			t.eq(kind + " costs scrap armour", w.ctx.run.mass, 12)
			t.eq(kind + " never slows planar velocity", Vector2(w.ctx.player.state.velocity.x, w.ctx.player.state.velocity.z), Vector2(before.x, before.z))
			w.events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1, "grounded": true})
			t.eq(kind + " one hit per landing", w.ctx.run.mass, 12)
			# A separate event with no armour must lift vertically instead.
			var empty := _fixture(row)
			empty[0].ctx.run.mass = 0
			for i in 53:
				empty[0].events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1})
			empty[0].events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1})
			t.check(kind + " lifts without armour", empty[0].ctx.player.state.velocity.y > before.y)
			t.eq(kind + " lift keeps planar speed", Vector2(empty[0].ctx.player.state.velocity.x, empty[0].ctx.player.state.velocity.z), Vector2(before.x, before.z))
			empty[1].release()
			empty[0].free()
		for i in 90:
			facts.append_array(w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}))
		t.eq(kind + " one end", facts.filter(func(f): return f.kind == "ended").size(), 1)
		t.check(kind + " end removes effects", handler.active.is_empty() and w.terrain.overlays.is_empty())
		handler.release()
		w.free()
	_water_lifecycle()
	_geometry_boundaries()
	await _terrain_overlap()
	t.check("all seven kinds tested", t.checks >= 50, str(t.checks))
	quit(t.verdict())


func _water_lifecycle() -> void:
	var fill := _row("flood_fill", "flood_rising")
	fill.live_s = 60.0
	var drain := _row("drain", "flood_rising")
	drain.trigger.value = 2
	drain.live_s = 5.0
	var fixture := _fixture(fill, false, [drain])
	var w = fixture[0]
	var handler = fixture[1]
	for i in 53:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true})
	var state: Dictionary = handler.active.flood_fill
	var held: float = state.depth_m
	for i in 21:
		w.events.advance(0.1, Vector3(0, 1, 0), Vector3.ZERO, {"clock_tier": 1, "grounded": true})
	t.near("grounded ball holds real water rise", state.depth_m, held)
	t.near("grounded hold also holds the renderer", state.water.surface_y(), held)
	for i in 25:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true})
	t.near("water rise resumes after clearance", state.depth_m, ParkSchema.MAX_EVENT_WATER_M)
	for i in 80:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 2, "grounded": true})
	var inside: bool = w.terrain.flood.in_basin(Vector3.ZERO)
	t.check("drain keeps one committed surface", inside and not state.water.visible)
	t.near("drain lowers the existing flooded site", w.terrain.flood.surface_y(), 0.0)
	for i in 40:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 2, "grounded": true})
	w.terrain.flood.in_basin(Vector3.ZERO)
	t.check("drain end restores the prior live water", state.water.visible)
	t.near("restored water material uses its surface", w.terrain.flood.surface_y(), ParkSchema.MAX_EVENT_WATER_M)
	handler.release()
	w.free()


func _terrain_overlap() -> void:
	var first := _row("collapse", "cave_in_crumble")
	first.id = "collapse_first"
	first.live_s = 12.0
	var second := first.duplicate(true)
	second.id = "collapse_second"
	second.trigger.value = 2
	second.live_s = 30.0
	var fixture := _fixture(first, false, [second], {}, true)
	var w = fixture[0]
	var handler = fixture[1]
	var before: Node3D = w.find_child("Park_site", true, false)
	var before_position := before.position
	var before_visible := before.visible
	var probe := Vector2(4, 8).rotated(-deg_to_rad(30.0))
	var prior_height: float = w.terrain.height(probe.x, probe.y)
	var expected_live_height := 1.5 + 2.0 * (8.0 + 10.0) / 20.0
	t.near("shared swap starts on the authored before height", prior_height, 1.5)
	t.check("shared swap prepares one collider for both rows", handler._prepared[first.id].overlay == handler._prepared[second.id].overlay)
	for i in 53:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1})
	for i in 80:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 2})
	var overlay: Node3D = handler._prepared[second.id].overlay
	t.check("shared swap has both live rows", handler.active.has(first.id) and handler.active.has(second.id))
	t.check("shared swap displaces before membership while live", not w.terrain.overlays.has("rubble_ramp_before"))
	for i in 60:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 2})
	t.check("first terrain owner ends while the second stays live", not handler.active.has(first.id) and handler.active.has(second.id))
	t.check("second terrain owner retains visible overlay", overlay.visible and not before.visible)
	t.check("second terrain owner retains after membership", w.terrain.overlays.has("rubble_ramp_after"), str(w.terrain.overlays))
	t.near("second terrain owner retains committed height", w.terrain.height(probe.x, probe.y), expected_live_height)
	await physics_frame
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(probe.x, 100, probe.y), Vector3(probe.x, -100, probe.y))
	var hit: Dictionary = w.get_world_3d().direct_space_state.intersect_ray(query)
	t.check("second terrain owner retains the real collider", hit.get("collider") == overlay, str(hit))
	if not hit.is_empty():
		t.near("second owner ray agrees with the independent ramp", hit.position.y, expected_live_height, 0.001)
	for i in 300:
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 2})
	t.check("final terrain owner restores overlay membership", w.terrain.overlays == ["rubble_ramp_before"], str(w.terrain.overlays))
	t.check("final terrain owner restores before visibility and position", before.visible == before_visible and before.position == before_position and not overlay.visible)
	t.near("final terrain owner restores the prior height", w.terrain.height(probe.x, probe.y), prior_height)
	await physics_frame
	await physics_frame
	hit = w.get_world_3d().direct_space_state.intersect_ray(query)
	t.check("final terrain owner restores the prior collider", hit.get("collider") == before, str(hit))
	if not hit.is_empty():
		t.near("restored collider and prior height agree", hit.position.y, prior_height, 0.001)
	handler.release()
	w.free()


func _mesh_vertices(node: Node3D) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if node is MeshInstance3D:
		for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			points.append(node.global_transform * vertex)
	for child in node.get_children():
		if child is Node3D:
			points.append_array(_mesh_vertices(child))
	return points


func _footprint_mark(label: String, mark: Node3D, half: Vector2, yaw: float, terrain = null) -> void:
	var low := Vector2.INF
	var high := -Vector2.INF
	var corners := [false, false, false, false]
	var clearance := INF
	for point in _mesh_vertices(mark):
		if terrain != null:
			clearance = minf(clearance, point.y - terrain.height(point.x, point.z))
		var local := Vector2(point.x, point.z).rotated(yaw)
		low = low.min(local)
		high = high.max(local)
		for k in 4:
			var expected := Vector2(half.x if k % 2 else -half.x, half.y if k / 2 else -half.y)
			corners[k] = corners[k] or local.distance_to(expected) < 0.0001
	t.near(label + " warning local min X", low.x, -half.x)
	t.near(label + " warning local max X", high.x, half.x)
	t.near(label + " warning local min Z", low.y, -half.y)
	t.near(label + " warning local max Z", high.y, half.y)
	t.check(label + " warning includes all rectangular corners", corners.all(func(found): return found), str(corners))
	if terrain != null:
		t.check(label + " terrain clearance", clearance >= 0.1499, str(clearance))


func _geometry_boundaries() -> void:
	var half := Vector2(5, 10)
	var yaw := deg_to_rad(30.0)
	for kind in ["flood_fill", "collapse"]:
		var row := _row(kind, "flood_rising" if kind == "flood_fill" else "cave_in_crumble")
		var fixture := _fixture(row)
		var w = fixture[0]
		var handler = fixture[1]
		w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1})
		_footprint_mark(kind, handler.active[kind].mark, half, yaw)
		for i in 75:
			w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1})
		var state: Dictionary = handler.active[kind]
		_footprint_mark(kind + " landing", state.mark, half, yaw, w.terrain)
		var inside := (half * 0.95).rotated(-yaw)
		var outside := Vector2(half.x + 0.1, half.y * 0.95).rotated(-yaw)
		if kind == "flood_fill":
			t.check("rotated water wets the long-axis corner", state.water.in_basin(Vector3(inside.x, 0, inside.y)))
			t.check("rotated water excludes outside the width", not state.water.in_basin(Vector3(outside.x, 0, outside.y)))
		else:
			t.check("rotated terrain changes the long-axis corner", w.terrain.height(inside.x, inside.y) > 0.0)
			t.near("rotated terrain excludes outside the width", w.terrain.height(outside.x, outside.y), 0.0)
		handler.release()
		w.free()
	var lightning := _row("lightning", "lightning_charge")
	var fixture := _fixture(lightning, false, [], {"size": [260, 2, 240]})
	var w = fixture[0]
	var handler = fixture[1]
	w.events.advance(0.1, FAR * 10.0, Vector3.ZERO, {"clock_tier": 1})
	var points := _mesh_vertices(handler.active.lightning.mark)
	var extent := Vector2.ZERO
	for point in points:
		extent = extent.max(Vector2(absf(point.x), absf(point.z)))
	t.near("lightning warning X follows requested strike radius", extent.x, float(lightning.effect.strike_m))
	t.near("lightning warning Z follows requested strike radius", extent.y, float(lightning.effect.strike_m))
	for i in 52:
		w.events.advance(0.1, FAR * 10.0, Vector3.ZERO, {"clock_tier": 1})
	w.events.advance(0.1, Vector3(float(lightning.effect.strike_m) + 0.01, 0, 0), Vector3.ZERO, {"clock_tier": 1})
	t.eq("lightning outside strike radius preserves armour", w.ctx.run.mass, 20)
	w.events.advance(0.1, Vector3(float(lightning.effect.strike_m) - 0.01, 0, 0), Vector3.ZERO, {"clock_tier": 1})
	t.eq("lightning inside strike radius costs authored armour", w.ctx.run.mass, 20 - ceili(float(lightning.effect.damage)))
	handler.release()
	w.free()
