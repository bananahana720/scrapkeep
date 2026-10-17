extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")

# Overpowered pays (Andrew, 17 Oct 2026): a strong build or a lucky run is never punished.
#   - A linear or capped part held at its stack cap adds nothing more, so no roll offers it again,
#     on any pilot's full catalogue; a hyperbolic or uncapped part is never called maxed.
#   - Damage past a kill pays scrap: none without overflow or on a Warden, more with more
#     overflow, at most double the kill's scrap.
#   - A bigger hit draws a bigger damage number, up to MEGA_FONT; small hits keep the old sizes.
# Evidence limit: the rules only. How much faster a strong pilot grows is the bot gate's to
# measure, and how it feels is Andrew's.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const DRAWS := 300

var _t := preload("res://tests/support/t.gd").new("overpowered_pays_test")


func _initialize() -> void:
	Synergies.table = null
	_maxed_parts()
	_overkill()
	_numbers()
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


func _overkill() -> void:
	_t.eq("no overflow pays nothing", Enemy.overkill_scrap(6, 0.0, 40.0, "brute"), 0)
	_t.eq("a Warden pays no overflow", Enemy.overkill_scrap(6, 400.0, 40.0, "warden"), 0)
	_t.eq("one max-HP of overflow pays half again", Enemy.overkill_scrap(6, 40.0, 40.0, "brute"), 3)
	_t.eq("two max-HP of overflow pays double", Enemy.overkill_scrap(6, 80.0, 40.0, "brute"), 6)
	_t.eq("a huge overflow still pays double", Enemy.overkill_scrap(6, 4000.0, 40.0, "brute"), 6)
	_t.check("more overflow never pays less",
		Enemy.overkill_scrap(7, 30.0, 40.0, "chaser") <= Enemy.overkill_scrap(7, 60.0, 40.0, "chaser"), "")


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
