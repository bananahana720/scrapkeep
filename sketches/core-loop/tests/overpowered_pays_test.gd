extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")

# Overpowered pays (Andrew, 17 Oct 2026): a strong build or a lucky run is never punished.
#   - A linear or capped part held at its stack cap adds nothing more, so no roll offers it again,
#     on any pilot's full catalogue; a hyperbolic or uncapped part is never called maxed.
#   - A bigger hit draws a bigger damage number, up to MEGA_FONT; small hits keep the old sizes.
# Evidence limit: the rules only. How much faster a strong pilot grows is the bot gate's to
# measure, and how it feels is Andrew's.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const DRAWS := 300

var _t := preload("res://tests/support/t.gd").new("overpowered_pays_test")


func _initialize() -> void:
	Synergies.set_table(null)
	_maxed_parts()
	_numbers()
	_ceiling()
	quit(_t.verdict())


# The pilot's most-offered linear or capped part, so the maxed check has something to remove.
func _capped_part(pilot: String) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 400
	var seen := {}
	for i in DRAWS:
		for key in Parts.roll(rng, ["common", "rare", "relic"], pilot, [], 3):
			var d: Resource = Parts.def(key)
			if d != null and d.stack_rule in ["linear", "capped"] and d.stack_cap >= 1.0:
				seen[key] = int(seen.get(key, 0)) + 1
	var best := ""
	for key in seen:
		if best == "" or seen[key] > seen[best]:
			best = key
	return best


func _maxed_parts() -> void:
	var tested := 0
	for pilot in PILOTS:
		var part := _capped_part(pilot)
		if part == "":
			continue
		tested += 1
		var cap := int(Parts.def(part).stack_cap)
		var held: Array = []
		for i in cap - 1:
			held.append(part)
		_t.check("%s %s under its cap is not stacked out" % [pilot, part], not Parts.stacked_out(part, held), "%d of %d" % [held.size(), cap])
		var before := 0
		var probe := RandomNumberGenerator.new()
		probe.seed = 900 + tested
		for i in DRAWS:
			before += Parts.roll(probe, ["common", "rare", "relic"], pilot, held, 3).count(part)
		_t.check("%s still draws %s under its cap" % [pilot, part], before > 0, str(before))
		held.append(part)
		_t.check("%s %s at its cap is stacked out" % [pilot, part], Parts.stacked_out(part, held), "%d of %d" % [held.size(), cap])
		var rng := RandomNumberGenerator.new()
		rng.seed = 1700 + tested
		var offered := 0
		for i in DRAWS:
			var picks: Array = Parts.roll(rng, ["common", "rare", "relic"], pilot, held, 3)
			offered += picks.count(part)
		_t.eq("%s never draws its stacked-out %s" % [pilot, part], offered, 0)
	_t.check("some pilot has a capped part to test", tested > 0, str(tested))
	_harder_kept()
	var hyperbolic := ""
	for key in Parts.ids():
		var d: Resource = Parts.def(key)
		if d != null and d.stack_rule == "hyperbolic":
			hyperbolic = key
			break
	if hyperbolic != "":
		_t.check("a hyperbolic part is never stacked out", not Parts.stacked_out(hyperbolic, [hyperbolic, hyperbolic, hyperbolic, hyperbolic, hyperbolic]), hyperbolic)
	_t.check("an unknown part is never stacked out", not Parts.stacked_out("no_such_part", ["no_such_part"]), "")


func _numbers() -> void:
	_t.eq("a small hit keeps the old size", DamageNumbers.font_size(12.0), DamageNumbers.FONT)
	_t.eq("a small crit keeps the old size", DamageNumbers.font_size(12.0, true), DamageNumbers.CRIT_FONT)
	var last := 0
	var grows := true
	for value in [40.0, 80.0, 160.0, 320.0, 640.0]:
		var size := DamageNumbers.font_size(value)
		grows = grows and size > last
		last = size
	_t.check("each doubling past BIG_FROM draws bigger", grows, str(last))
	_t.eq("the biggest hit stops at MEGA_FONT", DamageNumbers.font_size(1.0e9, true), DamageNumbers.MEGA_FONT)


