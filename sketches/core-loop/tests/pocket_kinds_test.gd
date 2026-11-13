extends SceneTree

const Game := preload("res://src/game.gd")
const Activities := preload("res://src/world/activities.gd")
const ActivityView := preload("res://src/world/activity_view.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const Rows := preload("res://src/core/event_kinds.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const Intent := preload("res://src/movement/intent.gd")
const KINDS := ["movement_course", "arena", "elite_arena", "objective_limit", "round_arena", "ambush", "scattered_marks"]
const STAGES := ["park_dam", "park_test"]
const EXPECTED_CHECKS := 35
const H := 1.0 / 60.0

class Checks extends "res://tests/support/t.gd":
	var failed_labels: Array = []

	func check(label: String, ok: bool, detail: String = "") -> bool:
		if not ok:
			failed_labels.append(label + ": " + detail)
		return super.check(label, ok, detail)


var t := Checks.new("pocket_kinds_test")
var game
var acts
var graphs := {}
var paid := []
var only := ""
var warden_kills := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--only" in args:
		var index := args.find("--only")
		if index + 1 < args.size():
			only = args[index + 1]
		if not only in ["ladder", "ambush", "hazards", "exit", "recovery", "admission", "cues", "pay", "marks", "rounds", "combat_cues", "preview"]:
			t.check("valid control selection", false, str(args))
			quit(t.verdict())
			return
	var missing := KINDS.filter(func(k): return not Activities.RULES.has(k))
	t.eq("all seven pocket kinds have fixed rules", missing, [])
	if not missing.is_empty():
		t.eq("red-first expected check count", t.checks, 1)
		quit(t.verdict())
		return
	await _boot_game()
	for id in STAGES:
		graphs[id] = Graph.read("res://assets/park/%s/graph.bin" % id)
	if only == "":
		_admission()
		_preview()
		_ladder()
		await _authored_pay()
		await _combat()
		_objectives()
		_rounds()
		_cues()
		await _ambush()
		await _hazards()
		await _marks()
		await _exit()
	elif only == "combat_cues":
		await _combat()
		_rounds()
		_cues()
	elif only == "rounds":
		_rounds()
	elif only == "marks":
		await _marks()
	elif only == "pay":
		await _authored_pay()
	elif only == "cues":
		_cues()
	elif only == "admission":
		_admission()
	elif only == "ladder":
		_ladder()
	elif only == "preview":
		_preview()
	elif only == "ambush":
		await _ambush()
	elif only == "hazards":
		await _hazards()
	elif only == "exit":
		await _exit()
	elif only == "recovery":
		game.run.set_max_hp(100.0)
		await _combat()
		_rounds()
	var want: int = {"": EXPECTED_CHECKS, "ladder": 5, "ambush": 5, "hazards": 4, "exit": 5, "recovery": 12, "admission": 3, "cues": 3, "pay": 3, "marks": 5, "rounds": 8, "combat_cues": 13, "preview": 4}[only]
	t.eq("expected check count", t.checks, want - 1)
	for failure in t.failed_labels:
		print("failed check: " + failure)
	game.free()
	quit(t.verdict())


func _boot_game() -> void:
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
	print("pocket context: run_id=%s class=%s" % [game.run.run_id, game.run.class_id()])
	acts.clear()
	game.run.set_max_hp(99999.0)
	game.events.enemy_killed.connect(func(kind, _at, _scrap):
		if kind == "warden":
			warden_kills += 1)
	game.events.part_gained.connect(func(id, source):
		if source.begins_with("pocket_"):
			paid.append(id))


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


func _admitted(stage: String, kind: String, row_index: int, default_pay := false, override := {}) -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % stage))
	data.activity_rows[row_index].activity = kind
	# A speed bar (W1-76) belongs to a cracked cache; retyped as another kind, the site drops it.
	if kind != "cracked_cache":
		data.activity_rows[row_index].erase("bar")
	# Alternatives (W1-70) keep their row's kind and role; retyped, the site drops them and builds the new kind.
	data.activity_rows[row_index].erase("alts")
	if default_pay:
		data.activity_rows[row_index].pay = {}
	if not override.is_empty():
		data.activity_rows[row_index].pay = override
	var errors: Array = Schema.validate(data)
	if not errors.is_empty():
		return []
	var path := "user://pocket-admission.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var map := ParkMap.new(path)
	if not map.ok:
		return []
	var index: int = game.ctx.terrain.stage - 1
	var previous = game.ctx.terrain.maps[index]
	game.ctx.terrain.maps[index] = map
	acts._on_stage_entered(game.run.stage, false)
	game.ctx.terrain.maps[index] = previous
	return [acts.sites[row_index], map.activity_sites[row_index]]


