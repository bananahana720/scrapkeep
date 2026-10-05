# smoke: solo
extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const T := preload("res://tests/support/t.gd")

# A later world's ground builds on its first read, each world under the budget, and
# world one's setup builds only world one. Run on the table as it stands and on a copy
# that already names the second-zone maps. Evidence limit: headless wall time on a shared machine.

const WORLD_BUDGET_MS := 1500.0
const REPEAT_BUDGET_MS := 50.0

var _t := T.new("terrain_lazy_world_test")


class SwappedTable extends RefCounted:
	static var DEFS: Array = _swapped()

	static func _swapped() -> Array:
		var rows: Array = StageDefs.DEFS.duplicate(true)
		rows[3]["map"] = "dig_deep"
		rows[5]["map"] = "highdraft_crown"
		return rows


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_table(StageDefs, "current")
	_table(SwappedTable, "swapped")
	var load_out: Array = []
	OS.execute("cat", ["/proc/loadavg"], load_out)
	print("load average: ", String(load_out[0]).strip_edges() if load_out.size() > 0 else "unknown")
	quit(_t.verdict())


func _ms(from_usec: int) -> float:
	return float(Time.get_ticks_usec() - from_usec) / 1000.0


func _table(table, label: String) -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain := Terrain.new(table)
	var t0 := Time.get_ticks_usec()
	terrain.build(holder)
	var build_ms := _ms(t0)
	# 2026-10-04 (wave 11 review): red against a base that lacks the new map ids, where _init's
	# assert leaves a short maps array and is_built clamps the stage.
	_t.check("%s: one map object per row" % label, terrain.maps.size() == table.DEFS.size(),
		"%d maps for %d rows" % [terrain.maps.size(), table.DEFS.size()])
	for i in range(table.DEFS.size()):
		var want: String = Terrain.MAPS[table.DEFS[i]["map"]].resource_path.get_file()
		var got: String = terrain.map_for(i + 1).get_script().resource_path.get_file()
		_t.check("%s: row %d loads %s" % [label, i + 1, want], got == want, "got %s" % got)
	_t.check("%s: world 1 unaffected: stage 1 built at setup" % label, terrain.is_built(1))
	_t.check("%s: world 1 unaffected: stage 2 built at setup" % label, terrain.is_built(2))
	for i in [3, 4, 5, 6]:
		_t.check("%s: world 1 unaffected: stage %d not built at setup" % [label, i], not terrain.is_built(i))
	t0 = Time.get_ticks_usec()
	terrain.spawn_point(3)
	var world2_ms := _ms(t0)
	_t.check("%s: first read of stage 3 builds stages 3 and 4" % label, terrain.is_built(3) and terrain.is_built(4))
	_t.check("%s: first read of stage 3 leaves 5 and 6 unbuilt" % label, not terrain.is_built(5) and not terrain.is_built(6))
	_t.check("%s: world 2 read %.0f ms is under %.0f" % [label, world2_ms, WORLD_BUDGET_MS], world2_ms < WORLD_BUDGET_MS)
	t0 = Time.get_ticks_usec()
	terrain.spawn_point(5)
	var world3_ms := _ms(t0)
	_t.check("%s: first read of stage 5 builds stages 5 and 6" % label, terrain.is_built(5) and terrain.is_built(6))
	_t.check("%s: world 3 read %.0f ms is under %.0f" % [label, world3_ms, WORLD_BUDGET_MS], world3_ms < WORLD_BUDGET_MS)
	t0 = Time.get_ticks_usec()
	terrain.spawn_point(4)
	var repeat_ms := _ms(t0)
	_t.check("%s: repeat read %.1f ms is under %.0f" % [label, repeat_ms, REPEAT_BUDGET_MS], repeat_ms < REPEAT_BUDGET_MS)
	print("terrain_lazy_world: %s build_ms=%.1f world2_ms=%.1f world3_ms=%.1f repeat_ms=%.2f" % [label, build_ms, world2_ms, world3_ms, repeat_ms])
	holder.free()
