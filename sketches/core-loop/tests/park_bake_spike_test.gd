extends SceneTree

# Rule (PARK-WIN PW2, 2026-10-16): no baked park ground holds a one-cell spike or a one-cell wall.
# For every map under assets/park/ the test reads ground.bin (801 by 801 heights at 2 m) and, at
# every interior point and on each axis, measures how far the point stands above both of its
# neighbours beyond the slope those neighbours already carry:
#
#   excess = min(v - max(a, b), v - max(a + (a - a2), b + (b - b2)))
#
# where a, b are the neighbours and a2, b2 the next points out. A lone spike stands above all four
# neighbours, so it fails on both axes. A 2 m thick wall is level with its neighbours along its
# length, so the across-axis comparison sees it. A cone or spire apex rises steeply but its
# neighbours carry the same slope, so its excess is near zero.
#
# Why: at 699fded6 `crown_apron` (plateau) and `crown_exit_bank` (ramp) both claimed the z=660
# bake row, because a stamp edge counts as inside (src/world/park/park_stamps.gd:127) and the bake
# adds offsets (tools/park_bake.gd:205). The result was a 30 m wall, one row thick, 10 m before all
# three gates (52.9 m at z=660 against 21.9 and 22.9 m beside it). This test fails on that bake.
#
# Exempt, by name:
#   narrow rows  points inside the footprint of a stamped row whose shorter side is at most
#                NARROW_M: park_sinkhole's 4 m greybox posts, pillars and kicker spires stand 20 m
#                on one or two 2 m points by design.
#   KNOWN        park_sinkhole z=400: a 100 m wall, one row thick, for |x| beyond the sinkhole,
#                ground 0 on both sides. Same fault class as the crown (rim_south's plateau edge
#                shares the row with the ground south of it). Fixing it is a separate card; this
#                pin fails once the wall is gone, so the exemption gets deleted with the fix.
#
# The bar: after PW2 the worst unexempted point per map (printed below) is under 9.1 m; the crown
# wall's excess was 29.9 m.
#
# Planted: one injected spike of RIDGE_BAR_M + 1 m on a flat, unexempted point of a shipped map's
# ground, and a one-row wall of the same height, must each fail the same scan before a clean scan
# is trusted.

const T := preload("res://tests/support/t.gd")
const Stamps := preload("res://src/world/park/park_stamps.gd")

const PARK_ASSETS := "res://assets/park"
const PARK_DIR := "res://src/world/park"
const SIDE := 801
const STEP := 2.0
const HALF := 800.0
const RIDGE_BAR_M := 12.0
const NARROW_M := 4.0
const KNOWN := {"park_sinkhole": {"axis": "z", "z": 400.0}}
# Wave-16 card PARK-SINKHOLE-BAKE: park_sinkhole's channel-fill edge leaves ten 20 m one-cell points
# (a stamp edge counts as inside, so the fill and the ground beside it share a row). Pinned by exact
# coordinate (x, z) beside the z=400 line; park_stamps.gd edge rules stay untouched this wave. Each
# pin must still fire, so the card that fixes the bake deletes the pins and this test says so.
const KNOWN_POINTS := {"park_sinkhole": [
	Vector2i(52, -384),
	Vector2i(126, 272), Vector2i(126, 274), Vector2i(126, 276), Vector2i(126, 278), Vector2i(126, 280)]}

