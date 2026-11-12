extends "res://src/world/stage_map.gd"

# A stage map read from a park file (design-v3/PARK.md 2.1 and 2.9). It loads the JSON once,
# validates it with park_schema.gd, and fills the fields today's systems already read, so the
# bay, flow, director, reward gates, activities and contraptions keep their interfaces. A park
# that fails the schema fills nothing: errors holds the schema's rows and ok stays false.
# Heights stay the base plain's until the bake (tools/park_bake.gd) lands.

const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const BreatherRows := preload("res://src/world/breather_rows.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")

# The line half-width the graph bakes (tools/park_graph.gd LINE_M), the reach of the lane mask.
const LANE_REACH_M := 8.0
# A footprint is linear, a lane rather than an area, when its long side is at least this many times its short side.
const LANE_LINEAR_ASPECT := 2.0
const FIXTURE := "res://src/world/park/park_test.json"
const LINES_PATH := "res://assets/park/%s/lines.json"
# A scrap trail's gap reaches this far past a built kicker's footprint.
const TRAIL_GAP_MARGIN_M := 1.0
# Andrew's "Ride lips only" ruling (2026-10-17 06:16Z): a plain bank, drop, ground shelf or sky island whose height
# stamp is its whole shape is terrain, not a placeholder, so scatter lands on it as on the open ground. The same rows
# as scripts/placeholder-gate.mjs PLAIN_SLOPES and isPlainSlope.
const PLAIN_SLOPES := ["bank", "drop", "ground", "sky_island"]
# Andrew's "Edges are ground" (2026-10-17 22:29Z): a stamped kicker that spans the whole play rect across its facing
# (the Highdraft's mesa step lips, 18 rows and 28.8 km on park_islands) is a mesa edge, ground like a plain slope.
# Extended to every element by World NEEDS #149 6325353865, coordinator ruling (a) 2026-10-21, Andrew's veto list: a
# stamped greybox row of any element whose cross size spans the rect (a 1,600 m ride band) is ground too, because no
# over-greybox piece can honestly dress it. Same as scripts/placeholder-gate.mjs isMesaEdge.

var path := ""
var ok := false
var errors: Array = []
# The parsed park file, kept for the readers that come later (bake, event director, sight test).
var park := {}
# The landmark's light, the one point every layer finds (terrain.gd landmark_point): sight_top.
var landmark := Vector3.INF
# Contraption specs for contraptions.gd: the park rows with arrays turned into vectors.
var contraptions: Array = []
# Where Moss's bay docks after the break: {"at": Vector2, "facing": Vector3}.
var bay_dock := {}
# The engage ring's radius (alpha_defs beacon_radius today).
var reach_m := 0.0
var time_of_day := ""
# The stage's caged pilots for rescue_site.gd, from the park file's optional rescue_rows: {id, quest, prompt, pilot,
# at: Vector2, face: Vector2}.
var rescue_sites: Array = []


# An empty path reads nothing (ok stays false): event_ground.gd's OverlayMap copies a loaded map's
# fields instead, where reading the park file again took 36 ms of an event's telegraph frame.
func _init(park_path := FIXTURE) -> void:
	path = park_path
	if park_path == "":
		return
	var read := ParkSchema.load_park(path)
	errors = read["errors"]
	if not errors.is_empty():
		push_warning("park_map: %s fails the park schema: %s" % [path, ParkSchema.describe(errors)])
		return
	park = read["data"]
	_fill()
	ok = true


# The stage's breathers (breather_rows.gd, map audit unit 7): [{"id", "at": Vector2, "radius_m"}], [] for none.
func breathers() -> Array:
	return BreatherRows.rows(title).duplicate(true) if ok else []


func warden_spec() -> Dictionary:
	return park["landmark"]["warden"].duplicate(true) if ok else {}


