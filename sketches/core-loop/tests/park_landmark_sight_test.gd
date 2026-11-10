extends SceneTree

# Rule (design-v3/PARK.md section 8, "Two more stage tests"): on a 50 m grid over the play square,
# excluding hole and roofed cells, at least landmark.sight_share of points have a clear ray from
# 2 m above the ground to landmark.sight_top over the baked heights.
#
# Every baked park file runs: each src/world/park/<map_id>.json whose assets/park/<map_id>/
# bake.json and graph.bin exist. The grid is 33 by 33 points over -800..800. A point is skipped
# when its 2 m cell is a hole (holes.bin) or roofed: under the footprint of a deck row (y set)
# whose y is more than ROOF_M above the ground there, the reading tools/park_graph.gd uses for
# its open flag. From EYE_M above the baked ground a ray runs to sight_top, sampled every
# SAMPLE_M of planar distance against the bilinear ground; a sample where the ground stands above
# the ray blocks it. share = clear / counted, and the map passes when share >= sight_share.
#
# Planted, on park_test: a 300 m wall across the square at z = 400 to 420 in a copy of its
# heights drops the share below its sight_share, so the measure can fail; a deck 100 m up roofs
# the grid points under it and a deck within ROOF_M of the ground roofs none.
#
# Line-weighted sight (owner map point 1, 10 Nov; map-audit section G): on each world 1 park the
# share of stage graph nodes flagged LINE that also carry SIGHT_OK is at least LINE_SIGHT_MIN. The
# open-grid share above weighs every open cell; this one weighs the nodes a player rides. Each world
# 1 park prints `MAPCHECK <map> <measure> <value> pass>=<line> PASS|FAIL|OWED`. A stage under its
# line goes in OWED with the measured value; the test fails if an OWED stage now meets its line, and
# fails if a stage not in OWED is under it. Planted: a copy of the flags with SIGHT_OK cleared on
# every LINE node fails the same function.

const T := preload("res://tests/support/t.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")

# World 1's parks (the dam and the flume). The Slag Bowl is an arena, not a park file.
const WORLD1 := ["park_dam", "park_flume"]
const LINE_SIGHT_MIN := 0.85
# {"<map>": {"measure": "line_sight_share", "value": measured, "why": "..."}}. Empty: both parks pass.
const OWED := {}

const PARK_DIR := "res://src/world/park"
const OUT_DIR := "res://assets/park"
const GRAPH_TOOL := "res://tools/park_graph.gd"
const FIXTURE := "park_test"

const HALF_M := 800.0
const GRID_M := 50.0       # PARK.md:529, "a 50 m grid over the play square"
const EYE_M := 2.0         # PARK.md:529, "2 m above the ground"
const SAMPLE_M := 2.0      # one sample per bake grid step
const ROOF_M := 2.0        # tools/park_graph.gd ROOF_M, the open flag's roof reading
const BAKE_SIDE := 801
const BAKE_CELLS := 800
const WALL_Z := [400.0, 420.0]
const WALL_H := 300.0

var t := T.new("park_landmark_sight_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var tool: GDScript = load(GRAPH_TOOL)
	var maps := baked_maps()
	t.check("baked park files found", maps.size() > 0, "%d: %s" % [maps.size(), ", ".join(maps)])
	for map_id in maps:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [PARK_DIR, map_id]))
		var bake: Dictionary = tool.load_bake("%s/%s" % [OUT_DIR, map_id])
		if not t.check("%s bake loads" % map_id, bake["errors"].is_empty(), str(bake["errors"])):
			continue
		var r := measure(park, bake["ground"], bake["holes"])
		var need := float(park["landmark"]["sight_share"])
		print("[sight] map %s share %.4f counted %d excluded %d (holes %d, roofed %d) threshold %.2f" % [
			map_id, r["share"], r["counted"], r["skipped"], r["holes"], r["roofed"], need])
		t.check("%s counts grid points" % map_id, r["counted"] > 0, "%d" % r["counted"])
		t.check("%s sight share >= sight_share" % map_id, r["share"] >= need, "%.4f vs %.2f" % [r["share"], need])
		if map_id in WORLD1:
			print("MAPCHECK %s open_sight_share %.4f pass>=%.2f %s" % [map_id, r["share"], need, "PASS" if r["share"] >= need else "FAIL"])
			_line_sight(map_id)
		if map_id == FIXTURE:
			_planted(park, bake)
	for map_id in WORLD1:
		t.check("%s is a baked world 1 park" % map_id, map_id in maps, map_id)
	_line_planted()
	quit(t.verdict())


