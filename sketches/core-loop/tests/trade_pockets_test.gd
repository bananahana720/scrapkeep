extends SceneTree
# smoke: solo timeout=360s

const T := preload("res://tests/support/t.gd")
const MODEL := "res://src/world/trade_pockets.gd"
var t := T.new("trade_pockets_test")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not t.check("trade model exists", FileAccess.file_exists(MODEL)):
		quit(t.verdict())
		return
	var model = load(MODEL)
	var memory: Dictionary = model.memory()
	model.decide(memory, {"stage": 1, "family": "risk"}, true)
	t.eq("risk trade closes safe family", model.odds(memory, 2).safe_share, 0.0)
	memory = model.memory()
	var before: float = model.odds(memory, 2).safe_share
	model.decide(memory, {"stage": 1, "family": "risk"}, false)
	t.check("refusal raises safe odds at least 1.2x", model.odds(memory, 2).safe_share / before >= 1.2)
	if "--render-summary" not in OS.get_cmdline_user_args():
		_policies(model)
		_placements(model)
	if "--render-summary" in OS.get_cmdline_user_args():
		await _render_summary(model)
	elif "--model-only" not in OS.get_cmdline_user_args():
		await _runtime(model)
	quit(t.verdict())

func _policies(model) -> void:
	for policy in ["always-risk", "never"]:
		var count := 0
		var chains := 0
		var closed := 0
		var risk_runs := 0
		var boosted := 0
		var eligible := 0
		var skips := 0.0
		for seed_value in 10000:
			var mem: Dictionary = model.memory()
			var rng := RandomNumberGenerator.new()
			rng.seed = 93000 + seed_value
			var last := -100
			var chain := false
			var risk := false
			var safe_closed := true
			var refusal := false
			var boost := false
			for stage in range(1, 9):
				var offer: Dictionary = model.draw(mem, stage, rng, true)
				skips += float(model.odds(mem, stage).skip_time)
				if offer.is_empty():
					continue
				count += 1
				chain = chain or stage == last + 1
				last = stage
				model.see(mem, offer)
				var took: bool = policy == "always-risk" and offer.family == "risk"
				model.decide(mem, offer, took)
				if took:
					risk = true
				if risk:
					safe_closed = safe_closed and model.odds(mem, stage + 1).safe_share == 0.0
				if not took and stage < 8 and not mem.risk_taken:
					refusal = true
					# Counterfactual keeps stage appearance recency identical; only refusal changes.
					var counter: Dictionary = mem.duplicate(true)
					counter.last_refused = -100
					boost = boost or model.odds(mem, stage + 1).safe_share / model.odds(counter, stage + 1).safe_share >= 1.2
			chains += int(chain)
			risk_runs += int(risk)
			closed += int(risk and safe_closed)
			eligible += int(refusal)
			boosted += int(boost)
		var row := {"policy": policy, "runs": 10000, "stages": 8, "pockets_mean": count / 10000.0, "back_to_back_runs": chains, "risk_runs": risk_runs, "safe_closed_runs": closed, "refusal_runs": eligible, "boosted_runs": boosted, "skip_seconds": skips}
		print("trade_policy: " + JSON.stringify(row))
		t.check(policy + " mean 1.5 to 3", row.pockets_mean >= 1.5 and row.pockets_mean <= 3.0)
		t.check(policy + " back-to-back at most 30 percent", chains <= 3000)
		if policy == "always-risk":
			t.check("safe family gone in every risk-taking run", risk_runs > 0 and closed == risk_runs)
		else:
			t.check("refusal raises safe odds 1.2x in at least 80 percent of all runs", boosted >= 8000)
		t.eq(policy + " skip-all main-route seconds", skips, 0.0)

