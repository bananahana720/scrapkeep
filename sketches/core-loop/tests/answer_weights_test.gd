extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Shop := preload("res://src/build/shop.gd")

# 2026-10-18 (w17 answers): "Nudge loot", Andrew 2026-10-17 00:01Z: "Bad matchups: counter items show
# up 1.5x as often; still luck." A part whose Parts.ANSWERS tags hold the pilot's nemesis axis
# (Nemesis.PILOT) weighs Nemesis.OFFER_WEIGHT times its offer bucket's other parts, inside each group
# (Parts.answer_nudge into _nudged). Checks, on the full authored catalogue:
#   - the table: every ANSWERS id is a real part with a known axis, and every pilot has an
#     answering part in its pool;
#   - the odds, read exactly from Parts.slot_weights (the weights a kit slot draws by) for each
#     pilot at common and at rare, nudge on against off: an answering part weighs OFFER_WEIGHT times
#     what it did against every other part of its group and bucket, and each group's and bucket's
#     total weight is unchanged (so the SQ19 kit share cannot move);
#   - the draw reaches the nudge: with the same seed, Parts.roll differs from the nudge-off roll and
#     offers answering parts more often (a pilot whose answers are drawable at all);
#   - no effect where nothing answers: a pilot with no nemesis, and a pilot whose answering parts are
#     all excluded, draw the same picks and use the same rng on and off, and answer_nudge hands the
#     nudge back untouched;
#   - the shop shelf (Shop._stock, Parts.roll under it) is the nudged draw.
# Rivet (runner_gunner) and Sable (pylon_engineer) have their spread and plating answers mostly in
# the rest group; since w45 P5 (Parts.REST_OF_NEUTRAL), the rest group receives a bounded non-zero
# share of the non-kit pool so off-kit answering parts are drawable and receive the answer lean.
# Printed, not asserted: each pilot's answering share and how many answering parts the kit lean can
# draw at all (weight above zero). A part off the pilot's kit and off the neutral shelf sits in the
# "rest" group, which shares the non-kit slice with the neutral shelf via Parts.REST_OF_NEUTRAL.
# Evidence limit: the offer draw only. Whether a nudged run is easier is the matchup lab's claim.

const PILOTS := ["pylon_engineer", "runner_gunner", "demolitions_caster", "tarn", "tally", "remembered_cannon"]
const BUCKETS := ["weapon", "skill", "defence", "movement"]
const RARITIES := ["common", "rare"]
const EPS := 0.000001
const DRAWS := 400
const SHOP_VISITS := 400

var _t := preload("res://tests/support/t.gd").new("answer_weights_test")


class StubRun:
	extends RefCounted
	var parts: Array = []
	var stage := 1
	var cls := ""

	func class_id() -> String:
		return cls


class StubCtx:
	extends RefCounted
	var run := StubRun.new()


func _initialize() -> void:
	Synergies.set_table(null)
	_table()
	for pilot in PILOTS:
		for rarity in RARITIES:
			_odds(pilot, rarity)
		_excluded(pilot)
	_reaches()
	_no_nemesis()
	_shop()
	PartOffers.answer_nudge_on = true
	quit(_t.verdict())


func _answering(pilot: String, rarities: Array = RARITIES) -> Array:
	return Parts.offer_pool(pilot, rarities).filter(func(id): return Nemesis.answers(pilot, PartOffers.answers_of(id)))


func _table() -> void:
	var rows := Parts.rows()
	var bad: Array = []
	for id in PartOffers.ANSWERS:
		if not rows.has(id) or PartOffers.ANSWERS[id].is_empty() or not PartOffers.ANSWERS[id].all(func(a): return a in Nemesis.AXES):
			bad.append(id)
	_t.eq("every ANSWERS id is a real part with known axes", bad, [])
	_t.check("OFFER_WEIGHT is a lean above 1", Nemesis.OFFER_WEIGHT > 1.0, str(Nemesis.OFFER_WEIGHT))
	_t.eq("a part with no tag reads []", PartOffers.answers_of("rivet_seam"), [])
	for pilot in PILOTS:
		var answering: Array = _answering(pilot)
		_t.check("%s has answering parts in its pool" % pilot, not answering.is_empty(), str(answering))