# A stacked-out harder hitter swaps for a harder hitter, so every pair still holds one.
func _harder_kept() -> void:
	for pilot in PILOTS:
		var held: Array = []
		for key in Parts.offer_pool(pilot, ["common", "rare", "relic"]):
			var d: Resource = Parts.def(key)
			if d != null and d.hits_harder() and d.levels.is_empty() and d.stack_rule in ["linear", "capped"] and d.stack_cap >= 1.0:
				for i in int(d.stack_cap):
					held.append(key)
		var rng := RandomNumberGenerator.new()
		rng.seed = 2600
		var pairs := 0
		var missing := 0
		for i in DRAWS:
			var picks: Array = Parts.roll(rng, ["common", "rare", "relic"], pilot, held, 2)
			if picks.size() < 2:
				continue
			pairs += 1
			if not picks.any(func(key): return Parts.def(key).hits_harder()):
				missing += 1
		_t.check("%s pairs keep a harder hitter with its capped hitters stacked out" % pilot, pairs > 0 and missing == 0, "%d of %d pairs without one" % [missing, pairs])


# monster: judged as a monster build; else as the fail-closed default (a rule never told).
func _gain(numbers: Dictionary, ratio: float, monster := false, frame := 1) -> float:
	var rule = BossPosture.new(numbers)
	if monster:
		rule.set_monster(true)
	return float(rule.judge({"kind": "ram", "punch": ratio * 100.0, "plating": 100.0, "frame": frame})["gain"])


# Andrew's tap "Lift the ceiling" (17 Oct 22:04Z) under coordinator ruling (B) on #222 (21 Oct):
# a monster build (heft strictly above the fight's library top-bucket maximum) counts a hit up to 3x
# its plating; an ordinary ram, or a rule never told a class, keeps 1.5; the hull bosses keep 1.5.
func _ceiling() -> void:
	var row := {"curve": 2.0}
	_t.check("a Warden ram at 1.0x plating gains as before", is_equal_approx(_gain(row, 1.0), 30.0), str(_gain(row, 1.0)))
	var flat := {"curve": 1.0}
	_t.check("a monster ram at 3x plating gains twice a 1.5x ram", is_equal_approx(_gain(flat, 3.0, true), 2.0 * _gain(flat, 1.5, true)), "%.1f vs %.1f" % [_gain(flat, 3.0, true), _gain(flat, 1.5, true)])
	_t.check("a rule never told a class fails closed at 1.5", is_equal_approx(_gain(flat, 3.0), _gain(flat, 1.5)) and BossPosture.new(flat).mult_max == 1.5, str(BossPosture.new(flat).mult_max))
	var hull: Dictionary = BossRules.POSTURE
	_t.check("a hull boss still stops counting at 1.5x", is_equal_approx(_gain(hull, 3.0, true), _gain(hull, 1.5, true)), "%.1f" % _gain(hull, 3.0, true))
	var capped := {"curve": 2.0, "hit_cap": 20.0, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55}
	_t.check("hit_cap holds an ordinary amplified ram", _gain(capped, 0.9) <= 20.0001, "%.1f" % _gain(capped, 0.9))
	_t.check("hit_cap holds an ordinary pilot's big ram", _gain(capped, 3.0) < BossPosture.FULL, "%.1f" % _gain(capped, 3.0))
	_t.check("hit_cap opens for a monster ram", _gain(capped, 3.0, true) >= BossPosture.FULL - 0.001, "%.1f" % _gain(capped, 3.0, true))
	_t.check("hit_cap climbs between", _gain(capped, 2.25, true) > 20.0 and _gain(capped, 2.25, true) < BossPosture.FULL, "%.1f" % _gain(capped, 2.25, true))
	var first := BossPosture.new({"curve": 2.0, "hit_cap": 15.0, "hit_cap_until_stagger": true, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55})
	var ram := {"kind": "ram", "punch": 90.0, "plating": 100.0, "frame": 1}
	_t.check("hit_cap_until_stagger holds before the first stagger", float(first.judge(ram)["gain"]) <= 15.0001, "%.1f" % float(first.judge(ram)["gain"]))
	first.staggers = 1
	_t.check("hit_cap_until_stagger lets go after it", float(first.judge(ram)["gain"]) > 15.0, "%.1f" % float(first.judge(ram)["gain"]))
	_t.eq("the ultimate fills up to 70 on a closed guard for a monster", preload("res://src/combat/ultimate.gd").WARDEN_POSTURE_CAP, 70.0)
	_pilot_class()


