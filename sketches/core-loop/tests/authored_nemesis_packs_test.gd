extends SceneTree

const AlphaDefs := preload("res://src/core/alpha_defs.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Nemesis := preload("res://src/combat/nemesis.gd")
const Cards := preload("res://src/core/director_cards.gd")
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

# Park-table kill-first kinds: the park table holds no Linker pack (the alpha table has four), so the Linker is not counted here.
const KILL_FIRST := ["foreman", "dispatcher"]
const SHARE_MIN := 0.25
const SHARE_MAX := 0.40

var _t := T.new("authored_nemesis_packs_test")
var _table
var _name := ""


func _initialize() -> void:
	for pair in [["alpha: ", AlphaDefs], ["park: ", ParkDefs]]:
		_name = pair[0]
		_table = pair[1]
		_contrast()
		_kill_first()
		_budget()
		_control()
		_plate_press()
	_name = ""
	_same_tables()
	quit(_t.verdict())


# The played table (park_defs.gd, KD7) keeps its own copy of the pack lists; stages 1 to 6 must
# carry the same pack ids and kinds as alpha_defs.gd. The four *_linked packs are alpha-only
# (the Linker is not on the park table), so they are set aside on both sides.
func _same_tables() -> void:
	for stage in range(1, AlphaDefs.COUNT + 1):
		var a := _comparable(AlphaDefs.of(stage)["packs"])
		var p := _comparable(ParkDefs.of(stage)["packs"])
		_t.eq("stage %d: park and alpha pack ids and kinds match" % stage, p, a)
	var drifted := _comparable(ParkDefs.of(3)["packs"]).duplicate(true)
	drifted.pop_back()
	_t.check("control: a park table missing a pack differs from alpha", drifted != _comparable(AlphaDefs.of(3)["packs"]))


func _comparable(packs: Array) -> Array:
	var out := []
	for pack in packs:
		if not String(pack["id"]).ends_with("_linked"):
			out.append([pack["id"], pack["kinds"]])
	return out


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
	for stage in range(3, _table.COUNT + 1):
		var row: Dictionary = _table.of(stage)
		for class_id in Nemesis.PILOT:
			_t.check(_name + "stage %d (world %d): %s has a pressing and a sparing pack" % [stage, row["world"], class_id],
				_has_contrast(class_id, row["packs"]),
				str(row["packs"].map(func(p): return "%s:%s" % [p["id"], Nemesis.pack_presses(class_id, p["kinds"])])))


func _share(packs: Array) -> float:
	var n := 0
	for pack in packs:
		if pack["kinds"].any(func(k): return k in KILL_FIRST):
			n += 1
	return float(n) / float(packs.size())


func _kill_first() -> void:
	_t.eq(_name + "stage 1 has no kill-first pack", _share(_table.of(1)["packs"]), 0.0)
	var world_packs := {}
	for stage in range(1, _table.COUNT + 1):
		var row: Dictionary = _table.of(stage)
		var share: float = _share(row["packs"])
		var w: int = row["world"]
		if not world_packs.has(w):
			world_packs[w] = []
		world_packs[w].append_array(row["packs"])
		if stage >= 2:
			_t.check(_name + "stage %d kill-first share %.3f in [%.2f, %.2f]" % [stage, share, SHARE_MIN, SHARE_MAX],
				share >= SHARE_MIN and share <= SHARE_MAX)
	var s1 := _share(world_packs[1])
	var s2 := _share(world_packs[2])
	var s3 := _share(world_packs[3])
	_t.check(_name + "kill-first share rises by world (%.3f, %.3f, %.3f)" % [s1, s2, s3], s1 < s2 and s2 < s3)
	_t.check(_name + "stage 6 share is between %.2f and %.2f" % [SHARE_MIN, SHARE_MAX],
		_share(_table.of(6)["packs"]) >= SHARE_MIN and _share(_table.of(6)["packs"]) <= SHARE_MAX)
	var splitters := 0
	for stage in range(3, 5):
		for pack in _table.of(stage)["packs"]:
			splitters += int("splitter" in pack["kinds"])
	_t.check(_name + "the Splitter is in packs of stages 3 and 4 (%d)" % splitters, splitters >= 2)


func _budget() -> void:
	for stage in range(1, _table.COUNT + 1):
		var row: Dictionary = _table.of(stage)
		# The smallest crowd the stage can reach: director.gd _authored_arrival keeps a drawn pack
		# until the cap has room for all of it, so a pack (or the elite) over the lowest cap any
		# Breath option gives stops that stage spawning for good.
		var crowd := 1 << 30
		for breath in Director.BREATH:
			var d = Director.new(1)
			d.use_row(row, breath)
			d.threat = row.get("threat", 1.0)
			crowd = mini(crowd, d.cap())
		var attackers: int = AttackBudget.cap_at(1, int(row["world"]))
		var elite_cost: float = Cards.cost(row["elite"]["kinds"], true)
		_t.check(_name + "stage %d elite fits the lowest crowd cap" % stage, row["elite"]["kinds"].size() <= crowd,
			"%s crowd=%d" % [row["elite"]["kinds"], crowd])
		var ids := {}
		for pack in row["packs"]:
			var price: float = Cards.cost(pack["kinds"])
			var detail := "%s kinds=%s price=%s crowd=%d attackers=%d elite=%s" % [pack["id"], pack["kinds"], price, crowd, attackers, elite_cost]
			_t.check(_name + "stage %d pack %s is priced, fits the crowd and attacker caps, and costs no more than the elite" % [stage, pack["id"]],
				is_finite(price) and price > 0.0 and pack["kinds"].size() <= crowd and pack["kinds"].size() <= attackers and price <= elite_cost, detail)
			_t.check(_name + "stage %d pack id %s is unique" % [stage, pack["id"]], not ids.has(pack["id"]))
			ids[pack["id"]] = true


# Planted negatives: a table with no pressing pack for Sable, one with no sparing pack, and the
# shipped table with its plating packs struck must all fail the contrast check.
func _control() -> void:
	var no_plating := [
		{"id": "a", "kinds": ["chaser", "lobber"]},
		{"id": "b", "kinds": ["burrower", "lamp_swarm"]},
	]
	_t.check(_name + "control: a table with no plating pack fails for Sable", not _has_contrast("pylon_engineer", no_plating))
	var all_plating := [{"id": "a", "kinds": ["plated_brute"]}, {"id": "b", "kinds": ["deflector", "chaser"]}]
	_t.check(_name + "control: a table where every pack presses fails for Sable", not _has_contrast("pylon_engineer", all_plating))
	_t.check(_name + "control: the same two tables pass once one pack is swapped", _has_contrast("pylon_engineer", [no_plating[0], all_plating[0]]))
	var stripped: Array = _table.of(3)["packs"].filter(func(p): return not Nemesis.pack_presses("pylon_engineer", p["kinds"]))
	_t.check(_name + "control: stage 3 with its plating packs struck fails for Sable", not _has_contrast("pylon_engineer", stripped))
	var oversized := ["chaser", "chaser", "chaser", "chaser", "chaser"]
	_t.check(_name + "control: a five-chaser pack exceeds the stage cap and prices infinite", not is_finite(Cards.cost(oversized)))


# W18-PLATEPRESS: two plated rigs and a ballast heavy press the plating axis (ENEMY-PRIORITY.md
# section 5). The pack sits in the Highdraft only: a ninth pack in a Dig stage would drop the
# alpha table's kill-first share under SHARE_MIN. Plating is the axis of Sable (pylon_engineer)
# and Tally; Tarn, the Runner (spread), the Caster and the Cannon are spared by it.
func _plate_press() -> void:
	var pressed := ["pylon_engineer", "tally"]
	var spared := ["tarn", "runner_gunner", "demolitions_caster", "remembered_cannon"]
	for stage in [5, 6]:
		var found := {}
		for pack in _table.of(stage)["packs"]:
			if String(pack["id"]).begins_with("plate_press"):
				found = pack
		_t.check(_name + "stage %d holds a plate_press pack" % stage, not found.is_empty())
		if found.is_empty():
			continue
		_t.eq(_name + "stage %d plate_press kinds" % stage, found["kinds"], ["plated_brute", "swatter"])
		for id in pressed:
			_t.check(_name + "stage %d plate_press presses %s" % [stage, id], Nemesis.pack_presses(id, found["kinds"]))
		for id in spared:
			_t.check(_name + "stage %d plate_press spares %s" % [stage, id], not Nemesis.pack_presses(id, found["kinds"]))
	# Planted negative: the stage-5 table with the pack struck no longer holds a pack of that shape
	# that presses Sable and spares Tarn, so the same check fails.
	var struck: Array = _table.of(5)["packs"].filter(func(p): return not String(p["id"]).begins_with("plate_press"))
	_t.check(_name + "control: a table without the plate_press pack fails the plating-press check for Sable", not _has_press_shape(struck))
	_t.check(_name + "the shipped stage 5 table passes that check", _has_press_shape(_table.of(5)["packs"]))


func _has_press_shape(packs: Array) -> bool:
	for pack in packs:
		if pack["kinds"] == ["plated_brute", "swatter"] and Nemesis.pack_presses("pylon_engineer", pack["kinds"]) and not Nemesis.pack_presses("tarn", pack["kinds"]):
			return true
	return false