func _admission() -> void:
	var admitted := 0
	var pay_retained := true
	for stage in STAGES:
		for kind in KINDS:
			var built := _admitted(stage, kind, 0)
			if not built.is_empty():
				admitted += int(built[0].id == kind and built[1].id == kind)
				var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % stage))
				pay_retained = pay_retained and built[1].pay == data.activity_rows[0].pay
			acts.clear()
	t.check("new kinds admitted through schema ParkMap and stage entry", admitted == 14 and pay_retained, "%d/14 substitutions across park_dam and park_test; authored pay retained" % admitted)


func _preview() -> void:
	var readable := 0
	var hidden := 0
	for kind in KINDS:
		for pay in [{}, {"rarities": ["common"]}, {"rarities": ["rare"]}, {"named": "hot_rivets", "rarities": ["rare"]}]:
			var rule: Dictionary = Activities.RULES[kind]
			var s = _site(kind, Vector2(100, 100), {"graph": graphs.park_test, "pay": pay})
			var named: String = String(pay.get("named", ""))
			var parts := 1 if named != "" else int(rule.pay.parts)
			var rarity: String = Parts.rarity_of(named) if named != "" else String(pay.get("rarities", rule.pay.rarities)[0])
			var tier := parts + (1 if rarity == "rare" else 0)
			var reward := Parts.display_name(named) if named != "" else "%d %s parts" % [parts, rarity]
			var expected := "%s — Tier %d (%s)" % [rule.cue.word, tier, reward]
			var labels: Array = s.find_children("*", "Label3D", true, false)
			s.view.near(s.global_position + Vector3.RIGHT * (ActivityView.WORD_REACH + 1.0))
			var outside_hidden: bool = labels.all(func(label): return not label.is_visible_in_tree())
			var distance := (float(rule.ring) + ActivityView.WORD_REACH) * 0.5
			var ball: Vector3 = s.global_position + Vector3.RIGHT * distance
			s.view.near(ball)
			acts.step_pocket(s, H, ball)
			var visible: Array = labels.filter(func(label): return label.is_visible_in_tree())
			var preview_ok: bool = distance > float(rule.ring) and distance < ActivityView.WORD_REACH and not s.started and not s.done and not s.failed
			var text_ok: bool = visible.size() == 1 and visible[0].text == expected
			readable += int(outside_hidden and preview_ok and text_ok)
			if not outside_hidden or not preview_ok or not text_ok:
				print("preview mismatch: %s pay=%s visible=%d want='%s'" % [kind, pay, visible.size(), expected])
			acts._finish(s, s.global_position)
			s.view.near(ball)
			hidden += int(s.done and labels.all(func(label): return not label.is_visible_in_tree()))
			acts.clear()
	t.check("one visible resolved reward label before commitment", readable == 28, "%d/28 previews: seven kinds x default/common/rare/named; outside start ring and inside WORD_REACH; hidden beyond reach" % readable)
	t.check("completed pockets hide their stand label", hidden == 28, "%d/28 completions stay hidden after view.near" % hidden)


