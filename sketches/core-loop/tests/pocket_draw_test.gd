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
				bad["7"] = {"sites": []}
				t.check("future stage cache rejected", model.validate_doc(bad, stage) != "")
				await _runtime(specs)
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
		var door: Vector2 = spec.at + Vector2(entry.entrances[0].at[0], entry.entrances[0].at[1])
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
				var od: Vector2 = other.at + Vector2(other.interior.entrances[0].at[0], other.interior.entrances[0].at[1])
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

func _runtime(specs: Array) -> void:
	var Game = load("res://src/game.gd")
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
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
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	await physics_frame
	if not t.check("runtime has actual drawn sites", not specs.is_empty()):
		game.free()
		return
	var spec: Dictionary = specs[0]
	var s = acts._build(spec.id, spec.at, spec)
	acts.sites.append(s)
	var interior: Node = s.get_node("Interior_" + String(spec.interior.id))
	t.eq("drawn unvisited interior has no collision", _bodies(interior), 0)
	game.player.active_body().global_position = s.global_position + Vector3(0, 1, 0)
	acts._physics_process(0.0)
	await physics_frame
	t.eq("drawn entered terrain has collision", _bodies(interior), spec.interior.terrain.size())
	game.run.stage = 6
	game.run.pocket_draw_cache["6"] = {"sites": specs.duplicate(true)}
	game.run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_entrance_doc()))
	var Run = load("res://src/core/run_state.gd")
	var loaded = Run.new()
	t.check("Continue accepts entrance with draw cache", loaded.from_entrance_doc(doc))
	t.check("Continue preserves actual drawn sites", loaded.pocket_draw_cache == game.run.pocket_draw_cache)
	game.free()

func _bodies(node: Node) -> int:
	var count := int(node is PhysicsBody3D)
	for child in node.get_children():
		count += _bodies(child)
	return count
