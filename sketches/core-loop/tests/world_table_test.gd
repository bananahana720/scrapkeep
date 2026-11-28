extends SceneTree

const T := preload("res://tests/support/t.gd")
const Worlds := preload("res://src/core/worlds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const DigTable := preload("res://tests/doubles/dig_table_defs.gd")
const HighdraftTable := preload("res://tests/doubles/highdraft_table_defs.gd")
const HighdraftWorldThree := preload("res://tests/doubles/highdraft_world_three_defs.gd")
const RowPacks := preload("res://tests/doubles/row_packs_defs.gd")

# The world helpers on the three tables, and the world and boss rows in worlds.gd.


func _initialize() -> void:
	var t := T.new("world_table_test")
	_default(t)
	_slice(t)
	_double(t)
	_doubles_protocol(t)
	_rows(t)
	quit(t.verdict())


func _default(t) -> void:
	t.eq("default maps", StageDefs.DEFS.map(func(row): return row["map"]), ["spillway", "reach", "dig", "dig_deep", "highdraft", "highdraft_crown"])
	t.eq("default count", StageDefs.COUNT, StageDefs.DEFS.size())
	for s in range(1, StageDefs.COUNT + 1):
		var w := ceili(s / 2.0)
		t.eq("default world_of %d" % s, StageDefs.world_of(s), w)
		t.eq("default local %d" % s, StageDefs.local(s), (s - 1) % 2 + 1)
		t.eq("default is_world_last %d" % s, StageDefs.is_world_last(s), s % 2 == 0)
		t.eq("default is_run_last %d" % s, StageDefs.is_run_last(s), s == StageDefs.COUNT)
		t.eq("default is_run_last == is_last %d" % s, StageDefs.is_run_last(s), StageDefs.is_last(s))
	for w in StageDefs.worlds():
		t.eq("default first_of %d" % w, StageDefs.first_of(w), 2 * w - 1)
		t.eq("default last_of %d" % w, StageDefs.last_of(w), 2 * w)
	t.eq("default worlds", StageDefs.worlds(), [1, 2, 3])


func _slice(t) -> void:
	t.eq("slice world_of 1", SliceDefs.world_of(1), 1)
	t.eq("slice local 1", SliceDefs.local(1), 1)
	t.eq("slice first_of 1", SliceDefs.first_of(1), 1)
	t.eq("slice last_of 1", SliceDefs.last_of(1), 1)
	t.eq("slice worlds", SliceDefs.worlds(), [1])
	t.eq("slice is_world_last 1", SliceDefs.is_world_last(1), true)
	t.eq("slice is_run_last == is_last", SliceDefs.is_run_last(1), SliceDefs.is_last(1))


func _double(t) -> void:
	var want_world := [1, 1, 1, 2, 2, 2]
	for s in range(1, 7):
		t.eq("double world_of %d" % s, TwoWorld.world_of(s), want_world[s - 1])
		t.eq("double local %d" % s, TwoWorld.local(s), (s - 1) % 3 + 1)
		t.eq("double is_world_last %d" % s, TwoWorld.is_world_last(s), s == 3 or s == 6)
		t.eq("double is_run_last %d" % s, TwoWorld.is_run_last(s), s == 6)
		t.eq("double is_last %d" % s, TwoWorld.is_last(s), s == 6)
		t.eq("double row stage %d" % s, int(TwoWorld.of(s)["stage"]), s)
	t.eq("double world_of(4) == 2", TwoWorld.world_of(4), 2)
	t.eq("double local(4) == 1", TwoWorld.local(4), 1)
	t.check("double is_world_last(3)", TwoWorld.is_world_last(3))
	t.check("double is_run_last(6)", TwoWorld.is_run_last(6))
	t.eq("double first_of 1", TwoWorld.first_of(1), 1)
	t.eq("double first_of 2", TwoWorld.first_of(2), 4)
	t.eq("double last_of 1", TwoWorld.last_of(1), 3)
	t.eq("double last_of 2", TwoWorld.last_of(2), 6)
	t.eq("double worlds", TwoWorld.worlds(), [1, 2])


func _doubles_protocol(t) -> void:
	var lobber_packs := [{"id": "table_lobbers", "kinds": ["lobber"]}]
	var lobber_elite := {"id": "table_elite", "kinds": ["lobber", "lobber"]}
	var cases := [
		["dig", DigTable, 1, [1], "dig", "reactor", lobber_packs, lobber_elite, 3],
		["highdraft", HighdraftTable, 1, [1], "highdraft", "mind", lobber_packs, lobber_elite, 3],
		["highdraft_w3", HighdraftWorldThree, 1, [3], "highdraft", "mind", lobber_packs, lobber_elite, 3],
		["row_packs", RowPacks, 2, [1], "spillway", "reactor", lobber_packs, lobber_elite, 3],
		["two_world", TwoWorld, 6, [1, 2], "spillway", "reactor", [], {}, 0],
		["first_world", TwoWorld.FirstWorld, 3, [1], "spillway", "reactor", [], {}, 0],
	]
	for item in cases:
		var tag: String = item[0]
		var tbl = item[1]
		var count: int = item[2]
		var want_worlds: Array = item[3]
		t.eq(tag + " BOSS", tbl.BOSS, "brindle")
		t.eq(tag + " COUNT", tbl.COUNT, count)
		t.eq(tag + " DEFS size", tbl.DEFS.size(), count)
		t.eq(tag + " PICK_ON_CLASS_UP", tbl.PICK_ON_CLASS_UP, false)
		t.eq(tag + " worlds", tbl.worlds(), want_worlds)
		t.eq(tag + " of(0) clamps to 1", tbl.of(0), tbl.DEFS[0])
		t.eq(tag + " of(1) map", String(tbl.of(1)["map"]), item[4])
		t.eq(tag + " of(1) warden_family", String(tbl.of(1)["warden_family"]), item[5])
		t.eq(tag + " of(COUNT + 1) clamps to last", tbl.of(count + 1), tbl.DEFS[count - 1])
		t.eq(tag + " is_last(COUNT)", tbl.is_last(count), true)
		t.eq(tag + " is_run_last(COUNT)", tbl.is_run_last(count), true)
		t.eq(tag + " is_world_last(COUNT)", tbl.is_world_last(count), true)
		if count > 1:
			t.eq(tag + " is_last(1)", tbl.is_last(1), false)
		var first_world: int = want_worlds[0]
		t.eq(tag + " world_of(1)", tbl.world_of(1), first_world)
		t.eq(tag + " local(1)", tbl.local(1), 1)
		t.eq(tag + " first_of(first)", tbl.first_of(first_world), 1)
		t.eq(tag + " last_of(last)", tbl.last_of(want_worlds.back()), count)
		t.eq(tag + " synergy_in_play", tbl.synergy_in_play("any"), true)
		t.eq(tag + " part_in_play", tbl.part_in_play("any"), true)
		t.eq(tag + " parts_listed", tbl.parts_listed(), false)
		t.eq(tag + " packs", tbl.packs(), item[6])
		t.eq(tag + " elite", tbl.elite(), item[7])
		t.eq(tag + " elite_arrival", tbl.elite_arrival(), item[8])
		t.eq(tag + " has_vault", tbl.has_vault(), true)
	for lobber_tbl in [DigTable, HighdraftTable, HighdraftWorldThree, RowPacks]:
		t.eq("lobber PACKS const", lobber_tbl.PACKS, lobber_packs)
	t.eq("row_packs stage 2 map", String(RowPacks.of(2)["map"]), "gorge")
	t.eq("first_world stage 3 local", TwoWorld.FirstWorld.local(3), 3)


func _rows(t) -> void:
	t.eq("three worlds", Worlds.ROWS.size(), 3)
	for r in Worlds.ROWS:
		var boss := String(r["boss"])
		t.check("world %d boss %s has a row" % [int(r["id"]), boss], Worlds.BOSSES.has(boss))
		t.check("world %d boss_of resolves" % int(r["id"]), not Worlds.boss_of(int(r["id"])).is_empty())
	for id in Worlds.BOSSES:
		var b: Dictionary = Worlds.BOSSES[id]
		if b["built"]:
			t.check("built boss %s script exists" % id, ResourceLoader.exists(String(b["script"])), String(b["script"]))
		else:
			t.check("unbuilt boss %s script is absent" % id, not ResourceLoader.exists(String(b["script"])), String(b["script"]))
	t.eq("default table boss is world one's", StageDefs.BOSS, String(Worlds.row(1)["boss"]))
