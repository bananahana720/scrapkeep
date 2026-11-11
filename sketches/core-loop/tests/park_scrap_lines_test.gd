extends SceneTree

# Owner map point 10b (map-audit section G, unit 5): scrap lies on the skill lines. Read from the park file, its
# lines.json, the bake and the baked stage graph only; no scene boots. Per world 1 park (the dam and the flume):
#
#   on_lines (pass >= SHARE_MIN): the share of the scrap trail's pieces that stand within REACH_M of plan distance of
#     a skill mark. A mark is
#       a ride end   either end of a ride edge of the graph (a kicker, a launcher, a cable, a lift, a rail: the
#                    take-off and the landing are where the skill is);
#       a drop       a ground edge of the graph walkable one way only (a ledge) whose ends differ by DROP_M or more,
#                    read as the segment between its ends.
#   The pieces are the ones the game lays (scrap_field.gd trail_spots over park_map.gd scrap_trail), on the park's
#   baked ground with its holes (park_props.gd world_for); the game reads terrain.height, which adds event overlays.
#
# Output, one line per stage: `MAPCHECK <stage> scrap_on_lines <value> pass>=<line> PASS|FAIL`, plus `report INFO`
# lines naming the marks the pieces stand by, so a lines.json edit can be aimed.
#
# Planted: all scrap on flat ground. The same measure over the dam's trail, with the graph's heights flattened to
# one value and its ride edges taken away, reads 0 and fails.

const T := preload("res://tests/support/t.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")

const OUT_DIR := "res://assets/park"
const WORLD1 := ["park_dam", "park_flume"]
const REACH_M := 8.0
const DROP_M := 4.0
const SHARE_MIN := 0.3

var t := T.new("park_scrap_lines_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for map_id in WORLD1:
		var world := ParkProps.world_for(map_id)
		var map: ParkMap = world["map"]
		var g = ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])
		if not t.check("%s inputs load" % map_id, map.ok and g != null, "map and graph"):
			continue
		var at: Callable = world["ground"]
		var pieces := ScrapField.trail_spots(map.scrap_trail, func(x: float, z: float) -> float: return at.call(x, z, 0.0).y)
		if not t.check("%s has a scrap trail" % map_id, not pieces.is_empty(), "%d pieces" % pieces.size()):
			continue
		var r := measure(pieces, marks(g, _node_heights(g), true))
		var ok: bool = r["share"] >= SHARE_MIN
		print("MAPCHECK %s scrap_on_lines %.2f pass>=%.2f %s" % [map_id, r["share"], SHARE_MIN, "PASS" if ok else "FAIL"])
		print("MAPCHECK %s report INFO %d of %d pieces; by ride end %d, by drop only %d; rides %s" % [map_id,
			r["near"], pieces.size(), r["by_ride"], r["near"] - r["by_ride"], str(r["rides"])])
		t.check("%s: at least %.0f%% of the scrap lies on the skill lines" % [map_id, SHARE_MIN * 100.0], ok,
			"%.2f (%d of %d)" % [r["share"], r["near"], pieces.size()])
		if map_id == "park_dam":
			var flat := PackedFloat32Array()
			flat.resize(g.node_count())
			flat.fill(0.0)
			var planted := measure(pieces, marks(g, flat, false))
			t.check("planted: the dam's trail with flat ground and no rides reads under the line",
				planted["share"] < SHARE_MIN and planted["near"] == 0, "%.2f" % planted["share"])
	quit(t.verdict())


func _node_heights(g) -> PackedFloat32Array:
	var ys := PackedFloat32Array()
	for n in g.node_count():
		ys.append(g.position(n).y)
	return ys


# The skill marks of a graph over a height array (one value a node): [{"a": Vector2, "b": Vector2, "ride": row id or
# ""}]. A ride end is a zero-length mark; with_rides false leaves the rides out.
static func marks(g, ys: PackedFloat32Array, with_rides: bool) -> Array:
	var out := []
	var seen := {}
	for a in g.node_count():
		for e in range(g.off[a], g.off[a + 1]):
			var b: int = g.to[e]
			var row: String = g.names[g.ride[e]] if g.ride[e] >= 0 else ""
			if row != "":
				if with_rides:
					for n in [a, b]:
						if not seen.has(n):
							seen[n] = true
							var p: Vector3 = g.position(n)
							out.append({"a": Vector2(p.x, p.z), "b": Vector2(p.x, p.z), "ride": row})
				continue
			if ys[a] - ys[b] < DROP_M or _walks(g, b, a):
				continue
			var pa: Vector3 = g.position(a)
			var pb: Vector3 = g.position(b)
			out.append({"a": Vector2(pa.x, pa.z), "b": Vector2(pb.x, pb.z), "ride": ""})
	return out


static func _walks(g, a: int, b: int) -> bool:
	for e in range(g.off[a], g.off[a + 1]):
		if g.to[e] == b and (g.ride[e] < 0 or g.names[g.ride[e]] == ""):
			return true
	return false


# {share, near, by_ride, rides}: the pieces within REACH_M of a mark, those of them by a ride end, and the ride rows
# they stand by.
static func measure(pieces: Array[Vector3], marks_list: Array) -> Dictionary:
	var near := 0
	var by_ride := 0
	var rides := {}
	for piece in pieces:
		var p := Vector2(piece.x, piece.z)
		var hit := false
		var ride := ""
		for m: Dictionary in marks_list:
			if Geometry2D.get_closest_point_to_segment(p, m["a"], m["b"]).distance_to(p) <= REACH_M:
				hit = true
				if m["ride"] != "":
					ride = m["ride"]
					break
		if hit:
			near += 1
		if ride != "":
			by_ride += 1
			rides[ride] = rides.get(ride, 0) + 1
	return {"share": float(near) / maxf(1.0, pieces.size()), "near": near, "by_ride": by_ride, "rides": rides}