# Where this stage's fights happen, as the game places them, for the map checks (map points 2 and 3). Each site is
# {"id", "kind", "at": Vector2} plus its extent: a "home" (a crew's site row, director.gd _read_homes) and an "event"
# (its site row, resolved by NaturalFootprint, half sizes from effect.footprint_m when set, event_director.gd _park_clear; a
# lightning row is its strike disc, a "ring" of 0 to strike_m at the site's centre) carry the row's footprint as "half": Vector2 and "yaw_deg", as footprint_contains
# reads it; the "warden" (the engage ring) and the "yard" lock (lock_rows.gd) carry "ring": Vector2(inner, outer), the
# band of distance from `at` they cover. The yard lock shuts wherever the ball first crosses within_m of the beacon on
# the ground, centred ahead_m inside it, so its ring is every place that circle can stand for a ball that crosses
# the line rolling (one landing from the air inside it shuts the yard nearer in). An "activity" that fights (a camp, an
# ambush altar, a relay) carries its rule's ring at the row's spot. Dormant homes count: an
# event wakes them. Director timer packs are not sites; they spawn ahead of the ball anywhere off the pilot lines.
# An event that commits no hazard and sends no foe is not a fight: the sluice surge is the surge run's water front,
# which only pushes the ball on and never hurts (events/industrial.gd handle, activities.gd surge_run).
const NOT_FIGHTS := ["sluice_surge"]


func fight_sites() -> Array:
	if not ok:
		return []
	var rows := {}
	for row in park["park_rows"]:
		rows[row["id"]] = row
	var out := []
	for table in [["home_rows", "home"], ["event_rows", "event"]]:
		for row in park[table[0]]:
			var site: Dictionary = rows.get(row["site"], {})
			if site.is_empty():
				continue
			if table[1] == "event":
				if row.get("kind", "") in NOT_FIGHTS:
					continue
				# A lightning row strikes one strike_m disc at its site's centre (natural.gd plan and _hazard): the disc
				# is its fight, not the landform it sits on.
				if row.get("kind", "") == "lightning":
					out.append({"id": row["id"], "kind": "event", "at": _v2(site["at"]), "ring": Vector2(0.0, float(row.get("effect", {}).get("strike_m", 0.0)))})
					continue
				site = NaturalFootprint.resolve(row, site)
			var half := footprint_half_extents(site)
			var own = row.get("effect", {}).get("footprint_m")
			if own is Array:
				half = _v2(own).abs() * 0.5
			out.append({"id": row["id"], "kind": table[1], "at": _v2(site["at"]), "half": half, "yaw_deg": float(site["yaw_deg"])})
	# An activity that fights (its rule has a pack: a camp, an ambush altar, a relay) is a ring of its rule's radius at
	# the row's own spot. Loaded here, not preloaded: only the map checks ask, and activities.gd pulls in half the game.
	var rules: Dictionary = load("res://src/world/activities.gd").RULES
	for row in park.get("activity_rows", []):
		var rule: Dictionary = rules.get(String(row.get("activity", "")), {})
		if rule.has("pack") and row.has("at"):
			out.append({"id": row["id"], "kind": "activity", "at": _v2(row["at"]), "ring": Vector2(0.0, float(rule.get("ring", 0.0)))})
	out.append({"id": "warden", "kind": "warden", "at": beacon, "ring": Vector2(0.0, reach_m)})
	var lock: Dictionary = LockRows.row(title).get("lock", {})
	if not lock.is_empty():
		var radius := float(lock.get("radius_m", 26.0))
		var centre := float(lock.get("within_m", 0.0)) - minf(float(lock.get("ahead_m", 0.0)), radius * 0.5)
		out.append({"id": String(lock["id"]), "kind": "yard", "at": beacon, "ring": Vector2(maxf(0.0, centre - radius), centre + radius)})
	return out


# How this stage is left and entered, each row in the stage's own frame, plus where that frame sits in the world 1 atlas:
# {"stage", "atlas": {origin: Vector2, heading_deg}, "exit": {kind, at: Vector2, heading_deg, speed_cruise, opens},
# "arrives": {kind, at: Vector2, heading_deg, speed_cruise, from}}. The exit is the middle gate slot and the arrival is
# the spawn, so each place and heading is stated once in the file. Empty when the file declares no hand-over.
func handover() -> Dictionary:
	if not ok or not park.has("exit") or not park.has("arrives") or not park.has("atlas"):
		return {}
	var slots: Array = park["landmark"]["gate_slots"]
	var gate: Dictionary = slots[slots.size() / 2]
	var spawn: Dictionary = park["spawn"]
	var out: Dictionary = park["exit"].duplicate()
	out["at"] = _v2(gate["at"])
	out["heading_deg"] = float(gate["facing_deg"])
	var into: Dictionary = park["arrives"].duplicate()
	into["at"] = _v2(spawn["at"])
	into["heading_deg"] = float(spawn["heading_deg"])
	var atlas: Dictionary = park["atlas"]
	return {"stage": park["map"], "atlas": {"origin": _v2(atlas["origin"]), "heading_deg": float(atlas["heading_deg"])}, "exit": out, "arrives": into}