func _ladder() -> void:
	var held: Array = game.run.parts.duplicate()
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
			# A park's opt-in relay (SR10) is an event beside the pockets, not a pocket site.
			if row.activity == "hold_the_relay":
				continue
			var previous := 0
			for kind in KINDS.slice(0, 4):
				var admitted := _admitted(stage, kind, data.activity_rows.find(row), true)
				if admitted.is_empty():
					rise = false
					continue
				var s = admitted[0]
				var tier: int = acts.stand_odds(s).tier
				rise = rise and tier > previous
				previous = tier
				shown = shown and s.tier_label.text.contains("Tier %d" % tier)
				for seed_value in 20:
					game.ctx.rng.seed = 100 + seed_value
					s = _site(kind, admitted[1].at, admitted[1])
					shown = shown and s.tier_label.text.contains("Tier %d" % tier)
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
					equals_paid = equals_paid and bundle.all(func(part): return game.run.part_count(part) - held.count(part) >= bundle.count(part))
					grants += paid.size() - before
					game.run.parts.assign(held)
					checks += 1
					s.done = false
					s.pickup_taken = false
				game.ctx.build.recompute()
				count += 1
		print("tier-rise stage file: %s; %d sites x four kinds x 20 seeds" % [path, data.activity_rows.size()])
		acts.clear()
	t.check("tier rises on both stage files", rise, "park_dam and park_test: every authored activity site, four ascending rungs")
	t.check("shown-equals-paid over 20 seeds", equals_paid and checks == 560 and grants == 980, "%d chests / %d real part grants, expected 560/980 (seven authored sites with the dam incline cache)" % [checks, grants])
	t.check("tier shown before commit", shown, "all 28 stands carry their reward tier")


func _authored_pay() -> void:
	var held: Array = game.run.parts.duplicate()
	var correct := true
	var cases := 0
	var grants := 0
	for stage in STAGES:
		for kind in KINDS:
			for fixture in [{"row": 0, "pay": {}}, {"row": 1, "pay": {}}, {"row": 2, "pay": {}}, {"row": 0, "pay": {"rarities": ["common"]}}, {"row": 0, "pay": {"rarities": ["rare"]}}, {"row": 0, "pay": {"named": "hot_rivets", "rarities": ["rare"]}}]:
				var admitted := _admitted(stage, kind, fixture.row, false, fixture.pay)
				if admitted.is_empty():
					correct = false
					continue
				var spec: Dictionary = admitted[1].duplicate(true)
				spec.graph = graphs[stage]
				acts.clear()
				for seed_value in 20:
					game.ctx.rng.seed = 700 + seed_value
					var s = _site(kind, spec.at, spec)
					var pay: Dictionary = spec.pay
					var named := String(pay.get("named", ""))
					var count := 1 if named != "" else int(Activities.RULES[kind].pay.parts)
					var shown: int = acts.stand_odds(s).tier
					var label: String = s.tier_label.text
					if fixture.row == 2:
						game.ctx.rng.seed += 10000
					var before := paid.size()
					if kind == "round_arena":
						s.round = 1
						s.fog.begin(1)
						acts._pay_round(s)
						for reward in s.round_rewards.duplicate():
							reward.inside = false
							acts._watch_round_pickups(s, reward.pickup.global_position)
					else:
						acts._finish(s, s.global_position)
						s.inside_pickup = false
						acts._watch_pickup(s, s.pickup.global_position)
					var taken: Array = paid.slice(before)
					correct = correct and taken.all(func(part): return game.run.part_count(part) - held.count(part) >= taken.count(part))
					var paid_tier := taken.size()
					if taken.any(func(part): return Parts.rarity_of(part) == "rare"):
						paid_tier += 1
					correct = correct and shown == paid_tier and label.contains("Tier %d" % paid_tier)
					correct = correct and taken.size() == count and taken.all(func(part): return part == named if named != "" else Parts.rarity_of(part) in pay.rarities)
					correct = correct and label.contains(Parts.display_name(named)) if named != "" else correct and taken.all(func(part): return label.contains(Parts.rarity_of(part)))
					grants += taken.size()
					game.run.parts.assign(held)
					cases += 1
					acts.clear()
				game.ctx.build.recompute()
				await physics_frame
	t.check("authored pay overrides default bundles over 20 seeds", correct and cases == 1680, "%d/1680 cases, %d actual grants; both parks x seven kinds x three authored rows plus common/rare/named x 20 seeds; shown tier from resolved payout" % [cases, grants])


