# smoke: solo timeout=360s (rebuilds the park_test graph, then bakes and builds one planted park; a loaded machine slows the 20 s builds)
extends SceneTree

# Rule: the stage graph also bakes landform zones joined by one-move crossings, and ranks the
# degree-1 zones as pocket anchors by path distance (design-v3/PARK.md 2.11, K-UNITS SQ13,
# research/comps/pocket-placement.md:62 and isaac/floor-generation.md:107).
#
# Committed park_test graph: a rebuild of graph.bin and graph.json is byte-identical to the
# committed pair, and graph.bin round-trips through the loader. Every node sits in exactly one
# zone, zones are numbered by their lowest node, every crossing is well formed, and the three
# fixture ride edges that cross zones are the kicker lip, the cable bench_zip and the lift
# ledge_lift. Entrances follow the crossings (a walk both ways, a ride or a drop one way) and
# degree counts them. On the fixture, bench (the ramp is its one way in), service_ledge (a ledge
# entered by drops from the open ground, its way out a lift) and run_wash are the viable anchors
# off the route, costliest first; tube and lip are anchors on the route; cliff_rooms and
# canal_lip are guarded rows with no door_ok node, so they rank nowhere. No ranked anchor holds a
# line node.
#
# SQ13 ACCEPTANCE, measured here and printed by tools/park_graph.gd --jitter: the guaranteed
# pockets (reward and risk) draw their doors among the door_ok nodes of the two costliest anchors
# off the route over 1,000 seeded jitters and sit there on at least 95% of seeds, the re-roll rate
# is at most 20%, and the hidden pocket borders at least 3 zones. The fixture has two anchors far
# apart, so its jitter is robust by construction; the controls show the checks can fail: both
# doors drawn from the one anchor, one draw each, often land under 200 m apart and miss both
# thresholds, and a hidden pocket seen through a 20 m ring borders fewer than 3 zones.
#
# Planted park (written to user:// and baked there, the fixture file is never edited): a nook of
# one ramp far from the route is the costliest anchor and takes rank 1, a nook of two ramps is
# not an anchor, and a diagonal wall across the south-east corner splits the open ground in two,
# the corner piece unreachable from the spawn.

const T := preload("res://tests/support/t.gd")

const PARK := "res://src/world/park/park_test.json"
const BAKED := "res://assets/park/park_test"
const SCRATCH := "user://park_zones_test"
const TOOL := "res://tools/park_graph.gd"
const LOADER := "res://src/world/park/park_graph.gd"
const BAKE_TOOL := "res://tools/park_bake.gd"
const EXPECTED_CHECKS := 48