# The stage graph's own flags, read through flags(n), for a baked park.
func _graph(map_id: String):
	return ParkGraph.read("%s/%s/graph.bin" % [OUT_DIR, map_id])


func _flags_of(g) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in g.node_count():
		out.append(g.flags(n))
	return out


# {share, line, ok}: of the nodes flagged LINE, the share that also carry SIGHT_OK.
static func line_sight(flags: PackedInt32Array) -> Dictionary:
	var line := 0
	var ok := 0
	for f in flags:
		if f & ParkGraph.LINE != 0:
			line += 1
			if f & ParkGraph.SIGHT_OK != 0:
				ok += 1
	return {"share": float(ok) / float(line) if line > 0 else 0.0, "line": line, "ok": ok}


func _line_sight(map_id: String) -> void:
	var g = _graph(map_id)
	if not t.check("%s graph reads" % map_id, g != null, "graph.bin"):
		return
	var r := line_sight(_flags_of(g))
	t.check("%s has LINE nodes" % map_id, r["line"] > 0, "%d" % r["line"])
	var meets: bool = r["share"] >= LINE_SIGHT_MIN
	var owed: bool = OWED.has(map_id)
	var status := "PASS" if meets else ("OWED" if owed else "FAIL")
	print("MAPCHECK %s line_sight_share %.4f pass>=%.2f %s" % [map_id, r["share"], LINE_SIGHT_MIN, status])
	if owed:
		t.check("%s OWED line_sight_share still under its line (prune the entry when it meets it)" % map_id, not meets, "%.4f vs %.2f" % [r["share"], LINE_SIGHT_MIN])
	else:
		t.check("%s LINE nodes with SIGHT_OK >= %.2f" % [map_id, LINE_SIGHT_MIN], meets, "%d of %d = %.4f" % [r["ok"], r["line"], r["share"]])


# The same function on a copy of the dam's flags with SIGHT_OK cleared on the line nodes.
func _line_planted() -> void:
	var g = _graph("park_dam")
	if g == null:
		return
	var flags := _flags_of(g)
	var cleared := flags.duplicate()
	for n in cleared.size():
		if cleared[n] & ParkGraph.LINE != 0:
			cleared[n] &= ~ParkGraph.SIGHT_OK
	var real := line_sight(flags)
	var r := line_sight(cleared)
	print("PLANTED park_dam line_sight_share %.4f pass>=%.2f %s" % [r["share"], LINE_SIGHT_MIN, "PASS" if r["share"] >= LINE_SIGHT_MIN else "FAIL"])
	t.check("planted: SIGHT_OK cleared on the line nodes fails the line-sight assertion", r["share"] < LINE_SIGHT_MIN, "%.4f vs %.2f (real %.4f)" % [r["share"], LINE_SIGHT_MIN, real["share"]])


# Every park file with a bake and a graph beside it, by file name, sorted.
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


# {share, counted, skipped, holes, roofed, clear} over the 33 by 33 grid.
static func measure(park: Dictionary, ground: PackedFloat32Array, holes: PackedByteArray) -> Dictionary:
	var top_arr: Array = park["landmark"]["sight_top"]
	var top := Vector3(float(top_arr[0]), float(top_arr[1]), float(top_arr[2]))
	var decks := []
	for row in park["park_rows"]:
		if row["y"] != null:
			decks.append([Stamps.frame(row), float(row["y"])])
	var points := int(round(2.0 * HALF_M / GRID_M)) + 1
	var r := {"share": 0.0, "counted": 0, "skipped": 0, "holes": 0, "roofed": 0, "clear": 0}
	for gj in points:
		for gi in points:
			var x := -HALF_M + GRID_M * gi
			var z := -HALF_M + GRID_M * gj
			var ci := clampi(floori((x + HALF_M) / 2.0), 0, BAKE_CELLS - 1)
			var cj := clampi(floori((z + HALF_M) / 2.0), 0, BAKE_CELLS - 1)
			if holes[cj * BAKE_CELLS + ci] != 0:
				r["holes"] += 1
				r["skipped"] += 1
				continue
			var h := height(ground, x, z)
			var roofed := false
			for d in decks:
				if Stamps.inside(d[0], x, z) and float(d[1]) > h + ROOF_M:
					roofed = true
					break
			if roofed:
				r["roofed"] += 1
				r["skipped"] += 1
				continue
			r["counted"] += 1
			if clear_ray(ground, Vector3(x, h + EYE_M, z), top):
				r["clear"] += 1
	if r["counted"] > 0:
		r["share"] = float(r["clear"]) / float(r["counted"])
	return r