func _combat() -> void:
	var s = _site("arena")
	game.run.hp = game.run.max_hp * 0.5
	var hurt: float = game.run.hp
	acts.step_pocket(s, H, s.global_position)
	t.check("arena fixed bundle", s.started and s.pack.size() == 3 and s.hazards.size() >= 1, "three enemies and an active pocket hazard")
	_kill(s.pack)
	acts.step_pocket(s, H, s.global_position)
	t.check("arena clear heals and opens one chest", s.done and s.pickup != null and s.heal_paid and game.run.hp > hurt, "done=%s pickup=%s heal=%s hp=%s hurt=%s max=%s" % [s.done, s.pickup != null, s.heal_paid, game.run.hp, hurt, game.run.max_hp])
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
	var owner: Dictionary = Activities.RULES.round_arena
	var floor_s: float = Schema._lead_floor({"family": "natural", "kind": "lightning", "effect": {}})
	var formula := true
	var additions := true
	var lead := true
	var visible := true
	var payments := true
	var clear_has_no_bonus := true
	var times := []
	for difficulty in [float(owner.difficulty_cap) / 2.0, float(owner.difficulty_cap) * 10.0]:
		var s = _site("round_arena", Vector2(100, 100), {"difficulty": difficulty})
		var pay_count := 0
		var granted_before := paid.size()
		var cogs_before: int = game.run.cogs
		var capped: float = maxf(1.0, minf(difficulty, float(owner.difficulty_cap)))
		for round_index in int(owner.rounds):
			acts.step_pocket(s, H, s.global_position)
			var announced_at := -1.0
			var saw_geometry := false
			while not s.fog.active:
				if s.fog.announced and announced_at < 0.0:
					announced_at = s.fog.director.stage_time
					saw_geometry = is_instance_valid(s.fog._safe_view) and s.fog._safe_view.is_visible_in_tree() and s.fog._safe_view.get_child_count() > 0 and s.fog._safe_view.global_position == s.fog.committed.safe_at and Activities._alive(s.pack) == 0
				acts.step_pocket(s, H, s.global_position)
			var spawn_at: float = s.fog.director.stage_time
			visible = visible and s.fog.announced and saw_geometry
			lead = lead and announced_at >= 0.0 and spawn_at - announced_at >= floor_s - 0.000001
			var want: float = (float(owner.base) + float(owner.step) * round_index) * capped
			formula = formula and absf(s.round_credits - want) / want <= 0.01 and s.pack.size() == floori(want / float(owner.enemy_credit))
			times.append({"D": difficulty, "round": round_index + 1, "announced_s": announced_at, "spawn_s": spawn_at, "lead_floor_s": floor_s, "geometry_before_spawn": saw_geometry, "credits": s.round_credits, "expected_credits": want})
			var seen := {}
			for enemy in s.pack:
				seen[String(enemy.kind)] = true
			additions = additions and s.round_elements == owner.elements.slice(0, round_index + 1) and seen.keys() == s.round_elements
			var wallet_before_clear: int = game.run.cogs
			_kill(s.pack)
			acts.step_pocket(s, H, s.global_position)
			clear_has_no_bonus = clear_has_no_bonus and game.run.cogs == wallet_before_clear
			for reward in s.round_rewards.duplicate():
				reward.inside = false
				acts._watch_round_pickups(s, reward.pickup.global_position)
				pay_count += 1
		payments = payments and s.round_payments == pay_count and pay_count == int(owner.rounds) and s.done and paid.size() - granted_before == pay_count and game.run.cogs - cogs_before == pay_count * Activities.PAY_SCRAP
		acts.clear()
	print("round announcement and spawn timeline: " + JSON.stringify(times))
	t.check("round credits formula within 1 percent with D capped", formula and times.size() == 2 * int(owner.rounds), "below-cap and above-cap D; owning RULES base=%s step=%s cap=%s enemy_credit=%s; threshold 1 percent" % [owner.base, owner.step, owner.difficulty_cap, owner.enemy_credit])
	t.check("each round adds exactly one element", additions, "actual spawned archetypes match one new owner element per round at both difficulties")
	t.check("pay events equal round count", payments, "each difficulty: collected reward count = owner rounds; actual part grants and wallet = collected count x PAY_SCRAP")
	t.check("round clear adds no bonus cogs before collection", clear_has_no_bonus, "encounter credits fund spawns only; wallet rises on collected rewards")
	t.check("safe zone announced at least natural family lead", lead, "actual announcement-to-spawn intervals >= owner family floor %.3f s" % floor_s)
	t.check("safe zone announcement is visible before activation", visible, "six actual telegraphs set announced and expose committed safe-disc geometry before fog or enemies activate")


