extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Items := preload("res://src/build/items.gd")
const MakerDefs := preload("res://src/build/maker_defs.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Relics := preload("res://src/build/relics.gd")
const RelicSwaps := preload("res://src/combat/relic_swaps.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const Shop := preload("res://src/build/shop.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const Synergies := preload("res://src/build/synergies.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")
const T := preload("res://tests/support/t.gd")

var _t := T.new("risk_reward_distribution_test")
var _game
var _source := Intent.Scripted.new()


func _initialize() -> void:
	_check_risk_vs_kindness_tables()
	_check_world_escalation_and_verb_parts()
	_check_world_relics_all_pilots()
	_check_archetype_synergies_and_grapple_maps()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run_live.call_deferred()


func _sim(ticks: int) -> void:
	for _i in ticks:
		await physics_frame


func _check_risk_vs_kindness_tables() -> void:
	for stage in [1, 3, 5, 6]:
		var safe_offer := {"family": "safe", "interior_id": "ward_counter", "stage": stage, "tier": 1}
		_t.eq("kindness stays common at stage %d" % stage, TradePockets.reward_rarities_for(safe_offer, stage), ["common"])
		var safe_devs := TradePockets.devices(safe_offer)
		_t.check("kindness chest stays tier 1 and non-high-impact at stage %d" % stage,
			safe_devs.size() == 2 and int(safe_devs[1]["tier"]) == 1 and not bool(safe_devs[1]["high_impact"])
			and safe_devs[1]["owner"] == "kindness" and safe_devs[1]["rarities"] == ["common"], str(safe_devs))
	var blood := {"family": "risk", "interior_id": "blood_counter", "stage": 1, "tier": 1, "curse": false, "sacrifice": false}
	var curse := {"family": "risk", "interior_id": "curse_counter", "stage": 2, "tier": 2, "curse": true, "sacrifice": false}
	var sac := {"family": "risk", "interior_id": "sacrifice_counter", "stage": 3, "tier": 1, "curse": false, "sacrifice": true}
	var contract := {"id": TradePockets.OVERTIME_CONTRACT, "family": "risk", "stage": 1}
	_t.eq("blood_counter stage 1 draws rare", TradePockets.reward_rarities_for(blood, 1), ["rare"])
	_t.eq("curse_counter draws rare+relic", TradePockets.reward_rarities_for(curse, 2), ["rare", "relic"])
	_t.eq("sacrifice_counter draws rare+relic", TradePockets.reward_rarities_for(sac, 3), ["rare", "relic"])
	_t.eq("overtime_contract draws rare+relic", TradePockets.reward_rarities_for(contract, 1), ["rare", "relic"])
	var risk_devs := TradePockets.devices(blood)
	_t.check("gamble chest elevates to tier >= 2 and high_impact",
		risk_devs.size() == 2 and int(risk_devs[1]["tier"]) >= 2 and bool(risk_devs[1]["high_impact"])
		and risk_devs[1]["owner"] == "gamble" and risk_devs[1]["rarities"] == ["rare"], str(risk_devs))


func _check_world_escalation_and_verb_parts() -> void:
	var prev_table = Synergies.table
	Synergies.set_table(AlphaDefs)
	_t.eq("W1 fabricator stays common", PartOffers.source_rarities("fabricator", 1), ["common"])
	_t.eq("W2 fabricator mixes common and rare", PartOffers.source_rarities("fabricator", 3), ["common", "rare"])
	_t.eq("W3 fabricator mixes common and rare", PartOffers.source_rarities("fabricator", 5), ["common", "rare"])
	_t.eq("W1 vault stays rare", PartOffers.source_rarities("vault", 1), ["rare"])
	_t.eq("W2 vault escalates to rare+relic", PartOffers.source_rarities("vault", 3), ["rare", "relic"])
	_t.eq("W3 vault escalates to rare+relic", PartOffers.source_rarities("vault", 5), ["rare", "relic"])
	_t.check("rare multiplier climbs W1 < W2 < W3",
		PartOffers.stage_rare_mult(1) < PartOffers.stage_rare_mult(3) and PartOffers.stage_rare_mult(3) < PartOffers.stage_rare_mult(5),
		"%.2f / %.2f / %.2f" % [PartOffers.stage_rare_mult(1), PartOffers.stage_rare_mult(3), PartOffers.stage_rare_mult(5)])
	_t.eq("gate_rarities W1 0 cores stays common", PartOffers.gate_rarities(0, 1), ["common"])
	_t.eq("gate_rarities W2 0 cores mixes common+rare", PartOffers.gate_rarities(0, 3), ["common", "rare"])
	_t.eq("gate_rarities W2 1 core lifts to rare", PartOffers.gate_rarities(1, 3), ["rare"])
	_t.eq("gate_rarities W3 1 core lifts to rare+relic", PartOffers.gate_rarities(1, 5), ["rare", "relic"])

	var verb_parts := ["slag_pike", "halo_rig", "backwash", "barbed_reel", "faultline_cap", "second_bell",
		"long_leash", "fan_spread", "helix_drill", "basalt_ram", "storm_capacitor", "boomerang_spool",
		"orbital_flywheel", "prism_splitter", "slag_furnace"]
	for pid in verb_parts:
		_t.check("%s counts as changes_behaviour and high_impact" % pid,
			PartOffers.changes_behaviour(pid, Parts.def) and PartOffers.is_high_impact(pid, Parts.def), pid)
	_t.check("planted: stat cobalts gatling_heart and ram_plow stay changes_behaviour=false",
		not PartOffers.changes_behaviour("gatling_heart", Parts.def) and not PartOffers.changes_behaviour("ram_plow", Parts.def), "")

	var prev_seams := Parts.seams.duplicate()
	Parts.set_seams({"spawner.fan_spread": true, "spawner.helix_drill": true})
	var fab := Fabricators.new()
	fab._class_id = "runner_gunner"
	var rare_counts := {1: 0, 3: 0, 5: 0}
	var verb_hits := {1: 0, 3: 0, 5: 0}
	var surfaced_w23 := {}
	for stage in [1, 3, 5]:
		fab._stage = stage
		fab._rng = RandomNumberGenerator.new()
		fab._rng.seed = 6000 + stage * 100
		for _i in 240:
			var pid := fab._roll([])
			if Parts.rarity_of(pid) == "rare":
				rare_counts[stage] += 1
			if pid in verb_parts or PartOffers.changes_behaviour(pid, Parts.def):
				verb_hits[stage] += 1
			if stage >= 3 and pid in verb_parts:
				surfaced_w23[pid] = int(surfaced_w23.get(pid, 0)) + 1
	fab.free()
	_t.eq("W1 fabricator rolls 0 rares over 240 draws", rare_counts[1], 0)
	_t.check("W2 fabricator rolls meaningful rare share and W3 exceeds W2",
		rare_counts[3] >= 35 and rare_counts[5] > rare_counts[3] and rare_counts[5] >= 75,
		"W1=%d W2=%d W3=%d of 240" % [rare_counts[1], rare_counts[3], rare_counts[5]])
	_t.check("W2-W3 fabricators organically surface multiple Tier 2-3 verb-mutating parts",
		surfaced_w23.size() >= 6 and verb_hits[5] > verb_hits[1],
		"distinct=%d (%s) verbs=%s" % [surfaced_w23.size(), surfaced_w23.keys(), verb_hits])

	var hi_rng := RandomNumberGenerator.new()
	hi_rng.seed = 8123
	var hi_impact := 0
	var hi_relics := 0
	for _i in 80:
		var got := Parts.roll_high_impact(hi_rng, ["rare", "relic"], "pylon_engineer", [], 1, [], {}, 5, true)
		if not got.is_empty():
			var pid := String(got[0])
			if PartOffers.is_high_impact(pid, Parts.def):
				hi_impact += 1
			if Relics.is_relic(pid) and Relics.swap_of(Relics.relic_of(pid)) != "":
				hi_relics += 1
	_t.eq("roll_high_impact delivers 100% high-impact picks", hi_impact, 80)
	_t.check("roll_high_impact surfaces W2/W3 kit-swap relics when rare+relic allowed", hi_relics >= 15, "relics=%d/80" % hi_relics)
	Parts.set_seams(prev_seams)
	Synergies.set_table(prev_table)


func _check_world_relics_all_pilots() -> void:
	_t.eq("Relics.validate() clean", Relics.validate(), [])
	_t.eq("Relics.validate_alt() clean", Relics.validate_alt(), [])
	_t.eq("MakerSets.validate() clean", MakerSets.validate(), [])
	_t.eq("WORLD_SWAPS defines 6 missing W2/W3 swaps", Relics.WORLD_SWAPS.size(), 6)
	for pilot in Relics.pilots():
		for world in [1, 2, 3]:
			var swaps := Relics.eligible_swaps(pilot, {}, null, world)
			_t.check("%s has >= 1 kit-swap relic in World %d" % [pilot, world],
				not swaps.is_empty() and swaps.all(func(id): return Relics.swap_of(id) != "" and int(Relics.row(id)["world"]) == world),
				"swaps=%s" % [swaps])
	for id in Relics.WORLD_SWAPS:
		var r := Relics.row(id)
		var name_words := String(r["name"]).split(" ", false).size()
		var text_words := String(r["text"]).split(" ", false).size()
		var slot := String(r["slot"])
		var swap := Relics.swap_of(id)
		var icon := String(AbilityState.ABILITIES.get(swap, {}).get("icon", ""))
		_t.check("WORLD_SWAP %s respects word caps, overdrive, suffix, maker" % id,
			name_words <= Relics.MAX_NAME_WORDS and text_words <= Relics.MAX_TEXT_WORDS
			and Relics.overdrive_of(id) > 1.0 and String(r["maker"]) in Relics.valid_makers()
			and icon.ends_with(String(Relics.SUFFIX[slot])), str(r))


func _check_archetype_synergies_and_grapple_maps() -> void:
	_t.eq("planted: empty build has no dominant archetype", PartOffers.dominant_archetype([], Parts.maker_of), "")
	_t.eq("planted: single part does not lock archetype", PartOffers.dominant_archetype(["ram_plow"], Parts.maker_of), "")
	_t.eq("heavy_melee archetype detected", PartOffers.dominant_archetype(["ram_plow", "basalt_ram", "drop_weight"], Parts.maker_of), "heavy_melee")
	_t.eq("run_n_gun archetype detected", PartOffers.dominant_archetype(["gatling_heart", "fan_spread", "helix_drill"], Parts.maker_of), "run_n_gun")
	_t.eq("spell_cast archetype detected", PartOffers.dominant_archetype(["spare_cell", "storm_capacitor", "second_bell"], Parts.maker_of), "spell_cast")

	var melee_nudge := PartOffers.archetype_nudge(["ram_plow", "basalt_ram"], ["drop_weight", "faultline_cap", "gatling_heart"], Parts.offer_ops())
	_t.check("heavy_melee nudge boosts melee anchors and leaves gun parts untouched",
		melee_nudge.has("drop_weight") and melee_nudge.has("faultline_cap") and not melee_nudge.has("gatling_heart"), str(melee_nudge))
	var gun_nudge := PartOffers.archetype_nudge(["gatling_heart", "fan_spread"], ["helix_drill", "slag_pike", "drop_weight"], Parts.offer_ops())
	_t.check("run_n_gun nudge boosts shooting anchors and leaves melee parts untouched",
		gun_nudge.has("helix_drill") and gun_nudge.has("slag_pike") and not gun_nudge.has("drop_weight"), str(gun_nudge))
	var spell_nudge := PartOffers.archetype_nudge(["spare_cell", "storm_capacitor"], ["second_bell", "overcharge_coil", "ram_plow"], Parts.offer_ops())
	_t.check("spell_cast nudge boosts casting anchors and leaves melee parts untouched",
		spell_nudge.has("second_bell") and spell_nudge.has("overcharge_coil") and not spell_nudge.has("ram_plow"), str(spell_nudge))

	_t.eq("evolution completion bait finds basalt_ram for orbital_flywheel",
		PartOffers.completing_archetype_part(["orbital_flywheel"], ["hot_rivets", "basalt_ram"], Parts.offer_ops()), "basalt_ram")
	_t.eq("3-piece Spillway completion bait finds 3rd Spillway piece",
		PartOffers.completing_archetype_part(["quick_spool", "cap_relay"], ["hot_rivets", "backwash"], Parts.offer_ops()), "backwash")
	_t.eq("3-piece Roosts completion bait finds 3rd Roosts piece",
		PartOffers.completing_archetype_part(["loose_trigger", "long_barrel"], ["hot_rivets", "storm_capacitor"], Parts.offer_ops()), "storm_capacitor")

	_t.eq("basalt_ram maps to tether_slam grapple mutation", Items.grapple_mutation_of("basalt_ram"), "tether_slam")
	_t.eq("storm_capacitor maps to sonic_snap_sling grapple mutation", Items.grapple_mutation_of("storm_capacitor"), "sonic_snap_sling")
	_t.eq("slag_furnace maps to hot_wire grapple mutation", Items.grapple_mutation_of("slag_furnace"), "hot_wire")
	_t.eq("prism_splitter maps to live_bus grapple mutation", Items.grapple_mutation_of("prism_splitter"), "live_bus")
	_t.eq("orbital_flywheel maps to wrecking_flail grapple mutation", Items.grapple_mutation_of("orbital_flywheel"), "wrecking_flail")

	PartOffers.archetype_nudge_on = false
	_t.eq("archetype_nudge respects toggle", PartOffers.archetype_nudge(["ram_plow", "basalt_ram"], ["drop_weight"], Parts.offer_ops()), {})
	Parts.reset_for_tests()
	_t.check("reset_for_tests restores archetype_nudge_on", PartOffers.archetype_nudge_on, "")


func _run_live() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await _sim(6)
	var run = _game.ctx.run
	var build = _game.ctx.build
	var shop: Shop = build.shop
	var combat = _game.combat
	var swaps: RelicSwaps = combat.relic_swaps

	run.stage = 3
	run.parts.clear()
	run.cogs = 500
	var low_auc := TradePockets.bid_salvage_auction(run, 40)
	_t.check("salvage auction low bid stays common and non-high-impact",
		bool(low_auc["ok"]) and not bool(low_auc["high_impact"]) and low_auc["rarities"] == ["common"]
		and Parts.rarity_of(String(low_auc["part_id"])) == "common", str(low_auc))
	run.stage = 4
	run.parts.clear()
	run.cogs = 500
	var hi_auc := TradePockets.bid_salvage_auction(run, 100)
	_t.check("salvage auction high bid grants high-impact rare",
		bool(hi_auc["ok"]) and bool(hi_auc["high_impact"]) and hi_auc["rarities"] == ["rare"]
		and Parts.rarity_of(String(hi_auc["part_id"])) == "rare" and PartOffers.is_high_impact(String(hi_auc["part_id"]), Parts.def), str(hi_auc))
	run.stage = 5
	run.parts.clear()
	run.cogs = 500
	var relic_auc := TradePockets.bid_salvage_auction(run, 180)
	_t.check("salvage auction relic bid grants high-impact rare or relic",
		bool(relic_auc["ok"]) and bool(relic_auc["high_impact"]) and relic_auc["rarities"] == ["rare", "relic"]
		and Parts.rarity_of(String(relic_auc["part_id"])) in ["rare", "relic"]
		and PartOffers.is_high_impact(String(relic_auc["part_id"]), Parts.def), str(relic_auc))

	run.stage = 3
	run.parts.clear()
	var cogs_before: int = run.cogs
	TradePockets.sign_overtime_contract(run)
	var contract_win := TradePockets.settle_overtime_contract(run, 25.0, _game.player.ball_position())
	_t.check("overtime contract win pays 140 cogs and high-impact W2 part",
		bool(contract_win["ok"]) and bool(contract_win["won"]) and run.cogs == cogs_before + 140
		and String(contract_win.get("part_id", "")) != "" and PartOffers.is_high_impact(String(contract_win["part_id"]), Parts.def), str(contract_win))

	run.stage = 4
	run.parts.clear()
	var cores_before: int = run.bonus_cores
	build.overtime_paid(_game.player.ball_position(), 2)
	_t.check("overtime 2 rings pays 1 high-impact rare part",
		run.parts.size() == 1 and Parts.rarity_of(String(run.parts[0])) == "rare" and PartOffers.is_high_impact(String(run.parts[0]), Parts.def), str(run.parts))
	run.parts.clear()
	build.overtime_paid(_game.player.ball_position(), 3)
	_t.check("overtime 3 rings pays 2 high-impact rare/relic parts and bonus core",
		run.parts.size() == 2 and run.bonus_cores == cores_before + 1
		and run.parts.all(func(pid): return Parts.rarity_of(String(pid)) in ["rare", "relic"] and PartOffers.is_high_impact(String(pid), Parts.def)), str(run.parts))

	run.stage = 3
	run.parts.clear()
	StakeDevices.reset_challenge_stakes(run)
	StakeDevices.stack_challenge(run, Vector3.ZERO)
	StakeDevices.stack_challenge(run, Vector3.ZERO)
	build.gates.close()
	build._on_flow_changed("gates")
	var stake_offers: Array = build.gates.offers.filter(func(o): return not ActiveOffers.is_offer(String(o["part_id"])))
	var stake_tail: Array = stake_offers.slice(2)
	_t.check("challenge stakes add 2 high-impact rare/relic gate choices",
		stake_tail.size() == 2 and stake_tail.all(func(o): return String(o["rarity"]) in ["rare", "relic"] and PartOffers.is_high_impact(String(o["part_id"]), Parts.def)),
		str(stake_tail.map(func(o): return [o["part_id"], o["rarity"]])))
	build.gates.close()
	StakeDevices.reset_challenge_stakes(run)

	run.stage = 3
	run.parts.clear()
	run.add_part("quick_spool", "test")
	run.add_part("cap_relay", "test")
	shop.enter()
	var set_shown: bool = shop.shelf.any(func(e): return MakerSets.maker_of(String(e["part_id"])) == MakerDefs.SPILLWAY)
	_t.check("W2 shop surfaces completing 3rd Spillway piece when 2 held", set_shown, str(shop.shelf))
	shop.leave()

	var spell_rng := RandomNumberGenerator.new()
	spell_rng.seed = 4242
	var active_hits := 0
	for _i in 40:
		var ao: String = build.active_offer_for_channel("gate", ["rare", "relic"], spell_rng, true)
		if ao != "":
			active_hits += 1
	_t.check("boosted risky channel with near-set Spillway strongly surfaces F-key actives",
		active_hits >= 15, "active_hits=%d/40" % active_hits)

	run.parts.clear()
	run.add_part(Relics.part_of("arc_sling"), "test")
	build.sync_relics()
	swaps.reset(true)
	var anchor: Vector3 = _game.player.ball_position() + Vector3(0.0, 2.0, -10.0)
	_game.player.grapple_to(anchor, Vector3.UP, null)
	combat._fire_line_skill("bank_arc", 1.0)
	var base_width: float = float(swaps._arc_chords[-1]["width"])
	var base_dmg: float = float(swaps._arc_chords[-1]["damage"])

	run.parts.clear()
	run.add_part(Relics.part_of("storm_sling"), "test")
	build.sync_relics()
	swaps.reset(true)
	_game.player.grapple_to(anchor, Vector3.UP, null)
	combat._fire_line_skill("bank_arc", 1.0)
	var od_width: float = float(swaps._arc_chords[-1]["width"])
	var od_dmg: float = float(swaps._arc_chords[-1]["damage"])
	_t.check("W2 storm_sling overdrives bank_arc width and damage vs W1 arc_sling",
		od_width > base_width and od_dmg > base_dmg,
		"width %.2f->%.2f dmg %.2f->%.2f" % [base_width, od_width, base_dmg, od_dmg])

	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = 777
	var boss_picks := RewardGates.roll_cobalt_boss_picks(boss_rng, "pylon_engineer", [], 2, 5)
	_t.check("boss cobalt picks return 2 behaviour-changing rares",
		boss_picks.size() == 2 and boss_picks.all(func(pid): return Parts.rarity_of(String(pid)) == "rare" and PartOffers.changes_behaviour(String(pid), Parts.def)),
		str(boss_picks))

	_game.free()
	quit(_t.verdict())
