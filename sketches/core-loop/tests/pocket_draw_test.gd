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
	var Run = load("res://src/core/run_state.gd")
	var coverage := {}
	for stage in range(1, Park.COUNT + 1):
		var map = Map.new("res://src/world/park/%s.json" % Park.of(stage).map)
		var graph = Graph.read("res://assets/park/%s/graph.bin" % map.park.map)
		if not t.check(map.park.map + " graph loads", graph != null):
			continue
		var prepared: Dictionary = model.prepare(graph, map)
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
			var expected_slots := maxi(0, mini(8, stage + 2) - authored.size())
			t.check("D2 extra slot cap", specs.size() <= expected_slots)
			t.check("stage 1 exempt; later stages draw", specs.is_empty() if stage == 1 else not specs.is_empty())
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
		var pay: Dictionary = Rules._pay(spec.pay)
		var allowed: Array = Rules.PAY_FAR if spec == sorted.back() else Rules.PAY_NEAR
		t.check("drawn set pay ladder", not pay.rarities.is_empty() and pay.rarities.all(func(r): return r in allowed))

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
	var interior: Node = s.get_node("Interior_" + String(s.interior.id))
	t.eq("drawn unvisited interior has no collision", _bodies(interior), 0)
	game.player.active_body().global_position = s.global_position + Vector3(0, 1, 0)
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
	resumed.free()

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
			t.check("D8 stage 1 exempt with zero draws", row.exempt and row.draw_count == 0)
			continue
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
		var floor_value := minf(2.0, 0.9 * bound)
		t.check("D10 floor derivation: " + row.map, is_equal_approx(row.detour_floor, floor_value))
		t.check("D10 measured detour meets floor: " + row.map, row.detour_ratio >= floor_value, "%.6f >= %.6f" % [row.detour_ratio, floor_value])
