extends SceneTree

const ParkDefs := preload("res://src/core/park_defs.gd")
const Terrain := preload("res://src/world/terrain.gd")
const EdgeMarkers := preload("res://src/ui/edge_markers.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Rule: a discovered hidden-pocket door (a valve door or a cracked wall) shows one amber edge
# marker while the ball is inside POCKET_RANGE (240 m, PARK.md:265's sight_ok range, never the
# comps note's 60 m) of it and the ball has a clear ray to it over the ground (sight_ok). On all
# six stages, each door of the stage's map: present with both, absent past the range, absent
# behind a planted ridge, absent while undiscovered, and the range edge is inclusive. A door
# the player has already opened (a valve open, a wall broken) needs no marker. The marker takes
# the amber role colour and the activity glyph; it is no new meaning colour. A live check on
# stage 1 runs the same rule through targets().

var _t := preload("res://tests/support/t.gd").new("ui_edge_marker_pocket_test")
var _game


func _initialize() -> void:
	_run.call_deferred()


# A flat ground, and a ground with a 60 m ridge one third of the way along the ball-to-door ray.
static func _flat(_x: float, _z: float) -> float:
	return 0.0


func _ridge(ball: Vector3, door: Vector3) -> Callable:
	var dir := Vector2(door.x - ball.x, door.z - ball.z)
	var span := dir.length()
	dir = dir.normalized()
	return func(x: float, z: float) -> float:
		var along := (Vector2(x, z) - Vector2(ball.x, ball.z)).dot(dir)
		return 60.0 if absf(along - span / 3.0) < 6.0 else 0.0


# A map with only a contraptions list.
class _Stub:
	var contraptions: Array

	func _init(rows: Array) -> void:
		contraptions = rows


func _run() -> void:
	_t.near("range is the 240 m sight_ok range", EdgeMarkers.POCKET_RANGE, 240.0)
	var amber := EventKinds.role_color("amber")

	_t.eq("six stages", ParkDefs.DEFS.size(), 6)
	var table := Terrain.new(ParkDefs)
	var real_stages := 0
	for i in ParkDefs.DEFS.size():
		var row: Dictionary = ParkDefs.DEFS[i]
		var map = table.maps[i]
		var doors: Array = EdgeMarkers.pocket_doors(map)
		var label := "stage %d %s" % [row["stage"], row["map"]]
		if doors.is_empty():
			# This stage's map carries no hidden-pocket door yet (only the stage 1 park file does). The rule still
			# runs on the stage: one planted valve door 120 m from its spawn toward its beacon.
			var toward: Vector2 = (map.beacon - map.spawn).normalized()
			var planted := {"kind": "valve", "id": "planted_valve", "at": map.spawn + toward * 100.0,
				"door": {"at": map.spawn + toward * 120.0}}
			doors = EdgeMarkers.pocket_doors(_Stub.new([planted]))
			label += " (planted door)"
		else:
			real_stages += 1
		print("[report] %s: %d pocket doors" % [label, doors.size()])
		if not _t.check("%s has a pocket door" % label, not doors.is_empty(), "%d doors" % doors.size()):
			continue
		var flat := Callable(self, "_flat")
		for door in doors:
			var at: Vector2 = door["at"]
			var door_pos := Vector3(at.x, 1.5, at.y)
			var discovered := {door["key"]: true}
			var near_ball := door_pos + Vector3(100.0, 0.0, 0.0)
			var edge_ball := door_pos + Vector3(EdgeMarkers.POCKET_RANGE, 0.0, 0.0)
			var far_ball := door_pos + Vector3(EdgeMarkers.POCKET_RANGE + 1.0, 0.0, 0.0)
			var tag := "%s %s" % [label, door["id"]]

			var present: Array = EdgeMarkers.pocket_targets([door], discovered, near_ball, flat)
			_t.eq("%s: present inside range with sight and discovered" % tag, present.size(), 1)
			if present.size() == 1:
				_t.check("%s: amber, at the door, activity glyph" % tag,
					present[0]["color"] == amber and present[0]["at"] == door_pos and present[0].has("icon"), str(present[0]))
				_t.check("%s: the shared colour read gives amber" % tag, EdgeMarkers.marker_color(present[0]) == amber)
			_t.eq("%s: present at exactly 240 m" % tag,
				EdgeMarkers.pocket_targets([door], discovered, edge_ball, flat).size(), 1)
			_t.eq("%s: absent at 241 m" % tag,
				EdgeMarkers.pocket_targets([door], discovered, far_ball, flat).size(), 0)
			_t.eq("%s: absent without sight (ridge on the ray)" % tag,
				EdgeMarkers.pocket_targets([door], discovered, near_ball, _ridge(near_ball, door_pos)).size(), 0)
			_t.eq("%s: absent while undiscovered" % tag,
				EdgeMarkers.pocket_targets([door], {}, near_ball, flat).size(), 0)
			_t.eq("%s: another door's discovery does not show this one" % tag,
				EdgeMarkers.pocket_targets([door], {"other/door": true}, near_ball, flat).size(), 0)
			var shut: Dictionary = door.duplicate()
			shut["done"] = true
			_t.eq("%s: an opened door needs no marker" % tag,
				EdgeMarkers.pocket_targets([shut], discovered, near_ball, flat).size(), 0)
	print("[report] stages whose map carries a real hidden-pocket door: %d of 6" % real_stages)
	_t.check("at least one stage carries a real door", real_stages >= 1)
	await _live()
	quit(_t.verdict())


# Stage 1 through the live HUD markers: targets() carries exactly the pocket targets the
# static rule gives for the ball's real position and the real terrain.
func _live() -> void:
	var Game = load("res://src/game.gd")
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.flow.press_start()
	_game.flow.choose_class(1)
	for i in 30:
		await physics_frame
	var markers = _game.hud.edge_markers
	var map = _game.world.terrain.map()
	var doors: Array = EdgeMarkers.pocket_doors(map)
	var pockets := func() -> Array:
		return markers.targets().filter(func(t): return t.has("pocket"))
	_t.eq("live: nothing undiscovered shows", pockets.call().size(), 0)
	for door in doors:
		markers.discovered[door["key"]] = true
	var ground := Callable(_game.world.terrain, "height")
	var ball: Vector3 = _game.player.ball_position()
	var want := EdgeMarkers.pocket_targets(doors, markers.discovered, ball, ground)
	_t.eq("live: targets() carries the rule's pocket targets", pockets.call().size(), want.size())
	# Put the ball beside the first door on the real terrain: that door must show.
	if not doors.is_empty():
		var at: Vector2 = doors[0]["at"]
		_game.player.reset_to(Vector3(at.x + 30.0, _game.world.terrain.height(at.x + 30.0, at.y) + 2.0, at.y))
		for i in 5:
			await physics_frame
		var shown: Array = pockets.call()
		_t.check("live: the door beside the ball shows", shown.any(func(t): return t["pocket"] == doors[0]["id"]),
			"%d shown, ball %s, door %s" % [shown.size(), _game.player.ball_position(), at])
		# Far from the door (past 240 m) the live target is gone.
		_game.player.reset_to(Vector3(at.x + 300.0, _game.world.terrain.height(at.x + 300.0, at.y) + 2.0, at.y))
		for i in 5:
			await physics_frame
		_t.check("live: the door 300 m away does not show", not pockets.call().any(func(t): return t["pocket"] == doors[0]["id"]))
		# A new run forgets what the last run found: door keys repeat across runs, so a door found
		# in run 1 must not show in run 2 until the player sees it again.
		_t.check("live: run 1 latched the doors", not markers.discovered.is_empty())
		_game.player.reset_to(Vector3(at.x + 30.0, _game.world.terrain.height(at.x + 30.0, at.y) + 2.0, at.y))
		_game.flow.new_run()
		for i in 5:
			await physics_frame
		_t.check("live: a new run clears the discovered doors", markers.discovered.is_empty(), str(markers.discovered))
		_t.check("live: no pocket target shows beside an undiscovered door in run 2", not pockets.call().any(func(t): return t["pocket"] == doors[0]["id"]))
	_game.free()
