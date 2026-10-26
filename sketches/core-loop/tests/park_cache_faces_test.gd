extends SceneTree

# Every park cracked_cache opens onto ground a ball can reach, and no cliff can drop a ball into it:
#   face  the ground out from its open face rises no more than RISE_M within NEAR_M, so a cliff never
#         stands across its mouth (a long slope up the run-up is fine).
#   back  the ground behind its back wall rises no more than RISE_M within BACK_M, so a ball rolling
#         off a ledge above never lands inside the open-topped room, where its walls box it in.
# The flume's bend_cache failed both (24 Oct): it took the rule's north face into a 15 m cliff 4 m
# away, and then, faced south, still stood at that cliff's foot, so explorer bots that rolled off
# the top landed in the room at y 30. Its row now faces south (activity_rows "face", park_map.gd)
# and stands at [42, -96], beyond the reach of a ball launched off the cliff top at speed.
#
# Secret spots (secrets.gd FINDS, DOOR and ROOMS) are checked spot by spot from the table, not only the
# ones this run drew, and on top of the two checks above:
#   mouth the ground out to RUN_M in front of the face never lies more than CLIMB_M below the room's
#         floor, so a ball rolled at the face neither falls into a slot on the way nor climbs to it.
#         Two dam spots failed it (26 Oct): the radio's service_ledge face looked across a 24 m slot,
#         so a roll at it fell in 0 of 6 times and only a jump broke it; the turbine seep's powerhouse
#         face stood atop an 18 degree ramp, 5.3 m over 16 m, and a boosted roll up it reached the face
#         under cruise and broke it 0 of 18 times. The seep now stands mid-deck (120, 530) facing north.
#   back  as above, but also behind both side walls (the first-win rooms keep the centreline).
#
# Planted: the bend_cache back at its old spot fails both checks; the radio's old service_ledge spot
# and the seep's old powerhouse spot fail the mouth check; the radio's first slot_fin_far draft, square
# north beside the fin, fails the side-wall back check.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Activities := preload("res://src/world/activities.gd")
const Secrets := preload("res://src/core/secrets.gd")

const NEAR_M := 8.0
const RISE_M := 4.0
const BACK_M := 20.0
const RUN_M := 16.0
const CLIMB_M := 2.0
# The bend_cache's old room: the site [42, -142] moved CACHE_LANE_OFFSET out along its south face.
const OLD_BEND := Vector2(42.0, -136.0)
# The dam radio's old service_ledge spot (#492), facing north across the slot.
const OLD_LEDGE := {"at": [-184, 488], "face": [0, -1]}
# The turbine seep's old powerhouse spot (#413), facing north down the deck's ramp.
const OLD_POWERHOUSE := {"at": [120, 488], "face": [0, -1]}
# The radio's first slot_fin_far draft, its east wall under the fin's crest.
const FIN_DRAFT := {"at": [44, -243], "face": [0, -1]}

