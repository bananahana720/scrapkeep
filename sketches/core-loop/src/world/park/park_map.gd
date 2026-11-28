extends "res://src/world/stage_map.gd"


const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const LockRows := preload("res://src/world/lock_rows.gd")
const BreatherRows := preload("res://src/world/breather_rows.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")

const LANE_REACH_M := 8.0
const LANE_LINEAR_ASPECT := 2.0
const FIXTURE := "res://src/world/park/park_test.json"
const LINES_PATH := "res://assets/park/%s/lines.json"
const TRAIL_GAP_MARGIN_M := 1.0
const PLAIN_SLOPES := ["bank", "drop", "ground", "sky_island"]

var path := ""
var ok := false
var errors: Array = []
var park := {}
var landmark := Vector3.INF
var contraptions: Array = []
var bay_dock := {}
var reach_m := 0.0
var time_of_day := ""
var rescue_sites: Array = []
var survival_sites: Array = []
var approach := {}
var _ride_lines = null


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


func breathers() -> Array:
	return BreatherRows.rows(title).duplicate(true) if ok else []


func warden_spec() -> Dictionary:
	return park["landmark"]["warden"].duplicate(true) if ok else {}


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
				if row.get("kind", "") == "lightning":
					out.append({"id": row["id"], "kind": "event", "at": v2(site["at"]), "ring": Vector2(0.0, float(row.get("effect", {}).get("strike_m", 0.0)))})
					continue
				site = NaturalFootprint.resolve(row, site)
			var half := footprint_half_extents(site)
			var own = row.get("effect", {}).get("footprint_m")
			if own is Array:
				half = v2(own).abs() * 0.5
			out.append({"id": row["id"], "kind": table[1], "at": v2(site["at"]), "half": half, "yaw_deg": float(site["yaw_deg"])})
	var rules: Dictionary = load("res://src/world/activities.gd").RULES
	for row in park.get("activity_rows", []):
		var ring := -1.0
		for variant in [row] + row.get("alts", []):
			var rule: Dictionary = rules.get(String(variant.get("activity", "")), {})
			if rule.has("pack"):
				ring = maxf(ring, float(rule.get("ring", 0.0)))
		if ring >= 0.0 and row.has("at"):
			out.append({"id": row["id"], "kind": "activity", "at": v2(row["at"]), "ring": Vector2(0.0, ring)})
	out.append({"id": "warden", "kind": "warden", "at": beacon, "ring": Vector2(0.0, reach_m)})
	var lock: Dictionary = LockRows.row(title).get("lock", {})
	if not lock.is_empty():
		var radius := float(lock.get("radius_m", 26.0))
		var ahead := minf(float(lock.get("ahead_m", 0.0)), radius * 0.5)
		var within := float(lock.get("within_m", 0.0))
		var share: float = load("res://src/world/stage_locks.gd").LOCK_ANY_SLOPE_SHARE
		out.append({"id": String(lock["id"]), "kind": "yard", "at": beacon,
			"ring": Vector2(maxf(0.0, within * share - ahead - radius), within - ahead + radius)})
	return out


func handover() -> Dictionary:
	if not ok or not park.has("exit") or not park.has("arrives") or not park.has("atlas"):
		return {}
	var slots: Array = park["landmark"]["gate_slots"]
	var gate: Dictionary = slots[slots.size() / 2]
	var spawn: Dictionary = park["spawn"]
	var out: Dictionary = park["exit"].duplicate()
	out["at"] = v2(gate["at"])
	out["heading_deg"] = float(gate["facing_deg"])
	var into: Dictionary = park["arrives"].duplicate()
	into["at"] = v2(spawn["at"])
	into["heading_deg"] = float(spawn["heading_deg"])
	var atlas: Dictionary = park["atlas"]
	return {"stage": park["map"], "atlas": {"origin": v2(atlas["origin"]), "heading_deg": float(atlas["heading_deg"])}, "exit": out, "arrives": into}


func _fill() -> void:
	title = String(park["map"])
	time_of_day = String(park["time_of_day"])
	spawn = v2(park["spawn"]["at"])
	heading = facing(float(park["spawn"]["heading_deg"]))
	var r: Array = park["play_rect"]
	play_rect = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

	var mark: Dictionary = park["landmark"]
	beacon = v2(mark["beacon"])
	reach_m = float(mark["reach_m"])
	landmark = _v3(mark["sight_top"])
	bay_dock = {"at": v2(mark["bay_dock"]["at"]), "facing": facing(float(mark["bay_dock"]["facing_deg"]))}
	gate_slots = []
	for slot in mark["gate_slots"]:
		gate_slots.append({"at": v2(slot["at"]), "facing": facing(float(slot["facing_deg"]))})

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
		var site := _variant(row)
		site.merge({"row": row["id"], "site": row["site"], "at": v2(row["at"])})
		if row.has("route"):
			site["route"] = String(row["route"])
		if row.has("face"):
			site["face"] = v2(row["face"]).normalized()
		if row.has("bar"):
			site["bar"] = String(row["bar"])
		if row.get("extra", "") == "card_2":
			site["extra"] = "card_2"
		if row.has("alts"):
			site["alts"] = (row["alts"] as Array).map(func(alt: Dictionary) -> Dictionary: return _variant(alt.merged({"pay": {}})))
		activity_sites.append(site)

	rescue_sites = []
	for row in park.get("rescue_rows", []):
		rescue_sites.append({"id": row["id"], "quest": row["quest"], "prompt": row["prompt"], "pilot": row["pilot"],
			"at": v2(row["at"]), "face": v2(row["face"]).normalized()})

	survival_sites = []
	for row in park.get("survival_rows", []):
		survival_sites.append({"row": row["id"], "form": row["form"], "at": v2(row["at"])})

	approach = {"to": park["approach"]["to"], "smoke": v2(park["approach"]["smoke"])} if park.has("approach") else {}

	scrap_trail = _scrap_trail()

	scatter = scatter.duplicate(true)
	var keep_out := []
	for row in park["park_rows"]:
		if open_to_scatter(row, play_rect) != "":
			continue
		keep_out.append(_footprint(row))
	keep_out.append(_footprint(mark))
	scatter["keep_out"] = keep_out


