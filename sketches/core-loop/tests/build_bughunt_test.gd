extends SceneTree

const Build := preload("res://src/build/build.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Triggers := preload("res://src/build/triggers.gd")
const PartDef := preload("res://src/build/part_def.gd")

# Unit BUGFIX-BUILD (wave 12-F, 2026-10-09): the hosted bug hunter's four build findings,
# each checked on the real code with stand-ins only for the spawner and the sheet:
#   - F001: an item hit takes the weapon multiplier once (rebound_strike, item_effects);
#   - F002: an expired brace share is cleared, so a later weaker brace sets its own share;
#   - F003: a generated rare item gets the middle base stat, a relic the top one;
#   - F004: a one-slot stage-2 gate keeps the synergy bait instead of the pattern part.


class FakeSpawner:
	var forces: Array = []

	func strike(_enemy: Node3D, _kind: String, force: float) -> void:
		forces.append(force)


class FakeCtx:
	var spawner


class FakeBuild:
	var ctx


class FakeSheet:
	var punch := 0.0
	var mods := {"weapon_damage": 1.5}

	func mod(knob: String) -> float:
		return mods.get(knob, 1.0)


var _failures := 0


# The checks run on the first frame, once root is inside the tree, so the F001 enemy
# stand-in has a global transform when item_hit reads it.
func _process(_delta: float) -> bool:
	_check_f001_item_hit_once()
	_check_f002_brace_expires()
	_check_f003_rare_base_stat()
	_check_f004_one_slot_bait()
	print("build_bughunt_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _check_f001_item_hit_once() -> void:
	var build = Build.new()
	var ctx := FakeCtx.new()
	ctx.spawner = FakeSpawner.new()
	build.ctx = ctx
	build.sheet = FakeSheet.new()
	var effects := ItemEffects.new(build)
	build.effects = effects
	var enemy := Node3D.new()
	root.add_child(enemy)
	var c := Triggers.Commitment.new(Triggers.Kind.ON_REBOUND, "rebound", 1.0, Vector3.ZERO, enemy, 5.0)
	effects._apply("test_rebound", PartDef.new(), {"do": "rebound_strike"}, c, 1.0, 0.0, 0)
	var expect: float = ItemEffects.BASE_HIT * 1.5
	var got: float = ctx.spawner.forces[0] if not ctx.spawner.forces.is_empty() else -1.0
	_report("F001 item hit scales once", is_equal_approx(got, expect),
		"rebound_strike at power 1 with weapon_damage 1.5 struck %.2f; expected %.2f (BASE_HIT x 1.5), not %.2f (x 1.5 squared)"
			% [got, expect, ItemEffects.BASE_HIT * 2.25])
	enemy.free()
	build.free()


func _check_f002_brace_expires() -> void:
	var effects := ItemEffects.new(FakeBuild.new())
	var c := Triggers.Commitment.new(Triggers.Kind.ON_HIT, "test")
	var fx := {"do": "brace", "window": 1.0}
	effects._clock = 0.0
	effects._apply("test_brace", PartDef.new(), fx, c, 0.8, 0.0, 0)
	effects._clock = 10.0
	effects._apply("test_brace", PartDef.new(), fx, c, 0.2, 0.0, 0)
	var after_expiry: float = effects._brace_share
	effects._clock = 10.5
	effects._apply("test_brace", PartDef.new(), fx, c, 0.1, 0.0, 0)
	var inside_window: float = effects._brace_share
	_report("F002 expired brace clears", is_equal_approx(after_expiry, 0.2) and is_equal_approx(inside_window, 0.2),
		"brace 0.8 at t=0, brace 0.2 at t=10 (window 1 s) -> share %.2f, expected 0.20; brace 0.1 at t=10.5 inside the window -> %.2f, expected 0.20 kept"
			% [after_expiry, inside_window])


func _check_f003_rare_base_stat() -> void:
	var got := {}
	for rarity in ["common", "rare", "relic"]:
		got[rarity] = ItemGen.generated_row(ItemGen.make_id("weapon", rarity, "", "on_hit")).get("punch", -1.0)
	var stat: Array = ItemGen.BASES["weapon"]["stat"]["punch"]
	_report("F003 rare gets the middle stat", got["common"] == stat[0] and got["rare"] == stat[1] and got["relic"] == stat[2],
		"generated weapon punch by rarity %s; expected common %.0f, rare %.0f, relic %.0f" % [got, stat[0], stat[1], stat[2]])


func _check_f004_one_slot_bait() -> void:
	var rarities: Array = Parts.gate_rarities(0)
	var class_id := "runner_gunner"
	var pool: Array = Parts.offer_pool(class_id, rarities)
	var plain: Array = Parts.ids().filter(func(key): return Parts.def(key).patterns.is_empty())
	var held: Array = []
	var bait := ""
	for a in plain:
		for b in plain:
			var hand: Array = [a, b]
			var candidate: String = Parts.completing_part(hand, pool)
			if candidate != "" and not candidate in PartOffers.PATTERN_PARTS and not Parts.holds_pattern(hand):
				held = hand
				bait = candidate
				break
		if bait != "":
			break
	if bait == "":
		_report("F004 one-slot gate keeps the bait", false, "no pattern-less hand one part from a synergy was found")
		return
	var rng := RandomNumberGenerator.new()
	var seeded := -1
	for s in 200:
		rng.seed = s
		if rng.randf() < PartOffers.SYNERGY_BAIT:
			seeded = s
			break
	rng.seed = seeded
	var plain_one: Array = Parts.roll(rng, rarities, class_id, held, 1)
	rng.seed = seeded
	var gate: Array = Parts.roll_gate(rng, rarities, class_id, held, 1, PartOffers.PATTERN_GUARANTEE_STAGE)
	_report("F004 one-slot gate keeps the bait", plain_one == [bait] and gate == [bait],
		"held %s, seed %d: roll() gave %s (bait %s); stage-%d roll_gate with one slot gave %s, expected the bait kept"
			% [held, seeded, plain_one, bait, PartOffers.PATTERN_GUARANTEE_STAGE, gate])