func _phase_matches(s, phase: String, audio, since: int, count: int) -> bool:
	var key := String(s.rule.cue[phase])
	var row := Rows.row(key)
	var cues: Array = audio.cue_log.slice(since).filter(func(c): return c[0] == key)
	return cues.size() == count and cues.all(func(c): return c[1] == row.sound) and is_instance_valid(s.phase_view) and s.phase_view.get_child(0).material_override.albedo_color == row.color


func _cues() -> void:
	acts._on_stage_entered(game.run.stage, true)
	acts.clear()
	var shared := true
	var valid_markers := 0
	var completions := []
	var listener := func(id, _at): completions.append(id)
	game.events.activity_done.connect(listener)
	var audio = game.presentation.audio
	var markers := EdgeMarkers.new()
	markers.setup(game)
	for kind in KINDS:
		game.flow.state = game.flow.STAGE
		var s = _site(kind, Vector2(100, 100), {"graph": graphs.park_test})
		var targets: Array = markers.targets().filter(func(target): return target.has("activity"))
		valid_markers += int(targets.size() == 1 and targets[0].activity == s.rule.cue.view and EdgeMarkers.marker_color(targets[0]) == Rows.activity_color(s.rule.cue.view))
		audio._last_start.clear()
		var since: int = audio.cue_log.size()
		acts.step_pocket(s, H, s.targets[0] if kind == "scattered_marks" else s.global_position)
		shared = shared and _phase_matches(s, "telegraph", audio, since, 1)
		var clear_count := 0
		var pay_count := 0
		var clear_since: int = audio.cue_log.size()
		match kind:
			"movement_course", "objective_limit", "scattered_marks":
				for target in s.targets:
					acts.step_pocket(s, H, target)
				clear_count = 1
			"arena", "elite_arena":
				_kill(s.pack)
				acts.step_pocket(s, H, s.global_position)
				clear_count = 1
			"ambush":
				for wave in 3:
					_kill(s.pack)
					acts.step_pocket(s, H, s.global_position)
				clear_count = 1
			"round_arena":
				for round_index in int(s.rule.rounds):
					while s.awaiting_round:
						acts.step_pocket(s, H, s.global_position)
					audio._last_start.clear()
					_kill(s.pack)
					acts.step_pocket(s, H, s.global_position)
					clear_count += 1
		shared = shared and s.done and _phase_matches(s, "clear", audio, clear_since, clear_count)
		shared = shared and audio.cue_log.slice(clear_since).all(func(c): return c[0] != "activity_done")
		audio._last_start.clear()
		since = audio.cue_log.size()
		if kind == "round_arena":
			for reward in s.round_rewards.duplicate():
				audio._last_start.clear()
				reward.inside = false
				acts._watch_round_pickups(s, reward.pickup.global_position)
				pay_count += 1
		else:
			s.inside_pickup = false
			if s.pickup != null:
				acts._watch_pickup(s, s.pickup.global_position)
				pay_count = 1
			else:
				shared = false
		shared = shared and _phase_matches(s, "pay", audio, since, pay_count)
		acts.clear()
	game.events.activity_done.disconnect(listener)
	markers.free()
	t.check("sight and sound consume each kind's shared cue record", shared and valid_markers == 7 and completions.size() == 7, "%d/7 real marker targets; actual start, clear, pickup; exactly one shared clear per completion and no legacy cue; gameplay facts=%d" % [valid_markers, completions.size()])


