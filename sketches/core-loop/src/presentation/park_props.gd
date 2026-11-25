extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const ParkSites := preload("res://src/presentation/park_sites.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")
const ThreadGuard := preload("res://src/core/thread_guard.gd")
const NaturalFootprint := preload("res://src/world/events/natural_footprint.gd")
const EventDirector := preload("res://src/world/event_director.gd")

const FILE_SCHEMA := "scrapkeep-park-props/1"
const KIT_SCHEMA := "scrapkeep-park-props-kit/1"
const FILE_DIR := "res://src/world/park/props/"
const LINES_PATH := "res://assets/park/%s/lines.json"
const PARKS := ["park_dam", "park_flume", "park_pit", "park_sinkhole", "park_islands", "park_crown"]
const HERO := "dress_hero"
const PROP := "dress_prop"
const GROUP := "park_props"
const LOW_PRESET := "low"

const LINE_CLEAR_LOW_M := 6.0
const LINE_CLEAR_MID_M := 10.0
const LINE_CLEAR_TALL_M := 20.0
const LINE_CLEAR_KIND_MAX_M := 60.0
const BRIEF_LINE_KINDS := {"laundry_line": 30.0, "washline": 30.0, "windsock": 30.0, "kite_pennant": 30.0}
const LOW_HEIGHT_M := 1.2
const NEAR_RANGE_M := 60.0
const TALL_HEIGHT_M := 3.0
const RIDE_ELEMENTS := ["kicker", "drop", "rail", "grind_line", "half_pipe", "bowl", "elevated_line", "ledge", "tunnel", "flow_line", "sky_island"]
const OPEN_ELEMENTS := ["ground", "bank", "terrace", "anchor_field"]
const HOME_CLEAR_M := 25.0
const SLOPE_MAX_DEG := 25.0
const SEAT_FLOAT_MAX_M := 0.15
const SMALL_RADIUS_M := 0.6
const ALIGN_MAX_DEG := 12.0
const LINE_REACH_M := 64.0
const KICK_MARGIN_M := 8.0
const KICK_RUNOUT_M := 40.0
const LITTER_CHUNK_M := 160.0
const LITTER_SCALE_MIN := 0.9
const LITTER_SCALE_MAX := 1.15
const LITTER_GAP_RATIO := 0.5
const LITTER_FOOT_CELL_M := 4.0
const CAMP_ACTIVITIES := ["enemy_camp"]
const GROUND_ROW_INSET_M := 8.0
const LOW_GROUND_MAX_M := 1.0
const LOW_GROUND_MIN_M := 60.0
const STAMP_NARROW_M := LOW_GROUND_MIN_M
const LOW_GROUND_HOME_MIN_M := 200.0
const LOW_GROUND_ELEMENTS := ["flow_line", "bowl", "drop", "sky_island"]
const LITTER_BAND_MIN_M := 6.0
const LITTER_BAND_MAX_M := 64.0

const HERO_RANGES := [[0.0, 70.0], [62.0, 180.0], [172.0, 450.0]]
const PROP_RANGES := [[0.0, 35.0], [32.0, 90.0], [87.0, 200.0]]
const LITTER_RANGE := [0.0, 70.0]
const HERO_MARGIN_M := 8.0
const PROP_MARGIN_M := 3.0
const LOW_RANGE_SCALE := 0.5
const BUILD_SLICE_USEC := 3000
const FREE_SLICE_USEC := 1500
const MERGE_CHUNK := 4

static var file_overrides := {}
# Main thread only: Godot headless Dummy rasterizer mesh RIDs are not thread-safe.
static var _meshes := {}
static var _cache_owner := ""
static var _requested := {}
static var _far_sources := {}
static var far_reads := 0
static var _material: StandardMaterial3D


static func reset_for_tests() -> void:
	file_overrides.clear()
	far_reads = 0
	release_shared()
	_stand_ins_lock.lock()
	_stand_ins.clear()
	_stand_ins_stamp = -1
	_stand_ins_lock.unlock()

var ctx
const PropKicks := preload("res://src/presentation/prop_kicks.gd")
const Tuning := preload("res://src/movement/tuning.gd")
signal prop_kicked(at: Vector3, mode: String, speed: float, tags: Array)
var kicks := PropKicks.new()
var _ground := Callable()
var map_id := ""
var instances: Array = []
var views: Array[GeometryInstance3D] = []
var last_entry_usec := 0
var last_process_usec := 0
var last_process_frame := -1
var last_steps := PackedStringArray()
var _built_for := []
var _pending := false
var _task := -1
var _out := {}
var _jobs: Array = []
var _reads: Array = []
var _holder: Node3D
var _dying: Array[Node] = []
var _steps: Array = []
var _kit := {}
var _low := false
var _next := {}
var _next_meshes: Array = []
var _next_reads: Array = []


class Context:
	extends RefCounted
	var map
	var map_id := ""
	var ground: Callable
	var rect := Rect2()
	var sites
	var lanes: Array = []
	var lines := {}
	var homes: Array = []
	var camps: Array[Vector2] = []
	var spawn := Vector2.ZERO
	var ground_rows := {}
	var low_rows := {}
	var stamped: Array = []
	var scatter_rows: Array = []
	var unresolved: Array = []
	var events: Array = []
	var _cells := {}

	func line_distance(p: Vector2) -> float:
		var best := INF
		for leg: Vector4 in _cells.get(_cell(p), []):
			var a := Vector2(leg.x, leg.y)
			var b := Vector2(leg.z, leg.w)
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
		return best

	static func blocks_props(row: Dictionary) -> bool:
		var element := String(row.get("element", ""))
		var home = row.get("home")
		var fact = row.get("ride_fact")
		if element.is_empty() or (home is String and not (home as String).is_empty()):
			return true
		return element in RIDE_ELEMENTS or (fact != null and not (fact is String and (fact as String).is_empty()) and not (fact is bool and not fact) and not element in OPEN_ELEMENTS)

	func keepout_at(p: Vector2, margin: float, low_ok := false) -> String:
		var what: String = SetDressing.blocked(sites._keepouts, p, margin)
		if what != "":
			return what
		for row: Dictionary in sites._cells.get(ParkSites._cell(p), []):
			if blocks_props(row) and not ground_rows.has(row.get("id")) and not (low_ok and low_rows.has(row.get("id"))) and ParkMap.footprint_contains(row, p, margin):
				return "built row " + String(row.get("id", "?"))
		for row: Dictionary in stamped:
			if not ground_rows.has(row.get("id")) and not (low_ok and low_rows.has(row.get("id"))) and ParkMap.footprint_contains(row, p, margin):
				return "built row " + String(row.get("id", "?"))
		return ""

	func use_ground_rows(ids) -> void:
		ground_rows = {}
		if not ids is Array:
			return
		for row: Dictionary in map.park.get("park_rows", []):
			if (ids as Array).has(row.get("id")):
				ground_rows[row["id"]] = row

	func use_low_ground_rows(ids) -> void:
		low_rows = {}
		if not ids is Array:
			return
		for row: Dictionary in map.park.get("park_rows", []):
			if (ids as Array).has(row.get("id")):
				low_rows[row["id"]] = row

	func add_leg(a: Vector2, b: Vector2) -> void:
		var low := _cell(Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * LINE_REACH_M)
		var high := _cell(Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * LINE_REACH_M)
		for x in range(low.x, high.x + 1):
			for y in range(low.y, high.y + 1):
				var key := Vector2i(x, y)
				if not _cells.has(key):
					_cells[key] = []
				_cells[key].append(Vector4(a.x, a.y, b.x, b.y))

	static func _cell(p: Vector2) -> Vector2i:
		return Vector2i(floori(p.x / LINE_REACH_M), floori(p.y / LINE_REACH_M))


static func stage_of(id: String) -> int:
	return PARKS.find(id) + 1


