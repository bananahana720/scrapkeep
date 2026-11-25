extends SceneTree


const ParkProps := preload("res://src/presentation/park_props.gd")

const TIERS := {
	"low": {"band": [6.0, 30.0], "radius": 4.0, "height": 1.0, "tags": []},
	"mid": {"band": [10.0, 45.0], "radius": 6.0, "height": 2.0, "tags": []},
	"tall": {"band": [20.0, 64.0], "radius": 12.0, "height": 5.0, "tags": ["tall"]},
}
var tier := "tall"
var VIGNETTE_RADIUS_M := 12.0
var VIGNETTE_HEIGHT_M := 1.0
var LINE_BAND_M := [20.0, 64.0]
const MAX_SLOPE_DEG := 15.0
const SPACING_M := 60.0
const BENCH_VIGNETTES := 60
const GRID_M := 10.0
const SKIP_ELEMENTS := ["ground", "anchor_field"]


func _initialize() -> void:
	var map_id := ""
	var line_key := "floor"
	var check := false
	var file_arg := ""
	var bench := false
	var ground_rows_arg := ""
	var low_rows_arg := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			map_id = arg.trim_prefix("--map=")
		elif arg.begins_with("--line="):
			line_key = arg.trim_prefix("--line=")
		elif arg.begins_with("--file="):
			file_arg = arg.trim_prefix("--file=")
		elif arg.begins_with("--ground-rows="):
			ground_rows_arg = arg.trim_prefix("--ground-rows=")
		elif arg.begins_with("--low-ground-rows="):
			low_rows_arg = arg.trim_prefix("--low-ground-rows=")
		elif arg == "--bench":
			bench = true
		elif arg.begins_with("--tier="):
			tier = arg.trim_prefix("--tier=")
		elif arg == "--check":
			check = true
	if not TIERS.has(tier):
		push_error("park_props_plan: --tier is one of %s" % str(TIERS.keys()))
		quit(2)
		return
	VIGNETTE_RADIUS_M = TIERS[tier]["radius"]
	VIGNETTE_HEIGHT_M = TIERS[tier]["height"]
	LINE_BAND_M = TIERS[tier]["band"]
	if ParkProps.stage_of(map_id) == 0:
		push_error("park_props_plan: name a park with --map=park_dam (one of %s)" % str(ParkProps.PARKS))
		quit(2)
		return
	if not file_arg.is_empty():
		ParkProps.file_overrides[map_id] = file_arg
	var world := ParkProps.world_for(map_id)
	var map = world["map"]
	if not map.ok:
		push_error("park_props_plan: %s fails its park schema" % map_id)
		quit(2)
		return
	var c := ParkProps.context(map, world["ground"], world["stage"])
	if not ground_rows_arg.is_empty():
		c.use_ground_rows(Array(ground_rows_arg.split(",", false)))
	else:
		c.use_ground_rows(ParkProps.load_json(ParkProps.file_path(map_id)).get("ground_rows"))
	if not low_rows_arg.is_empty():
		c.use_low_ground_rows(Array(low_rows_arg.split(",", false)))
	else:
		c.use_low_ground_rows(ParkProps.load_json(ParkProps.file_path(map_id)).get("low_ground_rows"))
	if bench:
		quit(_bench(map_id, map, world))
		return
	quit(_check(map_id, map, world, c, not file_arg.is_empty()) if check else _plan(map_id, map, world, c, line_key))


