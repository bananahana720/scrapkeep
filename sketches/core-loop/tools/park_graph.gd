extends SceneTree

# The stage graph (design-v3/PARK.md 2.11 and 2.12, K-UNITS KB8): the bake's second step. Reads
# the park file and the bake's ground.bin, holes.bin and under.bin and writes
# assets/park/<map_id>/:
#
#   graph.bin    the graph src/world/park/park_graph.gd loads (nodes, edges, flags, d_landmark,
#                d_spawn), zstd
#   graph.json   schema, map, the park file's, bake.json's, the tool's and graph.bin's sha256,
#                the counts, and the ruling: route connectivity, the spawn check and the pocket
#                table (every distance a path distance on this graph, PARK.md 2.12 readings;
#                per pocket door_m, the path from the nearest line node to the door, and
#                detour_m, the path from the nearest line node to the pay point),
#                each pocket's pay.rarities against the 2.12 pay ladder, and full_visit_ratio:
#                spawn through all four doors in the best order to the beacon, over spawn to
#                beacon (reported, start target at most 3.0), reward_ratio: the median
#                spawn-to-pocket path over the spawn-to-beacon path (printed for information, no
#                target since ruling ac), and the targets array that marks a target missed
#
# The park file stays the authored truth: the graph checks the spawn, the landmark and the
# activities and never moves them. Two runs on one park and bake give identical bytes.
#
#   godot --headless --path sketches/core-loop --script res://tools/park_graph.gd -- --map=park_test
#
# Zones (SQ13). graph.bin also carries the landform zones and their crossings, and graph.json a
# zones block: the counts, the anchors ranked by path distance and the hidden pocket's border
# (rules in src/world/park/park_graph.gd). `--jitter` (or `--jitter=<seeds>`, 1,000 by default)
# adds the guaranteed-pocket draw over that many seeds, prints it against its thresholds and exits
# 1 when the two costliest anchors take under 95% of seeds, the re-roll rate passes 20% or the
# hidden pocket borders fewer than 3 zones. It is slow, so a bake leaves it off.
#
# Rules, each a starting value (PARK.md 2.11):
#   Ground edge  8-neighbours on the 8 m lattice. a -> b exists when the highest of the four 2 m
#                vertices from a toward b (b included) is at most CLIMB_M above a, so a wall
#                thinner than the lattice still blocks, and any drop is one-way down.
#   Deck         a park row with y set gets its own 8 m lattice along and across its yaw at y,
#                8-neighbour edges inside it, and its border nodes link to any other node within
#                LINK_M horizontally by the same climb rule (drop off any side, step on within 4 m).
#   Ride edges   read from the rows, tagged with the row id, length the straight 3D distance:
#                kicker (verb launch): takeoff, the node under its far end (at + half its length
#                along its yaw), to the nearest node of the place after it in each route's
#                from-via-to sequence; launcher: its start node to the node nearest `target`;
#                cable: `from` to `to`; thermal and lift: from the lowest node within 8 m of `at`
#                (its site row's deck when the site has y) up to the node nearest the column top
#                (at, start y + height or rise) among nodes more than CLIMB_M and at most the
#                column above the start; grind row (verb grind, grind_line or rail): its two end
#                nodes, each way the line is clear (on the ground no sample along it rises more
#                than CLIMB_M above where the ride starts; raised, the ground stays under the
#                rail), so a wall across a ground-level lip blocks it; glide row: its start end
#                one-way to the ground under its far end.
#   open         not a hole cell and no deck row's footprint more than 2 m above the node.
#   line         within LINE_M (3D) of the shortest path spawn -> waymarks in order -> beacon; a
#                park-row waymark is reached at its nearest node by path, an activity waymark at
#                its door node.
#   sight_ok     a line node, or a clear ray over ground.bin from EYE_M above the node to EYE_M
#                above a line node within SIGHT_M; up to SIGHT_TRIES line nodes are tried, nearest
#                first and then spread evenly over the rest. Holes do not open the ray: a tunnel's
#                roof stands where the ground was.

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const Parts := preload("res://src/build/parts.gd")

const TOOL_FILES := ["res://tools/park_graph.gd", "res://src/world/park/park_graph.gd", "res://src/world/park/park_placement.gd", "res://src/combat/warden_swarm.gd"]
const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"

const BAKE_SIDE := 801
const BAKE_CELLS := 800
const SIDE := ParkGraph.SIDE
const STEP := ParkGraph.STEP_M
const HALF := ParkGraph.HALF_M
const CLIMB_M := 4.0
const LINK_M := 11.4
const LINE_M := 8.0
const ROOF_M := 2.0
const EYE_M := 2.0
const SIGHT_M := 240.0
const SIGHT_TRIES := 32
const SIGHT_STEP_M := 2.0
const START_REACH_M := 8.0
const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]