# Ruling (B): the lift needs a heft strictly above the fight's threshold.
func _pilot_class() -> void:
	var Ult := preload("res://src/combat/ultimate.gd")
	var flat := {"curve": 1.0}
	for on in [true, false]:
		var rule := BossPosture.new(flat)
		rule.set_monster(on)
		var gain := float(rule.judge({"kind": "ram", "punch": 250.0, "plating": 100.0, "frame": 1})["gain"])
		var want := _gain(flat, 2.5, true) if on else _gain(flat, 1.5)
		_t.check("set_monster(%s) %s" % [on, "lifts" if on else "holds 1.5"], is_equal_approx(gain, want) and (rule.mult_max == 3.0) == on, "%.1f mult_max %.1f" % [gain, rule.mult_max])
	var monster := BossPosture.new(flat)
	monster.set_monster(true)
	_t.check("a monster hit tops out at 3x", is_equal_approx(float(monster.judge({"kind": "ram", "punch": 500.0, "plating": 100.0, "frame": 2})["gain"]), _gain(flat, 3.0, true)), "")
	monster.set_monster(false)
	_t.check("a pilot back under the threshold loses the lift on the next hit", monster.mult_max == 1.5, str(monster.mult_max))
	var hull := BossPosture.new(BossRules.POSTURE)
	hull.set_monster(true)
	_t.check("a hull boss stays at 1.5 for a monster", hull.mult_max == 1.5 and hull.ordinary_ceiling() == 1.5, str(hull.mult_max))
	var waking := BossPosture.new({"curve": 2.0, "hit_cap": 20.0, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55})
	waking.set_monster(true)
	_t.check("a monster build lifts mult_max over a hit_cap row", waking.mult_max == 3.0, str(waking.mult_max))
	_t.eq("the set piece cap is 70 for a monster build", Ult.warden_cap(true), 70.0)
	_t.eq("the set piece cap is 45 for anyone else", Ult.warden_cap(false), 45.0)
	_warden_class_source()


# A fleet-less Warden with no heft or threshold is no monster; a spec heft above its threshold flips it.
func _warden_class_source() -> void:
	var Warden := preload("res://src/combat/warden.gd")
	var Ult := preload("res://src/combat/ultimate.gd")
	var MonsterHeft := preload("res://src/combat/monster_heft.gd")
	var bare = Warden.new()
	_t.eq("a fleet-less Warden with no heft source reads heft 0", bare.pilot_heft(), 0.0)
	_t.check("a Warden with no stage or threshold has an infinite threshold", is_inf(bare.monster_threshold()), str(bare.monster_threshold()))
	_t.check("a Warden with no heft source or threshold is no monster", not bare.monster_build(), "")
	_t.eq("it gets the ordinary cap", Ult.cap_for_warden(bare), 45.0)
	bare.spec = {"heft": func() -> float: return 99.0}
	_t.check("a huge heft against no threshold is still no monster (fails closed)", not bare.monster_build(), "")
	bare.spec = {"heft": func() -> float: return 5.0, "monster_heft": 4.0}
	_t.check("spec heft above spec monster_heft is a monster build", bare.monster_build(), "")
	_t.eq("a monster build gets 70", Ult.cap_for_warden(bare), 70.0)
	bare.spec = {"heft": func() -> float: return 4.0, "monster_heft": 4.0}
	_t.check("heft equal to the threshold is not strictly above it", not bare.monster_build(), "")
	bare.spec = {"heft": func() -> float: return 3.0, "monster_heft": 4.0}
	_t.check("spec heft below spec monster_heft is no monster", not bare.monster_build(), "")
	bare.spec = {"stage": 4}
	_t.eq("a spec stage reads that stage's library threshold", bare.monster_threshold(), MonsterHeft.threshold_for_stage(4))
	_t.check("a missing stage threshold is infinite", is_inf(MonsterHeft.threshold_for_stage(99)), "")
	bare.free()
	var Waking := preload("res://src/boss/waking.gd")
	var Mind := preload("res://src/boss/mind.gd")
	for script in [Waking, Mind]:
		_t.check("%s sets monster_heft from the loader" % script.resource_path.get_file(), script.source_code.contains('spec["monster_heft"] = MonsterHeft.'), "")
	_t.eq("the Waking spec takes the s4 entrance", MonsterHeft.waking_threshold(), MonsterHeft.threshold_for_stage(3))
	_t.eq("the Mind spec takes the s6 entrance", MonsterHeft.mind_threshold(), MonsterHeft.threshold_for_stage(5))
