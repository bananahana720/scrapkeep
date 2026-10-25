extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const Schema := preload("res://src/world/park/park_schema.gd")
const ROOT := "res://src/world/park/"

class Map:
	extends RefCounted
	var park := {}

var _failures := 0
var _facts := 0
var _combinations := 0


func _initialize() -> void:
	var stages := []
	for file in DirAccess.get_files_at(ROOT):
		if file.ends_with(".json") and file != "park_test.json":
			stages.append(file)
	stages.sort()
	_check("stage files present", not stages.is_empty(), str(stages))
	for file in stages:
		var read := Schema.read_file(ROOT + file)
		_check(file + " parses", read.errors.is_empty() and not read.data.is_empty(), str(read.errors))
		if read.data.is_empty():
			continue
		_all_combinations(read.data)
		_stepped_facts(read.data)
	_adversarial_route()
	print("park_routes_test coverage: stages=%d combinations=%d facts=%d" % [stages.size(), _combinations, _facts])
	print("park_routes_test: PASS" if _failures == 0 else "park_routes_test: FAIL")
	quit(0 if _failures == 0 else 1)


func _director(park: Dictionary):
	var map := Map.new()
	map.park = park
	return Director.new(77731, {}, map, 14.0, func(_x, _z): return 0.0)


# Independent route oracle. Edges come from the authored routes, never the director's
# route predicate. Opened edges start dormant; an active closure beats an opening.
func _connected(park: Dictionary, live: Dictionary) -> bool:
	var open := {}
	for edge in park.routes:
		open[edge.id] = true
	for row in park.event_rows:
		for id in row.route_change.opens:
			open[id] = false
	for change in live.values():
		for id in change.opens:
			open[id] = true
	for change in live.values():
		for id in change.closes:
			open[id] = false
	var seen := {"drop_in": true}
	var pending := ["drop_in"]
	while not pending.is_empty():
		var node: String = pending.pop_front()
		for edge in park.routes:
			if open[edge.id] and edge.from == node and not seen.has(edge.to):
				seen[edge.to] = true
				pending.append(edge.to)
	return seen.has("landmark")


func _allowed(rows: Array) -> bool:
	var ground := 0
	var fleet := 0
	var ancient := 0
	for row in rows:
		fleet += int(row.family == "fleet")
		ancient += int(row.family == "ancient")
		ground += int(row.kind in ["flood_fill", "drain", "cave_in", "collapse", "impact", "flash_flood", "fleet_landing", "machine_eruption"] or row.effect.get("swap", "") != "")
	return ground <= 2 and fleet <= 1 and ancient <= 1


func _all_combinations(park: Dictionary) -> void:
	var rows: Array = park.event_rows
	var bad := []
	for mask in range(1 << rows.size()):
		var chosen := []
		var live := {}
		for i in rows.size():
			if mask & (1 << i):
				chosen.append(rows[i])
				live[rows[i].id] = rows[i].route_change
		if not _allowed(chosen):
			continue
		_combinations += 1
		if not _connected(park, live):
			bad.append(live.keys())
	_check(park.map + " every allowed route combination", bad.is_empty(), str(bad))


func _stepped_facts(park: Dictionary) -> void:
	var d = _director(park)
	if not d.has_method("register_family"):
		_check(park.map + " route after every event fact", false, "park row scheduling interface absent")
		return
	var live := {}
	var started := {}
	var announced := {}
	var landing_world := {}
	var land_hooks := []
	d.register_family("ancient", func(action, row, _ctx):
		if action == "land":
			land_hooks.append(row.id))
	var bad := []
	for i in 10000:
		var phases: Array = ["engaged", "stagger", "chunk_1", "chunk_2", "chunk_3"] if i % 800 == 0 else []
		if i % 2000 == 200:
			phases.append("broken")
		# A row that opens on an activity (the flume's sluice on its surge ring) is rung in as the ring would.
		if i % 800 == 400:
			for row in park.event_rows:
				if row.trigger.get("on") == "activity":
					d.notify_activity(row.trigger.value)
		for f in d.call("advance", 0.1, Vector3(5000, 1, 5000), Vector3.ZERO, {"clock_tier": 4, "warden_phases": phases, "grounded": true}):
			if f.kind == "announced":
				announced[f.id] = true
			if f.kind == "world" and f.get("phase") == "land":
				landing_world[f.id] = true
			_observe(f, park, live, started, bad)
	for f in d.end_all():
		_observe(f, park, live, started, bad)
	var missing := []
	for row in park.event_rows:
		if not started.has(row.id):
			missing.append(row.id)
	if park.map == "park_dam":
		_check("toe_vents_wake announces, starts and lands", announced.has("toe_vents_wake")
			and started.has("toe_vents_wake") and landing_world.has("toe_vents_wake") and land_hooks.has("toe_vents_wake"),
			"announced=%s started=%s landed=%s land_hooks=%s" % [announced.keys(), started.keys(), landing_world.keys(), land_hooks])
	_check(park.map + " route after every event fact", bad.is_empty() and missing.is_empty() and not started.is_empty(),
		"starts=%s missing=%s disconnected=%s" % [started.keys(), missing, bad])


func _observe(f: Dictionary, park: Dictionary, live: Dictionary, started: Dictionary, bad: Array) -> void:
	_facts += 1
	if f.kind == "started" and f.get("family") != "weather":
		live[f.id] = f.route_change
		started[f.id] = true
	if f.kind == "ended":
		live.erase(f.id)
	if not _connected(park, live):
		bad.append([f.kind, f.id])


func _adversarial_route() -> void:
	var park: Dictionary = Schema.read_file(ROOT + "park_dam.json").data.duplicate(true)
	# Cutting the sole drop-in edge is independently disconnected. The engine must
	# defer the row, with no land hook and no started/world landing fact.
	var cut: Dictionary = park.event_rows[0].duplicate(true)
	cut.id = "cut"
	cut.route_change = {"closes": ["shelf"], "opens": []}
	cut.trigger = {"on": "clock_tier", "value": 0}
	park.event_rows = [cut]
	_check("oracle detects severed drop-in", not _connected(park, {"cut": cut.route_change}), "closing shelf disconnects park_dam")
	var d = _director(park)
	if not d.has_method("register_family"):
		_check("unsafe route held", false, "park row scheduling interface absent")
		return
	var land := []
	d.register_family("natural", func(action, _r, _ctx):
		if action == "land":
			land.append(action))
	var started := false
	for i in 1000:
		for f in d.call("advance", 0.1, Vector3(5000, 1, 5000), Vector3.ZERO, {"clock_tier": 4, "grounded": true}):
			started = started or (f.kind == "started" and f.get("family") != "weather")
	_check("unsafe route held", not started and land.is_empty(), "no land callback or start fact for a route cut")


func _check(label: String, ok: bool, detail: String) -> void:
	_failures += int(not ok)
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
