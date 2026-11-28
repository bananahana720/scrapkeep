extends SceneTree
# smoke: solo timeout=360s

const T := preload("res://tests/support/t.gd")
const MODEL := "res://src/world/pockets/pocket_draw.gd"
const Library := preload("res://src/world/pockets/pocket_library.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Map := preload("res://src/world/park/park_map.gd")
const Park := preload("res://src/core/park_defs.gd")
const Rules := preload("res://tools/park_graph.gd")
const Trade := preload("res://src/world/trade_pockets.gd")
const Modifier := preload("res://src/world/events/stage_modifier.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Secrets := preload("res://src/core/secrets.gd")
class MeasuredGraph extends "res://src/world/park/park_graph.gd":
	var footprint_scans := {}
	func box_nodes(lo: Vector2, hi: Vector2) -> PackedInt32Array:
		var span := hi - lo
		for side in Library.FOOTPRINTS.values():
			if span.is_equal_approx(Vector2.ONE * (side + Graph.STEP_M * 2.0)):
				var key := [lo, hi]
				footprint_scans[key] = footprint_scans.get(key, 0) + 1
		return super.box_nodes(lo, hi)

var t := T.new("pocket_draw_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("draw implementation exists", FileAccess.file_exists(MODEL)):
		quit(t.verdict())
		return
	var tool = load("res://tools/park_graph.gd")
	if "--arm-only" in OS.get_cmdline_user_args():
		t.check("draw arm implementation exists", tool.has_method("draw_arm"))
		quit(t.verdict())
		return
	if "--detour-only" in OS.get_cmdline_user_args():
		_detours(tool.draw_arm("all", 1000, 200))
		quit(t.verdict())
		return
	if "--runtime-only" in OS.get_cmdline_user_args():
		await _runtime([])
		quit(t.verdict())
		return
	var model = load(MODEL)
	_preparation(model)
	if "--preparation-only" in OS.get_cmdline_user_args():
		quit(t.verdict())
		return
	var Run = load("res://src/core/run_state.gd")
	var coverage := {}
	for stage in range(1, Park.COUNT + 1):
		var map = Map.new("res://src/world/park/%s.json" % Park.of(stage).map)
		var graph = Graph.read("res://assets/park/%s/graph.bin" % map.park.map)
		if not t.check(map.park.map + " graph loads", graph != null):
			continue
		var prepared: Dictionary = model.prepare(graph, map)
		var anchor_nodes := {}
		for anchor in prepared.anchors:
			anchor_nodes[anchor.node] = true
		t.eq("one chance anchor per graph site", prepared.anchors.size(), anchor_nodes.size())
		var from_line := _from_line(graph)
		var trade_pool := Trade.candidates(graph, map)
		var authored: Array = map.activity_sites.duplicate(true)
		for seed_value in 12:
			var run = Run.new()
			run.stage = stage
			run.run_seed = seed_value
			var trade := Trade.stage_site(graph, map, run, 78000, trade_pool)
			var trade_before: Dictionary = run.trade_memory.duplicate(true)
			var specs: Array = model.stage_sites(graph, map, run, 78000, trade, prepared)
			t.eq("trade placement and memory unchanged", run.trade_memory, trade_before)
			t.eq("authored sites unchanged", map.activity_sites, authored)
			var standing: int = authored.filter(func(s): return s.get("extra", "") != "card_2").size()
			# Every park stage draws at least MIN_DRAWN while CAP has room (ruling bu + W50 Roboquest authored sites).
			var room := maxi(0, Modifier.CAP - standing)
			var expected_slots := clampi(mini(Modifier.CAP, stage + 2) - standing, mini(Modifier.MIN_DRAWN, room), room)
			t.eq("the draw's slots are the modifier's base slots", Modifier.base_slots(stage, standing), expected_slots)
			t.check("D2 extra slot cap", specs.size() <= expected_slots)
			t.check("every stage draws, the dam too", not specs.is_empty())
			_audit(graph, map, specs, trade, from_line)
			for spec in specs:
				coverage[spec.interior.id] = true
			var again = Run.new()
			again.stage = stage
			again.run_seed = seed_value
			t.check("same seed reconstructs sites", model.stage_sites(graph, map, again, 78000, trade, prepared) == specs)
			t.check("cache survives a changed layout seed", model.stage_sites(graph, map, run, 123, trade, prepared) == specs)
			var doc: Dictionary = JSON.parse_string(JSON.stringify(model.to_doc(run.pocket_draw_cache)))
			t.eq("draw cache document validates", model.validate_doc(doc, stage), "")
			var restored: Dictionary = model.from_doc(doc)
			t.check("JSON cache round trip", restored == run.pocket_draw_cache)
			if stage == 6 and seed_value == 0:
				_failure(model, prepared, map, graph)
				var bad: Dictionary = doc.duplicate(true)
				if not bad[str(stage)].sites.is_empty():
					bad[str(stage)].sites[0].at = ["bad", 0]
					t.check("invalid cached coordinate rejected", model.validate_doc(bad, stage) != "")
				bad = doc.duplicate(true)
				if not bad[str(stage)].sites.is_empty():
					bad[str(stage)].sites[0].turn = 4
					t.check("invalid cached orientation rejected", model.validate_doc(bad, stage) != "")
				bad = doc.duplicate(true)
				bad["7"] = {"sites": []}
				t.check("future stage cache rejected", model.validate_doc(bad, stage) != "")
				if not "--placement-only" in OS.get_cmdline_user_args():
					await _runtime(specs)
	if not "--placement-only" in OS.get_cmdline_user_args():
		_detours(tool.draw_arm("all", 1000, 200))
	print("pocket_draw_coverage: " + JSON.stringify(coverage.keys()))
	quit(t.verdict())

func _preparation(model) -> void:
	var map = Map.new("res://src/world/park/park_flume.json")
	var original = Graph.read("res://assets/park/park_flume/graph.bin")
	var graph := MeasuredGraph.new()
	for property in original.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			graph.set(property.name, original.get(property.name))
	var prepared: Dictionary = model.prepare(graph, map)
	var maximum := 0
	var anchors := {}
	for anchor in prepared.anchors:
		anchors[anchor.at] = true
	for box in graph.footprint_scans:
		if anchors.has((box[0] + box[1]) * 0.5):
			maximum = maxi(maximum, graph.footprint_scans[box])
	t.check("preparation exercises full footprint queries", not graph.footprint_scans.is_empty() and not prepared.anchors.is_empty())
	t.eq("quarter-turns share one physical footprint scan", maximum, 1)
	print("PREPARATION queries=%d" % graph.footprint_scans.size())

func _from_line(graph) -> PackedFloat32Array:
	var nodes := PackedInt32Array()
	for node in graph.node_count():
		if graph.flags(node) & Graph.LINE != 0:
			nodes.append(node)
	return graph.search(nodes)

func _audit(graph, map, specs: Array, trade: Dictionary, from_line: PackedFloat32Array) -> void:
	var ids := {}
	var doors: Array = Trade.doors(map)
	if not trade.is_empty():
		doors.append({"at": trade.at})
	var sorted: Array = specs.duplicate()
	sorted.sort_custom(func(a, b): return from_line[a.node] < from_line[b.node])
	for spec in specs:
		var entry: Dictionary = spec.interior
		t.check("distinctness: no repeated interior", not ids.has(entry.id), entry.id)
		ids[entry.id] = true
		for authored in map.activity_sites:
			t.check("no stage assigned interior drawn", Library.for_site(map.park.map, authored.row).get("id", "") != entry.id)
		t.check("non-trade library entry", entry.kind != "trade")
		var half: float = Library.FOOTPRINTS[entry.footprint] * 0.5
		var door: Vector2 = spec.at + Vector2(entry.entrances[0].at[0], entry.entrances[0].at[1]).rotated(spec.get("turn", 0) * PI * 0.5)
		var dn: int = graph.nearest(door)
		t.check("drawn door off-line, open, door-ok and sight-ok", graph.flags(dn) & (Graph.OPEN | Graph.DOOR_OK | Graph.SIGHT_OK) == (Graph.OPEN | Graph.DOOR_OK | Graph.SIGHT_OK) and graph.flags(dn) & (Graph.LINE | Graph.WARDEN | Graph.GUARDED) == 0)
		t.check("door distance to spawn", graph.d_spawn_node(dn) >= Rules.DOOR_SPAWN_M)
		t.check("door distance to beacon", graph.d_landmark_node(dn) >= Rules.DOOR_BEACON_M)
		t.check("pay detour band", from_line[spec.node] >= Rules.DETOUR_MIN_M and from_line[spec.node] <= Rules.DETOUR_MAX_M)
		var box := Rect2(spec.at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
		for existing in doors:
			var nearest := Vector2(clampf(existing.at.x, box.position.x, box.end.x), clampf(existing.at.y, box.position.y, box.end.y))
			t.check("door-ring: entire drawn footprint outside 40m", nearest.distance_to(existing.at) > Rules.RING_M)
			t.check("door to existing door minimum", door.distance_to(existing.at) >= Rules.DOOR_DOOR_M)
		for other in specs:
			if other != spec:
				var od: Vector2 = other.at + Vector2(other.interior.entrances[0].at[0], other.interior.entrances[0].at[1]).rotated(other.get("turn", 0) * PI * 0.5)
				t.check("drawn doors separated", door.distance_to(od) >= Rules.DOOR_DOOR_M)
		var route_clear := true
		for n in graph.box_nodes(box.position, box.end):
			route_clear = route_clear and graph.flags(n) & Graph.LINE == 0
		t.check("drawn footprint does not cut main route", route_clear)
		var owner: Dictionary = load("res://src/world/activities.gd").RULES[entry.activity].pay
		for key in owner:
			if key != "rarities":
				t.eq("drawn pay preserves owner " + key, spec.pay.get(key), owner[key])
		if entry.activity == "enemy_camp":
			t.check("drawn camp pays the common roll, no named part", not spec.pay.has("named") and spec.pay.rarities == ["common"], str(spec.pay))
		if map.park.map in model_tidy():
			var low := INF
			var high := -INF
			for n in graph.box_nodes(box.position - Vector2.ONE * Graph.STEP_M, box.end + Vector2.ONE * Graph.STEP_M):
				low = minf(low, graph.py[n])
				high = maxf(high, graph.py[n])
			t.check("world 1 pocket stands on level ground", high - low <= load(MODEL).LEVEL_M, "%s at %s rises %.1f m" % [entry.id, spec.at, high - low])
			for row in map.park.get("rescue_rows", []):
				var cage := Vector2(row.at[0], row.at[1])
				t.check("world 1 pocket clear of the rescue cage", Vector2(clampf(cage.x, box.position.x, box.end.x), clampf(cage.y, box.position.y, box.end.y)).distance_to(cage) > Rules.RING_M)
			for site in RogueDirector.read_sites(map.park.map).get("miniboss_sites", []):
				var rogue := Vector2(site.at[0], site.at[1])
				t.check("world 1 pocket outside the rogue site's disc", Vector2(clampf(rogue.x, box.position.x, box.end.x), clampf(rogue.y, box.position.y, box.end.y)).distance_to(rogue) > float(site.radius_m))
			# Read from the secrets' own rows, not the draw's list of them.
			var hidden := []
			for find in Secrets.FINDS.values():
				hidden.append_array(find.spots.filter(func(_spot): return find.map == map.park.map))
			for row in Secrets.ROOMS.values() + [Secrets.DOOR]:
				if row.map == map.park.map:
					hidden.append(row)
			for row in hidden:
				var secret := Vector2(row.at[0], row.at[1])
				t.check("world 1 pocket clear of a secret's spot", Vector2(clampf(secret.x, box.position.x, box.end.x), clampf(secret.y, box.position.y, box.end.y)).distance_to(secret) > Rules.RING_M, "%s at %s, secret at %s" % [entry.id, spec.at, secret])
		var pay: Dictionary = Rules._pay(spec.pay)
		var allowed: Array = Rules.PAY_FAR if spec == sorted.back() else Rules.PAY_NEAR
		t.check("drawn set pay ladder", not pay.rarities.is_empty() and pay.rarities.all(func(r): return r in allowed))

func model_tidy() -> Array:
	return load(MODEL).TIDY

func _failure(model, prepared: Dictionary, map, graph) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23003
	var anchors: Array = prepared.anchors.duplicate(true)
	anchors.push_front({"node": graph.spawn_node, "at": map.spawn})
	var drawn: Dictionary = model.draw(prepared, map, 6, rng, {}, anchors)
	var spent := 0
	for spec in drawn.sites:
		var side: float = Library.FOOTPRINTS[spec.interior.footprint]
		spent += ceili(side * side / Library.FOOTPRINTS.small)
	t.check("production placement failure exercised", drawn.metrics.failed_placements > 0)
	t.eq("zero-credit-lost: failed placements refund", int(drawn.metrics.remaining_credits) + spent, 150)
	t.check("failed anchor tries next anchor", not drawn.sites.is_empty())

func _runtime(_specs: Array) -> void:
	var Game = load("res://src/game.gd")
	var model = load(MODEL)
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.run_store_path = "user://pocket-draw-continue.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.run_store_path))
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_frozen(true)
	game.camera.set_physics_process(false)
	game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.rng.seed = 78000
	game.run.run_seed = 0
	game.flow.enter_stage(2, Vector3.ZERO, false)
	await physics_frame
	var acts = game.world.activities
	acts.set_physics_process(false)
	var saved: Dictionary = game.flow.store.load()
	var expected_doc := {}
	for key in game.run.pocket_draw_cache:
		var placed := []
		for spec in game.run.pocket_draw_cache[key].sites:
			placed.append({"interior": spec.interior.id, "node": spec.node, "at": [spec.at.x, spec.at.y], "turn": spec.get("turn", 0)})
		expected_doc[key] = {"sites": placed}
	expected_doc = JSON.parse_string(JSON.stringify(expected_doc))
	t.eq("stage-entry disk save includes current draw cache", saved.get("pocket_draw_cache", {}), expected_doc)
	var authored: int = game.world.terrain.map().activity_sites.size()
	var specs: Array = game.run.pocket_draw_cache["2"].sites
	var actual: Array = acts.sites.filter(func(site): return not site.interior.is_empty() and site.interior.id == specs[0].interior.id) if not specs.is_empty() else []
	if not t.check("production stage entry appends actual drawn sites", actual.size() == specs.size() and not actual.is_empty()):
		game.free()
		return
	t.check("drawn sites appended after authored and trade", acts.sites.find(actual[0]) >= authored)
	var trade: Dictionary = game.run.trade_memory.offers["2"]
	if not trade.is_empty():
		var trade_sites: Array = acts.sites.filter(func(site): return not site.trade.is_empty())
		t.eq("production trade still placed once", trade_sites.size(), 1)
		t.check("production draw follows trade", acts.sites.find(actual[0]) > acts.sites.find(trade_sites[0]))
	var before: int = game.ctx.rng.state
	acts._on_stage_entered(2, false)
	t.eq("draw stage assembly leaves ctx RNG unchanged", game.ctx.rng.state, before)
	await physics_frame
	var s = acts.sites.filter(func(site): return not site.interior.is_empty() and site.interior.id == specs[0].interior.id)[0]
	t.check("drawn orientation built", is_equal_approx(s.rotation.y, -specs[0].get("turn", 0) * PI * 0.5))
	var owner: Dictionary = acts.RULES[s.id].pay
	for key in owner:
		if key != "rarities":
			t.eq("built drawn pay preserves owner " + key, s.rule.pay.get(key), owner[key])

	var interior: Node = s.get_node("Interior_" + String(s.interior.id))
	t.eq("drawn unvisited interior has no collision", _bodies(interior), 0)
	game.player.body().global_position = s.global_position + Vector3(0, 1, 0)
	acts._physics_process(0.0)
	await physics_frame
	t.eq("drawn entered terrain has collision", _bodies(interior), s.interior.terrain.size())
	var Run = load("res://src/core/run_state.gd")
	var loaded = Run.new()
	t.check("Continue accepts actual saved entrance", loaded.from_entrance_doc(saved))
	t.check("Continue preserves saved drawn sites", loaded.pocket_draw_cache == game.run.pocket_draw_cache)
	game.flow.retry_stage()
	t.check("retry preserves current stage draw", game.run.pocket_draw_cache["2"].sites == specs)
	var path: String = game.run_store_path
	game.free()
	var resumed = Game.new()
	resumed.test_mode = true
	resumed.table = "park"
	resumed.run_store_path = path
	root.add_child(resumed)
	while resumed.flow == null:
		await physics_frame
	resumed.ctx.rng.seed = 123
	t.check("real Continue flow resumes", resumed.flow.resume_run())
	t.check("Continue reconstructs identical cached draw despite new layout seed", resumed.run.pocket_draw_cache.get("2", {}).get("sites", []) == specs)
	var rebuilt: Array = resumed.world.activities.sites.filter(func(site): return not site.interior.is_empty() and site.interior.id == specs[0].interior.id)
	t.check("Continue rebuilds saved drawn interior", rebuilt.size() == specs.size())
	if not rebuilt.is_empty():
		t.check("Continue rebuilds saved orientation", is_equal_approx(rebuilt[0].rotation.y, -specs[0].get("turn", 0) * PI * 0.5))
		t.eq("Continue rebuilds saved position", Vector2(rebuilt[0].global_position.x, rebuilt[0].global_position.z), specs[0].at)
	var cache: Dictionary = Library.rows().filter(func(entry): return entry.kind == "secret")[0]
	for turn in 4:
		var at := Vector2(640, 640)
		var spec: Dictionary = Library.site_spec(cache).merged({"drawn": true, "turn": turn})
		var built = resumed.world.activities._build(cache.activity, at, spec)
		t.eq("drawn cache keeps planned centre", Vector2(built.global_position.x, built.global_position.z), at)
		t.check("drawn cache keeps planned orientation", is_equal_approx(built.rotation.y, -turn * PI * 0.5))
		var expected := at + _turned(Vector2(0, -resumed.world.activities.PEDESTAL_BACK), turn)
		# The model's pedestal stands on its origin (W1-22); the greybox cylinder is centred.
		var rendered: MeshInstance3D = built.get_node_or_null("CachePedestal")
		var lift := 0.0
		if rendered == null:
			for child in built.get_children():
				if child is MeshInstance3D and child.mesh is CylinderMesh:
					rendered = child
					lift = rendered.mesh.height * 0.5
		if t.check("drawn cache renders pedestal turn %d" % turn, rendered != null):
			t.check("drawn cache rendered pedestal at owned offset turn %d" % turn, Vector2(rendered.global_position.x, rendered.global_position.z).distance_to(expected) < 0.001)
			t.check("drawn cache reward and rendered pedestal agree turn %d" % turn, Vector2(built.pedestal.x, built.pedestal.z).distance_to(expected) < 0.001)
			t.check("drawn cache pedestal world position agrees turn %d" % turn, (rendered.global_position - Vector3.UP * lift).distance_to(built.pedestal) < 0.001)
			var before_parts: int = resumed.run.parts.size()
			resumed.world.activities._break_wall(built)
			if t.check("drawn cache wall releases reward turn %d" % turn, built.pickup != null):
				t.check("drawn cache reward appears at rendered pedestal turn %d" % turn, Vector2(built.pickup.global_position.x, built.pickup.global_position.z).distance_to(expected) < 0.001)
				resumed.world.activities._watch_pickup(built, Vector3(expected.x + 10, built.pedestal.y, expected.y))
				resumed.world.activities._watch_pickup(built, Vector3(expected.x, built.pedestal.y, expected.y))
				t.check("drawn cache reward collectible at rendered pedestal turn %d" % turn, built.pickup_taken and resumed.run.parts.size() > before_parts)

	_owned_rewards(resumed.world.activities, model)
	_hazard_geometry(resumed.world.activities)
	resumed.free()

func _owned_rewards(acts, model) -> void:
	for entry in Library.rows():
		if entry.kind == "trade":
			continue
		var cache: Dictionary = model.from_doc({"2": {"sites": [{"interior": entry.id, "node": 0, "at": [640, 640], "turn": 0}]}})
		var spec: Dictionary = cache["2"].sites[0]
		var built = acts._build(entry.activity, spec.at, spec)
		var owner: Dictionary = acts.RULES[entry.activity].pay
		for key in owner:
			if key != "rarities":
				t.eq("restored built pay preserves owner " + key, built.rule.pay.get(key), owner[key])
		if entry.activity == "enemy_camp":
			t.eq("built drawn camp pays the common roll", acts.pay_table(built), {"named": "", "rarities": ["common"]})
		t.eq("a drawn pocket rolls apart from the stage's authored site of its kind", acts._luck_id(built), "%s:%s" % [entry.activity, entry.id])
		built.free()
	# A save from before the dam drew holds an empty stage 1 draw; a later stage's empty draw is kept.
	t.eq("an old save's empty dam draw is dropped on load", model.from_doc({"1": {"sites": []}, "2": {"sites": []}}), {"2": {"sites": []}})

func _turned(at: Vector2, turn: int) -> Vector2:
	return [at, Vector2(-at.y, at.x), -at, Vector2(at.y, -at.x)][turn]

func _hazard_geometry(acts) -> void:
	var entry: Dictionary = Library.rows().filter(func(e): return e.id == "round_foundry")[0]
	var origin := Vector2(640, 640)
	for turn in 4:
		var spec: Dictionary = Library.site_spec(entry).merged({"drawn": true, "turn": turn})
		var site = acts._build(entry.activity, origin, spec)
		for i in entry.hazards.size():
			var box: Dictionary = entry.hazards[i]
			var centre := origin + _turned(Vector2(box.at[0], box.at[1]), turn)
			var extent := Vector2(box.size[0], box.size[2]) if turn % 2 == 0 else Vector2(box.size[2], box.size[0])
			var hazard = site.hazards[i]
			hazard.begin(2)
			hazard.active = true
			var visual: MeshInstance3D = hazard._visual
			var bounds: AABB = visual.global_transform * visual.get_aabb()
			t.check("hazard visual centre turn %d" % turn, Vector2(bounds.get_center().x, bounds.get_center().z).distance_to(centre) < 0.001)
			t.check("hazard visual extents turn %d" % turn, Vector2(bounds.size.x, bounds.size.z).distance_to(extent) < 0.001)
			t.check("hazard committed centre turn %d" % turn, Vector2(hazard.committed.site.at[0], hazard.committed.site.at[1]).distance_to(centre) < 0.001)
			t.check("hazard committed extents turn %d" % turn, Vector2(hazard.committed.site.size[2], hazard.committed.site.size[0]).distance_to(extent) < 0.001)
			t.near("hazard visual and committed floor agree turn %d" % turn, bounds.position.y, hazard.committed.floor_y)
			t.near("hazard visual and committed height agree turn %d" % turn, bounds.size.y, hazard.committed.height)
			var safe: Vector3 = hazard.committed.safe_at
			t.check("hazard safe disc uses transformed centre turn %d" % turn, Vector2(safe.x, safe.z).distance_to(centre) < 0.001)
			t.check("hazard safe disc matches visual shader turn %d" % turn, visual.material_override.get_shader_parameter("safe_at").distance_to(Vector2(safe.x, safe.z)) < 0.001)
			for x in [-1.1, -0.8, 0.0, 0.8, 1.1]:
				for z in [-1.1, -0.8, 0.0, 0.8, 1.1]:
					var delta := Vector2(x * extent.x * 0.5, z * extent.y * 0.5)
					var at := centre + delta
					var inside: bool = absf(x) < 1.0 and absf(z) < 1.0 and delta.length() > acts.POCKET_SAFE_M
					t.eq("hazard damage agrees with visible bounds turn %d" % turn, hazard.damage_at(Vector3(at.x, bounds.position.y + 1, at.y)) > 0.0, inside)
			for step in 12:
				var at := origin + _turned(Vector2(0, step * 2), turn)
				t.eq("transformed safe corridor damage-free turn %d" % turn, hazard.damage_at(Vector3(at.x, bounds.position.y + 1, at.y)), 0.0)
			hazard.stop()
		site.free()

func _bodies(node: Node) -> int:
	var count := int(node is PhysicsBody3D)
	for child in node.get_children():
		count += _bodies(child)
	return count

func _detours(arm: Dictionary) -> void:
	t.eq("detour arm retains stage sample count", arm.stage_samples, 6000)
	t.eq("detour arm retains placement sample count", arm.placement_samples, 1200)
	t.eq("detour arm includes every template", arm.templates.size(), Park.COUNT)
	for row in arm.templates:
		if row.stage == 1:
			t.check("the dam draws on every seed (D8's exemption retired, ruling bu)", row.nonempty_stages == row.stage_samples and row.draw_count >= row.stage_samples)
		if not t.check("D10 bound and floor reported: " + row.map, row.has("detour_bound") and row.has("detour_floor")):
			continue
		var graph = Graph.read("res://assets/park/%s/graph.bin" % row.map)
		var distance := _from_line(graph)
		# Reverse the probe: start at permissive doors, then enumerate possible pay centres.
		var low := INF
		var high := 0.0
		var reach := 0.0
		for side in Library.FOOTPRINTS.values():
			reach = maxf(reach, side * 0.5 + Graph.STEP_M / sqrt(2.0))
		var cells := ceili(reach / Graph.STEP_M)
		for door in range(Graph.SIDE * Graph.SIDE):
			if graph.flags(door) & (Graph.SIGHT_OK | Graph.DOOR_OK) != (Graph.SIGHT_OK | Graph.DOOR_OK) or graph.d_spawn_node(door) < Rules.DOOR_SPAWN_M or graph.d_landmark_node(door) < Rules.DOOR_BEACON_M:
				continue
			for dz in range(-cells, cells + 1):
				for dx in range(-cells, cells + 1):
					if Vector2(dx, dz).length() * Graph.STEP_M > reach:
						continue
					var x := door % Graph.SIDE + dx
					var z := door / Graph.SIDE + dz
					if x < 0 or x >= Graph.SIDE or z < 0 or z >= Graph.SIDE:
						continue
					var value: float = distance[z * Graph.SIDE + x]
					if value >= Rules.DETOUR_MIN_M and value <= Rules.DETOUR_MAX_M:
						low = minf(low, value)
						high = maxf(high, value)
		var bound := high / low
		t.check("D10 independent permissive bound: " + row.map, is_equal_approx(row.detour_bound, bound), str(row.detour_bound) + " vs " + str(bound))
		# Every park reads its floor against the anchors prepare() actually leaves after keep-outs and TIDY.
		var anchors: Array = load(MODEL).prepare(graph, Map.new("res://src/world/park/%s.json" % row.map)).anchors
		if not anchors.is_empty():
			var reach_low := INF
			var reach_high := 0.0
			for anchor in anchors:
				reach_low = minf(reach_low, distance[anchor.node])
				reach_high = maxf(reach_high, distance[anchor.node])
			if row.map in model_tidy():
				t.check("level ground leaves anchors: " + row.map, not anchors.is_empty())
			bound = minf(bound, reach_high / reach_low)
			t.check("D10 anchor bound: " + row.map, is_equal_approx(row.anchor_bound, bound), str(row.anchor_bound) + " vs " + str(bound))
		var floor_value := minf(2.0, 0.9 * bound)
		t.check("D10 floor derivation: " + row.map, is_equal_approx(row.detour_floor, floor_value))
		t.check("D10 measured detour meets floor: " + row.map, row.detour_ratio >= floor_value, "%.6f >= %.6f" % [row.detour_ratio, floor_value])
