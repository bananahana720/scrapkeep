extends SceneTree

# Worn haul lanes: park files carry optional wear_rows (park_schema.gd), and ParkTerrain.paint_wear
# darkens the ground tint along each polyline whatever its direction, clamped to the map. The park is the
# test fixture with lanes added in memory. The last check builds the dam's real ground, so a park file's
# own lanes are shown to reach the painter.

const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")
const T := preload("res://tests/support/t.gd")

const FIXTURE := "res://src/world/park/park_test.json"
const DAM := "res://src/world/park/park_dam.json"
const WIDTH_M := 6.0
const WIDE_M := 12.0
const GREY := 0.6
# A shade of difference the eye can see on the 0..1 scale; the lane darkens by up to ParkTerrain.WEAR_DARKEN.
const VISIBLE_STEP := 0.02

var _t := T.new("park_wear_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = ParkSchema.load_park(FIXTURE)["data"]
	var lanes := [
		_lane("rising", [[0, 0], [0, 100]]),
		_lane("falling", [[200, 300], [200, 200], [200, 100]]),
		_lane("east_west", [[-400, 100], [-300, 100]]),
		_lane("diagonal", [[-300, -300], [-200, -200]]),
		{"id": "wide_diagonal", "points": [[200, -300], [300, -200]], "width_m": WIDE_M},
		_lane("off_edge", [[ParkTerrain.HALF - 20.0, 0], [ParkTerrain.HALF + 60.0, 0]]),
	]
	park["wear_rows"] = lanes
	_t.check("the park with wear lanes validates", ParkSchema.validate(park).is_empty(), ParkSchema.describe(ParkSchema.validate(park)))
	_paint_checks(lanes)
	_schema_checks(park)
	await _built_ground_check()
	quit(_t.verdict())


func _lane(id: String, points: Array) -> Dictionary:
	return {"id": id, "points": points, "width_m": WIDTH_M}


func _image() -> Image:
	var side := ParkTerrain.CELLS * 2 + 2 * ParkTerrain.FEATHER_MARGIN
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(GREY, GREY, GREY, 0.5))
	return image


func _luma(image: Image, x: float, z: float) -> float:
	var origin := Vector2i.ONE * (int(ParkTerrain.HALF) + ParkTerrain.FEATHER_MARGIN)
	var c := image.get_pixelv(Vector2i(roundi(x), roundi(z)) + origin)
	return (c.r + c.g + c.b) / 3.0


func _paint_checks(lanes: Array) -> void:
	var image := _image()
	ParkTerrain.paint_wear(image, lanes)
	var far := WIDTH_M * 2.0
	_t.check("a pixel on the rising lane is darker than one two widths away",
		_luma(image, 0, 50) < _luma(image, far, 50) - VISIBLE_STEP, "%.3f vs %.3f" % [_luma(image, 0, 50), _luma(image, far, 50)])
	_t.check("a lane whose z falls along its points paints",
		_luma(image, 200, 200) < _luma(image, 200 + far, 200) - VISIBLE_STEP, "%.3f" % _luma(image, 200, 200))
	_t.check("an east-west lane is worn across its width, not only along x",
		_luma(image, -350, 100) < _luma(image, -350, 100 + far) - VISIBLE_STEP, "%.3f" % _luma(image, -350, 100 + far))
	var diagonal := _luma(image, -250, -250)
	_t.check("a diagonal lane paints", diagonal < _luma(image, -250 + far, -250 - far) - VISIBLE_STEP, "%.3f" % diagonal)
	# A diagonal lane keeps its width. Count worn pixels straight across the wide diagonal lane: a painter
	# that measured width along x alone would wear about half as many.
	var worn := 0
	for k in range(-10, 11):
		worn += int(_luma(image, 250 + k, -250 - k) < GREY - VISIBLE_STEP)
	var expected := int(WIDE_M / sqrt(2.0))
	_t.check("a diagonal lane is as wide across as its width says", worn >= expected - 1, "%d worn pixels across, about %d expected" % [worn, expected])
	_t.check("a lane running off the map edge paints its on-map part", _luma(image, ParkTerrain.HALF - 10.0, 0) < GREY - VISIBLE_STEP,
		"%.3f" % _luma(image, ParkTerrain.HALF - 10.0, 0))
	var edge := int(ParkTerrain.HALF) + ParkTerrain.FEATHER_MARGIN
	_t.check("a lane running off one edge does not come back on the opposite edge",
		is_equal_approx(_luma(image, -edge, 0), GREY) and is_equal_approx(_luma(image, 0, -edge), GREY), "%.3f, %.3f" % [_luma(image, -edge, 0), _luma(image, 0, -edge)])


func _schema_checks(park: Dictionary) -> void:
	var cases := {
		"one point": _lane("lone", [[0, 0]]),
		"a point with three numbers": _lane("tall", [[0, 0], [1, 2, 3]]),
		"a zero width": {"id": "thin", "points": [[0, 0], [5, 5]], "width_m": 0},
		"no width": {"id": "bare", "points": [[0, 0], [5, 5]]},
	}
	for label in cases:
		var bad: Dictionary = park.duplicate(true)
		bad["wear_rows"].append(cases[label])
		var errors := ParkSchema.validate(bad)
		_t.check("a wear row with %s fails validation" % label, errors.any(func(e): return e["id"] == cases[label]["id"]), ParkSchema.describe(errors))


# The dam's ground built through the real path (make_render, start), once with its map and once without.
# The map is the only difference, so a darker pixel on a lane is the park file's own row reaching the painter.
func _built_ground_check() -> void:
	var map := ParkMap.new(DAM)
	var rows: Array = map.park.get("wear_rows", [])
	if not _t.check("the dam's park file carries a wear lane", not rows.is_empty(), "%d rows" % rows.size()):
		return
	var points: Array = rows[0]["points"]
	var mid: Array = points[points.size() / 2]
	var worn := await _ground_luma(map, mid[0], mid[1])
	var bare := await _ground_luma(null, mid[0], mid[1])
	_t.check("the dam's built ground is darker on its own lane than the same ground built without the park's rows",
		worn < bare - VISIBLE_STEP, "%s at (%.1f, %.1f): %.3f with the park, %.3f without" % [rows[0]["id"], mid[0], mid[1], worn, bare])


func _ground_luma(map: RefCounted, x: float, z: float) -> float:
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	await process_frame
	var render: Node3D = ParkTerrain.make_render(holder, "Render_wear")
	var ground := ParkTerrain.new()
	holder.add_child(ground)
	ground.start("park_dam", map, false, render)
	await process_frame
	var loc := Vector2i(floori(x / ParkTerrain.REGION_SIZE), floori(z / ParkTerrain.REGION_SIZE))
	var c: Color = render.data.get_region(loc).get_color_map().get_pixel(roundi(x) - loc.x * ParkTerrain.REGION_SIZE, roundi(z) - loc.y * ParkTerrain.REGION_SIZE)
	holder.queue_free()
	await process_frame
	return (c.r + c.g + c.b) / 3.0
