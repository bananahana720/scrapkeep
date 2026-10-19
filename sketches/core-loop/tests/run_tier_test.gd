extends SceneTree
# smoke: bots timeout=1200s
# 2026-10-15 RT-CAP: a 20-seed whole-run replay (five batches of four child games) ran at 359.5 s
# of the 360 s solo ceiling on a normal machine and timed out at load 55 to 59, so it moved to the
# bot tier (npm run sketch:bots; sketch:gate runs both). Every check is unchanged.

const ChildRuns := preload("res://tests/trees/child_runs.gd")
const T := preload("res://tests/support/t.gd")
const Director := preload("res://src/world/director.gd")
const Park := preload("res://src/core/park_defs.gd")
const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Progress := preload("res://src/core/progress.gd")
const Sheet := preload("res://src/build/build_sheet.gd")
const Game := preload("res://src/game.gd")
const RunState := preload("res://src/core/run_state.gd")
const Profile := preload("res://src/core/profile.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Flow := preload("res://src/core/flow.gd")
const StartCard := preload("res://src/ui/start_pick_card.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const Cards := preload("res://src/world/director_cards.gd")

# Re-pinned 2026-10-14 (coordinator): the KD2 flume merge c81cec4a changed stage 2's park data, so every
# whole run moved. SG10 proved tier 0 equal to the pre-SG10 game on the old pins (b8b6605b passes them);
# these are tier-0 replays at c81cec4a, without SG11, seeds 0..19, with the same script:
# /home/andrew/.local/share/godot/4.7.2/Godot_v4.7.2-stable_linux.x86_64
# --headless --path sketches/core-loop --script /home/andrew/scratch/w13/sol/sg10-tier-r5/base_replay.gd
# -- --record-base --section=runtime --seed=N  (log: /home/andrew/scratch/w13/runtier-repin.log)
# 2026-10-16 wave-15 re-pin (ruling RT1): the schedule hash now leaves out each park row's presentation
# fields (recipe, fit); KD1-DRESS's three recipe renames had moved all 20. Whole runs unchanged.
# 2026-10-16 PARK-WIN re-pin: crown_apron at 730.5 -> 731.5 (PW2) and the islands Warden anchor y
# 80 -> 66 (PW1) are park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged.
# 2026-10-17 HIGHDRAFT-ROSTER re-pin (#72): the Highdraft packs (ballast_heavy, gap_net) and the
# Highdraft elite move the director schedule and the default run; recorded with --record-base.
# 2026-10-17 stage/alpha-w16 combined re-pin: every admitted director-moving PR together (attack budget,
# Foreman, specials, Dig and Highdraft rosters, #75 isle skirt); recorded with --record-base --section=runtime.
# 2026-10-18 stage/alpha-w16 re-pin: cand 6f075df2, crown pass, #65, #73, #79, #96, #97, #98 and #99 together; recorded with --record-base --section=runtime.
# 2026-10-18 Dig plated elites and Highdraft ring-outs (#69) merged onto stage/alpha-w17; recorded with --record-base --section=runtime.
# 2026-10-18 stage/alpha-w17 re-record at 04eb0d00 (Gate lane): #125, #127, #129, #139, #140, #106, #142, #144, #105 and the #126
# flume pass (park rows) together; recorded with --record-base --section=runtime, seeds 0..19 in four-wide batches.
# 2026-10-18 W18-PACKS re-pin: park_defs.gd gains the nine authored nemesis, Dispatcher and Splitter packs; all 20 schedule and all 20
# whole-run hashes moved. Values read from this test's own MEASURE lines (schedule0, tier0.hash) on the unmodified test. The whole-run
# pins (BASE_RUN) also carry the Systems A nemesis lean, because world.gd now feeds the director a build, so they moved for both reasons.
const BASE_SCHEDULE := [
	"e5f91c32e612d43fa54b204661fdc33470d6cf02759a05231c88486d6b691ec9",
	"dab0241e2d8ccf925cf0cb4e201e55d780cc3aba4ff490d21c39b5248a635508",
	"def429587f3f752c54f6e5ade7ef7914fe2185adb9ecb8673a2bbb117e8833d1",
	"a7cb6e95d0e4ec8cd6221ed9ba1af4761f25b8513796c6b851879be82e6e0681",
	"6966c949e25ad7bb37db21161a10877f6b569278f3d354cf0e3ee524b5517733",
	"4278d770ab23554c82ddf59068f2d28e0055b7a58fe25e3a79c2e2a3f65b9f9c",
	"ecc6ec3432d4b0a956a5ede54bb8b79943080d290e118ec14415dda365c6d94f",
	"b503375a08ebb2a539ab1b8b2948a8f5932b1f6121dd6703ec317d5c45374b7a",
	"08dd93ca541f0f44290d2c3ebee63a525b3a26eadfcbce734c20d163f66a6ef2",
	"fb9a72213ee69bf87b4d8cefaa5522613dd6c0c0d3a5b38a534e1bbdf7ef6c03",
	"efce87236218e1af4491f9d0a2737f86319e860f96423570daab9a6417ca16e1",
	"3a3e5775c56362f268518e35577b5bc956e1da87d3cc495ea02d23ebd19ae0aa",
	"3f1afdc4b82f6d1d6061936013ce3b1fb5ded8c12c1570b820e926ac6ee56d86",
	"48f2894e5523ec7f99b438efbac35c8f35f9de17a6d16827160107e9c1ce6f8f",
	"79e0e3f49513f163a7541f10098934c2c0121cae6ea33ef5378a687e818a37a5",
	"c54d8158ad949ef98eea71d16ed4db98ba12d021586cc6804cc83f23e3e07e6c",
	"b8112c90cbdd10752c005265117b16125d1cc137ea8b92661b8efe873a601d78",
	"95227b2d6d872950c01122fd9481168cd3d58bed817adb9f807d6f00c23c485d",
	"de76077f0954df85ab7f444c6d609353e6f09a11af19c0aaae16868000125326",
	"19841d7f5a46077b45b828136f77d5d59420f305343f30374b60ff73a635f1b8",
]
# 2026-10-15 wave-14 re-pin at 8b507ffb (SQ9 speed bank, PC-POOL part rows, SQ19 offer weights and
# the SQ9 free-rest fix move the default run; schedules unchanged): recorded with --record-base.
# 2026-10-18 stage/alpha-w17 re-record at 04eb0d00: whole runs moved on seeds 3, 7, 12, 14, 15, 16, 17, 18, 19 (9 of 20); the others are
# unchanged; recorded with BASE_SCHEDULE above.
const BASE_RUN := [
	"46ff439348b4b7d856fd8b33c686d7aa5614f3d3024d05fcc6ff7077f349a341",
	"e44d97666884d6bbb9fe3309a21020a1bfdcee47683c9d7c4d0869ad95aaa8be",
	"c22c6980840610550eaaa93103f129860f28915f094193de0c3f6f87f55b3405",
	"8098d73d646d1805de41785b2023edfe6e1991fd08f7255000121e03b46bb964",
	"576da35f55250068b3c5781d890519662454337c577e152c385054deae184302",
	"c2122fc5e48d14a3d6f7a9e2ae62ed73171f06920302afb0532d7f768ebaa3c5",
	"b20746a4316057d765e22563d2a3ff445b6505cf46d6b82d923fa6901869c378",
	"039d4723759485eecbd9d139a57dc6fb9f6420ae2ab69263b626b47ec94be4de",
	"460dcaf929c06b0abf7f6f5cfc299b8078e5b83f72f9f4e356a83c75226e0c6f",
	"5bd7ebb18d7ca2654569e21ec22e2f53880df282735a415feeede5726476debd",
	"b838a810a05b1185c43e7e748fc58f825052b3179fc05b160a32944db0b96725",
	"1469beac37537f4cd3721062b6df8a2c75bd8ebfd34bedaa1f985b026fe6f796",
	"65122a8cf0d0cc9741d010eafa06cceb0c1a7e099e85ccf03f62bab44a5cd0ee",
	"54a53bf98e4da960fa909ddab2e96427056b236ada14ca9ce13c6bc6bf8117a3",
	"d1c3dde58ac99057912dc2652658cd6b9f1c49f7c290296dfec80ccaa28c0090",
	"0223ccdc05d38755340667fff57c0c6a072b9f9880cf6115aa1ed2a90a788756",
	"c153536139e27f800b6dd7cfe2c413ac506d26845b4d231f27f8ad13f9c46e80",
	"3151629d7948d3121bed43a382949999de4664b6517d3275c2002cc760ee1687",
	"cfdf07cb4f559b94418569b717a3b7a6124ea11f68f5c9b8ca4f35f768fc7bc9",
	"bab0406d5496a71c7ab15db79ac168ae9b01a996a28b61ed6f2b07f63242cb67",
]
const SEEDS := 20
const DRAWS := 400
class ChoiceGame extends "res://src/game.gd":
	var capture_requests: Array[bool] = []
	func _capture_mouse(capture: bool) -> void:
		capture_requests.append(capture)

var t := T.new("run_tier_test")
var game
var record := false
var section := "all"
var only_seed := -1
var continue_path := ""
var continue_mode := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--record-base":
			record = true
		if arg.begins_with("--seed="):
			only_seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--section="):
			section = arg.trim_prefix("--section=")
		if arg.begins_with("--continue-path="):
			continue_path = arg.trim_prefix("--continue-path=")
		if arg.begins_with("--continue-mode="):
			continue_mode = arg.trim_prefix("--continue-mode=")
	if only_seed >= 0 or section in ["card", "variants", "persistence", "format", "mouse", "continue", "continue-replay"]:
		_create_game()
	call_deferred("_run")

func _create_game() -> void:
	game = ChoiceGame.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)

func _parallel_runtime() -> void:
	for first in range(0, SEEDS, 4):
		var jobs := []
		for seed_value in range(first, mini(first + 4, SEEDS)):
			var args := ["--section=runtime", "--seed=%d" % seed_value]
			if record:
				args.append("--record-base")
			jobs.append({"script": "res://tests/run_tier_test.gd", "args": args})
		# 150 s per batch of four (70 s before RT-CAP): the cap catches a hang, not a slow machine.
		var results := ChildRuns.run(jobs, 150.0)
		for i in results.size():
			var result: Dictionary = results[i]
			var summary := ChildRuns.summary(result)
			for line in String(result.log).split("\n"):
				if line.begins_with("MEASURE "):
					print(line)
			var good: bool = not result.timed_out and result.code == 0 and summary.errors.is_empty()
			t.check("runtime child seed %d" % (first + i), good, "exit=%s timeout=%s" % [result.code, result.timed_out])

func _hash(value) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(value))
	return digest.finish().hex_encode()