func _fill() -> void:
	title = String(park["map"])
	time_of_day = String(park["time_of_day"])
	spawn = _v2(park["spawn"]["at"])
	heading = facing(float(park["spawn"]["heading_deg"]))
	var r: Array = park["play_rect"]
	play_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

	var mark: Dictionary = park["landmark"]
	beacon = _v2(mark["beacon"])
	reach_m = float(mark["reach_m"])
	landmark = _v3(mark["sight_top"])
	bay_dock = {"at": _v2(mark["bay_dock"]["at"]), "facing": facing(float(mark["bay_dock"]["facing_deg"]))}
	gate_slots = []
	for slot in mark["gate_slots"]:
		gate_slots.append({"at": _v2(slot["at"]), "facing": facing(float(slot["facing_deg"]))})

	kickers = []
	for row in park["park_rows"]:
		if row["element"] != "kicker":
			continue
		kickers.append(kicker_lip(row))

	contraptions = []
	for row in park["contraption_rows"]:
		contraptions.append(vectors(row))

	activity_sites = []
	for row in park["activity_rows"]:
		# activities.gd keys its rule by the activity kind; an empty pack or pay keeps the rule's own.
		var site := {"id": row["activity"], "row": row["id"], "site": row["site"], "at": _v2(row["at"])}
		if not (row["pack"] as Array).is_empty():
			site["pack"] = row["pack"].duplicate()
		if not (row["pay"] as Dictionary).is_empty():
			site["pay"] = row["pay"].duplicate(true)
		if row.has("route"):
			site["route"] = String(row["route"])
		# Optional: the way a cracked_cache's open face looks; without it, the rule's (north).
		if row.has("face"):
			site["face"] = _v2(row["face"]).normalized()
		# Optional: a cracked_cache's wall bar as a speed tier (activities.gd BARS).
		if row.has("bar"):
			site["bar"] = String(row["bar"])
		# Optional: a card 2 extra (the completionist card's added activities) stands beside the pocket draw.
		if row.get("extra", "") == "card_2":
			site["extra"] = "card_2"
		activity_sites.append(site)

	rescue_sites = []
	for row in park.get("rescue_rows", []):
		rescue_sites.append({"id": row["id"], "quest": row["quest"], "prompt": row["prompt"], "pilot": row["pilot"],
			"at": _v2(row["at"]), "face": _v2(row["face"]).normalized()})

	scrap_trail = _scrap_trail()

	# Scatter keeps out of every built footprint (PARK.md 2.9) but the ground, the plain slopes, the mesa
	# edges and a row the scatter itself dresses; the kit rows come with KB5.
	scatter = scatter.duplicate(true)
	var keep_out := []
	for row in park["park_rows"]:
		if open_to_scatter(row, play_rect) != "":
			continue
		keep_out.append(_footprint(row))
	keep_out.append(_footprint(mark))
	scatter["keep_out"] = keep_out
	# Coordinator ruling 5, 2026-10-19 (issue #149) and the #241 ruling, option (c): the kit pieces taller than the
	# ghost-solid band (#183) are sunk to the band along the park's line (scatter.gd, LANE_BAND_M), not across whole
	# row footprints. Nothing is read or built here: scatter.gd's chunked build makes the mask on a worker, in the first
	# of its chunk jobs (lane_mask_for), so a ParkMap stays cheap to make and the boot path never touches the graph.