func _placements(model) -> void:
	var Park = load("res://src/core/park_defs.gd")
	var Map = load("res://src/world/park/park_map.gd")
	var Graph = load("res://src/world/park/park_graph.gd")
	var Run = load("res://src/core/run_state.gd")
	for stage in range(1, Park.COUNT + 1):
		var id: String = Park.of(stage).map
		var map = Map.new("res://src/world/park/%s.json" % id)
		var authored: Array = map.activity_sites.duplicate(true)
		var graph = Graph.read("res://assets/park/%s/graph.bin" % id)
		if not t.check(id + " graph loads", graph != null):
			continue
		var pool: PackedInt32Array = model.candidates(graph, map)
		if not t.check(id + " placement pool nonempty", not pool.is_empty()):
			continue
		var spec := {}
		var used_seed := 0
		var run = Run.new()
		run.stage = stage
		for seed_value in 100:
			run.trade_memory = model.memory()
			run.run_seed = seed_value
			spec = model.stage_site(graph, map, run, 78000, pool)
			if not spec.is_empty():
				used_seed = seed_value
				break
		if not t.check(id + " stage offers a trade", not spec.is_empty()):
			continue
		run.trade_memory = model.memory()
		t.eq(id + " same seed same site", model.stage_site(graph, map, run, 78000, pool), spec)
		var flags: int = graph.flags(spec.node)
		t.check(id + " trade placement off main line", flags & Graph.LINE == 0)
		t.check(id + " trade placement door-ok", flags & Graph.DOOR_OK != 0)
		var line_m := INF
		for n in graph.node_count():
			if graph.flags(n) & Graph.LINE != 0:
				var p: Vector3 = graph.position(n)
				line_m = minf(line_m, spec.at.distance_to(Vector2(p.x, p.z)))
		t.check(id + " entire interior clear of main line", line_m > 40.0)
		var door_m := {}
		for door in model.doors(map):
			var distance: float = spec.at.distance_to(door.at)
			door_m[door.id] = distance
			t.check(id + " outside " + door.id + " 40m door ring", distance > 62.0)
		t.eq(id + " authored activity sites unchanged", map.activity_sites, authored)
		print("trade_placement: " + JSON.stringify({"stage": stage, "map": id, "run_seed": used_seed, "layout_seed": 78000, "node": spec.node, "at": [spec.at.x, spec.at.y], "line_planar_m": line_m, "doors_planar_m": door_m, "interior": spec.trade.interior_id}))
	var run = Run.new()
	t.eq("map without graph offers no trade", model.stage_site(null, null, run, 1, PackedInt32Array()), {})

func _offer(model, entry: Dictionary, stage: int) -> Dictionary:
	return model.odds(model.memory(), stage).merged({"stage": stage, "family": "risk" if entry.id in model.FAMILIES.risk else "safe", "interior_id": entry.id, "curse": entry.id == "curse_counter", "sacrifice": entry.id == "sacrifice_counter", "sacrifice_chance": model.SACRIFICE_CHANCE + model.FULL_HEALTH_BUMP, "full_health_bump": true, "pool_floor": model.POOL_FLOOR if entry.id == "curse_counter" else 0.0, "tier": 1})