var _t := T.new("park_cache_faces_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var caches := 0
	var spots := 0
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if not "park" in m:
			continue
		var map_id := String(m.park.get("map", ""))
		game.flow.enter_stage(i + 1, Vector3.ZERO, false)
		await physics_frame
		await physics_frame
		for s in game.world.activities.sites:
			# The park's own cracked_cache rows and the field finds; other caches draw their spots per run.
			if not is_instance_valid(s) or s.id != "cracked_cache" or not (s.has_meta("find") or _authored(m, s)):
				continue
			caches += 1
			var face: Vector2 = s.rule["face"]
			var at := Vector2(s.global_position.x, s.global_position.z)
			var rise := _rise(game, at, face)
			_t.check("%s %s opens onto reachable ground" % [map_id, s.name], rise <= RISE_M,
				"ground rises %.1f m within %.0f m of its face %s" % [rise, NEAR_M, face])
			var back := _back_rise(game, at, face)
			_t.check("%s %s stands clear of a ledge above" % [map_id, s.name], back <= RISE_M,
				"ground rises %.1f m within %.0f m behind its back wall" % [back, BACK_M])
		spots += _secret_spots(game, map_id)
		if map_id == "park_dam":
			var drop := _drop(game, _front(OLD_LEDGE), _face(OLD_LEDGE))
			_t.check("planted: the radio's old service_ledge spot fails the mouth check", drop > CLIMB_M, "%.1f m" % drop)
			var ramp := _drop(game, _front(OLD_POWERHOUSE), _face(OLD_POWERHOUSE))
			_t.check("planted: the seep's old powerhouse spot fails the mouth check", ramp > CLIMB_M, "%.1f m" % ramp)
			var fin := _back_rise(game, _front(FIN_DRAFT), _face(FIN_DRAFT), true)
			_t.check("planted: the radio's slot_fin_far draft fails the side-wall back check", fin > RISE_M, "%.1f m" % fin)
		if map_id == "park_flume":
			var south := Vector2(0.0, 1.0)
			var north := _rise(game, OLD_BEND - south * 12.0, -south)
			_t.check("planted: the old bend_cache facing north fails", north > RISE_M, "%.1f m" % north)
			var under := _back_rise(game, OLD_BEND, south)
			_t.check("planted: the old bend_cache under the cliff fails", under > RISE_M, "%.1f m" % under)
	_t.check("park caches found", caches >= 8, "%d" % caches)
	var want := Secrets.ROOMS.size() + 1
	for id in Secrets.FINDS:
		want += (Secrets.FINDS[id]["spots"] as Array).size()
	_t.eq("every secret spot checked", spots, want)
	quit(_t.verdict())


func _rise(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var top := -INF
	for d in [2.0, 4.0, 6.0, NEAR_M]:
		var p: Vector2 = at + face * d
		top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top


# The rise behind the back wall, from the room's floor at its face: on the centreline, and with
# `sides` behind both side walls too (a ridge running past one side drops a ball onto that wall as
# surely as one behind; the radio's first slot_fin_far draft stood 6 m off the fin's 20 m crest).
func _back_rise(game, at: Vector2, face: Vector2, sides := false) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var wall := at - face * (Activities.WALL_DEPTH + 0.5)
	var side := Vector2(-face.y, face.x)
	var top := -INF
	for lane in ([-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W] if sides else [0.0]):
		for d in [0.0, 4.0, 8.0, 12.0, 16.0, BACK_M]:
			var p: Vector2 = wall - face * d + side * lane
			top = maxf(top, game.ctx.terrain.height(p.x, p.y) - y0)
	return top


# Every secret spot on this park from the tables: each find's spots, the timed door and the first-win
# rooms (a room has no face of its own, so it takes the cache rule's).
func _secret_spots(game, map_id: String) -> int:
	var rows := []
	for id in Secrets.FINDS:
		var f: Dictionary = Secrets.FINDS[id]
		if f["map"] == map_id:
			for spot in f["spots"]:
				rows.append({"name": "%s at %s" % [id, spot["site"]], "at": spot["at"], "face": spot["face"]})
	if Secrets.DOOR["map"] == map_id:
		rows.append({"name": "timed door", "at": Secrets.DOOR["at"], "face": Secrets.DOOR["face"]})
	var rule_face: Vector2 = Activities.RULES["cracked_cache"]["face"]
	# The first-win rooms keep the centreline back check: the islands' highdraft_lookout has 5-9 m rock
	# teeth beside its west wall (7.4 m on that lane, 26 Oct), a world 3 look owed after world 1.
	for id in Secrets.ROOMS:
		if Secrets.ROOMS[id]["map"] == map_id:
			rows.append({"name": id, "at": Secrets.ROOMS[id]["at"], "face": [rule_face.x, rule_face.y], "room": true})
	for row in rows:
		var at := _front(row)
		var face := _face(row)
		var rise := _rise(game, at, face)
		_t.check("%s %s opens onto reachable ground" % [map_id, row["name"]], rise <= RISE_M,
			"ground rises %.1f m within %.0f m of its face %s" % [rise, NEAR_M, face])
		var back := _back_rise(game, at, face, not row.get("room", false))
		_t.check("%s %s stands clear of a ledge above" % [map_id, row["name"]], back <= RISE_M,
			"ground rises %.1f m within %.0f m behind its back wall" % [back, BACK_M])
		var drop := _drop(game, at, face)
		_t.check("%s %s has a level run-up" % [map_id, row["name"]], drop <= CLIMB_M,
			"ground lies %.1f m below its floor within %.0f m of its face %s" % [drop, RUN_M, face])
	return rows.size()


# Where the room's face stands: the spot moved CACHE_LANE_OFFSET out along its face (activities.gd).
func _front(row: Dictionary) -> Vector2:
	return Vector2(float(row["at"][0]), float(row["at"][1])) + _face(row) * Activities.CACHE_LANE_OFFSET


func _face(row: Dictionary) -> Vector2:
	return Vector2(float(row["face"][0]), float(row["face"][1])).normalized()


# How far the run-up lies below the room's floor at its lowest, on three lanes across the face.
func _drop(game, at: Vector2, face: Vector2) -> float:
	var y0: float = game.ctx.terrain.height(at.x, at.y)
	var side := Vector2(-face.y, face.x)
	var deepest := -INF
	for lane in [-Activities.WALL_HALF_W * 0.5, 0.0, Activities.WALL_HALF_W * 0.5]:
		for d in range(2, int(RUN_M) + 1, 2):
			var p: Vector2 = at + face * float(d) + side * lane
			deepest = maxf(deepest, y0 - game.ctx.terrain.height(p.x, p.y))
	return deepest


func _authored(m, s) -> bool:
	var at := Vector2(s.global_position.x, s.global_position.z)
	for row in m.activity_sites:
		if String(row["id"]) == "cracked_cache" and Vector2(row["at"]).distance_to(at) < 10.0:
			return true
	return false