# The stage's scrap trail (stage_map.gd scrap_trail): the floor line of the park's lines.json, where that line carries
# a scrap row ({"spacing_m", "phrase", "rest"}, the beat lay-out scrap_field.gd lay_trail reads), from the drop-in to
# the engage ring, where the Warden's ground starts. Its gaps are the stretches of the line a built kicker stands on,
# [from, to] in metres along the line: a plate ramp is built over the ground a piece would stand on (the flume's
# mesa_entry_kicker buried one 0.9 m deep). A kicker stamped into the ground (the dam's) is ground, and keeps its pieces.
# {} for a park whose floor line has no scrap row.
func _scrap_trail() -> Dictionary:
	var lines_path := LINES_PATH % title
	if not FileAccess.file_exists(lines_path):
		return {}
	var line: Dictionary = ParkSchema.read_file(lines_path)["data"].get("floor", {})
	var row = line.get("scrap")
	if not row is Dictionary:
		return {}
	var points := PackedVector2Array()
	for point in line.get("waypoints", []):
		var at := place_of(park, point) if point is String else _v2(point)
		if at == Vector2.INF:
			push_warning("park_map: %s floor waypoint %s resolves to no place, so no scrap trail" % [lines_path, point])
			return {}
		if at.distance_to(beacon) <= reach_m and not points.is_empty():
			var t := Geometry2D.segment_intersects_circle(points[-1], at, beacon, reach_m)
			if t > 0.0:
				points.append(points[-1].lerp(at, t))
			break
		points.append(at)
	var ramps: Array = park["park_rows"].filter(func(r: Dictionary) -> bool:
		return r["element"] == "kicker" and String(r.get("stamp", "")) == "")
	var gaps := []
	var along := 0.0
	var inside := false
	for i in range(1, points.size()):
		var leg := points[i] - points[i - 1]
		var steps := maxi(1, ceili(leg.length()))
		for s in steps + 1:
			var p := points[i - 1] + leg * (float(s) / steps)
			var on_ramp := ramps.any(func(r: Dictionary) -> bool: return footprint_contains(r, p, TRAIL_GAP_MARGIN_M))
			var at := along + leg.length() * s / steps
			if on_ramp and not inside:
				gaps.append([at, at])
			elif on_ramp:
				gaps[-1][1] = at
			inside = on_ramp
		along += leg.length()
	return {"points": points, "spacing_m": float(row["spacing_m"]), "phrase": int(row["phrase"]), "rest": int(row["rest"]),
		"gaps": gaps}


# Where a line's named waypoint stands on a park file: drop_in is the spawn, landmark the landmark's beacon, any other
# id a park row's or an activity's at. INF when the park has no such place.
static func place_of(park_data: Dictionary, id: String) -> Vector2:
	if id == ParkSchema.DROP_IN:
		return _v2(park_data["spawn"]["at"])
	if id == ParkSchema.LANDMARK:
		return _v2(park_data["landmark"]["beacon"])
	for table in ["park_rows", "activity_rows"]:
		for row: Dictionary in park_data.get(table, []):
			if row.get("id") == id:
				return _v2(row["at"])
	return Vector2.INF


# The res:// path of a park file's baked graph.
static func graph_path_for(park_json: String) -> String:
	return "res://assets/park/%s/graph.bin" % park_json.get_file().get_basename()


# A park's lane mask from its own baked graph, read here privately (the graph is read-only data and a search writes its own
# heap, so a worker may read one: activities.gd does the same). Pure and thread-safe: no static state, nothing shared.
# scatter.gd's chunked build calls it from the first of its worker jobs.
static func lane_mask_for(park_json: String, park_data: Dictionary) -> Dictionary:
	var graph_path := graph_path_for(park_json)
	var graph = ParkGraph.read(graph_path) if FileAccess.file_exists(graph_path) else null
	return build_lane_mask(graph, park_data, graph_path)


