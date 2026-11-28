extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const Build := preload("res://src/build/build.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ItemEffects := preload("res://src/build/item_effects.gd")
const Triggers := preload("res://src/build/triggers.gd")
const Presentation := preload("res://src/presentation/presentation.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const Codex := preload("res://src/core/codex.gd")
const Registry := preload("res://tests/support/content_registry.gd")

# SG5, comps/gunfire/scrolls-and-synergies.md:86: measure real item strikes through
# Build.item_hit against one fixed target. This is a headless model, not a feel verdict.
const BASE_HIT := 14.0
const BASE_DPS := 60.0
const TARGET_HP := 600.0
const ENEMY_DPS := 5.0
const ENCOUNTER_SEEDS := 40
const HAZARD_HITS := 4
const HAZARD_DAMAGE := 8.0
const JITTER := 0.25

var _t := preload("res://tests/support/t.gd").new("burden_sweep_test")


class FixedTarget extends Node3D:
	var damage := 0.0


class StrikeRecorder extends Node:
	var hits := 0
	var kinds: Array = []
	var build

	func strike(enemy: Node3D, kind: String, damage: float) -> void:
		enemy.damage += damage
		hits += 1
		kinds.append(kind)
		build._on_struck_trigger(enemy, kind, damage)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var payouts: Array = []
	for id in Parts.ids():
		if Parts.def(id).effect.get("do", "") == "burden_payout":
			payouts.append(id)
	_t.eq("exactly one burden payout row", payouts.size(), 1)
	if payouts.size() != 1:
		quit(_t.verdict())
		return
	var id: String = payouts[0]
	var d: Resource = Parts.def(id)
	_t.eq("payout uses the ceiling curve", d.stack_rule, "hyperbolic")
	_t.check("payout has a finite positive declared cap", is_finite(d.stack_cap) and d.stack_cap > 0.0 and d.stack_cap < 1.0, str(d.stack_cap))
	_t.check("payout has a finite positive slope", is_finite(float(d.effect.get("per", 0.0))) and float(d.effect.get("per", 0.0)) > 0.0, str(d.effect))
	_t.eq("payout answers each eligible hit", d.trigger, "on_hit")
	_t.check("payout effect is registered", ItemEffects.EFFECTS.has("burden_payout"), "")
	_card(id, d)
	_sweep(id, d)
	_edges(id, d)
	_t.eq("parts golden digest matches the changed rows", Registry.digest(Parts.rows()), Registry.GOLDEN_HASHES["parts.rows"])
	quit(_t.verdict())


func _held(id: String, burdens: int, payout_copies := 1) -> Array:
	var held: Array = []
	for i in payout_copies:
		held.append(id)
	var costs := Parts.burdens()
	for i in burdens:
		held.append(costs[i % costs.size()])
	return held


func _measure(held: Array, proc := 1.0, refresh_before: Array = []) -> Dictionary:
	var build = Build.new()
	var target := FixedTarget.new()
	var recorder := StrikeRecorder.new()
	root.add_child(target)
	root.add_child(recorder)
	build.ctx = {"spawner": recorder}
	recorder.build = build
	build.sheet = BuildSheet.from_parts(held)
	var effects := ItemEffects.new(build)
	effects.refresh(refresh_before)
	effects.refresh(held)
	var hit: float = BASE_HIT * build.sheet.mod("weapon_damage")
	var bus := Triggers.Bus.new()
	build.bus = bus
	bus.post(Triggers.Commitment.new(Triggers.Kind.ON_HIT, "line", proc, Vector3.ZERO, target, hit))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000
	bus.run(effects.resolve, rng)
	var result := {"bonus": target.damage / hit, "power": build.sheet.power() * (1.0 + target.damage / hit),
		"ceiling": ClassDef.by_id("pylon_engineer").base_hp + build.sheet.max_hp_bonus, "hits": recorder.hits, "kinds": recorder.kinds.duplicate(),
		"procs": effects.procs.duplicate(), "pending": bus.pending.size()}
	build.free()
	recorder.free()
	target.free()
	return result


func _encounter(s: Dictionary) -> Dictionary:
	var dps: float = BASE_DPS * s["power"]
	var taken_total := 0.0
	var survived := 0
	for seed_value in ENCOUNTER_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + seed_value
		var taken: float = ENEMY_DPS * TARGET_HP / dps
		for h in HAZARD_HITS:
			taken += HAZARD_DAMAGE * rng.randf_range(1.0 - JITTER, 1.0 + JITTER)
		taken_total += taken
		if taken < s["ceiling"]:
			survived += 1
	return {"dps": dps, "taken": taken_total / ENCOUNTER_SEEDS, "survived": survived}


func _sweep(id: String, d: Resource) -> void:
	print("burden sweep step 2: count, payout, step, cap, net power, dps, taken, survived of %d" % ENCOUNTER_SEEDS)
	var previous := 0.0
	var previous_step := INF
	var zero := _measure(_held(id, 0))
	var five := {}
	var ten := {}
	for count in range(0, 11):
		var s := _measure(_held(id, count))
		var e := _encounter(s)
		var step: float = s["bonus"] - previous
		print("  burdens %2d payout %.6f step %.6f cap %.3f power %.6f dps %.2f taken %.2f survived %d" % [count,
			s["bonus"], step, d.stack_cap, s["power"], e["dps"], e["taken"], e["survived"]])
		_t.check("count %d finite complete sweep row" % count, is_finite(s["bonus"]) and is_finite(s["power"])
			and is_finite(e["dps"]) and is_finite(e["taken"]) and is_finite(s["ceiling"]) and e["dps"] > 0.0, "")
		_t.check("count %d total payout strictly below declared cap" % count, s["bonus"] >= 0.0 and s["bonus"] < d.stack_cap, str(s["bonus"]))
		var expected: float = d.stack_cap * (1.0 - 1.0 / (1.0 + float(d.effect["per"]) * count))
		_t.near("count %d measured payout follows ceiling curve" % count, s["bonus"], expected, 0.000001)
		if count > 0:
			_t.check("count %d payout grows with non-growing step" % count, step > 0.0 and step <= previous_step + 0.000001, str(step))
			previous_step = step
			_t.eq("count %d one guarded item strike" % count, s["kinds"], [Build.SYNERGY_KIND])
			_t.eq("count %d payout proc counted" % count, s["procs"].get(id, 0), 1)
		_t.eq("count %d trigger pass drains" % count, s["pending"], 0)
		previous = s["bonus"]
		if count == 5:
			five = e
		if count == 10:
			ten = s
	_t.check("10 burdens net power at most 3x zero", ten["power"] <= 3.0 * zero["power"], "%.6fx" % (ten["power"] / zero["power"]))
	var baseline := _encounter(zero)
	_t.check("5 burdens survive at least as often as 0", five["survived"] >= baseline["survived"], "%d vs %d" % [five["survived"], baseline["survived"]])


func _edges(id: String, d: Resource) -> void:
	var held := _held(id, 10)
	var s := _measure(held)
	_t.eq("same seeded build replays identically", _measure(held), s)
	_t.near("no burden means no payout", _measure(_held(id, 0))["bonus"], 0.0, 0.000001)
	_t.eq("no payout means no extra strike", _measure(_held(id, 10, 0))["hits"], 0)
	_t.eq("own strike with zero proc cannot pay again", _measure(held, 0.0)["hits"], 0)
	_t.eq("refresh removing all burdens clears payout", _measure(_held(id, 0), 1.0, held)["hits"], 0)
	_t.near("refresh is idempotent", _measure(held, 1.0, held)["bonus"], s["bonus"], 0.000001)
	var duplicated := _measure(_held(id, 10, 100))
	_t.check("100 payout copies share one ceiling", duplicated["bonus"] < d.stack_cap and duplicated["bonus"] > s["bonus"], str(duplicated["bonus"]))
	var scaled := held.duplicate()
	scaled.append("hot_rivets")
	_t.near("weapon multiplier does not multiply payout share twice", _measure(scaled)["bonus"], s["bonus"], 0.000001)
	for cost in Parts.burdens():
		var repeated: Array = [id]
		for i in 10:
			repeated.append(cost)
		_t.near("ten copies of %s count as ten burdens" % cost, _measure(repeated)["bonus"], s["bonus"], 0.000001)
	var rule: String = d.stack_rule
	d.stack_rule = "linear"
	var uncapped := _measure(held)
	d.stack_rule = rule
	_t.check("positive control: a linear payout breaks the cap", uncapped["bonus"] >= d.stack_cap, str(uncapped["bonus"]))


func _card(id: String, d: Resource) -> void:
	var cap_text := "up to +%d%%" % roundi(d.stack_cap * 100.0)
	var banner = CodexBanner.new()
	root.add_child(banner)
	banner.cards = true
	var p = Presentation.new()
	var codex = Codex.new()
	p.ctx = {"codex": codex}
	p.banner = banner
	p._on_part(id, "pocket")
	_t.check("part card prints its declared payout cap", banner._body.visible and cap_text in banner._body.text, banner._body.text)
	_t.near("readout resource exposes the same cap", Parts.def(id).stack_cap, Parts.row(id).get("cap", -1.0), 0.000001)
	p.free()
	codex.free()
	banner.free()