func _runtime(model) -> void:
	var Game = load("res://src/game.gd")
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var Intent = load("res://src/movement/intent.gd")
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
	game.camera.set_physics_process(false)
	game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	game.world.interact.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_frozen(true)
	game.player.source = Intent.Scripted.new()
	var acts = game.world.activities
	acts.set_physics_process(false)
	acts.clear()
	game.combat._start_attempt()
	# The park's stage handler appends the seeded trade after authored sites.
	game.run.trade_memory = model.memory()
	game.run.run_seed = 0
	acts._on_stage_entered(1, false)
	var actual: Array = acts.sites.filter(func(site): return not site.trade.is_empty())
	t.check("actual park stage entry appends at most one trade", actual.size() <= 1)
	if actual.is_empty():
		game.run.trade_memory = model.memory()
		game.run.run_seed = 1
		acts._on_stage_entered(1, false)
		actual = acts.sites.filter(func(site): return not site.trade.is_empty())
	t.eq("actual park stage has one seeded trade", actual.size(), 1)
	if not actual.is_empty():
		t.check("trade is appended after authored sites", acts.sites[-1] == actual[0])
	acts.clear()
	await physics_frame
	Engine.time_scale = 4.0
	var interiors: Array = Library.rows().filter(func(entry): return entry.kind == "trade")
	t.eq("eight trade interiors", interiors.size(), 8)
	var stage := 0
	for entry in interiors:
		stage += 1
		var safe := 0
		var price_ok := true
		var trials := 1 if "--render-summary" in OS.get_cmdline_user_args() else 20
		for trial in trials:
			acts.clear()
			game.combat._start_attempt()
			game.run.begin(game.run.class_def)
			game.ctx.build.recompute()
			game.run.hp = game.run.max_hp
			game.run.trade_memory = model.memory()
			game.run.run_seed = 71000 + trial
			var spec: Dictionary = Library.site_spec(entry)
			spec["trade"] = _offer(model, entry, stage)
			var id: String = "curse" if spec.trade.curse else "sacrifice" if spec.trade.sacrifice else "trade_" + String(spec.trade.family)
			var s = acts._build(id, Vector2(100, 100), spec)
			acts.sites.append(s)
			var label: Label3D = s.get_node("TradePrices")
			price_ok = price_ok and label.visible and label.position.z > entry.entrances[0].at[1]
			for device in s.trade_devices:
				price_ok = price_ok and label.text.contains(device.words()) and device.offer.cost_kind != "scrap" and device in game.world.interact.devices
			var at: Vector3 = s.to_global(Vector3(entry.entry_spot[0], 0, entry.entry_spot[1]))
			at.y = game.ctx.terrain.height(at.x, at.z) + 1.1
			game.player.reset_to(at)
			game.player.active_body().global_position = at
			game.player.active_body().linear_velocity = Vector3.ZERO
			game.player.set_frozen(true)
			var before: float = game.run.hp
			acts.set_physics_process(true)
			for tick in 45:
				await physics_frame
			acts.set_physics_process(false)
			safe += int(game.run.hp == before and not s.done)
			if trial == 0:
				var device = s.trade_devices[1]
				game.run.cogs = 10000
				var hp: float = game.run.hp
				var max_hp: float = game.run.max_hp
				var cogs: int = game.run.cogs
				game.world.interact.fire(device)
				acts._watch_trade(s, at)
				t.check(entry.id + " consent buys the shown price", device.spent and (is_equal_approx(hp - game.run.hp + game.run.max_hp - max_hp, device.offer.cost) if device.offer.cost_kind == "hp" else cogs - game.run.cogs == device.offer.cost))
				t.eq(entry.id + " risk memory follows successful purchase", game.run.trade_memory.risk_taken, spec.trade.family == "risk")
				var settled: Dictionary = game.run.trade_memory.duplicate(true)
				var after_hp: float = game.run.hp
				var after_cogs: int = game.run.cogs
				if device.ready_now():
					game.world.interact.fire(device)
				t.check(entry.id + " spent device cannot charge twice", game.run.trade_memory == settled and game.run.hp == after_hp and game.run.cogs == after_cogs)
		t.check(entry.id + " every price shown before entry", price_ok)
		t.check(entry.id + " idle first 2s safe at least 95 percent", float(safe) / trials >= 0.95)
		print("trade_entry_rate: " + JSON.stringify({"interior": entry.id, "idle_entries": trials, "idle_safe": safe, "simulated_seconds": 2.0, "time_scale": 4.0, "price_before_entry": price_ok}))
	acts.clear()
	await physics_frame
	Engine.time_scale = 1.0
	await _summary(game, model, interiors)
	game.free()
	await process_frame

func _summary(game, model, interiors: Array) -> void:
	game.run.trade_memory = model.memory()
	var all_seen := []
	for i in interiors.size():
		var offer := _offer(model, interiors[i], i + 1)
		offer.recency = [1.0, 0.25, 0.5][i % 3]
		model.see(game.run.trade_memory, offer)
		all_seen.append(offer)
	game.run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	model.decide(game.run.trade_memory, {"stage": 1, "family": "risk"}, true)
	game.run.restore()
	t.eq("retry restores opposing memory", game.run.trade_memory.risk_taken, false)
	t.eq("retry preserves prior seen modifiers", game.run.summary().trade_pockets, all_seen)
	game.run.enter_stage(2)
	t.eq("transition settles a refusal before checkpoint", game.run.trade_memory.last_refused, 1)
	game.screens._on_flow_changed("summary")
	await process_frame
	var shown: String = game.screens.body_text()
	for offer in all_seen:
		t.check(offer.interior_id + " summary lists family and recency", shown.contains(String(offer.interior_id).replace("_", " ") + " | " + offer.family + " | recency x%.2f" % offer.recency))
	t.check("summary lists curse pool and sacrifice bump", shown.contains("curse, pool floor 0.2") and shown.contains("full-health +0.25"))
	if "--render-summary" in OS.get_cmdline_user_args():
		for frame in 60:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := OS.get_environment("SI1_SUMMARY_PNG")
		var image: Image = root.get_texture().get_image()
		t.check("rendered summary image nonempty", not image.is_empty())
		t.eq("rendered summary saved", image.save_png(path), OK)

func _render_summary(model) -> void:
	var Game = load("res://src/game.gd")
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.set_physics_process(false)
	for child in game.get_children():
		if child is Node3D:
			child.visible = false
	game.world.set_physics_process(false)
	game.presentation.process_mode = Node.PROCESS_MODE_DISABLED
	await _summary(game, model, Library.rows().filter(func(entry): return entry.kind == "trade"))
	game.free()
	await process_frame
