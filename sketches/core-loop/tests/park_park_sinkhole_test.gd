extends SceneTree

# Stage 4, park_sinkhole (design-v3/park/stages/4-park_sinkhole.md, K-UNITS KD4). Pinned
# 2026-10-12, merged greybox continuation. The committed bake and graph are fresh for the park file; the
# waymarks run drop_in, tube_mouth, great_room, landmark; the graph's pocket table names one
# pocket per role with the ids this stage ships and no breach; the landmark carries the swarm
# brood on the sinkhole mounting; every pilot line and the floor line start at drop_in, pass the
# waymarks in order, end at landmark and name only places the park file has; and the two
# ride-fact sources the runtime fires on this head (kicker rows and the lava channel's rope fan)
# are in the file. Fix round 2026-10-11: every row but the ground, the kickers and the stage page's
# site markers carries a recipe (R10), so it places at runtime. pins() is run on planted copies
# too, and each plant must turn it red.

const T := preload("res://tests/support/t.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const GraphLoader := preload("res://src/world/park/park_graph.gd")

const MAP := "park_sinkhole"
const PARK := "res://src/world/park/park_sinkhole.json"
const BAKED := "res://assets/park/park_sinkhole"
const LINES := "res://assets/park/park_sinkhole/lines.json"
const WAYMARKS := ["drop_in", "tube_mouth", "great_room", "landmark"]
const POCKETS := {"online": "great_room_camp", "risk": "east_chamber_bounty", "reward": "west_chamber_cache", "hidden": "sealed_crosscut"}
const PILOTS := ["sable", "rivet", "kest", "tarn", "tally", "cannon"]
const RECIPE_LEFT := ["great_room", "east_chamber", "west_chamber", "crosscut_drift", "west_cenote", "sinkhole_walls", "caisson_bowl"]

var t := T.new("park_park_sinkhole_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stale: Array = ParkBake.freshness(PARK, BAKED)
	t.check("the committed bake is fresh", stale.is_empty(), str(stale))
	var graph_stale: Array = ParkGraphTool.freshness(PARK, BAKED, BAKED)
	t.check("the committed graph is fresh", graph_stale.is_empty(), str(graph_stale))
	var read := ParkSchema.load_park(PARK)
	if not t.check("the park file loads with zero errors", read["errors"].is_empty(), str(read["errors"])):
		quit(t.verdict())
		return
	var park: Dictionary = read["data"]
	var graph = JSON.parse_string(FileAccess.get_file_as_string(BAKED + "/graph.json"))
	var lines = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	if not t.check("graph.json and the lines file parse", graph is Dictionary and lines is Dictionary):
		quit(t.verdict())
		return
	var seating := floor_seating(park)
	t.check("great-room floor seats beneath terrain at entry and exit", seating.is_empty(), "\n".join(seating))
	var errors := pins(park, graph, lines)
	t.check("every stage pin holds", errors.is_empty(), "\n".join(errors))

	# Plants: each must break a pin.
	var p1: Dictionary = park.duplicate(true)
	p1["waymarks"] = ["drop_in", "great_room", "tube_mouth", "landmark"]
	t.check("plant: swapped waymarks fail", not pins(p1, graph, lines).is_empty())
	var g1: Dictionary = graph.duplicate(true)
	g1["pockets"][1]["role"] = "reward"
	t.check("plant: a second reward pocket fails", not pins(park, g1, lines).is_empty())
	var p2: Dictionary = park.duplicate(true)
	p2["landmark"]["warden"]["mounting"] = "headframe"
	t.check("plant: another mounting fails", not pins(p2, graph, lines).is_empty())
	var p4: Dictionary = park.duplicate(true)
	p4["landmark"]["warden"]["anchor"] = [0.0, -99.0, 380.0]
	t.check("plant: a moved Warden anchor fails", not pins(p4, graph, lines).is_empty())
	var l1: Dictionary = lines.duplicate(true)
	l1["pilots"]["tarn"]["waypoints"].insert(3, "no_such_row")
	t.check("plant: an unknown waypoint fails", not pins(park, graph, l1).is_empty())
	var p3: Dictionary = park.duplicate(true)
	p3["contraption_rows"] = p3["contraption_rows"].filter(func(c): return c["kind"] != "cable" or not String(c["site"]).begins_with("lava_channel"))
	t.check("plant: no rope fan fails", not pins(p3, graph, lines).is_empty())
	var p5: Dictionary = park.duplicate(true)
	for r in p5["park_rows"]:
		if r["element"] == "anchor_field":
			r["recipe"] = ""
			break
	t.check("plant: an anchor field with no recipe fails", not pins(p5, graph, lines).is_empty())
	var g2: Dictionary = graph.duplicate(true)
	g2["beacon_ok"] = false
	t.check("plant: an unqualified beacon fails", not pins(park, g2, lines).is_empty())
	var g3: Dictionary = graph.duplicate(true)
	g3["spawn"]["run"] = false
	t.check("plant: an unqualified spawn run fails", not pins(park, g3, lines).is_empty())
	var raised_floor: Dictionary = park.duplicate(true)
	for row in raised_floor["park_rows"]:
		if row["id"] == "great_room_floor":
			row["y"] = float(row["y"]) + 3.0
	t.check("plant: a floor raised 3 m fails seating", not floor_seating(raised_floor).is_empty())

	# The beacon disc over the brood's pool: the pool takes the swarm's slab, so its rising floor
	# is judged as the pool and the lip outside it must be flat. With the nest 30 m lower, the pit
	# no longer reaches the first floor, the slab is not built, and the plain flat-disc rule fails.
	var built = GraphLoader.read(BAKED + "/graph.bin")
	if t.check("graph.bin loads", built != null):
		var beacon: Dictionary = ParkGraphTool.beacon_check(built, park)
		t.check("the beacon disc judges the brood's pool", beacon["ok"] and not (beacon["pool"] as Dictionary).is_empty(), str(beacon))
		var deep: Dictionary = park.duplicate(true)
		deep["landmark"]["warden"]["anchor"] = [0.0, -129.0, 388.0]
		var plain: Dictionary = ParkGraphTool.beacon_check(built, deep)
		t.check("plant: a pool the pit cannot take falls back to the flat disc and fails", not plain["ok"] and (plain["pool"] as Dictionary).is_empty(), str(plain))
	quit(t.verdict())


# JSON numbers parse as floats, so a pinned point compares as a vector, not an Array of ints.
static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() == 2 else Vector2.INF


static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2])) if a is Array and a.size() == 3 else Vector3.INF


