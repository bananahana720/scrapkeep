extends "res://tests/rivet_kit_test.gd"

# Hitch guard (#73, 2026-10-18). A park shares one Shape3D across many colliders. Keyed by shape
# alone, the terrain warm-up rebuilt every placement each cycle: 100 to 175 ms physics ticks
# every 0.5 s while Rivet stood still (the revert of 8e40be12). Keyed by shape and transform, a
# standing Rivet's warm-up finds everything cached after the first cycle. Counts, not times, so
# it holds on any machine. Expected: 11 checks, including the count assertion.
# 2026-11-11 (speed pass): a park's convex wedges share point lists, so their faces are searched
# once per point list; the kept faces equal a fresh search, and another wedge gets its own.

const PLACEMENTS := 24
const CYCLES := 10
# Misses per warm-up cycle allowed once warm: none are expected; one covers a stray body.
const MISSES_PER_CYCLE_MAX := 1


func _initialize() -> void:
	_t = T.new("rivet_warm_hitch_test")
	_expected_checks = 11
	super._initialize()


func _park() -> Shape3D:
	var shared := BoxShape3D.new()
	shared.size = Vector3(4.0, 1.0, 4.0)
	var centre: Vector3 = _player.ball_position()
	for i in PLACEMENTS:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collision := CollisionShape3D.new()
		collision.shape = shared
		body.add_child(collision)
		_game.add_child(body)
		body.global_position = centre + Vector3(-30.0 + 5.0 * float(i % 12), -0.5, -8.0 - 6.0 * float(i / 12))
	await physics_frame
	await physics_frame
	return shared


# Builds started over `CYCLES` further warm-up cycles after the first; the first's builds too.
func _stand(kit_terrain: TerrainFaces) -> Dictionary:
	_kit.terrain.finish()
	_kit.terrain = kit_terrain
	var before := kit_terrain.builds
	var cycles_before: int = _kit.warm_cycles
	_kit.warm_cycle()
	var first := kit_terrain.builds - before
	var warm := kit_terrain.builds
	for i in CYCLES:
		await physics_frame
		_kit.warm_cycle()
	return {"first": first, "later": kit_terrain.builds - warm, "cycles": _kit.warm_cycles - cycles_before - 1}


func _run() -> void:
	await _boot()
	_t.check("the stand is Rivet's, so the warm-up runs", _kit._rivet())
	await _park()
	var good := TerrainFaces.new()
	var kept: Dictionary = await _stand(good)
	_t.check("the first cycle caches every placement", int(kept["first"]) >= PLACEMENTS, "%d builds" % int(kept["first"]))
	_t.check("later cycles run", int(kept["cycles"]) == CYCLES, str(kept))
	_t.check("a standing Rivet's later cycles miss nothing (bound %d a cycle)" % MISSES_PER_CYCLE_MAX, int(kept["later"]) <= MISSES_PER_CYCLE_MAX * CYCLES, "%d builds in %d cycles, %d first, %d cached reads" % [int(kept["later"]), CYCLES, int(kept["first"]), good.hits])
	_t.check("the cache is read, not rebuilt", good.hits >= PLACEMENTS * CYCLES, "%d hits" % good.hits)
	good.finish()
	# Planted control: the old keying, one build per shape. The same park must trip the bound.
	var old := TerrainFaces.new()
	old.keep_one_placement = true
	var thrash: Dictionary = await _stand(old)
	_t.check("control: one-placement keying rebuilds every cycle", int(thrash["later"]) > MISSES_PER_CYCLE_MAX * CYCLES, "%d builds in %d cycles" % [int(thrash["later"]), CYCLES])
	_t.check("control: it rebuilds a park's worth a cycle", int(thrash["later"]) >= (PLACEMENTS - 1) * CYCLES, "%d builds" % int(thrash["later"]))
	old.finish()
	_wedge_faces()
	_finish()


func _wedge_faces() -> void:
	var wedge := PackedVector3Array([Vector3(0, 0, 0), Vector3(4, 0, 0), Vector3(0, 0, 3), Vector3(4, 0, 3),
		Vector3(0, 2, 0), Vector3(4, 2, 0)])
	var other := PackedVector3Array(wedge)
	other[4] = Vector3(0, 3, 0)
	other[5] = Vector3(4, 3, 0)
	var first: Array = _kit._convex_faces(wedge)
	_t.check("a wedge's faces are searched once per point list", is_same(first, _kit._convex_faces(PackedVector3Array(wedge))))
	_t.check("the kept faces equal a fresh search", var_to_str(first) == var_to_str(_kit._convex_faces_uncached(wedge)) and first.size() == 5,
		"%d faces" % first.size())
	var second: Array = _kit._convex_faces(other)
	_t.check("another wedge gets its own faces", not is_same(first, second)
		and var_to_str(second) == var_to_str(_kit._convex_faces_uncached(other)) and var_to_str(second) != var_to_str(first))