static func _variant(row: Dictionary) -> Dictionary:
	var out := {"id": row["activity"]}
	if not (row["pack"] as Array).is_empty():
		out["pack"] = row["pack"].duplicate()
	if not (row["pay"] as Dictionary).is_empty():
		out["pay"] = row["pay"].duplicate(true)
	return out


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
		var at := place_of(park, point) if point is String else v2(point)
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


func line_within(at: Vector2, reach_m: float) -> bool:
	if not ThreadGuard.main_only("park_map line_within"):
		return false
	if _ride_lines == null:
		_ride_lines = _read_ride_lines()
	for points: PackedVector2Array in _ride_lines:
		for i in range(1, points.size()):
			if Geometry2D.get_closest_point_to_segment(at, points[i - 1], points[i]).distance_to(at) <= reach_m:
				return true
	return false


func _read_ride_lines() -> Array:
	var out: Array = []
	var lines_path := LINES_PATH % title
	if not FileAccess.file_exists(lines_path):
		return out
	var data: Dictionary = ParkSchema.read_file(lines_path)["data"]
	var routes: Array = []
	if data.get("floor") is Dictionary:
		routes.append(data["floor"].get("waypoints", []))
	for pilot in data.get("pilots", {}):
		routes.append(data["pilots"][pilot].get("waypoints", []))
	for route: Array in routes:
		var points := PackedVector2Array()
		for point in route:
			var at := place_of(park, point) if point is String else v2(point)
			if at != Vector2.INF:
				points.append(at)
		out.append(points)
	return out


static func place_of(park_data: Dictionary, id: String) -> Vector2:
	if id == ParkSchema.DROP_IN:
		return v2(park_data["spawn"]["at"])
	if id == ParkSchema.LANDMARK:
		return v2(park_data["landmark"]["beacon"])
	for table in ["park_rows", "activity_rows"]:
		for row: Dictionary in park_data.get(table, []):
			if row.get("id") == id:
				return v2(row["at"])
	return Vector2.INF


static func graph_path_for(park_json: String) -> String:
	return "res://assets/park/%s/graph.bin" % park_json.get_file().get_basename()


static func lane_mask_for(park_json: String, park_data: Dictionary) -> Dictionary:
	var graph_path := graph_path_for(park_json)
	var graph = ParkGraph.read(graph_path) if FileAccess.file_exists(graph_path) else null
	return build_lane_mask(graph, park_data, graph_path)


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


static func plain_slope(row: Dictionary) -> bool:
	var element := String(row.get("element", ""))
	return element in PLAIN_SLOPES and String(row.get("recipe", "")) == ParkRecipes.GREYBOX + element \
		and String(row.get("stamp", "")) != "" and row.get("y") == null


static func mesa_edge(row: Dictionary, rect: Rect2) -> bool:
	if not String(row.get("recipe", "")).begins_with(ParkRecipes.GREYBOX) \
			or String(row.get("stamp", "")) == "" or row.get("y") != null:
		return false
	var dir := yaw_dir(float(row["yaw_deg"]))
	return float(row["size"][2]) >= absf(dir.y) * rect.size.x + absf(dir.x) * rect.size.y


static func kicker_lip(row: Dictionary) -> Dictionary:
	var dir := yaw_dir(float(row["yaw_deg"]))
	var exit: Vector3 = ParkRecipes.ride_frame(row)["exit"]
	return {"id": row["id"], "at": v2(row["at"]) + dir * exit.z, "dir": dir, "width": float(row["size"][2])}


static func yaw_dir(yaw_deg: float) -> Vector2:
	var a := deg_to_rad(yaw_deg)
	return Vector2(sin(a), cos(a))


static func facing(yaw_deg: float) -> Vector3:
	var d := yaw_dir(yaw_deg)
	return Vector3(d.x, 0.0, d.y)


static func footprint_half_extents(row: Dictionary) -> Vector2:
	return Vector2(float(row["size"][2]), float(row["size"][0])).abs() * 0.5


static func footprint_contains(row: Dictionary, world_xz: Vector2, margin := 0.0,
		end_xz := Vector2.INF, half_extents := Vector2.INF) -> bool:
	var half := footprint_half_extents(row) if half_extents == Vector2.INF else half_extents
	half += Vector2.ONE * maxf(0.0, margin)
	var centre := v2(row["at"])
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
	return {"id": row["id"], "at": v2(row["at"]), "size": Vector2(float(row["size"][0]), float(row["size"][2])),
		"yaw": deg_to_rad(float(row["yaw_deg"]))}


static func vectors(value):
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = vectors(value[key])
		return out
	if value is Array:
		if ParkSchema.is_vec(value, 2):
			return v2(value)
		if ParkSchema.is_vec(value, 3):
			return _v3(value)
		return value.map(func(v): return vectors(v))
	return value


static func v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
