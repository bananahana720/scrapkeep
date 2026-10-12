extends SceneTree

const Game := preload("res://src/game.gd")
const Activities := preload("res://src/world/activities.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Intent := preload("res://src/movement/intent.gd")
const KINDS := ["movement_course", "arena", "elite_arena", "objective_limit", "round_arena", "ambush", "scattered_marks"]
const STAGES := ["park_dam", "park_test"]
const EXPECTED_CHECKS := 28
const H := 1.0 / 60.0

var t := preload("res://tests/support/t.gd").new("pocket_kinds_test")
var game
var acts
var graphs := {}
var paid := []
var only := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--only" in args:
		var index := args.find("--only")
		if index + 1 < args.size():
			only = args[index + 1]
		if not only in ["ladder", "ambush", "hazards", "exit"]:
			t.check("valid control selection", false, str(args))
			quit(t.verdict())
			return
	var missing := KINDS.filter(func(k): return not Activities.RULES.has(k))
	t.eq("all seven pocket kinds have fixed rules", missing, [])
	if not missing.is_empty():
		t.eq("red-first expected check count", t.checks, 1)
		quit(t.verdict())
		return
	game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.world.set_physics_process(false)
	game.flow.set_physics_process(false)
	acts = game.world.activities
	acts.set_physics_process(false)
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	acts.clear()
	game.run.set_max_hp(99999.0)
	game.events.part_gained.connect(func(id, source):
		if source.begins_with("pocket_"):
			paid.append(id))
	for id in STAGES:
		graphs[id] = Graph.read("res://assets/park/%s/graph.bin" % id)
	if only == "":
		_ladder()
		await _combat()
		_objectives()
		_rounds()
		_cues()
		await _ambush()
		await _hazards()
		await _marks()
		await _exit()
	elif only == "ladder":
		_ladder()
	elif only == "ambush":
		await _ambush()
	elif only == "hazards":
		await _hazards()
	elif only == "exit":
		await _exit()
	var want: int = {"": EXPECTED_CHECKS, "ladder": 5, "ambush": 5, "hazards": 4, "exit": 4}[only]
	t.eq("expected check count", t.checks, want - 1)
	game.free()
	quit(t.verdict())


func _site(kind: String, at := Vector2(100, 100), extra := {}):
	var spec := {"id": kind, "at": at}
	spec.merge(extra, true)
	var s = acts._build(kind, at, spec)
	acts.sites.append(s)
	return s


func _kill(pack: Array) -> void:
	for enemy in pack.duplicate():
		if is_instance_valid(enemy) and not enemy.is_dead():
			enemy._die()


func _ladder() -> void:
	var rise := true
	var equals_paid := true
	var shown := true
	var checks := 0
	var grants := 0
	for stage in STAGES:
		var path := "res://src/world/park/%s.json" % stage
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var count := 0
		for row in data.activity_rows:
			var previous := 0
			for kind in KINDS.slice(0, 4):
				var s = _site(kind, Vector2(row.at[0], row.at[1]))
				var tier: int = acts.stand_odds(s).tier
				rise = rise and tier > previous
				previous = tier
				shown = shown and s.tier_label.text.contains("Tier %d" % tier)
				for seed_value in 20:
					game.ctx.rng.seed = 100 + seed_value
					acts._finish(s, s.global_position)
					var bundle: Array = s.pickup_parts.duplicate()
					var expected_rarity := "common" if kind == "movement_course" else "rare"
					var actual := 1 if bundle.size() == 1 and Parts.rarity_of(bundle[0]) == "common" else bundle.size() + 1
					equals_paid = equals_paid and bundle.all(func(part): return Parts.rarity_of(part) == expected_rarity and game.ctx.stages.part_in_play(part))
					equals_paid = equals_paid and actual == tier
					# Take the real pickup, proving the part in the run, not only the offer.
					s.inside_pickup = false
					var before := paid.size()
					acts._watch_pickup(s, s.global_position)
					equals_paid = equals_paid and paid.slice(before) == bundle
					grants += paid.size() - before
					checks += 1
					s.done = false
					s.pickup_taken = false
				count += 1
		print("tier-rise stage file: %s; %d sites x four kinds x 20 seeds" % [path, data.activity_rows.size()])
		acts.clear()
	t.check("tier rises on both stage files", rise, "park_dam and park_test: every authored activity site, four ascending rungs")
	t.check("shown-equals-paid over 20 seeds", equals_paid and checks == 480 and grants == 840, "%d chests / %d real part grants, expected 480/840" % [checks, grants])
	t.check("tier shown before commit", shown, "all 24 stands carry their reward tier")


func _combat() -> void:
	var s = _site("arena")
	game.run.hp = game.run.max_hp - 100.0
	var hurt: float = game.run.hp
	acts.step_pocket(s, H, s.global_position)
	t.check("arena fixed bundle", s.started and s.pack.size() == 3 and s.hazards.size() >= 1, "three enemies and an active pocket hazard")
	_kill(s.pack)
	acts.step_pocket(s, H, s.global_position)
	t.check("arena clear heals and opens one chest", s.done and s.pickup != null and s.heal_paid and game.run.hp > hurt, "clear creates the reward pickup and restores wounded health once")
	acts.clear()
	var arrivals := 0
	var vanished := true
	for i in 4:
		s = _site("elite_arena", Vector2(100 + i * 20, 100))
		acts.step_pocket(s, H, s.global_position)
		if s.started:
			arrivals += 1
			var members: Array = s.pack.duplicate()
			s.brute._die()
			await physics_frame
			vanished = vanished and Activities._alive(members) == 0 and Activities._alive(s.pack) == 0 and s.done
	t.check("elite death leaves zero pocket enemies within 1 s", vanished and arrivals == 3, "one physics frame after death; three accepted elites")
	t.eq("elite arrivals per stage capped at three", arrivals, 3)
	acts.clear()


func _objectives() -> void:
	var movement = _site("movement_course")
	acts.step_pocket(movement, H, movement.global_position)
	for point in movement.targets:
		acts.step_pocket(movement, H, point)
	t.check("movement course has no gate", movement.done and movement.pack.is_empty(), "course finishes from its rolling targets without enemies or a progression gate")
	var objective = _site("objective_limit")
	acts.step_pocket(objective, H, objective.global_position)
	var ticks: int = objective.ticks
	game.flow.state = game.flow.TITLE
	acts._physics_process(H)
	t.eq("objective does not count ticks outside stage", objective.ticks, ticks)
	game.flow.state = game.flow.STAGE
	acts.step_pocket(objective, H, objective.targets[0])
	t.check("timed objective pickup pays", objective.done and objective.ticks == ticks + 1, "pickup reached before tick limit")
	var late = _site("objective_limit")
	for i in int(late.rule.limit_ticks) + 1:
		acts.step_pocket(late, H, late.global_position)
	t.check("timed objective fails at tick limit without pay", late.failed and not late.done and late.pickup == null, "integer objective ticks, no wall clock")
	acts.clear()


func _rounds() -> void:
	var s = _site("round_arena", Vector2(100, 100), {"difficulty": 100.0})
	var formula := true
	var additions := true
	var lead := true
	var pay_count := 0
	var granted_before := paid.size()
	var cogs_before: int = game.run.cogs
	var announced := -1.0
	for round_index in 3:
		acts.step_pocket(s, H, s.global_position)
		announced = s.fog.director.stage_time
		while not s.fog.active:
			acts.step_pocket(s, H, s.global_position)
		lead = lead and s.fog.director.stage_time - announced >= 3.0 - 0.000001
		var want := (12.0 + 6.0 * round_index) * 3.0
		formula = formula and absf(s.round_credits - want) / want <= 0.01 and s.pack.size() == int(want / 6.0)
		var seen := {}
		for enemy in s.pack:
			seen[String(enemy.kind)] = true
		additions = additions and s.round_elements.size() == round_index + 1 and seen.keys() == s.round_elements
		_kill(s.pack)
		acts.step_pocket(s, H, s.global_position)
		for reward in s.round_rewards.duplicate():
			reward.inside = false
			acts._watch_round_pickups(s, reward.pickup.global_position)
		pay_count += 1
	t.check("round credits formula within 1 percent with D capped", formula, "(12 + 6 x (round - 1)) x min(D,3); three rounds")
	t.check("each round adds exactly one element", additions and s.round_elements == ["chaser", "lobber", "plated_brute"], str(s.round_elements))
	t.check("pay events equal round count", s.round_payments == pay_count and pay_count == 3 and s.done and paid.size() - granted_before == 3 and game.run.cogs - cogs_before == 702, "%d round payments; three part_gained events; 162 credits + 540 scrap cogs" % s.round_payments)
	t.check("safe zone announced at least natural family lead", lead, "all three safe zones announced at least 3 s before spawn")
	acts.clear()


func _cues() -> void:
	var shared := true
	var audio = game.presentation.audio
	for kind in KINDS:
		var s = _site(kind, Vector2(100, 100), {"graph": graphs.park_test})
		for phase in ["telegraph", "clear", "pay"]:
			audio._last_start.clear()
			acts._cue(s, phase)
			var key := String(s.rule.cue[phase])
			var row := preload("res://src/core/event_kinds.gd").row(key)
			shared = shared and s.phase_view.get_child(0).material_override.albedo_color == row.color
			shared = shared and not audio.cue_log.is_empty() and audio.cue_log.back()[0] == key and audio.cue_log.back()[1] == row.sound
		acts.clear()
	t.check("sight and sound consume each kind's shared cue record", shared, "seven kinds x telegraph, clear and pay: 21 constructed glyph materials and audio log sounds")


func _ambush() -> void:
	var waves := true
	var route_hits := 0
	var clears := 0
	for seed_value in 20:
		game.ctx.rng.seed = 500 + seed_value
		var s = _site("ambush", Vector2(500, 300), {"graph": graphs.park_test})
		for wave in 3:
			acts.step_pocket(s, H, s.global_position)
			waves = waves and s.pack.size() >= 1 and s.pack.size() <= 5 and s.wave == wave + 1
			for e in s.pack:
				route_hits += int((graphs.park_test.flags(graphs.park_test.nearest(e.global_position)) & Graph.LINE) != 0)
			_kill(s.pack)
			acts.step_pocket(s, H, s.global_position)
		clears += int(s.done)
		acts.clear()
		await physics_frame
	t.check("ambush three waves of one to five", waves, "20 seeds, 60 waves")
	t.check("ambush opens on clear in 100 percent", clears == 20, "%d/20 clear" % clears)
	t.eq("zero-main-route ambush placements", route_hits, 0)


func _hazards() -> void:
	var outside := 0
	var after := 0
	var active := 0
	var cases := []
	for kind in ["arena", "elite_arena", "round_arena", "ambush"]:
		cases.append({"kind": kind, "at": Vector2(100, 100), "extra": {}})
	var authored := 0
	for stage in STAGES:
		var path := "res://src/world/park/%s.json" % stage
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for row in data.activity_rows:
			if row.activity == "enemy_camp":
				cases.append({"kind": "enemy_camp", "at": Vector2(row.at[0], row.at[1]), "extra": {"site": row.site, "pay": row.pay}})
				authored += 1
		print("authored arena hazard check: " + path)
	for seed_value in 20:
		game.ctx.rng.seed = seed_value
		for fixture in cases:
			var s = _site(fixture.kind, fixture.at, fixture.extra)
			var hazard = s.hazards[0]
			hazard.begin(1)
			for i in 185:
				hazard.advance(H, s.global_position)
			var edge: Vector3 = s.global_position + Vector3(12, 0, 0)
			active += int(hazard.damage_at(edge) > 0.0)
			outside += int(hazard.damage_at(s.global_position + Vector3(40, 0, 0)) > 0.0)
			outside += int(hazard.damage_at(s.global_position) > 0.0)
			acts._finish(s, s.global_position)
			after += int(hazard.damage_at(edge) > 0.0)
			acts.clear()
		await physics_frame
	t.check("no damage outside committed fog geometry", outside == 0 and active == 120 and authored == 2, "120 live hazards, including both authored park arenas; outside footprint and inside safe zone: %d hits" % outside)
	t.check("zero-hazard-after-clear in 100 percent", after == 0, "%d/120 hazards still damaging after clear" % after)


func _marks() -> void:
	var spacing := true
	var far := true
	var counts := true
	var draws := 0
	var count_histogram := {}
	var disconnected := 0
	var too_close := 0
	var minimum_pair := INF
	for stage in STAGES:
		var g = graphs[stage]
		var pool: Array = acts.mark_candidates(g)
		var far_cutoff: float = acts.mark_far_m(g)
		var distance_cache := {}
		var reach_cache := {}
		for seed_value in 1000:
			var marks: Array = acts.draw_marks(g, seed_value, pool)
			count_histogram[marks.size()] = int(count_histogram.get(marks.size(), 0)) + 1
			counts = counts and marks.size() >= 3 and marks.size() <= 4
			for a in marks:
				far = far and g.d_spawn_node(a) >= far_cutoff
				if not distance_cache.has(a):
					# Directed reachability proves each pair has a finite path; bounded
					# Dijkstra independently detects every pair shorter than 80 m.
					distance_cache[a] = g.search(PackedInt32Array([a]), false, 80.0)
					reach_cache[a] = g.reach(PackedInt32Array([a]))
				for b in marks:
					if a != b:
						var metres: float = distance_cache[a][b]
						spacing = spacing and metres >= 80.0 and reach_cache[a][b] != 0
						disconnected += int(reach_cache[a][b] == 0)
						if is_finite(metres):
							minimum_pair = minf(minimum_pair, metres)
						too_close += int(metres < 80.0)
			draws += 1
		print("scattered marks: %s; 1000 seeded draws; %d candidates" % [stage, pool.size()])
		await physics_frame
	t.check("scattered marks count and path spacing", counts and spacing and draws == 2000, "2000 draws; counts=%s; disconnected=%d; under80=%d; smallest bounded pair=%s" % [count_histogram, disconnected, too_close, minimum_pair])
	t.check("every scattered mark in far half by path", far, "distance from spawn >= half farthest reachable objective-fit node")
	var s = _site("scattered_marks", Vector2(100, 100), {"graph": graphs.park_test})
	var reverse_order: Array = s.targets.duplicate()
	reverse_order.reverse()
	for p in reverse_order:
		acts.step_pocket(s, H, p)
	var before := paid.size()
	s.inside_pickup = false
	acts._watch_pickup(s, s.global_position)
	t.check("marks found in any order pay like a pocket", s.done and s.pickup_taken and paid.size() == before + 1 and Parts.rarity_of(paid.back()) == "rare", "reverse collection order grants one approved rare part and pocket scrap")
	acts.clear()


func _exit() -> void:
	var open := true
	var opened := 0
	for seed_value in 1000:
		game.ctx.rng.seed = seed_value
		var s = _site("scattered_marks", Vector2(100, 100), {"graph": graphs.park_test})
		game.flow._unseal()
		acts.step_pocket(s, H, Vector3(-700, 0, -700))
		var this_open: bool = game.flow.state == game.flow.GATES and not game.flow.sealed and s.marks_taken == 0
		open = open and this_open
		opened += int(this_open)
		acts.clear()
		if seed_value % 20 == 19:
			await physics_frame
	t.check("exit-opens-with-zero-marks in 100 percent", open and opened == 1000, "%d/1000 real flow unseals with no mark taken" % opened)
	for kind in KINDS:
		_site(kind, Vector2(100, 100), {"graph": graphs.park_test})
	game.flow._unseal()
	acts._physics_process(H)
	t.check("exit opens with every pocket untouched", game.flow.state == game.flow.GATES and not game.flow.sealed and acts.sites.all(func(s): return not s.done), "all seven optional kinds remain unfinished")
	acts.clear()