# Samples every SAMPLE_M of planar distance strictly between the eye and the target.
static func clear_ray(ground: PackedFloat32Array, from: Vector3, to: Vector3) -> bool:
	var planar := Vector2(to.x - from.x, to.z - from.z).length()
	if planar <= SAMPLE_M:
		return true
	var steps := floori(planar / SAMPLE_M)
	for s in range(1, steps + 1):
		var d := s * SAMPLE_M
		if d >= planar:
			break
		var p := from.lerp(to, d / planar)
		if height(ground, p.x, p.z) > p.y:
			return false
	return true


# The ground under (x, z), bilinear over the 2 m grid of ground.bin.
static func height(ground: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var fz := clampf((z + HALF_M) / 2.0, 0.0, BAKE_SIDE - 1.001)
	var i := floori(fx)
	var j := floori(fz)
	var u := fx - i
	var v := fz - j
	var h00 := ground[j * BAKE_SIDE + i]
	var h10 := ground[j * BAKE_SIDE + i + 1]
	var h01 := ground[(j + 1) * BAKE_SIDE + i]
	var h11 := ground[(j + 1) * BAKE_SIDE + i + 1]
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), v)


# A copy of the fixture's heights with a WALL_H wall across the square fails the rule.
func _planted(park: Dictionary, bake: Dictionary) -> void:
	var walled: PackedFloat32Array = bake["ground"].duplicate()
	for vj in BAKE_SIDE:
		var z := -HALF_M + 2.0 * vj
		if z < WALL_Z[0] or z > WALL_Z[1]:
			continue
		for vi in BAKE_SIDE:
			walled[vj * BAKE_SIDE + vi] += WALL_H
	var r := measure(park, walled, bake["holes"])
	var need := float(park["landmark"]["sight_share"])
	print("[planted] %s with a %.0f m wall at z %.0f..%.0f: share %.4f counted %d" % [FIXTURE, WALL_H, WALL_Z[0], WALL_Z[1], r["share"], r["counted"]])
	t.check("planted wall drops the share below sight_share", r["share"] < need, "%.4f vs %.2f" % [r["share"], need])
	# A deck 100 m up over a 200 m square roofs its 4 by 4 grid points; one 1 m above the
	# ground roofs none.
	var high := park.duplicate(true)
	var low := park.duplicate(true)
	for pair in [[high, 100.0], [low, 41.0]]:
		var deck: Dictionary = park["park_rows"][0].duplicate(true)
		deck["id"] = "planted_roof"
		deck["at"] = [-575, -575]
		deck["size"] = [190, 2, 190]
		deck["stamp"] = ""
		deck["y"] = pair[1]
		pair[0]["park_rows"].append(deck)
	var base := measure(park, bake["ground"], bake["holes"])
	var roofed := measure(high, bake["ground"], bake["holes"])
	var floor_level := measure(low, bake["ground"], bake["holes"])
	print("[planted] roof 100 m up: roofed %d (fixture %d); roof 1 m above the ground: roofed %d" % [roofed["roofed"], base["roofed"], floor_level["roofed"]])
	t.eq("planted high deck roofs 16 more grid points", roofed["roofed"] - base["roofed"], 16)
	t.eq("planted deck within ROOF_M of the ground roofs none", floor_level["roofed"], base["roofed"])
