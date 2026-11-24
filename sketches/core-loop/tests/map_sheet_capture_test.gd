extends SceneTree

# tools/map_sheet_capture.gd (map standard points 1 picture and 8b, map-audit.md section G) chooses its poses from each
# world 1 park's stage graph. Headless, with no game: on the dam and the flume the beam mode gives 8 riding-line poses
# with finite places and headings, the first at the drop-in, the last two within the tool's NEAR_TOLERANCE_M of 150 m
# and 50 m from the real beam's foot (the landmark placed through park_recipes), every one apart and with the beam
# inside MAX_BEARING_DEG of the camera. The dam's lines reach both near reads; the flume's end at its beacon 99 m out,
# so its 50 m read stands on open sighted ground off the lines and says so (on_line false). The silhouette mode gives
# one pose a COUNTS row with 2 to 5 machines on ground line nodes, and a control run shows exactly one fewer. Argument parsing, the sheet grid and the bearing helpers are pure.
# A headless child run of the tool exits 2 before it builds a game.

const T := preload("res://tests/support/t.gd")
const Tool := preload("res://tools/map_sheet_capture.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkGraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")

const MAPS := ["park_dam", "park_flume"]

var t := T.new("map_sheet_capture_test")
var _recipes = load("res://src/world/park/park_recipes.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_args()
	_helpers()
	var holder := Node3D.new()
	root.add_child(holder)
	for map_id: String in MAPS:
		var park: Dictionary = Tool.park_data(map_id)
		var graph = Tool.load_graph(map_id)
		if not t.check("%s graph loads" % map_id, graph != null):
			continue
		var bake := ParkGraphTool.load_bake("res://assets/park/" + map_id)
		var node: Node3D = _recipes.place_landmark(park, holder, Terrain._park_floor_at.bind(bake["ground"], bake["holes"], bake["under"]))
		var beam = node.get_node_or_null("AncientBeam") if node != null else null
		if not t.check("%s carries its beam" % map_id, beam != null):
			continue
		var axis := Vector2(beam.bottom.x, beam.bottom.z)
		_beam_poses(map_id, graph, park, axis)
		_fight_poses(map_id, graph, axis)
		node.free()
	holder.free()
	_headless_refusal()
	quit(t.verdict())


func _args() -> void:
	var ok := Tool.parse_args(PackedStringArray(["--map=park_dam", "--mode=beam", "--out=/tmp/x"]))
	t.check("parses a full beam run", ok["ok"] and ok["map"] == "park_dam" and ok["mode"] == "beam" and not ok["control"], str(ok))
	var c := Tool.parse_args(PackedStringArray(["--map=park_flume", "--mode=silhouette", "--out=/tmp/x", "--control=1"]))
	t.check("parses a silhouette control run", c["ok"] and c["control"] and c["mode"] == "silhouette", str(c))
	for bad: Array in [["--map=park_pit", "--mode=beam", "--out=/tmp/x"], ["--map=park_dam", "--mode=wall", "--out=/tmp/x"],
			["--map=park_dam", "--mode=beam", "--out=rel/dir"], ["--map=park_dam", "--mode=beam", "--out=res://x"],
			["--map=park_dam", "--mode=beam", "--out=/tmp/x", "--control=2"], ["--map=park_dam", "--mode=beam"],
			["--map=park_dam", "--mode=beam", "--out=/tmp/x", "--shots=1"]]:
		var r := Tool.parse_args(PackedStringArray(bad))
		t.check("refuses %s" % " ".join(bad), not r["ok"] and r["error"] != "", r["error"])


func _helpers() -> void:
	t.eq("beam sheet is 4x2", Tool.sheet_grid(8), Vector2i(4, 2))
	t.eq("four tiles are 2x2", Tool.sheet_grid(4), Vector2i(2, 2))
	t.eq("six tiles are 3x2", Tool.sheet_grid(6), Vector2i(3, 2))
	t.near("dead ahead bears 0", Tool.bearing_deg(Vector3.FORWARD, Vector3.ZERO, Vector2(0, -100)), 0.0, 1e-4)
	t.near("a beam to the right bears +90", Tool.bearing_deg(Vector3.FORWARD, Vector3.ZERO, Vector2(100, 0)), 90.0, 1e-4)
	t.near("a beam to the left bears -90", Tool.bearing_deg(Vector3.FORWARD, Vector3.ZERO, Vector2(-100, 0)), -90.0, 1e-4)
	var turned := Tool.clamp_toward(Vector3.FORWARD, Vector3.ZERO, Vector2(100, 0), 40.0)
	t.near("a heading 90 degrees off turns in to 40", Tool.bearing_deg(turned, Vector3.ZERO, Vector2(100, 0)), 40.0, 1e-3)
	t.check("a heading inside the limit is kept", Tool.clamp_toward(Vector3.FORWARD, Vector3.ZERO, Vector2(10, -100), 40.0).is_equal_approx(Vector3.FORWARD))
	t.check("rects that touch are not apart", not Tool.apart(Rect2(0, 0, 10, 10), Rect2(12, 0, 10, 10)))
	t.check("rects with a gap are apart", Tool.apart(Rect2(0, 0, 10, 10), Rect2(20, 0, 10, 10)))
	for n in range(2, 6):
		var slots := Tool.slot_offsets(n)
		var spread := true
		for i in n:
			for j in range(i + 1, n):
				spread = spread and (slots[i] as Vector2).distance_to(slots[j]) >= Tool.SPREAD_M - 0.001
		t.check("%d slots stand ahead and apart" % n, slots.size() == n and spread and slots.all(func(s): return s.x > 0.0))
	for i in Tool.COUNTS.size():
		var full: int = Tool.COUNTS[i]
		var hidden := Tool.hidden_slot(i, full)
		t.check("pose %d hides a slot it stages" % (i + 1), hidden >= 0 and hidden < full)
		t.eq("pose %d control shows one fewer" % (i + 1), Tool.shown_count(full, true), full - 1)
		t.eq("pose %d full run shows all" % (i + 1), Tool.shown_count(full, false), full)
	var kinds := {}
	for i in Tool.COUNTS.size():
		for s in Tool.COUNTS[i]:
			kinds[Tool.kind_for(i, s)] = true
	t.eq("every world 1 kind is staged", kinds.size(), Tool.KINDS.size())


func _beam_poses(map_id: String, graph, park: Dictionary, axis: Vector2) -> void:
	var poses := Tool.beam_poses(graph, park, axis)
	if not t.eq("%s has 8 beam poses" % map_id, poses.size(), Tool.BEAM_POSES):
		return
	t.eq("%s first pose is the drop-in" % map_id, poses[0]["kind"], "drop_in")
	var spawn: Array = park["spawn"]["at"]
	t.check("%s drop-in stands on the spawn" % map_id, Vector2(poses[0]["at"].x, poses[0]["at"].z).is_equal_approx(Vector2(spawn[0], spawn[1])))
	t.eq("%s pose 7 is the 150 m read" % map_id, poses[6]["kind"], "near_150")
	t.eq("%s pose 8 is the 50 m read" % map_id, poses[7]["kind"], "near_50")
	t.near("%s pose 7 stands about 150 m out" % map_id, poses[6]["distance_m"], 150.0, Tool.NEAR_TOLERANCE_M)
	t.near("%s pose 8 stands about 50 m out" % map_id, poses[7]["distance_m"], 50.0, Tool.NEAR_TOLERANCE_M)
	t.eq("%s near reads on the lines" % map_id, [poses[6]["on_line"], poses[7]["on_line"]], [true, map_id != "park_flume"])
	var f8: int = graph.flags(poses[7]["node"])
	t.check("%s 50 m read stands on open sighted ground the ball can reach" % map_id, f8 & ParkGraph.SIGHT_OK != 0
		and f8 & (ParkGraph.LINE | ParkGraph.OPEN) != 0 and f8 & ParkGraph.UNDER == 0 and is_finite(graph.d_landmark_node(poses[7]["node"])))
	var ride_ok := true
	var finite := true
	var apart := true
	var framed := true
	for i in poses.size():
		var p: Dictionary = poses[i]
		var at: Vector3 = p["at"]
		var h: Vector3 = p["heading"]
		finite = finite and at.is_finite() and h.is_finite() and is_equal_approx(h.length(), 1.0) and absf(h.y) < 1e-5
		framed = framed and absf(float(p["bearing_deg"])) <= Tool.MAX_BEARING_DEG + 0.01
		if i > 0 and p["on_line"]:
			ride_ok = ride_ok and graph.flags(p["node"]) & ParkGraph.LINE != 0 and graph.flags(p["node"]) & ParkGraph.SIGHT_OK != 0
		if i > 0 and i < 6:
			ride_ok = ride_ok and p["on_line"] and float(p["distance_m"]) < float(poses[0]["distance_m"]) and float(p["distance_m"]) > 150.0
		for j in i:
			var q: Vector3 = poses[j]["at"]
			apart = apart and Vector2(at.x - q.x, at.z - q.z).length() >= Tool.POSE_GAP_M - 0.001
	t.check("%s poses are finite with flat unit headings" % map_id, finite)
	t.check("%s ride poses are sighted line nodes between the drop-in and 150 m" % map_id, ride_ok)
	t.check("%s poses stand apart" % map_id, apart)
	t.check("%s every pose has the beam within %d degrees" % [map_id, int(Tool.MAX_BEARING_DEG)], framed)
	print("[poses] %s %s" % [map_id, ", ".join(poses.map(func(p): return "%s %.0f m %.0f deg" % [p["kind"], p["distance_m"], p["bearing_deg"]]))])


func _fight_poses(map_id: String, graph, axis: Vector2) -> void:
	var poses := Tool.fight_poses(graph, axis)
	if not t.eq("%s has a fight pose for each count" % map_id, poses.size(), Tool.COUNTS.size()):
		return
	var ok := true
	for i in poses.size():
		var full: int = poses[i]["count"]
		ok = ok and full >= 2 and full <= 5 and poses[i]["tries"].size() > 0
		for p: Dictionary in poses[i]["tries"]:
			var n: int = p["node"]
			ok = ok and graph.flags(n) & ParkGraph.LINE != 0 and graph.flags(n) & ParkGraph.DECK == 0 and (p["at"] as Vector3).is_finite()
	t.check("%s fight poses stage 2 to 5 machines on ground line nodes" % map_id, ok)
	var firsts: Array = poses.map(func(p): return p["tries"][0]["node"])
	var d: Array = firsts.map(func(n): return graph.d_spawn_node(n))
	var ordered := true
	for i in range(1, d.size()):
		ordered = ordered and d[i] > d[i - 1]
	t.check("%s fight poses run along the ride" % map_id, ordered, str(d))


# The tool on a headless display refuses before it builds anything.
func _headless_refusal() -> void:
	var out := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tools/map_sheet_capture.gd", "--",
		"--map=park_dam", "--mode=beam", "--out=" + OS.get_user_data_dir().path_join("map-sheet-refused")]
	var code := OS.execute(OS.get_executable_path(), args, out, true)
	t.eq("a headless run exits 2", code, 2)
	t.check("a headless run writes nothing", not DirAccess.dir_exists_absolute(OS.get_user_data_dir().path_join("map-sheet-refused")))
