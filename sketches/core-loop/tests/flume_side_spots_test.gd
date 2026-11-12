extends SceneTree

# W1-17 (issue 832): two more side spots on the flume, toward the 30-minute completionist run.
#   trestle_cache  a standing cracked_cache on the low canal country under the flume trestle's turn,
#                  seen from the flume grind above; the flume's second reward pocket (PARK.md 2.12,
#                  OFFLINE_MAX 2; the pocket rules themselves are park_park_flume_test's).
#   grade_wall     a hidden cache room on the canal grade west of the trestle hollow, sealed by a
#                  cracked wall (contraptions.gd, a cracked_wall with a cache, as a valve's door seals
#                  the weir cache). No marker. A ram at speed crumbles the wall, puts a part on the
#                  pedestal and files the codex row the camp counts (secrets.gd WORLD_CODEX).
# Checks:
#   (a) both rows exist; the wall stands across its room's mouth (cache at + face x CACHE_LANE_OFFSET),
#       turned to the face and as wide as the room; its codex id counts at the camp.
#   (b) both spots keep SPOT_CLEAR_M from every fight site (ParkMap.fight_sites), field-find spot, other
#       activity and contraption, and LINE_CLEAR_M from every authored line leg (six pilots and the floor
#       line), so no line rides into a room.
#   (c) the sealed room opens onto reachable ground: level within RUN_M of its mouth, no ledge behind.
#   (d) in the game: the flume's four cache rooms roll four part streams; the room is built shut and unmarked, a bump under the ram's bar leaves the wall,
#       a ram at cruise crumbles it and files flume_grade_cache, the ball takes the part, and a stage
#       retry seals the room again.
# Planted: the wall moved 3 m off the mouth fails (a); a spot on Tarn's line, or beside the bend cache, fails (b).

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Secrets := preload("res://src/core/secrets.gd")

const PARK := "res://src/world/park/park_flume.json"
const LINES := "res://assets/park/park_flume/lines.json"
const SPOT_CLEAR_M := 60.0
const LINE_CLEAR_M := 20.0
const RUN_M := 16.0
const CLIMB_M := 2.0
const RISE_M := 4.0
const BACK_M := 20.0
const MOUTH_EPS_M := 0.1
const TURN_EPS := 0.01

var _t := T.new("flume_side_spots_test")