const Placement := preload("res://src/world/park/park_placement.gd")
const WardenSwarm := preload("res://src/combat/warden_swarm.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
# Placement rules live in park_placement.gd (the game draws pockets with them); kept here under their old names.
const DOOR_SPAWN_M := Placement.DOOR_SPAWN_M
const DOOR_BEACON_M := Placement.DOOR_BEACON_M
const DOOR_DOOR_M := Placement.DOOR_DOOR_M
const RING_M := Placement.RING_M
const DETOUR_MIN_M := Placement.DETOUR_MIN_M
const DETOUR_MAX_M := Placement.DETOUR_MAX_M
const HIDDEN_ROUTES := Placement.HIDDEN_ROUTES
const BEACON_DISC_SHARE := Placement.BEACON_DISC_SHARE
const BEACON_FLAT_M := Placement.BEACON_FLAT_M
# A lattice node on a footprint's edge counts as on it (_in_footprint): yaw turns leave it a hair outside.
const FOOTPRINT_EPS_M := 0.01
const FULL_VISIT_RATIO_MAX := Placement.FULL_VISIT_RATIO_MAX
const ONLINE_KINDS := Placement.ONLINE_KINDS
const REWARD_KINDS := Placement.REWARD_KINDS
const RISK_KINDS := Placement.RISK_KINDS
# Opt-in events a park stands beside its four pockets (W13 SR10; the flume's surge course, unit 11): not counted as a
# pocket, but their door keeps the sight and clear-ring rules.
const EVENT_KINDS := ["hold_the_relay", "surge_run"]
# The completionist card's extra activity (card 2, default: two more activities a park) may add a second reward or
# risk pocket; every distance rule still holds for it, and the pay ladder still ranks the first pair (PARK.md 2.12).
const OFFLINE_MAX := 2
const HIDDEN_KINDS := Placement.HIDDEN_KINDS
const DESTRUCTIVE_EVENTS := Placement.DESTRUCTIVE_EVENTS
const HAZARD_CONTRAPTIONS := Placement.HAZARD_CONTRAPTIONS
const MOVE_RULES := Placement.MOVE_RULES
const LOG_RULES := Placement.LOG_RULES
const PAY_ONLINE := Placement.PAY_ONLINE
const PAY_NEAR := Placement.PAY_NEAR
const PAY_FAR := Placement.PAY_FAR
const Index := Placement.Index


func _initialize() -> void:
	var map_id := ""
	var jitter_seeds := 0
	var draw_mode := false
	var draw_seeds := 1000
	var placement_seeds := 200
	var draw_out := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--pockets=draw":
			draw_mode = true
		elif arg.begins_with("--seeds="):
			draw_seeds = int(arg.trim_prefix("--seeds="))
		elif arg.begins_with("--placement-seeds="):
			placement_seeds = int(arg.trim_prefix("--placement-seeds="))
		elif arg.begins_with("--out="):
			draw_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg == "--jitter":
			jitter_seeds = JITTER_SEEDS
		elif arg.begins_with("--jitter="):
			jitter_seeds = int(arg.trim_prefix("--jitter="))
	if map_id.is_empty():
		printerr("park_graph: pass --map=<map_id>")
		quit(2)
		return
	if draw_mode:
		var arm := draw_arm(map_id, draw_seeds, placement_seeds)
		var summary := arm.duplicate(true)
		for row in summary.templates:
			row.erase("samples")
		print("pocket_draw_arm: " + JSON.stringify(summary))
		if not draw_out.is_empty():
			var file := FileAccess.open(draw_out, FileAccess.WRITE)
			if file == null:
				printerr("park_graph: cannot save draw arm to " + draw_out)
				quit(2)
				return
			file.store_string(JSON.stringify(arm, "\t"))
			file.close()
		print("pocket_draw_arm: %s (%d stage samples, %d placement samples)" % ["PASS" if arm.ok else "FAIL", arm.stage_samples, arm.placement_samples])
		quit(0 if arm.ok else 1)
		return
	var park_path := "%s/%s.json" % [PARK_DIR, map_id]
	var dir := "%s/%s" % [OUT_DIR, map_id]
	var stale: Array = ParkBake.freshness(park_path, dir)
	if not stale.is_empty():
		printerr("park_graph: the bake is stale, run tools/park_bake.gd first: %s" % "; ".join(stale))
		quit(1)
		return
	var result := run(park_path, dir, dir)
	if not result["info"].is_empty():
		print(report_text(result["info"]))
	if not result["ok"]:
		printerr("park_graph: %s" % "\n".join(result["errors"]))
		quit(1)
		return
	if jitter_seeds > 0:
		# The jitter needs the graph as the loader reads it, zones included.
		var graph = ParkGraph.read(dir + "/graph.bin")
		var park: Dictionary = ParkSchema.load_park(park_path)["data"]
		var drawn := jitter(graph, jitter_seeds)
		print(jitter_text(drawn))
		var misses := zone_gate(drawn, hidden_border(graph, park))
		if not misses.is_empty():
			printerr("park_graph: zone anchors are out of target: %s" % "; ".join(misses))
			quit(1)
			return
	quit(0)


# Builds the graph of park_path on the bake in bake_dir and writes graph.bin and graph.json to
# out_dir. Returns {"ok", "errors", "info"} with info the graph.json content. A waymark the
# graph cannot reach still writes both files and the report, and is not ok.
static func run(park_path: String, bake_dir: String, out_dir: String) -> Dictionary:
	var read := ParkSchema.load_park(park_path)
	if not read["errors"].is_empty():
		return {"ok": false, "errors": ["%s fails the park schema: %s" % [park_path, ParkSchema.describe(read["errors"])]], "info": {}}
	var park: Dictionary = read["data"]
	var bake := load_bake(bake_dir)
	if not bake["errors"].is_empty():
		return {"ok": false, "errors": bake["errors"], "info": {}}
	var built := build(park, bake)
	if not built["errors"].is_empty():
		return {"ok": false, "errors": built["errors"], "info": {}}
	var graph = built["graph"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bin_path := out_dir + "/graph.bin"
	var file := FileAccess.open_compressed(bin_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return {"ok": false, "errors": ["cannot write %s: %s" % [bin_path, error_string(FileAccess.get_open_error())]], "info": {}}
	file.store_buffer(graph.to_bytes())
	file.close()

	var info := ruling(graph, park, built)
	info["schema"] = ParkGraph.SCHEMA
	info["map"] = String(park["map"])
	info["park_sha256"] = FileAccess.get_sha256(park_path)
	info["bake_sha256"] = FileAccess.get_sha256(bake_dir + "/bake.json")
	info["tool_sha256"] = tool_sha256()
	info["graph_sha256"] = FileAccess.get_sha256(bin_path)
	info["bytes"] = FileAccess.get_file_as_bytes(bin_path).size()
	info["line_errors"] = built["line_errors"]
	var json_path := out_dir + "/graph.json"
	var out := FileAccess.open(json_path, FileAccess.WRITE)
	if out == null:
		return {"ok": false, "errors": ["cannot write %s" % json_path], "info": {}}
	out.store_string(JSON.stringify(info, "  ", true) + "\n")
	out.close()
	return {"ok": built["line_errors"].is_empty(), "errors": built["line_errors"], "info": info}


# What makes the graph in graph_dir stale for park_path and the bake in bake_dir; empty is fresh.
static func freshness(park_path: String, bake_dir: String, graph_dir: String) -> Array:
	var json_path := graph_dir + "/graph.json"
	if not FileAccess.file_exists(json_path):
		return ["%s missing: run tools/park_graph.gd" % json_path]
	var info = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary:
		return ["%s does not parse" % json_path]
	var stale := []
	if info.get("schema") != ParkGraph.SCHEMA:
		stale.append("schema: %s, want %s" % [info.get("schema"), ParkGraph.SCHEMA])
	var checks := [["park_sha256", park_path], ["bake_sha256", bake_dir + "/bake.json"], ["graph_sha256", graph_dir + "/graph.bin"]]
	for check in checks:
		var got := FileAccess.get_sha256(check[1])
		if got.is_empty() or info.get(check[0]) != got:
			stale.append("%s: graph.json has %s, %s is %s; rerun tools/park_graph.gd" % [check[0], info.get(check[0]), check[1], got])
	var tool_sha := tool_sha256()
	if info.get("tool_sha256") != tool_sha:
		stale.append("tool_sha256: graph.json has %s, the tool is %s; rerun" % [info.get("tool_sha256"), tool_sha])
	return stale


static func tool_sha256() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in TOOL_FILES:
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


# The three bake files the graph reads. {"ground", "holes", "under", "errors"}.
static func load_bake(dir: String) -> Dictionary:
	var out := {"errors": []}
	var raw := FileAccess.open_compressed(dir + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if raw == null:
		out["errors"].append("%s/ground.bin does not open" % dir)
		return out
	var bytes := raw.get_buffer(BAKE_SIDE * BAKE_SIDE * 4 + 16)
	raw.close()
	if bytes.size() != BAKE_SIDE * BAKE_SIDE * 4:
		out["errors"].append("%s/ground.bin is %d bytes, want %d" % [dir, bytes.size(), BAKE_SIDE * BAKE_SIDE * 4])
		return out
	out["ground"] = bytes.to_float32_array()
	out["holes"] = FileAccess.get_file_as_bytes(dir + "/holes.bin")
	out["under"] = FileAccess.get_file_as_bytes(dir + "/under.bin").to_float32_array()
	if out["holes"].size() != BAKE_CELLS * BAKE_CELLS:
		out["errors"].append("%s/holes.bin is %d bytes, want %d" % [dir, out["holes"].size(), BAKE_CELLS * BAKE_CELLS])
	return out


# Builds the graph. opts {"sight": false} skips the sight flag (the planted-route tests).
# Returns {"graph", "errors", "line_errors", "line_path", "ride_edges"}: a waymark the graph
# cannot reach is a line error (the line stops there), not a build error.
static func build(park: Dictionary, bake: Dictionary, opts := {}) -> Dictionary:
	var b := Builder.new()
	b.park = park
	b.ground = bake["ground"]
	b.holes = bake["holes"]
	b.under = bake["under"]
	b.sight = bool(opts.get("sight", true))
	b.run()
	return {"graph": b.g, "errors": b.errors, "line_errors": b.line_errors, "line_path": b.line_path, "ride_edges": b.ride_count}


class Builder:
	var park: Dictionary
	var ground: PackedFloat32Array
	var holes: PackedByteArray
	var under: PackedFloat32Array
	var sight := true
	var errors := []
	var line_errors := []
	var g: ParkGraph = ParkGraph.new()
	var vh := PackedFloat32Array()
	var rows: Array = []
	var row_index := {}
	var deck_start := PackedInt32Array()
	var deck_count := PackedInt32Array()
	var deck_dims := []
	var e_from := PackedInt32Array()
	var e_to := PackedInt32Array()
	var e_len := PackedFloat32Array()
	var e_ride := PackedInt32Array()
	var ride_count := 0
	var line_path := PackedInt32Array()
	var _row_nodes := {}

	func run() -> void:
		rows = park["park_rows"]
		for k in rows.size():
			row_index[String(rows[k]["id"])] = k
			g.names.append(String(rows[k]["id"]))
		for c in park["contraption_rows"]:
			g.names.append(String(c["id"]))
		_heights()
		_nodes()
		_ground_edges()
		_deck_edges()
		g.spawn_node = ParkGraph.lattice_index(float(park["spawn"]["at"][0]), float(park["spawn"]["at"][1]))
		var beacon: Array = park["landmark"]["beacon"]
		g.beacon_node = ParkGraph.lattice_index(float(beacon[0]), float(beacon[1]))
		_ride_edges()
		_csr()
		_flags()
		_line()
		g.d_from = g.search(PackedInt32Array([g.spawn_node]))
		g.d_land = g.search(PackedInt32Array([g.beacon_node]), true)
		for n in g.node_count():
			var f: int = g.node_flags[n]
			if f & ParkGraph.OPEN != 0 and f & (ParkGraph.LINE | ParkGraph.GUARDED | ParkGraph.WARDEN) == 0:
				g.node_flags[n] = f | ParkGraph.DOOR_OK
		_zones()
		if sight:
			_sight()

	# --- Zones (SQ13; the rules are in src/world/park/park_graph.gd) ---

	# Cuts the nodes into zones and joins them by crossings. Labels first: a deck row's lattice is
	# its row; a ground node inside landform rows takes the one with the smallest footprint (the
	# later row on a tie); any other ground node is open ground. A zone is one connected piece of
	# one label (ground edges only, either way), so a wall across the plain makes two open zones
	# and a landform cut in two by another row makes two zones of it. A piece under
	# ZONE_FRAGMENT_NODES that is not the largest piece of its label joins the zone it shares most
	# edges with. Zones are numbered by their lowest node.
	func _zones() -> void:
		var n := g.node_count()
		var lattice := SIDE * SIDE
		var label := PackedInt32Array()
		label.resize(n)
		label.fill(-1)
		var area := PackedFloat32Array()
		area.resize(n)
		area.fill(INF)
		var square := (2.0 * HALF) * (2.0 * HALF)
		for k in rows.size():
			var row: Dictionary = rows[k]
			if row["y"] != null or row["element"] == "anchor_field":
				continue
			var f := Stamps.frame(row)
			var a: float = f["length"] * f["width"]
			if a >= ParkGraph.ZONE_BACKGROUND_SHARE * square:
				continue
			for o in g.inside_nodes(f):
				if a <= area[o]:
					area[o] = a
					label[o] = k
		var open_label := rows.size()
		for o in n:
			if o >= lattice:
				label[o] = g.node_rows[o]
			elif label[o] < 0:
				label[o] = open_label
		# Union by lowest node index: a piece's root is its lowest node.
		var parent := PackedInt32Array()
		parent.resize(n)
		for o in n:
			parent[o] = o
		for a in n:
			for e in range(g.off[a], g.off[a + 1]):
				var b := g.to[e]
				if g.ride[e] < 0 and label[a] == label[b]:
					var ra := _root(parent, a)
					var rb := _root(parent, b)
					if ra != rb:
						parent[maxi(ra, rb)] = mini(ra, rb)
		_merge_fragments(parent, label)
		g.node_zone = PackedInt32Array()
		g.node_zone.resize(n)
		var zone_of_root := {}
		var zone_label := []
		var zone_nodes := []
		for o in n:
			var r := _root(parent, o)
			if not zone_of_root.has(r):
				zone_of_root[r] = zone_label.size()
				zone_label.append(label[r])
				zone_nodes.append(PackedInt32Array())
			g.node_zone[o] = zone_of_root[r]
			zone_nodes[zone_of_root[r]].append(o)
		var made := {}
		var table := []
		for z in zone_label.size():
			var lab: int = zone_label[z]
			var zone_name := "open"
			var kind := "open"
			var row_id := ""
			if lab < rows.size():
				row_id = String(rows[lab]["id"])
				zone_name = row_id
				kind = "deck" if rows[lab]["y"] != null else ("under" if rows[lab]["hole"] else "landform")
			made[zone_name] = int(made.get(zone_name, 0)) + 1
			if made[zone_name] > 1:
				zone_name = "%s.%d" % [zone_name, made[zone_name]]
			var count: int = zone_nodes[z].size()
			var sx := 0.0
			var sz := 0.0
			var line := false
			var warden := false
			var doors := 0
			var d_spawn := INF
			var d_land := INF
			for o in zone_nodes[z]:
				sx += g.px[o]
				sz += g.pz[o]
				var fl: int = g.node_flags[o]
				line = line or fl & ParkGraph.LINE != 0
				warden = warden or fl & ParkGraph.WARDEN != 0
				if fl & ParkGraph.DOOR_OK != 0:
					doors += 1
				d_spawn = minf(d_spawn, g.d_from[o])
				d_land = minf(d_land, g.d_land[o])
			table.append({"id": z, "name": zone_name, "kind": kind, "row": row_id, "nodes": count,
				"cx": snappedf(sx / count, 0.1), "cz": snappedf(sz / count, 0.1), "line": line, "warden": warden,
				"door_ok": doors, "d_spawn": snappedf(d_spawn, 0.01) if d_spawn < INF else -1.0,
				"d_landmark": snappedf(d_land, 0.01) if d_land < INF else -1.0,
				"degree": 0, "openings": 0, "drops": 0, "entrances": [], "exits": []})
		# Crossings: ground edges counted per ordered zone pair, ride edges per row.
		var zc: int = zone_label.size()
		var ground := {}
		var rides := {}
		for a in n:
			var za: int = g.node_zone[a]
			for e in range(g.off[a], g.off[a + 1]):
				var zb: int = g.node_zone[g.to[e]]
				if za == zb:
					continue
				if g.ride[e] >= 0:
					var rk := "%d,%d,%d" % [za, zb, g.ride[e]]
					rides[rk] = int(rides.get(rk, 0)) + 1
				else:
					var gk := za * zc + zb
					ground[gk] = int(ground.get(gk, 0)) + 1
		var crossings := []
		var unordered := {}
		for gk in ground:
			unordered[mini(gk / zc, gk % zc) * zc + maxi(gk / zc, gk % zc)] = true
		var pair_keys := unordered.keys()
		pair_keys.sort()
		for pk in pair_keys:
			var lo: int = pk / zc
			var hi: int = pk % zc
			var f: int = int(ground.get(lo * zc + hi, 0))
			var b: int = int(ground.get(hi * zc + lo, 0))
			if mini(f, b) >= ParkGraph.ZONE_MIN_LINKS:
				crossings.append({"a": lo, "b": hi, "kind": "walk", "row": "", "links": mini(f, b)})
			elif maxi(f, b) >= ParkGraph.ZONE_MIN_LINKS:
				if f >= b:
					crossings.append({"a": lo, "b": hi, "kind": "drop", "row": "", "links": f})
				else:
					crossings.append({"a": hi, "b": lo, "kind": "drop", "row": "", "links": b})
		var ride_keys := rides.keys()
		ride_keys.sort()
		var ride_list := []
		for rk in ride_keys:
			var parts: PackedStringArray = String(rk).split(",")
			ride_list.append({"a": int(parts[0]), "b": int(parts[1]), "kind": "ride", "row": g.names[int(parts[2])], "links": rides[rk]})
		ride_list.sort_custom(func(x, y): return [x["a"], x["b"], x["row"]] < [y["a"], y["b"], y["row"]])
		crossings.append_array(ride_list)
		var entering := []
		var leaving := []
		for z in table.size():
			entering.append({})
			leaving.append({})
		for c in crossings:
			var ca: int = c["a"]
			var cb: int = c["b"]
			if c["kind"] == "drop":
				table[ca]["drops"] += 1
				table[cb]["drops"] += 1
			else:
				table[ca]["openings"] += 1
				table[cb]["openings"] += 1
			leaving[ca][cb] = true
			entering[cb][ca] = true
			if c["kind"] == "walk":
				leaving[cb][ca] = true
				entering[ca][cb] = true
		for z in table.size():
			var into: Array = entering[z].keys()
			into.sort()
			var out: Array = leaving[z].keys()
			out.sort()
			table[z]["entrances"] = into
			table[z]["exits"] = out
			table[z]["degree"] = into.size()
		g.zone_table = table
		g.crossing_table = crossings

	# A piece under ZONE_FRAGMENT_NODES that is not the largest piece of its label joins the piece
	# it shares most ground edges with (the lower root on a tie). Pieces go in node order, so a
	# fragment that borders only another fragment follows it.
	func _merge_fragments(parent: PackedInt32Array, label: PackedInt32Array) -> void:
		var n := parent.size()
		var size := {}
		var best := {}
		for o in n:
			var r := _root(parent, o)
			size[r] = int(size.get(r, 0)) + 1
		for r in size:
			var lab: int = label[r]
			if not best.has(lab) or size[r] > size[best[lab]] or (size[r] == size[best[lab]] and r < best[lab]):
				best[lab] = r
		var members := {}
		for o in n:
			var r := _root(parent, o)
			if size[r] < ParkGraph.ZONE_FRAGMENT_NODES and best[label[r]] != r:
				if not members.has(r):
					members[r] = PackedInt32Array()
				members[r].append(o)
		var roots := members.keys()
		roots.sort()
		for r in roots:
			var links := {}
			for o in members[r]:
				for e in range(g.off[o], g.off[o + 1]):
					var t := _root(parent, g.to[e])
					if t != r:
						links[t] = int(links.get(t, 0)) + 1
				for e in range(g.roff[o], g.roff[o + 1]):
					var t := _root(parent, g.rto[e])
					if t != r:
						links[t] = int(links.get(t, 0)) + 1
			var target := -1
			for t in links:
				if target < 0 or links[t] > links[target] or (links[t] == links[target] and t < target):
					target = t
			if target >= 0:
				parent[r] = target

	static func _root(parent: PackedInt32Array, o: int) -> int:
		var r := o
		while parent[r] != r:
			r = parent[r]
		while parent[o] != r:
			var next := parent[o]
			parent[o] = r
			o = next
		return r

	# Vertex heights: the ground, or on a hole cell the under.bin floor.
	func _heights() -> void:
		vh = ground.duplicate()
		var k := 0
		var cell_under := {}
		for c in BAKE_CELLS * BAKE_CELLS:
			if holes[c] == 1:
				cell_under[c] = under[k] if k < under.size() else ground[(c / BAKE_CELLS) * BAKE_SIDE + c % BAKE_CELLS]
				k += 1
		for j in BAKE_SIDE:
			for i in BAKE_SIDE:
				var c := mini(j, BAKE_CELLS - 1) * BAKE_CELLS + mini(i, BAKE_CELLS - 1)
				if holes[c] == 1:
					vh[j * BAKE_SIDE + i] = cell_under[c]

	func _hole(i: int, j: int) -> bool:
		return holes[mini(j, BAKE_CELLS - 1) * BAKE_CELLS + mini(i, BAKE_CELLS - 1)] == 1

	func _add_node(x: float, y: float, z: float, flags: int, row: int) -> void:
		g.px.append(x)
		g.py.append(y)
		g.pz.append(z)
		g.node_flags.append(flags)
		g.node_rows.append(row)

	func _nodes() -> void:
		for J in SIDE:
			for I in SIDE:
				var i := I * ParkGraph.LATTICE
				var j := J * ParkGraph.LATTICE
				_add_node(-HALF + STEP * I, vh[j * BAKE_SIDE + i], -HALF + STEP * J,
					ParkGraph.UNDER if _hole(i, j) else 0, -1)
		for k in rows.size():
			var row: Dictionary = rows[k]
			deck_start.append(g.node_count())
			if row["y"] == null:
				deck_count.append(0)
				deck_dims.append([0, 0])
				continue
			var f := Stamps.frame(row)
			var na := maxi(1, floori(f["length"] / STEP) + 1)
			var nc := maxi(1, floori(f["width"] / STEP) + 1)
			deck_dims.append([na, nc])
			deck_count.append(na * nc)
			var c: Vector2 = f["at"]
			for a in na:
				for w in nc:
					var p: Vector2 = c + f["along"] * ((a - (na - 1) * 0.5) * STEP) + f["across"] * ((w - (nc - 1) * 0.5) * STEP)
					_add_node(p.x, float(row["y"]), p.y, ParkGraph.DECK, k)

	func _edge(a: int, b: int, ride: int) -> void:
		if a == b:
			return
		e_from.append(a)
		e_to.append(b)
		e_len.append(g.position(a).distance_to(g.position(b)))
		e_ride.append(ride)
		if ride >= 0:
			ride_count += 1

	func _ground_edges() -> void:
		for J in SIDE:
			for I in SIDE:
				var a := J * SIDE + I
				var ya: float = g.py[a]
				for d in DIRS:
					var I2: int = I + d[0]
					var J2: int = J + d[1]
					if I2 < 0 or J2 < 0 or I2 >= SIDE or J2 >= SIDE:
						continue
					var top := -INF
					for k in range(1, ParkGraph.LATTICE + 1):
						top = maxf(top, vh[(J * ParkGraph.LATTICE + k * d[1]) * BAKE_SIDE + I * ParkGraph.LATTICE + k * d[0]])
					if top - ya <= CLIMB_M:
						_edge(a, J2 * SIDE + I2, -1)

	func _deck_edges() -> void:
		for k in rows.size():
			var n := deck_count[k]
			if n == 0:
				continue
			var na: int = deck_dims[k][0]
			var nc: int = deck_dims[k][1]
			var s := deck_start[k]
			for a in na:
				for w in nc:
					var me := s + a * nc + w
					for d in DIRS:
						var a2: int = a + d[0]
						var w2: int = w + d[1]
						if a2 >= 0 and w2 >= 0 and a2 < na and w2 < nc:
							_climb_edge(me, s + a2 * nc + w2)
					if a == 0 or w == 0 or a == na - 1 or w == nc - 1:
						_link(me, k)

	# Border deck node `me` of row k to every node of another kind within LINK_M horizontally.
	func _link(me: int, k: int) -> void:
		var p: Vector3 = g.position(me)
		var c := ParkGraph.lattice_index(p.x, p.z)
		var ci := c % SIDE
		var cj := c / SIDE
		for dj in range(-2, 3):
			for di in range(-2, 3):
				var i := ci + di
				var j := cj + dj
				if i < 0 or j < 0 or i >= SIDE or j >= SIDE:
					continue
				var o := j * SIDE + i
				if Vector2(g.px[o] - p.x, g.pz[o] - p.z).length() <= LINK_M:
					_climb_edge(me, o)
					_climb_edge(o, me)
		for k2 in rows.size():
			if k2 == k or deck_count[k2] == 0:
				continue
			for o in range(deck_start[k2], deck_start[k2] + deck_count[k2]):
				# Each pair once: the lower row links both ways.
				if k2 < k and _is_border(o, k2):
					continue
				if Vector2(g.px[o] - p.x, g.pz[o] - p.z).length() <= LINK_M:
					_climb_edge(me, o)
					_climb_edge(o, me)

	func _is_border(node: int, k: int) -> bool:
		var nc: int = deck_dims[k][1]
		var na: int = deck_dims[k][0]
		var local := node - deck_start[k]
		var a := local / nc
		var w := local % nc
		return a == 0 or w == 0 or a == na - 1 or w == nc - 1

	func _climb_edge(a: int, b: int) -> void:
		if g.py[b] - g.py[a] <= CLIMB_M:
			_edge(a, b, -1)

	# The nodes that stand for a place a route or waymark names.
	func place_nodes(id: String) -> PackedInt32Array:
		if id == ParkSchema.DROP_IN:
			return PackedInt32Array([g.spawn_node])
		if id == ParkSchema.LANDMARK:
			return ring_nodes(park["landmark"]["beacon"], float(park["landmark"]["reach_m"]))
		if row_index.has(id):
			return row_nodes(row_index[id])
		for act in park["activity_rows"]:
			if act["id"] == id:
				return PackedInt32Array([door_node(act["at"], String(act["site"]))])
		return PackedInt32Array()

	func row_nodes(k: int) -> PackedInt32Array:
		if _row_nodes.has(k):
			return _row_nodes[k]
		var out := g.footprint_nodes(rows[k], deck_start[k], deck_count[k])
		_row_nodes[k] = out
		return out

	func ring_nodes(at: Array, radius: float) -> PackedInt32Array:
		return g.disc_nodes(Vector2(float(at[0]), float(at[1])), radius)

	# The door node for a point on a site row: the site's deck when it has y, else the ground.
	func door_node(at: Array, site: String) -> int:
		return g.site_node(park, row_index, deck_start, deck_count, Vector2(float(at[0]), float(at[1])), site)

	func _ride_edges() -> void:
		# Kickers: to the place after them in each route's from-via-to sequence.
		for k in rows.size():
			var row: Dictionary = rows[k]
			if row["verb"] != "launch":
				continue
			var f := Stamps.frame(row)
			var lip: Vector2 = f["at"] + f["along"] * (f["length"] * 0.5)
			var takeoff := door_node([lip.x, lip.y], String(row["id"]))
			# A lip snapped up a face the graph cannot climb (> CLIMB_M) takes off from the kicker's own node. A lip
			# on its footprint's edge holds the node over the face's top itself, with its neighbours along the edge
			# (drum_lip_kicker on the terrace edge): it takes off from the nearest own node below the face.
			var own := row_nodes(k)
			if not own.is_empty() and not own.has(takeoff):
				var near := g.nearest_in(own, Vector3(lip.x, g.position(takeoff).y, lip.y))
				if near >= 0 and g.py[takeoff] - g.py[near] > CLIMB_M:
					takeoff = near
			elif own.has(takeoff):
				var below := PackedInt32Array()
				for n in own:
					if g.py[takeoff] - g.py[n] > CLIMB_M:
						below.append(n)
				if not below.is_empty():
					takeoff = g.nearest_in(below, Vector3(lip.x, g.position(takeoff).y, lip.y))
			var landed := PackedInt32Array()
			for route in park["routes"]:
				var seq := ParkGraph.route_sequence(route)
				for s in range(seq.size() - 1):
					if seq[s] != row["id"]:
						continue
					var land := g.nearest_in(place_nodes(seq[s + 1]), g.position(takeoff))
					if land >= 0 and not landed.has(land):
						landed.append(land)
						_edge(takeoff, land, k)
		# Grind rows both ways along their line; glide rows one-way down along their yaw.
		for k in rows.size():
			var row: Dictionary = rows[k]
			var grind: bool = row["verb"] == "grind" or row["element"] == "grind_line" or row["element"] == "rail"
			if not grind and row["verb"] != "glide":
				continue
			var f := Stamps.frame(row)
			var half: Vector2 = f["along"] * (f["length"] * 0.5)
			var p0: Vector2 = f["at"] - half
			var p1: Vector2 = f["at"] + half
			var a := g.nearest(_point(p0, row["y"]))
			if grind:
				var b := g.nearest(_point(p1, row["y"]))
				if _grind_clear(p0, p1, row["y"], g.py[a]):
					_edge(a, b, k)
				if _grind_clear(p1, p0, row["y"], g.py[b]):
					_edge(b, a, k)
			else:
				_edge(a, g.nearest(p1), k)
		var base := rows.size()
		var contraptions: Array = park["contraption_rows"]
		for c in contraptions.size():
			var row: Dictionary = contraptions[c]
			match String(row["kind"]):
				"launcher":
					var a := door_node(row["at"], String(row["site"]))
					_edge(a, g.nearest(_v3(row["target"])), base + c)
				"cable":
					_edge(g.nearest(_v3(row["from"])), g.nearest(_v3(row["to"])), base + c)
				"thermal", "lift":
					var rise := float(row.get("height", row.get("rise", 0.0)))
					var start := _lowest_near(row["at"], String(row["site"]))
					var top := _column_top(start, Vector2(float(row["at"][0]), float(row["at"][1])), rise)
					if top >= 0:
						_edge(start, top, base + c)

	# A grind line rides along its line, so what stands across it blocks it: on the ground (y
	# null) no 2 m sample from start to end rises more than CLIMB_M above the start, as a ground
	# edge; raised (y set) the ground never rises above the rail.
	func _grind_clear(from: Vector2, dest: Vector2, y, start_y: float) -> bool:
		var steps := maxi(1, ceili(from.distance_to(dest) / 2.0))
		for s in range(1, steps + 1):
			var p := from.lerp(dest, float(s) / steps)
			var i := clampi(roundi((p.x + HALF) / 2.0), 0, BAKE_SIDE - 1)
			var j := clampi(roundi((p.y + HALF) / 2.0), 0, BAKE_SIDE - 1)
			var h := vh[j * BAKE_SIDE + i]
			if y == null and h - start_y > CLIMB_M:
				return false
			if y != null and h > float(y):
				return false
		return true

	func _point(p: Vector2, y) -> Vector3:
		if y == null:
			return Vector3(p.x, g.py[ParkGraph.lattice_index(p.x, p.y)], p.y)
		return Vector3(p.x, float(y), p.y)

	func _v3(a: Array) -> Vector3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))

	# A lift or thermal starts from its site's deck when the site has y, else from the lowest
	# node within START_REACH_M of `at` (the floor it rises from).
	func _lowest_near(at: Array, site: String) -> int:
		var p := Vector2(float(at[0]), float(at[1]))
		if row_index.has(site) and rows[row_index[site]]["y"] != null:
			return door_node(at, site)
		var best := -1
		for n in g.disc_nodes(p, START_REACH_M):
			if best < 0 or g.py[n] < g.py[best]:
				best = n
		return best if best >= 0 else g.nearest(p)

	func _column_top(start: int, at: Vector2, rise: float) -> int:
		var y0: float = g.py[start]
		var top := Vector3(at.x, y0 + rise, at.y)
		var best := -1
		var best_d := INF
		var candidates := g.disc_nodes(at, rise + STEP)
		for n in range(SIDE * SIDE, g.node_count()):
			if Vector2(g.px[n] - at.x, g.pz[n] - at.y).length() <= rise + STEP:
				candidates.append(n)
		for n in candidates:
			var y: float = g.py[n]
			if y <= y0 + CLIMB_M or y > y0 + rise + 0.5:
				continue
			var d := top.distance_squared_to(g.position(n))
			if d < best_d or (d == best_d and n < best):
				best_d = d
				best = n
		return best

	func _csr() -> void:
		var n := g.node_count()
		var m := e_from.size()
		g.off = PackedInt32Array()
		g.off.resize(n + 1)
		for e in m:
			g.off[e_from[e] + 1] += 1
		for k in n:
			g.off[k + 1] += g.off[k]
		var fill := g.off.slice(0, n)
		g.to = PackedInt32Array()
		g.to.resize(m)
		g.length = PackedFloat32Array()
		g.length.resize(m)
		g.ride = PackedInt32Array()
		g.ride.resize(m)
		for e in m:
			var a := e_from[e]
			var at := fill[a]
			g.to[at] = e_to[e]
			g.length[at] = e_len[e]
			g.ride[at] = e_ride[e]
			fill[a] = at + 1
		g.reverse()

	func _flags() -> void:
		var n := g.node_count()
		var roofed := PackedByteArray()
		roofed.resize(n)
		var guarded := PackedByteArray()
		guarded.resize(n)
		for k in rows.size():
			var row: Dictionary = rows[k]
			var is_deck: bool = row["y"] != null
			var is_guarded: bool = ParkSchema.GUARDED_SOCIETIES.has(row["society"])
			if not is_deck and not is_guarded:
				continue
			var f := Stamps.frame(row)
			var inside := g.inside_nodes(f)
			for o in range(deck_start[k], deck_start[k] + deck_count[k]):
				if is_guarded:
					guarded[o] = 1
			for o in range(SIDE * SIDE, n):
				if g.node_rows[o] != k and Stamps.inside(f, g.px[o], g.pz[o]):
					inside.append(o)
			for o in inside:
				if is_guarded:
					guarded[o] = 1
				if is_deck and float(row["y"]) > g.py[o] + ROOF_M:
					roofed[o] = 1
		var beacon := Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))
		var reach := float(park["landmark"]["reach_m"])
		for o in n:
			var f: int = g.node_flags[o]
			if f & ParkGraph.UNDER == 0 and roofed[o] == 0:
				f |= ParkGraph.OPEN
			if guarded[o] == 1:
				f |= ParkGraph.GUARDED
			if Vector2(g.px[o], g.pz[o]).distance_to(beacon) <= reach:
				f |= ParkGraph.WARDEN
			g.node_flags[o] = f

	# The line: spawn -> each middle waymark -> beacon, shortest by path, then every node within
	# LINE_M of it.
	func _line() -> void:
		var current := g.spawn_node
		line_path = PackedInt32Array([current])
		var waymarks: Array = park["waymarks"]
		var targets := []
		for k in range(1, waymarks.size() - 1):
			targets.append(String(waymarks[k]))
		targets.append(ParkSchema.LANDMARK)
		for id in targets:
			var goal := PackedInt32Array([g.beacon_node]) if id == ParkSchema.LANDMARK else place_nodes(id)
			if goal.is_empty():
				line_errors.append("waymark %s has no node" % id)
				break
			var walk: Dictionary = g.search_prev(current)
			var dist: PackedFloat32Array = walk["dist"]
			var best := -1
			for o in goal:
				if dist[o] < INF and (best < 0 or dist[o] < dist[best] or (dist[o] == dist[best] and o < best)):
					best = o
			if best < 0:
				line_errors.append("waymark %s is unreachable from %s on the graph" % [id, _describe(current)])
				break
			var leg := PackedInt32Array()
			var o := best
			while o != current:
				leg.append(o)
				o = walk["prev"][o]
			leg.reverse()
			line_path.append_array(leg)
			current = best
		for s in line_path.size():
			var p: Vector3 = g.position(line_path[s])
			var q: Vector3 = g.position(line_path[mini(s + 1, line_path.size() - 1)])
			var lo := Vector2(minf(p.x, q.x) - LINE_M, minf(p.z, q.z) - LINE_M)
			var hi := Vector2(maxf(p.x, q.x) + LINE_M, maxf(p.z, q.z) + LINE_M)
			var candidates := g.box_nodes(lo, hi)
			for o in range(SIDE * SIDE, g.node_count()):
				if g.px[o] >= lo.x and g.px[o] <= hi.x and g.pz[o] >= lo.y and g.pz[o] <= hi.y:
					candidates.append(o)
			for o in candidates:
				if g.node_flags[o] & ParkGraph.LINE == 0 and _segment_distance(g.position(o), p, q) <= LINE_M:
					g.node_flags[o] |= ParkGraph.LINE

	func _describe(node: int) -> String:
		var p: Vector3 = g.position(node)
		return "[%d, %d]" % [roundi(p.x), roundi(p.z)]

	func _sight() -> void:
		var bucket_m := 64.0
		var buckets := {}
		var line_nodes := PackedInt32Array()
		for o in g.node_count():
			if g.node_flags[o] & ParkGraph.LINE != 0:
				line_nodes.append(o)
				var key := _bucket(g.px[o], g.pz[o], bucket_m)
				if not buckets.has(key):
					buckets[key] = PackedInt32Array()
				var list: PackedInt32Array = buckets[key]
				list.append(o)
				buckets[key] = list
		var reach := ceili(SIGHT_M / bucket_m)
		for o in g.node_count():
			if g.node_flags[o] & ParkGraph.LINE != 0:
				g.node_flags[o] |= ParkGraph.SIGHT_OK
				continue
			var p: Vector3 = g.position(o)
			var bx := floori((p.x + 1024.0) / bucket_m)
			var bz := floori((p.z + 1024.0) / bucket_m)
			var near := []
			for dz in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var key := (bz + dz) * 1000 + (bx + dx)
					if not buckets.has(key):
						continue
					for l in buckets[key]:
						var d := p.distance_to(g.position(l))
						if d <= SIGHT_M:
							near.append([d, l])
			if near.is_empty():
				continue
			near.sort()
			var stride := maxi(1, ceili(float(near.size()) / SIGHT_TRIES))
			var tries := [0]
			for k in range(stride, near.size(), stride):
				tries.append(k)
			for k in tries:
				if _clear(p, g.position(near[k][1])):
					g.node_flags[o] |= ParkGraph.SIGHT_OK
					break

	func _bucket(x: float, z: float, size: float) -> int:
		return floori((z + 1024.0) / size) * 1000 + floori((x + 1024.0) / size)

	func _clear(a: Vector3, b: Vector3) -> bool:
		var from := a + Vector3(0, EYE_M, 0)
		var dest := b + Vector3(0, EYE_M, 0)
		var dist := from.distance_to(dest)
		var steps := floori(dist / SIGHT_STEP_M)
		for s in range(1, steps):
			var p := from.lerp(dest, s * SIGHT_STEP_M / dist)
			if _terrain(p.x, p.z) > p.y:
				return false
		return true

	# The ground under (x, z), bilinear over the 2 m grid of ground.bin (holes ignored).
	func _terrain(x: float, z: float) -> float:
		var fx := clampf((x + HALF) / 2.0, 0.0, BAKE_SIDE - 1.001)
		var fz := clampf((z + HALF) / 2.0, 0.0, BAKE_SIDE - 1.001)
		var i := floori(fx)
		var j := floori(fz)
		var u := fx - i
		var v := fz - j
		var h00 := ground[j * BAKE_SIDE + i]
		var h10 := ground[j * BAKE_SIDE + i + 1]
		var h01 := ground[(j + 1) * BAKE_SIDE + i]
		var h11 := ground[(j + 1) * BAKE_SIDE + i + 1]
		return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)

	static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 <= 0.0:
			return p.distance_to(a)
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		return p.distance_to(a + ab * t)


