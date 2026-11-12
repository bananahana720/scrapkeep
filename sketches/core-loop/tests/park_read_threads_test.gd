extends SceneTree

# The park table's six park files read together at Game setup (terrain.gd _read_parks_together): the first on the
# calling thread, the rest on workers. Each round must give every park, each the same as a read on one thread. ROUNDS
# reads stress the workers for a shared write the parallel read must not have; the rare cold-line crash it guards
# against (Godot's untyped operator cache) shows once a process, so no round count here can catch that one.

const Terrain := preload("res://src/world/terrain.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")

const ROUNDS := 12

var t := T.new("park_read_threads_test")


func _init() -> void:
	var first: Dictionary = Terrain._read_parks_together(ParkDefs)
	var ids := []
	for row in ParkDefs.DEFS:
		if not ids.has(String(row["map"])):
			ids.append(String(row["map"]))
	t.eq("every park in the table reads", first.keys(), ids)
	var want := {}
	for id in ids:
		want[id] = _facts(ParkMap.new("res://src/world/park/%s.json" % id))
	var mismatches := []
	for round in ROUNDS:
		var parks: Dictionary = first if round == 0 else Terrain._read_parks_together(ParkDefs)
		for id in ids:
			if not parks.has(id) or _facts(parks[id]) != want[id]:
				mismatches.append("%s round %d" % [id, round])
	t.eq("each threaded read matches a read on one thread, %d rounds" % ROUNDS, mismatches, [])
	quit(t.verdict())


func _facts(map) -> Array:
	return [map.ok, map.title, map.spawn, map.beacon, map.reach_m, map.play_rect, map.kickers.size(), map.contraptions.size(),
		map.activity_sites.size(), map.rescue_sites.size(), map.scatter["keep_out"].size(), map.scrap_trail.get("gaps", [])]
