# smoke: timeout=300s (179.1 s on stage/alpha-w18 fcddfe10 on 2026-10-24, killed at the 180 s default cap in full-gate shard D)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Parts := preload("res://src/build/parts.gd")
const Shop := preload("res://src/build/shop.gd")

# SG13 visible offer odds. Every part source draws from one pool, and every offer shows the
# rarities it can contain with their weights, read from the one data row the roll reads
# (ItemGen.TIER_WEIGHTS):
#   - the shown weights are that row's, and each table's shares sum to 1;
#   - 10,000 draws per table land within a stated tolerance of the shown shares, both at the
#     rarity pick and through Parts.roll (the door every source uses);
#   - the find, shop, top-shelf and pocket id lists are subsets of one pool;
#   - the shelf record carries its odds, and the top shelf's own;
#   - a stand shows its pay table before commit and the part it pays sits inside it, over
#     20 seeds, for every kind; a named part shows its own tier.
# Two planted failures prove the matcher and the row count can fail. This does not qualify
# how the readout looks or reads in play.

const DRAWS := 10000
const SEEDS := 20
const KINDS := ["cracked_cache", "ambush_altar", "hauler_bounty", "enemy_camp"]
# A draw table's observed share must sit within this many standard errors of the shown share
# (the floor keeps a 3% tier from demanding a hair).
const TOLERANCE_SD := 4.5
const TOLERANCE_FLOOR := 0.01

var _t := preload("res://tests/support/t.gd").new("visible_odds_test")
var _game


func _initialize() -> void:
	_run()


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "alpha"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = Intent.Scripted.new()
	_game.world.set_physics_process(false)
	_game.world.activities.set_physics_process(false)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	await physics_frame
	_game.world.activities.clear()
	_row()
	_frequencies()
	_one_pool()
	_shelf()
	_stands()
	_readout()
	_planted()
	_game.free()
	quit(_t.verdict())


# Every table a part source draws from, named by its owner's own constant.
func _tables() -> Dictionary:
	return {
		"shelf": Shop.SHELF_RARITIES, "shelf floor": Shop.FLOOR_RARITIES, "top shelf": Shop.TOP_RARITIES, "pocket pay": Activities.PAY_RARITIES,
		"cache pick": CrackedCache.PICK_RARITIES, "fabricator": Parts.SOURCE_RARITIES["fabricator"],
		"vault": Parts.SOURCE_RARITIES["vault"], "milestone": Parts.SOURCE_RARITIES["milestone"],
		"gate 0 cores": Parts.gate_rarities(0), "gate 1 core": Parts.gate_rarities(1), "gate 2 cores": Parts.gate_rarities(2),
	}


# True when `shown` is exactly the table's rows read from the one weight row.
func _matches_row(shown: Array, table: Array) -> bool:
	var want := ItemGen.resolve_rarities(table)
	if shown.size() != want.size() or shown.is_empty():
		return false
	var total := 0.0
	for r in want:
		total += float(ItemGen.TIER_WEIGHTS[r])
	for i in want.size():
		var row: Dictionary = shown[i]
		if row.get("rarity", "") != want[i] or not is_equal_approx(float(row.get("weight", -1.0)), float(ItemGen.TIER_WEIGHTS[want[i]])):
			return false
		if total > 0.0 and not is_equal_approx(float(row.get("share", -1.0)), float(ItemGen.TIER_WEIGHTS[want[i]]) / total):
			return false
	return true


func _row() -> void:
	for r in ItemGen.RARITIES:
		_t.check("%s: RARITY weight is the weight row's" % r, ItemGen.TIER_WEIGHTS.has(r) and float(ItemGen.RARITY[r]["weight"]) == float(ItemGen.TIER_WEIGHTS[r]),
			"%s vs %s" % [ItemGen.RARITY[r]["weight"], ItemGen.TIER_WEIGHTS.get(r, "none")])
	_t.eq("weight row keys are the four rarities", ItemGen.TIER_WEIGHTS.keys(), ItemGen.RARITIES)
	var tables := _tables()
	_t.check("table count is nonzero", tables.size() >= 10, str(tables.size()))
	for name in tables:
		var odds: Array = ItemGen.odds(tables[name])
		_t.check("%s: shown odds are the weight row's" % name, _matches_row(odds, tables[name]), var_to_str(odds))
		var sum := 0.0
		for row in odds:
			sum += float(row["share"])
		_t.near("%s: shares sum to one" % name, sum, 1.0, 0.0001)