func _ambush() -> void:
	var waves := true
	var route_hits := 0
	var clears := 0
	for seed_value in 20:
		game.ctx.rng.seed = 500 + seed_value
		_seal_stage()
		var s = _site("ambush", Vector2(500, 300), {"graph": graphs.park_test})
		for wave in 3:
			acts.step_pocket(s, H, s.global_position)
			waves = waves and s.pack.size() >= 1 and s.pack.size() <= 5 and s.wave == wave + 1
			for e in s.pack:
				route_hits += int((graphs.park_test.flags(graphs.park_test.nearest(e.global_position)) & Graph.LINE) != 0)
			_kill(s.pack)
			acts.step_pocket(s, H, s.global_position)
		_break_stage()
		clears += int(s.done and game.flow.state == game.flow.GATES and not game.flow.sealed and not game.beacon.sealed)
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
		var farthest := 0.0
		for node in g.node_count():
			var distance: float = g.d_spawn_node(node)
			if (g.flags(node) & Graph.DOOR_OK) != 0 and is_finite(distance):
				farthest = maxf(farthest, distance)
		var far_cutoff: float = farthest / 2.0
		print("independent far-half oracle: %s cutoff=%.3f m; objective-fit nodes with finite spawn paths" % [stage, far_cutoff])
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


func _seal_stage(reusable = null) -> bool:
	var flow = game.flow
	if is_instance_valid(flow.warden) and flow.warden != reusable:
		flow.warden.queue_free()
	flow.state = flow.STAGE
	flow.sealed = true
	game.beacon.place(game.ctx.terrain.beacon_point(game.run.stage), game.beacon.duration, game.beacon.radius)
	flow.warden = reusable if is_instance_valid(reusable) else flow._spawn_warden()
	if is_instance_valid(reusable):
		reusable.hp = reusable.max_hp
		reusable._dead = false
	if not is_instance_valid(flow.warden):
		return false
	flow._warden_at = flow.warden.global_position
	return flow.warden.kind == "warden" and game.ctx.spawner.integrity_of(flow.warden) > 0.0 and flow.sealed and game.beacon.sealed


func _break_stage(reuse := false) -> void:
	if reuse:
		var warden = game.flow.warden
		warden.hp = 0.0
		warden._dead = true
		game.run.record_kill("warden", warden.global_position, 0)
	else:
		game.flow.warden._die()
	acts._physics_process(H)


func _exit() -> void:
	if only == "":
		game.free()
		await _boot_game()
	var before := warden_kills
	var open := true
	var opened := 0
	var index: int = game.ctx.terrain.stage - 1
	var previous = game.ctx.terrain.maps[index]
	game.player.set_physics_process(false)
	game.player.active_body().freeze = true
	for stage in STAGES:
		game.ctx.terrain.maps[index] = ParkMap.new("res://src/world/park/%s.json" % stage)
		var reusable = game.flow._spawn_warden()
		reusable.set_physics_process(false)
		for seed_value in 1000:
			game.ctx.rng.seed = seed_value
			var s = _site("scattered_marks", Vector2(100, 100), {"graph": graphs[stage]})
			game.player.active_body().global_position = Vector3(-700, 0, -700)
			var was_sealed := _seal_stage(reusable)
			_break_stage(true)
			var this_open: bool = was_sealed and game.flow.state == game.flow.GATES and not game.flow.sealed and not game.beacon.sealed and s.marks_taken == 0
			open = open and this_open
			opened += int(this_open)
			acts.clear()
			if seed_value % 20 == 19:
				await physics_frame
		reusable.queue_free()
		print("ordinary exit path: %s; 1000 freshly sealed stages; real Warden reset alive, killed through RunState, zero marks" % stage)
	t.check("exit-opens-with-zero-marks in 100 percent", open and opened == 2000, "%d/2000 normal Warden-death exits with no mark taken" % opened)
	t.check("seeded exits use ordinary stage Warden deaths", warden_kills - before == 2000, "%d/2000 Warden kill facts across both parks" % (warden_kills - before))
	for kind in KINDS:
		_site(kind, Vector2(100, 100), {"graph": graphs.park_test})
	var was_sealed := _seal_stage()
	_break_stage()
	t.check("exit opens with every pocket untouched", was_sealed and game.flow.state == game.flow.GATES and not game.flow.sealed and not game.beacon.sealed and acts.sites.all(func(s): return not s.done and s.marks_taken == 0), "all seven optional kinds remain unfinished after ordinary Warden death and activity processing")
	game.ctx.terrain.maps[index] = previous
	acts.clear()