# The lane mask for a park, from its read graph and its parsed file: {"cells": PackedByteArray SIDE x SIDE, row-major
# (z, then x), 1 where the ground lattice cell is on the line; "side", "step", "half"} of park_graph.gd's lattice, {}
# (with a warning) when there is no graph. Pure, with no static state: scatter.gd's chunked build calls it once, on a
# worker, behind a lock before any chunk job reads it (lane_mask_for); the chunk jobs only read it. The line is the union of
#   - every ground node the graph flags LINE (within LINE_M of the shortest path spawn -> waymarks -> beacon);
#   - the ride edges of the rows a route names in from, to or via: a grind row's chord from end to end (the rider rides
#     along it), and a kicker's, launcher's, cable's or lift's two ends (the rest of that edge is flight). The graph
#     holds ride edges for grind, kicker, glide and contraption rows only;
#   - the long-axis centre chord of a routed row with no ride edge and a linear footprint (see LANE_LINEAR_ASPECT).
# One rule for every component, in node space: a node is marked when it lies within LANE_REACH_M (the graph's LINE_M,
# 8 m, its own half-width of the line; the rider's ball is Tuning.RADIUS 1.0, well inside it) of the waymark path, of a
# routed ride edge or of a routed chord. The LINE flags come from the graph already so marked; the edges and chords are
# marked the same way here. A piece is sunk when its nearest node is marked, and that node is at most STEP/sqrt(2)
# (5.66 m) from it, so the guarantee is only that a piece within LANE_REACH_M - STEP/sqrt(2) (about 2.34 m) of the line
# is sunk, and a piece up to LANE_REACH_M + STEP/sqrt(2) (about 13.66 m) away may be; the same for every component.
static func build_lane_mask(graph, park_data: Dictionary, graph_label := "") -> Dictionary:
	if graph == null:
		push_warning("park_map: %s has no readable graph.bin, so no lane mask: tall scatter is not sunk along its line" % graph_label)
		return {}
	var side := ParkGraph.SIDE
	var cells := PackedByteArray()
	cells.resize(side * side)
	for n in cells.size():
		if graph.node_flags[n] & ParkGraph.LINE != 0:
			cells[n] = 1
	var routed := {}
	for route: Dictionary in park_data.get("routes", []):
		for id in [route.get("from", "")] + Array(route.get("via", [])) + [route.get("to", "")]:
			routed[String(id)] = true
	var edged := {}
	var grinds := {}
	for row: Dictionary in park_data.get("park_rows", []):
		if row["verb"] == "grind" or row["element"] == "grind_line" or row["element"] == "rail":
			grinds[String(row["id"])] = true
	for a in graph.node_count():
		for e in range(graph.off[a], graph.off[a + 1]):
			if graph.ride[e] < 0:
				continue
			var row_id: String = graph.names[graph.ride[e]]
			if not routed.has(row_id):
				continue
			edged[row_id] = true
			var b: int = graph.to[e]
			var pa := Vector2(graph.px[a], graph.pz[a])
			var pb := Vector2(graph.px[b], graph.pz[b])
			if grinds.has(row_id) and a < side * side and b < side * side:
				_mark_near(cells, pa, pb)
			else:
				if a < side * side:
					_mark_near(cells, pa, pa)
				if b < side * side:
					_mark_near(cells, pb, pb)
	# Issue #241 comment 6327153207: a routed row with no ride edge and a linear footprint (long side at least
	# LANE_LINEAR_ASPECT times the short) is ridden along its length, so its long-axis centre chord is a lane too. A
	# squarish area row (a bowl, a deck, a wide ground row) adds nothing: there is no lane in it to protect.
	for row: Dictionary in park_data.get("park_rows", []):
		if not routed.has(String(row["id"])) or edged.has(String(row["id"])):
			continue
		var f := _footprint(row)
		var size := Vector2(absf((f["size"] as Vector2).x), absf((f["size"] as Vector2).y))
		if minf(size.x, size.y) <= 0.0 or maxf(size.x, size.y) < LANE_LINEAR_ASPECT * minf(size.x, size.y):
			continue
		var facing := Vector2(sin(f["yaw"]), cos(f["yaw"]))
		var along := facing if size.x >= size.y else Vector2(facing.y, -facing.x)
		var half_len := maxf(size.x, size.y) * 0.5
		_mark_near(cells, (f["at"] as Vector2) - along * half_len, (f["at"] as Vector2) + along * half_len)
	return {"cells": cells, "side": side, "step": ParkGraph.STEP_M, "half": ParkGraph.HALF_M}


# Marks every lattice cell whose node lies within LANE_REACH_M of the segment p-q on the ground plane.
static func _mark_near(cells: PackedByteArray, p: Vector2, q: Vector2) -> void:
	var side := ParkGraph.SIDE
	var step := ParkGraph.STEP_M
	var half := ParkGraph.HALF_M
	var reach := LANE_REACH_M
	var lo := Vector2(minf(p.x, q.x) - reach, minf(p.y, q.y) - reach)
	var hi := Vector2(maxf(p.x, q.x) + reach, maxf(p.y, q.y) + reach)
	for j in range(maxi(0, ceili((lo.y + half) / step)), mini(side - 1, floori((hi.y + half) / step)) + 1):
		for i in range(maxi(0, ceili((lo.x + half) / step)), mini(side - 1, floori((hi.x + half) / step)) + 1):
			var c := Vector2(-half + step * i, -half + step * j)
			if Geometry2D.get_closest_point_to_segment(c, p, q).distance_to(c) <= reach:
				cells[j * side + i] = 1


# Why keep_out leaves a row to the scatter: "ground", "scatter" (a row the scatter itself dresses), "plain_slope" or
# "mesa_edge"; "" for a built row, which the scatter keeps out of. keep_out reads this.
static func open_to_scatter(row: Dictionary, rect: Rect2) -> String:
	if row["element"] == "ground":
		return "ground"
	if row["recipe"] == ParkRecipes.SCATTER_DRESSED:
		return "scatter"
	if plain_slope(row):
		return "plain_slope"
	if mesa_edge(row, rect):
		return "mesa_edge"
	return ""


