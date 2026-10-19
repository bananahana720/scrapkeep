extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const BossRules := preload("res://src/boss/boss_rules.gd")
const StubBoss := preload("res://src/boss/stub_boss.gd")
const Warden := preload("res://src/combat/warden.gd")

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
	await process_frame  # the tree takes children only once it is running; the arena Warden checks need that
	Synergies.table = null
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


func _gain(numbers: Dictionary, ratio: float, frame := 1) -> float:
	var rule = BossPosture.new(numbers)
	return float(rule.judge({"kind": "ram", "punch": ratio * 100.0, "plating": 100.0, "frame": frame})["gain"])


# Andrew's tap "Lift the ceiling" (17 Oct 22:04Z): a Warden counts a hit up to 3x its plating, so
# a monster ram gains more than an ordinary one; an ordinary ram gains what it did; the hull
# bosses keep the old 1.5 ceiling; hit_cap holds an ordinary hit and opens for a monster one.
func _ceiling() -> void:
	var row := {"curve": 2.0}
	_t.check("a Warden ram at 1.0x plating gains as before", is_equal_approx(_gain(row, 1.0), 30.0), str(_gain(row, 1.0)))
	var flat := {"curve": 1.0}
	_t.check("a monster ram at 3x plating gains twice a 1.5x ram", is_equal_approx(_gain(flat, 3.0), 2.0 * _gain(flat, 1.5)), "%.1f vs %.1f" % [_gain(flat, 3.0), _gain(flat, 1.5)])
	var hull: Dictionary = BossRules.POSTURE
	_t.check("a hull boss still stops counting at 1.5x", is_equal_approx(_gain(hull, 3.0), _gain(hull, 1.5)), "%.1f" % _gain(hull, 3.0))
	var capped := {"curve": 2.0, "hit_cap": 20.0, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55}
	_t.check("hit_cap holds an ordinary amplified ram", _gain(capped, 0.9) <= 20.0001, "%.1f" % _gain(capped, 0.9))
	_t.check("hit_cap opens for a monster ram", _gain(capped, 3.0) >= BossPosture.FULL - 0.001, "%.1f" % _gain(capped, 3.0))
	_t.check("hit_cap climbs between", _gain(capped, 2.25) > 20.0 and _gain(capped, 2.25) < BossPosture.FULL, "%.1f" % _gain(capped, 2.25))
	var first := BossPosture.new({"curve": 2.0, "hit_cap": 15.0, "hit_cap_until_stagger": true, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55})
	var ram := {"kind": "ram", "punch": 90.0, "plating": 100.0, "frame": 1}
	_t.check("hit_cap_until_stagger holds before the first stagger", float(first.judge(ram)["gain"]) <= 15.0001, "%.1f" % float(first.judge(ram)["gain"]))
	first.staggers = 1
	_t.check("hit_cap_until_stagger lets go after it", float(first.judge(ram)["gain"]) > 15.0, "%.1f" % float(first.judge(ram)["gain"]))
	_t.eq("the ultimate fills up to 70 on a closed guard", preload("res://src/combat/ultimate.gd").WARDEN_POSTURE_CAP, 70.0)
	_pilot_class()


# DECISIONS section 5: monster builds get the lift, ordinary pilots keep the old ceiling and cap.
func _pilot_class() -> void:
	var Ult := preload("res://src/combat/ultimate.gd")
	var flat := {"curve": 1.0}
	var ordinary := BossPosture.new(flat)
	ordinary.set_pilot_class(2)
	var at_cap := float(ordinary.judge({"kind": "ram", "punch": 250.0, "plating": 100.0, "frame": 1})["gain"])
	_t.check("a class II hit at ratio 2.5 gains as if capped at 1.5", is_equal_approx(at_cap, _gain(flat, 1.5)), "%.1f vs %.1f" % [at_cap, _gain(flat, 1.5)])
	for cls in [3, 4, 5]:
		var monster := BossPosture.new(flat)
		monster.set_pilot_class(cls)
		var gain := float(monster.judge({"kind": "ram", "punch": 250.0, "plating": 100.0, "frame": 1})["gain"])
		_t.check("a class %d hit at ratio 2.5 counts the lifted ceiling" % cls, is_equal_approx(gain, _gain(flat, 2.5)), "%.1f" % gain)
		_t.check("a class %d hit tops out at 3x" % cls, is_equal_approx(float(monster.judge({"kind": "ram", "punch": 500.0, "plating": 100.0, "frame": 2})["gain"]), _gain(flat, 3.0)), "")
	var grows := BossPosture.new(flat)
	grows.set_pilot_class(2)
	grows.set_pilot_class(3)
	_t.check("a pilot who grows mid-fight earns the lift on the next hit", grows.mult_max == 3.0, str(grows.mult_max))
	var hull := BossPosture.new(BossRules.POSTURE)
	hull.set_pilot_class(5)
	_t.check("a hull boss stays at 1.5 at any class", hull.mult_max == 1.5, str(hull.mult_max))
	var waking := BossPosture.new({"curve": 2.0, "hit_cap": 20.0, "contact_gain_scale": 150.0, "contact_gain_floor": 0.55})
	waking.set_pilot_class(2)
	_t.check("an ordinary pilot's hit_cap holds", float(waking.judge({"kind": "ram", "punch": 300.0, "plating": 100.0, "frame": 1})["gain"]) < BossPosture.FULL, "")
	_t.eq("the set piece cap is 45 at class II", Ult.warden_cap(2), 45.0)
	_t.eq("the set piece cap is 70 at class III", Ult.warden_cap(3), 70.0)
	_t.eq("the set piece cap is 70 at class V", Ult.warden_cap(5), 70.0)
	_t.eq("the set piece cap is 45 when the class is unknown", Ult.warden_cap(0), 45.0)
	var unknown := BossPosture.new(flat)
	unknown.set_pilot_class(0)
	_t.check("an unknown class fails closed at 1.5", unknown.mult_max == 1.5, str(unknown.mult_max))
	_warden_class_source()