# 2026-10-16 (ruling RT1): the park rows without their presentation fields. A row's recipe and fit pick
# the art it draws with and never reach the director, so a dressing swap must not move the schedule pin
# (KD1-DRESS moved all 20 by renaming three recipes).
const PRESENTATION_FIELDS := ["recipe", "fit"]

static func _director_rows(rows: Array) -> Array:
	var kept := []
	for row in rows:
		var copy: Dictionary = row.duplicate(true)
		for field in PRESENTATION_FIELDS:
			copy.erase(field)
		kept.append(copy)
	return kept

# 2026-10-17 (SQ2, PR #15): each due spawn carries its arrival's pack number for the attacker
# budget (attack_budget.gd). It copies a tag the director already drew and moves no spawn, so the
# schedule pin leaves it out, as RT1 leaves out presentation fields.
static func _without_pack(due: Array) -> Array:
	var kept: Array[Dictionary] = []
	for spawn in due:
		var copy: Dictionary = spawn.duplicate(true)
		copy.erase("pack")
		kept.append(copy)
	return kept

func _schedule(d, steps := 1200) -> Dictionary:
	var ball: Vector2 = d._park_map.beacon if d._park_map != null else Vector2.ZERO
	if d._park_map != null:
		d.play_rect = d._park_map.play_rect
	var schedule := []
	var members := 0
	for step in steps:
		var due: Array = d.advance(0.5, 0, ball)
		members += due.size()
		if not due.is_empty():
			schedule.append([step, _without_pack(due)])
	return {"schedule": schedule, "members": members, "cap": d.cap(), "interval": d.interval()}