var t := T.new("park_zones_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not t.check("zone API exists on the loader and the tool", _api_exists()):
		quit(t.verdict())
		return
	var tool: GDScript = load(TOOL)
	var loader: GDScript = load(LOADER)
	var bake: GDScript = load(BAKE_TOOL)
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	var graph = loader.read(BAKED + "/graph.bin")
	if not t.check("graph.bin loads", graph != null):
		quit(t.verdict())
		return
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	t.check("committed graph is fresh", tool.freshness(PARK, BAKED, BAKED).is_empty())
	_rebuild(tool, graph)
	_partition(graph, loader)
	_crossings(graph, loader)
	_fixture_anchors(graph, loader)
	_acceptance(tool, graph, park)
	_planted(tool, bake, loader, park)
	t.eq("the test ran its stated check count", t.checks + 1, EXPECTED_CHECKS)
	quit(t.verdict())


func _api_exists() -> bool:
	if not ResourceLoader.exists(TOOL) or not ResourceLoader.exists(LOADER):
		return false
	var loader: GDScript = load(LOADER)
	var tool: GDScript = load(TOOL)
	var methods := PackedStringArray()
	for m in loader.get_script_method_list():
		methods.append(m["name"])
	for name in ["zones", "crossings", "anchors", "zone_of", "zone_nodes"]:
		if not methods.has(name):
			return false
	var tool_methods := PackedStringArray()
	for m in tool.get_script_method_list():
		tool_methods.append(m["name"])
	return tool_methods.has("jitter") and tool_methods.has("hidden_border")


# Two bakes of the fixture give identical bytes, and the loader re-serializes the file it read.
func _rebuild(tool: GDScript, graph) -> void:
	var again: Dictionary = tool.run(PARK, BAKED, SCRATCH + "/again")
	t.check("rebuild succeeds", again["ok"], str(again["errors"]))
	for name in ["graph.bin", "graph.json"]:
		var a := FileAccess.get_file_as_bytes(BAKED + "/" + name)
		var b := FileAccess.get_file_as_bytes(SCRATCH + "/again/" + name)
		t.check("rebuild is byte-identical: " + name, not a.is_empty() and a == b, "%d vs %d bytes" % [a.size(), b.size()])
	var file := FileAccess.open_compressed(BAKED + "/graph.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var raw := PackedByteArray()
	while not file.eof_reached():
		var chunk := file.get_buffer(1 << 20)
		if chunk.is_empty():
			break
		raw.append_array(chunk)
	file.close()
	t.check("the loader re-serializes graph.bin byte for byte", graph.to_bytes() == raw, "%d vs %d bytes" % [graph.to_bytes().size(), raw.size()])


func _partition(graph, loader: GDScript) -> void:
	var n: int = graph.node_count()
	var zones: Array = graph.zones()
	var assigned := 0
	for o in n:
		var z: int = graph.zone_of(o)
		if z >= 0 and z < zones.size():
			assigned += 1
	t.eq("every node is in exactly one zone", assigned, n)
	var total := 0
	var names := {}
	var ordered := true
	var last := -1
	for z in zones.size():
		var members: PackedInt32Array = graph.zone_nodes(z)
		total += members.size()
		names[zones[z]["name"]] = true
		if members.is_empty() or members[0] <= last:
			ordered = false
		else:
			last = members[0]
	t.eq("zone node counts sum to the node count", total, n)
	t.eq("zone names are unique", names.size(), zones.size())
	t.check("zones are numbered by their lowest node", ordered)
	t.eq("the fixture has 13 zones", zones.size(), 13)
	t.eq("the open ground is one zone on the fixture", _names_with_kind(zones, "open"), ["open"])


func _crossings(graph, loader: GDScript) -> void:
	var zones: Array = graph.zones()
	var well_formed := true
	var rides := []
	var expected := []
	for z in zones.size():
		expected.append({})
	for c in graph.crossings():
		if c["a"] < 0 or c["b"] < 0 or c["a"] >= zones.size() or c["b"] >= zones.size() or c["a"] == c["b"]:
			well_formed = false
			continue
		if not ["walk", "ride", "drop"].has(c["kind"]) or c["links"] < (1 if c["kind"] == "ride" else loader.ZONE_MIN_LINKS):
			well_formed = false
		if c["kind"] == "walk" and c["a"] > c["b"]:
			well_formed = false
		if c["kind"] == "ride":
			rides.append("%s: %s to %s" % [c["row"], zones[c["a"]]["name"], zones[c["b"]]["name"]])
		expected[c["b"]][c["a"]] = true
		if c["kind"] == "walk":
			expected[c["a"]][c["b"]] = true
	t.check("every crossing is well formed", well_formed)
	rides.sort()
	t.eq("the ride crossings are the lip kicker, the bench cable and the ledge lift", rides,
		["bench_zip: bench to open", "ledge_lift: service_ledge to open", "lip: open to tube"])
	var entered := true
	for z in zones.size():
		var want: Array = expected[z].keys()
		want.sort()
		if want != zones[z]["entrances"]:
			entered = false
	t.check("entrances follow the crossings: walks both ways, rides and drops one way", entered)
	var degrees := true
	for z in zones:
		if z["degree"] != z["entrances"].size():
			degrees = false
	t.check("degree is the entrance count", degrees)


func _fixture_anchors(graph, loader: GDScript) -> void:
	var zones: Array = graph.zones()
	var by_name := {}
	for z in zones:
		by_name[z["name"]] = z
	t.eq("bench is entered by bench_ramp alone", _names(zones, by_name["bench"]["entrances"]), ["bench_ramp"])
	t.eq("service_ledge is entered from the open ground alone", _names(zones, by_name["service_ledge"]["entrances"]), ["open"])
	t.eq("bench_ramp has two entrances, so it is no anchor", by_name["bench_ramp"]["degree"], 2)
	var anchors: Array = graph.anchors()
	var ranked := []
	var unranked := []
	for a in anchors:
		if a["rank"] > 0:
			ranked.append(a["name"])
		else:
			unranked.append(a["name"])
	t.eq("the ranked anchors, costliest first, are bench, service_ledge and run_wash", ranked, ["bench", "service_ledge", "run_wash"])
	unranked.sort()
	t.eq("tube and lip are on the route and cliff_rooms and canal_lip have no doors, so none ranks",
		unranked, ["canal_lip", "cliff_rooms", "lip", "tube"])
	var sorted := true
	var degree_one := true
	for k in anchors.size():
		if k > 0 and anchors[k]["cost"] > anchors[k - 1]["cost"]:
			sorted = false
		if zones[anchors[k]["zone"]]["degree"] != 1:
			degree_one = false
	t.check("anchors run costliest first", sorted)
	t.check("every anchor has degree 1", degree_one)
	var line_free := true
	for a in anchors:
		if a["rank"] > 0:
			for o in graph.zone_nodes(a["zone"]):
				if graph.flags(o) & loader.LINE != 0:
					line_free = false
	t.check("no ranked anchor holds a line node", line_free)
	var costs := true
	for a in anchors:
		if a["cost"] != zones[a["zone"]]["d_spawn"]:
			costs = false
	t.check("an anchor's cost is its zone's d_spawn", costs)


# The SQ13 acceptance numbers, asserted against their thresholds, and the controls.
func _acceptance(tool: GDScript, graph, park: Dictionary) -> void:
	var drawn: Dictionary = tool.jitter(graph, 1000)
	print(tool.jitter_text(drawn))
	t.eq("the jitter ran 1,000 seeds", drawn["seeds"], 1000)
	t.check("guaranteed pockets sit at the two costliest anchors on at least 95% of seeds", drawn["top2_share"] >= 0.95, "%.1f%%" % (100.0 * drawn["top2_share"]))
	t.check("the re-roll rate is at most 20%", drawn["reroll_share"] <= 0.20, "%.1f%%" % (100.0 * drawn["reroll_share"]))
	t.eq("every seed places the guaranteed pockets", drawn["placed"], 1000)
	t.eq("the jitter is repeatable", tool.jitter(graph, 1000), drawn)
	# Control: both guaranteed pockets drawn from the bench, one draw each, so two doors often fall
	# under 200 m apart.
	var twins := []
	for a in graph.anchors():
		if a["name"] == "bench":
			var twin: Dictionary = a.duplicate()
			twin["name"] = "bench_twin"
			twin["rank"] = 2
			twins = [a, twin]
	var forced: Dictionary = tool.jitter(graph, 1000, {"anchors": twins, "draws": 1})
	t.check("control: two pockets in one anchor miss the top pair on over 5% of seeds", forced["top2_share"] < 0.95, "%.1f%%" % (100.0 * forced["top2_share"]))
	t.check("control: two pockets in one anchor re-roll on over 20% of seeds", forced["reroll_share"] > 0.20, "%.1f%%" % (100.0 * forced["reroll_share"]))
	var border: Array = tool.hidden_border(graph, park)
	t.eq("the fixture has one hidden pocket, tube_wall", [border.size(), border[0]["id"]], [1, "tube_wall"])
	t.check("the hidden pocket borders at least 3 zones", border[0]["count"] >= 3, str(border[0]["zones"]))
	var narrow: Array = tool.hidden_border(graph, park, 20.0)
	t.check("control: seen through a 20 m ring the hidden pocket borders fewer than 3 zones", narrow[0]["count"] < 3, str(narrow[0]["zones"]))


# One planted park: nook_a (one ramp) far from the route, nook_b (two ramps), and a diagonal wall
# across the south-east corner.
func _planted(tool: GDScript, bake: GDScript, loader: GDScript, park: Dictionary) -> void:
	var planted := park.duplicate(true)
	var rows: Array = planted["park_rows"]
	rows.append(_row("nook_a", [-650, 650], [100, 6, 100], 0, "plateau"))
	rows.append(_row("nook_a_ramp", [-720.5, 650], [39, 6, 40], -90, "ramp"))
	rows.append(_row("nook_b", [-650, 400], [100, 6, 100], 0, "plateau"))
	rows.append(_row("nook_b_west", [-720.5, 400], [39, 6, 40], -90, "ramp"))
	rows.append(_row("nook_b_east", [-579.5, 400], [39, 6, 40], 90, "ramp"))
	rows.append(_row("corner_wall", [750, 750], [160, 200, 20], -45, "plateau"))
	var path := SCRATCH + "/planted.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(JSON.stringify(planted, " ").to_utf8_buffer())
	f.close()
	var baked: Dictionary = bake.bake(path, SCRATCH + "/planted")
	if not t.check("planted park bakes", baked["ok"], str(baked["errors"])):
		return
	var built: Dictionary = tool.build(planted, tool.load_bake(SCRATCH + "/planted"), {"sight": false})
	if not t.check("planted park builds", built["errors"].is_empty(), str(built["errors"])):
		return
	var graph = built["graph"]
	var zones: Array = graph.zones()
	var by_name := {}
	for z in zones:
		by_name[z["name"]] = z
	t.check("planted nook_a, nook_b and their ramps are zones", by_name.has("nook_a") and by_name.has("nook_b") and by_name.has("nook_a_ramp") and by_name.has("nook_b_west") and by_name.has("nook_b_east"))
	t.eq("nook_a is entered by its ramp alone", _names(zones, by_name["nook_a"]["entrances"]), ["nook_a_ramp"])
	t.eq("nook_b has two ways in, so it is no anchor", by_name["nook_b"]["degree"], 2)
	var ranked := []
	for a in graph.anchors():
		if a["rank"] > 0:
			ranked.append(a["name"])
	t.eq("the planted anchors rank nook_a first, then the fixture's", ranked.slice(0, 4), ["nook_a", "bench", "service_ledge", "run_wash"])
	t.check("nook_b is not an anchor", not ranked.has("nook_b"))
	var drawn: Dictionary = tool.jitter(graph, 1000)
	t.eq("the planted jitter draws from nook_a, bench and service_ledge first", drawn["anchors"].slice(0, 3), ["nook_a", "bench", "service_ledge"])
	t.check("the planted pockets sit at the two costliest anchors on at least 95% of seeds", drawn["top2_share"] >= 0.95, "%.1f%%" % (100.0 * drawn["top2_share"]))
	var open_zones := _names_with_kind(zones, "open")
	t.eq("the diagonal wall splits the open ground in two", open_zones, ["open", "open.2"])
	t.eq("the corner piece is out of the spawn's reach", by_name["open.2"]["d_spawn"], -1.0)


func _names_with_kind(zones: Array, kind: String) -> Array:
	var out := []
	for z in zones:
		if z["kind"] == kind:
			out.append(z["name"])
	return out


func _names(zones: Array, ids: Array) -> Array:
	var out := []
	for id in ids:
		out.append(zones[id]["name"])
	out.sort()
	return out


func _row(id: String, at: Array, size: Array, yaw: float, stamp: String) -> Dictionary:
	return {"id": id, "element": "ground", "landform": "slickrock", "society": "none", "at": at, "y": null,
		"size": size, "yaw_deg": yaw, "verb": "roll", "ride_fact": "", "home": "", "recipe": "",
		"stamp": stamp, "hole": false, "budget": "landform", "routes": [], "fragment": ""}
