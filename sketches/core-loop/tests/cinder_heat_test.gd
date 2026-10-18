extends SceneTree

# Rule (Andrew, 2026-10-17 23:24Z, the sinkhole's floor is lava; src/world/cinder_heat.gd): touching the cinder floor is
# free for GRACE_S, then it burns BURN_HP_PER_S in TICK_S pulses; leaving the floor or landing a hit cools it at once;
# the burn never takes the hull under FLOOR_HP. The glow telegraph rises over the grace and the facts fire once each.

const T := preload("res://tests/support/t.gd")
const CinderHeat := preload("res://src/world/cinder_heat.gd")
const DT := 1.0 / 90.0

var t := T.new("cinder_heat_test")


func _initialize() -> void:
	var heat := CinderHeat.new()
	var facts := []
	var hurt := 0.0
	var glow_at_grace := 0.0
	for k in int(CinderHeat.GRACE_S / DT) - 1:
		var out := heat.step(DT, true, 100.0)
		hurt += float(out["damage"])
		if out["fact"] != "":
			facts.append(out["fact"])
		glow_at_grace = float(out["glow"])
	t.check("no burn inside the grace", hurt == 0.0, "%.2f hp" % hurt)
	t.check("the cinders glow before the burn", facts == [CinderHeat.GLOW_FACT] and glow_at_grace > 0.9, "%s glow %.2f" % [facts, glow_at_grace])
	for k in int(2.0 / DT):
		var out := heat.step(DT, true, 100.0)
		hurt += float(out["damage"])
		if out["fact"] != "":
			facts.append(out["fact"])
	t.check("two seconds past the grace burn BURN_HP_PER_S", absf(hurt - 2.0 * CinderHeat.BURN_HP_PER_S) <= CinderHeat.BURN_HP_PER_S * CinderHeat.TICK_S, "%.2f hp" % hurt)
	t.check("the burn sizzles once", facts.count(CinderHeat.BURN_FACT) == 1, str(facts))
	var off := heat.step(DT, false, 100.0)
	t.check("leaving the floor hisses and cools", off["fact"] == CinderHeat.COOL_FACT and heat.dwell == 0.0, str(off))

	# Zigzag: short touches never add up.
	var zig := CinderHeat.new()
	var zig_hurt := 0.0
	for rep in 20:
		for k in int(1.0 / DT):
			zig_hurt += float(zig.step(DT, true, 100.0)["damage"])
		zig.step(DT, false, 100.0)
	t.check("touches under the grace never burn", zig_hurt == 0.0, "%.2f hp" % zig_hurt)

	# Bowling through a pack: each landed hit resets the dwell.
	var bowl := CinderHeat.new()
	var bowl_hurt := 0.0
	for k in int(6.0 / DT):
		bowl_hurt += float(bowl.step(DT, true, 100.0)["damage"])
		if k % 90 == 89:
			bowl.struck()
	t.check("a hit a second keeps the floor cool", bowl_hurt == 0.0, "%.2f hp" % bowl_hurt)

	# A hit mid-glow restarts the telegraph, so the next glow is heard again.
	var reglow := CinderHeat.new()
	var glows := 0
	for k in int(2.0 / DT):
		if reglow.step(DT, true, 100.0)["fact"] == CinderHeat.GLOW_FACT:
			glows += 1
		if k == int(1.0 / DT):
			reglow.struck()
	t.check("a hit mid-glow re-arms the glow", glows == 2, "%d glows" % glows)

	# Never lethal.
	var low := CinderHeat.new()
	var hp := 3.0
	for k in int(30.0 / DT):
		hp -= float(low.step(DT, true, hp)["damage"])
	t.check("the burn stops at FLOOR_HP", is_equal_approx(hp, CinderHeat.FLOOR_HP), "hp %.2f" % hp)
	quit(t.verdict())
