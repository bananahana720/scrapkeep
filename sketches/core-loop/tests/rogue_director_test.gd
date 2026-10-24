extends SceneTree

const RogueDirector := preload("res://src/world/rogue_director.gd")
const Rogue := preload("res://src/combat/rogue.gd")

# The rogue director (world/rogue_director.gd) on a fixture sidecar in the scrapkeep-sites/1
# shape: each world gets its own machine; the same stage seed gives the same site, so a
# retry replays it; seeds spread over every site; a park without a sidecar, a wrong schema
# or a world past the table gets no rogue; the trigger opens TRIGGER_PAD_M past the disc.
# Then every park sidecar on disk plans a rogue whose site is one of its own.

const PARKS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
const DOC := {"schema": "scrapkeep-sites/1", "map": "park_test", "miniboss_sites": [
	{"id": "a", "at": [0, 0], "radius_m": 40, "third": "early"},
	{"id": "b", "at": [100, 50], "radius_m": 20, "third": "mid"},
	{"id": "c", "at": [-60, 200], "radius_m": 38, "third": "late"}]}

var _failures := 0


func _initialize() -> void:
	for world in [1, 2, 3]:
		var plan := RogueDirector.plan(7, world, DOC)
		_check("world %d machine" % world, plan.get("kind") == RogueDirector.KINDS[world] and Rogue.ROWS.has(plan.get("kind", ""))
				and int(Rogue.ROWS[plan.kind].world) == world, str(plan))
	var first := RogueDirector.plan(1234, 1, DOC)
	_check("retry replays", RogueDirector.plan(1234, 1, DOC) == first, "seed 1234 twice -> %s" % first.site)
	var seen := {}
	for seed_value in 64:
		seen[RogueDirector.plan(seed_value, 2, DOC).site] = true
	_check("seeds spread", seen.size() == 3, "64 seeds met sites %s" % [seen.keys()])
	_check("no sidecar", RogueDirector.plan(1, 1, RogueDirector.read_sites("park_none")).is_empty(), "missing file -> {}")
	_check("wrong schema", RogueDirector.plan(1, 1, {"schema": "x", "miniboss_sites": DOC.miniboss_sites}).is_empty(), "schema x -> {}")
	_check("no world", RogueDirector.plan(1, 4, DOC).is_empty() and RogueDirector.plan(1, 0, DOC).is_empty(), "worlds 0 and 4 -> {}")
	var b := {}
	for seed_value in 64:
		b = RogueDirector.plan(seed_value, 3, DOC)
		if b.site == "b":
			break
	var edge := 20.0 + RogueDirector.TRIGGER_PAD_M
	_check("trigger", RogueDirector.wakes(b, Vector3(100.0 + edge - 0.5, 0.0, 50.0)) and not RogueDirector.wakes(b, Vector3(100.0 + edge + 0.5, 0.0, 50.0))
			and not RogueDirector.wakes({}, Vector3.ZERO), "site b wakes inside %.0f m and not past it" % edge)
	for map_id in PARKS:
		var doc := RogueDirector.read_sites(map_id)
		if doc.is_empty():
			print("[park %s] no sidecar on this base -> SKIP" % map_id)
			continue
		var ids: Array = doc.miniboss_sites.map(func(site): return site.id)
		var plan := RogueDirector.plan(99, 1, doc)
		_check("park %s" % map_id, plan.get("site", "") in ids, "planned %s of %s" % [plan.get("site", ""), ids])
	print("rogue_director_test: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(name: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [name, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1