# The table's rarities that hold at least one part for the run's class, derived from the pool
# itself and not from the code under test.
func _avail(table: Array) -> Array:
	var class_id: String = _game.ctx.run.class_id()
	return ItemGen.resolve_rarities(table).filter(func(r): return not Parts.offer_pool(class_id, [r]).is_empty())


func _tolerance(share: float) -> float:
	return maxf(TOLERANCE_FLOOR, TOLERANCE_SD * sqrt(share * (1.0 - share) / float(DRAWS)))


func _check_frequencies(label: String, counts: Dictionary, odds: Array) -> void:
	_t.eq("%s: draws counted" % label, _sum(counts.values()), DRAWS)
	for row in odds:
		var seen := float(counts.get(row["rarity"], 0)) / float(DRAWS)
		var tol := _tolerance(float(row["share"]))
		_t.check("%s: %s observed %.4f vs shown %.4f" % [label, row["rarity"], seen, float(row["share"])],
			absf(seen - float(row["share"])) <= tol, "tolerance %.4f" % tol)
	for key in counts:
		_t.check("%s: %s was a shown rarity" % [label, key], _shown_rarity(odds, String(key)), str(key))


func _shown_rarity(odds: Array, rarity: String) -> bool:
	for row in odds:
		if row["rarity"] == rarity:
			return true
	return false


func _sum(values: Array) -> int:
	var n := 0
	for v in values:
		n += int(v)
	return n


func _frequencies() -> void:
	var class_id: String = _game.ctx.run.class_id()
	var tables := _tables()
	var seed_at := 9000
	for name in tables:
		var rarities: Array = tables[name]
		var odds: Array = ItemGen.odds(rarities)
		seed_at += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_at
		var picked := {}
		for i in DRAWS:
			var r := ItemGen.pick_rarity(rng, rarities)
			picked[r] = int(picked.get(r, 0)) + 1
		_check_frequencies("%s pick" % name, picked, odds)
		# The same table through the door every source uses, one slot at a time and nothing held.
		var rolled := {}
		for i in DRAWS:
			var ids: Array = Parts.roll(rng, rarities, class_id, [], 1)
			if ids.is_empty():
				continue
			var r := _rarity_of_id(String(ids[0]))
			rolled[r] = int(rolled.get(r, 0)) + 1
		# What Parts.roll can deliver: the table's rarities that hold a part for this class. A rarity
		# with no part is not shown; a table with none shows nothing and rolls nothing.
		var live := _avail(rarities)
		var shown: Array = Parts.odds_for(rarities, class_id)
		_t.check("%s: roll table shows what the pool holds %s" % [name, live], live.is_empty() == shown.is_empty() and (live.is_empty() or _matches_row(shown, live)), var_to_str(shown))
		if live.is_empty():
			_t.eq("%s: an empty table rolls nothing" % name, rolled.size(), 0)
		else:
			_check_frequencies("%s roll" % name, rolled, shown)


func _rarity_of_id(part_id: String) -> String:
	if ItemGen.is_generated(part_id):
		return String(ItemGen.parse(part_id).get("rarity", ""))
	return Parts.rarity_of(part_id)


