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
	if "--entrance-only" in OS.get_cmdline_user_args():
		_entrance_round_trip(model)
		quit(t.verdict())
		return
	_entrance_round_trip(model)
	_kindness_hue(model)
	var memory: Dictionary = model.memory()
	model.decide(memory, {"stage": 1, "family": "risk"}, true)
	t.eq("risk trade closes safe family", model.odds(memory, 2).safe_share, 0.0)
	memory = model.memory()
	var before: float = model.odds(memory, 2).safe_share
	model.decide(memory, {"stage": 1, "family": "risk"}, false)
	t.check("refusal raises safe odds at least 1.2x", model.odds(memory, 2).safe_share / before >= 1.2)
	if "--render-summary" not in OS.get_cmdline_user_args() and "--appearance-only" not in OS.get_cmdline_user_args():
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
				model.appear(mem, offer)
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
	game.run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	acts._on_stage_entered(1, false)
	var actual: Array = acts.sites.filter(func(site): return not site.trade.is_empty())
	t.check("actual park stage entry appends at most one trade", actual.size() <= 1)
	if actual.is_empty():
		game.run.trade_memory = model.memory()
		game.run.run_seed = 1
		game.run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
		acts._on_stage_entered(1, false)
		actual = acts.sites.filter(func(site): return not site.trade.is_empty())
	t.eq("actual park stage has one seeded trade", actual.size(), 1)
	if not actual.is_empty():
		# The stage's drawn pockets are planned round the trade, so they follow it (every stage draws since
		# ruling bu, the dam too); nothing authored does.
		var trade_at: int = acts.sites.find(actual[0])
		t.check("trade is appended after authored sites", acts.sites.slice(trade_at + 1).all(func(site): return site.drawn)
				and not acts.sites.slice(0, trade_at).any(func(site): return site.drawn),
			str(acts.sites.map(func(site): return "%s%s" % [site.id, " (drawn)" if site.drawn else ""])))
		_appearance_recency(game, model, actual[0])
	acts.clear()
	await physics_frame
	if "--appearance-only" in OS.get_cmdline_user_args():
		game.free()
		await process_frame
		return
	Engine.time_scale = 4.0
	var interiors: Array = Library.rows().filter(func(entry): return entry.kind == "trade")
	t.eq("eight trade interiors", interiors.size(), 8)
	var stage := 0
	for entry in interiors:
		stage += 1
		var safe := 0
		var price_ok := true
		var beam_words := {}
		var door_heads := {}
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
			door_heads[label.text.get_slice("\n", 0) + " / " + label.text.get_slice("\n", 1)] = true
			beam_words[s.view.word.text] = true
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
			# Two simulated seconds at the active physics rate and time scale (gate note, 2026-10-14).
			for tick in ceili(2.0 * Engine.physics_ticks_per_second / Engine.time_scale):
				await physics_frame
			acts.set_physics_process(false)
			safe += int(game.run.hp == before and not s.done)
			if trial == 0:
				var device = s.trade_devices[1]
				game.run.cogs = 10000
				var hp: float = game.run.hp
				var max_hp: float = game.run.max_hp
				var cogs: int = game.run.cogs
				var taken: Array = []
				var heard := func(kind: String, _where: Vector3): taken.append(kind)
				game.events.trade_taken.connect(heard)
				game.world.interact.fire(device)
				acts._watch_trade(s, at)
				acts._watch_trade(s, at)
				game.events.trade_taken.disconnect(heard)
				t.eq(entry.id + " a taken trade is published once, by its kind", taken, [s.id])
				t.check(entry.id + " consent buys the shown price", device.spent and (is_equal_approx(hp - game.run.hp + game.run.max_hp - max_hp, device.offer.cost) if device.offer.cost_kind == "hp" else cogs - game.run.cogs == device.offer.cost))
				t.eq(entry.id + " risk memory follows successful purchase", game.run.trade_memory.risk_taken, spec.trade.family == "risk")
				var settled: Dictionary = game.run.trade_memory.duplicate(true)
				var after_hp: float = game.run.hp
				var after_cogs: int = game.run.cogs
				if device.ready_now():
					game.world.interact.fire(device)
				t.check(entry.id + " spent device cannot charge twice", game.run.trade_memory == settled and game.run.hp == after_hp and game.run.cogs == after_cogs)
		t.check(entry.id + " every price shown before entry", price_ok)
		# The beam's word is the counter's name alone (the view's own tell); the prices are the door label's.
		t.check(entry.id + " the beam word is the counter's name", beam_words.keys() == [String(entry.tell.word)], str(beam_words.keys()))
		# Ruling ci: the door says whose offer it is, in that owner's voice, and never the family's code word.
		var risky: bool = entry.id in model.FAMILIES.risk
		var head: String = ("Keeper's gamble: %s / Nobody makes you." if risky else "Foreman's kindness: %s / A small efficiency fee. You're welcome.") % entry.tell.word
		t.check(entry.id + " the door names whose offer it is", door_heads.keys() == [head], str(door_heads.keys()))
		t.check(entry.id + " idle first 2s safe at least 95 percent", float(safe) / trials >= 0.95)
		print("trade_entry_rate: " + JSON.stringify({"interior": entry.id, "idle_entries": trials, "idle_safe": safe, "simulated_seconds": ceili(2.0 * Engine.physics_ticks_per_second / Engine.time_scale) * Engine.time_scale / Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "price_before_entry": price_ok}))
	acts.clear()
	await physics_frame
	Engine.time_scale = 1.0
	await _summary(game, model, interiors)
	game.free()
	await process_frame