func _group_of(pilot: String, id: String) -> String:
	if Parts.in_kit(pilot, id):
		return "moving" if Parts.bucket_of(id) == "movement" else "still"
	return "shelf" if id in PartOffers.NEUTRAL_SHELF else "rest"


# The slot's odds with the nudge off and on, read exactly.
func _odds(pilot: String, rarity: String) -> void:
	var pool: Array = Parts.offer_pool(pilot, [rarity])
	var off := Parts.slot_weights(rarity, pilot, pool, {}, {})
	var on := Parts.slot_weights(rarity, pilot, pool, {}, PartOffers.answer_nudge(pilot, pool, {}))
	var label := "%s %s" % [pilot, rarity]
	_t.eq("%s: the same candidates on and off" % label, on["candidates"], off["candidates"])
	var mass := {}
	var ratios := {}
	var drawable := 0
	var answering := 0
	var share_off := 0.0
	var share_on := 0.0
	for id in off["candidates"]:
		var key := "%s/%s" % [_group_of(pilot, id), Parts.bucket_of(id)]
		if not mass.has(key):
			mass[key] = [0.0, 0.0]
			ratios[key] = {"answer": [], "other": []}
		mass[key][0] += off["weights"][id]
		mass[key][1] += on["weights"][id]
		var answers := Nemesis.answers(pilot, PartOffers.answers_of(id))
		if off["weights"][id] > EPS:
			ratios[key]["answer" if answers else "other"].append(on["weights"][id] / off["weights"][id])
		if answers:
			answering += 1
			drawable += 1 if off["weights"][id] > EPS else 0
			share_off += off["weights"][id]
			share_on += on["weights"][id]
	var worst_mass := 0.0
	for key in mass:
		worst_mass = maxf(worst_mass, absf(mass[key][0] - mass[key][1]))
	_t.check("%s: every group and bucket keeps its weight" % label, worst_mass <= EPS, "worst %.9f" % worst_mass)
	var bad: Array = []
	for key in ratios:
		var a: Array = ratios[key]["answer"]
		var o: Array = ratios[key]["other"]
		if a.is_empty() or o.is_empty():
			continue
		for r in a:
			if absf(r / o[0] - Nemesis.OFFER_WEIGHT) > EPS:
				bad.append(key)
		for r in o:
			if absf(r - o[0]) > EPS:
				bad.append(key)
	_t.eq("%s: an answering part weighs OFFER_WEIGHT times its group-bucket's others" % label, bad, [])
	print("[%s] answers in pool %d, drawable %d, answering weight off %.3f on %.3f" % [label, answering, drawable, share_off, share_on])
	_t.check("%s: the answering weight never falls" % label, share_on >= share_off - EPS, "%.4f against %.4f" % [share_on, share_off])


# With every answering part excluded nothing is nudged: the same seed gives the same picks.
func _excluded(pilot: String) -> void:
	var answering: Array = _answering(pilot)
	_t.eq("%s: answer_nudge leaves the nudge alone when nothing in the pool answers" % pilot,
		PartOffers.answer_nudge(pilot, Parts.offer_pool(pilot, RARITIES).filter(func(id): return not id in answering), {}), {})
	var runs: Array = []
	for on in [true, false]:
		PartOffers.answer_nudge_on = on
		var rng := RandomNumberGenerator.new()
		rng.seed = 4141
		var got: Array = []
		for _i in 100:
			got.append(Parts.roll(rng, RARITIES, pilot, [], 3, answering))
		runs.append([got, rng.randi()])
	PartOffers.answer_nudge_on = true
	_t.check("%s: picks and rng use match with the answering parts excluded" % pilot, runs[0] == runs[1], "")