func _config(tier_value: int) -> Dictionary:
	var tables: Dictionary = load("res://src/world/director_cards.gd").get_script_constant_map()
	var tiers: Dictionary = tables.get("RUN_TIERS", {})
	if not record:
		t.check("owning tier row %d exists" % tier_value, tiers.has(tier_value))
	return tiers.get(tier_value, {"cap_weight": 1.0, "interval_weight": 1.0, "event_core_multiplier": 1.0, "rare_weight": 1.0})

func _component(seed_value: int, tier_value: int) -> Dictionary:
	var stages := []
	var members := 0
	var config := _config(tier_value)
	for row in Park.DEFS:
		var d = Director.new(seed_value)
		if d.has_method("set_run_tier_reader"):
			d.set_run_tier_reader(func(): return tier_value)
		d.use_row(row)
		d.threat = row.threat
		d.authored = row.packs
		d.elite = row.elite
		d.elite_arrival = Park.ELITE_ARRIVAL
		var measured := _schedule(d)
		members += measured.members
		if not record:
			var cap_expected := mini(Director.HARD_CAP, roundi((6 + 2 * Director.MAX_TIME_TIERS) * row.threat * row.pressure.pack_scale * config.cap_weight))
			var interval_expected := maxf(Director.MIN_INTERVAL, (Director.BASE_INTERVAL - 0.7 * Director.MAX_TIME_TIERS) / row.threat * row.pressure.interval_scale * config.interval_weight)
			t.eq("independent cap seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], measured.cap, cap_expected)
			t.near("independent interval seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], measured.interval, interval_expected)
			if tier_value == 0:
				t.near("health untouched seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], d.hp_scale(), row.threat)
			else:
				var dial_steps: Dictionary = load("res://src/core/stage_defs.gd").get_script_constant_map().get("RUN_TIER_DIAL_STEPS", {"health": 0.2})
				var health_cap: float = load("res://src/core/run_tier.gd").get_script_constant_map().get("HEALTH_DIAL_CAP", 1.6)
				var health_expected: float = row.threat * minf(health_cap, 1.0 + int(row.world) * float(dial_steps.health))
				t.near("independent tier-1 health seed %d stage %d" % [seed_value, row.stage], d.hp_scale(), health_expected)
			t.eq("interval mode retained", d.mode, "interval")
		var pay := {"kill_scrap": row.kill_scrap, "source_rarities": Parts.SOURCE_RARITIES,
			"gate_rarities": [Parts.gate_rarities(0), Parts.gate_rarities(1), Parts.gate_rarities(2)],
			"milestones": Parts.MILESTONE_FOR_EVENT}
		if d._park_map != null:
			pay["park_rows"] = _director_rows(d._park_map.park.park_rows)
		stages.append({"stage": row.stage, "mode": d.mode, "schedule": measured.schedule,
			"pay_rows": pay, "cap": measured.cap, "interval": measured.interval})
	return {"hash": _hash(stages), "members": members}

func _fresh_profile(won: bool):
	var p := Profile.new("user://run_tier_test/unused.json")
	p.load_profile()
	p.can_save = false
	if won:
		p.earn("first_win", 1.0)
	return p

func _begin(seed_value: int, tier_value: int) -> void:
	game.ctx.profile = _fresh_profile(true)
	game.ctx.calm = true
	game.run.run_seed_override = seed_value
	game.ctx.rng.seed = seed_value
	game.flow._begin_run(ClassDef.all()[0])
	if tier_value != 0 and game.flow.has_method("choose_run_tier"):
		game.flow.choose_run_tier(tier_value)

func _stage_pay(seed_value: int, tier_value: int, stage_value: int) -> Dictionary:
	var config := _config(tier_value)
	var rare := 0
	var expected_rare := 0
	var measured := _schedule(game.world.director, 120)
	var core_rows := []
	# Settle committed event-win facts through the world consumer.
	for win in 8:
		game.world._publish([{"kind": "milestone", "id": "tier_fixture_%d" % win, "at": Vector2.ZERO}])
		core_rows.append(game.run.bonus_cores)
		if not record:
			t.eq("settled cores seed %d tier %d stage %d win %d" % [seed_value, tier_value, stage_value, win], game.run.bonus_cores, floori((win + 1) * config.event_core_multiplier))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * Park.COUNT + stage_value
	var pay_rows := []
	var oracle := RandomNumberGenerator.new()
	oracle.seed = seed_value * Park.COUNT + stage_value
	var common_weight: float = ItemGen.TIER_WEIGHTS.common
	var rare_weight: float = ItemGen.TIER_WEIGHTS.rare * config.rare_weight
	for draw in DRAWS:
		expected_rare += int(oracle.randf() * (common_weight + rare_weight) >= common_weight)
		# A single listed offer consumes the rarity draw and one bucket draw.
		oracle.randf()
		var picks: Array = Parts.roll(rng, ["common", "rare"], game.run.class_id(), [], 1)
		pay_rows.append(picks)
		if not picks.is_empty() and Parts.rarity_of(picks[0]) == "rare":
			rare += 1
	var row := [stage_value, game.world.director.mode, measured.schedule, measured.cap,
		measured.interval, core_rows, pay_rows, game.run.start_pick_options(), game.run.start_pick.get("taken", "")]
	if not record:
		t.eq("independent rare settlement seed %d tier %d stage %d" % [seed_value, tier_value, stage_value], rare, expected_rare)
	return {"row": row, "threat": measured.members, "cores": game.run.bonus_cores, "rare": rare}

func _pay_result(stages: Array, threat: int, cores: int, rare: int) -> Dictionary:
	var rare_share := float(rare) / (DRAWS * Park.COUNT)
	return {"hash": _hash(stages), "threat": threat, "cores": cores, "rare_share": rare_share, "pay": cores + rare_share}

func _settle(seed_value: int, tier_value: int) -> Dictionary:
	_begin(seed_value, tier_value)
	var stages := []
	var threat := 0
	var cores := 0
	var rare := 0
	for stage_value in range(1, Park.COUNT + 1):
		if stage_value != 1:
			game.flow.enter_stage(stage_value, Vector3(0.0, 0.0, 20.0), false)
		var measured := _stage_pay(seed_value, tier_value, stage_value)
		stages.append(measured.row)
		threat += measured.threat
		cores += measured.cores
		rare += measured.rare
		await process_frame
	return _pay_result(stages, threat, cores, rare)

func _settle_pair(seed_value: int) -> Array:
	_begin(seed_value, 0)
	var rows := [[], []]
	var threat := [0, 0]
	var cores := [0, 0]
	var rare := [0, 0]
	for stage_value in range(1, Park.COUNT + 1):
		if stage_value != 1:
			if game.run.has_method("selected_run_tier"):
				game.run.run_tier = 0
			game.flow.enter_stage(stage_value, Vector3(0.0, 0.0, 20.0), false)
		var base := _stage_pay(seed_value, 0, stage_value)
		var stream_before_retry: int = game.ctx.rng.state
		if stage_value == 1 and game.flow.has_method("choose_run_tier"):
			t.check("production tier choice seed %d" % seed_value, game.flow.choose_run_tier(1))
		elif game.run.has_method("selected_run_tier"):
			# Controlled alternate entrance: only the chosen tier differs.
			game.run._snapshot["run_tier"] = 1
		game.flow.retry_stage()
		var hard := _stage_pay(seed_value, 1, stage_value)
		# Keep the next base stage on the original run's stream.
		game.ctx.rng.state = stream_before_retry
		for tier_value in [0, 1]:
			var measured: Dictionary = base if tier_value == 0 else hard
			rows[tier_value].append(measured.row)
			threat[tier_value] += measured.threat
			cores[tier_value] += measured.cores
			rare[tier_value] += measured.rare
		await process_frame
	return [_pay_result(rows[0], threat[0], cores[0], rare[0]), _pay_result(rows[1], threat[1], cores[1], rare[1])]

func _runtime() -> void:
	var tier_script = load("res://src/core/run_tier.gd") if not record and ResourceLoader.exists("res://src/core/run_tier.gd") else null
	if not record:
		t.check("named pay cap is 1.5", tier_script != null and tier_script.get_script_constant_map().get("PAY_GAIN_CAP") == 1.5)
	for seed_value in SEEDS:
		if only_seed >= 0 and seed_value != only_seed:
			continue
		var a := _component(seed_value, 0)
		if record:
			var base: Dictionary = await _settle(seed_value, 0)
			print("BASE " + JSON.stringify({"seed": seed_value, "schedule": a.hash, "run": base.hash}))
			continue
		var b := _component(seed_value, 1)
		var pair: Array = await _settle_pair(seed_value)
		var base: Dictionary = pair[0]
		var hard: Dictionary = pair[1]
		t.check("bit-identical schedule seed %d" % seed_value, BASE_SCHEDULE.size() == SEEDS and a.hash == BASE_SCHEDULE[seed_value])
		t.check("bit-identical whole-run default seed %d" % seed_value, BASE_RUN.size() == SEEDS and base.hash == BASE_RUN[seed_value])
		t.check("higher threat seed %d" % seed_value, b.members > a.members and hard.threat > base.threat)
		t.check("higher pay seed %d" % seed_value, hard.pay > base.pay and hard.cores > base.cores and hard.rare_share > base.rare_share)
		t.check("pay cap seed %d" % seed_value, hard.pay / base.pay <= RunTier.PAY_GAIN_CAP)
		print("MEASURE " + JSON.stringify({"seed": seed_value, "tier0": base, "tier1": hard, "ratio": hard.pay / base.pay,
			"schedule0": a.hash, "schedule1": b.hash, "measure": "settled event bonus cores + rare parts / 2400 production draws; all six stages"}))

func _card() -> void:
	game.ctx.root.bot_driven = false
	_begin(701, 0)
	var default_doc: Dictionary = game.run.to_entrance_doc()
	t.check("tier-zero entrance keeps base format", not default_doc.has("run_tier") and not default_doc.has("event_core_grants"))
	if not game.flow.has_method("show_start_card"):
		t.check("production start card appears", false)
		return
	game.ctx.profile = _fresh_profile(false)
	game.flow.show_start_card()
	var card = game.flow.start_card
	t.check("production start card appears", card.is_inside_tree() and card.showing() and card.is_processing_input())
	t.check("start card releases cursor", not game.capture_requests.is_empty() and game.capture_requests.back() == false and game.get_meta("menu_held", false))
	t.check("start card does not pause or hold movement", not paused and not game.player.frozen() and game.player.state.velocity.length() > 0.0)
	t.check("locked tier not offered", card.offered_tiers() == [0])
	t.check("locked tier rejected at boundary", not game.flow.choose_run_tier(1) and game.run.selected_run_tier() == 0)
	var win_bus := GameEvents.new()
	var win_run := RunState.new(win_bus, 37)
	win_run.begin(ClassDef.all()[0])
	var progress := Progress.new()
	root.add_child(progress)
	progress.setup(win_bus, win_run, game.ctx.profile)
	win_bus.run_started.emit(win_run.class_id())
	win_bus.run_ended.emit(false)
	t.check("loss does not unlock tier", not game.ctx.profile.earned("first_win"))
	win_bus.run_started.emit(win_run.class_id())
	win_bus.run_ended.emit(true)
	t.check("recorded win unlocks tier", game.ctx.profile.earned("first_win"))
	progress.free()
	win_bus.free()
	load("res://src/build/parts.gd").call("bind_run", game.run)
	game.flow.show_start_card()
	t.check("win offers tier 1", card.offered_tiers() == [0, 1])
	var labels := []
	for node in card.get_children():
		if node is Label and node.visible:
			labels.append(node.text)
	var hard: Dictionary = Cards.RUN_TIERS[1]
	var expected_threat := "Threat: %d%% more crowd, %d%% shorter intervals" % [roundi(100.0 * (hard.cap_weight - 1.0)), roundi(100.0 * (1.0 - hard.interval_weight))]
	var expected_pay := "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi(100.0 * (hard.event_core_multiplier - 1.0)), RunTier.PAY_GAIN_CAP]
	t.check("rendered pre-choice threat/pay", expected_threat in labels
		and expected_pay in labels and game.run.selected_run_tier() == 0)
	var host = game.get_node("Workshop")
	t.check("start card sits above workshop", card.get_parent().layer > host.layer)
	t.eq("start card handles input during workshop pause", card.process_mode, Node.PROCESS_MODE_ALWAYS)
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	game.test_mode = false
	game._input(click)
	game.test_mode = true
	game.bot_driven = false
	t.check("start-card clicks do not recapture cursor", game.capture_requests.back() == false)
	# Click the actual tier button, then use viewport input for a pick.
	card.tier_button(1).pressed.emit()
	t.eq("scripted tier click reaches RunState", game.run.selected_run_tier(), 1)
	t.eq("world director reads selected tier", game.world.director.run_tier(), 1)
	var first: Array = game.run.start_pick_options()
	card.reroll_button.pressed.emit()
	t.check("reroll click reaches RunState", game.run.start_pick_options() != first and game.run.start_pick.rerolls_left == 0)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_1
	key.physical_keycode = KEY_1
	host.armed = true
	host.open_pick()
	t.check("competing workshop pick is open", host.pick.is_open())
	var tree_before: Array = game.player.tree.picks.duplicate()
	root.push_input(key, true)
	t.check("scripted pick reaches RunState", game.run.start_pick.taken == game.run.start_pick_options()[0] and not card.showing())
	t.check("start input does not choose a workshop upgrade", game.player.tree.picks == tree_before)
	host.close_pick()
	host.armed = false
	t.check("pick returns aim control", game.capture_requests.back() == true and not game.get_meta("menu_held", false))
	var doc: Dictionary = game.run.to_entrance_doc()
	var loaded := RunState.new(GameEvents.new(), 4)
	loaded.begin(ClassDef.all()[0])
	t.check("selected tier entrance load", loaded.from_entrance_doc(doc) and loaded.selected_run_tier() == 1)
	loaded.restore()
	t.eq("selected tier retry survives", loaded.selected_run_tier(), 1)
	loaded.events.free()
	game.flow.retry_stage()
	t.eq("actual flow retry preserves tier", game.run.selected_run_tier(), 1)
	game.ctx.root.bot_driven = true
	_begin(702, 0)
	t.check("bot default unchanged", game.run.selected_run_tier() == 0 and game.run.start_pick.taken == "" and not game.flow.start_card.showing())

func _persistence() -> void:
	game.flow.store = Flow.RunStore.new("user://tier-continue-%d.json" % OS.get_process_id())
	_begin(704, 0)
	t.check("disk base Continue eligible", not game.flow.saved_run().is_empty())
	t.check("disk tier-one selection", game.flow.choose_run_tier(1))
	t.eq("disk tier-one save succeeds", game.flow.store_error, "")
	var saved: Dictionary = game.flow.saved_run()
	t.check("disk tier-one Continue eligible", not saved.is_empty(), game.flow.saved_run_why)
	game.flow.state = Flow.TITLE
	t.check("disk tier-one Continue resumes", game.flow.resume_run())
	t.eq("disk Continue preserves tier one", game.run.selected_run_tier(), 1)
	game.flow.retry_stage()
	t.eq("disk Continue retry preserves tier one", game.run.selected_run_tier(), 1)
	var doc: Dictionary = game.run.to_entrance_doc()
	doc["run_tier"] = 1
	doc["event_core_grants"] = 7
	game.flow._save(doc)
	t.eq("nonzero grants disk save succeeds", game.flow.store_error, "")
	var disk: Dictionary = game.flow.saved_run()
	t.check("nonzero grants disk Continue eligible", not disk.is_empty(), game.flow.saved_run_why)
	t.eq("nonzero grants survive RunStore JSON", disk.get("event_core_grants", -1), 7)
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(doc))
	t.eq("JSON decodes tier as float", typeof(decoded.run_tier), TYPE_FLOAT)
	t.eq("JSON decodes grants as float", typeof(decoded.event_core_grants), TYPE_FLOAT)
	var loaded := RunState.new(GameEvents.new(), 9)
	loaded.begin(ClassDef.all()[0])
	t.check("JSON both tier fields reconstruct", loaded.from_entrance_doc(decoded))
	t.eq("JSON reconstructed tier", loaded.selected_run_tier(), 1)
	t.eq("JSON reconstructed nonzero grants", loaded.event_core_grants, 7)
	t.eq("JSON reconstructed grants are int", typeof(loaded.event_core_grants), TYPE_INT)
	if loaded.has_snapshot():
		loaded.restore()
	t.eq("JSON retry nonzero grants", loaded.event_core_grants, 7)
	for field in ["run_tier", "event_core_grants"]:
		for bad in [0.5, INF, -INF, NAN, "1", true, null, [], {}]:
			var invalid := doc.duplicate(true)
			invalid[field] = bad
			t.eq("reject %s %s" % [field, str(bad)], RunState.validate_entrance_doc(invalid), "invalid " + field)
	for bad_tier in [-1, 2, -1.0, 2.0]:
		var invalid := doc.duplicate(true)
		invalid.run_tier = bad_tier
		t.eq("reject tier domain %s" % str(bad_tier), RunState.validate_entrance_doc(invalid), "invalid run_tier")
	for bad_grants in [-1, -1.0]:
		var invalid := doc.duplicate(true)
		invalid.event_core_grants = bad_grants
		t.eq("reject grants domain %s" % str(bad_grants), RunState.validate_entrance_doc(invalid), "invalid event_core_grants")
	loaded.events.free()
	game.flow.store = null

func _continue_card() -> void:
	game.bot_driven = true
	var jobs := []
	for stage_value in [1, 2]:
		var path := "user://tier-offer-%d-stage-%d.json" % [OS.get_process_id(), stage_value]
		game.flow.store = Flow.RunStore.new(path)
		_begin(707, 0)
		t.check("Continue fixture rerolls saved offer", game.run.reroll_start_pick())
		if stage_value == 2:
			game.flow.enter_stage(2, Vector3.ZERO, false)
		else:
			game.flow._save(game.run.to_entrance_doc())
		t.eq("Continue fixture disk save stage %d" % stage_value, game.flow.store_error, "")
		var saved: Dictionary = game.flow.store.load()
		t.eq("Continue fixture untaken stage %d" % stage_value, saved.start_pick.taken, "")
		t.eq("Continue fixture saved three options stage %d" % stage_value, saved.start_pick.options, game.run.start_pick_options())
		var modes := ["interactive", "bot", "headless"] if stage_value == 1 else ["interactive"]
		for mode in modes:
			jobs.append({"script": "res://tests/run_tier_test.gd", "args": ["--section=continue-replay", "--continue-path=" + path, "--continue-mode=" + mode]})
	game.flow.store = null
	var results := ChildRuns.run(jobs, 70.0)
	for i in results.size():
		var result: Dictionary = results[i]
		var summary := ChildRuns.summary(result)
		for line in summary.checks:
			print(line)
		print(summary.verdict)
		t.check("fresh-process Continue child %d" % i, not result.timed_out and result.code == 0 and summary.errors.is_empty() and summary.verdict.ends_with(": PASS"), "exit=%s timeout=%s errors=%s" % [result.code, result.timed_out, summary.errors])

func _continue_replay() -> void:
	paused = true
	game.ctx.calm = true
	game.ctx.profile = _fresh_profile(true)
	game.flow.store = Flow.RunStore.new(continue_path)
	var saved: Dictionary = game.flow.store.load()
	var expected_options: Array = saved.start_pick.options.duplicate()
	var expected_stage := int(saved.stage)
	var label := "Continue stage %d %s" % [expected_stage, continue_mode]
	t.eq(label + " fresh title", game.flow.state, Flow.TITLE)
	t.check(label + " starts with card hidden", not game.flow.start_card.showing())
	if continue_mode == "interactive":
		game.bot_driven = false
	elif continue_mode == "bot":
		game.bot_driven = true
	else:
		t.check(label + " headless default is bot driven", game.bot_driven and DisplayServer.get_name() == "headless")
	t.check(label + " resumes without retry", game.flow.resume_run())
	await process_frame
	var card = game.flow.start_card
	t.eq(label + " restored options", game.run.start_pick_options(), expected_options)
	t.eq(label + " restored stage", game.run.stage, expected_stage)
	t.eq(label + " default tier unchanged", game.run.selected_run_tier(), 0)
	t.eq(label + " no automatic pick", game.run.start_pick.taken, "")
	t.eq(label + " no automatic reroll", game.run.start_pick.rerolls_left, int(saved.start_pick.rerolls_left))
	if expected_stage == 1 and continue_mode == "interactive":
		t.check(label + " presents saved card", card.showing() and card.is_processing_input())
		var shown_ids := []
		for tile in card.tiles():
			shown_ids.append(tile.id)
		t.eq(label + " shows saved three options", shown_ids, expected_options)
		var labels := []
		for child in card.get_children():
			if child is Label and child.is_visible_in_tree():
				labels.append(child.text)
		var hard: Dictionary = Cards.RUN_TIERS[1]
		var threat := "Threat: %d%% more crowd, %d%% shorter intervals" % [roundi(100.0 * (hard.cap_weight - 1.0)), roundi(100.0 * (1.0 - hard.interval_weight))]
		var pay := "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi(100.0 * (hard.event_core_multiplier - 1.0)), RunTier.PAY_GAIN_CAP]
		t.check(label + " visible pre-choice tier disclosure", threat in labels and pay in labels and card.offered_tiers() == [0, 1])
		var key := InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_2
		key.physical_keycode = KEY_2
		root.push_input(key, true)
		t.eq(label + " viewport choice reaches RunState", game.run.start_pick.taken, expected_options[1])
		t.check(label + " choice closes card", not card.showing())
	else:
		t.check(label + " card stays hidden", not card.showing())
		t.eq(label + " returns to stage without waiting", game.flow.state, Flow.STAGE)
	paused = false
	game.flow.store = null

func _tier_zero_format() -> void:
	for switch_back in [false, true]:
		var label := "switch to tier zero" if switch_back else "fresh tier zero"
		game.flow.store = Flow.RunStore.new("user://tier-format-%d-%s.json" % [OS.get_process_id(), str(switch_back)])
		_begin(705, 0)
		var checkpoint: Dictionary = game.flow.store.load()
		game.run.cogs += 13
		game.run.scrap += 17
		game.run.hp -= 1.0
		game.run.add_event_core(Vector3.ZERO)
		game.run.reroll_start_pick()
		if switch_back:
			t.check(label + " tier-one selection", game.flow.choose_run_tier(1))
			var hard: Dictionary = game.flow.store.load()
			t.eq(label + " tier-one checkpoint grants", hard.get("event_core_grants", -1), 0)
			hard.erase("run_tier")
			hard.erase("event_core_grants")
			t.eq(label + " tier-one preserves checkpoint", hard, checkpoint)
		t.check(label + " production selection", game.flow.choose_run_tier(0))
		t.eq(label + " saves successfully", game.flow.store_error, "")
		var saved: Dictionary = game.flow.store.load()
		t.check(label + " omits both tier fields", not saved.has("run_tier") and not saved.has("event_core_grants"))
		t.eq(label + " original checkpoint unchanged", saved, checkpoint)
		t.check(label + " Continue eligible", not game.flow.saved_run().is_empty(), game.flow.saved_run_why)
		game.flow.state = Flow.TITLE
		t.check(label + " Continue resumes", game.flow.resume_run())
		t.eq(label + " Continue uses checkpoint cogs", game.run.cogs, int(checkpoint.cogs))
		t.eq(label + " Continue tier", game.run.selected_run_tier(), 0)
	game.flow.store = null

func _mouse_tiles() -> void:
	game.bot_driven = false
	paused = true
	var offers := [["cogs", "core", "long_barrel"], ["loose_trigger", "magnet_spool", "spiral_wave"]]
	for offer_index in offers.size():
		for pick_index in 3:
			_begin(706, 0)
			if offer_index == 1:
				game.flow._begin_run(ClassDef.by_id("tally"))
			game.run.start_pick["options"] = offers[offer_index].duplicate()
			game.flow.show_start_card()
			await process_frame
			var card = game.flow.start_card
			var tiles: Array = card.tiles()
			var widths := []
			var total := StartCard.TILE_GAP * (tiles.size() - 1)
			for tile in tiles:
				var width := StartCard.PAD * 2.0 + StartCard.KEY + StartCard.GAP * 2.0 + StartCard.ICON + UiFonts.bold().get_string_size(tile.name, HORIZONTAL_ALIGNMENT_LEFT, -1, StartCard.FONT).x
				widths.append(width)
				total += width
			var label := "narrow" if offer_index == 0 else "wide"
			t.check(label + " offer covers extent case", total < card.size.x if offer_index == 0 else is_equal_approx(total, card.size.x), "tiles=%s card=%s" % [total, card.size.x])
			var expected := []
			var x: float = (card.size.x - total) * 0.5
			for width in widths:
				expected.append(Rect2(x, 0.0, width, StartCard.ICON + StartCard.PAD * 2.0))
				x += width + StartCard.TILE_GAP
			t.check(label + " shared panel rectangles exist", card.has_method("tile_rects"))
			if card.has_method("tile_rects"):
				t.eq(label + " panels match independent layout", card.tile_rects(), expected)
			var buttons := []
			for child in card.get_children():
				if child is Button and child.tooltip_text.begins_with("Take "):
					buttons.append(child)
			for i in buttons.size():
				t.eq(label + " hit rectangle %d" % i, Rect2(buttons[i].position, buttons[i].size), expected[i])
			var at: Vector2 = card.global_position + expected[pick_index].get_center()
			var move := InputEventMouseMotion.new()
			move.position = at
			move.global_position = at
			root.push_input(move, true)
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = at
				click.global_position = at
				click.pressed = pressed
				root.push_input(click, true)
			await process_frame
			t.eq(label + " viewport mouse tile %d reaches RunState" % pick_index, game.run.start_pick.taken, offers[offer_index][pick_index])
			t.check(label + " mouse pick closes card", not card.showing())
	paused = false
	game.bot_driven = true

func _expected_modifier(held: Array, key: String, tier_value: int) -> float:
	var expected := 1.0
	for id in held:
		var mods: Dictionary = Parts.CATALOGUE[id].get("mods", {})
		if tier_value == 1 and RunTier.ENHANCED.has(id):
			mods = mods.duplicate()
			mods.merge(RunTier.ENHANCED[id].mods, true)
		expected *= float(mods.get(key, 1.0))
	return expected

func _variants() -> void:
	_begin(703, 0)
	var base: Resource = Parts.def("loose_trigger")
	var original: Dictionary = Parts.rows()["loose_trigger"].duplicate(true)
	var base_rows := {}
	for id in RunTier.ENHANCED:
		base_rows[id] = Parts.row(id).duplicate(true)
	if game.flow.has_method("choose_run_tier"):
		game.flow.choose_run_tier(1)
	var enhanced: Resource = Parts.def("loose_trigger")
	t.check("effective bonus improves", enhanced.mods.weapon_rate > base.mods.weapon_rate)
	t.check("variant id slot rarity preserved", enhanced.id == base.id and enhanced.family == base.family and enhanced.rarity == base.rarity)
	var policy: Dictionary = load("res://src/core/run_tier.gd").get_script_constant_map().ENHANCED
	t.check("at most four enhanced rows", policy.size() <= 4)
	for id in policy:
		var current: Dictionary = Parts.row(id)
		var before: Dictionary = base_rows[id]
		for field in ["family", "rarity", "class_id", "slot", "layer"]:
			t.eq("variant %s preserves %s" % [id, field], current.get(field), before.get(field))
		var built = Sheet.from_parts([id])
		for key in policy[id].mods:
			t.check("variant %s improves %s" % [id, key], policy[id].mods[key] > Parts.CATALOGUE[id].mods[key])
			t.near("variant %s applied once by build" % id, built.mods[key], _expected_modifier([id], key, 1))
			t.near("variant %s two base-id copies fold independently" % id, Sheet.from_parts([id, id]).mods[key], _expected_modifier([id, id], key, 1))
	game.run.add_part("loose_trigger", "tier_test")
	game.run.add_part("loose_trigger@tier1", "tier_test")
	t.check("one-version acquisition", game.run.parts == ["loose_trigger"])
	var sheet = Sheet.from_parts(game.run.parts)
	var expected_rate := _expected_modifier(["loose_trigger"], "weapon_rate", 1)
	t.near("one-version effective build", sheet.mods.weapon_rate, expected_rate)
	var doc: Dictionary = game.run.to_entrance_doc()
	var loaded := RunState.new(GameEvents.new(), 8)
	loaded.begin(ClassDef.all()[0])
	t.check("enhanced reconstruction loads", loaded.from_entrance_doc(doc))
	t.check("one-version reconstruction", loaded.parts == ["loose_trigger"])
	t.near("reconstruction enhanced effect once", Sheet.from_parts(loaded.parts).mods.get("weapon_rate", 1.0), expected_rate)
	loaded.restore()
	t.near("retry enhanced effect once", Sheet.from_parts(loaded.parts).mods.get("weapon_rate", 1.0), expected_rate)
	# Deliberately attempt a second version through a save boundary.
	var invalid := doc.duplicate(true)
	invalid.parts.append("loose_trigger@tier1")
	t.check("both-version entrance rejected", not loaded.from_entrance_doc(invalid))
	loaded.begin(ClassDef.all()[0])
	t.near("tier-zero cache does not leak", Parts.def("loose_trigger").mods.weapon_rate, _expected_modifier(["loose_trigger"], "weapon_rate", 0))
	t.check("cached base row immutable", Parts.rows()["loose_trigger"] == original)
	loaded.events.free()

func _run() -> void:
	paused = true
	if game != null:
		# Audio processes while paused; this fixture does not measure sound.
		game.presentation.audio.process_mode = Node.PROCESS_MODE_DISABLED
	if record or section in ["all", "runtime"]:
		if only_seed < 0:
			_parallel_runtime()
		else:
			await _runtime()
	paused = false
	if not record and section == "all" and game == null:
		_create_game()
		await process_frame
	if not record and section in ["all", "card"]:
		_card()
	if not record and section in ["all", "variants"]:
		_variants()
	if not record and section in ["all", "persistence"]:
		_persistence()
	if not record and section in ["all", "format"]:
		_tier_zero_format()
	if not record and section in ["all", "mouse"]:
		await _mouse_tiles()
	if not record and section in ["all", "continue"]:
		_continue_card()
	if not record and section == "continue-replay":
		await _continue_replay()
	if game != null:
		game.free()
	quit(t.verdict())