func _bench(map_id: String, map, world: Dictionary) -> int:
	var file := ParkProps.load_json(ParkProps.file_path(map_id))
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	if file.is_empty() or kit.is_empty():
		push_error("park_props_bench: no vignette file or kit for " + map_id)
		return 2
	var spots: Array = []
	for i in BENCH_VIGNETTES:
		var spot: Dictionary = (file["spots"][i % file["spots"].size()] as Dictionary).duplicate(true)
		spot["id"] = "bench_%d" % i
		spots.append(spot)
	file["spots"] = spots
	var t0 := Time.get_ticks_usec()
	var c := ParkProps.context(map, world["ground"], world["stage"])
	var t1 := Time.get_ticks_usec()
	var list := ParkProps.expand(file, kit, map, world["ground"], c)
	var t2 := Time.get_ticks_usec()
	for path: String in ParkProps.mesh_paths(list, kit, false):
		ParkProps._mesh(path)
	var t3 := Time.get_ticks_usec()
	var built := ParkProps.build_nodes(list, kit)
	var t4 := Time.get_ticks_usec()
	var worst := 0.0
	for job: Dictionary in ParkProps.jobs(list):
		var started := Time.get_ticks_usec()
		ParkProps.build_job(built, job, kit, false)
		worst = maxf(worst, (Time.get_ticks_usec() - started) / 1000.0)
	print("park_props_bench: %d vignettes, %d instances, %d views: context %.1f ms, expand %.1f ms, mesh reads %.1f ms (worker side %.1f ms); node build %.1f ms on the main thread, worst single job %.1f ms" % [
		BENCH_VIGNETTES, list.size(), built.find_children("*", "GeometryInstance3D", true, false).size(), (t1 - t0) / 1000.0,
		(t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t2 - t0) / 1000.0, (t4 - t3) / 1000.0, worst])
	var floating := 0.0
	for inst: Dictionary in list:
		floating = maxf(floating, inst["float_m"])
	print("park_props_bench: max foot float %.3f m" % floating)
	built.free()
	return 0


func _check(map_id: String, map, world: Dictionary, c, has_file_arg := false) -> int:
	var path := ParkProps.file_path(map_id)
	var file := ParkProps.load_json(path)
	if file.is_empty():
		print(JSON.stringify({"map": map_id, "error": "no vignette file at " + path}))
		return 2
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	var errors: Array = ParkProps.kit_errors(kit) + ParkProps.file_errors(file, kit, map) + c.unresolved
	for error in errors:
		print(JSON.stringify({"map": map_id, "rule": "schema", "detail": error}))
	if not errors.is_empty():
		return 1
	var list := ParkProps.expand(file, kit, map, world["ground"], c)
	var violations := ParkProps.validate(list.filter(func(i: Dictionary) -> bool: return not i["litter"]), map, world["ground"], world["stage"], c)
	for v: Dictionary in violations:
		print(JSON.stringify({"map": map_id, "vignette": v["vignette"], "kind": v["kind"], "at": [snappedf(v["pos"].x, 0.1), snappedf(v["pos"].z, 0.1)],
			"rule": v["rule"], "detail": v["detail"]}))
	var litter := list.filter(func(i: Dictionary) -> bool: return i["litter"]).size()
	var fingerprint := ParkProps.fingerprint(list)
	var patterns := ParkProps.spot_pattern_errors(file)
	for row: Dictionary in patterns:
		print(JSON.stringify({"map": map_id, "rule": row["rule"], "spots": row["spots"], "detail": row["detail"]}))
	var pins := 0
	var pin_text := ParkProps.pin_error(file, fingerprint)
	if not pin_text.is_empty():
		if file.has("pin") or not has_file_arg:
			pins = 1
			print(JSON.stringify({"map": map_id, "rule": "pin", "detail": pin_text}))
		else:
			print(JSON.stringify({"map": map_id, "level": "note", "detail": "no pin"}))
	var lints := ParkProps.label_lint(file)
	for row: Dictionary in lints:
		print(JSON.stringify({"map": map_id, "level": "lint", "rule": row["rule"], "spot": row["spot"], "detail": row["detail"]}))
	var failing := violations.size() + patterns.size() + pins
	print("park_props_plan: %s %d instances (%d litter), %d violations, fingerprint %d, %d pattern, %d pin, %d lint" % [map_id, list.size(), litter, failing, fingerprint, patterns.size(), pins, lints.size()])
	return 1 if failing > 0 else 0


