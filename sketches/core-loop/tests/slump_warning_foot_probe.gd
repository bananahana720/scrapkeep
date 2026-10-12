extends "res://tests/ground_slump_game_test.gd"

var measured_progress := {}

func _run() -> void:
	t = T.new("slump_warning_foot_probe")
	await super._run()

func _warning(state: Dictionary) -> void:
	super._warning(state)
	var crack = state.mark.get_node_or_null("CrawlingCrack")
	if crack == null:
		return
	var band := floori(float(state.get("warning_progress", 0.0)) * 3.0)
	if measured_progress.has(band):
		return
	measured_progress[band] = true
	var low := Vector3.INF
	var high := -Vector3.INF
	for vertex in crack.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		var point: Vector3 = crack.global_transform * vertex
		low = low.min(point)
		high = high.max(point)
	var park: Dictionary = game.world.event_families.natural._original_map.park
	var row: Dictionary = park.event_rows.filter(func(r): return r.id == "tailings_slump")[0]
	var width := float(Kinds.world_row(row.telegraph.form).crack_width_m)
	# The fixture's independent face is 374..376; KD3 owns its bench centre and width.
	var foot := 374.0
	if park.park_rows.any(func(r): return r.id == "pit_bench_2"):
		var bench: Dictionary = park.park_rows.filter(func(r): return r.id == "pit_bench_2")[0]
		foot = float(bench.at[0]) + float(bench.size[2]) * 0.5 - ParkTerrain.STEP * 0.5
	print("SLUMP_CRACK_BOUNDS low=%s high=%s; original foot x=%s y=%s; width=%s" % [low, high, foot, low_tread, width])
	t.check("crawling crack intersects original bench face foot band %s" % band, low.x <= foot + width and high.x >= foot - width, str([low, high]))
	t.near("crawling crack sits above original foot band %s" % band, low.y, low_tread + 0.15, 0.001)
	t.check("crawling crack retains canonical width band %s" % band, high.x - low.x <= width + 0.0001, str(high.x - low.x))