func _one_pool() -> void:
	var class_id: String = _game.ctx.run.class_id()
	var pool: Array = Parts.offer_pool(class_id, ItemGen.RARITIES)
	_t.check("the pool has parts", pool.size() >= 10, str(pool.size()))
	var tables := _tables()
	for name in tables:
		var list: Array = Parts.offer_pool(class_id, tables[name])
		var outside := list.filter(func(key): return not key in pool)
		_t.check("%s list is a subset of the pool (%d ids)" % [name, list.size()], outside.is_empty(), str(outside))
	# What a real roll hands out is an id of the pool or a recipe that parses.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var strays: Array = []
	var rolled := 0
	for name in ["shelf", "top shelf", "pocket pay", "cache pick", "vault"]:
		for i in 400:
			for id in Parts.roll(rng, tables[name], class_id, [], 3):
				rolled += 1
				if not (id in pool or (ItemGen.is_generated(id) and not ItemGen.parse(id).is_empty())):
					strays.append("%s:%s" % [name, id])
	_t.check("rolled ids come from the pool (%d ids)" % rolled, rolled > 0 and strays.is_empty(), str(strays.slice(0, 5)))


func _shelf() -> void:
	var shop = _game.ctx.build.shop
	shop.enter()
	_t.check("the shelf is stocked", shop.shelf.size() == Shop.SHELF_SIZE, str(shop.shelf.size()))
	var live := _avail(Shop.SHELF_RARITIES)
	_t.eq("the shelf table holds both its rarities", live, Shop.SHELF_RARITIES)
	# The cobalt rung: slot 0 draws from the floor table and shows its odds; the rest the shelf's.
	var floor_live := _avail(Shop.FLOOR_RARITIES)
	var tables := func(i: int) -> Array: return floor_live if i == 0 else live
	for i in shop.shelf.size():
		var entry: Dictionary = shop.shelf[i]
		_t.check("shelf record %s carries its odds" % entry["part_id"], entry.has("odds") and _matches_row(entry["odds"], tables.call(i)), var_to_str(entry.get("odds", "none")))
	_t.check("shelf slot 0 is cobalt or better", Parts.rung_of(shop.shelf[0]["part_id"]) >= Parts.RUNG_FLOOR, shop.shelf[0]["part_id"])
	for offer in shop.shelf_offers():
		var want := ItemGen.odds(tables.call(int(offer["index"])))
		_t.eq("offer %d odds equal its table's" % offer["index"], offer.get("odds", []), want)
		_t.eq("offer %d odds text is the readout's" % offer["index"], offer.get("odds_text", ""), ItemGen.odds_text(want))
	var top: Dictionary = shop.top_shelf()
	_t.check("the top shelf has a part", not top.is_empty(), var_to_str(top))
	if not top.is_empty():
		var table: Array = Shop.TOP_RARITIES if Parts.rarity_of(top["part_id"]) in Shop.TOP_RARITIES else Shop.SHELF_RARITIES
		_t.check("the top shelf carries the odds of the table it drew from", _matches_row(top.get("odds", []), _avail(table)), var_to_str(top.get("odds", "none")))
	shop.reroll()
	var rerolled := range(shop.shelf.size()).all(func(i): return shop.shelf[i].has("odds") and _matches_row(shop.shelf[i]["odds"], tables.call(i)))
	_t.check("a rerolled shelf carries odds too", rerolled and Parts.rung_of(shop.shelf[0]["part_id"]) >= Parts.RUNG_FLOOR, "reroll")


func _paid(kind: String, pay: Dictionary, seed_value: int) -> Dictionary:
	var acts = _game.world.activities
	acts.clear()
	_game.ctx.rng.seed = seed_value
	var spec := {"id": kind, "at": Vector2(0.0, 0.0)}
	if not pay.is_empty():
		spec["pay"] = pay
	var s = acts._build(kind, Vector2(0.0, 0.0), spec)
	acts.sites.append(s)
	var shown: Dictionary = acts.stand_odds(s)
	acts._finish(s, Vector3.ZERO)
	return {"shown": shown, "part": String(s.pickup_part)}


