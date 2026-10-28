extends SceneTree

# Rule (design-v3/PARK.md section 8, "Two more stage tests"): no open play cell lies more than
# 80 m from a park row's footprint (start).
#
# Every baked park file runs: each src/world/park/<map_id>.json whose assets/park/<map_id>/
# bake.json and graph.bin exist. The open play cells are the graph's open nodes (graph.bin, the
# OPEN flag of src/world/park/park_graph.gd), decks included. A node outside the park's play_rect
# that the spawn cannot reach (no finite d_spawn) is no play cell and is left out, counted in the
# print: the top of a canyon wall at the square's edge (the dam's, #488; the flume's, #545, whose
# east wall runs 275 m from x 525 to the edge, past every row). For each, the planar distance to
# the nearest park row footprint is taken: 0 inside, the rectangle or the inscribed ellipse of
# src/world/park/park_stamps.gd frame(), turned by yaw. A `ground` element row is the stage's
# canvas, not a park piece (PARK.md:82, "a plain ground row"); counting it would let the base
# plain, which covers the whole square, pass every stage, so ground rows are not counted. The map
# fails when any open node lies farther than DENSITY_M; the worst node is printed.
#
# Planted, on park_test: the same graph with only the first half of the counted rows fails.

const T := preload("res://tests/support/t.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"
const FIXTURE := "park_test"

const DENSITY_M := 80.0    # PARK.md:529, "no open play cell lies more than 80 m from a park row's footprint (start)"
const CANVAS_ELEMENT := "ground"
const ELLIPSE_SAMPLES := 256

var t := T.new("park_density_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := baked_maps()
	t.check("baked park files found", maps.size() > 0, "%d: %s" % [maps.size(), ", ".join(maps)])
	for map_id in maps:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [PARK_DIR, map_id]))
		var graph = ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])
		if not t.check("%s graph.bin loads" % map_id, graph != null):
			continue
		var rows := counted_rows(park)
		var r := measure(graph, rows, _rect(park))
		print("[density] map %s open %d (outside the play rect and unreachable, left out: %d) rows %d worst %.1f m at node %d (%.0f, %.1f, %.0f) nearest %s; over %.0f m: %d" % [
			map_id, r["open"], r["left_out"], rows.size(), r["worst"], r["node"], r["at"].x, r["at"].y, r["at"].z,
			r["nearest"], DENSITY_M, r["over"]])
		t.check("%s has open nodes" % map_id, r["open"] > 0, "%d" % r["open"])
		t.check("%s every open node within %.0f m of a park row" % [map_id, DENSITY_M], r["worst"] <= DENSITY_M,
			"worst %.1f m, %d nodes over" % [r["worst"], r["over"]])
		if map_id == FIXTURE:
			var half := rows.slice(0, rows.size() / 2)
			var p := measure(graph, half, _rect(park))
			print("[planted] %s with %d of %d rows: worst %.1f m at node %d, over %d" % [FIXTURE, half.size(), rows.size(), p["worst"], p["node"], p["over"]])
			t.check("planted half-row park fails the density rule", p["worst"] > DENSITY_M, "%.1f m" % p["worst"])
	quit(t.verdict())


static func baked_maps() -> PackedStringArray:
	var out := PackedStringArray()
	for name in DirAccess.get_files_at(PARK_DIR):
		if not name.ends_with(".json"):
			continue
		var map_id := name.get_basename()
		var dir := "%s/%s" % [OUT_DIR, map_id]
		if FileAccess.file_exists(dir + "/bake.json") and FileAccess.file_exists(dir + "/graph.bin"):
			out.append(map_id)
	out.sort()
	return out


# [{id, frame}] for every park row that is not the canvas.
static func counted_rows(park: Dictionary) -> Array:
	var out := []
	for row in park["park_rows"]:
		if String(row["element"]) == CANVAS_ELEMENT:
			continue
		out.append({"id": String(row["id"]), "frame": Stamps.frame(row)})
	return out


static func _rect(park: Dictionary) -> Rect2:
	var a: Array = park["play_rect"]
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))


# {open, left_out, worst, node, at, nearest, over} over the graph's open play cells.
static func measure(graph, rows: Array, rect: Rect2) -> Dictionary:
	var r := {"open": 0, "left_out": 0, "worst": 0.0, "node": -1, "at": Vector3.ZERO, "nearest": "", "over": 0}
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.OPEN == 0:
			continue
		var p: Vector3 = graph.position(n)
		if not rect.has_point(Vector2(p.x, p.z)) and not is_finite(graph.d_spawn_node(n)):
			r["left_out"] += 1
			continue
		r["open"] += 1
		var best := INF
		var best_id := ""
		for row in rows:
			var d := distance(row["frame"], p.x, p.z, best)
			if d < best:
				best = d
				best_id = row["id"]
				if best == 0.0:
					break
		if best > DENSITY_M:
			r["over"] += 1
		if best > r["worst"] or r["node"] < 0:
			r["worst"] = best
			r["node"] = n
			r["at"] = p
			r["nearest"] = best_id
	return r


# Planar distance from (x, z) to the footprint, 0 inside. `beat` skips the ellipse search when
# the rectangle that holds it is already no nearer.
static func distance(f: Dictionary, x: float, z: float, beat := INF) -> float:
	if Stamps.inside(f, x, z):
		return 0.0
	var rel: Vector2 = Vector2(x, z) - (f["at"] as Vector2)
	var u := rel.dot(f["along"])
	var v := rel.dot(f["across"])
	var hl: float = f["length"] * 0.5
	var hw: float = f["width"] * 0.5
	var box := Vector2(maxf(absf(u) - hl, 0.0), maxf(absf(v) - hw, 0.0)).length()
	if not f["ellipse"] or box >= beat:
		return box
	# The ellipse's nearest rim point, sampled: never nearer than the true distance.
	var best := INF
	for k in ELLIPSE_SAMPLES:
		var a := TAU * k / ELLIPSE_SAMPLES
		var d := Vector2(absf(u) - hl * cos(a), absf(v) - hw * sin(a)).length()
		best = minf(best, d)
	return best