# --- The ruling: what the graph says about the park (PARK.md 2.11 and 2.12). ---

# Per route, the steps where the graph does not connect it: [] when connected. Each step goes
# from the nodes reached so far to the next place's nodes; only the nodes reached carry on.
static func route_steps(graph, park: Dictionary) -> Dictionary:
	var index := Index.new(graph, park)
	var out := {}
	for route in park["routes"]:
		var seq := ParkGraph.route_sequence(route)
		var breaks := []
		var current := index.place_nodes(seq[0])
		if current.is_empty():
			breaks.append("%s has no node" % seq[0])
		for s in range(1, seq.size()):
			if current.is_empty():
				break
			var seen: PackedByteArray = graph.reach(current)
			var next := PackedInt32Array()
			for o in index.place_nodes(seq[s]):
				if seen[o] == 1:
					next.append(o)
			if next.is_empty():
				breaks.append("%s -> %s: no path" % [seq[s - 1], seq[s]])
			current = next
		out[String(route["id"])] = breaks
	return out


static func route_breaks(graph, park: Dictionary) -> Array:
	var out := []
	var steps := route_steps(graph, park)
	for route in park["routes"]:
		for step in steps[String(route["id"])]:
			out.append({"route": String(route["id"]), "step": step})
	return out


# The spawn's d_landmark against the open nodes: ok when at most a quarter of the open nodes
# with a path to the beacon lie farther (PARK.md 2.11).
static func spawn_check(graph, park: Dictionary) -> Dictionary:
	var at: Array = park["spawn"]["at"]
	var spawn: int = graph.nearest(Vector2(float(at[0]), float(at[1])))
	var d: float = graph.d_land[spawn]
	var open := 0
	var farther := 0
	for o in graph.node_count():
		if graph.node_flags[o] & ParkGraph.OPEN == 0 or graph.d_land[o] == INF:
			continue
		open += 1
		if graph.d_land[o] > d:
			farther += 1
	var share := float(farther) / maxf(1.0, float(open))
	return {"ok": d < INF and share <= 0.25, "d_landmark": d, "farther_share": share, "open": open}


