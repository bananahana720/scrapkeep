extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const PartDef := preload("res://src/build/part_def.gd")
const Items := preload("res://src/build/items.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Icons := preload("res://src/ui/icons.gd")

# The catalogue change request (DEMO-SPEC, reconciled.json, owner B): every row has a
# verb, a punch value and one or two known tags; only common rows may be
# percentage-only; of 50 seeded gate pairs each holds a part that raises punch or
# transforms a pattern; rarity follows source (gate tiers by bonus cores, fabricator
# common, vault rare, milestone relic); a vault kill adds exactly one rare part
# with source "vault"; and the gate label reads "{name}: {verb}. +{n} punch".
# Balance loop B4: the tag table is pinned (parts per tag, kinetic down from 8 to 6),
# and over 50 seeds every stage-2 gate pair for a build with no pattern transformer
# offers Spiral Wave, Cross Split or Chain Arc, while a build that holds one, or any
# other stage, gets exactly the pair roll() gives; build opens stage 2's gates that way.
#
# v2 W4 loot (I2 section 4) extends it: every row's trigger is one of the twelve kinds
# or passive, its stack rule is known and its cap fits the rule, every number is
# finite, every description is at most eight words, every icon category, trigger and
# element glyph is a real Icons id, every effect id is in item_effects' closed table,
# the whole 69-item table is in the pool, the class items are offered only to their
# class, a part waiting on a missing seam is never offered, generated recipes rebuild
# identically from their id, and the rarity weights hold.

# 2026-10-04: the default table is the alpha ruleset (twelve parts, five synergies, class pick on); this test checks the full catalogue so it runs on the legacy FirstWorld table.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _ticks := 0
var _gained: Array = []


func _initialize() -> void:
	_game = LegacyGame.new()
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
	_check_loot_rows()
	_check_table_present()
	_check_class_gating()
	_check_needs_gate()
	_check_generator()
	_check_rarity_weights()
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
		if d.verb == "" or d.punch < 0.0 or d.tags.is_empty() or d.tags.size() > 2 or not d.rarity in ItemGen.RARITIES:
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
		"rare, relic and evolved rows that only scale numbers: %s" % [plain_above_common])


func _check_gate_pairs() -> void:
	var rng := RandomNumberGenerator.new()
	var soft: Array = []
	for seed_value in 50:
		rng.seed = 1000 + seed_value
		var cores := seed_value % 3
		var pair: Array = Parts.roll(rng, PartOffers.gate_rarities(cores), "runner_gunner", [], 2)
		if pair.size() != 2 or not pair.any(func(key): return Parts.def(key).hits_harder()):
			soft.append(pair)
	_report("gate pairs hit harder", soft.is_empty(),
		"50 seeded gate pairs across 0 to 2 bonus cores; pairs with no punch or pattern part: %s" % [soft])


func _check_sources() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var wrong: Array = []
	var expect := {0: ["common"], 1: ["common", "rare"], 2: ["rare", "relic"], 3: ["rare", "relic"]}
	for cores in expect:
		if PartOffers.gate_rarities(cores) != expect[cores]:
			wrong.append("gate %d cores %s" % [cores, PartOffers.gate_rarities(cores)])
	for source in ["fabricator", "vault", "milestone"]:
		for i in 60:
			var picks: Array = Parts.roll(rng, PartOffers.SOURCE_RARITIES.get(source, []), "pylon_engineer", [], 1)
			if source == "milestone":
				picks = [PartOffers.milestone_for("event_%d" % i, [])]
			if picks.is_empty() or Parts.def(picks[0]).rarity != PartOffers.SOURCE_RARITIES[source][0]:
				wrong.append("%s gave %s" % [source, picks])
				break
	_report("rarity by source", wrong.is_empty(),
		"gates: 0 cores common, 1 common/rare, 2+ rare/relic; fabricator common, vault rare, milestone relic; wrong %s" % [wrong])


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
	_report("gate label", line == "Slag Rounds: Hit much harder. +10 punch" and plain == "Loose Trigger: Fire faster.",
		"'%s' and '%s'" % [line, plain])