class Kit:
	var sprinting := false
	var gliding := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PARK))
	var cache := _row(park["activity_rows"], "trestle_cache")
	var wall := _row(park["contraption_rows"], "grade_wall")
	if not _t.check("both rows exist", not cache.is_empty() and not wall.is_empty()):
		quit(_t.verdict())
		return
	_t.check("trestle_cache is a cracked_cache", cache["activity"] == "cracked_cache")
	_t.eq("grade_wall stands across its room's mouth", _mouth_error(wall), [])
	var moved: Dictionary = wall.duplicate(true)
	moved["at"] = [float(wall["at"][0]) + 3.0, float(wall["at"][1])]
	_t.check("planted: the wall 3 m off the mouth fails", not _mouth_error(moved).is_empty())
	_t.check("flume_grade_cache counts at the camp", (Secrets.WORLD_CODEX[1] as Array).has(String(wall["codex"]["id"])))

	var map := ParkMap.new(PARK)
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINES))
	var spots := {"trestle_cache": _v(cache["at"]), "grade_wall": _v(wall["cache"]["at"])}
	for id in spots:
		_t.eq("%s keeps clear of the park's other content" % id, _crowded(map, park, id, spots[id]), [])
		_t.eq("%s keeps clear of every line" % id, _on_lines(park, lines, spots[id]), [])
	var tarn: Array = lines["pilots"]["tarn"]["waypoints"]
	_t.check("planted: a spot on Tarn's line fails", not _on_lines(park, lines, _v(tarn[10])).is_empty())
	_t.check("planted: a spot beside the bend cache is crowded", not _crowded(map, park, "trestle_cache", Vector2(42, -60)).is_empty())

	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var stage := -1
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if "park" in m and String(m.park.get("map", "")) == "park_flume":
			stage = i + 1
	game.flow.enter_stage(stage, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var devices = game.world.contraptions.get(stage)
	if not _t.check("the flume's contraptions are built", devices != null):
		quit(_t.verdict())
		return
	var w := {}
	for d in devices.walls:
		if d["spec"]["id"] == "grade_wall":
			w = d
	if not _t.check("grade_wall is built with its room", not w.is_empty() and is_instance_valid(w.get("cache_site"))):
		quit(_t.verdict())
		return
	var room = w["cache_site"]
	_t.check("the room has no face of its own and no marker", room.wall == null and not room.view.visible)
	var face := _v(wall["cache"]["face"]).normalized()
	var mouth := Vector2(room.global_position.x, room.global_position.z)
	_t.check("the room's mouth is where the wall stands", mouth.distance_to(_v(wall["at"])) <= MOUTH_EPS_M, str(mouth))
	var drop := _drop(game, mouth, face)
	_t.check("the room has a level run-up", drop <= CLIMB_M, "ground lies %.1f m below its floor within %.0f m" % [drop, RUN_M])
	var back := _back_rise(game, mouth, face)
	_t.check("the room stands clear of a ledge above", back <= RISE_M, "ground rises %.1f m within %.0f m behind" % [back, BACK_M])

	var acts = game.world.activities
	var streams := {}
	for s in acts.sites:
		if is_instance_valid(s) and s.id == "cracked_cache" and not s.drawn and not s.has_meta("find"):
			streams[acts._luck_id(s)] = true
	for d in devices.valves + devices.walls:
		if is_instance_valid(d.get("cache_site")):
			streams[acts._luck_id(d["cache_site"])] = true
	_t.check("the flume's four cache rooms roll four streams", streams.size() == 4, str(streams.keys()))

	var kit := Kit.new()
	var body: StaticBody3D = w["body"]
	var y: float = game.ctx.terrain.height(mouth.x, mouth.y) + 1.0
	var ball := Vector3(mouth.x, y, mouth.y) + Vector3(face.x, 0.0, face.y) * 2.5
	var inward := Vector3(-face.x, 0.0, -face.y)
	var slow: Array = devices.step(1.0 / 90.0, ball, inward * devices.cruise * 0.5, kit, false)
	_t.check("a bump under the ram's bar leaves the wall", not w["broken"] and body.visible, str(slow))
	var facts: Array = devices.step(1.0 / 90.0, ball, inward * devices.cruise, kit, false)
	_t.check("a ram at cruise crumbles the wall", w["broken"])
	_t.check("the ram files flume_grade_cache and no tunnel row", facts.any(func(f): return f["kind"] == "codex" and f["id"] == "flume_grade_cache")
		and not facts.any(func(f): return f["kind"] == "codex" and f["id"] == "sprint_through"), str(facts))
	_t.eq("the codex knows the row before it is found", game.ctx.codex.name_of("flume_grade_cache"), "Overtime Locker")
	_t.check("the part waits on the pedestal", room.done and room.pickup != null)
	var parts_before: int = game.ctx.run.parts.size()
	devices.step(1.0 / 90.0, room.pickup.global_position, Vector3.ZERO, kit, false)
	_t.check("the ball takes the part", room.pickup_taken and game.ctx.run.parts.size() == parts_before + 1,
		"%d -> %d" % [parts_before, game.ctx.run.parts.size()])
	# A retry re-enters the stage, and the stage entry resets its devices (world.gd _on_stage_entered).
	game.flow.enter_stage(stage, Vector3.ZERO, true)
	await physics_frame
	_t.check("a retry seals the room again", not w["broken"] and body.visible and is_instance_valid(w.get("cache_site")) and not w["cache_site"].done,
		"broken %s visible %s room %s" % [w["broken"], body.visible, is_instance_valid(w.get("cache_site"))])
	_t.eq("expected check count", _t.checks + 1, 26)
	quit(_t.verdict())


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if r["id"] == id:
			return r
	return {}


func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# Where the wall misses its room's mouth: position, turn and width.
func _mouth_error(wall: Dictionary) -> Array:
	var out := []
	var face := _v(wall["cache"]["face"]).normalized()
	var mouth := _v(wall["cache"]["at"]) + face * Activities.CACHE_LANE_OFFSET
	if _v(wall["at"]).distance_to(mouth) > MOUTH_EPS_M:
		out.append("at %s, mouth %s" % [_v(wall["at"]), mouth])
	if absf(angle_difference(float(wall["turn"]), atan2(face.x, face.y))) > TURN_EPS:
		out.append("turn %.4f, face wants %.4f" % [float(wall["turn"]), atan2(face.x, face.y)])
	if absf(float(wall["size"][0]) - Activities.WALL_HALF_W * 2.0) > MOUTH_EPS_M:
		out.append("width %.1f" % float(wall["size"][0]))
	return out


func _crowded(map, park: Dictionary, id: String, at: Vector2) -> Array:
	var out := []
	var others := []
	for f in map.fight_sites():
		others.append(["fight " + String(f["id"]), f["at"]])
	for a in park["activity_rows"]:
		if a["id"] != id:
			others.append(["activity " + String(a["id"]), _v(a["at"])])
	for c in park["contraption_rows"]:
		if c["id"] != id:
			for key in ["at", "from", "to"]:
				if c.has(key):
					others.append(["contraption " + String(c["id"]), Vector2(float(c[key][0]), float(c[key][c[key].size() - 1]))])
			if c.has("cache"):
				others.append(["cache " + String(c["id"]), _v(c["cache"]["at"])])
	for fid in Secrets.FINDS:
		if Secrets.FINDS[fid]["map"] == "park_flume":
			for s in Secrets.FINDS[fid]["spots"]:
				others.append(["find " + String(s["site"]), _v(s["at"])])
	for o in others:
		var d: float = at.distance_to(o[1])
		if d < SPOT_CLEAR_M:
			out.append("%s %.0f m" % [o[0], d])
	return out


# Every authored line leg that passes within LINE_CLEAR_M of `at`.
func _on_lines(park: Dictionary, lines: Dictionary, at: Vector2) -> Array:
	var out := []
	var ways := {}
	for p in lines["pilots"]:
		ways[p] = lines["pilots"][p]["waypoints"]
	ways["floor"] = lines["floor"]["waypoints"]
	for name in ways:
		var pts := []
		for wp in ways[name]:
			var p = _resolve(park, wp)
			if p != null:
				pts.append(p)
		for k in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(at, pts[k], pts[k + 1])
			if q.distance_to(at) < LINE_CLEAR_M:
				out.append("%s leg %d %.0f m" % [name, k, q.distance_to(at)])
				break
	return out


func _resolve(park: Dictionary, wp):
	if wp is Array:
		return _v(wp)
	if wp == "drop_in":
		return _v(park["spawn"]["at"])
	if wp == "landmark":
		return _v(park["landmark"]["at"])
	for table in ["activity_rows", "park_rows"]:
		for r in park[table]:
			if r["id"] == wp:
				return _v(r["at"])
	return null


# The lowest ground within RUN_M out of the mouth, below the floor at the mouth, on the centre and both
# side lanes (a cross-fall would open a gap under the wall's 0.6 m sink).
func _drop(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var side := Vector2(-face.y, face.x)
	var low := 0.0
	for lane in [-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W]:
		for d in [0.0, 2.0, 4.0, 8.0, 12.0, RUN_M]:
			var p: Vector2 = at + face * d + side * lane
			low = maxf(low, absf(y0 - game.ctx.terrain.height(p.x, p.y)) if d == 0.0 else y0 - game.ctx.terrain.height(p.x, p.y))
	return low


func _back_rise(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var back := at - face * (Activities.WALL_DEPTH + 0.5)
	var side := Vector2(-face.y, face.x)
	var top := -INF
	for lane in [-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W]:
		for d in [0.0, 4.0, 8.0, 12.0, 16.0, BACK_M]:
			var p: Vector2 = back - face * d + side * lane
			top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top