static func world_for(id: String) -> Dictionary:
	var map := ParkMap.new("res://src/world/park/%s.json" % id)
	var dir := ParkTerrain.bake_dir(id)
	var heights := ParkTerrain._read_zstd(dir + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var holes := FileAccess.get_file_as_bytes(dir + "/holes.bin")
	var floors := FileAccess.get_file_as_bytes(dir + "/under.bin").to_float32_array()
	var under := PackedFloat32Array()
	under.resize(ParkTerrain.CELLS * ParkTerrain.CELLS)
	var n := 0
	for k in holes.size():
		if holes[k] == 1:
			under[k] = floors[n]
			n += 1
	return {"map": map, "ground": Terrain._park_ground_at.bind(heights, holes, under), "stage": stage_of(id)}


static func file_path(id: String) -> String:
	return String(file_overrides.get(id, FILE_DIR + id + ".json"))


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func context(park_map, ground: Callable, stage := -1) -> Context:
	var c := Context.new()
	c.map = park_map
	c.ground = ground
	c.map_id = String(park_map.park.get("map", ""))
	c.rect = park_map.play_rect
	c.spawn = park_map.spawn
	var st: int = stage_of(c.map_id) if stage < 0 else stage
	c.sites = ParkSites.new(park_map, ground, st)
	c.sites._keepouts = kicker_keepouts(c.sites._keepouts, park_map.kickers, park_map.park.get("park_rows", []))
	c.lanes = ParkRecipes.clear_zones(park_map.park).filter(func(z: Dictionary) -> bool: return z.has("a"))
	var lines := load_json(LINES_PATH % c.map_id)
	var named: Dictionary = (lines.get("pilots", {}) as Dictionary).duplicate()
	var keys := named.keys()
	keys.sort()
	var ordered := {}
	for key in keys:
		ordered[key] = named[key]
	ordered["floor"] = lines.get("floor", {})
	for key in ordered:
		var pts := PackedVector2Array()
		for point in ordered[key].get("waypoints", []):
			var at := _place(park_map.park, point) if point is String else _pair(point)
			if at != Vector2.INF:
				pts.append(at)
			else:
				c.unresolved.append("lines.json %s waypoint %s resolves to no place" % [key, str(point)])
		if pts.size() > 1:
			c.lines[key] = pts
			for i in range(1, pts.size()):
				c.add_leg(pts[i - 1], pts[i])
	for home: Dictionary in park_map.park.get("home_rows", []):
		var site := String(home.get("site", ""))
		var found := {}
		for row: Dictionary in park_map.park.get("park_rows", []):
			if row["id"] == site:
				found = row
				break
		if found.is_empty():
			for row: Dictionary in park_map.park.get("activity_rows", []):
				if row["id"] == site:
					found = {"at": row["at"], "point": true}
					break
		if not found.is_empty():
			c.homes.append({"id": String(home.get("id", site)), "row": found})
		else:
			c.unresolved.append("home_rows site %s (home %s) names no park or activity row" % [site, String(home.get("id", site))])
	for ev: Dictionary in park_map.park.get("event_rows", []):
		var event_site := String(ev.get("site", ""))
		var event_row := {}
		for row: Dictionary in park_map.park.get("park_rows", []):
			if row["id"] == event_site:
				event_row = row
				break
		if not event_row.is_empty():
			var effect: Dictionary = ev.get("effect", {})
			var site := NaturalFootprint.resolve(ev, event_row)
			var half = ParkMap.footprint_half_extents(site)
			if effect.has("footprint_m"):
				var footprint = effect["footprint_m"]
				half = (footprint if footprint is Vector2 else Vector2(float(footprint[0]), float(footprint[1]))).abs() * 0.5
			var lightning: bool = String(ev.get("kind", "")) == "lightning"
			var hazard_m = effect.get("hazard_m")
			c.events.append({"id": String(ev.get("id", event_site)), "site": site, "half": half,
				"box": not lightning or EventDirector._park_ground(ev),
				"strike": maxf(0.0, float(effect.get("strike_m", 0.0))) if lightning else -1.0,
				"hazard": maxf(0.0, float(hazard_m[0])) if hazard_m is Array and not (hazard_m as Array).is_empty() else -1.0,
				"hold": maxf(0.0, float(ev.get("hold_clear_m", 0.0)))})
		else:
			c.unresolved.append("event_rows site %s (event %s) names no park row" % [event_site, String(ev.get("id", event_site))])
	for row: Dictionary in park_map.park.get("park_rows", []):
		if not String(row.get("stamp", "")).is_empty() \
				and maxf(float(row["size"][0]), float(row["size"][2])) > ParkSites.STAMP_KEEP_M and Context.blocks_props(row) \
				and (String(row.get("element", "")) == "sky_island" or minf(absf(float(row["size"][0])), absf(float(row["size"][2]))) <= STAMP_NARROW_M):
			c.stamped.append(row)
		if String(row.get("recipe", "")) == ParkRecipes.SCATTER_DRESSED:
			c.scatter_rows.append(row)
	for row: Dictionary in park_map.park.get("activity_rows", []):
		if String(row.get("activity", "")) in CAMP_ACTIVITIES:
			c.camps.append(_pair(row["at"]))
	return c


static func kicker_keepouts(keepouts: Array, kickers: Array, park_rows: Array) -> Array:
	var out := keepouts.filter(func(row: Dictionary) -> bool: return row["what"] != "kicker ramp")
	for kicker: Dictionary in kickers:
		var length := _kicker_length(kicker, park_rows)
		var dir: Vector2 = kicker["dir"]
		var side := Vector2(-dir.y, dir.x) * float(kicker["width"]) * 0.5
		var radius := length * 0.5 + KICK_MARGIN_M
		var body: Vector2 = kicker["at"] - dir * length * 0.5
		out.append({"what": "kicker ramp", "points": PackedVector2Array([body - side, body + side]), "radius": radius, "ride": true})
		var run := kicker_runout(kicker, park_rows)
		out.append({"what": "kicker run-out", "points": run["points"], "radius": run["radius"], "ride": true})
	return out


static func _kicker_length(kicker: Dictionary, park_rows: Array) -> float:
	var length := 12.0
	for row: Dictionary in park_rows:
		if row["id"] == kicker.get("id"):
			length = float(row["size"][0])
	return length


static func kicker_runout(kicker: Dictionary, park_rows: Array) -> Dictionary:
	var dir: Vector2 = kicker["dir"]
	var side := Vector2(-dir.y, dir.x) * float(kicker["width"]) * 0.5
	var run: Vector2 = kicker["at"] + dir * KICK_RUNOUT_M * 0.5
	var radius := _kicker_length(kicker, park_rows) * 0.5 + KICK_MARGIN_M
	return {"points": PackedVector2Array([run - side, run + side]), "radius": maxf(radius, KICK_RUNOUT_M * 0.5)}


static func runout_near(c: Context, kicker_id: String, at: Vector2, within := 40.0) -> String:
	for kicker: Dictionary in c.map.kickers:
		if String(kicker.get("id", "")) != kicker_id:
			continue
		var run := kicker_runout(kicker, c.map.park.get("park_rows", []))
		var pts: PackedVector2Array = run["points"]
		var gap := at.distance_to(Geometry2D.get_closest_point_to_segment(at, pts[0], pts[1])) - float(run["radius"])
		if gap <= within:
			return ""
		return "%.0f m from the %s run-out edge, want at most %.0f" % [gap, kicker_id, within]
	return "no kicker %s in the park" % kicker_id


static func probe_scales(file: Dictionary) -> PackedFloat32Array:
	var found := [1.0]
	for template: Dictionary in (file.get("templates", {}) as Dictionary).values():
		for prop: Dictionary in template.get("props", []):
			found.append(float(prop.get("scale", 1.0)))
	if file.get("litter") is Dictionary:
		found.append(LITTER_SCALE_MIN)
		found.append(LITTER_SCALE_MAX)
	found.sort()
	var out := PackedFloat32Array()
	for scale: float in found:
		if out.is_empty() or not is_equal_approx(out[out.size() - 1], scale):
			out.append(scale)
	return out


static func probe_variants_of(kit: Dictionary) -> Array:
	var out := []
	var names: Array = (kit.get("kinds", {}) as Dictionary).keys()
	names.sort()
	for kind: String in names:
		var keys: Array = (kit["kinds"][kind]["variants"] as Dictionary).keys()
		keys.sort()
		for v: String in keys:
			out.append({"kind": kind, "v": v})
	return out


static func probe_at(c: Context, kit: Dictionary, probes: Array, scales: Array, at: Vector2) -> String:
	for scale: float in scales:
		for probe: Dictionary in probes:
			var inst := _instance("probe", String(probe["kind"]), String(probe["v"]), kit, at, 0.0, scale, 0.0, c.ground, false)
			if check_one(inst, c).is_empty():
				return "%s/%s@%.2f" % [probe["kind"], probe["v"], scale]
	return ""


static func probe_legal_at(c: Context, kit: Dictionary, probes: Array, scales: Array, at: Vector2) -> bool:
	return probe_at(c, kit, probes, scales, at) != ""


static func camera_for(pose: Dictionary, cam: Dictionary, ground: Callable) -> Transform3D:
	var x := float(pose["x"])
	var z := float(pose["z"])
	var anchor := Vector3(x, _height(ground, Vector2(x, z)) + 1.0 + float(cam["up"]), z)
	var basis := Basis(Vector3.UP, float(pose["yaw"])) * Basis(Vector3.RIGHT, float(cam["pitch"]))
	return Transform3D(basis, anchor + basis * Vector3(0.0, 0.0, float(cam["arm"])))


static func cell_visible(view: Transform3D, cam: Dictionary, point: Vector3, range_m: float) -> bool:
	if Vector2(point.x - view.origin.x, point.z - view.origin.z).length() > range_m:
		return false
	var local := view.affine_inverse() * point
	var depth := -local.z
	if depth <= 0.1:
		return false
	var tan_v := tan(deg_to_rad(float(cam["fov_deg"])) * 0.5)
	return absf(local.y) <= depth * tan_v and absf(local.x) <= depth * tan_v * float(cam["aspect"])


static func cone_legal_cells(c: Context, kit: Dictionary, probes: Array, scales: Array, poses: Array, cam: Dictionary, range_m: float, cell_m := 2.5, limit := 1) -> Array:
	var out := []
	if probes.is_empty():
		return out
	for pose: Dictionary in poses:
		var view := camera_for(pose, cam, c.ground)
		var x0 := floori((view.origin.x - range_m) / cell_m)
		var x1 := ceili((view.origin.x + range_m) / cell_m)
		var z0 := floori((view.origin.z - range_m) / cell_m)
		var z1 := ceili((view.origin.z + range_m) / cell_m)
		for ix in range(x0, x1 + 1):
			for iz in range(z0, z1 + 1):
				var at := Vector2((ix + 0.5) * cell_m, (iz + 0.5) * cell_m)
				if not cell_visible(view, cam, Vector3(at.x, _height(c.ground, at), at.y), range_m):
					continue
				if probe_legal_at(c, kit, probes, scales, at):
					out.append(at)
					if out.size() >= limit:
						return out
	return out


static func parse_open(arg: String) -> Dictionary:
	var spaces := []
	for part in arg.split(",", false):
		var f := part.split(":", true, 3)
		var reason := String(f[3]) if f.size() == 4 else ""
		if f.size() != 4 or not (reason == "no_cell" or (reason.begins_with("runout:") and reason.length() > 7) or _filled_cell(reason) != Vector2.INF):
			return {"error": "--open entry '%s' wants x:z:r:no_cell, x:z:r:runout:<kicker> or x:z:r:filled:<cx>:<cz>" % part}
		spaces.append([Vector2(float(f[0]), float(f[1])), float(f[2]), reason])
	return {"spaces": spaces}


static func _filled_cell(reason: String) -> Vector2:
	var f := reason.split(":")
	if f.size() != 3 or f[0] != "filled" or not String(f[1]).is_valid_float() or not String(f[2]).is_valid_float():
		return Vector2.INF
	return Vector2(float(f[1]), float(f[2]))


static func open_reason(c: Context, kit: Dictionary, file: Dictionary, reason: String, at: Vector2, poses: Array, cam: Dictionary, placed: Array = []) -> Dictionary:
	if reason.begins_with("runout:"):
		var why := runout_near(c, reason.trim_prefix("runout:"), at)
		return {"ok": why == "", "why": why, "cell": null}
	var filled := _filled_cell(reason)
	if reason != "no_cell" and filled == Vector2.INF:
		return {"ok": false, "why": "unknown reason %s" % reason, "cell": null}
	var saved_ground := c.ground_rows
	var saved_low := c.low_rows
	c.use_ground_rows(file.get("ground_rows"))
	c.use_low_ground_rows(file.get("low_ground_rows"))
	var scales := Array(probe_scales(file))
	var probes := probe_variants_of(kit)
	var result := {"ok": false, "why": "no kit to probe with", "cell": null}
	if not probes.is_empty() and filled != Vector2.INF:
		result = _filled_verdict(cone_legal_cells(c, kit, probes, scales, poses, cam, NEAR_RANGE_M, FILLED_CELL_M, FILLED_CELL_LIMIT), filled, placed)
	elif not probes.is_empty():
		var cells := cone_legal_cells(c, kit, probes, scales, poses, cam, NEAR_RANGE_M)
		var label := "%d probe variants at scales %s" % [probes.size(), str(scales)]
		if cells.is_empty():
			result = {"ok": true, "why": label + " find no legal cell in the view frustum", "cell": null}
		else:
			result = {"ok": false, "why": "probe %s has a legal cell at (%.1f, %.1f) in the view frustum (%s)" % [probe_at(c, kit, probes, scales, cells[0]), cells[0].x, cells[0].y, label], "cell": [cells[0].x, cells[0].y]}
	c.ground_rows = saved_ground
	c.low_rows = saved_low
	return result


const FILLED_CELL_M := 2.5
const FILLED_CELL_LIMIT := 4096


static func _filled_verdict(cells: Array, named: Vector2, placed: Array) -> Dictionary:
	if cells.is_empty():
		return {"ok": false, "why": "no legal cell: use no_cell", "cell": null}
	if cells.size() >= FILLED_CELL_LIMIT:
		return {"ok": false, "why": "the cone scan stopped at %d legal cells, so free cells may be unseen" % FILLED_CELL_LIMIT, "cell": null}
	var unique := []
	for cell: Vector2 in cells:
		if not unique.has(cell):
			unique.append(cell)
	cells = unique
	var taken := []
	for cell: Vector2 in cells:
		var is_taken := false
		for inst: Dictionary in placed:
			if inst.get("litter", false):
				continue
			var pos: Vector3 = inst["pos"]
			if Vector2(pos.x, pos.z).distance_to(cell) <= float(inst["radius"]) + FILLED_CELL_M * 0.5:
				is_taken = true
				break
		if is_taken:
			taken.append(cell)
		else:
			return {"ok": false, "why": "free legal cell at (%.1f, %.1f)" % [cell.x, cell.y], "cell": [cell.x, cell.y]}
	for cell: Vector2 in taken:
		if cell.distance_to(named) <= FILLED_CELL_M:
			return {"ok": true, "why": "%d legal cells in the view frustum, all covered by placed props" % cells.size(), "cell": null}
	return {"ok": false, "why": "named cell (%.1f, %.1f) is not a legal filled cell" % [named.x, named.y], "cell": null}


static func _pair(value) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


static func _place(park: Dictionary, id: String) -> Vector2:
	if id == "drop_in":
		return _pair(park.get("spawn", {}).get("at"))
	if id == "landmark":
		return _pair(park.get("landmark", {}).get("beacon"))
	for table in ["park_rows", "activity_rows"]:
		for row in park.get(table, []):
			if row is Dictionary and row.get("id") == id:
				return _pair(row.get("at"))
	return Vector2.INF


static func file_errors(file: Dictionary, kit: Dictionary, park_map = null) -> Array:
	var errors := []
	if file.get("schema") != FILE_SCHEMA:
		errors.append("schema is not " + FILE_SCHEMA)
	if not file.get("map") is String or not String(file.get("map", "")).begins_with("park_"):
		errors.append("map is not a park id")
	if not file.get("kit") is String:
		errors.append("kit is not a path")
	var kinds: Dictionary = kit.get("kinds", {}) if kit.get("kinds") is Dictionary else {}
	var templates = file.get("templates")
	if not templates is Dictionary or (templates as Dictionary).is_empty():
		errors.append("templates is empty")
		templates = {}
	for tid in templates:
		var props = templates[tid].get("props") if templates[tid] is Dictionary else null
		if not props is Array or (props as Array).is_empty():
			errors.append("template %s has no props" % tid)
			continue
		for i in (props as Array).size():
			var prop = props[i]
			var label := "template %s prop %d" % [tid, i]
			if not prop is Dictionary:
				errors.append(label + " is not an object")
				continue
			errors.append_array(_kind_errors(label, kinds, prop.get("kind"), prop.get("v")))
			if _pair(prop.get("at")) == Vector2.INF:
				errors.append(label + " has no at [dx, dz]")
			for key in ["yaw_deg", "scale", "tilt_deg"]:
				if prop.has(key) and not (prop[key] is float or prop[key] is int):
					errors.append("%s %s is not a number" % [label, key])
			if prop.has("scale") and float(prop["scale"]) <= 0.0:
				errors.append(label + " scale is not positive")
	var spots = file.get("spots")
	if not spots is Array or (spots as Array).is_empty():
		errors.append("spots is empty")
		spots = []
	var seen := {}
	for spot in spots:
		if not spot is Dictionary or not spot.get("id") is String or String(spot.get("id")).is_empty():
			errors.append("a spot has no id")
			continue
		var id := String(spot["id"])
		if seen.has(id):
			errors.append("spot id %s repeats" % id)
		seen[id] = true
		if not templates.has(spot.get("template", "")):
			errors.append("spot %s names no template" % id)
		if _pair(spot.get("at")) == Vector2.INF:
			errors.append("spot %s has no at [x, z]" % id)
	var litter = file.get("litter")
	if litter is Dictionary:
		if not (litter.get("spacing_m") is float or litter.get("spacing_m") is int) or float(litter.get("spacing_m", 0.0)) <= 0.0:
			errors.append("litter spacing_m is not positive")
		var band = litter.get("band_m")
		if not band is Array or (band as Array).size() != 2 or float(band[0]) < 0.0 or float(band[1]) < float(band[0]):
			errors.append("litter band_m is not [near, far]")
		elif float(band[0]) < LITTER_BAND_MIN_M or float(band[1]) > LITTER_BAND_MAX_M:
			errors.append("litter band_m [%s, %s] is outside the tier bands: near at least %.0f, far at most %.0f" % [str(band[0]), str(band[1]), LITTER_BAND_MIN_M, LITTER_BAND_MAX_M])
		if not litter.get("seed") is float and not litter.get("seed") is int:
			errors.append("litter seed is not a number")
		if not litter.get("kinds") is Array or (litter.get("kinds") as Array).is_empty():
			errors.append("litter kinds is empty")
		else:
			for row in litter["kinds"]:
				errors.append_array(_kind_errors("litter", kinds, row.get("kind") if row is Dictionary else null, "*"))
				if not row is Dictionary or float(row.get("weight", 0.0)) <= 0.0:
					errors.append("litter kind weight is not positive")
	elif file.has("litter"):
		errors.append("litter is not an object")
	if file.has("ground_rows"):
		errors.append_array(_ground_row_errors(file["ground_rows"], park_map))
	if file.has("low_ground_rows"):
		errors.append_array(_low_ground_row_errors(file["low_ground_rows"], park_map))
	if file.get("ground_rows") is Array and file.get("low_ground_rows") is Array:
		for id in file["ground_rows"]:
			if id is String and (file["low_ground_rows"] as Array).has(id):
				errors.append("row %s is in both ground_rows and low_ground_rows; a ground row has no height cap, so list it in one" % id)
	return errors


const ROW_BAND_M := 1.5
const ROW_CV := 0.1
const ROW_GAP_MIN_M := 0.5
const ROW_GAP_MAX_M := 40.0
const YAW_LINK_M := 24.0
const YAW_LINK_DEG := 1.0

static func spot_pattern_errors(file: Dictionary) -> Array:
	var ids: Array = []
	var pts: Array = []
	var yaws: Array = []
	for spot in file.get("spots", []):
		if spot is Dictionary and _pair(spot.get("at")) != Vector2.INF:
			ids.append(String(spot.get("id", "")))
			pts.append(_pair(spot["at"]))
			yaws.append(float(spot.get("yaw_deg", 0.0)))
	var n := ids.size()
	var out := []
	var parent := []
	for i in n:
		parent.append(i)
	var in_row := {}
	var cvs := {}
	for i in n:
		for j in range(i + 1, n):
			var dir: Vector2 = pts[j] - pts[i]
			var span := dir.length()
			if span <= ROW_GAP_MIN_M or span > 2.0 * ROW_GAP_MAX_M:
				continue
			dir /= span
			var on := []
			for k in n:
				var rel: Vector2 = pts[k] - pts[i]
				if absf(rel.cross(dir)) <= ROW_BAND_M:
					on.append([rel.dot(dir), k])
			if on.size() < 3:
				continue
			on.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			for w in range(0, on.size() - 2):
				var g1: float = on[w + 1][0] - on[w][0]
				var g2: float = on[w + 2][0] - on[w + 1][0]
				if g1 <= ROW_GAP_MIN_M or g1 > ROW_GAP_MAX_M or g2 <= ROW_GAP_MIN_M or g2 > ROW_GAP_MAX_M:
					continue
				var mean := (g1 + g2) * 0.5
				var cv := sqrt(((g1 - mean) * (g1 - mean) + (g2 - mean) * (g2 - mean)) * 0.5) / mean
				if cv >= ROW_CV:
					continue
				var a: int = on[w][1]
				var b: int = on[w + 1][1]
				var d: int = on[w + 2][1]
				for k in [a, b, d]:
					in_row[k] = true
					cvs[k] = minf(float(cvs.get(k, INF)), cv)
				parent[_find(parent, b)] = _find(parent, a)
				parent[_find(parent, d)] = _find(parent, a)
	var groups := {}
	for k in in_row:
		var root := _find(parent, k)
		if not groups.has(root):
			groups[root] = []
		groups[root].append(k)
	for root in groups:
		var members: Array = groups[root]
		var names := members.map(func(k: int) -> String: return ids[k])
		names.sort()
		var best := INF
		for k in members:
			best = minf(best, float(cvs[k]))
		out.append({"rule": "row", "spots": names, "detail": "%d spots lie within %.1f m of a line with gap CV %.3f (under %.1f)" % [names.size(), ROW_BAND_M, best, ROW_CV]})
	var yparent := []
	for i in n:
		yparent.append(i)
	for i in n:
		for j in range(i + 1, n):
			var diff := fposmod(float(yaws[i]) - float(yaws[j]) + 180.0, 360.0) - 180.0
			if absf(diff) <= YAW_LINK_DEG and (pts[i] as Vector2).distance_to(pts[j]) <= YAW_LINK_M:
				yparent[_find(yparent, j)] = _find(yparent, i)
	var ygroups := {}
	for i in n:
		var root := _find(yparent, i)
		if not ygroups.has(root):
			ygroups[root] = []
		ygroups[root].append(i)
	for root in ygroups:
		var members: Array = ygroups[root]
		if members.size() < 3:
			continue
		var names := members.map(func(k: int) -> String: return ids[k])
		names.sort()
		out.append({"rule": "yaw", "spots": names, "detail": "%d spots within %.0f m chain share yaw %.0f degrees (within %.0f)" % [names.size(), YAW_LINK_M, float(yaws[members[0]]), YAW_LINK_DEG]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["rule"] != b["rule"]:
			return a["rule"] < b["rule"]
		return a["spots"][0] < b["spots"][0])
	return out


static func _find(parent: Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func label_lint(file: Dictionary) -> Array:
	var out := []
	var templates: Dictionary = file.get("templates", {}) if file.get("templates") is Dictionary else {}
	for spot in file.get("spots", []):
		if not spot is Dictionary or not spot.get("near") is String:
			continue
		var near := String(spot["near"])
		var id := String(spot.get("id", ""))
		if near != near.strip_edges():
			out.append({"rule": "label", "spot": id, "detail": "near has leading or trailing whitespace"})
		var template = templates.get(spot.get("template", ""))
		var story := String(template.get("story", "")) if template is Dictionary else ""
		if story.is_empty():
			continue
		var cut := _story_cut(near, story)
		if cut > 0:
			out.append({"rule": "label", "spot": id, "detail": "near is the template story cut mid-word at %d characters" % cut})
	return out


static func _story_cut(near: String, story: String) -> int:
	var lower_story := story.to_lower()
	for sep in [": ", ", "]:
		var from := 0
		while true:
			var at := near.find(sep, from)
			if at < 0:
				break
			from = at + 1
			var tail := near.substr(at + sep.length()).to_lower()
			if tail.is_empty() or tail.length() >= lower_story.length() or not lower_story.begins_with(tail):
				continue
			if _is_word_char(tail[tail.length() - 1]) and _is_word_char(lower_story[tail.length()]):
				return tail.length()
	return 0


static func _is_word_char(ch: String) -> bool:
	return ch.to_lower() != ch.to_upper() or (ch >= "0" and ch <= "9")


static func pin_error(file: Dictionary, fingerprint_value: int) -> String:
	if not file.has("pin"):
		return "no pin: pin %d" % fingerprint_value
	if int(file["pin"]) != fingerprint_value:
		return "fingerprint %d, file pins %d" % [fingerprint_value, int(file["pin"])]
	return ""


static func _low_ground_row_errors(ids, park_map) -> Array:
	if not ids is Array or (ids as Array).is_empty():
		return ["low_ground_rows is not a non-empty list of park row ids"]
	var errors := []
	var rows := {}
	var home_sites := {}
	if park_map != null:
		for row: Dictionary in park_map.park.get("park_rows", []):
			rows[row["id"]] = row
		for home: Dictionary in park_map.park.get("home_rows", []):
			home_sites[String(home.get("site", ""))] = true
	for id in ids:
		if not id is String:
			errors.append("low_ground_rows entry %s is not a row id" % str(id))
			continue
		if park_map == null:
			continue
		if not rows.has(id):
			errors.append("low_ground_rows names %s, which is no park row" % id)
			continue
		var row: Dictionary = rows[id]
		var element := String(row.get("element", ""))
		var width := absf(float(row["size"][2]))
		var length := absf(float(row["size"][0]))
		var home = row.get("home")
		if element not in LOW_GROUND_ELEMENTS:
			errors.append("low_ground_rows lists %s, a %s; only a flow_line, bowl, drop or sky_island can be low ground (narrow features never)" % [id, element])
		elif (home is String and not (home as String).is_empty()) or home_sites.has(id):
			if maxf(width, length) <= LOW_GROUND_HOME_MIN_M:
				errors.append("low_ground_rows lists %s, a home site %.0f by %.0f m; a home site must be longer than %.0f m" % [id, length, width, LOW_GROUND_HOME_MIN_M])
		elif minf(width, length) < LOW_GROUND_MIN_M:
			errors.append("low_ground_rows lists %s, %.0f by %.0f m; both axes must be at least %.0f m" % [id, length, width, LOW_GROUND_MIN_M])
	return errors


static func _ground_row_errors(ids, park_map) -> Array:
	if not ids is Array or (ids as Array).is_empty():
		return ["ground_rows is not a non-empty list of park row ids"]
	var errors := []
	var rows := {}
	if park_map != null:
		for row: Dictionary in park_map.park.get("park_rows", []):
			rows[row["id"]] = row
	var home_sites := {}
	if park_map != null:
		for home: Dictionary in park_map.park.get("home_rows", []):
			home_sites[String(home.get("site", ""))] = String(home.get("id", ""))
	for id in ids:
		if not id is String:
			errors.append("ground_rows entry %s is not a row id" % str(id))
		elif park_map != null and not rows.has(id):
			errors.append("ground_rows names %s, which is no park row" % id)
		elif park_map != null:
			var home = rows[id].get("home")
			if home is String and not (home as String).is_empty():
				errors.append("ground_rows lists %s, a row with a home (%s); a home row can never be a placement surface" % [id, home])
			elif home_sites.has(id):
				errors.append("ground_rows lists %s, the site of home %s; a home row can never be a placement surface" % [id, home_sites[id]])
	return errors


static func _kind_errors(label: String, kinds: Dictionary, kind, v) -> Array:
	if not kind is String or not kinds.has(kind):
		return ["%s names kind %s, which the kit lacks" % [label, str(kind)]]
	if String(v) != "*" and not (kinds[kind].get("variants", {}) as Dictionary).has(String(v)):
		return ["%s names variant %s of %s, which the kit lacks" % [label, str(v), kind]]
	return []


static func kit_errors(kit: Dictionary, min_kinds := 0, min_variants := 1) -> Array:
	var errors := []
	if kit.get("schema") != KIT_SCHEMA:
		errors.append("kit schema is not " + KIT_SCHEMA)
	var kinds = kit.get("kinds")
	if not kinds is Dictionary:
		return errors + ["kit has no kinds"]
	if (kinds as Dictionary).size() < min_kinds:
		errors.append("kit has %d kinds, want at least %d" % [(kinds as Dictionary).size(), min_kinds])
	for kind in kinds:
		var def = kinds[kind]
		if not def is Dictionary or not def.get("class") in [HERO, PROP]:
			errors.append("kind %s has no class dress_hero or dress_prop" % kind)
			continue
		if not def.get("tags") is Array:
			errors.append("kind %s has no tags" % kind)
		var brief := float(BRIEF_LINE_KINDS.get(kind, 0.0))
		if brief > 0.0 and not ((def.get("line_clear_m") is float or def.get("line_clear_m") is int) and float(def["line_clear_m"]) >= brief):
			errors.append("kind %s is a brief line kind and needs line_clear_m of at least %.0f" % [kind, brief])
		if def.has("line_clear_m"):
			var reach = def["line_clear_m"]
			if not (reach is float or reach is int) or float(reach) != float(reach) or float(reach) <= LINE_CLEAR_LOW_M or float(reach) > LINE_CLEAR_KIND_MAX_M:
				errors.append("kind %s line_clear_m %s is not a number above %.0f and at most %.0f" % [kind, str(reach), LINE_CLEAR_LOW_M, LINE_CLEAR_KIND_MAX_M])
		var variants = def.get("variants")
		if not variants is Dictionary or (variants as Dictionary).size() < min_variants:
			errors.append("kind %s has fewer than %d variants" % [kind, min_variants])
			continue
		for v in variants:
			var row = variants[v]
			var label := "%s/%s" % [kind, v]
			if not row is Dictionary or not row.get("lod") is Array or (row["lod"] as Array).size() != 3 or not row.get("tris") is Array or (row["tris"] as Array).size() != 3:
				errors.append(label + " lacks three lod paths and three tris")
				continue
			for path in row["lod"]:
				if not ResourceLoader.exists(String(path)):
					errors.append("%s lod %s does not exist" % [label, str(path)])
			if float(row.get("radius", 0.0)) <= 0.0 or float(row.get("height", 0.0)) <= 0.0:
				errors.append(label + " has no radius or height")
	return errors


static func expand(file: Dictionary, kit: Dictionary, park_map, ground: Callable, c: Context = null) -> Array:
	if c == null:
		c = context(park_map, ground)
	var out := []
	c.use_ground_rows(file.get("ground_rows"))
	c.use_low_ground_rows(file.get("low_ground_rows"))
	var id := String(file.get("map", ""))
	var templates: Dictionary = file.get("templates", {})
	var spots: Array = file.get("spots", [])
	for spot: Dictionary in spots:
		var template = templates.get(spot.get("template", ""))
		if not template is Dictionary:
			continue
		var origin := _pair(spot["at"])
		var spot_yaw := deg_to_rad(float(spot.get("yaw_deg", 0.0)))
		var props: Array = template.get("props", [])
		for i in props.size():
			var prop: Dictionary = props[i]
			var variants: Dictionary = kit["kinds"][prop["kind"]]["variants"]
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%s|%s|%d" % [id, spot["id"], i])
			var v := String(prop.get("v", "*"))
			if v == "*":
				var keys := variants.keys()
				keys.sort()
				v = String(keys[rng.randi() % keys.size()])
			var offset := Vector3(_pair(prop["at"]).x, 0.0, _pair(prop["at"]).y)
			var flat := Basis(Vector3.UP, spot_yaw) * offset
			out.append(_instance(String(spot["id"]), String(prop["kind"]), v, kit, Vector2(origin.x + flat.x, origin.y + flat.z),
				spot_yaw + deg_to_rad(float(prop.get("yaw_deg", 0.0))), float(prop.get("scale", 1.0)), deg_to_rad(float(prop.get("tilt_deg", 0.0))), ground, false))
	var litter = file.get("litter")
	if litter is Dictionary:
		out.append_array(_litter(litter, id, kit, c, ground, out))
	return out


static func _instance(vignette: String, kind: String, v: String, kit: Dictionary, at: Vector2, yaw: float, scale: float, tilt: float, ground: Callable, litter: bool) -> Dictionary:
	var def: Dictionary = kit["kinds"][kind]
	var row: Dictionary = def["variants"][v]
	var radius := float(row["radius"]) * scale
	var height := float(row["height"]) * scale
	var y := _height(ground, at)
	if radius > SMALL_RADIUS_M:
		for k in 4:
			y = minf(y, _height(ground, at + Vector2.from_angle(k * TAU / 4.0) * radius))
	var up := Vector3.UP
	if radius <= SMALL_RADIUS_M:
		var n := _normal(ground, at, 0.5)
		var lean := minf(acos(clampf(n.y, -1.0, 1.0)), deg_to_rad(ALIGN_MAX_DEG))
		var axis := Vector3.UP.cross(n)
		if lean > 0.0001 and axis.length() > 0.0001:
			up = Vector3.UP.rotated(axis.normalized(), lean)
	var basis := Basis(Vector3.UP, yaw)
	if absf(tilt) > 0.0:
		basis = basis * Basis(Vector3.RIGHT, tilt)
	if up != Vector3.UP:
		var axis := Vector3.UP.cross(up).normalized()
		basis = Basis(axis, acos(clampf(up.y, -1.0, 1.0))) * basis
	var floating := 0.0
	var steepest := rad_to_deg(acos(clampf(_normal(ground, at, clampf(radius * 0.5, 0.5, 2.0)).y, -1.0, 1.0)))
	var span := clampf(radius * 0.5, 0.5, 2.0)
	if radius > SMALL_RADIUS_M:
		for k in 8:
			var rim := at + Vector2.from_angle(k * TAU / 8.0) * radius
			floating = maxf(floating, y - _height(ground, rim))
			steepest = maxf(steepest, rad_to_deg(acos(clampf(_normal(ground, rim, span).y, -1.0, 1.0))))
	return {"vignette": vignette, "kind": kind, "v": v, "class": String(def["class"]), "tags": (def.get("tags", []) as Array).duplicate(),
		"pos": Vector3(at.x, y, at.y), "basis": basis, "scale": scale, "radius": radius, "height": height, "litter": litter,
		"float_m": floating, "slope_deg": steepest, "line_clear_m": float(def.get("line_clear_m", 0.0))}


static func _height(ground: Callable, at: Vector2) -> float:
	return (ground.call(at.x, at.y, 0.0) as Vector3).y


static func _normal(ground: Callable, at: Vector2, span: float) -> Vector3:
	var dx := _height(ground, at + Vector2(span, 0.0)) - _height(ground, at - Vector2(span, 0.0))
	var dz := _height(ground, at + Vector2(0.0, span)) - _height(ground, at - Vector2(0.0, span))
	return Vector3(-dx, 2.0 * span, -dz).normalized()


static func _litter(litter: Dictionary, id: String, kit: Dictionary, c: Context, ground: Callable, props: Array = []) -> Array:
	var out := []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|litter|%d" % [id, int(litter.get("seed", 0))])
	var spacing := float(litter["spacing_m"])
	var band: Array = litter["band_m"]
	var kinds: Array = litter["kinds"]
	var total := 0.0
	for row: Dictionary in kinds:
		total += float(row["weight"])
	var placed: Array[Vector2] = []
	var feet := _feet(props)
	for key in c.lines:
		var pts: PackedVector2Array = c.lines[key]
		var carried := rng.randf_range(0.0, spacing)
		for i in range(1, pts.size()):
			var along := (pts[i] - pts[i - 1])
			var length := along.length()
			if length < 0.001:
				continue
			var dir := along / length
			var side_dir := Vector2(-dir.y, dir.x)
			var d := spacing - carried if carried > 0.0 else spacing
			while d <= length:
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var lateral := rng.randf_range(float(band[0]), float(band[1]))
				var pick := rng.randf() * total
				var vr := rng.randi()
				var yaw := rng.randf_range(0.0, TAU)
				var scale := rng.randf_range(LITTER_SCALE_MIN, LITTER_SCALE_MAX)
				var at := pts[i - 1] + dir * d + side_dir * side * lateral
				d += spacing
				var kind := String((kinds[0] as Dictionary)["kind"])
				var acc := 0.0
				for row: Dictionary in kinds:
					acc += float(row["weight"])
					if pick <= acc:
						kind = String(row["kind"])
						break
				if placed.any(func(other: Vector2) -> bool: return other.distance_to(at) < spacing * LITTER_GAP_RATIO):
					continue
				var variants: Dictionary = kit["kinds"][kind]["variants"]
				var names := variants.keys()
				names.sort()
				var inst := _instance("litter", kind, String(names[vr % names.size()]), kit, at, yaw, scale, 0.0, ground, true)
				if not check_one(inst, c).is_empty():
					continue
				if _meets(feet, at, float(inst["radius"])):
					continue
				placed.append(at)
				out.append(inst)
			carried = fmod(carried + length, spacing)
	return out


static func _feet(props: Array) -> Dictionary:
	var cells := {}
	var widest := 0.0
	for prop: Dictionary in props:
		var at := Vector2(prop["pos"].x, prop["pos"].z)
		var cell := Vector2i(floori(at.x / LITTER_FOOT_CELL_M), floori(at.y / LITTER_FOOT_CELL_M))
		cells[cell] = (cells.get(cell, []) as Array) + [[at, float(prop["radius"])]]
		widest = maxf(widest, float(prop["radius"]))
	return {"cells": cells, "widest": widest}


static func _meets(feet: Dictionary, at: Vector2, radius: float) -> bool:
	var cells: Dictionary = feet["cells"]
	if cells.is_empty():
		return false
	var span := ceili((float(feet["widest"]) + radius) / LITTER_FOOT_CELL_M)
	var home := Vector2i(floori(at.x / LITTER_FOOT_CELL_M), floori(at.y / LITTER_FOOT_CELL_M))
	for dj in range(-span, span + 1):
		for di in range(-span, span + 1):
			for foot: Array in cells.get(home + Vector2i(di, dj), []):
				if (foot[0] as Vector2).distance_to(at) < float(foot[1]) + radius:
					return true
	return false


static func validate(list: Array, park_map, ground: Callable, stage := -1, c: Context = null) -> Array:
	if c == null:
		c = context(park_map, ground, stage)
	var out := []
	for inst: Dictionary in list:
		out.append_array(check_one(inst, c))
	return out


static func check_one(inst: Dictionary, c: Context) -> Array:
	var out := []
	var pos: Vector3 = inst["pos"]
	var p := Vector2(pos.x, pos.z)
	var r: float = inst["radius"]
	var height: float = inst["height"]
	var hero: bool = inst["class"] == HERO
	var tall: bool = tier_of(inst) == "tall"
	var fail := func(rule: String, detail: String) -> void:
		out.append({"vignette": inst["vignette"], "kind": inst["kind"], "pos": pos, "rule": rule, "detail": detail})
	var edge := c.line_distance(p) - r
	var tier_need := LINE_CLEAR_TALL_M if tall else (LINE_CLEAR_MID_M if height > LOW_HEIGHT_M else LINE_CLEAR_LOW_M)
	var kind_need := float(inst.get("line_clear_m", 0.0))
	var need := maxf(tier_need, kind_need)
	if need + r > LINE_REACH_M:
		fail.call("line_clear", "rule beyond the line reach (need + radius > %.0f m)" % LINE_REACH_M)
	elif edge < need:
		if kind_need > tier_need:
			fail.call("line_clear", "kind %s, %.1f m from a line, want %.0f" % [inst["kind"], edge, need])
		else:
			fail.call("line_clear", "%s, %.1f m from a line, want %.0f" % ["tall or hero" if tall else ("mid" if height > LOW_HEIGHT_M else "low"), edge, need])
	for ev: Dictionary in c.events:
		var grown: float = float(ev["hold"]) + r
		var hit := false
		var site_at := _pair(ev["site"]["at"])
		if ev["box"]:
			hit = ParkMap.footprint_contains(ev["site"], p, grown, Vector2.INF, ev["half"])
		if float(ev["strike"]) >= 0.0 and site_at.distance_to(p) < float(ev["strike"]) + grown:
			hit = true
		if float(ev["hazard"]) >= 0.0 and site_at.distance_to(p) < float(ev["hazard"]) + grown:
			hit = true
		if hit:
			fail.call("telegraph", "inside event %s hold zone (%s grown %.0f m)" % [ev["id"], ev["site"].get("id", "?"), ev["hold"]])
	if tall and ParkRecipes.in_clear(c.lanes, p, r):
		fail.call("route_lane", "tall, inside a route lane")
	if tall:
		for row: Dictionary in c.scatter_rows:
			if ParkMap.footprint_contains(row, p, r):
				fail.call("scatter_row", "tall or hero inside scatter-dressed row %s" % row.get("id", "?"))
				break
	if not c.rect.grow(-r).has_point(p):
		fail.call("play_rect", "outside the play rect")
	else:
		var margin := clampf(r + ParkSites.MARGIN, ParkSites.MARGIN, ParkSites.MARGIN_MAX)
		var low := height <= LOW_GROUND_MAX_M + 0.0001
		var what := c.keepout_at(p, margin, true)
		if what != "":
			fail.call("keepout", "within %.1f m of %s" % [margin, what])
		elif not low:
			for row: Dictionary in c.low_rows.values():
				if ParkMap.footprint_contains(row, p, margin):
					fail.call("low_ground", "%.2f m tall inside low_ground_rows row %s, want at most %.1f" % [height, row.get("id", "?"), LOW_GROUND_MAX_M])
					break
	for home: Dictionary in c.homes:
		var row: Dictionary = home["row"]
		var near := false
		if not row.has("point") and c.low_rows.has(row.get("id")):
			continue
		if row.has("point"):
			near = _pair(row["at"]).distance_to(p) < HOME_CLEAR_M + r
		else:
			near = ParkMap.footprint_contains(row, p, HOME_CLEAR_M + r)
		if near:
			fail.call("home_clear", "within %.0f m of home %s" % [HOME_CLEAR_M, home["id"]])
	for camp in c.camps:
		if camp.distance_to(p) < HOME_CLEAR_M + r:
			fail.call("home_clear", "within %.0f m of an enemy camp" % HOME_CLEAR_M)
	if not c.ground_rows.is_empty():
		var inside := false
		var surfaces: Array = c.ground_rows.values()
		if height <= LOW_GROUND_MAX_M + 0.0001:
			surfaces = surfaces + c.low_rows.values()
		for row: Dictionary in surfaces:
			var half := ParkMap.footprint_half_extents(row) - Vector2.ONE * (GROUND_ROW_INSET_M + r)
			if half.x >= 0.0 and half.y >= 0.0 and ParkMap.footprint_contains(row, p, 0.0, Vector2.INF, half):
				inside = true
				break
		if not inside:
			fail.call("ground_row", "outside every listed ground row, or within %.0f m of its edge" % GROUND_ROW_INSET_M)
	var slope := float(inst["slope_deg"])
	if slope > SLOPE_MAX_DEG:
		fail.call("slope", "%.1f degrees under the footprint, want at most %.0f" % [slope, SLOPE_MAX_DEG])
	var floating := float(inst["float_m"])
	if floating > SEAT_FLOAT_MAX_M:
		fail.call("seat", "%.2f m floats off the ground, want at most %.2f" % [floating, SEAT_FLOAT_MAX_M])
	return out


static func fingerprint(list: Array) -> int:
	return hash(var_to_bytes(fingerprint_parts(list)))


static func fingerprint_parts(list: Array) -> Array:
	var parts := []
	for inst: Dictionary in list:
		parts.append([inst["vignette"], inst["kind"], inst["v"], inst["pos"], inst["basis"], inst["scale"]])
	return parts


static func build_nodes(list: Array, kit: Dictionary, low := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Content"
	for job: Dictionary in jobs(list, low):
		build_job(root, job, kit, low)
	return root


static func jobs(list: Array, low := false) -> Array:
	var by_vignette := {}
	var out := []
	var litter := []
	for inst: Dictionary in list:
		if inst["litter"]:
			litter.append(inst)
			continue
		if not by_vignette.has(inst["vignette"]):
			by_vignette[inst["vignette"]] = {"name": "Vignette_" + String(inst["vignette"]), "members": [], "litter": false}
			out.append(by_vignette[inst["vignette"]])
		by_vignette[inst["vignette"]]["members"].append(inst)
	if not litter.is_empty() and not low:
		out.append({"name": "Litter", "members": litter, "litter": true})
	return out


static func build_job(parent: Node3D, job: Dictionary, kit: Dictionary, low: bool) -> Node3D:
	var holder := new_holder(parent, job)
	for step: Array in job_steps(job, kit, low):
		(step[1] as Callable).call(holder)
	return holder


static func new_holder(parent: Node3D, job: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = job["name"]
	parent.add_child(holder)
	return holder


static func job_steps(job: Dictionary, kit: Dictionary, low: bool) -> Array:
	var steps := []
	var groups := {}
	var keys := []
	var far_members := []
	for inst: Dictionary in job["members"]:
		if inst["class"] == HERO:
			steps.append(["hero", func(holder: Node3D): _hero(holder, inst, kit)])
			continue
		var pos: Vector3 = inst["pos"]
		var key := "%s_%s" % [inst["kind"], inst["v"]]
		if job["litter"]:
			key = "%d_%d_%s" % [floori(pos.x / LITTER_CHUNK_M), floori(pos.z / LITTER_CHUNK_M), key]
		if not groups.has(key):
			groups[key] = []
			keys.append(key)
		groups[key].append(inst)
	var far_paths := []
	for key in keys:
		var members: Array = groups[key]
		var first: Dictionary = members[0]
		var lods := _lod_paths(kit, first)
		if job["litter"]:
			steps.append(["litter", func(holder: Node3D): _batch(holder, "Litter_" + String(key), _mesh(lods[1]), members, first, 1, LITTER_RANGE, PROP_MARGIN_M, true)])
			continue
		for lod in 2:
			steps.append(["batch", func(holder: Node3D): _batch(holder, "%s_L%d" % [key, lod], _mesh(lods[lod]), members, first, lod, _range(PROP_RANGES[lod], low, lod), PROP_MARGIN_M, false)])
		far_members.append_array(members)
		if not lods[2] in far_paths:
			far_paths.append(lods[2])
	for path: String in far_paths:
		steps.append(["read", func(_h: Node3D): _far_source(path)])
	if not far_members.is_empty():
		var merge := FarMerge.new(far_members)
		for start in range(0, far_members.size(), MERGE_CHUNK):
			var chunk := far_members.slice(start, start + MERGE_CHUNK)
			steps.append(["merge", func(_h: Node3D): _merge_far(merge, chunk, kit)])
		steps.append(["upload", func(holder: Node3D): _merged_far(holder, merge, far_members[0], _range(PROP_RANGES[2], low, 2))])
	return steps


static func mesh_paths(list: Array, kit: Dictionary, low: bool) -> Array:
	var paths := []
	var seen := {}
	for inst: Dictionary in list:
		var lods := _lod_paths(kit, inst)
		var wanted: Array = ([] if low else [lods[1]]) if inst["litter"] else lods
		for path: String in wanted:
			if not seen.has(path):
				seen[path] = true
				paths.append(path)
	return paths


static func prepare(id: String, park_map, ground: Callable, stage: int, low: bool) -> Dictionary:
	var file := load_json(file_path(id))
	if file.is_empty():
		return {}
	var kit := load_json(String(file.get("kit", "")))
	var errors := kit_errors(kit) + file_errors(file, kit, park_map)
	if not errors.is_empty():
		return {"errors": errors}
	var list := expand(file, kit, park_map, ground, context(park_map, ground, stage))
	return {"kit": kit, "list": list, "paths": mesh_paths(list, kit, low), "errors": []}


static func _range(base: Array, low: bool, lod: int) -> Array:
	if not low:
		return base
	var end := float(base[1]) * LOW_RANGE_SCALE if lod < 2 else float(base[1])
	var begin := 0.0 if lod == 0 else float(PROP_RANGES[lod - 1][1]) * LOW_RANGE_SCALE - PROP_MARGIN_M
	return [begin, end]


static func levels(hero: bool, low := false) -> Array:
	var out := []
	for lod in 3:
		var span: Array = HERO_RANGES[lod] if hero else _range(PROP_RANGES[lod], low, lod)
		out.append([float(span[0]), float(span[1]), 0.0, HERO_MARGIN_M if hero else PROP_MARGIN_M])
	return out


static func _lod_paths(kit: Dictionary, inst: Dictionary) -> Array:
	var variants: Dictionary = kit["kinds"][inst["kind"]]["variants"]
	return _stand_in(variants, String(inst["v"])) if ModelVariants.enabled() else variants[inst["v"]]["lod"]


const STAND_IN_RADIUS := 1.1
const STAND_IN_HEIGHT := 0.15
static var _stand_ins := {}
static var _stand_ins_stamp := -1
static var _stand_ins_lock := Mutex.new()


static func _stand_in(variants: Dictionary, v: String) -> Array:
	var own: Dictionary = variants[v]
	var key := String(own["lod"][0])
	_stand_ins_lock.lock()
	if _stand_ins_stamp != ModelVariants.stamp():
		_stand_ins.clear()
		_stand_ins_stamp = ModelVariants.stamp()
	if not _stand_ins.has(key):
		_stand_ins[key] = _find_stand_in(variants, v)
	var found: Array = _stand_ins[key]
	_stand_ins_lock.unlock()
	return found


static func _find_stand_in(variants: Dictionary, v: String) -> Array:
	var own: Dictionary = variants[v]
	if _all_generated(own["lod"]):
		return own["lod"]
	var keys := variants.keys()
	keys.sort()
	for key in keys:
		var sister: Dictionary = variants[key]
		if key == v or not _all_generated(sister["lod"]):
			continue
		if float(sister["radius"]) <= float(own["radius"]) * STAND_IN_RADIUS \
				and absf(float(sister["height"]) - float(own["height"])) <= float(own["height"]) * STAND_IN_HEIGHT:
			return sister["lod"]
	return own["lod"]


static func _all_generated(lods: Array) -> bool:
	for lod in lods:
		if ModelVariants.path(String(lod)) == String(lod):
			return false
	return true


static func _hero(holder: Node3D, inst: Dictionary, kit: Dictionary) -> void:
	var lods := _lod_paths(kit, inst)
	var tr := _transform(inst)
	for lod in 3:
		var mesh := _mesh(lods[lod])
		if mesh == null:
			continue
		var view := MeshInstance3D.new()
		view.name = "%s_%d_L%d" % [inst["kind"], holder.get_child_count(), lod]
		view.mesh = mesh
		view.transform = tr
		_ranges(view, HERO_RANGES[lod], HERO_MARGIN_M)
		_tag(view, inst, lod, lod == 0)
		holder.add_child(view)


static func _batch(holder: Node3D, label: String, mesh: Mesh, members: Array, first: Dictionary, lod: int, begin_end: Array, margin: float, litter: bool) -> void:
	if mesh == null:
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = members.size()
	var centre := Vector3.ZERO
	for i in members.size():
		multi.set_instance_transform(i, _transform(members[i]))
		centre += (members[i]["pos"] as Vector3) / members.size()
	var view := MultiMeshInstance3D.new()
	view.name = label
	view.multimesh = multi
	var spread := 0.0
	if litter:
		for member: Dictionary in members:
			spread = maxf(spread, (member["pos"] as Vector3).distance_to(centre))
	_ranges(view, [begin_end[0], float(begin_end[1]) + spread], margin)
	_tag(view, first, lod, false)
	view.set_meta("dress_count", members.size())
	# Godot headless Dummy renderer keeps no MultiMesh transforms for readback.
	view.set_meta("dress_members", members)
	holder.add_child(view)


static func _merged_far(holder: Node3D, merge: FarMerge, first: Dictionary, begin_end: Array) -> void:
	if merge.vertices.is_empty():
		return
	var built := []
	built.resize(Mesh.ARRAY_MAX)
	built[Mesh.ARRAY_VERTEX] = merge.vertices
	built[Mesh.ARRAY_NORMAL] = merge.normals
	built[Mesh.ARRAY_COLOR] = merge.colours
	built[Mesh.ARRAY_INDEX] = merge.indices
	var merged := ArrayMesh.new()
	merged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, built)
	var view := MeshInstance3D.new()
	view.name = "Far_L2"
	view.mesh = merged
	view.position = merge.centre
	_ranges(view, begin_end, PROP_MARGIN_M)
	_tag(view, first, 2, false)
	view.set_meta("dress_tier", "merged")
	view.set_meta("dress_count", merge.positions.size())
	view.set_meta("dress_member_pos", merge.positions)
	view.set_meta("dress_member_kinds", merge.kinds)
	holder.add_child(view)


class FarMerge extends RefCounted:
	var centre := Vector3.ZERO
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var positions := PackedVector3Array()
	var kinds := PackedStringArray()

	func _init(members: Array) -> void:
		for inst: Dictionary in members:
			centre += (inst["pos"] as Vector3) / members.size()


static func _merge_far(merge: FarMerge, members: Array, kit: Dictionary) -> void:
	for inst: Dictionary in members:
		var source := _far_source(_lod_paths(kit, inst)[2])
		if source.is_empty():
			continue
		var src_v: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var src_n = source[Mesh.ARRAY_NORMAL]
		var src_c = source[Mesh.ARRAY_COLOR]
		var src_i = source[Mesh.ARRAY_INDEX]
		var base := merge.vertices.size()
		merge.vertices.append_array(Transform3D(Basis.IDENTITY, -merge.centre) * (_transform(inst) * src_v))
		var normals: PackedVector3Array
		if src_n != null:
			normals = Transform3D(inst["basis"] as Basis, Vector3.ZERO) * (src_n as PackedVector3Array)
		else:
			normals.resize(src_v.size())
			normals.fill((inst["basis"] as Basis) * Vector3.UP)
		for k in normals.size():
			normals[k] = normals[k].normalized()
		merge.normals.append_array(normals)
		if src_c != null:
			merge.colours.append_array(src_c)
		else:
			var white := PackedColorArray()
			white.resize(src_v.size())
			white.fill(Color.WHITE)
			merge.colours.append_array(white)
		var at := merge.indices.size()
		merge.indices.append_array(src_i)
		for k in range(at, merge.indices.size()):
			merge.indices[k] += base
		merge.positions.append(inst["pos"])
		merge.kinds.append(String(inst["kind"]))


static func _far_source(path: String) -> Array:
	if _far_sources.has(path):
		return _far_sources[path]
	var out := []
	var mesh := _mesh(path)
	if mesh != null and mesh.get_surface_count() > 0:
		far_reads += 1
		var arrays := mesh.surface_get_arrays(0)
		if not (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty() and arrays[Mesh.ARRAY_INDEX] != null:
			out = arrays
	_far_sources[path] = out
	return out


static func _ranges(view: GeometryInstance3D, begin_end: Array, margin: float) -> void:
	view.visibility_range_begin = begin_end[0]
	view.visibility_range_end = begin_end[1]
	view.visibility_range_begin_margin = 0.0
	view.visibility_range_end_margin = margin
	view.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func _tag(view: GeometryInstance3D, inst: Dictionary, lod: int, shadow: bool) -> void:
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	style_view(view)
	view.add_to_group(GROUP)
	view.set_meta("dress_kind", inst["kind"])
	view.set_meta("dress_class", inst["class"])
	view.set_meta("dress_lod", lod)
	view.set_meta("dress_tier", tier_of(inst))


static func tier_of(inst: Dictionary) -> String:
	var height := float(inst["height"])
	if inst["class"] == HERO or height > TALL_HEIGHT_M or "tall" in inst["tags"]:
		return "tall"
	return "mid" if height > LOW_HEIGHT_M else "low"


static func _transform(inst: Dictionary) -> Transform3D:
	return PropKicks.place_of(inst)


static func _mesh(path: String) -> Mesh:
	if not ThreadGuard.main_only("park_props mesh " + path):
		return null
	if _meshes.has(path):
		return _meshes[path]
	var mesh: Mesh = null
	var packed = ResourceLoader.load_threaded_get(_requested[path]) if _requested.has(path) else load(ModelVariants.path(path))
	_requested.erase(path)
	if packed is PackedScene:
		var scene: Node = (packed as PackedScene).instantiate()
		var view: MeshInstance3D = scene as MeshInstance3D
		if view == null:
			var found := scene.find_children("*", "MeshInstance3D", true, false)
			view = found[0] if not found.is_empty() else null
		if view != null:
			mesh = view.mesh
		scene.free()
	_meshes[path] = mesh
	return mesh


# Godot imports glTF COLOR_0 with an albedo-white material that ignores vertex color; copying meshes stalls on renderer readback.
static func style_view(view: GeometryInstance3D) -> void:
	view.material_override = _vertex_material()


static func colour_errors(mesh: Mesh, label := "mesh", view: GeometryInstance3D = null) -> Array:
	var errors := []
	if mesh == null or mesh.get_surface_count() == 0:
		return [label + " has no surface"]
	var override := view.material_override if view != null else null
	for surface in mesh.get_surface_count():
		if not mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
			errors.append("%s surface %d has no ARRAY_COLOR" % [label, surface])
		var material: Material = override if override != null else mesh.surface_get_material(surface)
		if not material is BaseMaterial3D or not (material as BaseMaterial3D).vertex_color_use_as_albedo:
			errors.append("%s surface %d material does not use vertex colour as albedo" % [label, surface])
	return errors


static func _vertex_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = false
		_material.roughness = 0.8
		_material.metallic = 0.0
	return _material


static func release_shared() -> void:
	for path: String in _requested:
		ResourceLoader.load_threaded_get(_requested[path])
	_requested.clear()
	_meshes.clear()
	_far_sources.clear()
	_material = null
	_cache_owner = ""


func setup(context_in) -> void:
	ctx = context_in
	name = "ParkProps"
	ctx.events.stage_entered.connect(_stage_entered)
	ctx.events.stage_content_cleared.connect(_clear_stage)
	if ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	else:
		_pending = true


func _kick(delta: float) -> void:
	if not visible or instances.is_empty() or not is_built() or ctx.player == null or ctx.player.frozen():
		return
	if not kicks.indexed:
		_ground = ctx.terrain.ground_callable(ctx.terrain.stage)
		kicks.index(instances, func(inst: Dictionary): return inst["class"] != HERO and tier_of(inst) != "tall", views.filter(func(v): return v is MultiMeshInstance3D))
	var height := func(x: float, z: float) -> float: return (_ground.call(x, z, 0.0) as Vector3).y
	for kick: Dictionary in kicks.step(delta, ctx.player.shown_position(), ctx.player.state.velocity, Tuning.RADIUS, height):
		prop_kicked.emit(kick["at"], kick["mode"], kick["speed"], kick["tags"])


func _process(_delta: float) -> void:
	var started := Time.get_ticks_usec()
	last_steps = PackedStringArray()
	if not _dying.is_empty():
		_reap(FREE_SLICE_USEC)
	if _pending and ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		_take()
	if not _reads.is_empty():
		_read_meshes(BUILD_SLICE_USEC)
	elif not _jobs.is_empty():
		_slice(BUILD_SLICE_USEC)
	elif _task < 0 and not _pending:
		_prepare_next()
	_kick(_delta)
	last_process_usec = Time.get_ticks_usec() - started
	last_process_frame = Engine.get_process_frames()


func _reap(budget_usec: int) -> void:
	var deadline := Time.get_ticks_usec() + budget_usec
	while not _dying.is_empty() and Time.get_ticks_usec() < deadline:
		var node: Node = _dying.back()
		while node.get_child_count() > 0:
			node = node.get_child(node.get_child_count() - 1)
		if node == _dying.back():
			_dying.pop_back()
		node.free()


func is_built() -> bool:
	return _task < 0 and _reads.is_empty() and _jobs.is_empty() and not _pending


func finish() -> void:
	if _pending and ctx.terrain.is_ready(ctx.terrain.stage):
		_build_stage()
	if _task >= 0:
		_take()
	while not _reads.is_empty():
		_mesh(_reads.pop_front())
	_slice(1 << 40)


func _stage_entered(_stage: int, _retry: bool) -> void:
	var started := Time.get_ticks_usec()
	_build_stage()
	last_entry_usec = Time.get_ticks_usec() - started


func _clear_stage(_reason: String) -> void:
	visible = false


func _exit_tree() -> void:
	_free_views()
	if not _next.is_empty():
		WorkerThreadPool.wait_for_task_completion(_next.task)
		_next = {}
	_next_meshes = []
	_next_reads = []


func _free_views() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	_out = {}
	_reads = []
	_jobs = []
	_holder = null
	_steps = []
	for child in get_children():
		if _dying.has(child):
			continue
		child.name = "Freed%s" % child.name
		child.visible = false
		child.process_mode = Node.PROCESS_MODE_DISABLED
		_dying.append(child)
	views.clear()
	kicks.clear()
	instances = []
	_built_for = []
	map_id = ""


func _build_stage() -> void:
	_pending = false
	var stage: int = ctx.terrain.stage
	var map = ctx.terrain.map_for(stage)
	if not ParkSites.is_park(map) or not FileAccess.file_exists(file_path(String(map.park.get("map", "")))):
		_free_views()
		return
	var id := String(map.park["map"])
	var low: bool = Preset.current == LOW_PRESET
	var key := _key(stage)
	visible = true
	if key == _built_for:
		return
	_free_views()
	map_id = id
	_built_for = key
	_low = low
	if not _next.is_empty() and _next.key == key:
		_task = _next.task
		_out = _next.out
		_next = {}
		_next_meshes = []
		_next_reads = []
		return
	var out := {}
	_out = out
	var ground: Callable = ctx.terrain.ground_callable(stage)
	_task = WorkerThreadPool.add_task(func(): out.merge(prepare(id, map, ground, stage, low)), false, "park props plan")


func _take() -> void:
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	var out := _out
	_out = {}
	if out.is_empty() or not out["errors"].is_empty():
		push_warning("park_props: %s has no usable vignette file or kit: %s" % [map_id, str(out.get("errors", []))])
		return
	instances = out["list"]
	_kit = out["kit"]
	var next_out: Dictionary = _next.out if not _next.is_empty() and _next.listed else {}
	_keep_cached(instances, _kit, next_out)
	_cache_owner = map_id
	_jobs = jobs(instances, _low)
	_reads = _uncached(out["paths"])


# Godot headless Dummy rasterizer mesh RIDs are not thread-safe; load on main thread when headless.
static func _uncached(paths: Array) -> Array:
	var out := paths.filter(func(path: String): return not _meshes.has(path))
	if not AppShell.headless():
		for path: String in out:
			var source := ModelVariants.path(path)
			if not _requested.has(path) and ResourceLoader.load_threaded_request(source) == OK:
				_requested[path] = source
	return out


func _read_meshes(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while not _reads.is_empty():
		var path: String = _reads[0]
		if _requested.has(path) and ResourceLoader.load_threaded_get_status(_requested[path]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		_reads.pop_front()
		var read_started := Time.get_ticks_usec()
		_mesh(path)
		last_steps.append("mesh %.1f" % ((Time.get_ticks_usec() - read_started) / 1000.0))
		if Time.get_ticks_usec() - started >= budget_usec:
			return


func _key(stage: int) -> Array:
	return [stage, String(ctx.terrain.map_for(stage).park["map"]), Preset.current == LOW_PRESET, ctx.terrain.geometry_root(stage).get_instance_id()]


func _next_key() -> Array:
	var terrain = ctx.terrain
	if not "maps" in terrain:
		return []
	var next: int = terrain.stage + 1
	if next > terrain.maps.size() or not terrain.is_ready(next):
		return []
	var map = terrain.map_for(next)
	if not ParkSites.is_park(map) or not FileAccess.file_exists(file_path(String(map.park.get("map", "")))):
		return []
	return _key(next)


func _prepare_next() -> void:
	var key := _next_key()
	if _next.is_empty() or _next.key != key:
		_next_meshes = []
		_next_reads = []
	if not _next_meshes.is_empty():
		var path: String = _next_meshes[0]
		if _requested.has(path) and ResourceLoader.load_threaded_get_status(_requested[path]) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		var started := Time.get_ticks_usec()
		_mesh(_next_meshes.pop_front())
		last_steps.append("mesh %.1f" % ((Time.get_ticks_usec() - started) / 1000.0))
		return
	if not _next_reads.is_empty():
		var started := Time.get_ticks_usec()
		_far_source(_next_reads.pop_back())
		last_steps.append("pre-read %.1f" % ((Time.get_ticks_usec() - started) / 1000.0))
		return
	if not _next.is_empty():
		if _next.key != key:
			if WorkerThreadPool.is_task_completed(_next.task):
				WorkerThreadPool.wait_for_task_completion(_next.task)
				_next = {}
		elif not _next.listed and WorkerThreadPool.is_task_completed(_next.task):
			_next.listed = true
			var planned: Dictionary = _next.out
			if not planned.is_empty() and planned["errors"].is_empty():
				_next_meshes = _uncached(planned["paths"])
				_next_reads = far_paths(planned["list"], planned["kit"])
		return
	if key.is_empty() or key == _built_for:
		return
	var stage: int = key[0]
	var id: String = key[1]
	var low: bool = key[2]
	var map = ctx.terrain.map_for(stage)
	var ground: Callable = ctx.terrain.ground_callable(stage)
	var out := {}
	_next = {"key": key, "out": out, "listed": false,
		"task": WorkerThreadPool.add_task(func(): out.merge(prepare(id, map, ground, stage, low)), false, "park props next plan")}


func next_read(stage: int) -> bool:
	return not _next.is_empty() and int(_next.key[0]) == stage and _next.listed and _next_meshes.is_empty() and _next_reads.is_empty()


static func far_paths(list: Array, kit: Dictionary) -> Array:
	var seen := {}
	for inst: Dictionary in list:
		if not inst["litter"] and inst["class"] != HERO:
			seen[_lod_paths(kit, inst)[2]] = true
	return seen.keys()


static func _keep_cached(list: Array, kit: Dictionary, next_out: Dictionary) -> void:
	var keep := {}
	for inst: Dictionary in list:
		for path in _lod_paths(kit, inst):
			keep[path] = true
	if not next_out.is_empty() and next_out["errors"].is_empty():
		for inst: Dictionary in next_out["list"]:
			for path in _lod_paths(next_out["kit"], inst):
				keep[path] = true
	for path in _meshes.keys():
		if not keep.has(path):
			_meshes.erase(path)
	for path in _far_sources.keys():
		if not keep.has(path):
			_far_sources.erase(path)


func _slice(budget_usec: int) -> void:
	var started := Time.get_ticks_usec()
	while not _jobs.is_empty():
		if _holder == null:
			_holder = new_holder(self, _jobs[0])
			_steps = job_steps(_jobs[0], _kit, _low)
		var before := _holder.get_child_count()
		var step: Array = _steps.pop_front()
		var step_started := Time.get_ticks_usec()
		(step[1] as Callable).call(_holder)
		last_steps.append("%s %.1f" % [step[0], (Time.get_ticks_usec() - step_started) / 1000.0])
		for i in range(before, _holder.get_child_count()):
			views.append(_holder.get_child(i))
		if _steps.is_empty():
			_jobs.pop_front()
			_holder = null
		if Time.get_ticks_usec() - started >= budget_usec:
			break