# A stamped plain slope: a PLAIN_SLOPES greybox whose stamp shapes the ground and that has no absolute y, so
# park_recipes.gd stamp_replaces draws no box for it and the stamped ground is the whole piece.
static func plain_slope(row: Dictionary) -> bool:
	var element := String(row.get("element", ""))
	return element in PLAIN_SLOPES and String(row.get("recipe", "")) == ParkRecipes.GREYBOX + element \
		and String(row.get("stamp", "")) != "" and row.get("y") == null


# A mesa edge: a stamped greybox (stamp_replaces, as plain_slope) of any element or greybox recipe (isle_apron is element
# terrace on greybox:ground) whose cross size reaches across the whole of rect, measured along the row's cross axis. Per
# World NEEDS #149 6325353865, coordinator ruling (a) 2026-10-21, Andrew's veto list.
static func mesa_edge(row: Dictionary, rect: Rect2) -> bool:
	if not String(row.get("recipe", "")).begins_with(ParkRecipes.GREYBOX) \
			or String(row.get("stamp", "")) == "" or row.get("y") != null:
		return false
	var dir := _dir(float(row["yaw_deg"]))
	return float(row["size"][2]) >= absf(dir.y) * rect.size.x + absf(dir.x) * rect.size.y


# One kicker row's lip: the ride's exit, the footprint's far end along the facing, which park_recipes.gd ride_frame (the
# one owner of the origin rule) gives for a greybox and a GLB recipe alike; width is the piece's cross size.
static func kicker_lip(row: Dictionary) -> Dictionary:
	var dir := _dir(float(row["yaw_deg"]))
	var exit: Vector3 = ParkRecipes.ride_frame(row)["exit"]
	return {"id": row["id"], "at": _v2(row["at"]) + dir * exit.z, "dir": dir, "width": float(row["size"][2])}


# The ground-plane direction a yaw faces: 0 faces +z, turning toward +x (PARK.md 2.1).
static func _dir(yaw_deg: float) -> Vector2:
	var a := deg_to_rad(yaw_deg)
	return Vector2(sin(a), cos(a))


static func facing(yaw_deg: float) -> Vector3:
	var d := _dir(yaw_deg)
	return Vector3(d.x, 0.0, d.y)


# PARK size is [length, height, width]; place_greybox runs length along local +Z.
static func footprint_half_extents(row: Dictionary) -> Vector2:
	return Vector2(float(row["size"][2]), float(row["size"][0])).abs() * 0.5


# Closed rectangle in world XZ. An optional endpoint checks the whole segment;
# explicit event footprints supply their already-resolved local X/Z half-extents.
static func footprint_contains(row: Dictionary, world_xz: Vector2, margin := 0.0,
		end_xz := Vector2.INF, half_extents := Vector2.INF) -> bool:
	var half := footprint_half_extents(row) if half_extents == Vector2.INF else half_extents
	half += Vector2.ONE * maxf(0.0, margin)
	var centre := _v2(row["at"])
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var point := (world_xz - centre).rotated(yaw)
	if end_xz == Vector2.INF:
		return absf(point.x) <= half.x and absf(point.y) <= half.y
	var end := (end_xz - centre).rotated(yaw)
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		var delta: float = end[axis] - point[axis]
		if absf(delta) < 0.00000001:
			if absf(point[axis]) > half[axis]:
				return false
		else:
			var near: float = (-half[axis] - point[axis]) / delta
			var far: float = (half[axis] - point[axis]) / delta
			enter = maxf(enter, minf(near, far))
			leave = minf(leave, maxf(near, far))
			if enter > leave:
				return false
	return true


static func _footprint(row: Dictionary) -> Dictionary:
	return {"id": row["id"], "at": _v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])),
		"yaw": deg_to_rad(float(row["yaw_deg"]))}


# A JSON value with every [x, z] turned into a Vector2 and every [x, y, z] into a Vector3,
# through nested objects and lists (PARK.md 2.6: arrays become vectors in park_map.gd).
static func vectors(value):
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = vectors(value[key])
		return out
	if value is Array:
		if ParkSchema._is_vec(value, 2):
			return _v2(value)
		if ParkSchema._is_vec(value, 3):
			return _v3(value)
		return value.map(func(v): return vectors(v))
	return value


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