# Parts per tag across the whole catalogue. B4 moved kinetic off Arc Coil and Runner
# Overclock (8 -> 6 carriers), which brings Wrecking Ball under the 60% discovery cap.
# v2 W4 re-pinned it for the 86-row pool (the first 28, the 58 new rows) plus Moss's
# four cells; kinetic keeps to its old share (6 of 41 tags, 15%) or below 25%, so
# Wrecking Ball stays under its cap as the pool grows.
# 2026-10-08 (alpha wave 11 GP2): six new parts; was arc 14, spiral 7, anchor 17, speed 31, mass 33
# 2026-10-11 (alpha wave 13 SG5): load_dividend; was mass 35
# 2026-10-12 (alpha wave 13 SR9): relay_convergence, seam-gated on relay.convergence; was arc 15
# 2026-10-15 (wave 14 SQ19b, coordinator ruling): Tally's winch_pawl carries anchor (the winch
# and harpoon family); was anchor 18
# 2026-10-22 (alpha wave 19, earned save): spare_frame carries mass and anchor; was anchor 19, mass 36
# 2026-11-21 (wave 45 U6): Slag Pike carries kinetic and Halo Rig split; was kinetic 19, split 5
# 2026-11-21 (wave 45 U7): the five verb items: Backwash kinetic, Barbed Reel anchor and chain, Faultline
# Cap mass and kinetic, Second Bell spiral (the echo tag, as Echo Charge), Long Leash chain; tags picked
# so no pilot's kit share moves (offer_weights_test); was kinetic 20, spiral 8, chain 9, anchor 20, mass 37
# 2026-11-24 (wave 46 E2-09): Brass Drum (speed, split) and Heavy Breech (kinetic, mass); was kinetic 22, split 6, speed 32, mass 38
const TAG_COUNTS := {"frost": 5, "arc": 16, "kinetic": 23, "split": 7, "spiral": 9, "chain": 11, "anchor": 21,
	"speed": 33, "mass": 39}
const KINETIC_SHARE_MAX := 0.25


func _check_tag_counts() -> void:
	var counts := {}
	var total := 0
	for part_id in Parts.ids():
		for tag in Parts.tags_of(part_id):
			counts[tag] = counts.get(tag, 0) + 1
			total += 1
	var share: float = counts.get("kinetic", 0) / float(maxi(1, total))
	_report("tag table", counts == TAG_COUNTS and share <= KINETIC_SHARE_MAX,
		"parts per tag %s (pinned %s); kinetic share %.0f%% (at most %.0f%%)" % [counts, TAG_COUNTS, share * 100.0, KINETIC_SHARE_MAX * 100.0])


# I2 section 4's invariants, row by row.
func _check_loot_rows() -> void:
	var bad: Array = []
	for part_id in Parts.ids():
		bad.append_array(_row_problems(part_id, Parts.def(part_id)))
	_report("loot row invariants", bad.is_empty(),
		"%d rows: trigger in the closed twelve or passive, stack rule and cap fit, numbers finite, text at most 8 words, cat_/trg_/el_ glyphs are Icons ids, effect ids known; problems %s"
			% [Parts.ids().size(), bad])


