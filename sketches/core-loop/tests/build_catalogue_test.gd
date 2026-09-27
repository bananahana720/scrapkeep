extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")

# The catalogue change request (DEMO-SPEC, reconciled.json, owner B): every row has a
# verb, a punch value and one or two known tags; only common rows may be
# percentage-only; of 50 seeded gate pairs each holds a part that raises punch or
# transforms a pattern; rarity follows source (gate tiers by bonus cores, fabricator
# uncommon, vault rare, milestone rare-plus); a vault kill adds exactly one rare part
# with source "vault"; and the gate label reads "{name}: {verb}. Punch +{n}".
# Balance loop B4: the tag table is pinned (parts per tag, kinetic down from 8 to 6),
# and over 50 seeds every stage-2 gate pair for a build with no pattern transformer
# offers Spiral Wave, Cross Split or Chain Arc, while a build that holds one, or any
# other stage, gets exactly the pair roll() gives; build opens stage 2's gates that way.

var _game
var _failures := 0
var _ticks := 0
var _gained: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.part_gained.connect(func(id: String, source: String): _gained.append([id, source]))
		return false
	if _ticks < 12:
		return false
	_check_rows()
	_check_tag_counts()
	_check_gate_pairs()
	_check_pattern_guarantee()
	_check_pattern_gate_live()
	_check_sources()
	_check_vault()
	_check_label()
	print("build_catalogue_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_rows() -> void:
	var bad: Array = []
	var plain_above_common: Array = []
	var tags_used := {}
	for part_id in Parts.ids():
		var d: Resource = Parts.def(part_id)
		if d.verb == "" or d.punch < 0.0 or d.tags.is_empty() or d.tags.size() > 2 or not d.rarity in PartDef.RARITIES:
			bad.append(part_id)
		for tag in d.tags:
			if not tag in PartDef.TAGS:
				bad.append("%s tag %s" % [part_id, tag])
			tags_used[tag] = true
		if d.rarity != "common" and d.percentage_only():
			plain_above_common.append(part_id)
	_report("every row has verb, punch and tags", bad.is_empty() and tags_used.size() == PartDef.TAGS.size(),
		"%d rows; rows missing a verb or with 0 or 3+ tags or an unknown tag %s; %d of %d tags in use"
			% [Parts.ids().size(), bad, tags_used.size(), PartDef.TAGS.size()])
	_report("no plain rows above common", plain_above_common.is_empty(),
		"uncommon, rare and rare-plus rows that only scale numbers: %s" % [plain_above_common])


func _check_gate_pairs() -> void:
	var rng := RandomNumberGenerator.new()
	var soft: Array = []
	for seed_value in 50:
		rng.seed = 1000 + seed_value
		var cores := seed_value % 3
		var pair: Array = Parts.roll(rng, Parts.gate_rarities(cores), "runner_gunner", [], 2)
		if pair.size() != 2 or not pair.any(func(key): return Parts.def(key).hits_harder()):
			soft.append(pair)
	_report("gate pairs hit harder", soft.is_empty(),
		"50 seeded gate pairs across 0 to 2 bonus cores; pairs with no punch or pattern part: %s" % [soft])


func _check_sources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wrong: Array = []
	var expect := {0: ["common", "uncommon"], 1: ["uncommon", "rare"], 2: ["rare", "rare_plus"], 3: ["rare", "rare_plus"]}
	for cores in expect:
		if Parts.gate_rarities(cores) != expect[cores]:
			wrong.append("gate %d cores %s" % [cores, Parts.gate_rarities(cores)])
	for source in ["fabricator", "vault", "milestone"]:
		for i in 60:
			var picks: Array = Parts.roll(rng, Parts.SOURCE_RARITIES.get(source, []), "pylon_engineer", [], 1)
			if source == "milestone":
				picks = [Parts.milestone_for("event_%d" % i, [])]
			if picks.is_empty() or Parts.def(picks[0]).rarity != Parts.SOURCE_RARITIES[source][0]:
				wrong.append("%s gave %s" % [source, picks])
				break
	_report("rarity by source", wrong.is_empty(),
		"gates: 0 cores common/uncommon, 1 uncommon/rare, 2+ rare/rare-plus; fabricator uncommon, vault rare, milestone rare-plus; wrong %s" % [wrong])


func _check_vault() -> void:
	var before: int = _game.run.parts.size()
	_gained.clear()
	_game.run.record_kill("vault", _game.player.ball_position() + Vector3(4.0, 0.0, 0.0), 0)
	var ok: bool = _gained.size() == 1 and _gained[0][1] == "vault" and Parts.def(_gained[0][0]).rarity == "rare" \
		and _game.run.parts.size() == before + 1
	_game.run.record_kill("chaser", _game.player.ball_position(), 0)
	_report("vault pays a rare part", ok and _game.run.parts.size() == before + 1,
		"a vault kill published %s; a chaser kill after it added nothing" % [_gained])


func _check_label() -> void:
	var line := Parts.headline("slag_rounds")
	var plain := Parts.headline("loose_trigger")
	_report("gate label", line == "Slag Rounds: Shots land heavy. Punch +10" and plain == "Loose Trigger: Fire faster.",
		"'%s' and '%s'" % [line, plain])


# Parts per tag across the whole catalogue. B4 moved kinetic off Arc Coil and Runner
# Overclock (8 -> 6 carriers), which brings Wrecking Ball under the 60% discovery cap.
const TAG_COUNTS := {"frost": 3, "arc": 4, "kinetic": 6, "split": 2, "spiral": 3, "chain": 3, "anchor": 5,
	"speed": 8, "mass": 7}


func _check_tag_counts() -> void:
	var counts := {}
	for part_id in Parts.ids():
		for tag in Parts.tags_of(part_id):
			counts[tag] = counts.get(tag, 0) + 1
	_report("tag table", counts == TAG_COUNTS, "parts per tag %s (pinned %s)" % [counts, TAG_COUNTS])


func _is_pattern(key: String) -> bool:
	return key in Parts.PATTERN_PARTS


# A held build of 0 to 4 parts drawn from draw_from, the same for a given seed.
func _hand(seed_value: int, draw_from: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + seed_value
	var hand: Array = []
	for i in seed_value % 5:
		hand.append(draw_from[rng.randi_range(0, draw_from.size() - 1)])
	return hand


func _check_pattern_guarantee() -> void:
	var plain: Array = Parts.ids().filter(func(key): return Parts.def(key).patterns.is_empty())
	var holders: Array = Parts.ids().filter(func(key): return not Parts.def(key).patterns.is_empty())
	var rng := RandomNumberGenerator.new()
	var missing: Array = []
	var broken: Array = []
	var changed: Array = []
	var fired := 0
	for seed_value in 50:
		var cores := seed_value % 3
		var rarities: Array = Parts.gate_rarities(cores)
		var class_id: String = ["runner_gunner", "pylon_engineer"][seed_value % 2]
		# A pattern-less build on stage 2 always sees a pattern part, and the first slot
		# (where the synergy bait sits) and the rarity rule outside the pattern slot hold.
		var held := _hand(seed_value, plain)
		rng.seed = 2000 + seed_value
		var plain_pair: Array = Parts.roll(rng, rarities, class_id, held, 2)
		rng.seed = 2000 + seed_value
		var pair: Array = Parts.roll_gate(rng, rarities, class_id, held, 2, 2)
		if pair.size() != 2 or not pair.any(_is_pattern):
			missing.append([cores, held, pair])
		if pair != plain_pair:
			fired += 1
		for i in pair.size():
			var d: Resource = Parts.def(pair[i])
			if not _is_pattern(pair[i]) and not d.rarity in rarities:
				broken.append("%s at %d cores is %s" % [pair[i], cores, d.rarity])
			if _is_pattern(pair[i]) and not d.rarity in rarities and cores < 2:
				broken.append("pattern %s relaxed at %d cores" % [pair[i], cores])
		if pair[0] != plain_pair[0] or not pair.any(func(key): return Parts.def(key).hits_harder()):
			broken.append("seed %d first slot %s vs %s" % [seed_value, pair[0], plain_pair[0]])
		# A build that already holds a pattern transformer, and every other stage, is
		# untouched: the same seed gives the same pair as roll().
		var holding: Array = held.duplicate()
		holding.append(holders[seed_value % holders.size()])
		rng.seed = 3000 + seed_value
		var expect_holding: Array = Parts.roll(rng, rarities, class_id, holding, 2)
		rng.seed = 3000 + seed_value
		if Parts.roll_gate(rng, rarities, class_id, holding, 2, 2) != expect_holding:
			changed.append("holding %s" % [holding])
		for stage in [1, 3]:
			rng.seed = 4000 + seed_value
			var expect_stage: Array = Parts.roll(rng, rarities, class_id, held, 2)
			rng.seed = 4000 + seed_value
			if Parts.roll_gate(rng, rarities, class_id, held, 2, stage) != expect_stage:
				changed.append("stage %d %s" % [stage, held])
	_report("stage-2 pattern guarantee", missing.is_empty() and broken.is_empty(),
		"50 seeded stage-2 pairs for pattern-less builds across 0 to 2 bonus cores; %d needed the guarantee; pairs with no pattern part %s; rule breaks %s"
			% [fired, missing, broken])
	_report("pattern holders and other stages unaffected", changed.is_empty(),
		"50 seeds: a build holding a pattern transformer on stage 2, and pattern-less builds on stages 1 and 3, got roll()'s pair; differed %s"
			% [changed])


# Build opens stage 2's gates through roll_gate: a pattern-less run on stage 2 is offered
# a pattern part on every one of 20 seeded openings.
func _check_pattern_gate_live() -> void:
	var build = _game.ctx.build
	var run = _game.run
	var saved_stage: int = run.stage
	var held_pattern: bool = Parts.holds_pattern(run.parts)
	run.stage = 2
	var without: Array = []
	for seed_value in 20:
		_game.ctx.rng.seed = 500 + seed_value
		build._on_flow_changed("gates")
		var ids: Array = build.gates.offers.map(func(o): return o["part_id"])
		if ids.size() != 2 or not ids.any(_is_pattern):
			without.append(ids)
		build.gates.close()
	run.stage = saved_stage
	_report("stage-2 gates offer a pattern", not held_pattern and without.is_empty(),
		"20 seeded stage-2 openings for held %s; openings with no pattern part %s" % [run.parts, without])
