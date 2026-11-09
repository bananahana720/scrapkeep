extends SceneTree

# Scrap on the beat along the floor line of the dam and the flume (ruling cd, Andrew 9 Nov 2026): one piece every 9.8 m
# of ground rolled, two beats at the 14 m/s cruise at 172 BPM, in eight-piece phrases with four empty beats between,
# from the drop-in to the Warden's engage ring; no gears and no fabricator hoops.
#   lay-out   scrap_field.gd trail_spots on made ground: the spacing, the phrases and the rest on the flat; the same
#             rolled distance up a slope; no piece on a ledge's face and none in a gap, with the beat kept; a phrase the
#             line ends inside left out; the same answer twice, with no rng to draw.
#   maps      park_map.gd scrap_trail for the dam and the flume: the line's floor row, from the spawn through the camp to
#             the engage ring, a gap for each built kicker the line crosses; scrap_lines stays empty (fabricators stand on scrap
#             lines, and the ruling is no hoops); the other parks and a floor line with no scrap row carry no trail.
#   schema    park_schema.gd validate_lines takes the scrap row, and a planted bad row turns it red.
#   fold      drops past the scrap cap fold into each other and leave the trail's pieces where they were laid.
#   ladder    the real field's magnet and the real scrap streak, stepped at 90 ticks a second with the ball rolling a
#             flat trail: at cruise (and at 10 m/s) each phrase climbs rungs 0 to 7 and the next starts at 0 again; at a
#             7 m/s walk nothing climbs (the planted control: the window is what carries the run).
# The real stages are park_scrap_trail_test's.