func _stands() -> void:
	var rows := 0
	var cases := [{}, {"rarities": ["rare"]}, {"rarities": ["common"]}, {"named": "hot_rivets", "rarities": ["rare"]}]
	for kind in KINDS:
		for pay in cases:
			for i in SEEDS:
				var got := _paid(kind, pay, 500 + i)
				var shown: Dictionary = got["shown"]
				var part: String = got["part"]
				rows += 1
				var rarity := _rarity_of_id(part)
				var table: Array = shown.get("rarities", [])
				var expected: Array = table if String(shown.get("named", "")) != "" else _avail(table)
				var ok := part != "" and rarity in table and _matches_row(shown.get("odds", []), expected) \
						and String(shown.get("text", "")) == ItemGen.odds_text(shown.get("odds", []))
				if not ok:
					_t.check("%s %s seed %d: shown table holds the paid rarity" % [kind, var_to_str(pay), i], false, "paid %s (%s), shown %s" % [part, rarity, var_to_str(shown)])
				# A named part the table offers is paid as itself, so the stand shows its own tier.
				if String(shown.get("named", "")) != "":
					if part != shown["named"] or table != [Parts.rarity_of(part)]:
						_t.check("%s named stand shows its part's tier" % kind, false, "paid %s, shown %s" % [part, var_to_str(shown)])
						ok = false
	_t.check("stand rows were checked (%d)" % rows, rows == KINDS.size() * cases.size() * SEEDS, str(rows))
	_t.check("every stand's shown table held its paid rarity", _t.failures == 0, "%d rows" % rows)
	# Without a pay key the stand shows the rule's own table.
	for kind in ["cracked_cache", "ambush_altar", "hauler_bounty"]:
		var s = _game.world.activities._build(kind, Vector2.ZERO, {"id": kind, "at": Vector2.ZERO})
		_t.eq("%s default stand shows the pay rarities" % kind, _game.world.activities.stand_odds(s).get("rarities", []), ItemGen.resolve_rarities(Activities.RULES[kind]["pay"]["rarities"]))
		s.queue_free()


func _readout() -> void:
	var odds := ItemGen.odds(["common", "rare"])
	var text := ItemGen.odds_text(odds)
	_t.check("the readout names each rarity and its percent", "FIELD KIT" in text and "FLEET GRADE" in text and "%d%%" % roundi(float(odds[0]["share"]) * 100.0) in text, text)
	_t.check("a zero-weight rarity is not listed", not "EVOLVED" in ItemGen.odds_text(ItemGen.odds(["common", "evolved"])), ItemGen.odds_text(ItemGen.odds(["common", "evolved"])))
	_t.eq("an empty table reads empty", ItemGen.odds_text([]), "")
	# A table whose rarity holds no part shows only the rarities that do (relic holds none here).
	var class_id: String = _game.ctx.run.class_id()
	_t.eq("a rarity with no part is not shown", Parts.odds_for(["rare", "relic"], class_id).map(func(row): return row["rarity"]), _avail(["rare", "relic"]))
	_t.eq("a table with no part shows nothing", Parts.odds_for(["evolved"], class_id), [])
	for row in ItemGen.odds_rows(odds):
		_t.check("readout row %s has a colour, a label and a percent" % row["rarity"], row.has("color") and String(row["label"]) != "" and int(row["percent"]) > 0, var_to_str(row))


# The matcher and the count must be able to fail.
func _planted() -> void:
	var odds := ItemGen.odds(Shop.SHELF_RARITIES)
	var stale: Array = odds.duplicate(true)
	stale[0]["weight"] = float(stale[0]["weight"]) + 1.0
	_t.check("planted stale weight is caught", not _matches_row(stale, Shop.SHELF_RARITIES), "weight off by one")
	var swapped: Array = odds.duplicate(true)
	swapped[0]["rarity"] = "relic"
	_t.check("planted wrong rarity is caught", not _matches_row(swapped, Shop.SHELF_RARITIES), "relic for common")
	_t.check("planted empty odds list is caught", not _matches_row([], Shop.SHELF_RARITIES), "empty")
	var lopsided := {"common": 9990, "rare": 10}
	var before := _t.failures
	_check_frequencies("planted lopsided", lopsided, odds)
	_t.check("planted lopsided draws fail the frequency check", _t.failures > before, "failures %d to %d" % [before, _t.failures])
	_t.failures = before