func _appearance_recency(game, model, site) -> void:
	var run = game.run
	var acts = game.world.activities
	var outside: Vector3 = site.global_position + Vector3(200.0, 0.0, 200.0)
	game.player.reset_to(outside)
	game.player.active_body().global_position = outside
	t.check("skipped trade player outside approach radius", Vector2(outside.x, outside.z).distance_to(Vector2(site.global_position.x, site.global_position.z)) > site.footprint.z * 0.5 + 16.0)
	acts._watch_trade(site, game.player.ball_position())
	t.eq("skipped trade stays unvisited", run.summary().trade_pockets, [])
	var placed: Dictionary = run.trade_memory.offers["1"].duplicate(true)
	var after_placement: Dictionary = run.trade_memory.duplicate(true)
	var cached: Dictionary = model.stage_site(acts._graph, game.ctx.terrain.map(), run, game.ctx.rng.seed, PackedInt32Array())
	t.eq("cached placement returns identical skipped trade", cached, placed)
	t.eq("cached placement does not mutate appearance memory", run.trade_memory, after_placement)
	run.restore()
	t.eq("retry restores pre-placement appearance odds", model.odds(run.trade_memory, 2).recency, 1.0)
	acts._on_stage_entered(1, true)
	t.eq("retry replays identical skipped trade placement", run.trade_memory.offers["1"], placed)
	var replayed: Array = acts.sites.filter(func(row): return not row.trade.is_empty())
	t.eq("retry rebuilds one skipped trade", replayed.size(), 1)
	if not replayed.is_empty():
		acts._watch_trade(replayed[0], game.player.ball_position())
	run.enter_stage(2)
	t.eq("unvisited appearance next-stage multiplier x0.25", model.odds(run.trade_memory, 2).recency, 0.25)
	t.eq("unvisited appearance next-stage chance", model.odds(run.trade_memory, 2).chance, 0.1125)
	t.eq("unvisited appearance leaves summary empty next stage", run.summary().trade_pockets, [])
	run.enter_stage(3)
	t.eq("unvisited appearance two-stage multiplier x0.5", model.odds(run.trade_memory, 3).recency, 0.5)
	t.eq("unvisited appearance two-stage chance", model.odds(run.trade_memory, 3).chance, 0.225)
	t.eq("unvisited appearance leaves summary empty two stages later", run.summary().trade_pockets, [])
	run.enter_stage(4)
	t.eq("unvisited appearance penalty expires after two stages", model.odds(run.trade_memory, 4).recency, 1.0)
	t.eq("expired appearance chance returns to base", model.odds(run.trade_memory, 4).chance, 0.45)

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
	var played: String = game.screens.body_text()
	t.check("a played run's summary keeps the odds readout off", not played.contains("recency x") and not played.contains("refusal x") and not played.contains("pool floor"), played)
	game.dev = true
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