# SR15: is the beacon on an objective-fit node. The disc is read from the park file's beacon and
# reach_m on the graph's ground lattice, so a planted beacon is judged where it stands. Returns
# {"ok", "radius_m", "nodes", "rise_m", "closed", "decks", "reasons"}: closed counts disc nodes
# that are not open (a roof, a hole), decks the deck nodes inside the disc, rise_m the largest
# height difference from the beacon's node.
# A sinkhole mounting whose pit takes the swarm's pool slab (the ground under the pool centre at
# or below the first floor, warden_swarm.gd's own test) has a rising floor of its own: the pool's
# nodes count for open but not for rise, and the rise is the spread of the disc's nodes outside
# the pool. "pool" in the result is that pool, {} when the plain rule ran.
# A headframe mounting fights over floors its landmark's model dresses (rows whose recipe is "landmark": the collar
# dish round the shaft and the tipple deck the drop finisher lands from, park/stages/3-park_pit.md section 2): their
# ground nodes do not count for rise, ground they roof is not closed, their deck nodes are no second floor, and the
# rise is the spread of the disc's other nodes. "floors" in the result names those rows, [] when the plain rule ran.
static func beacon_check(graph, park: Dictionary) -> Dictionary:
	var at := Vector2(float(park["landmark"]["beacon"][0]), float(park["landmark"]["beacon"][1]))
	var radius := float(park["landmark"]["reach_m"]) * BEACON_DISC_SHARE
	var centre: int = ParkGraph.lattice_index(at.x, at.y)
	var base: float = graph.py[centre]
	var pool := _beacon_pool(graph, park)
	var floors := _mounting_floors(park)
	var lip_low := INF
	var lip_high := -INF
	var nodes := 0
	var closed := 0
	var decks := 0
	var rise := 0.0
	for o in graph.disc_nodes(at, radius):
		if o >= SIDE * SIDE:
			continue
		nodes += 1
		var p := Vector2(graph.px[o], graph.pz[o])
		var roofed := floors.any(func(row: Dictionary) -> bool: return row["y"] != null and _in_footprint(row, p))
		if graph.node_flags[o] & ParkGraph.OPEN == 0 and not roofed:
			closed += 1
		if not floors.is_empty():
			if not floors.any(func(row: Dictionary) -> bool: return _in_footprint(row, p)):
				lip_low = minf(lip_low, graph.py[o])
				lip_high = maxf(lip_high, graph.py[o])
		elif pool.is_empty():
			rise = maxf(rise, absf(graph.py[o] - base))
		elif p.distance_to(pool["centre"]) > float(pool["radius_m"]):
			lip_low = minf(lip_low, graph.py[o])
			lip_high = maxf(lip_high, graph.py[o])
	if not (pool.is_empty() and floors.is_empty()) and lip_high >= lip_low:
		rise = lip_high - lip_low
	var floor_ids := floors.map(func(row: Dictionary) -> String: return String(row["id"]))
	# A deck row inside the disc (a ledge, a bridge) is a floor of its own: the beacon is then
	# on a ledge or under one, and the fight has two floors.
	for o in range(SIDE * SIDE, graph.node_count()):
		if Vector2(graph.px[o], graph.pz[o]).distance_to(at) <= radius and not floor_ids.has(graph.node_row(o)):
			decks += 1
			rise = maxf(rise, absf(graph.py[o] - base))
	var reasons := []
	if closed > 0:
		reasons.append("%d of %d disc nodes are not open" % [closed, nodes])
	if decks > 0:
		reasons.append("%d deck nodes stand inside the disc" % decks)
	if rise > BEACON_FLAT_M:
		reasons.append("the disc rises %.2f m, want at most %.1f m" % [rise, BEACON_FLAT_M])
	return {"ok": reasons.is_empty() and nodes > 0, "radius_m": radius, "nodes": nodes, "rise_m": rise,
		"closed": closed, "decks": decks, "reasons": reasons, "pool": pool, "floors": floor_ids}


