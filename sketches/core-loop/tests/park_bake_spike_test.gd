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
#
# No other exemption exists. park_sinkhole used to carry a KNOWN z=400 wall row (672 points) and ten
# pinned 20 m channel-fill-edge points (PARK-SINKHOLE-BAKE). Cause: stamps add, so two plateaus that
# share an edge row (rim_east and rim_south at z=400) or overlap by a sliver (20 m fills against each
# other or across a rim's edge) stack to double height on the shared grid points. The fix belongs in
# the park rows: a bake-wide max-merge of plateaus moved flume and islands ground by up to 30 m.
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
var t := T.new("park_bake_spike_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var maps := _maps()
	t.check("found the park bakes", maps.size() >= 7, str(maps))
	for map_id in maps:
		var h := _ground(PARK_ASSETS + "/" + map_id + "/ground.bin")
		if not t.eq("%s ground.bin is 801 by 801 float32" % map_id, h.size(), SIDE * SIDE):
			continue
		var exempt := _narrow(PARK_DIR + "/" + map_id + ".json")
		var worst := scan(h, exempt)
		print("park_bake_spike_test: %s worst %.3f m at (%.0f, %.0f) height %.3f across %s, %d points over %.1f m, %d narrow-row points exempt" % [
			map_id, worst["excess"], worst["x"], worst["z"], worst["height"], worst["axis"], worst["over"], RIDGE_BAR_M, worst["narrow"]])
		t.check("%s has no one-cell spike or wall over %.1f m" % [map_id, RIDGE_BAR_M], worst["over"] == 0,
			"%d points, worst %.3f m at (%.0f, %.0f) across %s; first points %s" % [worst["over"], worst["excess"], worst["x"], worst["z"], worst["axis"], str(worst["points"])])
		_planted(map_id, h, exempt)
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
static func scan(h: PackedFloat32Array, exempt: PackedByteArray) -> Dictionary:
	var worst := {"excess": -INF, "x": 0.0, "z": 0.0, "height": 0.0, "axis": "", "over": 0, "narrow": 0, "points": []}
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


# A copy of base with a one-point-thick wall on line `at` (a row index for axis "z", a column index
# for axis "x") from index `from` to `to`, each point standing RIDGE_BAR_M + 1 m over the slope its
# neighbours carry. Returns {"h", "added"}; exempt points are skipped.
static func with_wall(base: PackedFloat32Array, exempt: PackedByteArray, axis: String, at: int, from: int, to: int) -> Dictionary:
	var out := base.duplicate()
	var d := SIDE if axis == "z" else 1
	var added := 0
	for n in range(from, to + 1):
		var k := at * SIDE + n if axis == "z" else n * SIDE + at
		if exempt[k] == 1:
			continue
		var a := base[k - d]
		var b := base[k + d]
		out[k] = maxf(a, b) + absf(a - base[k - 2 * d]) + absf(b - base[k + 2 * d]) + RIDGE_BAR_M + 1.0
		added += 1
	return {"h": out, "added": added}


# Every map gets the same planted controls, so a path that stops counting fails here, not silently:
# a lone spike, a short one-point-wide column (the shape a pair of overlapping 20 m fills leaves),
# a partial and a full-width z-row wall (the z=400 shape), an x-column wall, and the narrow-row
# exemption (a spike on an exempt point is counted as narrow, not over).
func _planted(map_id: String, base: PackedFloat32Array, exempt: PackedByteArray) -> void:
	var clean := scan(base, exempt)
	# The first interior point from the map's middle whose 5 by 5 neighbourhood is flat within 0.5 m
	# and not exempt, so the slope term cannot hide what is planted.
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
	var got := scan(spike, exempt)
	t.check("planted: one injected cell spike fails the scan (%s)" % map_id, got["over"] == clean["over"] + 1,
		"over %d (clean %d), worst %.2f at (%.0f, %.0f)" % [got["over"], clean["over"], got["excess"], got["x"], got["z"]])
	# The same spike on an exempt point is counted as narrow and does not add to over.
	var exempt_c := exempt.duplicate()
	exempt_c[c] = 1
	var narrow := scan(spike, exempt_c)
	t.check("planted: the narrow-row exemption takes only the exempt point (%s)" % map_id,
		narrow["over"] == clean["over"] and narrow["narrow"] == clean["narrow"] + 1,
		"over %d (clean %d), narrow %d (clean %d)" % [narrow["over"], clean["over"], narrow["narrow"], clean["narrow"]])
	# Channel-fill-edge shape: five points in a z line, one point wide across x, 20 m up on flat ground.
	var column := base.duplicate()
	var column_n := 0
	for dj in range(-2, 3):
		var kc := c + dj * SIDE
		if exempt[kc] == 0 and absf(base[kc] - base[c]) <= 0.5:
			column[kc] = base[c] + 20.0
			column_n += 1
	var col_got := scan(column, exempt)
	t.check("planted: a one-point-wide 20 m column fails the scan (%s)" % map_id, column_n == 5 and col_got["over"] - clean["over"] >= 3,
		"over %d (clean %d), %d column points" % [col_got["over"], clean["over"], column_n])
	var wj := c / SIDE
	var wi := c % SIDE
	var part := with_wall(base, exempt, "z", wj, 300, 500)
	var walled := scan(part["h"], exempt)
	t.check("planted: a partial z-row wall fails the scan (%s)" % map_id, part["added"] > 150 and walled["over"] - clean["over"] >= part["added"],
		"over %d (clean %d), %d wall points" % [walled["over"], clean["over"], part["added"]])
	var full := with_wall(base, exempt, "z", wj, 2, SIDE - 3)
	var full_got := scan(full["h"], exempt)
	t.check("planted: a full-width z-row wall fails the scan (%s)" % map_id, full["added"] > 600 and full_got["over"] - clean["over"] >= full["added"],
		"over %d (clean %d), %d wall points" % [full_got["over"], clean["over"], full["added"]])
	var col_wall := with_wall(base, exempt, "x", wi, 300, 500)
	var col_wall_got := scan(col_wall["h"], exempt)
	t.check("planted: an x-column wall fails the scan (%s)" % map_id, col_wall["added"] > 150 and col_wall_got["over"] - clean["over"] >= col_wall["added"],
		"over %d (clean %d), %d wall points" % [col_wall_got["over"], clean["over"], col_wall["added"]])
