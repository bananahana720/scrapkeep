extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Parts := preload("res://src/build/parts.gd")
const PartOffers := preload("res://src/build/part_offers.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ActiveDefs := preload("res://src/combat/actives/active_defs.gd")
const ActiveOffers := preload("res://src/combat/actives/active_offers.gd")

# The slice table names twelve parts (SliceDefs.PARTS) and every source offers only those:
# the shop shelf and its reroll, a reward gate, a vault, a fabricator, a cracked cache and an
# activity. Each source is its real call, drawn 200 times on seeds 1 to 200. The same draws
# on the default table reach parts outside the twelve, which is the control: the check can
# fail. Then every kept synergy has both its parts in the twelve for each of the three
# pilots, and the list is twelve real distinct ids with at least two parts that hit harder
# and at least two at each rarity a slice source draws.

const DRAWS := 200
const SOURCES := ["shelf", "reroll", "gate", "vault", "fabricator", "cache", "activity"]

var _t := T.new("slice_parts_test")
var _game
var _done := false


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _done or _game.flow == null:
		return false
	_done = true
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_sources()
	_list()
	_game.free()
	quit(_t.verdict())
	return true


# Every part id one source offers over DRAWS seeds, as {source: [ids]}.
func _draw() -> Dictionary:
	var shop = _game.ctx.build_module().shop
	var class_id: String = _game.ctx.run.class_id()
	var held: Array = []
	var out := {}
	for source in SOURCES:
		out[source] = []
	for seed_at in range(1, DRAWS + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_at
		shop._rng.seed = seed_at
		for entry in shop._stock():
			out["shelf"].append(entry["part_id"])
		out["reroll"].append(shop._roll_one(["common", "rare"]))
		out["reroll"].append(shop._roll_one(["relic"]))
		for bonus in 3:
			out["gate"].append_array(Parts.roll_gate(rng, PartOffers.gate_rarities(bonus), class_id, held, 2, 1))
		out["vault"].append_array(Parts.roll(rng, PartOffers.SOURCE_RARITIES["vault"], class_id, held, 1))
		out["fabricator"].append_array(Parts.roll(rng, PartOffers.SOURCE_RARITIES["fabricator"], class_id, held, 1))
		out["cache"].append_array(Parts.roll(rng, ["common", "rare"], class_id, held, 3))
		out["activity"].append_array(Parts.roll(rng, ["common", "rare"], class_id, held, 1))
	return out


# Re-pinned 2026-10-24 (#445, actives on by default): the shelf also sells actives (active_offers.gd),
# which are not parts, so an offer of a known active is not outside the twelve.
func _outside(ids: Array) -> Array:
	return ids.filter(func(id): return not id in SliceDefs.PARTS and not _is_active(id))


func _is_active(id) -> bool:
	var text := String(id)
	return text.begins_with(ActiveOffers.PREFIX) and ActiveDefs.ROWS.has(text.trim_prefix(ActiveOffers.PREFIX))


func _sources() -> void:
	_t.check("the game runs the slice table", Synergies.table == SliceDefs, "table %s" % [Synergies.table])
	var slice := _draw()
	for source in SOURCES:
		var ids: Array = slice[source]
		_t.check("slice %s offers only the twelve" % source, not ids.is_empty() and _outside(ids).is_empty(),
			"%d offers, outside the twelve: %s" % [ids.size(), _outside(ids).slice(0, 5)])
	var shop = _game.ctx.build_module().shop
	var repeats := 0
	var empty_ids := 0
	for visit in DRAWS:
		shop.enter()
		var shelf_ids: Array = shop.shelf.map(func(entry): return entry["part_id"])
		if not shop.top.is_empty():
			if shop.top["part_id"] == "":
				empty_ids += 1
			elif shop.top["part_id"] in shelf_ids:
				repeats += 1
		shop.leave()
	_t.check("slice top shelf never repeats a shelf part or holds an empty id", repeats == 0 and empty_ids == 0,
		"%d visits: %d repeats, %d empty ids" % [DRAWS, repeats, empty_ids])
	# 2026-10-04: the default table takes the alpha ruleset, so it no longer reaches parts outside
	# the twelve; the control is an unfiltered table (null), which still does.
	Synergies.set_table(null)
	var base := _draw()
	for source in SOURCES:
		if source == "shelf" or source == "reroll" or source == "gate" or source == "cache":
			_t.check("unfiltered %s reaches parts outside the twelve" % source, not _outside(base[source]).is_empty(),
				"%d offers, %d outside" % [base[source].size(), _outside(base[source]).size()])
	Synergies.set_table(SliceDefs)


func _list() -> void:
	var ids: Array = SliceDefs.PARTS
	var seen := {}
	for id in ids:
		seen[id] = true
	_t.check("twelve distinct real ids", ids.size() == 12 and seen.size() == 12 and ids.all(func(id): return Parts.rows().has(id)),
		"%d ids, %d distinct" % [ids.size(), seen.size()])
	_t.check("part_in_play follows the list", ids.all(func(id): return SliceDefs.part_in_play(id)) and not SliceDefs.part_in_play("tempest_core")
		and not StageDefs.part_in_play("tempest_core") and StageDefs.parts_listed(), "list, a milestone and the default table (alpha ruleset since 2026-10-04)")
	var harder := ids.filter(func(id): return Parts.def(id).hits_harder())
	_t.check("at least two hit harder", harder.size() >= 2, "hits harder: %s" % [harder])
	for rarity in ["common", "rare"]:
		var at := ids.filter(func(id): return Parts.def(id).rarity == rarity)
		_t.check("at least two %s" % rarity, at.size() >= 2, "%s: %s" % [rarity, at])
	for pilot in ClassDef.all():
		var pool: Array = Parts.offer_pool(pilot.id, ["common", "rare", "relic"])
		var awake: Array = Synergies.active(Parts.maker_counts(pool))
		for synergy in SliceDefs.SYNERGIES.filter(func(id): return not Synergies.told_on_wake(id)):
			_t.check("%s completes for %s" % [synergy, pilot.id], synergy in awake, "pool of %d for this pilot wakes %s" % [pool.size(), awake])
