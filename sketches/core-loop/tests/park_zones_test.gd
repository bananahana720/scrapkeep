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
# is at most 20%. The fixture's hidden pocket borders only open ground, so its border gate must
# report OUT OF TARGET. The fixture has two anchors far apart, so its jitter is robust by
# construction; the twin-anchor control misses both jitter thresholds. Planted hidden pockets
# at a three-zone junction pass and mid-zone fail under the coordinator's footprint rule.
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
const EXPECTED_CHECKS := 62

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
	# The pair is measured against the zones table, not against anchors(): the viable off-route
	# anchors with doors, by d_spawn descending, ties by zone id.
	var want := []
	var table: Array = graph.zones()
	for z in table:
		if z["degree"] == 1 and z["d_spawn"] >= 0.0 and not (z["line"] or z["warden"]) and z["door_ok"] >= graph.ANCHOR_MIN_DOOR_NODES and not tool.anchor_doors(graph, z["id"]).is_empty():
			want.append(z)
	want.sort_custom(func(a, b): return a["d_spawn"] > b["d_spawn"] or (a["d_spawn"] == b["d_spawn"] and a["id"] < b["id"]))
	var want_names := []
	for z in want:
		want_names.append(z["name"])
	t.eq("the jitter draws from the zones table's costliest anchors, costliest first", drawn["anchors"], want_names)
	t.check("the anchor ranks agree with the cost order", drawn["order_ok"])
	# Control: a reversed rank order is caught.
	var flipped: Array = graph.anchors()
	var top_rank := 0
	for a in flipped:
		top_rank = maxi(top_rank, a["rank"])
	for a in flipped:
		if a["rank"] > 0:
			a["rank"] = top_rank + 1 - a["rank"]
	var mirror: Dictionary = tool.jitter(graph, 50, {"anchors": flipped})
	t.check("control: ranks running cheapest first make order_ok false", not mirror["order_ok"])
	var border: Array = tool.hidden_border(graph, park)
	var reported_ids := []
	for pocket in tool.pockets(graph, park)["rows"]:
		if pocket["role"] == "hidden":
			reported_ids.append(pocket["id"])
	t.eq("the border measures every hidden pocket in the full pocket report",
		border.map(func(h): return h["id"]), reported_ids)
	# The CLI gate, called as the CLI calls it. The fixture remains authored in place.
	t.eq("the fixture border gate truthfully reports its one-zone pocket", tool.zone_gate(drawn, border),
		["hidden pocket tube_wall borders 1 zones"])
	t.check("control: the gate fails a park with no hidden pocket", not tool.zone_gate(drawn, []).is_empty())
	var weak := drawn.duplicate()
	weak["top2_share"] = 0.94
	weak["reroll_share"] = 0.21
	weak["order_ok"] = false
	t.eq("control: the gate names the rank order, the top pair, re-roll rate and fixture border", tool.zone_gate(weak, border).size(), 4)
	t.eq("the fixture has one hidden pocket, tube_wall", [border.size(), border[0]["id"]], [1, "tube_wall"])
	t.eq("the fixture footprint borders only open ground", border[0]["zones"], ["open"])
	t.eq("the fixture footprint zone count is one", border[0]["count"], 1)
	var summary: Dictionary = tool.zone_summary(graph, park)
	var text: String = tool.zone_text(summary)
	print(text)
	t.check("the fixture report prints OUT OF TARGET with its measured count",
		text.contains("hidden pocket tube_wall borders 1 zones (open), at least 3 wanted: OUT OF TARGET"))


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
	var border_controls := [
		_hidden_control("junction_hidden", [-700, 670]),
		_hidden_control("mid_zone_hidden", [-650, 650]),
	]
	# The door and cache stay mid-zone. Only the rotated wall frame reaches the junction.
	var wall_only: Dictionary = border_controls[1].duplicate(true)
	wall_only["id"] = "wall_frame_hidden"
	wall_only["size"] = [48, 6, 120]
	wall_only["turn"] = PI * 0.5
	border_controls.append(wall_only)
	planted["contraption_rows"].append_array(border_controls)
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
	# Measure each planted hidden row using the baked planted graph, with that row as the
	# park's one hidden pocket. The rows are saved in planted.json under user://.
	for control in border_controls:
		var measured_park := planted.duplicate(true)
		measured_park["contraption_rows"] = measured_park["contraption_rows"].filter(func(c): return not tool.HIDDEN_KINDS.has(c["kind"]))
		measured_park["contraption_rows"].append(control)
		var border: Array = tool.hidden_border(graph, measured_park)
		print("planted footprint %s: %s" % [control["id"], str(border)])
		var junction: bool = control["id"] != "mid_zone_hidden"
		t.eq("control: %s borders its footprint's zones" % control["id"], border[0]["zones"],
			["nook_a", "nook_a_ramp", "open"] if junction else ["nook_a"])
		var misses: Array = tool.zone_gate(drawn, border)
		t.eq("control: %s %s the border gate" % [control["id"], "passes" if junction else "fails"], misses,
			[] if junction else ["hidden pocket mid_zone_hidden borders 1 zones"])


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


func _hidden_control(id: String, at: Array) -> Dictionary:
	return {"id": id, "kind": "cracked_wall", "site": "nook_a", "recipe": "", "at": at,
		"cache": {"at": at.duplicate()}, "size": [12, 6, 1.4], "turn": 0.0, "break_at_cruise": true}