func _plan(map_id: String, map, world: Dictionary, c, line_key: String) -> int:
	var ground: Callable = world["ground"]
	var main: PackedVector2Array = c.lines.get(line_key, PackedVector2Array())
	if main.size() < 2:
		push_error("park_props_plan: %s has no line %s (have %s)" % [map_id, line_key, str(c.lines.keys())])
		return 2
	var rows: Array = map.park["park_rows"].filter(func(r: Dictionary) -> bool: return not r["element"] in SKIP_ELEMENTS)
	var found := []
	var rect: Rect2 = map.play_rect
	var x := rect.position.x + GRID_M
	while x < rect.end.x:
		var z := rect.position.y + GRID_M
		while z < rect.end.y:
			var at := Vector2(x, z)
			z += GRID_M
			var d: float = c.line_distance(at)
			if d < LINE_BAND_M[0] or d > LINE_BAND_M[1]:
				continue
			var probe := {"vignette": "plan", "kind": "plan", "class": ParkProps.PROP, "tags": TIERS[tier]["tags"], "pos": Vector3(at.x, 0.0, at.y), "radius": VIGNETTE_RADIUS_M,
				"height": VIGNETTE_HEIGHT_M, "litter": false, "float_m": 0.0, "slope_deg": 0.0}
			probe["slope_deg"] = _slope(ground, at)
			if probe["slope_deg"] > MAX_SLOPE_DEG or not ParkProps.check_one(probe, c).is_empty() or not _ring_clear(c, at):
				continue
			var near := _along(main, at)
			found.append({"at": at, "line_m": d, "along_m": near["along"], "line_side_m": near["dist"], "slope": probe["slope_deg"]})
		x += GRID_M
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["along_m"] < b["along_m"] if not is_equal_approx(a["along_m"], b["along_m"]) else a["slope"] < b["slope"])
	var kept: Array[Vector2] = []
	var printed := 0
	for spot: Dictionary in found:
		if kept.any(func(other: Vector2) -> bool: return other.distance_to(spot["at"]) < SPACING_M):
			continue
		kept.append(spot["at"])
		printed += 1
		var row := _nearest_row(rows, spot["at"])
		print(JSON.stringify({"at": [spot["at"].x, spot["at"].y], "line_m": snappedf(spot["line_m"], 0.1), "along_m": snappedf(spot["along_m"], 1.0),
			"slope_deg": snappedf(spot["slope"], 0.1), "row": row["id"], "society": row["society"], "element": row["element"], "landform": row["landform"],
			"row_m": snappedf(row["distance"], 1.0)}))
	print("park_props_plan: %s %d candidates (tier %s), %d spots %.0f m apart along %s" % [map_id, found.size(), tier, printed, SPACING_M, line_key])
	return 0


func _ring_clear(c, at: Vector2) -> bool:
	for reach in [VIGNETTE_RADIUS_M * 0.5, VIGNETTE_RADIUS_M]:
		for k in 8:
			var p: Vector2 = at + Vector2.from_angle(k * TAU / 8.0) * reach
			if c.keepout_at(p, ParkProps.ParkSites.MARGIN, VIGNETTE_HEIGHT_M <= ParkProps.LOW_GROUND_MAX_M) != "" or (tier == "tall" and ParkProps.ParkRecipes.in_clear(c.lanes, p, 0.0)):
				return false
	return true


func _along(line: PackedVector2Array, at: Vector2) -> Dictionary:
	var best := {"along": 0.0, "dist": INF}
	var run := 0.0
	for i in range(1, line.size()):
		var near := Geometry2D.get_closest_point_to_segment(at, line[i - 1], line[i])
		var d := at.distance_to(near)
		if d < best["dist"]:
			best = {"along": run + line[i - 1].distance_to(near), "dist": d}
		run += line[i - 1].distance_to(line[i])
	return best


func _slope(ground: Callable, at: Vector2) -> float:
	var worst := 0.0
	for k in 5:
		var p := at if k == 0 else at + Vector2.from_angle((k - 1) * TAU / 4.0) * VIGNETTE_RADIUS_M * 0.5
		var n := ParkProps._normal(ground, p, 2.0)
		worst = maxf(worst, rad_to_deg(acos(clampf(n.y, -1.0, 1.0))))
	return worst


func _nearest_row(rows: Array, at: Vector2) -> Dictionary:
	var best := {"id": "", "society": "", "element": "", "landform": "", "distance": INF}
	for row: Dictionary in rows:
		var d := Vector2(float(row["at"][0]), float(row["at"][1])).distance_to(at)
		if d < best["distance"]:
			best = {"id": row["id"], "society": row["society"], "element": row["element"], "landform": row["landform"], "distance": d}
	return best
