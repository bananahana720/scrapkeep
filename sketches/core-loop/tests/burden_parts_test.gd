extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Icons := preload("res://src/ui/icons.gd")
const WordBudget := preload("res://src/core/word_budget.gd")

# SG4 (W13-INTEGRATION-3, comps/gunfire/scrolls-and-synergies.md:86): burden parts are rare,
# pure stated downsides that only a visible optional pocket pays out, held under a per-world
# hot-wired cap. Checks:
#   - each burden row sits in the hot-wired row shape: one cost icon and at most three words,
#     the words resolved from the part's own numbers, and the part is a pure downside;
#   - offer_pool for all six pilots and every rarity returns zero burdens, as do rolls and
#     hotwire_offer; the alpha parts list names the burdens so a pocket's pay.named is in play;
#   - a pocket row's pay.named pays the burden through the authored-row-or-burden rule;
#     burdens stay out of rows(), preserving the loot digest pin;
#   - one hot-wired part in world one, the per-world cap from world 2;
#   - burden sweep step 1: a dummy build holds 0 to 10 burdens against a fixed target; damage
#     per second and damage taken print per count, and 5 burdens survive the fixed scripted
#     encounter at least as often as 0 (reports now, gates from SG5 on the 3x power ceiling).
# Evidence limit: a headless model of one fixed encounter; it does not judge how a burden feels.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const RARITIES := [["common"], ["rare"], ["relic"], ["evolved"], ["common", "rare", "relic"]]
const ENCOUNTER_SEEDS := 40

# The fixed encounter: the dummy target has TARGET_HP; the build deals BASE_DPS x its power;
# the target hits back ENEMY_DPS for as long as it lives, plus HAZARD_HITS fixed hits at
# seeded jitter. The pilot survives when the damage taken is under its health ceiling.
const TARGET_HP := 600.0
const BASE_DPS := 60.0
const ENEMY_DPS := 5.0
const HAZARD_HITS := 4
const HAZARD_DAMAGE := 8.0
const JITTER := 0.25

var _t := preload("res://tests/support/t.gd").new("burden_parts_test")


func _initialize() -> void:
	_run()


func _run() -> void:
	_rows()
	_pool()
	_cap()
	_sweep()
	await _pocket_pay()
	quit(_t.verdict())


func _rows() -> void:
	var burdens := Parts.burdens()
	_t.check("at least two burdens", burdens.size() >= 2, str(burdens))
	for id in burdens:
		var row := Parts.hotwired(id)
		_t.check("%s is a hot-wired row" % id, not row.is_empty() and row.get("burden", false) and row.has("name"), str(row.keys()))
		var cost := Parts.burden_cost(id)
		var words := WordBudget.words_in(String(cost.get("words", "")))
		_t.check("%s cost icon and 1 to 3 words" % id, Icons.has(String(cost.get("icon", ""))) and words >= 1 and words <= 3,
			"icon %s, \"%s\" is %d words" % [cost.get("icon"), cost.get("words"), words])
		_t.check("%s words resolved" % id, not "{" in String(cost.get("words", "{")), String(cost.get("words", "")))
		_t.eq("%s is rare" % id, Parts.rarity_of(id), "rare")
		_t.check("%s is known to the build" % id, Parts.has(id) and Parts.def(id) != null, "")
		var d: Resource = Parts.def(id)
		# A pure downside: no knob above 1, nothing added, health and scrap never up.
		var pure: bool = d.punch <= 0.0 and d.patterns.is_empty() and d.elements.is_empty() and d.effect.is_empty() \
			and d.charges.is_empty() and d.trigger == "" and d.magnet <= 1.0 and d.kill_scrap <= 1.0 \
			and d.max_hp_bonus <= 0.0 and d.cooldown_scale >= 1.0
		for knob in d.mods:
			pure = pure and float(d.mods[knob]) <= 1.0
		var costs: bool = d.max_hp_bonus < 0.0 or d.magnet < 1.0 or d.kill_scrap < 1.0 or not d.mods.is_empty()
		_t.check("%s is a pure stated downside" % id, pure and costs, "hp %s magnet %s scrap %s mods %s" % [d.max_hp_bonus, d.magnet, d.kill_scrap, d.mods])
		_t.check("%s in the alpha parts list" % id, AlphaDefs.part_in_play(id), "")
		_t.check("%s is in no loot table" % id, not Parts.rows().has(id) and not id in Parts.ids(), "")
	_t.eq("the alpha burden list is the burden rows", AlphaDefs.BURDEN_PARTS, burdens)
	_t.check("no burden sits in the loot parts list", AlphaDefs.PARTS.all(func(id): return not Parts.is_burden(id)), "")
	_t.check("the two hot-wired parts are not burdens", not Parts.is_burden("riveted_shell") and not Parts.is_burden("spark_tread"), "")