func _count(picks_by_draw: Array, answering: Array) -> int:
	var n := 0
	for picks in picks_by_draw:
		for id in picks:
			n += 1 if id in answering else 0
	return n


# Same seed, nudge on and off: the draw is the nudged one, and it leans to the answers.
func _reaches() -> void:
	for pilot in ["demolitions_caster", "tally"]:
		var answering: Array = _answering(pilot)
		var draws: Array = []
		for on in [true, false]:
			PartOffers.answer_nudge_on = on
			var rng := RandomNumberGenerator.new()
			rng.seed = 5150
			var got: Array = []
			for _i in DRAWS:
				got.append(Parts.roll(rng, RARITIES, pilot, [], 2))
			draws.append(got)
		PartOffers.answer_nudge_on = true
		var on_n := _count(draws[0], answering)
		var off_n := _count(draws[1], answering)
		print("[%s] %d draws of 2: answering offers on %d, off %d" % [pilot, DRAWS, on_n, off_n])
		_t.check("%s: roll differs with the nudge on" % pilot, draws[0] != draws[1], "")
		_t.check("%s: roll offers answering parts more often on" % pilot, on_n > off_n, "%d against %d" % [on_n, off_n])


func _no_nemesis() -> void:
	_t.eq("a class with no nemesis has no axes", Nemesis.of("nobody"), [])
	_t.eq("answer_nudge hands a no-nemesis pilot's nudge back", PartOffers.answer_nudge("nobody", Parts.offer_pool("", RARITIES), {}), {})
	var runs: Array = []
	for on in [true, false]:
		PartOffers.answer_nudge_on = on
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var got: Array = []
		for _i in 100:
			got.append(Parts.roll(rng, RARITIES, "", [], 3))
		runs.append([got, rng.randi()])
	PartOffers.answer_nudge_on = true
	_t.check("a classless draw is identical with the nudge on and off", runs[0] == runs[1], "")
	var nudge := {"hot_rivets": 1.5}
	var pooled: Array = ["hot_rivets", "long_barrel"]
	_t.eq("a held maker nudge passes through when the pilot has no nemesis", PartOffers.answer_nudge("nobody", pooled, nudge), nudge)
	var merged := PartOffers.answer_nudge("tarn", pooled, nudge)
	_t.check("a maker nudge and an answer nudge multiply", is_equal_approx(merged["long_barrel"], Nemesis.OFFER_WEIGHT)
		and is_equal_approx(merged["hot_rivets"], 1.5) and nudge["hot_rivets"] == 1.5, str(merged))


# The shop shelf draws through Parts.roll: the same visits stock more answers with the nudge on.
func _shop() -> void:
	for pilot in ["demolitions_caster", "tarn"]:
		var answering: Array = _answering(pilot, Shop.SHELF_RARITIES)
		var shelves: Array = []
		for on in [true, false]:
			PartOffers.answer_nudge_on = on
			var ctx := StubCtx.new()
			ctx.run.cls = pilot
			var shop := Shop.new(ctx, null)
			var got: Array = []
			for visit in SHOP_VISITS:
				shop._rng.seed = Shop.SEED + visit * 131
				got.append(shop._stock().map(func(entry): return entry["part_id"]))
			shelves.append(got)
		PartOffers.answer_nudge_on = true
		var on_n := _count(shelves[0], answering)
		var off_n := _count(shelves[1], answering)
		print("[shop %s] %d visits: answering stock on %d, off %d" % [pilot, SHOP_VISITS, on_n, off_n])
		_t.check("%s: the shop shelf differs with the nudge on" % pilot, shelves[0] != shelves[1], "")
		_t.check("%s: the shop shelf stocks answering parts more often on" % pilot, on_n > off_n, "%d against %d" % [on_n, off_n])
