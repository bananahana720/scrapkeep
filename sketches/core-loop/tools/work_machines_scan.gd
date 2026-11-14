extends "res://tests/work_machines_test.gd"

# Finds spots for a looping worker (work_machines.gd) that pass every placement check in
# tests/work_machines_test.gd: a 20 m grid, eight yaws, 38 to 110 m off the pilot lines, best sight first.
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/work_machines_scan.gd -- <park> <kind>
# Prints "CAND seen=<share> at=(x,z) yaw=<deg> gap=<m to the nearest line> near=<m to the nearest line point that sees it>".

func _main() -> void:
	await process_frame
	var map_id := OS.get_cmdline_user_args()[0]
	var kind := OS.get_cmdline_user_args()[1]
	var map := ParkMap.new("res://src/world/park/%s.json" % map_id)
	var park: Dictionary = map.park
	var lines := _lines(park)
	var heights := ParkTerrain._read_zstd(ParkTerrain.bake_dir(map_id) + "/ground.bin", ParkTerrain.SIDE * ParkTerrain.SIDE * 4).to_float32_array()
	_scatter = _scatter_of(map_id, map, heights)
	var out := []
	for x in range(-700, 700, 20):
		for z in range(-760, 640, 20):
			var at := Vector2(x, z)
			var gap := _line_gap(at, lines)
			if gap < 38.0 or gap > 110.0:
				continue
			for yaw in [0.0, 45.0, 90.0, 135.0, 180.0, -135.0, -90.0, -45.0]:
				var row := {"id": "c", "kind": kind, "at": at, "yaw_deg": yaw}
				var j := _judge(row, park, lines, heights)
				var ok: bool = j.spread <= FOOT_SPREAD_M and j.foot_gap >= LINE_CLEAR_M and j.get("tip_gap", INF) >= TIP_CLEAR_M
				ok = ok and j.home_gap >= HOME_CLEAR_M and j.beacon_gap >= j.ring and j.seen >= 0.6 and j.near_seen <= NEAR_SEEN_M[kind] and j.props_inside.is_empty() and j.rows.is_empty() and j.tall.is_empty()
				if ok:
					out.append([j.seen, x, z, yaw, gap, j.near_seen])
	out.sort_custom(func(a, b): return a[0] > b[0])
	for r in out.slice(0, 400):
		print("CAND seen=%.2f at=(%d,%d) yaw=%d gap=%.0f near=%.0f" % r)
	quit(0)
