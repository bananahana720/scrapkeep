extends SceneTree

# Wave 45 Unit P5: World 1 + Worlds 2/3 scalability hardening checks.
# Verifies:
#   1. Parts.slot_weights() gives strictly > 0.0 draw weight to every admitted World 1 common/uncommon
#      and rare item (including off-kit items: backwash, second_bell, long_leash, focus_lens,
#      live_line, tracer_round), preserves KIT_SHARE (0.70), handles every empty-group branch and
#      NEUTRAL_REPEAT_CAP cleanly, and scopes NEUTRAL_WEAPON_EASE to shelf only (never crushing
#      Rivet's rare-slot weapon parts in rest). Includes live roll and computed zero-rest controls.
#   2. ChallengeDials stages 3-6 inherit the stage 2 ruling-cu baseline (rolling regen, shell cover,
#      lobber lead, chaser speed, pack lead + cruise fade, boil stall) without altering stages 1-2;
#      planted control restores [1,1,0,0,0,0] and confirms stage 3 regresses to stationary healing.
#   3. Elements.BOSS_KINDS and elite_rules cover W2/W3 bosses ("waking", "mind") while regular mobs
#      stay false (planted control); Panels.drop_row() and NO_DROP_KINDS handle worlds 1-3 and
#      out-of-range worlds cleanly through Dropper.chance().

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Elements := preload("res://src/build/elements.gd")
const Panels := preload("res://src/build/panels.gd")
const RunState := preload("res://src/core/run_state.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const T := preload("res://tests/support/t.gd")

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const OFF_KIT_SIX := ["backwash", "second_bell", "long_leash", "focus_lens", "live_line", "tracer_round"]

var _t := T.new("w45_w23_scalability_test")


func _initialize() -> void:
	ChallengeDials.reset()
	_check_rest_weights()
	_check_slot_weight_invariants()
	_check_rivet_weapon_ease_scoping()
	_check_challenge_dials_w23()
	_check_boss_immunity_and_panels()
	ChallengeDials.reset()
	Synergies.set_table(null)
	quit(_t.verdict())


func _group_mass(pilot: String, weights: Dictionary) -> Dictionary:
	var mass := {"kit": 0.0, "moving": 0.0, "still": 0.0, "shelf": 0.0, "rest": 0.0}
	for id in weights:
		var w := float(weights[id])
		if Parts.in_kit(pilot, id):
			mass["kit"] += w
			mass["moving" if PartOffers.bucket_of(id, Parts.row) == "movement" else "still"] += w
		elif id in PartOffers.NEUTRAL_SHELF:
			mass["shelf"] += w
		else:
			mass["rest"] += w
	return mass


func _check_rest_weights() -> void:
	Synergies.set_table(AlphaDefs)
	for pilot in PILOTS:
		for rarity in ["common", "rare"]:
			var pool: Array = Parts.offer_pool(pilot, [rarity])
			var slot: Dictionary = PartOffers.slot_weights(rarity, pilot, pool, {}, {}, Parts.offer_ops())
			var weights: Dictionary = slot["weights"]
			var total := 0.0
			var zero_items: Array = []
			for id in pool:
				var w := float(weights.get(id, 0.0))
				total += w
				if w <= 0.0:
					zero_items.append(id)
			_t.near("%s %s slot weights sum to 1.0" % [pilot, rarity], total, 1.0, 0.0001)
			_t.eq("%s %s every admitted pool item has strictly positive weight" % [pilot, rarity], zero_items, [])
		var common_pool: Array = Parts.offer_pool(pilot, ["common"])
		var common_slot: Dictionary = PartOffers.slot_weights("common", pilot, common_pool, {}, {}, Parts.offer_ops())
		var weights: Dictionary = common_slot["weights"]
		var mass := _group_mass(pilot, weights)
		var expected_rest: float = (1.0 - PartOffers.KIT_SHARE) * PartOffers.REST_OF_NEUTRAL
		_t.near("%s common kit mass holds KIT_SHARE (0.70)" % pilot, mass["kit"], PartOffers.KIT_SHARE, 0.0001)
		_t.near("%s common rest mass holds (1 - KIT_SHARE) * REST_OF_NEUTRAL" % pilot, mass["rest"], expected_rest, 0.0001)
		for id in OFF_KIT_SIX:
			var w := float(weights.get(id, 0.0))
			_t.check("%s draws %s with weight > 0" % [pilot, id], w > 0.0, "%.6f" % w)
	# Live draw check + 1-slot RNG budget + computed control: over 1200 seeded gate (2-slot) and
	# single-slot (fabricator/pocket) draws for runner_gunner, off-kit items land in rolled picks,
	# and a 1-slot listed roll spends exactly two rng draws (rarity + pick) even when picking rest.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4505
	var gate_hits := 0
	for _i in 1200:
		var picks: Array = Parts.roll(rng, ["common"], "runner_gunner", [], 2)
		for id in picks:
			if id in OFF_KIT_SIX:
				gate_hits += 1
	_t.check("live gate roll draws off-kit items for runner_gunner", gate_hits > 0, "%d hits in 1200 gate draws" % gate_hits)
	var single_rng := RandomNumberGenerator.new()
	single_rng.seed = 4506
	var oracle_rng := RandomNumberGenerator.new()
	oracle_rng.seed = 4506
	var single_hits := 0
	var rng_mismatches := 0
	for _i in 1200:
		oracle_rng.randf()
		oracle_rng.randf()
		var picks: Array = Parts.roll(single_rng, ["common", "rare"], "runner_gunner", [], 1)
		if single_rng.state != oracle_rng.state:
			rng_mismatches += 1
		if not picks.is_empty() and picks[0] in OFF_KIT_SIX:
			single_hits += 1
	_t.check("live 1-slot roll draws off-kit items for runner_gunner", single_hits > 0, "%d hits in 1200 1-slot draws" % single_hits)
	_t.eq("1-slot listed roll spends exactly 2 rng draws (no extra _keep_a_neutral draw)", rng_mismatches, 0)
	var full_pool: Array = Parts.offer_pool("runner_gunner", ["common"])
	var no_rest_pool: Array = full_pool.filter(func(id): return Parts.in_kit("runner_gunner", id) or id in PartOffers.NEUTRAL_SHELF)
	var with_rest := _group_mass("runner_gunner", PartOffers.slot_weights("common", "runner_gunner", full_pool, {}, {}, Parts.offer_ops())["weights"])
	var without_rest := _group_mass("runner_gunner", PartOffers.slot_weights("common", "runner_gunner", no_rest_pool, {}, {}, Parts.offer_ops())["weights"])
	_t.near("planted control: removing rest shifts rest mass to shelf and keeps kit at 0.70",
		without_rest["shelf"] - with_rest["shelf"], with_rest["rest"], 0.0001)
	_t.near("planted control: without rest group, rest mass is exactly 0.0", without_rest["rest"], 0.0, 0.000001)
	_t.near("planted control: kit mass stays 0.70 with or without rest", without_rest["kit"], PartOffers.KIT_SHARE, 0.0001)
	Synergies.set_table(null)


func _check_slot_weight_invariants() -> void:
	Synergies.set_table(AlphaDefs)
	var pilot := "runner_gunner"
	var pool: Array = Parts.offer_pool(pilot, ["common"])
	var moving_ids: Array = pool.filter(func(id): return Parts.in_kit(pilot, id) and PartOffers.bucket_of(id, Parts.row) == "movement")
	var still_ids: Array = pool.filter(func(id): return Parts.in_kit(pilot, id) and PartOffers.bucket_of(id, Parts.row) != "movement")
	var shelf_ids: Array = pool.filter(func(id): return not Parts.in_kit(pilot, id) and id in PartOffers.NEUTRAL_SHELF)
	var rest_ids: Array = pool.filter(func(id): return not Parts.in_kit(pilot, id) and not id in PartOffers.NEUTRAL_SHELF)
	_t.check("precondition: runner_gunner common pool populates all four groups",
		not moving_ids.is_empty() and still_ids.size() >= 3 and not shelf_ids.is_empty() and not rest_ids.is_empty())

	# 1. Empty moving: still absorbs moving, kit stays 0.70, rest keeps its slice.
	var no_moving: Dictionary = PartOffers.slot_weights("common", pilot, still_ids + shelf_ids + rest_ids, {}, {}, Parts.offer_ops())["weights"]
	var m_no_moving := _group_mass(pilot, no_moving)
	_t.near("empty moving: still absorbs moving to KIT_SHARE", m_no_moving["still"], PartOffers.KIT_SHARE, 0.0001)
	_t.near("empty moving: rest keeps its slice", m_no_moving["rest"], (1.0 - PartOffers.KIT_SHARE) * PartOffers.REST_OF_NEUTRAL, 0.0001)

	# 2. Empty still with shelf + rest: shelf absorbs still (and moving stays at MOVEMENT_SHARE).
	var no_still: Dictionary = PartOffers.slot_weights("common", pilot, moving_ids + shelf_ids + rest_ids, {}, {}, Parts.offer_ops())["weights"]
	var m_no_still := _group_mass(pilot, no_still)
	_t.near("empty still (with shelf): moving stays capped at MOVEMENT_SHARE", m_no_still["moving"], PartOffers.MOVEMENT_SHARE, 0.0001)
	_t.near("empty still (with shelf): rest keeps its slice", m_no_still["rest"], (1.0 - PartOffers.KIT_SHARE) * PartOffers.REST_OF_NEUTRAL, 0.0001)
	_t.near("empty still (with shelf): total sums to 1.0", m_no_still["kit"] + m_no_still["shelf"] + m_no_still["rest"], 1.0, 0.0001)

	# 3. Empty still AND empty shelf, non-empty rest: rest absorbs everything except moving.
	var only_moving_rest: Dictionary = PartOffers.slot_weights("common", pilot, moving_ids + rest_ids, {}, {}, Parts.offer_ops())["weights"]
	var m_mr := _group_mass(pilot, only_moving_rest)
	_t.near("empty still+shelf: moving keeps MOVEMENT_SHARE", m_mr["moving"], PartOffers.MOVEMENT_SHARE, 0.0001)
	_t.near("empty still+shelf: rest absorbs remaining 1 - MOVEMENT_SHARE", m_mr["rest"], 1.0 - PartOffers.MOVEMENT_SHARE, 0.0001)

	# 4. Empty shelf with non-empty still + rest (rare-like shape): still absorbs shelf, rest keeps rest_share.
	var no_shelf: Dictionary = PartOffers.slot_weights("common", pilot, moving_ids + still_ids + rest_ids, {}, {}, Parts.offer_ops())["weights"]
	var m_ns := _group_mass(pilot, no_shelf)
	var rest_slice: float = (1.0 - PartOffers.KIT_SHARE) * PartOffers.REST_OF_NEUTRAL
	_t.near("empty shelf (uncapped still): kit absorbs shelf to 1 - rest_slice", m_ns["kit"], 1.0 - rest_slice, 0.0001)
	_t.near("empty shelf (uncapped still): rest keeps rest_slice", m_ns["rest"], rest_slice, 0.0001)

	# 5. Only moving non-empty: moving absorbs all share and each item caps at KIT_PART_CAP.
	var only_moving: Dictionary = PartOffers.slot_weights("common", pilot, moving_ids, {}, {}, Parts.offer_ops())["weights"]
	var want_moving_mass := minf(1.0, moving_ids.size() * PartOffers.KIT_PART_CAP)
	_t.near("only moving non-empty: moving absorbs share up to KIT_PART_CAP per item",
		_group_mass(pilot, only_moving)["moving"], want_moving_mass, 0.0001)

	# 6. Empty pool: returns empty candidates and weights.
	_t.eq("empty pool returns empty slot", PartOffers.slot_weights("common", pilot, [], {}, {}, Parts.offer_ops()), {"candidates": [], "weights": {}})

	# 7. KIT_PART_CAP overflow: a 1-item still kit caps at KIT_PART_CAP and spills excess to shelf.
	var capped_still: Dictionary = PartOffers.slot_weights("common", pilot, [still_ids[0]] + shelf_ids + rest_ids, {}, {}, Parts.offer_ops())["weights"]
	_t.near("1-item still kit is clamped to KIT_PART_CAP", float(capped_still[still_ids[0]]), PartOffers.KIT_PART_CAP, 0.0001)
	_t.near("cap overflow flows to shelf before rest", _group_mass(pilot, capped_still)["rest"], rest_slice, 0.0001)

	# 8. Repeat cap behavior: a shelf item at NEUTRAL_REPEAT_CAP is excluded; a rest item is only dampened.
	var offered := {}
	offered[shelf_ids[0]] = PartOffers.NEUTRAL_REPEAT_CAP
	offered[rest_ids[0]] = PartOffers.NEUTRAL_REPEAT_CAP
	var capped_slot: Dictionary = PartOffers.slot_weights("common", pilot, pool, offered, {}, Parts.offer_ops())["weights"]
	_t.check("shelf item at NEUTRAL_REPEAT_CAP is excluded from candidates", not capped_slot.has(shelf_ids[0]))
	_t.check("rest item at NEUTRAL_REPEAT_CAP remains drawable with dampened weight",
		capped_slot.has(rest_ids[0]) and float(capped_slot[rest_ids[0]]) > 0.0
		and float(capped_slot[rest_ids[0]]) < float(capped_slot[rest_ids[1]]))
	# Capping every shelf item empties shelf cleanly; total stays 1.0 and rest stays positive.
	var all_shelf_capped := {}
	for id in shelf_ids:
		all_shelf_capped[id] = PartOffers.NEUTRAL_REPEAT_CAP
	var shelf_gone: Dictionary = PartOffers.slot_weights("common", pilot, pool, all_shelf_capped, {}, Parts.offer_ops())["weights"]
	var m_sg := _group_mass(pilot, shelf_gone)
	_t.near("all shelf items at repeat cap: shelf mass is 0.0", m_sg["shelf"], 0.0, 0.000001)
	_t.near("all shelf items at repeat cap: total mass stays 1.0", m_sg["kit"] + m_sg["rest"], 1.0, 0.0001)
	_t.check("all shelf items at repeat cap: rest remains positive", m_sg["rest"] > 0.0, "%.4f" % m_sg["rest"])
	Synergies.set_table(null)


func _check_rivet_weapon_ease_scoping() -> void:
	Synergies.set_table(AlphaDefs)
	# On Rivet's common slot (shelf present): NEUTRAL_WEAPON_EASE eases off-kit weapon items so
	# Rivet's declared movement + skill pair stays ahead of weapon.
	var c_pool: Array = Parts.offer_pool("runner_gunner", ["common"])
	var c_weights: Dictionary = PartOffers.slot_weights("common", "runner_gunner", c_pool, {}, {}, Parts.offer_ops())["weights"]
	var shelf_weapon := float(c_weights["hot_rivets"])
	var shelf_defence := float(c_weights["rivet_plating"])
	_t.near("Rivet common shelf weapon is eased by NEUTRAL_WEAPON_EASE vs shelf defence",
		shelf_weapon / shelf_defence, PartOffers.NEUTRAL_WEAPON_EASE, 0.0001)
	var rest_weapon := float(c_weights["focus_lens"])
	var rest_skill := float(c_weights["second_bell"])
	_t.near("Rivet common rest weapon is eased by NEUTRAL_WEAPON_EASE while shelf is non-empty",
		rest_weapon / rest_skill, PartOffers.NEUTRAL_WEAPON_EASE, 0.0001)

	# On Rivet's rare slot (shelf empty, rest receives KIT_PART_CAP overflow): NEUTRAL_WEAPON_EASE
	# does NOT apply to rest, so rare weapon parts keep equal per-item weight with non-weapon rare
	# rest parts and Rivet's rare weapon share is never crushed down to ~7%.
	var r_pool: Array = Parts.offer_pool("runner_gunner", ["rare"])
	var r_weights: Dictionary = PartOffers.slot_weights("rare", "runner_gunner", r_pool, {}, {}, Parts.offer_ops())["weights"]
	var rare_weapon_rest := float(r_weights["sunforged_core"])
	var rare_skill_rest := float(r_weights["spare_cell"])
	_t.near("Rivet rare rest weapon equals rare rest non-weapon weight (no ease on cap overflow)",
		rare_weapon_rest, rare_skill_rest, 0.000001)
	var rare_weapon_total := 0.0
	for id in r_weights:
		if PartOffers.bucket_of(id, Parts.row) == "weapon":
			rare_weapon_total += float(r_weights[id])
	_t.check("Rivet rare weapon share stays above 25% (not crushed to ~7% by ease)",
		rare_weapon_total > 0.25, "%.3f" % rare_weapon_total)
	Synergies.set_table(null)


func _check_challenge_dials_w23() -> void:
	ChallengeDials.reset()
	# World 1 stages 1-2 values stay exact to the thousandth.
	var w1_pins := {
		"pilot.regen_rolling_by_stage": [1.0, 1.0],
		"hazard.shell_cover_by_stage": [1.0, 1.0],
		"mobs.lobber_lead_by_stage": [0.75, 0.75],
		"mobs.chaser_speed_by_stage": [9.0, 9.0],
		"pack.lead_by_stage": [0.7, 0.5],
		"pack.lead_cruise_by_stage": [0.0, 0.0],
		"hazard.boil_stall_by_stage": [1.0, 1.0],
		"mobs.damage_by_stage": [2.6, 2.5],
		"warden.pulse_damage_by_stage": [4.0, 4.5],
		"warden.pulse_cycle_by_stage": [1.0, 0.85],
		"warden.pulse_ratchet_by_stage": [1.0, 0.9],
		"mobs.interval_scale_by_stage": [1.0, 0.7],
		"mobs.clock_tiers_by_stage": [3.0, 3.0],
		"hazard.boil_by_stage": [2.0, 2.0],
		"hazard.hits_enemies_by_stage": [1.0, 1.0],
	}
	for key in w1_pins:
		var arr: Array = ChallengeDials.value(key)
		var want: Array = w1_pins[key]
		_t.near("W1 stage 1 pin %s" % key, float(arr[0]), float(want[0]), 0.0001)
		_t.near("W1 stage 2 pin %s" % key, float(arr[1]), float(want[1]), 0.0001)
	# Stages 3-6 inherit the stage 2 ruling-cu baseline (never regressing below stage 2).
	var inherited := [
		"pilot.regen_rolling_by_stage",
		"hazard.shell_cover_by_stage",
		"mobs.lobber_lead_by_stage",
		"mobs.chaser_speed_by_stage",
		"pack.lead_by_stage",
		"pack.lead_cruise_by_stage",
		"hazard.boil_stall_by_stage",
	]
	for key in inherited:
		var arr: Array = ChallengeDials.value(key)
		for stage in range(3, 7):
			_t.near("%s stage %d inherits stage 2 baseline" % [key, stage], float(arr[stage - 1]), float(arr[1]), 0.0001)
	# Live consumers on stages 3-6 read the inherited ruling-cu rules.
	var run := RunState.new()
	for stage in range(3, 7):
		run.stage = stage
		_t.check("stage %d RunState.regen_needs_roll() stays true" % stage, run.regen_needs_roll())
		_t.near("stage %d Chaser.stage_speed stays 9.0" % stage, Chaser.stage_speed(stage), 9.0, 0.0001)
		var crew := PackPressure.crew_row(stage)
		_t.near("stage %d PackPressure lead stays 0.5" % stage, float(crew["lead"]), 0.5, 0.0001)
		_t.near("stage %d PackPressure lead_cruise stays 0.0" % stage, float(crew["lead_cruise"]), 0.0, 0.0001)
	# Planted control: restoring the old W1-only [1, 1, 0, 0, 0, 0] flips stage 3 back to stationary healing.
	ChallengeDials.set_overrides({"pilot.regen_rolling_by_stage": [1.0, 1.0, 0.0, 0.0, 0.0, 0.0]})
	run.stage = 3
	_t.check("planted control: W1-only regen array drops stage 3 back to stationary healing", not run.regen_needs_roll())
	ChallengeDials.reset()


func _check_boss_immunity_and_panels() -> void:
	_t.check("Elements.BOSS_KINDS includes waking", "waking" in Elements.BOSS_KINDS)
	_t.check("Elements.BOSS_KINDS includes mind", "mind" in Elements.BOSS_KINDS)
	_t.check("Elements.elite_rules('waking', false) is true", Elements.elite_rules("waking", false))
	_t.check("Elements.elite_rules('mind', false) is true", Elements.elite_rules("mind", false))
	_t.check("Elements.elite_rules('brindle', false) stays true", Elements.elite_rules("brindle", false))
	# Planted control: a regular mob with elite=false is not immune, while elite=true is.
	_t.check("planted control: Elements.elite_rules('chaser', false) is false", not Elements.elite_rules("chaser", false))
	_t.check("planted control: Elements.elite_rules('chaser', true) is true", Elements.elite_rules("chaser", true))
	# Panels multi-world safety through Dropper.chance() and Panels.drop_row().
	var dropper = Panels.Dropper.new()
	dropper.world = 1
	_t.near("Dropper world 1 base chance untouched", dropper.chance(false, 1.0, false), 0.32, 0.00001)
	dropper.dry = 1
	_t.near("Dropper world 1 pity untouched", dropper.chance(false, 1.0, false), 0.38, 0.00001)
	for w in [2, 3, 99]:
		dropper.world = w
		dropper.dry = 0
		_t.near("Dropper world %d base chance matches drop_row()" % w,
			dropper.chance(false, 1.0, false), float(Panels.drop_row(w)["chance"]), 0.00001)
		dropper.dry = 1
		_t.near("Dropper world %d pity matches drop_row()" % w,
			dropper.chance(false, 1.0, false), float(Panels.drop_row(w)["chance"]) + float(Panels.drop_row(w)["pity"]), 0.00001)
	_t.check("Panels.DROP_BY_WORLD has explicit rows for worlds 2 and 3",
		Panels.DROP_BY_WORLD.has(2) and Panels.DROP_BY_WORLD.has(3))
	_t.eq("Panels.drop_row(99) falls back to DROP", Panels.drop_row(99), Panels.DROP)
	_t.check("Panels.NO_DROP_KINDS excludes waking and mind",
		"waking" in Panels.NO_DROP_KINDS and "mind" in Panels.NO_DROP_KINDS)
