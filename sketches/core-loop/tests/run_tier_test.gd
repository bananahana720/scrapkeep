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
# 2026-10-19 stage/alpha-w17 re-record at 958bbdcd (Gate lane): the candidate stack's park PRs (#170 crown, #180 pit,
# #183 islands, #185 dam rim_cache) move park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged.
# 2026-10-21 headframe leg swing rows (World, #241 6326650261 ruling (a)): two park_pit rows and the headframe_legs route
# move park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged; recorded with --record-base --section=runtime --seed=N.
const BASE_SCHEDULE := [
	"555d3ff10720e3a76d2ac7efe3357448b77327f5f5d7c2ae847b587101fd17cb",
	"d1e8b54b3938aefd9d81d42dde2b6ac4118846fe220ab22415792502b7ca13b4",
	"471ec4c8315008aa937d8a40484f29935bc53c29b12132749ebac6309541dc5c",
	"2b35c7cf5f0b637368e79ad8aaf4a2460588eca015d2633c4a17eacd2d71a345",
	"4d99af2388e32607faea10c0bd61a5c48955c68a3860c1ab65b3b5d74853b673",
	"c521453da08764b49874ac627acf8ff6bb8d868923f6b57561f0657972d41812",
	"f39b8a1b25e36dd83edd6281f37ba9bc8fca4af7b4fcea22253cf88a12880110",
	"f2d71610047627d729b62fba13a04867b43c547914a55e3d54daab20f85cca32",
	"26d1f47c9704aefebb4f6f932815e1a74f6c436a23a1bb7e4b697847887cc40e",
	"78e195a340b8917a72b3302efbaad589894478d650555f4d500f828f27d5eabf",
	"1b8fe897f819c96495ec9121aa62b4e5ea4659525bf1567b3916c6a3df70fe7f",
	"cdfdc72eb2ff0529e04942217662d894e764b95e0ecbfa26b685fef9450859ba",
	"451fdd0b4d220209c2e674b42de8f24624b9b188dbc1da7a0565c9370725a60f",
	"be48f19c147f40d498eae0f1ab266df412fe55f682a5f583fd6d551e219c2c10",
	"b0600884aa2b0a63340ae5367631907be93abe515b2fe0c543f772e71470b99d",
	"3bddadc4b053b9d146482229590e50713cda595703e4c501189d2627b8c6ac2a",
	"a591a12a0977956258bb6ce5f4a5b3ea2e239d80037fe73b76faf1039c507481",
	"7c42d3a6af41dbc84cf49b69efe4df33d0313f19f8be6b9284fda3fa64ca182e",
	"dd13170182fe42c659a4e850f7d9234314534a1f35330acf329cf38e37ddf4c0",
	"ab44826b44ec2c2c55a9c9e382f03e7d1113778b82de877b4f6dbd379034a7e1",
]
# 2026-10-15 wave-14 re-pin at 8b507ffb (SQ9 speed bank, PC-POOL part rows, SQ19 offer weights and
# the SQ9 free-rest fix move the default run; schedules unchanged): recorded with --record-base.
# 2026-10-18 stage/alpha-w17 re-record at 04eb0d00: whole runs moved on seeds 3, 7, 12, 14, 15, 16, 17, 18, 19 (9 of 20); the others are
# unchanged; recorded with BASE_SCHEDULE above.
# 2026-10-19 answer weighting (Systems, #149: OFFER_WEIGHT 1.5 on the pilot's nemesis answers) merged with stage/alpha-w17
# 1a7a7299: whole runs moved on all 20 seeds, schedules unchanged; recorded with --record-base --section=runtime, one seed at a time.
const BASE_RUN := [
	"2f207bcf1f24c4d4dc9289e1e8a2153653aa6c274dde600cb766c611eab1d2e6",
	"ca3f7c952e81ac340217f084c90ac97ad7edc1a8e8cca58d7d912f9fb1853e2c",
	"08fefb74b421b2b056532e66f0fac7aba0ac95b9156061974baa9be0a5c72365",
	"8d59a983ee861e0b849c2274a9d64affab5e84cebf7943834ba0ad7dca1ef4de",
	"5bb225480271c11857d00e1bcf323b3a54a880125f834d831aacefaa5fa9fd23",
	"1e84c9a90e812f9b4934ba70c00747c249b493c61a8feb9bb01ee1a78840dd9f",
	"e432ad7c0e624d9010d186eb5e1595e53dd5f37db1e48d80e9bdba1d13894b92",
	"3cb0d5879379dd82c55f3e28b88cf3d72f919d8b3c408940efcb25d1bd4bef13",
	"1359a0d2aefaa1d287813f20299a259865596d9f4d7a8ad569c42be83da34ffd",
	"62bbfb315da721f031b8c846aee8085f102fd671a904a3254a77f24496cd5443",
	"6006f815a0c8ae9852aa0880ec24613836ef6ba1cf7189c5b4df8c71aea11327",
	"5b08b142c29c5653e55a36dc71c54a639d44e784a3896325eb77d630eba1e26a",
	"6586afb7094cd3b8f0309cf499e69cfdb8b343bb959372f237464dd8448eed76",
	"06a0abed6827abc35272ab001207285fd17c2dac342a6891d4121a8a9d86a7dd",
	"899576e30526b6aca7cc6c034a579f85add6737f9bbad4d0383caed7e55fca15",
	"2563d3567d3df0721fe0dc35cda1c59bd8b281d786b40f036fc20de5885c8c56",
	"df2da022370e65d2ad91cf585499671c7b13bde264921b7cd02f493f2575c387",
	"0158fc4c65299a3811986a05f58456b73b8bd7c23ad061eabb525a0b35bd0b86",
	"32e09b558ff2476833a76fcc63e545f63073b9a0cdcaf2b5b8e128b169ebd059",
	"d53f09971fb55ae997a84b5a4a1b24ffdb6e1000e647e22d26214396d0ce60b3",
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