# A fleet-less Warden with no class source stays ordinary; one handed a class reads it.
func _warden_class_source() -> void:
	var bare = Warden.new()
	_t.eq("a fleet-less Warden with no class source reads class 0", bare.pilot_heft_class(), 0)
	bare.spec = {"heft_class": func() -> int: return 4}
	_t.eq("a fleet-less Warden reads the class its spec hands in", bare.pilot_heft_class(), 4)
	bare.free()
	_stub_boss_class()


# The class fakes: a run that reports a heft class, and flat ground for a Warden to stand on.
class FakeRun:
	var heft := 0
	var stage := 1

	func _init(h: int) -> void:
		heft = h

	func heft_class() -> int:
		return heft


class FakeCtx:
	var run
	var spawner = null


class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


# The arena Warden has no fleet: the stub boss (and The Waking through super) hands it the run's
# class in the spec, and the Warden's posture ceiling follows. Built the way the stub builds it.
func _stub_boss_class() -> void:
	var stub = StubBoss.new()
	var ctx := FakeCtx.new()
	ctx.run = FakeRun.new(2)
	stub.ctx = ctx
	var spec: Dictionary = stub._warden_spec()
	_t.check("the stub boss spec carries a heft_class callable", spec.get("heft_class") is Callable, str(spec.get("heft_class")))
	_t.eq("the callable reads the run's class", int(spec["heft_class"].call()), 2)
	for cls in [2, 3, 5]:
		ctx.run = FakeRun.new(cls)
		var warden = _arena_warden(stub._warden_spec())
		_t.eq("a Warden built from the stub spec reads class %d" % cls, warden.pilot_heft_class(), cls)
		var ceiling := _ceiling_after_hit(warden)
		_t.check("class %d Warden ceiling is %s" % [cls, "3.0x" if cls >= 3 else "1.5x"], is_equal_approx(ceiling, 3.0 if cls >= 3 else 1.5), "%.1f" % ceiling)
		warden.get_parent().free()
	# The spec reads ctx.run.stage, so it is built with a run; the callable runs later and guards a run gone.
	ctx.run = FakeRun.new(4)
	var spec_none: Dictionary = stub._warden_spec()
	ctx.run = null
	_t.eq("with no run the callable returns 0", int(spec_none["heft_class"].call()), 0)
	var none = _arena_warden(spec_none)
	_t.eq("a Warden with no run reads class 0", none.pilot_heft_class(), 0)
	_t.check("a Warden with no run keeps the 1.5x ceiling", is_equal_approx(_ceiling_after_hit(none), 1.5), "")
	none.get_parent().free()
	stub.free()


func _arena_warden(spec: Dictionary) -> Node3D:
	# stage and run are the fake ctx's; a Warden needs only ground, a root and a target-free setup.
	var warden := Warden.new()
	var root := Node3D.new()
	self.root.add_child(root)
	root.add_child(warden)
	warden.setup(null, FlatGround.new(), root, func() -> bool: return true, 0.0, spec)
	return warden


# judge_hit hands the run's class to the posture rule before it judges; read the ceiling after.
func _ceiling_after_hit(warden: Node3D) -> float:
	warden.judge_hit("ram", 100.0, false, 1)
	return float(warden._posture.mult_max)