# The rows a headframe mounting fights over (beacon_check): the park rows its landmark's model dresses. [] for any
# other mounting.
static func _mounting_floors(park: Dictionary) -> Array:
	var w = park["landmark"].get("warden", {})
	if not w is Dictionary or w.get("mounting") != WardenSwarm.HEADFRAME:
		return []
	return park["park_rows"].filter(func(row: Dictionary) -> bool: return row.get("recipe") == ParkRecipes.LANDMARK_DRESSED)


# Whether p lies on a row's footprint: size[0] along the row's facing (yaw_deg, 0 faces +z), size[2] across it.
static func _in_footprint(row: Dictionary, p: Vector2) -> bool:
	var d := p - Vector2(float(row["at"][0]), float(row["at"][1]))
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var along := d.x * sin(yaw) + d.y * cos(yaw)
	var across := d.x * cos(yaw) - d.y * sin(yaw)
	return absf(along) <= float(row["size"][0]) * 0.5 + FOOTPRINT_EPS_M and absf(across) <= float(row["size"][2]) * 0.5 + FOOTPRINT_EPS_M


# The swarm pool a sinkhole mounting fights over, placed as warden_swarm.gd places it (spec
# pool_centre and pool_floor, else POOL_OFFSET and POOL_BELOW_NEST from the nest anchor), when the
# ground under its centre takes the slab: {"centre" (Vector2), "floor_y", "radius_m"}, else {}.
static func _beacon_pool(graph, park: Dictionary) -> Dictionary:
	var w = park["landmark"].get("warden", {})
	if not w is Dictionary or w.get("mounting") != WardenSwarm.SINKHOLE or not w.get("anchor") is Array:
		return {}
	var anchor := Vector3(float(w["anchor"][0]), float(w["anchor"][1]), float(w["anchor"][2]))
	var c := anchor + WardenSwarm.POOL_OFFSET
	if w.get("pool_centre") is Array:
		c = Vector3(float(w["pool_centre"][0]), 0.0, float(w["pool_centre"][2]))
	var floor_y := float(w.get("pool_floor", anchor.y - WardenSwarm.POOL_BELOW_NEST))
	if graph.py[ParkGraph.lattice_index(c.x, c.z)] > floor_y + 0.5:
		return {}
	return {"centre": Vector2(c.x, c.z), "floor_y": floor_y, "radius_m": WardenSwarm.POOL_RADIUS}


# SR15: the stage rules in order, the beacon before the spawn (the spawn rule measures from the
# beacon, so it means nothing when the beacon is off). Stops at the first failure and names it:
# {"ok", "checked", "first_failed", "beacon", "spawn"}; a rule not run is absent from "checked".
static func stage_checks(graph, park: Dictionary) -> Dictionary:
	var out := {"ok": false, "checked": [], "first_failed": "", "beacon": {}, "spawn": {}}
	out["checked"].append("beacon_ok")
	out["beacon"] = beacon_check(graph, park)
	if not out["beacon"]["ok"]:
		out["first_failed"] = "beacon_ok"
		return out
	out["checked"].append("spawn")
	out["spawn"] = spawn_check(graph, park)
	if not out["spawn"]["ok"]:
		out["first_failed"] = "spawn"
		return out
	out["ok"] = true
	return out


# The four pockets (PARK.md 2.12): roles, door nodes, distances and breaches.
# rows_only returns the same pocket selection before the node and distance evaluation.
static func pockets(graph, park: Dictionary, rows_only := false) -> Dictionary:
	var rows := []
	var breaches := []
	var waymarks: Array = park["waymarks"]
	var online_id := ""
	for act in park["activity_rows"]:
		if waymarks.has(act["id"]):
			online_id = act["id"]
			break
	if online_id.is_empty():
		for act in park["activity_rows"]:
			if ONLINE_KINDS.has(act["activity"]):
				online_id = act["id"]
				break
	for act in park["activity_rows"]:
		var role := "extra"
		if act["id"] == online_id:
			role = "online"
		# A cache whose wall bar is a speed tier (activities.gd BARS, W1-76) is a skill ask that stands on a
		# fast line on purpose, not a detour reward: role "skill" keeps the sight and clear-ring checks only.
		elif act.has("bar"):
			role = "skill"
		elif REWARD_KINDS.has(act["activity"]):
			role = "reward"
		elif RISK_KINDS.has(act["activity"]):
			role = "risk"
		elif EVENT_KINDS.has(act["activity"]):
			role = "event"
		var pay := _pay(act.get("pay", {}))
		rows.append({"id": String(act["id"]), "role": role, "kind": String(act["activity"]),
			"site": String(act["site"]), "at": act["at"], "pay_at": act["at"], "pay_rarities": pay["rarities"], "pay_named": pay["named"]})
	# The hidden pocket: the first valve or cracked_wall that seals a cache (the stage 1 draft's
	# gallery_valve shape), else the first valve or cracked_wall.
	var hidden := _hidden_row(park)
	if not hidden.is_empty():
		var at: Array = hidden["door"]["at"] if hidden.has("door") else hidden["at"]
		var pay_at: Array = hidden["cache"]["at"] if hidden.get("cache") is Dictionary and hidden["cache"].has("at") else at
		rows.append({"id": String(hidden["id"]), "role": "hidden", "kind": String(hidden["kind"]),
			"site": String(hidden["site"]), "at": at, "pay_at": pay_at, "pay_rarities": [], "pay_named": ""})

	if rows_only:
		return {"rows": rows}
	var index := Index.new(graph, park)
	var roles := []
	for row in rows:
		roles.append(row["role"])
	for role in ["online", "hidden"]:
		if roles.count(role) != 1:
			breaches.append(_breach("park", "count", "%d %s pockets, want 1" % [roles.count(role), role]))
	for role in ["reward", "risk"]:
		if roles.count(role) < 1 or roles.count(role) > OFFLINE_MAX:
			breaches.append(_breach("park", "count", "%d %s pockets, want 1 to %d" % [roles.count(role), role, OFFLINE_MAX]))
	for row in rows:
		if row["role"] == "extra":
			breaches.append(_breach(row["id"], "count", "a %s is none of on-line, reward or risk" % row["kind"]))

	var beacon_d: float = graph.d_from[graph.beacon_node]
	# Two distances, two points (PARK.md 2.12): door_m from the nearest line node to the door
	# node, detour_m from the nearest line node to the pay point's node (the activity row's at,
	# the hidden pocket's cache, else its door). An activity row has one at, so its two coincide.
	var line_nodes := PackedInt32Array()
	for o in graph.node_count():
		if graph.node_flags[o] & ParkGraph.LINE != 0:
			line_nodes.append(o)
	var from_line: PackedFloat32Array = graph.search(line_nodes)
	var forward := {}
	for row in rows:
		var door := index.door(row["at"], row["site"])
		var pay_node := index.door(row["pay_at"], row["site"])
		var p: Vector3 = graph.position(door)
		row["door"] = door
		row["door_at"] = [roundi(p.x), roundi(p.z)]
		row["d_spawn"] = graph.d_from[door]
		row["d_landmark"] = graph.d_land[door]
		row["door_m"] = from_line[door]
		row["detour_m"] = from_line[pay_node]
		row["sight_ok"] = graph.node_flags[door] & ParkGraph.SIGHT_OK != 0
		row["flags"] = graph.flag_names(door)
		forward[row["id"]] = graph.search(PackedInt32Array([door]))
		row["clear_ring"] = _ring(graph, park, index, door)

	var off_line := []
	for row in rows:
		if row["role"] in ["reward", "risk", "hidden"]:
			off_line.append(row)
	for row in rows:
		row["nearest_door"] = INF
		row["nearest_door_id"] = ""
		if not off_line.has(row):
			continue
		for other in off_line:
			if other == row:
				continue
			var d := minf(forward[row["id"]][other["door"]], forward[other["id"]][row["door"]])
			if d < row["nearest_door"]:
				row["nearest_door"] = d
				row["nearest_door_id"] = other["id"]

	for row in rows:
		var id: String = row["id"]
		var role: String = row["role"]
		var f: int = graph.node_flags[row["door"]]
		if not row["sight_ok"]:
			breaches.append(_breach(id, "sight", "no clear ray from the door to a line node within %d m" % SIGHT_M))
		if not row["clear_ring"].is_empty():
			breaches.append(_breach(id, "clear_ring", "within %d m of the door: %s" % [RING_M, ", ".join(row["clear_ring"])]))
		if role in ["online", "extra", "event", "skill"]:
			continue
		if row["d_spawn"] < DOOR_SPAWN_M:
			breaches.append(_breach(id, "spawn", "%s m from the spawn, want at least %d" % [_m(row["d_spawn"]), DOOR_SPAWN_M]))
		if row["nearest_door"] < DOOR_DOOR_M:
			breaches.append(_breach(id, "door_to_door", "%s m from %s, want at least %d" % [_m(row["nearest_door"]), row["nearest_door_id"], DOOR_DOOR_M]))
		if f & ParkGraph.LINE != 0:
			breaches.append(_breach(id, "off_line", "the door is a line node"))
		if f & ParkGraph.WARDEN != 0:
			breaches.append(_breach(id, "warden", "the door is inside the engage ring"))
		if f & ParkGraph.GUARDED != 0:
			breaches.append(_breach(id, "guarded", "the door is inside a guarded row"))
		if role == "hidden":
			var n := _site_routes(park, index, row["site"])
			if n < HIDDEN_ROUTES:
				breaches.append(_breach(id, "hidden_routes", "site %s lists %d routes, want at least %d" % [row["site"], n, HIDDEN_ROUTES]))
			continue
		if f & ParkGraph.OPEN == 0:
			breaches.append(_breach(id, "open", "the door has a roof"))
		if row["d_landmark"] < DOOR_BEACON_M:
			breaches.append(_breach(id, "beacon", "%s m from the beacon, want at least %d" % [_m(row["d_landmark"]), DOOR_BEACON_M]))
		if row["detour_m"] < DETOUR_MIN_M or row["detour_m"] > DETOUR_MAX_M:
			breaches.append(_breach(id, "detour", "detour %s m from the line to the pay point, want %d to %d" % [_m(row["detour_m"]), DETOUR_MIN_M, DETOUR_MAX_M]))
	var reward := _role(rows, "reward")
	var risk := _role(rows, "risk")
	if not reward.is_empty() and not risk.is_empty() and reward["detour_m"] <= risk["detour_m"]:
		breaches.append(_breach(reward["id"], "detour_order", "reward detour %s m is not larger than the risk's %s m" % [_m(reward["detour_m"]), _m(risk["detour_m"])]))
	breaches.append_array(_pay_ladder(rows))
	var full := _full_visit(graph, rows, forward)
	var ratio := INF
	if full < INF and beacon_d > 0.0 and beacon_d < INF:
		ratio = full / beacon_d
	var reward_ratio := _reward_ratio(rows, beacon_d)
	var targets := [
		{"name": "full_visit_ratio", "value": ratio, "target": "at most %.1f" % FULL_VISIT_RATIO_MAX, "ok": ratio < INF and ratio <= FULL_VISIT_RATIO_MAX},
	]
	return {"rows": rows, "breaches": breaches, "beacon_d_spawn": beacon_d, "full_visit_m": full, "full_visit_ratio": ratio,
		"reward_ratio": reward_ratio, "targets": targets}


# The hidden pocket's contraption row: the first valve or cracked_wall that seals a cache, else the
# first valve or cracked_wall; {} when there is none.
static func _hidden_row(park: Dictionary) -> Dictionary:
	var hidden := {}
	for c in park["contraption_rows"]:
		if HIDDEN_KINDS.has(c["kind"]) and (hidden.is_empty() or (c.has("cache") and not hidden.has("cache"))):
			hidden = c
	return hidden