func _row_problems(part_id: String, d: Resource) -> Array:
	var out: Array = []
	if not Triggers.is_trigger(d.trigger):
		out.append("%s trigger %s" % [part_id, d.trigger])
	if not d.stack_rule in PartDef.STACK_RULES:
		out.append("%s stack %s" % [part_id, d.stack_rule])
	if d.stack_rule == "hyperbolic" and not (d.stack_cap > 0.0 and d.stack_cap < 1.0):
		out.append("%s hyperbolic cap %s" % [part_id, d.stack_cap])
	if d.stack_rule == "capped" and d.stack_cap < 1.0:
		out.append("%s capped cap %s" % [part_id, d.stack_cap])
	for value in [d.punch, d.magnet, d.kill_scrap, d.proc_coeff, d.stack_cap, d.max_hp_bonus, d.cooldown_scale]:
		if not is_finite(float(value)):
			out.append("%s non-finite" % part_id)
	for key in d.mods:
		if not is_finite(float(d.mods[key])):
			out.append("%s mod %s" % [part_id, key])
	for key in d.effect:
		if typeof(d.effect[key]) in [TYPE_FLOAT, TYPE_INT] and not is_finite(float(d.effect[key])):
			out.append("%s effect %s" % [part_id, key])
	if ItemGen.word_count(d.text) > ItemGen.MAX_WORDS:
		out.append("%s text '%s'" % [part_id, d.text])
	if not d.icon_category in PartDef.ICON_CATEGORIES or not ("cat_" + d.icon_category) in Icons.ids():
		out.append("%s icon %s" % [part_id, d.icon_category])
	if d.trigger != "" and not Triggers.icon(d.trigger) in Icons.ids():
		out.append("%s trigger icon" % part_id)
	if d.element != "" and not ("el_" + d.element) in Icons.ids():
		out.append("%s element %s" % [part_id, d.element])
	var effect_id: String = d.effect.get("do", "")
	if effect_id != "" and not ItemEffects.EFFECTS.has(effect_id):
		out.append("%s effect %s" % [part_id, effect_id])
	if d.trigger != "" and effect_id == "":
		out.append("%s trigger without effect" % part_id)
	if d.trigger != "" and effect_id in ItemEffects.PASSIVE_EFFECTS:
		out.append("%s passive effect on a trigger" % part_id)
	for slot in d.charges:
		if not slot in ItemEffects.SLOTS:
			out.append("%s charge slot %s" % [part_id, slot])
	return out


func _check_table_present() -> void:
	var missing: Array = []
	for part_id in Items.TABLE:
		if not Parts.has(part_id):
			missing.append(part_id)
	for part_id in PartOffers.PATTERN_PARTS:
		if not Parts.has(part_id):
			missing.append(part_id)
	var table := Items.TABLE.size() + PartOffers.PATTERN_PARTS.size()
	var bowling: int = Items.TABLE.values().filter(func(r): return r.get("bwl", false)).size()
	var happy: int = Items.TABLE.values().filter(func(r): return r.get("happy", false)).size()
	var charge: int = Items.TABLE.values().filter(func(r): return r.get("base", "") == "charge" and not r.get("happy", false)).size()
	_report("71-item table in the pool", missing.is_empty() and table == 71 and bowling == 8 and happy == 5 and charge == 8,
		"%d table items (68 new + 3 pattern rows), %d authored rows in all; bowling %d, happy accidents %d, charge %d; missing %s"
			% [table, Parts.ids().size(), bowling, happy, charge, missing])


func _check_class_gating() -> void:
	var wrong: Array = []
	var gated := {"glide_vane": Items.KEST, "jet_vent": Items.KEST, "sprint_cell": Items.RIVET, "cloak_flask": Items.KEST,
		"grapple_coil": Items.SABLE}
	var classes := [Items.SABLE, Items.RIVET, Items.KEST]
	for part_id in gated:
		var rarity: String = Parts.def(part_id).rarity
		for class_id in classes:
			var offered: bool = part_id in Parts.offer_pool(class_id, [rarity])
			if offered != (class_id == gated[part_id]):
				wrong.append("%s to %s" % [part_id, class_id])
	var anchor_class: String = Parts.def("anchor_spring").class_id
	_report("class items offered only to their class", wrong.is_empty() and anchor_class == Items.SABLE,
		"glide_vane, jet_vent, cloak_flask (Kest), sprint_cell (Rivet), grapple_coil and anchor_spring (Sable); wrong %s" % [wrong])


