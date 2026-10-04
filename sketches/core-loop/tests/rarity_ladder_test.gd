extends SceneTree

const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The rarity ladder (RR1): one RARITY table (item_gen.gd) with common, rare, relic and
# evolved. Every authored row and 200 seeded generated rows carry one of those ids; a
# row that only scales percentages is never above common; old ids resolve through
# RARITY_ALIASES; a hot-wired offer draws a stripe on its topper and others do not.

var _failures := 0


# A flat floor, enough for the gates to place themselves.
class Flat extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 0.0

	func drop_point(x: float, z: float, _y: float) -> Vector3:
		return Vector3(x, 0.0, z)


func _initialize() -> void:
	_check_table()
	_check_authored()
	_check_generated()
	_check_aliases()
	await _check_stripe()
	print("rarity_ladder_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_table() -> void:
	var problems: Array = []
	if ItemGen.RARITIES != ["common", "rare", "relic", "evolved"] or ItemGen.RARITY.keys() != ItemGen.RARITIES:
		problems.append("ids %s" % [ItemGen.RARITY.keys()])
	var stamps: Dictionary = EventKinds.reward_row("reveal")["stamps"]
	for i in ItemGen.RARITIES.size():
		var id: String = ItemGen.RARITIES[i]
		var row: Dictionary = ItemGen.RARITY[id]
		if row["rung"] != i or not row["color"] is Color or float(row["weight"]) < 0.0 or String(row["stamp"]) == "":
			problems.append("row %s %s" % [id, row])
		if stamps.get(id, "") != row["stamp"]:
			problems.append("stamp %s: ceremony says %s" % [id, stamps.get(id, "")])
		if RewardGates.rarity_color(id) != row["color"]:
			problems.append("colour %s" % id)
		if not EventKinds.REWARD_TIER_BY_RARITY.has(id) or not EventKinds.REWARD_RUNGS.has(id):
			problems.append("reward maps lack %s" % id)
	if ItemGen.RARITY["evolved"]["weight"] != 0.0:
		problems.append("evolved rolls")
	_report("table", problems.is_empty(), "common, rare, relic, evolved with colour, weight, stamp, rung 0..3; problems %s" % [problems])


func _check_authored() -> void:
	var bad: Array = []
	for id in Parts.ids():
		var rarity := Parts.rarity_of(id)
		if not rarity in ItemGen.RARITIES:
			bad.append("%s %s" % [id, rarity])
		elif rarity != "common" and Parts.def(id).percentage_only():
			bad.append("%s plain %s" % [id, rarity])
	_report("authored rows", bad.is_empty(), "%d rows, every rarity one of four, none plain above common; bad %s" % [Parts.ids().size(), bad])
	# The one function that enforces the exclusion, on a row that only scales numbers.
	var settled: Dictionary = Parts._settled({"rarity": "relic", "name": "Plain"})
	var kept: Dictionary = Parts._settled({"rarity": "relic", "name": "Hits", "punch": 5.0})
	_report("scalar-only exclusion", settled["rarity"] == "common" and kept["rarity"] == "relic",
		"a plain relic row settles to %s, a punching one stays %s" % [settled["rarity"], kept["rarity"]])


func _check_generated() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bad: Array = []
	for i in 200:
		var id := ItemGen.roll_id(rng, ItemGen.RARITIES[i % 4])
		# Every tenth recipe is an old saved id, so the alias path rides along.
		if i % 10 == 0:
			id = id.replace(":common:", ":uncommon:").replace(":relic:", ":rare_plus:")
		var raw: Dictionary = ItemGen.generated_row(id)
		var d: Resource = Parts.def(id)
		if raw.is_empty() or d == null or not String(raw["rarity"]) in ItemGen.RARITIES or not d.rarity in ItemGen.RARITIES:
			bad.append("%s %s" % [id, raw.get("rarity", "none")])
		elif d.rarity != "common" and d.percentage_only():
			bad.append("%s plain %s" % [id, d.rarity])
	_report("generated rows", bad.is_empty(), "200 seeded recipes (seed 4242), every rarity one of four, none plain above common; bad %s" % [bad])


func _check_aliases() -> void:
	var bad: Array = []
	for old in ItemGen.RARITY_ALIASES:
		var id := ItemGen.resolve_rarity(old)
		if not id in ItemGen.RARITIES:
			bad.append("%s -> %s" % [old, id])
	if ItemGen.resolve_rarity("uncommon") != "common" or ItemGen.resolve_rarity("rare_plus") != "relic" or ItemGen.resolve_rarity("nope") != "":
		bad.append("fold")
	var rolled := Parts.roll(RandomNumberGenerator.new(), ["common", "uncommon", "rare"], "pylon_engineer", [], 3)
	if rolled.is_empty() or rolled.any(func(id): return not Parts.rarity_of(id) in ["common", "rare"]):
		bad.append("old ids to roll: %s" % [rolled])
	_report("aliases", bad.is_empty(), "uncommon to common, rare_plus to relic, old ids accepted by roll; bad %s" % [bad])


func _check_stripe() -> void:
	var gates := RewardGates.new()
	root.add_child(gates)
	await process_frame
	gates.setup(Flat.new())
	var ids := ["riveted_shell", "pin_setter", "ten_pin"]
	var offers := gates.open(ids, Vector3.ZERO, Vector3.FORWARD, [])
	var bad: Array = []
	for i in offers.size():
		var offer: Dictionary = offers[i]
		var want: bool = ids[i] == "riveted_shell"
		var stripe := gates._gates[i].find_child("Stripe", true, false)
		if bool(offer["hotwired"]) != want or (stripe != null) != want:
			bad.append("%s hotwired %s stripe %s" % [ids[i], offer["hotwired"], stripe != null])
		if offer["rarity"] != Parts.rarity_of(ids[i]):
			bad.append("%s rarity changed" % ids[i])
	_report("hot-wired stripe", offers.size() == 3 and bad.is_empty(), "%d offers; the hot-wired one wears a stripe, the others none; bad %s" % [offers.size(), bad])
	gates.close()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