func _entrance_round_trip(model) -> void:
	var Run = load("res://src/core/run_state.gd")
	var ClassDef = load("res://src/core/class_def.gd")
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var Map = load("res://src/world/park/park_map.gd")
	var Graph = load("res://src/world/park/park_graph.gd")
	var run = Run.new()
	run.begin(ClassDef.all()[0])
	var risk := {"stage": 1, "family": "risk", "interior_id": "blood_counter", "chance": 0.45, "recency": 1.0, "safe_share": 0.5, "refusal_weight": 1.0, "skip_time": 0.0, "curse": false, "sacrifice": false, "sacrifice_chance": 11.0 / 28.0, "full_health_bump": true, "pool_floor": 0.0, "tier": 1}
	var refused := risk.merged({"stage": 2, "interior_id": "scrap_counter", "recency": 0.25, "chance": 0.1125, "safe_share": 0.0}, true)
	model.appear(run.trade_memory, risk)
	model.see(run.trade_memory, risk)
	model.decide(run.trade_memory, risk, true)
	run.enter_stage(2)
	model.appear(run.trade_memory, refused)
	model.see(run.trade_memory, refused)
	model.decide(run.trade_memory, refused, false)
	# A completed stage's cached placement includes native vectors, lost by raw JSON.
	run.trade_memory.offers["2"] = Library.site_spec(Library.trade("scrap_counter")).merged({"node": 11224, "at": Vector2(128, -32), "id": "trade_risk", "trade": refused})
	run.enter_stage(3)
	var prior := {"risk_taken": true, "last_appeared": 2, "last_seen": 2, "last_refused": 2, "seen": [risk, refused], "offers": {"2": Library.site_spec(Library.trade("scrap_counter")).merged({"node": 11224, "at": Vector2(128, -32), "id": "trade_risk", "trade": refused})}, "decisions": {"1": true, "2": false}}
	t.eq("Continue fixture prior memory matches literal choices", run.trade_memory, prior)
	run.snapshot(Vector3(1, 2, 3), Vector3(0, 0, 20), 0.5)
	var map = Map.new("res://src/world/park/park_pit.json")
	var graph = Graph.read("res://assets/park/park_pit/graph.bin")
	var pool: PackedInt32Array = model.candidates(graph, map)
	var placed := {}
	for seed_value in 100:
		run.run_seed = seed_value
		run.trade_memory = prior.duplicate(true)
		placed = model.stage_site(graph, map, run, 78000, pool)
		if not placed.is_empty():
			break
	t.check("Continue fixture entrance has a seeded offer", not placed.is_empty())
	if placed.is_empty():
		return
	model.see(run.trade_memory, placed.trade)
	model.decide(run.trade_memory, placed.trade, true)
	var doc: Dictionary = JSON.parse_string(JSON.stringify(run.to_entrance_doc(), "", true, true))
	t.check("entrance document serializes checkpoint trade memory", doc.has("trade_memory"))
	t.eq("trade entrance JSON validates", Run.validate_entrance_doc(doc), "")
	var risk_json: Dictionary = JSON.parse_string(JSON.stringify(risk, "", true, true))
	var refused_json: Dictionary = JSON.parse_string(JSON.stringify(refused, "", true, true))
	var banked: Dictionary = prior.duplicate(true)
	banked.seen = [risk_json, refused_json]
	banked.offers["2"].trade = refused_json
	var restored = Run.new()
	t.check("trade entrance JSON restores", restored.from_entrance_doc(doc))
	t.eq("Continue keeps same run identity", restored.run_id, run.run_id)
	t.eq("Continue keeps entrance stage", restored.stage, 3)
	t.eq("Continue prior risk purchase keeps safe odds zero", model.odds(restored.trade_memory, 3).safe_share, 0.0)
	t.eq("Continue retains prior appearance timestamp", restored.trade_memory.last_appeared, 2)
	t.eq("Continue retains prior refusal timestamp", restored.trade_memory.last_refused, 2)
	t.eq("Continue retains prior seen timestamp", restored.trade_memory.last_seen, 2)
	t.eq("Continue prior seen records reach results", restored.summary().trade_pockets, [risk_json, refused_json])
	t.eq("Continue restores all prior checkpoint trade memory", restored.trade_memory, banked)
	t.check("Continue rolls back current-stage purchase", not restored.trade_memory.decisions.has("3"))
	t.check("Continue rolls back current-stage appearance cache", not restored.trade_memory.offers.has("3"))
	var replayed: Dictionary = model.stage_site(graph, map, restored, 78000, pool)
	t.eq("Continue rebuilds identical entrance offer", replayed, placed)
	restored.restore()
	t.eq("Continue retry restores banked trade memory", restored.trade_memory, banked)
	var legacy: Dictionary = doc.duplicate(true)
	legacy.erase("trade_memory")
	var old = Run.new()
	t.check("older entrance without trades remains valid", old.from_entrance_doc(legacy))
	t.eq("older entrance defaults to fresh trade memory", old.trade_memory, {"risk_taken": false, "last_appeared": -100, "last_seen": -100, "last_refused": -100, "seen": [], "offers": {}, "decisions": {}})
	# Reject malformed optional memory before applying any of the entrance.
	var valid := {"risk_taken": true, "last_appeared": 2, "last_seen": 2, "last_refused": 2, "seen": [risk, refused], "offers": {}, "decisions": {"1": true, "2": false}}
	for change in [{"risk_taken": "true"}, {"last_appeared": 2.5}, {"last_refused": 4}, {"seen": [risk, risk]}, {"seen": [risk.merged({"interior_id": "ward_counter"}, true)]}, {"seen": [risk.merged({"recency": "bad"}, true)]}, {"decisions": {"1": "true"}}, {"offers": {"2": {"at": [1], "node": 1, "trade": refused}}}]:
		var bad: Dictionary = doc.duplicate(true)
		bad["trade_memory"] = valid.merged(change, true)
		t.check("malformed trade entrance rejected " + str(change.keys()), not Run.validate_entrance_doc(bad).is_empty())
		var untouched = Run.new()
		untouched.run_id = "unchanged"
		t.check("malformed trade entrance is atomic " + str(change.keys()), not untouched.from_entrance_doc(bad) and untouched.run_id == "unchanged")