func _pool() -> void:
	var seen := 0
	for pilot in PILOTS:
		for rarities in RARITIES:
			for id in Parts.offer_pool(pilot, rarities):
				if Parts.is_burden(id):
					seen += 1
		var rng := RandomNumberGenerator.new()
		for seed_value in 50:
			rng.seed = 5000 + seed_value
			for id in Parts.roll(rng, PartOffers.gate_rarities(seed_value % 3), pilot, [], 3):
				if Parts.is_burden(id):
					seen += 1
	_t.eq("offer_pool and roll return zero burdens for six pilots", seen, 0)
	var offered := 0
	for armor in [true, false]:
		for world in [1, 2, 3]:
			for id in Parts.hotwire_offer(armor, [], world):
				if Parts.is_burden(id):
					offered += 1
	_t.eq("hotwire_offer never returns a burden", offered, 0)
	_t.eq("held burdens do not count against the hot-wired cap", Parts.hotwire_offer(true, Parts.burdens()), Parts.hotwire_offer(true, []))


func _cap() -> void:
	_t.eq("world one cap", Parts.hotwire_cap(1), 1)
	_t.check("world 2 cap is above one", Parts.hotwire_cap(2) > 1 and Parts.hotwire_cap(3) >= Parts.hotwire_cap(2), "%d %d" % [Parts.hotwire_cap(2), Parts.hotwire_cap(3)])
	_t.check("world one offers with none held", not Parts.hotwire_offer(true, [], 1).is_empty(), "")
	_t.eq("world one offers nothing with one held", Parts.hotwire_offer(true, ["riveted_shell"], 1), [])
	_t.eq("default world is world one", Parts.hotwire_offer(true, ["spark_tread"]), [])
	_t.eq("world two offers the other with one held", Parts.hotwire_offer(true, ["riveted_shell"], 2), ["spark_tread"])
	_t.eq("world two never offers a held copy", Parts.hotwire_offer(true, ["riveted_shell", "spark_tread"], 2), [])
	_t.eq("a burden held leaves world one's offer alone", Parts.hotwire_offer(true, [Parts.burdens()[0]], 1), Parts.hotwire_offer(true, [], 1))


func _stats(count: int) -> Dictionary:
	var held: Array = []
	var ids := Parts.burdens()
	for i in count:
		held.append(ids[i % ids.size()])
	var sheet := BuildSheet.from_parts(held)
	var dps: float = BASE_DPS * sheet.power()
	var ttk: float = TARGET_HP / dps
	var ceiling: float = ClassDef.by_id("pylon_engineer").base_hp + sheet.max_hp_bonus
	var survived := 0
	var taken_total := 0.0
	for seed_value in ENCOUNTER_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + seed_value
		var taken: float = ENEMY_DPS * ttk
		for h in HAZARD_HITS:
			taken += HAZARD_DAMAGE * rng.randf_range(1.0 - JITTER, 1.0 + JITTER)
		taken_total += taken
		if taken < ceiling:
			survived += 1
	return {"dps": dps, "taken": taken_total / ENCOUNTER_SEEDS, "survived": survived, "ceiling": ceiling}


func _sweep() -> void:
	var zero := _stats(0)
	print("burden sweep step 1, per count: damage per second, mean damage taken, health ceiling, survived of %d" % ENCOUNTER_SEEDS)
	for count in range(0, 11):
		var s := _stats(count)
		print("  burdens %2d  dps %.2f  taken %.2f  ceiling %.1f  survived %d" % [count, s["dps"], s["taken"], s["ceiling"], s["survived"]])
		_t.check("count %d numbers finite" % count, is_finite(s["dps"]) and is_finite(s["taken"]) and is_finite(s["ceiling"]) and s["dps"] > 0.0, "")
		_t.check("count %d never raises the ceiling" % count, s["ceiling"] <= zero["ceiling"] + 0.0001, "")
	var five := _stats(5)
	_t.check("5 burdens survive at least as often as 0", five["survived"] >= zero["survived"], "%d vs %d of %d" % [five["survived"], zero["survived"], ENCOUNTER_SEEDS])
	var ten := _stats(10)
	_t.check("10 burdens cost something real", ten["ceiling"] < zero["ceiling"] or ten["dps"] < zero["dps"], "ceiling %.1f vs %.1f" % [ten["ceiling"], zero["ceiling"]])
	# The check can fail: a harsh stand-in ceiling must drop survival, or the survival bar proves nothing.
	var harsh_ceiling: float = ClassDef.by_id("pylon_engineer").base_hp - 80.0
	var harsh := 0
	for seed_value in ENCOUNTER_SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + seed_value
		var taken: float = ENEMY_DPS * (TARGET_HP / BASE_DPS)
		for h in HAZARD_HITS:
			taken += HAZARD_DAMAGE * rng.randf_range(1.0 - JITTER, 1.0 + JITTER)
		if taken < harsh_ceiling:
			harsh += 1
	_t.check("positive control: a 20 health ceiling does not survive as often", harsh < zero["survived"], "%d vs %d" % [harsh, zero["survived"]])


func _pocket_pay() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "alpha"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	game.world.set_physics_process(false)
	game.world.activities.set_physics_process(false)
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	game.world.activities.clear()
	var id: String = Parts.burdens()[0]
	var acts = game.world.activities
	var s = acts._build("cracked_cache", Vector2.ZERO, {"id": "cracked_cache", "at": Vector2.ZERO, "pay": {"named": id, "rarities": ["rare"]}})
	_t.eq("a pocket row's pay.named reaches the rule", String(s.rule["pay"].get("named", "")), id)
	acts._finish(s, Vector3.ZERO)
	_t.eq("a pocket row's pay.named pays the burden", String(s.pickup_part), id)
	s.queue_free()
	game.free()