const ScrapField := preload("res://src/build/scrap_field.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const Streak := preload("res://src/presentation/streak.gd")
const T := preload("res://tests/support/t.gd")

const SPACING := 9.8
const TRAIL := {"spacing_m": SPACING, "phrase": 8, "rest": 4}
const WORLD_1 := {"park_dam": "domes_camp", "park_flume": "siphon_camp"}
const GAPS := {"park_dam": 0, "park_flume": 4}
const OTHER_PARKS := ["park_pit", "park_sinkhole", "park_islands", "park_crown", "park_test"]
const CRUISE := 14.0
const TICK := 1.0 / 90.0

var t := T.new("scrap_trail_test")


class Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_lay_out()
	_maps()
	_schema()
	_fold()
	_ladder()
	quit(t.verdict())


static func _line(length: float, extra := {}) -> Dictionary:
	return TRAIL.merged({"points": PackedVector2Array([Vector2.ZERO, Vector2(0.0, length)])}).merged(extra)


func _lay_out() -> void:
	var flat := func(_x: float, _z: float) -> float: return 0.0
	# 400 m: beats 1 to 40. Phrases on beats 1-8, 13-20 and 25-32; beats 37-40 start a phrase the line ends inside.
	var spots := ScrapField.trail_spots(_line(400.0), flat)
	t.eq("400 m of flat line lays three whole phrases", spots.size(), 24)
	var steps := []
	for i in range(1, spots.size()):
		steps.append(snappedf(spots[i - 1].distance_to(spots[i]), 0.01))
	var want := []
	for i in 23:
		want.append(snappedf(SPACING * 5.0, 0.01) if i % 8 == 7 else SPACING)
	t.eq("pieces stand 9.8 m apart, with four empty beats between phrases", steps, want)
	t.near("the first piece is one beat from the drop-in", spots[0].z, SPACING, 0.001)
	t.check("the same line lays the same pieces twice", spots == ScrapField.trail_spots(_line(400.0), flat))
	t.eq("a line shorter than a phrase lays nothing", ScrapField.trail_spots(_line(70.0), flat).size(), 0)
	t.eq("no trail, no pieces", ScrapField.trail_spots({}, flat).size(), 0)

	var slope := func(_x: float, z: float) -> float: return z * 0.3
	spots = ScrapField.trail_spots(_line(400.0), slope)
	t.near("up a 30% slope the pieces are still 9.8 m of ground apart", spots[0].distance_to(spots[1]), SPACING, 0.01)
	t.near("and each stands on the ground", spots[3].y, spots[3].z * 0.3, 0.001)

	# A 20 m ledge whose face is the step from z 29 to 30: beat 3 (29.4 m) would stand on it.
	var ledge := func(_x: float, z: float) -> float: return 0.0 if z < 29.5 else -20.0
	spots = ScrapField.trail_spots(_line(400.0), ledge)
	var on_face := spots.filter(func(s: Vector3) -> bool: return s.z > 29.0 and s.z < 30.99)
	t.eq("no piece stands on a ledge's face", on_face.size(), 0)
	t.check("the piece the face would have held stands a step past the foot, on the low ground",
		is_equal_approx(spots[2].z, 31.0) and is_equal_approx(spots[2].y, -20.0), str(spots[2]))
	t.near("the drop is flown, not rolled: the next piece is 9.8 m of run on, not 20 m of fall", spots[3].z - spots[2].z, SPACING, 0.001)

	spots = ScrapField.trail_spots(_line(400.0, {"gaps": [[15.0, 35.0]]}), flat)
	t.check("a gap leaves its beats empty and keeps the beat after it",
		spots.size() == 22 and is_equal_approx(spots[0].z, SPACING) and is_equal_approx(spots[1].z, SPACING * 4.0),
		"%d pieces, first two at z %.1f and %.1f" % [spots.size(), spots[0].z, spots[1].z])


func _maps() -> void:
	for id: String in WORLD_1:
		var map = ParkMap.new("res://src/world/park/%s.json" % id)
		var trail: Dictionary = map.scrap_trail
		if not t.check("%s carries a scrap trail" % id, map.ok and trail.get("points", PackedVector2Array()).size() > 2):
			continue
		var points: PackedVector2Array = trail["points"]
		t.check("%s: 9.8 m apart in eight-piece phrases with a four-beat rest" % id,
			is_equal_approx(trail["spacing_m"], SPACING) and trail["phrase"] == 8 and trail["rest"] == 4, str(trail.keys()))
		t.check("%s: the trail starts at the drop-in" % id, points[0].is_equal_approx(map.spawn), str(points[0]))
		t.near("%s: and ends on the engage ring" % id, points[-1].distance_to(map.beacon), map.reach_m, 0.01)
		var camp: Vector2 = ParkMap.place_of(map.park, WORLD_1[id])
		t.check("%s: it leads through the camp" % id, camp in points, str(camp))
		# The dam's kickers are stamped into the ground; the flume's line crosses four plate kickers.
		var gaps: Array = trail["gaps"]
		t.check("%s: a gap for each built kicker the line crosses" % id,
			gaps.size() == GAPS[id] and gaps.all(func(g: Array) -> bool: return g[1] > g[0]), str(gaps))
		t.eq("%s: no scrap lines, so no gears and no fabricator hoops" % id, map.scrap_lines.size(), 0)
	for id: String in OTHER_PARKS:
		var map = ParkMap.new("res://src/world/park/%s.json" % id)
		t.check("%s carries no scrap trail" % id, map.ok and map.scrap_trail.is_empty(), str(map.errors))
	var none: Vector2 = ParkMap.place_of(ParkMap.new().park, "no_such_row")
	t.check("a waypoint the park lacks resolves to no place", none == Vector2.INF, str(none))


func _schema() -> void:
	for id: String in WORLD_1:
		var park: Dictionary = ParkSchema.read_file("res://src/world/park/%s.json" % id)["data"]
		var lines: Dictionary = ParkSchema.read_file(ParkMap.LINES_PATH % id)["data"]
		t.eq("%s lines pass the schema with their scrap row" % id, ParkSchema.validate_lines(lines, park), [])
		for bad: Dictionary in [{"spacing_m": 0, "phrase": 8, "rest": 4}, {"spacing_m": 9.8, "phrase": 0, "rest": 4}, {"spacing_m": 9.8, "phrase": 8.5, "rest": 4}, {"spacing_m": 9.8, "phrase": 8}]:
			var planted := lines.duplicate(true)
			planted["floor"]["scrap"] = bad
			var errors: Array = ParkSchema.validate_lines(planted, park)
			t.check("%s: planted scrap row %s turns the schema red" % [id, bad],
				errors.any(func(e: Dictionary) -> bool: return e["id"] == "floor.scrap"), str(errors))


# The rungs each pickup rang, as the audio's _on_scrap bumps them, over a flat 400 m trail rolled at `speed`.
func _rungs(speed: float) -> Array:
	var field = ScrapField.new()
	root.add_child(field)
	field.setup()
	field.lay_trail(Flat.new(), _line(400.0))
	var streak = Streak.for_kind("scrap_collected")
	var rungs := []
	var seconds := 0.0
	var ball := Vector3(0.0, 1.0, 0.0)
	while ball.z < 420.0:
		for _piece in field.step(ball, speed, TICK):
			rungs.append(streak.bump(roundi(seconds * 1000.0)))
		ball.z += speed * TICK
		seconds += TICK
	field.free()
	return rungs


# A long fight's drops fold the oldest loose pieces (SCRAP-LEAK); the trail is laid first, so it is the oldest.
func _fold() -> void:
	var field = ScrapField.new()
	root.add_child(field)
	field.setup()
	field.lay_trail(Flat.new(), _line(400.0))
	var laid: Array[Vector3] = field.trail_points()
	field.max_pieces = 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	field.drop(Vector3(300.0, 0.0, 300.0), 40, rng)
	t.check("drops past the cap fold into each other", field.count() <= 30, str(field.count()))
	t.check("and the 24 trail pieces all still stand where they were laid", laid.size() == 24 and field.trail_points() == laid,
		"%d of %d" % [field.trail_points().size(), laid.size()])
	field.clear()
	t.eq("clear takes the trail too", field.trail_points().size(), 0)
	field.free()


func _ladder() -> void:
	var phrase := [0, 1, 2, 3, 4, 5, 6, 7]
	t.eq("at cruise each phrase climbs the ladder once, 0 to 7", _rungs(CRUISE), phrase + phrase + phrase)
	t.eq("at 10 m/s too", _rungs(10.0), phrase + phrase + phrase)
	t.eq("at twice cruise too, and the rest still ends the run", _rungs(CRUISE * 2.0), phrase + phrase + phrase)
	var walk := _rungs(7.0)
	t.check("at a 7 m/s walk nothing climbs: the window carries the run", walk.size() == 24 and walk.max() == 0, str(walk))