# Ruling ci: purple means the Kindness, and the Mind elsewhere. The Kindness glow (stake_devices.gd glow_material) is
# hue 300 to 330, lit and unlit; nothing else World 1 draws falls in that band: no other Palette colour, no World 1
# light (WorldLook's world row, its dawn and morning acts, the camp), no material on a gamble's or a kindness's body
# but the glow, and no record sleeve in the camp. A grey has no hue, so a colour under KIND_S saturation is not one.
const KIND_LOW := 300.0
const KIND_HIGH := 330.0
const KIND_S := 0.15

func _in_band(c: Color) -> bool:
	return c.s >= KIND_S and c.h * 360.0 >= KIND_LOW and c.h * 360.0 <= KIND_HIGH

func _colours_in(value, out: Array) -> Array:
	if value is Color:
		out.append(value)
	elif value is Dictionary:
		for k in value:
			_colours_in(value[k], out)
	elif value is Array:
		for v in value:
			_colours_in(v, out)
	return out

func _kindness_hue(model) -> void:
	var Stake = load("res://src/world/stake_devices.gd")
	var Palette = load("res://src/core/palette.gd")
	var WorldLook = load("res://src/presentation/world_look.gd")
	var CampHub = load("res://src/world/camp_hub.gd")
	var glow: StandardMaterial3D = Stake.glow_material()
	t.check("the Kindness glow is hue 300 to 330, its light and its colour", _in_band(glow.emission) and _in_band(glow.albedo_color),
		"emission %.1f, albedo %.1f" % [glow.emission.h * 360.0, glow.albedo_color.h * 360.0])
	t.check("the Kindness glow is Palette.KINDNESS", glow.emission == Palette.KINDNESS)
	var strays: Array = []
	var consts: Dictionary = Palette.get_script_constant_map()
	for name in consts:
		if consts[name] is Color and name != "KINDNESS" and _in_band(consts[name]):
			strays.append("Palette.%s" % name)
	for key in ["ROWS", "TIME_ROWS", "CAMP"]:
		var table = WorldLook.get_script_constant_map()[key]
		var rows: Array = [table[1]] if key == "ROWS" else [table["dawn"], table["morning"]] if key == "TIME_ROWS" else [table]
		for c in _colours_in(rows, []):
			if _in_band(c):
				strays.append("WorldLook.%s %s" % [key, c.to_html()])
	for material in [Stake.cast_material(), Stake.bolt_material(), Stake.chalk_material()]:
		for c in [material.albedo_color, material.emission]:
			if _in_band(c):
				strays.append("stake_devices %s" % material.resource_name)
	for c in CampHub.SLEEVE_INKS:
		if _in_band(c):
			strays.append("camp sleeve %s" % c.to_html())
	t.check("no other World 1 colour or material is in the Kindness band", strays.is_empty(), str(strays))
	# The spot's owner rides on its devices: the gamble's two are the gamble's, the kindness's two the kindness's.
	var risk: Array = model.devices({"family": "risk", "tier": 2})
	var safe: Array = model.devices({"family": "safe", "tier": 1})
	t.check("a risky spot's devices are the gamble's, a safe spot's the kindness's",
		risk.all(func(d): return d.owner == "gamble") and safe.all(func(d): return d.owner == "kindness") and risk.size() == 2 and safe.size() == 2)