# The stage's facts, as error lines; [] when every pin holds.
static func pins(park: Dictionary, graph: Dictionary, lines: Dictionary) -> Array:
	var out := floor_seating(park)
	if park.get("map") != MAP:
		out.append("map is %s" % park.get("map"))
	if park["waymarks"] != WAYMARKS:
		out.append("waymarks %s, want %s" % [park["waymarks"], WAYMARKS])
	var mark: Dictionary = park["landmark"]
	if mark["kind"] != "sinkhole" or _v2(mark["at"]) != Vector2(0, 350) or _v2(mark["beacon"]) != Vector2(0, 350):
		out.append("landmark %s at %s, beacon %s" % [mark["kind"], mark["at"], mark["beacon"]])
	var w: Dictionary = mark["warden"]
	if w.get("family") != "swarm" or w.get("mounting") != "sinkhole" or w.get("harpoon_anchor") != true or _v3(w.get("anchor", [])) != Vector3(0, -99, 388):
		out.append("warden %s" % str(w))
	var roles := {}
	for p in graph.get("pockets", []):
		if POCKETS.has(p["role"]):
			if roles.has(p["role"]):
				out.append("two %s pockets" % p["role"])
			roles[p["role"]] = p["id"]
	if roles != POCKETS:
		out.append("pocket roles %s, want %s" % [roles, POCKETS])
	if not (graph.get("breaches", []) as Array).is_empty():
		out.append("graph breaches %s" % str(graph["breaches"]))
	if not graph.get("spawn", {}).get("ok", false):
		out.append("the spawn is not in the farthest quarter")
	if not graph.get("beacon_ok", false):
		out.append("the beacon is not qualified")
	if not graph.get("spawn", {}).get("run", false):
		out.append("the spawn run is not qualified")
	for route in graph.get("routes", {}):
		if not (graph["routes"][route] as Array).is_empty():
			out.append("route %s does not connect" % route)
	# Places a waypoint may name.
	var places := {"drop_in": true, "landmark": true}
	for r in park["park_rows"]:
		places[r["id"]] = true
	for a in park["activity_rows"]:
		places[a["id"]] = true
	var all := {}
	for k in PILOTS:
		if not lines.get("pilots", {}).has(k):
			out.append("no %s line" % k)
			continue
		all[k] = lines["pilots"][k]["waypoints"]
	all["floor"] = lines.get("floor", {}).get("waypoints", [])
	for k in all:
		var wps: Array = all[k]
		if wps.is_empty() or wps[0] != "drop_in" or wps[-1] != "landmark":
			out.append("%s line does not run drop_in to landmark" % k)
		var named := []
		for wp in wps:
			if wp is String:
				if not places.has(wp):
					out.append("%s line names %s, not a place in the park file" % [k, wp])
				named.append(wp)
		if named.filter(func(n): return n in WAYMARKS) != WAYMARKS:
			out.append("%s line waymarks %s" % [k, named])
	# The ride facts this head fires: a kicker row's lip, and the rope fan across the lava channel.
	var kickers: Array = park["park_rows"].filter(func(r): return r["element"] == "kicker")
	if kickers.size() < 2:
		out.append("%d kicker rows, want 2" % kickers.size())
	var fan: Array = park["contraption_rows"].filter(func(c): return c["kind"] == "cable" and String(c["site"]).begins_with("lava_channel"))
	if fan.size() < 4:
		out.append("%d rope-fan cables on the lava channel, want 4" % fan.size())
	# R10: every row but the ground carries a recipe, so it places at runtime; the rows left on "" are the
	# stage page's list (site markers with no stamp and no height, and kickers whose _ramp row's stamp is the lip).
	for r in park["park_rows"]:
		if r["element"] == "ground" or r["id"] in RECIPE_LEFT or r["element"] == "kicker":
			continue
		if String(r["recipe"]) == "":
			out.append("row %s (%s) has no recipe" % [r["id"], r["element"]])
	return out


