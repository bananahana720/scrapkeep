extends "res://tests/work_machines_test.gd"

# Finds spots for a looping worker (work_machines.gd) that pass every placement check in
# tests/work_machines_test.gd: a 20 m grid, eight yaws, 38 to 110 m off the pilot lines, best sight first.
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/work_machines_scan.gd -- <park> <kind>
# Prints "CAND seen=<share> at=(x,z) yaw=<deg> gap=<m to the nearest line> spread=<m of ground under the footings>".

func _main() -> void:
	await process_frame
	var map_id := OS.get_cmdline_user_args()[0]
	var kind := OS.get_cmdline_user_args()[1]
	var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
	var park: Dictionary = map.park
	var lines := _lines(park)
	var heights := ParkTerrain._read_zstd(ParkTerrain.bake_dir(map_id) + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	var out := []
	for x in range(-700, 700, 20):
		for z in range(-760, 640, 20):
			var at := Vector2(x, z)
			var gap := _line_gap(at, lines)
			if gap < 38.0 or gap > 110.0:
				continue
			for yaw in [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0]:
				var row := {"id": "c", "kind": kind, "at": at, "yaw_deg": yaw}
				var res := _judge(row, park, lines, heights)
				if res.ok:
					out.append([res.seen, x, z, yaw, gap, res.spread])
	out.sort_custom(func(a, b): return a[0] > b[0])
	for r in out.slice(0, 400):
		print("CAND seen=%.2f at=(%d,%d) yaw=%d gap=%.0f spread=%.2f" % r)
	quit(0)


func _judge(row: Dictionary, park: Dictionary, lines: Array, heights: PackedFloat32Array) -> Dictionary:
	var kind: Dictionary = WorkMachines.KINDS[row.kind]
	var basis := Basis(Vector3.UP, deg_to_rad(float(row.yaw_deg)))
	var pts := [row.at]
	for box in kind.solid:
		for cx in [-0.5, 0.5]:
			for cz in [-0.5, 0.5]:
				var c: Vector3 = basis * (box.at + Vector3(box.size.x * cx, 0.0, box.size.z * cz))
				pts.append(row.at + Vector2(c.x, c.z))
	var lo := INF
	var hi := -INF
	for p in pts:
		if _line_gap(p, lines) < LINE_CLEAR_M:
			return {"ok": false}
		var y := Terrain._grid_height(heights, p.x, p.y)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	if hi - lo > FOOT_SPREAD_M:
		return {"ok": false}
	if kind.has("reach_m"):
		var sweep := _span(row.kind, "slew_deg")
		for i in 11:
			var slew := deg_to_rad(lerpf(sweep.x, sweep.y, i / 10.0))
			var tip: Vector3 = Basis(Vector3.UP, deg_to_rad(float(row.yaw_deg)) + slew) * Vector3(0.0, 0.0, -float(kind.reach_m))
			var p: Vector2 = row.at + Vector2(tip.x, tip.z)
			if _line_gap(p, lines) < TIP_CLEAR_M:
				return {"ok": false}
			pts.append(p)
	for park_row in park.park_rows:
		if park_row.element == "ground":
			continue
		if maxf(float(park_row.size[0]), float(park_row.size[2])) > 300.0:
			continue
		for p in pts:
			if _row_gap(p, park_row) < ROW_CLEAR_M:
				return {"ok": false}
	var seen := _seen_from_lines(row, lines, heights)
	if seen.x < 0.6:
		return {"ok": false}
	return {"ok": true, "seen": seen.x, "spread": hi - lo}