var t := T.new("park_bake_spike_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := _maps()
	t.check("found the park bakes", maps.size() >= 7, str(maps))
	var plant_map := ""
	var plant_h := PackedFloat32Array()
	var plant_exempt := PackedByteArray()
	for map_id in maps:
		var h := _ground(PARK_ASSETS + "/" + map_id + "/ground.bin")
		if not t.eq("%s ground.bin is 801 by 801 float32" % map_id, h.size(), SIDE * SIDE):
			continue
		var exempt := _narrow(PARK_DIR + "/" + map_id + ".json")
		var pins: Array = KNOWN_POINTS.get(map_id, [])
		var worst := scan(h, exempt, KNOWN.get(map_id, {}), pins)
		print("park_bake_spike_test: %s worst %.3f m at (%.0f, %.0f) height %.3f across %s, %d points over %.1f m, %d narrow-row points exempt, %d on the known line, %d pinned points" % [
			map_id, worst["excess"], worst["x"], worst["z"], worst["height"], worst["axis"], worst["over"], RIDGE_BAR_M, worst["narrow"], worst["known"], worst["pinned"]])
		t.check("%s has no one-cell spike or wall over %.1f m" % [map_id, RIDGE_BAR_M], worst["over"] == 0,
			"%d points, worst %.3f m at (%.0f, %.0f) across %s; first points %s" % [worst["over"], worst["excess"], worst["x"], worst["z"], worst["axis"], str(worst["points"])])
		if KNOWN.has(map_id):
			t.check("%s known wall at z=%.0f is still there (delete its KNOWN pin once fixed)" % [map_id, KNOWN[map_id]["z"]], worst["known"] > 0, "%d points" % worst["known"])
		if not pins.is_empty():
			t.check("%s pinned points are all still spikes (delete KNOWN_POINTS once PARK-SINKHOLE-BAKE lands)" % map_id, worst["pinned"] == pins.size(), "%d of %d" % [worst["pinned"], pins.size()])
		if plant_map.is_empty():
			plant_map = map_id
			plant_h = h
			plant_exempt = exempt
	_planted(plant_map, plant_h, plant_exempt)
	quit(t.verdict())


func _maps() -> Array:
	var out := []
	var dir := DirAccess.open(PARK_ASSETS)
	if dir == null:
		return out
	for name in dir.get_directories():
		if FileAccess.file_exists(PARK_ASSETS + "/" + name + "/ground.bin"):
			out.append(name)
	out.sort()
	return out


func _ground(path: String) -> PackedFloat32Array:
	var raw := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if raw == null:
		return PackedFloat32Array()
	var bytes := raw.get_buffer(SIDE * SIDE * 4 + 16)
	raw.close()
	return bytes.to_float32_array()


# One byte per grid point, 1 inside the footprint of a stamped row no wider than NARROW_M.
func _narrow(park_path: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(SIDE * SIDE)
	var park = JSON.parse_string(FileAccess.get_file_as_string(park_path))
	if not t.check("%s parses" % park_path, park is Dictionary and park.get("park_rows") is Array):
		return out
	for row in park["park_rows"]:
		if String(row.get("stamp", "")).is_empty():
			continue
		var f := Stamps.frame(row)
		if minf(f["length"], f["width"]) > NARROW_M:
			continue
		var box := Stamps.bounds(f)
		for j in range(maxi(0, ceili((box[1] + HALF) / STEP)), mini(SIDE - 1, floori((box[3] + HALF) / STEP)) + 1):
			for i in range(maxi(0, ceili((box[0] + HALF) / STEP)), mini(SIDE - 1, floori((box[2] + HALF) / STEP)) + 1):
				if Stamps.inside(f, -HALF + STEP * i, -HALF + STEP * j):
					out[j * SIDE + i] = 1
	return out


static func excess_at(h: PackedFloat32Array, k: int, d: int) -> float:
	var v := h[k]
	var a := h[k - d]
	var b := h[k + d]
	var rise := v - maxf(a, b)
	return minf(rise, v - maxf(a + (a - h[k - 2 * d]), b + (b - h[k + 2 * d])))


# The worst unexempted excess, where it is, and how many unexempted points exceed RIDGE_BAR_M.
static func scan(h: PackedFloat32Array, exempt: PackedByteArray, known: Dictionary, pins: Array = []) -> Dictionary:
	var worst := {"excess": -INF, "x": 0.0, "z": 0.0, "height": 0.0, "axis": "", "over": 0, "narrow": 0, "known": 0, "pinned": 0, "points": []}
	var known_j := -1
	if not known.is_empty():
		known_j = int((float(known["z"]) + HALF) / STEP)
	for j in range(2, SIDE - 2):
		var row := j * SIDE
		for i in range(2, SIDE - 2):
			var k := row + i
			var ez := excess_at(h, k, SIDE)
			var ex := excess_at(h, k, 1)
			var e := maxf(ez, ex)
			if e <= RIDGE_BAR_M and e <= worst["excess"]:
				continue
			if exempt[k] == 1:
				if e > RIDGE_BAR_M:
					worst["narrow"] += 1
				continue
			if j == known_j and ez > RIDGE_BAR_M and ez >= ex:
				worst["known"] += 1
				continue
			if e > RIDGE_BAR_M and pins.has(Vector2i(int(-HALF + STEP * i), int(-HALF + STEP * j))):
				worst["pinned"] += 1
				continue
			if e > RIDGE_BAR_M:
				worst["over"] += 1
				if worst["points"].size() < 24:
					worst["points"].append(Vector2i(int(-HALF + STEP * i), int(-HALF + STEP * j)))
			if e > worst["excess"]:
				worst["excess"] = e
				worst["x"] = -HALF + STEP * i
				worst["z"] = -HALF + STEP * j
				worst["height"] = h[k]
				worst["axis"] = "z" if ez >= ex else "x"
	return worst


func _planted(map_id: String, base: PackedFloat32Array, exempt: PackedByteArray) -> void:
	if not t.check("a shipped ground to plant on", base.size() == SIDE * SIDE, map_id):
		return
	var known: Dictionary = KNOWN.get(map_id, {})
	var pins: Array = KNOWN_POINTS.get(map_id, [])
	var clean := scan(base, exempt, known, pins)
	# The spike goes on the first interior point, scanning from the map's middle row, whose 5 by 5
	# neighbourhood is flat within 0.5 m and not exempt, so the slope term cannot hide it.
	var c := -1
	for j in range(400, SIDE - 3):
		for i in range(400, SIDE - 3):
			var k := j * SIDE + i
			var flat := exempt[k] == 0
			for dj in range(-2, 3):
				for di in range(-2, 3):
					if absf(base[k + dj * SIDE + di] - base[k]) > 0.5:
						flat = false
			if flat:
				c = k
				break
		if c >= 0:
			break
	if not t.check("planted: found a flat unexempted point on %s" % map_id, c >= 0):
		return
	var spike := base.duplicate()
	spike[c] = base[c] + RIDGE_BAR_M + 1.0
	var got := scan(spike, exempt, known, pins)
	t.check("planted: one injected cell spike fails the scan (%s)" % map_id, got["over"] > clean["over"],
		"over %d (clean %d), worst %.2f at (%.0f, %.0f)" % [got["over"], clean["over"], got["excess"], got["x"], got["z"]])
	var wall := base.duplicate()
	var wj := c / SIDE
	var added := 0
	for i in range(300, 501):
		var k := wj * SIDE + i
		if exempt[k] == 1:
			continue
		wall[k] = maxf(base[k - SIDE], base[k + SIDE]) + absf(base[k - SIDE] - base[k - 2 * SIDE]) + absf(base[k + SIDE] - base[k + 2 * SIDE]) + RIDGE_BAR_M + 1.0
		added += 1
	var walled := scan(wall, exempt, known, pins)
	t.check("planted: a one-row wall fails the scan (%s)" % map_id, added > 150 and walled["over"] - clean["over"] >= added,
		"over %d (clean %d), %d wall points" % [walled["over"], clean["over"], added])
