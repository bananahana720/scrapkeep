extends SceneTree

const UndrawnPlaces := preload("res://tools/qa/undrawn_places.gd")
const Game := preload("res://src/game.gd")
const CampHub := preload("res://src/world/camp_hub.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

# Invisible walls found by tools/qa/collision_sweep.gd (30 Oct, Andrew's first sitting):
#   - a solid camp prop collides as a hull of its first mesh up to SOLID_TOP_M, not a box round the whole mesh: each
#     cottonwood's box took its crown down to the ground, 8.4 x 6.6 m round a 1.2 m trunk;
#   - a waisted anchor post (hoodoo a, size 10) splits its upper column, so no one hull spans the narrow neck under the cap.
# Ungrounded rests found by tools/spot_sweep.gd (ruling aa), each rolled out of from every side with --leave=1:
#   - the dam's river-canyon crevice (red team greedy, w29): the lobber ledge stopped one 2 m grid step short of the
#     west cliff, leaving a V slot the ball hung in (14 of 16 roll-outs, a jump did not free it). A ground row
#     (lobber_ledge_cliff_fill) now raises that step to the ledge's height.

# [stage, x, y, z] of each spot, y above the surface to drop onto.
const HUNG_SPOTS := [[1, -199.5, 30.0, 445.0]]
const WALL_FILTER := "--owner=Park_QAWall_Near"

var _t := T.new("invisible_walls_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	root.add_child(game)
	while game.flow == null:
		await process_frame
	var hub = game.camp_hub
	hub.ensure_built()
	var trees := 0
	for holder: Node in hub.root.get_children():
		if not String(holder.name).contains("Node3D") and not String(holder.name).begins_with("Prop_cottonwood"):
			continue
		var body := holder.get_node_or_null("Collider") as StaticBody3D
		if body == null or not holder.has_node("cottonwood_Trunk"):
			continue
		trees += 1
		var shape := (body.get_child(0) as CollisionShape3D).shape
		_t.check("a cottonwood collides as a hull (%s)" % holder.name, shape is ConvexPolygonShape3D, str(shape))
		if not shape is ConvexPolygonShape3D:
			continue
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		var mid := PackedVector3Array()
		for p: Vector3 in (shape as ConvexPolygonShape3D).points:
			lo = lo.min(p)
			hi = hi.max(p)
			if p.y > 1.5:
				mid.append(p)
		var trunk_r := 0.0
		for p in mid:
			trunk_r = maxf(trunk_r, Vector2(p.x, p.z).distance_to(Vector2(0.24, 0.05)))
		_t.check("%s: hull reaches SOLID_TOP_M and no higher (%.2f m)" % [holder.name, hi.y], absf(hi.y - CampHub.SOLID_TOP_M) < 0.01)
		_t.check("%s: above the root flare the hull is the trunk (widest %.2f m from its axis, want < 1.2)" % [holder.name, trunk_r],
			not mid.is_empty() and trunk_r < 1.2)
	_t.eq("six cottonwoods checked", trees, 6)
	var jukebox: Node = hub.piece("moss_jukebox")
	var jb := jukebox.get_node_or_null("Collider") as StaticBody3D if jukebox != null else null
	var jshape: Shape3D = (jb.get_child(0) as CollisionShape3D).shape if jb != null and jb.get_child_count() > 0 else null
	var jtop := -INF
	if jshape is ConvexPolygonShape3D:
		for p: Vector3 in (jshape as ConvexPolygonShape3D).points:
			jtop = maxf(jtop, p.y)
	_t.check("the jukebox cabinet stays solid to its top (%.2f m, cabinet 2.6 m)" % jtop, jtop > 2.5)

	var row := {"id": "hoodoo_1", "recipe": "anchor_hoodoo", "size": [283, 10, 273]}
	var fit := ParkRecipes.anchor_fit_boxes(row)
	var upper := fit.filter(func(b): return float(b["h"][0]) >= 2.0)
	_t.check("hoodoo a at size 10 splits its upper column (%d bands)" % upper.size(), upper.size() >= 2)
	var widest := 0.0
	var narrowest := INF
	for b: Dictionary in upper:
		var area := (float(b["x"][1]) - float(b["x"][0])) * (float(b["z"][1]) - float(b["z"][0]))
		widest = maxf(widest, area)
		narrowest = minf(narrowest, area)
	_t.check("its neck band is under half the widest band's footprint (%.1f of %.1f m2)" % [narrowest, widest], narrowest < 0.5 * widest)
	var hulls := ParkRecipes.anchor_hulls(row, fit)
	_t.eq("one hull per band", hulls.size(), fit.size())
	game.free()
	_cluster_samples()
	_wall_sweep()
	for spot: Array in HUNG_SPOTS:
		_roll_out(spot)
	quit(_t.verdict())


func _cluster_samples() -> void:
	# The middle sample bridges the two ends, crossing zero and a cell boundary.
	var points := PackedVector3Array([Vector3(-1, 2, 0), Vector3(1, 2, 0), Vector3(0, 2, 0), Vector3(6, 2, 0)])
	var places := UndrawnPlaces.cluster({"A": points, "B": PackedVector3Array([points[0]])}, 0.75)
	_t.eq("one connected patch, one distant patch and one different owner", places.size(), 3)
	if places.size() == 3:
		_t.eq("the connected patch spans its three samples", places[0],
			{"owner": "A", "samples": 3, "position": [0.0, 2.0, 0.0], "size": [2.0, 0.0, 0.0]})
		_t.eq("the distant patch is the single sample at x=6", places[1],
			{"owner": "A", "samples": 1, "position": [6.0, 2.0, 0.0], "size": [0.0, 0.0, 0.0]})
		_t.eq("the other owner keeps its coincident sample", places[2]["owner"], "B")


func _wall_sweep() -> void:
	var out := OS.get_user_data_dir().path_join("wall-sweep-" + Crypto.new().generate_random_bytes(12).hex_encode())
	var created := DirAccess.make_dir_absolute(out)
	if not _t.check("the wall fixture creates its own report directory", created == OK, error_string(created)):
		return
	var partial_stem := "wall_fixture-s1-partial-" + WALL_FILTER.sha256_text().left(10)
	_check_wall_reports(out, partial_stem)

	# Both sweeps can leave an unavailable report if the fixture fails to load.
	for stem: String in ["wall_fixture-s1", partial_stem]:
		for suffix: String in [".json", "-owners.json", "-unavailable.json", "-unavailable-owners.json"]:
			var path := out.path_join(stem + suffix)
			if FileAccess.file_exists(path):
				_t.eq("remove fixture report " + path.get_file(), DirAccess.remove_absolute(path), OK)
	_t.eq("remove the empty wall fixture directory", DirAccess.remove_absolute(out), OK)


func _check_wall_reports(out: String, partial_stem: String) -> void:
	var args := PackedStringArray(["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/qa/collision_sweep.gd", "--", "--area=wall_fixture", "--step=0.15", "--out=%s" % out])
	if OS.get_environment("PLANT") == "invisible_wall":
		args.append("--plant-wall")
	var output := []
	var code := OS.execute(OS.get_executable_path(), args, output, true)
	var path := out.path_join("wall_fixture-s1.json")
	if not _t.check("wall fixture wrote its report", code == 0 and FileAccess.file_exists(path), str(code)):
		print("\n".join(output))
		return
	var full_report := FileAccess.get_file_as_string(path)
	var report = JSON.parse_string(full_report)
	if not _t.check("the sweep sampled all three physical walls", report is Dictionary and report.get("totals", {}).get("shapes") == 3
			and report["totals"]["samples"] > 0 and report.get("places") is Array):
		return
	var counts := {}
	var invisible := 0
	var counted := 0
	for place in report["places"]:
		var owner: String = place["owner"]
		counts[owner] = int(counts.get(owner, 0)) + 1
		counted += int(place["samples"])
		if owner == "Park_QAWall_Missing" or (owner == "Park_QAWall_Matched" and args.has("--plant-wall")):
			invisible += int(place["samples"])
	_t.eq("the matching wall has no undrawn place", counts.get("Park_QAWall_Matched", 0), 0)
	_t.eq("the 0.4 m miss with a mesh within 1.5 m is one place", counts.get("Park_QAWall_Near", 0), 1)
	_t.eq("the planted invisible wall is one place", counts.get("Park_QAWall_Missing", 0), 1)
	_t.eq("the inventory accounts for every bare sample", counted, int(report["totals"]["bare"]))
	_t.eq("only the missing meshes have no geometry within 1.5 m", invisible, int(report["totals"]["invisible"]))
	args.append(WALL_FILTER)
	output.clear()
	code = OS.execute(OS.get_executable_path(), args, output, true)
	var partial_file := partial_stem + ".json"
	if _t.check("the filtered sweep has its own report", code == 0 and FileAccess.file_exists(out.path_join(partial_file))):
		var partial = JSON.parse_string(FileAccess.get_file_as_string(out.path_join(partial_file)))
		_t.eq("filtered report records its owner filter", partial["filters"], [WALL_FILTER])
		_t.eq("filtered report covers one collider", int(partial["totals"]["shapes"]), 1)
	else:
		print("\n".join(output))
	_t.check("the full map report survives a filtered sweep", FileAccess.get_file_as_string(path) == full_report)
	print("RECEIPT %s" % JSON.stringify({"places_by_owner": counts, "bare_samples": counted,
		"invisible_samples": report["totals"]["invisible"]}))


# Rolls out of spot from 8 sides (tools/spot_sweep.gd --leave=1): no probe may hang or stick, and the drop must land.
func _roll_out(spot: Array) -> void:
	var out := OS.get_user_data_dir().path_join("invisible-walls-%d.ndjson" % OS.get_process_id())
	var at := "%s,%s,%s" % [spot[1], spot[2], spot[3]]
	var output := []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--fixed-fps", "90", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/spot_sweep.gd", "--", "--out=%s" % out, "--stages=%d" % spot[0], "--dirs=8", "--leave=1", "--at=%s" % at], output, true)
	var outcomes := {}
	var file := FileAccess.open(out, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		var row = JSON.parse_string(line) if not line.is_empty() else null
		if row is Dictionary:
			outcomes[row["outcome"]] = int(outcomes.get(row["outcome"], 0)) + 1
	file = null
	DirAccess.remove_absolute(out)
	var probes := 0
	for n in outcomes.values():
		probes += n
	var ran := code == 0 and probes == 8
	if not ran:
		print("\n".join(output))
	_t.check("stage %d (%s): the sweep ran 8 roll-outs (exit %d, %d rows)" % [spot[0], at, code, probes], ran)
	_t.check("stage %d (%s): no roll-out hangs, sticks or falls through, and one gets clear %s" % [spot[0], at, outcomes],
		not outcomes.has("hung") and not outcomes.has("stuck") and not outcomes.has("fell") and not outcomes.has("bad_start") and outcomes.has("reached"))
