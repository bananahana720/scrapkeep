extends SceneTree
# smoke: bots timeout=1800s
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
# 2026-10-21 merge of stage/alpha-w18 0eb9c897 into claude/systems-b-w18 (after the plate_press removal): pins re-read from this test's own MEASURE lines (schedule0, tier0.hash), seeds 0..19.
# 2026-10-22 merge of stage/alpha-w18 bc6d4e4b into #214 (World lane, after GPU row 24b PASS): #214's islands rows plus the
# stage's pit swing rows; all 20 schedules moved, whole-run hashes unchanged; pins read from this test's own MEASURE lines (schedule0), --section=runtime --seed=N.
# 2026-10-22 (W18-PLATEPRESS on stage fe09d434): plate_press is plated_brute + swatter; pins re-read from this test's MEASURE lines.
# 2026-10-22 merge of stage/alpha-w18 74682daf with the crown sentinel_50 and sentinel_36 moves (World lane): schedules re-read from this
# test's own MEASURE lines (schedule0), whole-run hashes checked against BASE_RUN.
# 2026-10-22 lava_channel_post_21i moved 7 m off the park_sinkhole bend bank (World, #241 6345347272 item 1): a park-row datum in the schedule hash; all 20 moved, whole-run hashes unchanged; pins read from this test's own MEASURE lines (schedule0).
# 2026-10-22 merge of stage/alpha-w18 42ed00ee (B8: 21i move) into crowngap (#321): both moves change park-row data;
# schedules re-read from this test's own MEASURE lines (schedule0), whole-run hashes checked against BASE_RUN.
# 2026-10-22 main_tube_upper_post_11i and lava_channel_post_13i moved off their park_sinkhole washes (World, #241 comment 6352524432): park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged; pins read from this test's own MEASURE lines (schedule0), seeds 0..19.
# 2026-10-22 merge of stage/alpha-w18 a777720a (B11: #321) into postbanks (#350): both change park-row data; schedules re-read from MEASURE (schedule0), seeds 0..19.
# 2026-10-23 lava_channel_12, 13 and 21 reshaped to ease the sinkhole wash elbows A and B (World, #241 6354292643 item 3): park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged; pins read from this test's own MEASURE lines (schedule0), seeds 0..19.
# 2026-10-23 merge of stage/alpha-w18 e564e2c3 (B17: #359 sinkhole elbows) into the drum kicker move (drum_lip_kicker 3.07 m east, World, #241 6357419327): both change park-row data; schedules re-read from MEASURE (schedule0), seeds 0..19.
# 2026-10-23 lava_channel_14 and 20 shortened to ease the sinkhole wash elbows 14>15 and 19>20 (World, #241 6356545723): park-row data in the schedule hash; all 20 moved, whole-run hashes unchanged; pins read from this test's own MEASURE lines (schedule0), seeds 0..19.
# 2026-10-23 merge of stage/alpha-w18 63261606 into #375 (Gate thread): schedules re-read from MEASURE (schedule0), seeds 0..19.
# 2026-10-24 stage/alpha-w18 re-pin at 7eff47b0 (Gate thread, coordinator ruling): the w18 stack since c0763e81 (#385 rogue fleet, #391 boss
# phases, #389 tunes, #402 roster, #406 first hour, #407 Cannon, #413 secrets, #416 Slag Bowl, #417, #418 and the rest) moves the
# schedule and the default run on all 20 seeds; no bisect (ruling d). Pins read from this test's own MEASURE lines (schedule0, tier0.hash).
# 2026-10-26 stage/alpha-w18 re-pin at 8d7ddd31 (fifteenth line: #480, #481, #483; ruling j integration commit): #481's
# drum_lip_kicker move (x 256.07 -> 258.0, fit dropped) is park-row data in the schedule hash, so all 20 schedules moved;
# #483 moves none (2afb6fb5, before #483, records the same 20). Whole-run hashes unchanged. Recorded with --record-base --section=runtime --seed=N.
# 2026-10-26 stage/alpha-w18 re-pin for the eighteenth line (#488, #490; ruling j integration commit): #488's dam park edge
# (canyon walls, trimmed outskirts post fields, rebake) is park-row data in the schedule hash, so all 20 schedules moved; #490 moves
# none (a38446ee, before #490, records the same 20). Whole-run hashes unchanged. Recorded with --record-base --section=runtime --seed=N.
# 2026-10-28 stage/alpha-w21 re-pin at b9880234 + #538 (ruling j integration commit): #529's cobalt pool (four catalogue rares join
# AlphaDefs.PARTS) and #536's Warden-gate and shop cobalt floors move the schedule and the default run on 20 and 20 of 20 seeds.
# Recorded with --record-base --section=runtime; the BASE lines equal this test's MEASURE lines (schedule0, tier0.hash) on all 20.
# 2026-10-31 stage/alpha-w29 re-pin at ff9984e0 (ruling ba; ruling j integration commit): #602's flume pier nudges
# (bend_zip_pier_7 z -144.5 -> -142.0, bluff_ride_pier_15 (172.1, 349.8) -> (174.4, 351.7)) are park-row data in the schedule hash,
# so all 20 schedules moved; #597 and #600 before it and #601 and #603 after it move none (one-seed record per stack commit,
# gate/w29-ff9984e0/bots-6.md). Whole-run hashes unchanged. Pins read from this test's own MEASURE lines (schedule0) at ff9984e0.
# 2026-10-31 stage/alpha-w30 re-pin at 860ee797 (ruling j integration commit): #605's dam crevice fill is park-row data in the
# schedule hash, so all 20 schedules moved; #608, #609 and #610 move none (the values equal #605's own record at a9c379cb,
# #607 comment 6539679622). Whole-run hashes unchanged. Recorded with --record-base --section=runtime --seed=N at 860ee797.
# 2026-11-14 PR 845 (world 1 difficulty stack re-land, merged with stage/alpha-w40 bd5b30f5 at 7077c2ee): the director
# schedule moves with the stack (a third clock tier on world 1, mobs.clock_tiers_by_stage): all 20 schedules moved;
# whole-run hashes unchanged. Recorded with --record-base --section=runtime.
const BASE_SCHEDULE := [
	"ed17962613691e59a3bb29c66a2f4ca10d129d69aa117d67b94ffc65feda76a8",
	"acaa5513f167b63efa3081ff8d35d03cef67991cb53cff163c230df850cafc9e",
	"7b2590add65f318d94f0d17ecc6917df312641c6a3bc031dbc1b435c89c51427",
	"6e5966ec0f6dca1cebafada6364483a4f3cf1174c3018cd6844ac7a4b23d703c",
	"81089cf9c3ed111824fb1f05f7d3cc9cf92b4d9114557cdd8461dca0ac7d88e5",
	"6a7dec29bfe20df281c9ccef457751bb5cf95022e872d206f5222bc21fb76e4d",
	"9e4f732114630d14811268d23bcaa044d4f6f717ad5891d3aa50017c37aa2645",
	"509792ea7707fa0dfaecc80490281ea7cb0dde80672de23b0bb5f4e58fdad052",
	"f26e0e7b5212033d1323c0eae168be31984d2f76e12280cf7791dfdf357e7a56",
	"92f7675f04a164393e4d8c7da9787ae84314f0e4a881e28968d5c3b078847c67",
	"60ce065d855699e16b554f7e527e0b56573341a0728307244599cd203c407f77",
	"14a59a2f25825b81f896dc68252a809ad045b593eceecdf3dceef4fdf8a7c811",
	"15c9d0af6a50bc2962bf1bdcecb5894c64adb35fc2d4c91736beb9070cc2b635",
	"34dd0e51d3e1f20d61d514910bfd5ff629203bad813ec7474f1bd0f5e524aeaf",
	"7152e5a590c515e84a55a6328c20129832047e9d45c6e62d0eae84de69d74977",
	"e2f7f33d18d98e10e6c21840266435ef76bf2b012f6aa01fc662d8737244318a",
	"974be8d23247cfa2d4a87796c0009b5c12f817dbda4e9bfb0633dbe40150ce10",
	"e6542d22a6c2047dee99d4f6758089b2ff5e2ee87eb0a93374917d495169b4c1",
	"f2b103f8974b429705c577c23ff9f8c67d0d6f529d311bbd0ad8fc46e4ea30c0",
	"b8ebc250e0b7068c0011d7cf537844c4e5eb0c72690eb7ca674208bed9099161",
]
# 2026-10-15 wave-14 re-pin at 8b507ffb (SQ9 speed bank, PC-POOL part rows, SQ19 offer weights and
# the SQ9 free-rest fix move the default run; schedules unchanged): recorded with --record-base.
# 2026-10-18 stage/alpha-w17 re-record at 04eb0d00: whole runs moved on seeds 3, 7, 12, 14, 15, 16, 17, 18, 19 (9 of 20); the others are
# unchanged; recorded with BASE_SCHEDULE above.
# 2026-10-19 answer weighting (Systems, #149: OFFER_WEIGHT 1.5 on the pilot's nemesis answers) merged with stage/alpha-w17
# 1a7a7299: whole runs moved on all 20 seeds, schedules unchanged; recorded with --record-base --section=runtime, one seed at a time.
# 2026-10-24 stage/alpha-w18 re-pin at 7eff47b0: whole runs moved on all 20 seeds with the schedules above; read from MEASURE (tier0.hash).
# 2026-10-24 #445 (world 1 items: park table 45 parts + Spare Frame, actives on) merged with stage/alpha-w18 b3680e56 at d41cf373:
# schedules and whole runs moved on all 20 seeds (ruling j integration re-pin); read from MEASURE (schedule0, tier0.hash).
# 2026-10-28 stage/alpha-w21 re-pin at b9880234 + #538: the cobalt pool and floors (#529, #536); see the note above BASE_SCHEDULE.
# 2026-11-08 invariants pass (#619, seed fixes): each stage's stream now starts from (session seed, run
# seed, stage), scrap, gates and vaults roll on their own streams, and the shop shelf follows the run and
# stage; whole runs moved on all 20 seeds, schedules unchanged (ruling ai re-pin row). Read from MEASURE
# (tier0.hash) with a local 600 s child cap.
const BASE_RUN := [
	"0591fc6b1cd5855556d5e884d71dd67cc3d363e3dece69df37af3d09df99f0ae",
	"1acb33d431f201e108e32596f0446810307a37d89cece0687fece452f08dfb91",
	"754081510f15861460e4cbd60200944f65b74f12af163e1c28d0a26fa44781f9",
	"ddc3fc89be784d73ed0c7649345ab4e61b458af1f664885dffd7e449bb7f3e9c",
	"5b056085f8314883dd0e68f3c29fe40b680086d3b63601538e7ae5f4ca25a8f3",
	"a3b178aa9fad983215663bf07d6fbd237fbe7f32ad3fabde63b4c25483d9e03c",
	"93114ccfbc044bf661734e02e36fd17ee93e2bcd33e0a2a484be87b943ddfbbe",
	"5b67c55a0e10448d618e04401ef0b916eedc85c08acfe77cc4aa21fbc40f28bf",
	"20715c1185041d7d71c07bad70d8ac0b0fd4337e86fbf598d21232b8c214633a",
	"9d190e8c84d1d3b705c2f772bab2a0f69865e2eec2740b31644e8c778a63f87d",
	"46c560fbc63f19a572ef2b47f4bd06085b7113a75d42290b172400226fda101f",
	"f2cf59280bf15e1bc47bcb1ba4097c3ef7ab3c6841233b03fbf78567d1cb1545",
	"97c89c983a10c0f5e3b355eaacffd83665dd18f36e159caec398a48a0542f329",
	"5ff1a8ed94b7b6a943a88ee668da438b43bdc5a335940cbc2af093a63eb593b5",
	"669a0c0bcfc09da962741517a3d33520cb554876e1d4079b17b58cc5d476f1c1",
	"8e47f904cd4f85f63291018ccbeb154b430e0bab8305f85cb52bb7327a9dfae0",
	"9e0b091208b7935accb9bce0faedfe4989a78775c8cdbc8c77ef986b17ee6e40",
	"85b0472ca9152d474af831020277600db58be11d1cd99df95e11223b2c7e7948",
	"5688ace964ef79baf678d3eade08733f66ad575524acf40f607363b62a90db70",
	"035cf283ca9c9b22f6d4d6cc68523a0dbe01925c5f144980685116c9d765af7e",
]
const SEEDS := 20
const DRAWS := 400
class ChoiceGame extends "res://src/game.gd":
	var capture_requests: Array[bool] = []
	func capture_mouse(capture: bool) -> void:
		capture_requests.append(capture)
	var quits := 0
	func _quit() -> void:
		quits += 1

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
		# 300 s per batch of four (70 s before RT-CAP, then 150 s): the cap catches a hang, not a slow machine. A child
		# runs 83 s alone and 158-164 s four at a time on the w30 gate box, where 150 s killed all 20.
		var results := ChildRuns.run(jobs, 300.0)
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
			# The stage's last clock tier (mobs.clock_tiers_by_stage: +3 on world 1 since wave 37, +2 elsewhere).
			var last_tier := Director.clock_tiers(d.dial_stage)
			var cap_expected := mini(Director.HARD_CAP, roundi((6 + 2 * last_tier) * row.threat * row.pressure.pack_scale * config.cap_weight))
			var interval_expected := maxf(Director.MIN_INTERVAL, (Director.BASE_INTERVAL - 0.7 * last_tier) / row.threat * row.pressure.interval_scale * config.interval_weight)
			t.eq("independent cap seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], measured.cap, cap_expected)
			t.near("independent interval seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], measured.interval, interval_expected)
			# Ruling al: no tier raises enemy health.
			t.near("health untouched seed %d tier %d stage %d" % [seed_value, tier_value, row.stage], d.hp_scale(), row.threat)
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
	# A fresh profile's card offers no mouse-only choice (picks are 1/2/3, the reroll V), so it keeps
	# mouse look (w22 first-timer red team edge 3).
	t.check("a fresh profile's start card keeps aim", not card.wants_pointer() and (game.capture_requests.is_empty() or game.capture_requests.back() == true)
		and not game.get_meta("menu_held", false), "requests %s" % [game.capture_requests])
	# With no menu held the pause menu can open over the card; while it is open the card's keys and
	# clicks take nothing.
	var menu = game.get_node_or_null("PauseMenu")
	if menu != null:
		menu.open()
		var pick_key := InputEventKey.new()
		pick_key.pressed = true
		pick_key.keycode = KEY_1
		pick_key.physical_keycode = KEY_1
		card._input(pick_key)
		t.check("the pause menu opens over the card and the card takes nothing under it", menu.is_open()
			and not game.flow.take_start_pick(0) and not game.flow.reroll_start_pick() and String(game.run.start_pick.get("taken", "")) == ""
			and game.run.start_pick.rerolls_left > 0 and card.showing())
		menu.close()
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
	t.check("a tier to choose releases the cursor", card.wants_pointer() and game.capture_requests.back() == false and game.get_meta("menu_held", false))
	var hard: Dictionary = Cards.RUN_TIERS[1]
	var expected_threat := "Threat: %d%% more crowd, %d%% shorter intervals, plated elite brutes" % [roundi(100.0 * (hard.cap_weight - 1.0)), roundi(100.0 * (1.0 - hard.interval_weight))]
	var expected_pay := "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi(100.0 * (hard.event_core_multiplier - 1.0)), RunTier.PAY_GAIN_CAP]
	# The ladder is drawn (pips and gauges); the rung looked at writes its threat and pay before the press.
	card.tier_button(1).grab_focus()
	t.check("rendered pre-choice threat/pay", expected_threat in card.drawn_words()
		and expected_pay in card.drawn_words() and game.run.selected_run_tier() == 0, "words %s" % [card.drawn_words()])
	card.tier_button(1).release_focus()
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
	# Esc with the card's cursor free (the pause menu held off) never quits a run.
	var esc := InputEventKey.new()
	esc.pressed = true
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	game.test_mode = false
	game._input(esc)
	var in_run: int = game.quits
	# The same Esc on a dead run's screen still quits (the state is set bare and put back).
	var was: int = game.flow.state
	game.flow.state = game.flow.DEAD
	game._input(esc)
	game.flow.state = was
	game.test_mode = true
	game.bot_driven = false
	t.check("Esc at the start card does not quit the run", in_run == 0 and game.flow.in_play(), "quits %d" % in_run)
	t.eq("Esc outside play still quits", game.quits, 1)
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
	# The workshop armed as in a launched game (ruling cl): the kit pick takes the screen from the
	# start card and its own keys; with it closed the card comes back as the briefing and takes 1.
	host.armed = true
	host.open_pick()
	t.check("the kit pick takes the screen from the start card", host.pick.is_open() and not card.showing())
	var tree_before: Array = game.player.tree.picks.duplicate()
	root.push_input(key, true)
	t.check("1 on the kit pick takes a kit card and no start pick", game.player.tree.picks.size() == tree_before.size() + 1 and game.run.start_pick.taken == "")
	host.close_pick()
	t.check("the start card comes back as the briefing", card.showing() and host.briefing() and paused)
	root.push_input(key, true)
	t.check("scripted pick reaches RunState", game.run.start_pick.taken == game.run.start_pick_options()[0] and not card.showing())
	t.check("the briefing lets go", not host.briefing() and not paused)
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
	for bad_tier in [-1, RunTier.TOP + 1, -1.0, float(RunTier.TOP + 1)]:
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
		var hard: Dictionary = Cards.RUN_TIERS[1]
		var threat := "Threat: %d%% more crowd, %d%% shorter intervals, plated elite brutes" % [roundi(100.0 * (hard.cap_weight - 1.0)), roundi(100.0 * (1.0 - hard.interval_weight))]
		var pay := "Pay: %d%% more event cores and rare weight; gain cap %.1fx" % [roundi(100.0 * (hard.event_core_multiplier - 1.0)), RunTier.PAY_GAIN_CAP]
		# The ladder is drawn (pips and gauges); the rung looked at writes its threat and pay before the press.
		if card.tier_button(1) != null:
			card.tier_button(1).grab_focus()
		t.check(label + " visible pre-choice tier disclosure", card.ladder_shown() and "Crowd" in card.drawn_words() and "Pay" in card.drawn_words()
			and threat in card.drawn_words() and pay in card.drawn_words() and card.offered_tiers() == [0, 1], "words %s" % [card.drawn_words()])
		if card.tier_button(1) != null:
			card.tier_button(1).release_focus()
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
	# The narrow offer's tiles must stay under the interactive card's 780 px floor, effect lines included.
	var offers := [["cogs", "hot_rivets", "long_barrel"], ["loose_trigger", "magnet_spool", "spiral_wave"]]
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
				# A tile is as wide as the wider of its name and the effect line under it.
				var words := maxf(UiFonts.bold().get_string_size(tile.name, HORIZONTAL_ALIGNMENT_LEFT, -1, StartCard.FONT).x,
					UiFonts.bold().get_string_size(tile.effect, HORIZONTAL_ALIGNMENT_LEFT, -1, StartCard.EFFECT_FONT).x)
				var width := StartCard.PAD * 2.0 + StartCard.KEY + StartCard.GAP * 2.0 + StartCard.ICON + words
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
