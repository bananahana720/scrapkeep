extends SceneTree

const T := preload("res://tests/support/t.gd")
const ParkBake := preload("res://tools/park_bake.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Terrain := preload("res://src/world/terrain.gd")
const Warden := preload("res://src/combat/warden.gd")
const Roster := preload("res://src/combat/roster.gd")
const Tuning := preload("res://src/movement/tuning.gd")

const PARK := "res://src/world/park/park_dam.json"
const BAKED := "res://assets/park/park_dam"
const APPROACH := "reactor_approach"
const AT := [0.0, 565.0]
const SIZE := [60.0, 24.0, 60.0]
const ANCHOR := [0.0, 22.0, 590.0]

func _initialize() -> void:
	var t := T.new("park_reactor_approach_test")
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var w: Dictionary = park.landmark.warden
	t.eq("only the authored reactor dam-face mounting receives this approach", [w.family, w.mounting, w.anchor], [Roster.REACTOR, "dam_face", ANCHOR])
	var rows: Array = park.park_rows.filter(func(row): return row.id == APPROACH)
	t.eq("one ramp joins the toe apron to the mounted reactor", rows.size(), 1)
	if rows.size() == 1:
		var row: Dictionary = rows[0]
		t.eq("the approach remains at its measured position", row.at, AT)
		t.eq("the readable climb keeps its measured dimensions", row.size, SIZE)
		t.eq("the ramp rises toward the dam face", [row.stamp, row.yaw_deg, row.y], ["ramp", 180.0, null])
	var file := FileAccess.open_compressed(BAKED + "/ground.bin", FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var ground := file.get_buffer(file.get_length()).to_float32_array()
	t.eq("baked ground grid is complete", ground.size(), 801 * 801)
	if ground.size() == 801 * 801:
		var last := Terrain._grid_height(ground, 0, 537)
		var max_step := 0.0
		for z in range(539, 589, 2):
			var height := Terrain._grid_height(ground, 0, z)
			max_step = maxf(max_step, height - last)
			last = height
		t.check("rolling approach climbs without a wall", max_step <= 2.0, "largest 2m rise %.2f" % max_step)
		for x in [-2.0, 0.0, 2.0]:
			var floor_y := Terrain._grid_height(ground, x, float(ANCHOR[2]) - Warden.RADIUS)
			var ball_y := floor_y + Tuning.RADIUS
			t.check("rolling ball reaches the mounted body at x=%s" % x,
				absf(ball_y - float(ANCHOR[1])) <= Warden.HALF_HEIGHT + Tuning.RADIUS,
				"floor %.2f, ball %.2f, body %.2f" % [floor_y, ball_y, float(ANCHOR[1])])
	t.check("park_dam bake is fresh", ParkBake.freshness(PARK, BAKED).is_empty())
	t.check("park_dam graph is fresh", GraphTool.freshness(PARK, BAKED, BAKED).is_empty())
	for name in DirAccess.get_files_at("res://src/world/park"):
		if not name.ends_with(".json") or name == "park_dam.json":
			continue
		var other: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/" + name))
		t.check("the reactor approach stays out of " + name,
			other.get("park_rows", []).all(func(row): return row.id != APPROACH))
	t.eq("the pulse ring is still 30m", Warden.DEFAULT_REACH, 30.0)
	quit(t.verdict())
