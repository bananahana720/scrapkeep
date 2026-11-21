extends SceneTree

# Wave 45 Unit P5: World 1 + Worlds 2/3 scalability hardening checks.
# Verifies:
#   1. Parts.slot_weights() gives strictly > 0.0 draw weight to every admitted World 1 common/uncommon
#      and rare item (especially off-kit items: backwash, second_bell, long_leash, focus_lens,
#      live_line, tracer_round) while keeping KIT_SHARE intact; planted control zeroes rest share.
#   2. Fabricators.OFF_SHELF shares the 1.06 growth curve with Moss's shelf so late-run (parts_held=30)
#      off-shelf prices stay <= Moss's shelf across tiers 1-3; planted control checks 1.15^30 blowout.
#   3. ChallengeDials stages 3-6 inherit the stage 2 ruling-cu baseline (rolling regen, shell cover,
#      lobber lead, chaser speed, pack lead + cruise fade, boil stall) without altering stages 1-2;
#      planted control restores [1,1,0,0,0,0] and confirms stage 3 regresses to stationary healing.
#   4. Elements.BOSS_KINDS and elite_rules cover W2/W3 bosses ("waking", "mind") while regular mobs
#      stay false (planted control); Panels.DROP_BY_WORLD and NO_DROP_KINDS handle worlds 1-3 cleanly.

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Fabricators := preload("res://src/build/fabricators.gd")
const Elements := preload("res://src/build/elements.gd")
const Panels := preload("res://src/build/panels.gd")
const RunState := preload("res://src/core/run_state.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const PackPressure := preload("res://src/combat/pack_pressure.gd")
const T := preload("res://tests/support/t.gd")

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const OFF_KIT_SIX := ["backwash", "second_bell", "long_leash", "focus_lens", "live_line", "tracer_round"]
const TIER_SAMPLES := {1: "hot_rivets", 2: "slag_rounds", 3: "sunforged_core"}

var _t := T.new("w45_w23_scalability_test")


func _initialize() -> void:
	ChallengeDials.reset()
	_check_rest_weights()
	_check_off_shelf_pricing()
	_check_challenge_dials_w23()
	_check_boss_immunity_and_panels()
	ChallengeDials.reset()
	Synergies.table = null
	quit(_t.verdict())


func _check_rest_weights() -> void:
	Synergies.table = AlphaDefs
	_t.check("REST_OF_NEUTRAL is strictly between 0 and 1",
		Parts.REST_OF_NEUTRAL > 0.0 and Parts.REST_OF_NEUTRAL < 1.0, str(Parts.REST_OF_NEUTRAL))
	for pilot in PILOTS:
		for rarity in ["common", "rare"]:
			var pool: Array = Parts.offer_pool(pilot, [rarity])
			var slot: Dictionary = Parts.slot_weights(rarity, pilot, pool, {}, {})
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
		var common_slot: Dictionary = Parts.slot_weights("common", pilot, common_pool, {}, {})
		for id in OFF_KIT_SIX:
			var w := float(common_slot["weights"].get(id, 0.0))
			_t.check("%s draws %s with weight > 0" % [pilot, id], w > 0.0, "%.6f" % w)
	# Planted control: with rest share forced to 0.0 (the pre-P5 bug), all six off-kit items
	# sit in the rest group for every pilot and drop to exactly 0.0 draw weight.
	var dead_under_zero_rest := 0
	for pilot in PILOTS:
		var common_pool: Array = Parts.offer_pool(pilot, ["common"])
		for id in OFF_KIT_SIX:
			var in_rest: bool = id in common_pool and not Parts.in_kit(pilot, id) and not id in Parts.NEUTRAL_SHELF
			if in_rest:
				dead_under_zero_rest += 1
	_t.eq("planted control: zero rest share kills all 6 off-kit items across all 6 pilots",
		dead_under_zero_rest, OFF_KIT_SIX.size() * PILOTS.size())
	Synergies.table = null


func _check_off_shelf_pricing() -> void:
	_t.near("OFF_SHELF shares Moss shelf growth exponent (1.06)",
		float(Fabricators.OFF_SHELF["part_growth"]), float(Fabricators.COG_PRICES["part_growth"]), 0.000001)
	_t.eq("early World 1 (0 parts held) off-shelf prices stay 10/16/26",
		[Fabricators.off_shelf_price(1, 0), Fabricators.off_shelf_price(2, 0), Fabricators.off_shelf_price(3, 0)],
		[10, 16, 26])
	for tier in [1, 2, 3]:
		var sample_id: String = TIER_SAMPLES[tier]
		for held in [0, 10, 25, 30]:
			var off_p := Fabricators.off_shelf_price(tier, held)
			var shelf_p := Fabricators.price(sample_id, held)
			_t.check("tier %d at %d parts held: off-shelf (%d) <= Moss shelf (%d)" % [tier, held, off_p, shelf_p],
				off_p <= shelf_p and off_p > 0, "%d vs %d" % [off_p, shelf_p])
		# Planted control: the old 1.15^30 curve blows past Moss's shelf by > 2x at 30 held parts.
		var shelf_30 := Fabricators.price(sample_id, 30)
		var old_30 := int(round(float(Fabricators.OFF_SHELF["part_base"]) * float(Fabricators.COG_PRICES["part_tier"][tier]) * pow(1.15, 30)))
		_t.check("planted control: tier %d old 1.15^30 (%d) exceeds 2x Moss shelf (%d)" % [tier, old_30, shelf_30],
			float(old_30) > float(shelf_30) * 2.0, "ratio %.2fx" % (float(old_30) / float(shelf_30)))


func _check_challenge_dials_w23() -> void:
	ChallengeDials.reset()
	# World 1 stages 1-2 values stay exact to the thousandth.
	var w1_pins := {
		"pilot.regen_rolling_by_stage": [1.0, 1.0],
		"hazard.shell_cover_by_stage": [1.0, 1.0],
		"mobs.lobber_lead_by_stage": [0.75, 0.75],
		"mobs.chaser_speed_by_stage": [9.0, 9.0],
		"pack.lead_by_stage": [0.5, 0.5],
		"pack.lead_cruise_by_stage": [0.0, 0.0],
		"hazard.boil_stall_by_stage": [1.0, 1.0],
		"mobs.damage_by_stage": [2.0, 1.0],
		"warden.pulse_damage_by_stage": [1.3, 1.3],
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
	# Panels multi-world safety: W1 exact, W2 and W3 explicit valid rows, unknown world falls back to DROP.
	_t.near("Panels world 1 chance untouched", float(Panels.drop_row(1)["chance"]), 0.32, 0.00001)
	_t.near("Panels world 1 pity untouched", float(Panels.drop_row(1)["pity"]), 0.06, 0.00001)
	for w in [2, 3]:
		_t.check("Panels.DROP_BY_WORLD has explicit row for world %d" % w, Panels.DROP_BY_WORLD.has(w))
		var r := Panels.drop_row(w)
		_t.near("Panels world %d chance matches card row" % w, float(r["chance"]), float(Panels.DROP["chance"]), 0.00001)
		_t.near("Panels world %d pity matches card row" % w, float(r["pity"]), float(Panels.DROP["pity"]), 0.00001)
	_t.eq("Panels.drop_row(99) falls back to DROP", Panels.drop_row(99), Panels.DROP)
	_t.check("Panels.NO_DROP_KINDS excludes waking and mind",
		"waking" in Panels.NO_DROP_KINDS and "mind" in Panels.NO_DROP_KINDS)