static func floor_seating(park: Dictionary) -> Array:
	var rows: Array = park["park_rows"].filter(func(row): return row["id"] == "great_room_floor")
	if rows.size() != 1:
		return ["great_room_floor must name exactly one supporting floor row"]
	var raw := FileAccess.open_compressed(BAKED + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if raw == null:
		return ["floor seating cannot read the committed terrain"]
	var heights := raw.get_buffer(801 * 801 * 4).to_float32_array()
	raw.close()
	if heights.size() != 801 * 801:
		return ["floor seating needs the complete 2 m terrain grid"]
	var holes := FileAccess.get_file_as_bytes(BAKED + "/holes.bin")
	if holes.size() != 800 * 800:
		return ["floor seating needs the terrain hole mask"]
	var row: Dictionary = rows[0]
	var ground := func(x: float, z: float) -> float: return _baked_surface(heights, Vector2(x, z))
	var frame := ParkRecipes.row_transform(row, ground)
	var size: Array = row["size"]
	var errors := []
	for end in [-1.0, 1.0]:
		var top: Vector3 = frame * Vector3(0.0, float(size[1]), end * float(size[0]) * 0.5)
		var at := Vector2(top.x, top.z)
		var cell := Vector2i(floori((at.x + 800.0) / 2.0), floori((at.y + 800.0) / 2.0))
		if cell.x < 0 or cell.x >= 800 or cell.y < 0 or cell.y >= 800:
			errors.append("floor join %s lies outside the terrain" % at)
			continue
		var terrain_y := _baked_surface(heights, at)
		if holes[cell.y * 800 + cell.x] != 0 or top.y > terrain_y + 0.00001:
			errors.append("great_room_floor %s top %.5f exceeds supporting terrain %.5f at %s" % ["entry" if end < 0.0 else "exit", top.y, terrain_y, at])
	return errors


# Barycentric heights from the committed grid's triangles, independent of the runtime sampler.
static func _baked_surface(heights: PackedFloat32Array, at: Vector2) -> float:
	var grid := (at + Vector2(800.0, 800.0)) / 2.0
	var cell := Vector2i(floori(grid.x), floori(grid.y))
	var uv := grid - Vector2(cell)
	var origin := cell.y * 801 + cell.x
	var corners := [heights[origin], heights[origin + 1], heights[origin + 801], heights[origin + 802]]
	if uv.x + uv.y <= 1.0:
		return corners[0] * (1.0 - uv.x - uv.y) + corners[1] * uv.x + corners[2] * uv.y
	return corners[1] * (1.0 - uv.y) + corners[2] * (1.0 - uv.x) + corners[3] * (uv.x + uv.y - 1.0)
