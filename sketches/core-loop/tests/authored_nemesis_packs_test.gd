extends SceneTree

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Cards := preload("res://src/world/director_cards.gd")
const Director := preload("res://src/world/director.gd")
const AttackBudget := preload("res://src/combat/attack_budget.gd")
const T := preload("res://tests/support/t.gd")

# W18-PACKS: the authored pack tables give every pilot something to meet and something to be
# spared, so the nemesis lean (nemesis.gd, director.gd _draw_authored) has contrast to act on.
# Per pilot class id and per stage of worlds 2 and 3: at least one pack presses the pilot's
# nemesis axis and at least one does not. Kill-first packs (a Foreman or a Dispatcher) are none
# in stage 1 and a quarter to two fifths of a stage's packs from stage 2 on, rising by world.
# Every pack must be a purchasable priced group whose size fits the stage's crowd cap and the
# attacker budget, and whose price does not pass the stage's own elite.

const KILL_FIRST := ["foreman", "dispatcher"]
const SHARE_MIN := 0.25
const SHARE_MAX := 0.40

var _t := T.new("authored_nemesis_packs_test")


func _initialize() -> void:
	_contrast()
	_kill_first()
	_budget()
	_control()
	quit(_t.verdict())


# Whether `packs` holds a pack that presses `class_id`'s axes and one that does not.
func _has_contrast(class_id: String, packs: Array) -> bool:
	var presses := 0
	var spared := 0
	for pack in packs:
		if Nemesis.pack_presses(class_id, pack["kinds"]):
			presses += 1
		else:
			spared += 1
	return presses >= 1 and spared >= 1


func _contrast() -> void:
	for stage in range(3, AlphaDefs.COUNT + 1):
		var row := AlphaDefs.of(stage)
		for class_id in Nemesis.PILOT:
			_t.check("stage %d (world %d): %s has a pressing and a sparing pack" % [stage, row["world"], class_id],
				_has_contrast(class_id, row["packs"]),
				str(row["packs"].map(func(p): return "%s:%s" % [p["id"], Nemesis.pack_presses(class_id, p["kinds"])])))


func _share(packs: Array) -> float:
	var n := 0
	for pack in packs:
		if pack["kinds"].any(func(k): return k in KILL_FIRST):
			n += 1
	return float(n) / float(packs.size())


func _kill_first() -> void:
	_t.eq("stage 1 has no kill-first pack", _share(AlphaDefs.of(1)["packs"]), 0.0)
	var world_packs := {}
	for stage in range(1, AlphaDefs.COUNT + 1):
		var row := AlphaDefs.of(stage)
		var share := _share(row["packs"])
		var w: int = row["world"]
		if not world_packs.has(w):
			world_packs[w] = []
		world_packs[w].append_array(row["packs"])
		if stage >= 2:
			_t.check("stage %d kill-first share %.3f in [%.2f, %.2f]" % [stage, share, SHARE_MIN, SHARE_MAX],
				share >= SHARE_MIN and share <= SHARE_MAX)
	var s1 := _share(world_packs[1])
	var s2 := _share(world_packs[2])
	var s3 := _share(world_packs[3])
	_t.check("kill-first share rises by world (%.3f, %.3f, %.3f)" % [s1, s2, s3], s1 < s2 and s2 < s3)
	_t.check("stage 6 share is between %.2f and %.2f" % [SHARE_MIN, SHARE_MAX],
		_share(AlphaDefs.of(6)["packs"]) >= SHARE_MIN and _share(AlphaDefs.of(6)["packs"]) <= SHARE_MAX)
	var splitters := 0
	for stage in range(2, 5):
		for pack in AlphaDefs.of(stage)["packs"]:
			splitters += int("splitter" in pack["kinds"])
	_t.check("the Splitter is in a few packs of stages 2 to 4 (%d)" % splitters, splitters >= 3)


func _budget() -> void:
	for stage in range(1, AlphaDefs.COUNT + 1):
		var row := AlphaDefs.of(stage)
		var d = Director.new(1)
		d.use_row(row)
		d.threat = row.get("threat", 1.0)
		var crowd: int = d.cap()
		var attackers: int = AttackBudget.cap_at(1, int(row["world"]))
		var elite_cost: float = Cards.cost(row["elite"]["kinds"], true)
		var ids := {}
		for pack in row["packs"]:
			var price: float = Cards.cost(pack["kinds"])
			var detail := "%s kinds=%s price=%s crowd=%d attackers=%d elite=%s" % [pack["id"], pack["kinds"], price, crowd, attackers, elite_cost]
			_t.check("stage %d pack %s is priced, fits the crowd and attacker caps, and costs no more than the elite" % [stage, pack["id"]],
				is_finite(price) and price > 0.0 and pack["kinds"].size() <= crowd and pack["kinds"].size() <= attackers and price <= elite_cost, detail)
			_t.check("stage %d pack id %s is unique" % [stage, pack["id"]], not ids.has(pack["id"]))
			ids[pack["id"]] = true


# Planted negatives: a table with no pressing pack for Sable, one with no sparing pack, and the
# shipped table with its plating packs struck must all fail the contrast check.
func _control() -> void:
	var no_plating := [
		{"id": "a", "kinds": ["chaser", "lobber"]},
		{"id": "b", "kinds": ["burrower", "lamp_swarm"]},
	]
	_t.check("control: a table with no plating pack fails for Sable", not _has_contrast("pylon_engineer", no_plating))
	var all_plating := [{"id": "a", "kinds": ["plated_brute"]}, {"id": "b", "kinds": ["deflector", "chaser"]}]
	_t.check("control: a table where every pack presses fails for Sable", not _has_contrast("pylon_engineer", all_plating))
	_t.check("control: the same two tables pass once one pack is swapped", _has_contrast("pylon_engineer", [no_plating[0], all_plating[0]]))
	var stripped: Array = AlphaDefs.of(3)["packs"].filter(func(p): return not Nemesis.pack_presses("pylon_engineer", p["kinds"]))
	_t.check("control: stage 3 with its plating packs struck fails for Sable", not _has_contrast("pylon_engineer", stripped))
	var oversized := ["chaser", "chaser", "chaser", "chaser", "chaser"]
	_t.check("control: a five-chaser pack exceeds the stage cap and prices infinite", not is_finite(Cards.cost(oversized)))