func _check_needs_gate() -> void:
	var saved: Dictionary = Parts.seams.duplicate()
	Parts.set_seams({})
	var waiting: Array = Parts.ids().filter(func(id): return Parts.def(id).needs != "")
	var leaked: Array = []
	for part_id in waiting:
		var d: Resource = Parts.def(part_id)
		var class_id: String = d.class_id if d.class_id != "" else Items.SABLE
		if part_id in Parts.offer_pool(class_id, [d.rarity]):
			leaked.append(part_id)
	Parts.set_seams({"spawner.extend_cloak": true})
	var opened: bool = "feedback_loop" in Parts.offer_pool(Items.KEST, ["rare"])
	Parts.set_seams(saved)
	# 2026-10-12 (alpha wave 13 SR9): relay_convergence waits on relay.convergence; was 5 waiting.
	_report("parts waiting on a seam are never offered", leaked.is_empty() and waiting.size() == 6 and opened,
		"%d parts wait on a seam %s; offered without it %s; feedback_loop offered once spawner.extend_cloak exists: %s"
			% [waiting.size(), waiting, leaked, opened])


func _check_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	var bad: Array = []
	var bases := {}
	var triggers := {}
	for i in 240:
		var rarity: String = ItemGen.RARITIES[i % 4]
		var id := ItemGen.roll_id(rng, rarity)
		var d: Resource = Parts.def(id)
		var again: Dictionary = ItemGen.generated_row(id)
		bases[ItemGen.parse(id)["base"]] = true
		triggers[d.trigger] = true
		if d == null or d.rarity != rarity or d.display_name.split(" ").size() != 2 or again["text"] != d.text:
			bad.append(id)
			continue
		bad.append_array(_row_problems(id, d))
		if rarity != "common" and d.percentage_only():
			bad.append("%s plain" % id)
	_report("generator", bad.is_empty() and bases.size() == ItemGen.GENERATED_BASES.size() and triggers.size() == 12,
		"240 seeded recipes over %d bases and %d triggers: two-word names, rarity kept, same row rebuilt from the id, every invariant; problems %s"
			% [bases.size(), triggers.size(), bad])


func _check_rarity_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 97
	var counts := {}
	var n := 20000
	for i in n:
		var r := ItemGen.pick_rarity(rng, ItemGen.RARITIES)
		counts[r] = counts.get(r, 0) + 1
	var off: Array = []
	for r in ItemGen.RARITY:
		var want: float = ItemGen.RARITY[r]["weight"] / 100.0
		var got: float = counts.get(r, 0) / float(n)
		if absf(got - want) > 0.015:
			off.append("%s %.3f vs %.2f" % [r, got, want])
	_report("rarity weights", off.is_empty(), "20000 draws over all four rarities %s against 87/10/3/0; off %s" % [counts, off])


func _is_pattern(key: String) -> bool:
	return key in PartOffers.PATTERN_PARTS


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
		var rarities: Array = PartOffers.gate_rarities(cores)
		var class_id: String = ["runner_gunner", "pylon_engineer"][seed_value % 2]
		# A pattern-less build on stage 2 always sees a pattern part, and the first slot
		# (where the synergy bait sits) and the rarity rule outside the pattern slot hold.
		var held := _hand(seed_value, plain)
		rng.seed = 2000 + seed_value
		var plain_pair: Array = Parts.roll(rng, rarities, class_id, held, 2)
		rng.seed = 2000 + seed_value
		var pair: Array = PartOffers.roll_gate(rng, rarities, class_id, held, 2, 2, {}, Parts.offer_ops())
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
		if PartOffers.roll_gate(rng, rarities, class_id, holding, 2, 2, {}, Parts.offer_ops()) != expect_holding:
			changed.append("holding %s" % [holding])
		for stage in [1, 3]:
			rng.seed = 4000 + seed_value
			var expect_stage: Array = Parts.roll(rng, rarities, class_id, held, 2)
			rng.seed = 4000 + seed_value
			if PartOffers.roll_gate(rng, rarities, class_id, held, 2, stage, {}, Parts.offer_ops()) != expect_stage:
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
	var held_pattern: bool = PartOffers.holds_pattern(run.parts, Parts.def)
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
