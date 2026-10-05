extends SceneTree

const T := preload("res://tests/support/t.gd")
const Worlds := preload("res://src/core/worlds.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")

# The world helpers on the three tables, and the world and boss rows in worlds.gd.


func _initialize() -> void:
	var t := T.new("world_table_test")
	_default(t)
	_slice(t)
	_double(t)
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