# The median spawn-to-pocket path over the spawn-to-beacon path, across the off-line pockets
# (reward, risk, hidden: the pockets that pay for a detour). INF when a door or the beacon is out
# of reach or there is no such pocket.
static func _reward_ratio(rows: Array, beacon_d: float) -> float:
	var d := []
	for row in rows:
		if row["role"] in ["reward", "risk", "hidden"]:
			d.append(row["d_spawn"])
	if d.is_empty() or beacon_d <= 0.0 or beacon_d == INF or d.has(INF):
		return INF
	d.sort()
	var mid := d.size() / 2
	var median: float = d[mid] if d.size() % 2 == 1 else (d[mid - 1] + d[mid]) * 0.5
	return median / beacon_d


# One printable line per target, out of target marked: "full_visit_ratio 1.712 (target at most 3.0): in target".
static func target_lines(ruling_rows: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for row in ruling_rows.get("targets", []):
		var v: float = row["value"]
		var text := "unreachable" if (v == INF or v < 0.0) else "%.3f" % v
		out.append("%s %s (start target %s, reported): %s" % [row["name"], text, row["target"], "in target" if row["ok"] else "OUT OF TARGET"])
	return out



static func _pay(pay: Dictionary) -> Dictionary:
	return Placement._pay(pay)


static func _within(rarities: Array, allowed: Array) -> bool:
	return Placement._within(rarities, allowed)


# The pay ladder over the activity rows. The off-line pair is ranked by detour, the reward taken
# as the larger on a tie (detour_order already logs the tie).
static func _pay_ladder(rows: Array) -> Array:
	var out := []
	for row in rows:
		if row["role"] != "hidden" and row["pay_rarities"].is_empty():
			out.append(_breach(row["id"], "pay", "no pay.rarities and no named part the parts table knows"))
	var online := _role(rows, "online")
	if not online.is_empty() and not online["pay_rarities"].is_empty() and not _within(online["pay_rarities"], PAY_ONLINE):
		out.append(_breach(online["id"], "pay", "the on-line part pays %s, want %s" % [_rarity_text(online), ", ".join(PAY_ONLINE)]))
	var reward := _role(rows, "reward")
	var risk := _role(rows, "risk")
	if reward.is_empty() or risk.is_empty():
		return out
	var far := reward
	var near := risk
	if risk["detour_m"] > reward["detour_m"]:
		far = risk
		near = reward
	if not far["pay_rarities"].is_empty() and far["pay_rarities"] != PAY_FAR:
		out.append(_breach(far["id"], "pay", "the larger detour (%s m) pays %s, want %s only" % [_m(far["detour_m"]), _rarity_text(far), ", ".join(PAY_FAR)]))
	if not near["pay_rarities"].is_empty() and not _within(near["pay_rarities"], PAY_NEAR):
		out.append(_breach(near["id"], "pay", "the smaller detour (%s m) pays %s, want within %s" % [_m(near["detour_m"]), _rarity_text(near), ", ".join(PAY_NEAR)]))
	return out


static func _rarity_text(row: Dictionary) -> String:
	if row["role"] == "hidden":
		return "-"
	if row["pay_rarities"].is_empty():
		return "missing"
	var text := ", ".join(PackedStringArray(row["pay_rarities"]))
	return text if row["pay_named"] == "" else "%s (%s)" % [text, row["pay_named"]]


# The shortest path from the spawn through every pocket door, in any order, to the beacon
# (K-UNITS KB8, reported): d_spawn to the first door, door to door by forward search, d_landmark
# from the last. INF when no order has a path.
static func _full_visit(graph, rows: Array, forward: Dictionary) -> float:
	if rows.is_empty():
		return INF
	var left := []
	for i in rows.size():
		left.append(i)
	return _visit_from(graph, rows, forward, -1, left, 0.0)


static func _visit_from(graph, rows: Array, forward: Dictionary, at: int, left: Array, so_far: float) -> float:
	if left.is_empty():
		return so_far + graph.d_land[rows[at]["door"]]
	var best := INF
	for i in left:
		var leg: float = graph.d_from[rows[i]["door"]] if at < 0 else forward[rows[at]["id"]][rows[i]["door"]]
		if leg == INF:
			continue
		var rest: Array = left.duplicate()
		rest.erase(i)
		best = minf(best, _visit_from(graph, rows, forward, i, rest, so_far + leg))
	return best


static func _role(rows: Array, role: String) -> Dictionary:
	for row in rows:
		if row["role"] == role:
			return row
	return {}


static func _site_routes(park: Dictionary, index, site: String) -> int:
	if not index.row_index.has(site):
		return 0
	return park["park_rows"][index.row_index[site]]["routes"].size()


# What stands within RING_M of the door by path, either way: home sites, destructive event
# sites, hazard contraptions.
static func _ring(graph, park: Dictionary, index, door: int) -> PackedStringArray:
	var out_d: PackedFloat32Array = graph.search(PackedInt32Array([door]), false, RING_M)
	var in_d: PackedFloat32Array = graph.search(PackedInt32Array([door]), true, RING_M)
	var near := func(nodes: PackedInt32Array) -> bool:
		for o in nodes:
			if out_d[o] <= RING_M or in_d[o] <= RING_M:
				return true
		return false
	var hits := PackedStringArray()
	for home in park["home_rows"]:
		if near.call(index.row_nodes(String(home["site"]))):
			hits.append("home %s (site %s)" % [home["id"], home["site"]])
	for event in park["event_rows"]:
		if DESTRUCTIVE_EVENTS.has(event["kind"]) and near.call(index.row_nodes(String(event["site"]))):
			hits.append("%s %s (site %s)" % [event["kind"], event["id"], event["site"]])
	for c in park["contraption_rows"]:
		if HAZARD_CONTRAPTIONS.has(c["kind"]):
			var at := Vector2(float(c["at"][0]), float(c["at"][1]))
			if near.call(graph.disc_nodes(at, float(c.get("radius", 0.0)))):
				hits.append("%s %s" % [c["kind"], c["id"]])
	return hits


static func _breach(pocket: String, rule: String, detail: String) -> Dictionary:
	var action := "fix"
	if MOVE_RULES.has(rule):
		action = "move"
	elif LOG_RULES.has(rule):
		action = "log"
	return {"pocket": pocket, "rule": rule, "action": action, "detail": detail}


static func _m(d: float) -> String:
	return "unreachable" if d == INF else str(roundi(d))


static func _json_m(d: float) -> int:
	return -1 if d == INF else roundi(d)


# graph.json's ruling: counts, the spawn-to-beacon share, routes, spawn and pockets.
static func ruling(graph, park: Dictionary, built: Dictionary) -> Dictionary:
	var counts := {"open": 0, "line": 0, "door_ok": 0, "sight_ok": 0, "deck": 0, "under": 0}
	for o in graph.node_count():
		var f: int = graph.node_flags[o]
		for bit in [ParkGraph.OPEN, ParkGraph.LINE, ParkGraph.DOOR_OK, ParkGraph.SIGHT_OK, ParkGraph.DECK, ParkGraph.UNDER]:
			if f & bit != 0:
				counts[ParkGraph.FLAG_NAMES[bit]] += 1
	var longest := _longest(graph)
	var spawn_beacon: float = graph.d_from[graph.beacon_node]
	var stage := stage_checks(graph, park)
	var spawn_run: bool = stage["checked"].has("spawn")
	var spawn: Dictionary = stage["spawn"] if spawn_run else {"ok": false, "d_landmark": INF, "farther_share": 0.0}
	var pocket := pockets(graph, park)
	var pocket_rows := []
	for row in pocket["rows"]:
		pocket_rows.append({"id": row["id"], "role": row["role"], "kind": row["kind"], "site": row["site"],
			"door_at": row["door_at"], "d_spawn": _json_m(row["d_spawn"]), "d_landmark": _json_m(row["d_landmark"]),
			"door_m": _json_m(row["door_m"]), "detour_m": _json_m(row["detour_m"]), "sight_ok": row["sight_ok"],
			"clear_ring": Array(row["clear_ring"]), "nearest_door": _json_m(row["nearest_door"]),
			"nearest_door_id": row["nearest_door_id"], "flags": Array(row["flags"]),
			"pay_rarities": row["pay_rarities"], "pay_named": row["pay_named"]})
	var ratio := "unreachable"
	if pocket["full_visit_ratio"] < INF:
		ratio = "%.3f" % pocket["full_visit_ratio"]
	var reward := "unreachable"
	if pocket["reward_ratio"] < INF:
		reward = "%.3f" % pocket["reward_ratio"]
	var targets := []
	for row in pocket["targets"]:
		targets.append({"name": row["name"], "value": -1.0 if row["value"] == INF else snappedf(row["value"], 0.001),
			"target": row["target"], "ok": row["ok"]})
	return {
		"nodes": graph.node_count(), "edges": graph.edge_count(), "ride_edges": built["ride_edges"],
		"flags": counts, "line_path_nodes": built["line_path"].size(),
		"spawn_beacon_m": _json_m(spawn_beacon), "longest_est_m": _json_m(longest),
		"spawn_beacon_share": "%.3f" % (spawn_beacon / longest if longest > 0.0 and spawn_beacon < INF else 0.0),
		"spawn": {"ok": spawn["ok"], "run": spawn_run, "d_landmark": _json_m(spawn["d_landmark"]), "farther_share": "%.3f" % spawn["farther_share"]},
		"stage_checked": stage["checked"], "first_failed": stage["first_failed"],
		"routes": route_steps(graph, park),
		"pockets": pocket_rows, "breaches": pocket["breaches"],
		"full_visit_m": _json_m(pocket["full_visit_m"]), "full_visit_ratio": ratio,
		"reward_ratio": reward, "beacon_ok": stage["beacon"]["ok"], "targets": targets,
		"zones": zone_summary(graph, park),
	}


# The graph's longest shortest path, estimated (a lower bound) by two sweeps: the largest
# finite d_spawn and d_landmark, and the eccentricity of the node farthest from the beacon and
# of the node farthest from the spawn.
static func _longest(graph) -> float:
	var best := 0.0
	var far_land := -1
	var far_spawn := -1
	for o in graph.node_count():
		if graph.d_land[o] < INF and (far_land < 0 or graph.d_land[o] > graph.d_land[far_land]):
			far_land = o
		if graph.d_from[o] < INF and (far_spawn < 0 or graph.d_from[o] > graph.d_from[far_spawn]):
			far_spawn = o
	if far_land >= 0:
		best = maxf(best, graph.d_land[far_land])
		best = maxf(best, _max_finite(graph.search(PackedInt32Array([far_land]))))
	if far_spawn >= 0:
		best = maxf(best, graph.d_from[far_spawn])
		best = maxf(best, _max_finite(graph.search(PackedInt32Array([far_spawn]), true)))
	return best


static func _max_finite(d: PackedFloat32Array) -> float:
	var best := 0.0
	for v in d:
		if v < INF and v > best:
			best = v
	return best


# The pocket table a KD unit pastes (Markdown), and the breaches under it.
static func pocket_table(ruling_rows: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("| pocket | role | door [x, z] | d_spawn m | d_landmark m | door_m (line to door) | detour_m (line to pay) | sight_ok | clear ring 40 m | nearest door m | pay.rarities |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
	for row in ruling_rows["rows"]:
		var ring: Array = Array(row["clear_ring"])
		lines.append("| %s | %s | [%d, %d] | %s | %s | %s | %s | %s | %s | %s | %s |" % [row["id"], row["role"],
			row["door_at"][0], row["door_at"][1], _cell(row["d_spawn"]), _cell(row["d_landmark"]),
			_cell(row["door_m"]), _cell(row["detour_m"]), "yes" if row["sight_ok"] else "no",
			"clear" if ring.is_empty() else "; ".join(ring),
			"-" if row["nearest_door_id"] == "" else "%s (%s)" % [_cell(row["nearest_door"]), row["nearest_door_id"]],
			_rarity_text(row)])
	if ruling_rows["breaches"].is_empty():
		lines.append("")
		lines.append("Breaches: none.")
	else:
		lines.append("")
		lines.append("Breaches (move: the graph moves the pocket; log: logged for the sitting; fix: the park file is wrong):")
		for b in ruling_rows["breaches"]:
			lines.append("- %s %s (%s): %s" % [b["pocket"], b["rule"], b["action"], b["detail"]])
	lines.append("")
	lines.append("Targets (reported, not gated):")
	for line in target_lines(ruling_rows):
		lines.append("- " + line)
	if ruling_rows.has("reward_ratio"):
		lines.append("- " + reward_line(ruling_rows["reward_ratio"]))
	return "\n".join(lines)


# reward_ratio as information only (ruling ac, 26 Oct; park_placement.gd).
static func reward_line(value) -> String:
	var text: String = value if value is String else ("unreachable" if (value == INF or value < 0.0) else "%.3f" % value)
	return "reward_ratio %s (information only, no target: ruling ac, the beacon is the park's far end)" % text


static func _cell(v) -> String:
	if v is float or v is int:
		return "unreachable" if (v == INF or v < 0) else str(roundi(v))
	return str(v)


static func report_text(info: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("park_graph: %s: %d nodes, %d edges (%d ride), %d bytes" % [info["map"], info["nodes"], info["edges"], info["ride_edges"], info["bytes"]])
	lines.append("flags: %s" % JSON.stringify(info["flags"], "", true))
	for problem in info.get("line_errors", []):
		lines.append("LINE BROKEN: %s" % problem)
	lines.append("spawn to beacon %s m over the longest shortest path (estimate) %s m: share %s (start target 0.6, reported)" % [
		info["spawn_beacon_m"], info["longest_est_m"], info["spawn_beacon_share"]])
	if info["spawn"].get("run", true):
		lines.append("spawn d_landmark %s m, farther share of open nodes %s: %s" % [info["spawn"]["d_landmark"],
			info["spawn"]["farther_share"], "farthest quarter" if info["spawn"]["ok"] else "NOT in the farthest quarter"])
	else:
		lines.append("spawn rule not run: the beacon rule failed first")
	if String(info.get("first_failed", "")) != "":
		lines.append("first failed: %s" % info["first_failed"])
	else:
		lines.append("stage rules: %s passed" % ", ".join(info.get("stage_checked", [])))
	var ids: Array = info["routes"].keys()
	ids.sort()
	for id in ids:
		var steps: Array = info["routes"][id]
		lines.append("route %s: %s" % [id, "connected" if steps.is_empty() else "; ".join(steps)])
	var full := _cell(info["full_visit_m"])
	lines.append("full visit: spawn through every pocket door to the beacon %s over spawn to beacon: full_visit_ratio %s (start target at most 3.0, reported)" % [
		full if full == "unreachable" else full + " m", info["full_visit_ratio"]])
	if info.has("zones"):
		lines.append(zone_text(info["zones"]))
	lines.append("")
	lines.append("beacon_ok: %s" % ("yes" if info["beacon_ok"] else "NO: the beacon is not on an objective-fit node"))
	lines.append(pocket_table({"rows": info["pockets"], "breaches": info["breaches"], "targets": info["targets"], "reward_ratio": info["reward_ratio"]}))
	return "\n".join(lines)


# --- Zone anchors, the hidden-pocket border and the guaranteed-pocket jitter (SQ13) ---
#
# The jitter models the draw the pocket unit (SQ14) makes. The two guaranteed pockets, reward and
# risk, go to the two costliest viable off-route anchors by cost. order_ok checks anchors()
# rank against that cost order. Each door is drawn at random among the anchor's door_ok nodes
# that also keep the pocket rules a node can keep alone: at least DOOR_SPAWN_M from the spawn and DOOR_BEACON_M from the beacon by path.
# A draw whose two doors are less than DOOR_DOOR_M apart by path (the shorter way) is a re-roll;
# a pair gets JITTER_DRAWS draws before the draw falls back to the next pair of anchors, costliest
# first. Per seed: `top2` when the first pair places, `reroll` when its first draw fails.
const JITTER_SEEDS := 1000
const JITTER_TOP2_MIN := 0.95
const REROLL_MAX := 0.20
const JITTER_DRAWS := 8
# comps/isaac/floor-generation.md:107 (c): a hidden pocket borders at least 3 zones.
const HIDDEN_ZONES_MIN := 3


# The door_ok nodes of an anchor a guaranteed pocket may stand on.
static func anchor_doors(graph, zone: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for o in graph.zone_door_nodes(zone):
		if graph.d_from[o] >= DOOR_SPAWN_M and graph.d_land[o] >= DOOR_BEACON_M:
			out.append(o)
	return out


# opts: "anchors" (an anchors() list to draw from), "door_door_m", "draws".
static func jitter(graph, seeds := JITTER_SEEDS, opts := {}) -> Dictionary:
	# The order comes from the cost, never from the order or the rank anchors() hands back: the
	# pair this measures is the viable off-route anchors with doors, costliest first, ties by
	# zone id. A wrong sort or rank in anchors() then shows as order_ok false.
	var given: Array = opts.get("anchors", graph.anchors())
	var ranked := []
	for a in given:
		if not a["on_route"] and a["viable"]:
			var doors := anchor_doors(graph, a["zone"])
			if not doors.is_empty():
				ranked.append({"name": a["name"], "zone": a["zone"], "cost": a["cost"], "doors": doors})
	ranked.sort_custom(func(a, b): return a["cost"] > b["cost"] or (a["cost"] == b["cost"] and a["zone"] < b["zone"]))
	var by_rank := []
	for a in given:
		if a["rank"] > 0:
			by_rank.append(a)
	by_rank.sort_custom(func(a, b): return a["rank"] < b["rank"])
	var rank_names := []
	for a in by_rank:
		rank_names.append(a["name"])
	var cost_names := []
	for a in ranked:
		cost_names.append(a["name"])
	var order_ok: bool = rank_names == cost_names
	var door_door: float = opts.get("door_door_m", DOOR_DOOR_M)
	var draws: int = opts.get("draws", JITTER_DRAWS)
	var pairs := []
	for j in range(1, ranked.size()):
		for i in j:
			pairs.append([i, j])
	var apart := {}
	var rng := RandomNumberGenerator.new()
	var top2 := 0
	var placed := 0
	var rerolled := 0
	for s in range(1, seeds + 1):
		rng.seed = s
		var first_failed := pairs.is_empty()
		var done := false
		for p in pairs:
			for attempt in draws:
				var a: int = ranked[p[0]]["doors"][rng.randi() % ranked[p[0]]["doors"].size()]
				var b: int = ranked[p[1]]["doors"][rng.randi() % ranked[p[1]]["doors"].size()]
				if _doors_apart(graph, a, b, door_door, apart):
					done = true
					break
				if p == pairs[0] and attempt == 0:
					first_failed = true
			if done:
				placed += 1
				if p == pairs[0]:
					top2 += 1
				break
		if first_failed:
			rerolled += 1
	var names := []
	for a in ranked:
		names.append(a["name"])
	return {"seeds": seeds, "anchors": names, "placed": placed, "top2": top2, "top2_share": float(top2) / maxf(1.0, seeds),
		"order_ok": order_ok, "rerolls": rerolled, "reroll_share": float(rerolled) / maxf(1.0, seeds)}


# The --jitter gate: the reasons the zone anchors are out of target, [] when they are in.
static func zone_gate(drawn: Dictionary, border: Array) -> Array:
	var misses := []
	if not drawn["order_ok"]:
		misses.append("the anchor ranks do not run costliest first")
	if drawn["top2_share"] < JITTER_TOP2_MIN:
		misses.append("the top pair holds on %.1f%% of seeds" % (100.0 * drawn["top2_share"]))
	if drawn["reroll_share"] > REROLL_MAX:
		misses.append("the re-roll rate is %.1f%%" % (100.0 * drawn["reroll_share"]))
	if border.is_empty():
		misses.append("the park has no hidden pocket to border")
	for h in border:
		if h["count"] < HIDDEN_ZONES_MIN:
			misses.append("hidden pocket %s borders %d zones" % [h["id"], h["count"]])
	return misses


static func _doors_apart(graph, a: int, b: int, metres: float, cache: Dictionary) -> bool:
	if graph.position(a).distance_to(graph.position(b)) >= metres:
		return true
	var key: int = mini(a, b) * graph.node_count() + maxi(a, b)
	if not cache.has(key):
		cache[key] = minf(graph.path_m(a, b), graph.path_m(b, a))
	return cache[key] >= metres


# W13 coordinator ruling, 2026-10-12: a zone borders a hidden pocket when it holds a graph
# node within one lattice step (ParkGraph.STEP_M) of the sealed footprint: its wall frame
# plus its door and cache or pay points. The wall uses the runtime box's X/Z size and Y turn.
# Measure every hidden pocket reported by pockets(), without a door-radius override.
static func hidden_border(graph, park: Dictionary) -> Array:
	var by_id := {}
	for row in park["contraption_rows"]:
		by_id[String(row["id"])] = row
	var out := []
	var zones: Array = graph.zones()
	for pocket in pockets(graph, park, true)["rows"]:
		if pocket["role"] != "hidden":
			continue
		var hidden: Dictionary = by_id[pocket["id"]]
		var wall: Dictionary = hidden.get("door", hidden)
		var at: Array = wall["at"]
		var centre := Vector2(float(at[0]), float(at[1]))
		var size: Array = wall["size"]
		var half := Vector2(float(size[0]), float(size[2])) * 0.5
		var turn: float = wall["turn"]
		var points := []
		for point in [pocket["at"], pocket["pay_at"]]:
			points.append(Vector2(float(point[0]), float(point[1])))
		var seen := {}
		for o in graph.node_count():
			var p := Vector2(graph.px[o], graph.pz[o])
			# Inverse of the wall's rotation about Y, projected onto the X/Z plane.
			var local := (p - centre).rotated(turn)
			var outside := Vector2(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0))
			var distance := outside.length()
			for point in points:
				distance = minf(distance, p.distance_to(point))
			if distance <= ParkGraph.STEP_M:
				seen[graph.zone_of(o)] = true
		var names := []
		for z in seen:
			names.append(zones[z]["name"])
		names.sort()
		out.append({"id": String(pocket["id"]), "zones": names, "count": names.size()})
	return out


# graph.json's zones block: counts, the anchor list and the hidden pocket's border.
static func zone_summary(graph, park: Dictionary) -> Dictionary:
	var crossings := {"walk": 0, "ride": 0, "drop": 0}
	for c in graph.crossings():
		crossings[c["kind"]] += 1
	var anchors := []
	for a in graph.anchors():
		anchors.append({"name": a["name"], "cost": snappedf(a["cost"], 0.1), "d_landmark": snappedf(a["d_landmark"], 0.1),
			"on_route": a["on_route"], "viable": a["viable"], "rank": a["rank"]})
	return {"count": graph.zone_count(), "crossings": crossings, "anchors": anchors, "hidden": hidden_border(graph, park)}


static func zone_text(zones: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("")
	lines.append("zones: %d, crossings: %d walk, %d ride, %d drop" % [zones["count"], zones["crossings"]["walk"], zones["crossings"]["ride"], zones["crossings"]["drop"]])
	for a in zones["anchors"]:
		lines.append("anchor %s: cost %s m from the spawn, %s m from the beacon, %s, rank %s" % [a["name"], a["cost"], a["d_landmark"],
			"on the route" if a["on_route"] else "off the route" if a["viable"] else "off the route, too few doors", a["rank"] if a["rank"] > 0 else "-"])
	for h in zones["hidden"]:
		lines.append("hidden pocket %s borders %d zones (%s), at least %d wanted: %s" % [h["id"], h["count"], ", ".join(h["zones"]), HIDDEN_ZONES_MIN,
			"in target" if h["count"] >= HIDDEN_ZONES_MIN else "OUT OF TARGET"])
	return "\n".join(lines)


static func jitter_text(result: Dictionary) -> String:
	return "jitter over %d seeds, anchors %s: guaranteed pockets at the two costliest anchors on %.1f%% of seeds (at least %.0f%%: %s), re-roll rate %.1f%% (at most %.0f%%: %s)" % [
		result["seeds"], ", ".join(result["anchors"]), 100.0 * result["top2_share"], 100.0 * JITTER_TOP2_MIN,
		"in target" if result["top2_share"] >= JITTER_TOP2_MIN else "OUT OF TARGET", 100.0 * result["reroll_share"], 100.0 * REROLL_MAX,
		"in target" if result["reroll_share"] <= REROLL_MAX else "OUT OF TARGET"]


# Permissive envelope of every quantized entrance offset, including lattice rounding.
# This deliberately ignores footprint, route, ring and terrain restrictions.
static func draw_detour_bound(graph, from_line: PackedFloat32Array) -> Dictionary:
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var reach := 0.0
	for side in Library.FOOTPRINTS.values():
		reach = maxf(reach, float(side) * 0.5 + ParkGraph.STEP_M * sqrt(2.0) * 0.5)
	var offsets := []
	var cells := ceili(reach / ParkGraph.STEP_M)
	for dx in range(-cells, cells + 1):
		for dz in range(-cells, cells + 1):
			var offset := Vector2(dx, dz) * ParkGraph.STEP_M
			if offset.length() <= reach:
				offsets.append(offset)
	var low := INF
	var high := 0.0
	for n in range(ParkGraph.SIDE * ParkGraph.SIDE):
		if from_line[n] < DETOUR_MIN_M or from_line[n] > DETOUR_MAX_M:
			continue
		var at := Vector2(graph.px[n], graph.pz[n])
		for offset in offsets:
			var dn: int = graph.nearest(at + offset)
			if graph.flags(dn) & (ParkGraph.SIGHT_OK | ParkGraph.DOOR_OK) == (ParkGraph.SIGHT_OK | ParkGraph.DOOR_OK) and graph.d_spawn_node(dn) >= DOOR_SPAWN_M and graph.d_landmark_node(dn) >= DOOR_BEACON_M:
				low = minf(low, from_line[n])
				high = maxf(high, from_line[n])
				break
	return {"min": low, "max": high, "ratio": high / low}


# SQ14 runs on the committed graphs; this arm never rebakes or rewrites them.
static func draw_arm(map_id: String, seeds := 1000, placement_seeds := 200) -> Dictionary:
	var Park = load("res://src/core/park_defs.gd")
	var Map = load("res://src/world/park/park_map.gd")
	var Run = load("res://src/core/run_state.gd")
	var Trade = load("res://src/world/trade_pockets.gd")
	var Draw = load("res://src/world/pockets/pocket_draw.gd")
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var result := {"ok": true, "stage_samples": 0, "placement_samples": 0, "templates": [], "coverage": [], "errors": [], "layout_seed": 78000, "seed_start": 0, "detour_population": "path distance from main line to each drawn pay point; trade excluded"}
	var covered := {}
	if seeds <= 0 or placement_seeds <= 0 or placement_seeds > seeds:
		result.errors.append("require 0 < placement seeds <= stage seeds")
		result.ok = false
		return result
	for stage in range(1, Park.COUNT + 1):
		var id: String = Park.of(stage).map
		if map_id != "all" and map_id != id:
			continue
		var map = Map.new("res://src/world/park/%s.json" % id)
		var graph = ParkGraph.read("res://assets/park/%s/graph.bin" % id)
		if graph == null or not map.ok:
			result.errors.append("graph or map missing: " + id)
			continue
		var prepared: Dictionary = Draw.prepare(graph, map)
		var pool: PackedInt32Array = Trade.candidates(graph, map)
		var index := Index.new(graph, map.park)
		var ring_cache := {}
		var sets := {}
		var detours := []
		var union_blocks := {}
		var row := {"stage": stage, "map": id, "stage_samples": seeds, "placement_samples": placement_seeds, "draw_count": 0, "nonempty_stages": 0, "counts_in_3_to_8": 0, "distinct_sets": 0, "detour_p10": 0.0, "detour_p90": 0.0, "detour_ratio": 0.0, "failed_placements": 0, "credit_lost": 0, "chance_opportunities": 0, "chance_hits": 0, "chance_rate": 0.0, "placement_draws": 0, "rule_samples": seeds, "rule_breaches": 0, "route_cuts": 0, "door_ring_breaches": 0, "placement_example": {}, "samples": []}
		var envelope := draw_detour_bound(graph, prepared.from_line)
		row.detour_bound = envelope.ratio
		row.detour_bound_min = envelope.min
		row.detour_bound_max = envelope.max
		# World 1's level-ground rule (pocket_draw.gd TIDY) leaves fewer pay points than the permissive probe
		# sees (the dam's reach 283 m of its 503 m), so there the floor reads the anchors the draw may use.
		row.anchor_bound = row.detour_bound
		if id in Draw.TIDY and not prepared.anchors.is_empty():
			row.anchor_bound = minf(row.detour_bound, prepared.from_line[prepared.anchors.back().node] / prepared.from_line[prepared.anchors.front().node])
		row.detour_floor = minf(2.0, 0.9 * row.anchor_bound)
		if id not in Draw.TIDY and not is_equal_approx(row.detour_floor, minf(2.0, 0.9 * envelope.max / envelope.min)):
			result.errors.append("floor derivation requirement: " + id)
		for seed_value in seeds:
			var run = Run.new()
			run.run_seed = seed_value
			run.stage = stage
			var trade: Dictionary = Trade.stage_site(graph, map, run, 78000, pool)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([78000, seed_value, stage, "pocket_draw"])
			var drawn: Dictionary = Draw.draw(prepared, map, stage, rng, trade)
			var specs: Array = drawn.sites
			var interior_ids := []
			var nodes := []
			for spec in specs:
				interior_ids.append(spec.interior.id)
				nodes.append(spec.node)
				covered[spec.interior.id] = true
				detours.append(float(prepared.from_line[spec.node]))
			interior_ids.sort()
			sets[JSON.stringify(interior_ids)] = true
			row.draw_count += specs.size()
			row.nonempty_stages += int(not specs.is_empty())
			var count: int = map.activity_sites.size() + specs.size()
			row.counts_in_3_to_8 += int(count >= 3 and count <= 8)
			row.samples.append({"seed": seed_value, "interiors": interior_ids, "nodes": nodes, "non_trade_count": count})
			var breaches := drawn_rules(graph, map, specs, trade, prepared.from_line, index, ring_cache)
			row.rule_breaches += breaches.size()
			for b in breaches:
				row.door_ring_breaches += int(b.rule == "door_ring")
				if result.errors.size() < 20:
					result.errors.append({"map": id, "seed": seed_value, "breach": b})
			if seed_value < placement_seeds:
				row.placement_draws += specs.size()
				row.failed_placements += int(drawn.metrics.failed_placements)
				row.chance_opportunities += int(drawn.metrics.chance_opportunities)
				row.chance_hits += int(drawn.metrics.chance_hits)
				var spent := 0
				for spec in specs:
					var side: float = Library.FOOTPRINTS[spec.interior.footprint]
					spent += ceili(side * side / Library.FOOTPRINTS.small)
					var half := Vector2.ONE * side * 0.5
					for n in graph.box_nodes(spec.at - half - Vector2.ONE * ParkGraph.STEP_M, spec.at + half + Vector2.ONE * ParkGraph.STEP_M):
						union_blocks[n] = true
				row.credit_lost += absi(150 - spent - int(drawn.metrics.remaining_credits))
				row.samples.back()["placement"] = drawn.metrics.duplicate()
			row.samples.back()["rule_breaches"] = breaches
			if seed_value == 0:
				var examples := []
				for spec in specs:
					examples.append({"interior": spec.interior.id, "node": spec.node, "at": [spec.at.x, spec.at.y], "detour_m": prepared.from_line[spec.node], "footprint": spec.interior.footprint})
				row.placement_example = {"seed": 0, "sites": examples, "trade_node": trade.get("node", -1)}
		row.distinct_sets = sets.size()
		detours.sort()
		if not detours.is_empty():
			row.detour_p10 = detours[floori((detours.size() - 1) * 0.1)]
			row.detour_p90 = detours[floori((detours.size() - 1) * 0.9)]
			row.detour_ratio = row.detour_p90 / row.detour_p10
		if row.chance_opportunities > 0:
			row.chance_rate = float(row.chance_hits) / row.chance_opportunities
		# The union of all 200 placement samples is a stronger route check than each separately.
		var cut = ParkGraph.from_bytes(graph.to_bytes())
		cut.off = PackedInt32Array([0])
		cut.to.clear()
		cut.length.clear()
		cut.ride.clear()
		for n in graph.node_count():
			if not union_blocks.has(n):
				for e in range(graph.off[n], graph.off[n + 1]):
					if not union_blocks.has(graph.to[e]):
						cut.to.append(graph.to[e])
						cut.length.append(graph.length[e])
						cut.ride.append(graph.ride[e])
			cut.off.append(cut.to.size())
		row.route_cuts = route_breaks(cut, map.park).size()
		# Every stage draws since ruling bu (2026-11-09); D8's stage 1 exemption is retired.
		if row.distinct_sets < 8 or row.counts_in_3_to_8 < seeds * 0.95 or row.detour_ratio < row.detour_floor:
			result.errors.append("variety/count/detour requirement: " + id)
		if row.chance_opportunities == 0 or absf(row.chance_rate - 0.25) > 0.03:
			result.errors.append("chance rate requirement: " + id)
		if row.credit_lost != 0 or row.rule_breaches != 0 or row.route_cuts != 0:
			result.errors.append("credit/rules/routes requirement: " + id)
		result.stage_samples += seeds
		result.placement_samples += placement_seeds
		result.templates.append(row)
		var compact := row.duplicate()
		compact.erase("samples")
		print("pocket_draw_template: " + JSON.stringify(compact))
	result.coverage = covered.keys()
	result.coverage.sort()
	if map_id == "all":
		for entry in Library.rows():
			if entry.kind != "trade" and not covered.has(entry.id):
				result.errors.append("interior never drawn: " + entry.id)
	if result.templates.is_empty():
		result.errors.append("no park template selected")
	result.ok = result.errors.is_empty()
	return result


# The generated-set rules use the same owners as park_pockets_test, without calling the draw.
static func drawn_rules(graph, map, specs: Array, trade: Dictionary, from_line: PackedFloat32Array, index, ring_cache: Dictionary) -> Array:
	var Library = load("res://src/world/pockets/pocket_library.gd")
	var Trade = load("res://src/world/trade_pockets.gd")
	var out := []
	var seen := {}
	var existing: Array = Trade.doors(map)
	if not trade.is_empty():
		existing.append({"at": trade.at})
	var far := -1.0
	for spec in specs:
		far = maxf(far, from_line[spec.node])
	for spec in specs:
		var entry: Dictionary = spec.interior
		if seen.has(entry.id):
			out.append(_breach(entry.id, "distinctness", "repeated interior"))
		seen[entry.id] = true
		for authored in map.activity_sites:
			if Library.for_site(map.park.map, authored.row).get("id", "") == entry.id:
				out.append(_breach(entry.id, "assignment", "stage assigned interior drawn"))
		var half: float = Library.FOOTPRINTS[entry.footprint] * 0.5
		var door: Vector2 = spec.at + Vector2(entry.entrances[0].at[0], entry.entrances[0].at[1]).rotated(spec.get("turn", 0) * PI * 0.5)
		var dn: int = graph.nearest(door)
		var flags: int = graph.flags(dn)
		if flags & (ParkGraph.OPEN | ParkGraph.DOOR_OK | ParkGraph.SIGHT_OK) != (ParkGraph.OPEN | ParkGraph.DOOR_OK | ParkGraph.SIGHT_OK) or flags & (ParkGraph.LINE | ParkGraph.GUARDED | ParkGraph.WARDEN) != 0:
			out.append(_breach(entry.id, "door", "door flags"))
		if graph.d_spawn_node(dn) < DOOR_SPAWN_M or graph.d_landmark_node(dn) < DOOR_BEACON_M:
			out.append(_breach(entry.id, "distance", "spawn or beacon minimum"))
		if from_line[spec.node] < DETOUR_MIN_M or from_line[spec.node] > DETOUR_MAX_M:
			out.append(_breach(entry.id, "detour", "pay point outside band"))
		if not ring_cache.has(dn):
			ring_cache[dn] = _ring(graph, map.park, index, dn)
		if not ring_cache[dn].is_empty():
			out.append(_breach(entry.id, "clear_ring", str(ring_cache[dn])))
		var box := Rect2(spec.at - Vector2.ONE * half, Vector2.ONE * half * 2.0)
		for d in existing:
			var closest := Vector2(clampf(d.at.x, box.position.x, box.end.x), clampf(d.at.y, box.position.y, box.end.y))
			if closest.distance_to(d.at) <= RING_M:
				out.append(_breach(entry.id, "door_ring", "drawn footprint inside existing ring"))
			if door.distance_to(d.at) < DOOR_DOOR_M:
				out.append(_breach(entry.id, "door_to_door", "existing door too close"))
		for other in specs:
			if other != spec:
				var od: Vector2 = other.at + Vector2(other.interior.entrances[0].at[0], other.interior.entrances[0].at[1]).rotated(other.get("turn", 0) * PI * 0.5)
				if door.distance_to(od) < DOOR_DOOR_M:
					out.append(_breach(entry.id, "door_to_door", "drawn doors too close"))
		for n in graph.box_nodes(box.position, box.end):
			if graph.flags(n) & ParkGraph.LINE != 0:
				out.append(_breach(entry.id, "route", "footprint cuts line"))
				break
		var pay: Dictionary = _pay(spec.pay)
		var allowed: Array = PAY_FAR if from_line[spec.node] == far else PAY_NEAR
		if not _within(pay.rarities, allowed):
			out.append(_breach(entry.id, "pay", "pay ladder"))
	return out
