extends SceneTree

# World 1 unit 15's timed door (secrets.gd DOOR): rout Brindle with the run clock under 12 minutes and
# the next run, and only that one, finds the Shift Clock Door by the dam's drop-in.
#
#   rule       a slow rout, another boss or no profile marks nothing; a fast rout opens the door for the
#              run after this one, which outlasts a save and load (a quit and Continue) and closes when
#              the next run starts; the door survives the save merge with a newer copy on disk.
#   placement  the spot is reachable, a door_ok node near the drop-in, clear of the dam's activities,
#              contraptions and finds, and its face looks back toward the drop-in.
#   game       flow marks the door on a fast Brindle rout and rolls it as a new run starts (a restart
#              counts, so a restart from the door's run closes it); with the door
#              open the dam builds it on flat ground, lit, with its clock and board, and its codex row
#              is declared; breaking it files the row and pays on its own luck stream. A shut door builds
#              nothing.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Profile := preload("res://src/core/profile.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Activities := preload("res://src/world/activities.gd")

const DROP_IN_M := 160.0
const ACTIVITY_CLEAR_M := 60.0
const CONTRAPTION_CLEAR_M := 40.0
const FLAT_RISE_M := 1.5

var _t := T.new("timed_door_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rule()
	_placement()
	await _game()
	quit(_t.verdict())


func _rule() -> void:
	var path := "user://timed_door_test_profile.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Profile.new(path)
	p.load_profile()
	_t.check("no profile marks nothing", not Secrets.note_rout(null, "brindle", 60.0))
	_t.check("a slow rout marks nothing", not Secrets.note_rout(p, "brindle", 720.0))
	_t.check("another boss marks nothing", not Secrets.note_rout(p, "waking", 60.0))
	_t.check("a fresh profile has no door", not Secrets.door_open(p) and Secrets.door_sites("park_dam", p).is_empty())
	_t.check("a fast rout marks the door", Secrets.note_rout(p, "brindle", 719.0))
	_t.check("the door waits for the next run", not Secrets.door_open(p))
	Secrets.roll_door(p)
	_t.check("the next run has the door", Secrets.door_open(p))
	_t.eq("the dam holds it", Secrets.door_sites("park_dam", p).size(), 1)
	_t.check("the flume does not", Secrets.door_sites("park_flume", p).is_empty())
	_t.check("the profile saves", p.save(), p.last_error)
	var again := Profile.new(path)
	again.load_profile()
	_t.check("a quit and Continue keeps the door", Secrets.door_open(again))
	Secrets.roll_door(again)
	_t.check("the run after closes it", not Secrets.door_open(again))
	_t.check("the profile saves again", again.save(), again.last_error)
	# A second copy saves a newer generation first; the next save merges by max, so the door's
	# stats come through as this copy wrote them.
	var other := Profile.new(path)
	other.load_profile()
	other.set_stat("door.test_other", 1.0)
	_t.check("another copy saves first", other.save(), other.last_error)
	_t.check("a second fast rout opens it again", Secrets.note_rout(again, "brindle", 300.0))
	Secrets.roll_door(again)
	_t.check("for the run after that one", Secrets.door_open(again))
	_t.check("the merged save keeps it", again.save(), again.last_error)
	var merged := Profile.new(path)
	merged.load_profile()
	_t.check("the door survives the merge with a newer copy", Secrets.door_open(merged) and merged.stat("door.test_other") == 1.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _placement() -> void:
	var d: Dictionary = Secrets.DOOR
	var at := Vector2(float(d["at"][0]), float(d["at"][1]))
	var map := ParkMap.new("res://src/world/park/%s.json" % d["map"])
	_t.check("the door's park loads", map.ok, str(map.errors))
	_t.check("the door names a real park row", map.park["park_rows"].any(func(r): return r["id"] == d["site"]))
	for act in map.park["activity_rows"]:
		var gap := at.distance_to(Vector2(float(act["at"][0]), float(act["at"][1])))
		_t.check("the door keeps clear of %s" % act["id"], gap >= ACTIVITY_CLEAR_M, "%.0f m" % gap)
	for row in map.park["contraption_rows"]:
		if row.has("at"):
			var gap := at.distance_to(Vector2(float(row["at"][0]), float(row["at"][1])))
			_t.check("the door keeps clear of %s" % row["id"], gap >= CONTRAPTION_CLEAR_M, "%.0f m" % gap)
	for id in Secrets.FINDS:
		if Secrets.FINDS[id]["map"] == d["map"]:
			for spot in Secrets.FINDS[id]["spots"]:
				var gap := at.distance_to(Vector2(float(spot["at"][0]), float(spot["at"][1])))
				_t.check("the door keeps clear of %s at %s" % [id, spot["site"]], gap >= ACTIVITY_CLEAR_M, "%.0f m" % gap)
	var g = ParkGraph.read("res://assets/park/%s/graph.bin" % d["map"])
	_t.check("the dam has a graph", g != null)
	if g == null:
		return
	var node: int = g.nearest(at)
	_t.check("the door stands by the drop-in", g.d_spawn_node(node) <= DROP_IN_M, "%.0f m" % g.d_spawn_node(node))
	_t.check("the door is a door_ok node", g.flags(node) & ParkGraph.DOOR_OK != 0, str(g.flag_names(node)))
	var face := Vector2(float(d["face"][0]), float(d["face"][1])).normalized()
	var out_node: int = g.nearest(at + face * 24.0)
	_t.check("the door faces the drop-in", g.d_spawn_node(out_node) < g.d_spawn_node(node),
		"%.0f m out vs %.0f m in" % [g.d_spawn_node(out_node), g.d_spawn_node(node)])


func _game() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(1)
	var profile = game.ctx.profile
	var dam := _dam_index(game)
	_t.check("the dam is on the park table", dam >= 0)
	game.flow.enter_stage(dam + 1, Vector3.ZERO, false)
	await physics_frame
	_t.check("a shut door builds nothing", _door(game) == null)
	# Flow: a fast rout of world 1's boss marks the door, and the next new run opens it.
	game.flow.state = game.flow.BOSS
	game.run.run_time = 600.0
	game.flow._on_boss_defeated()
	_t.check("flow marks the door on a fast Brindle rout", profile.stat(Secrets.DOOR_FOR) >= 1.0 and not Secrets.door_open(profile))
	game.flow.new_run()
	_t.check("the next run opens it", Secrets.door_open(profile))
	game.flow.enter_stage(dam + 1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var s = _door(game)
	_t.check("the dam builds the open door", s != null)
	if s == null:
		game.queue_free()
		return
	var spot: Array = Secrets.DOOR["at"]
	var planar := Vector2(s.global_position.x - float(spot[0]), s.global_position.z - float(spot[1])).length()
	_t.check("the door stands at its spot", planar <= 12.0, "%.1f m" % planar)
	_t.check("the door stands on flat ground", _rise(game, s) <= FLAT_RISE_M, "%.2f m" % _rise(game, s))
	_t.check("the door keeps its beacon", s.view.lit())
	_t.check("the door shows its punch clock", s.wall.get_node_or_null("DoorClock") != null)
	var board: Label3D = s.get_node_or_null("RoomLog")
	_t.check("the door hangs the foreman's note", board != null and board.text.contains(String(Secrets.DOOR["log"])))
	var codex_id := String(Secrets.DOOR["codex"]["id"])
	_t.check("the door's codex row is declared", game.ctx.codex.status(codex_id) == "unencountered")
	_t.eq("the door rolls on its own stream", game.world.activities._luck_id(s), "cracked_cache:timed_door")
	game.world.activities._break_wall(s)
	_t.check("the door opens when its face breaks", s.done and not s.wall.visible)
	_t.check("the door files its codex row", game.ctx.codex.known(codex_id))
	_t.check("the camp counts the door", Secrets.WORLD_CODEX[1].has(codex_id))
	game.flow.new_run()
	_t.check("a restart from the door's run closes it", not Secrets.door_open(profile))
	await _patch_wire(game, dam, profile)
	game.queue_free()
	await process_frame


func _patch_wire(game, dam: int, profile) -> void:
	game.ctx.codex.mark_known("patch.rogue.w1")
	game.flow.enter_stage(dam + 1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var wire = null
	for s in game.world.activities.sites:
		if is_instance_valid(s) and s.has_meta("patch_wire"):
			wire = s
	_t.check("the dam builds the revealed patch wire", wire != null)
	if wire == null:
		return
	var wire_id := String(wire.get_meta("patch_wire"))
	_t.eq("the dam's wire is world one's", wire_id, "patch.wire.w1")
	_t.check("the wire is not settled before it breaks", not game.run.settled.has(wire_id) and not profile.is_settled(wire_id))
	game.world.activities._break_wall(wire)
	_t.check("a broken wire settles in the run", game.run.settled.has(wire_id), str(game.run.settled))
	_t.check("and in the profile", profile.is_settled(wire_id))
	var disk := Profile.new(profile.path)
	disk.load_profile()
	_t.check("and the settle is saved", disk.is_settled(wire_id), profile.path)


func _dam_index(game) -> int:
	for i in game.ctx.terrain.maps.size():
		var m = game.ctx.terrain.maps[i]
		if "park" in m and String(m.park.get("map", "")) == Secrets.DOOR["map"]:
			return i
	return -1


func _door(game):
	for s in game.world.activities.sites:
		if is_instance_valid(s) and s.has_meta("door"):
			return s
	return null


# The ground's rise under the room's footprint, face to back wall.
func _rise(game, s) -> float:
	var face: Vector2 = s.rule["face"]
	var side := Vector2(-face.y, face.x)
	var front := Vector2(s.global_position.x, s.global_position.z)
	var lo := INF
	var hi := -INF
	for dx in [-Activities.WALL_HALF_W, 0.0, Activities.WALL_HALF_W]:
		for dz in [0.0, -Activities.WALL_DEPTH * 0.5, -Activities.WALL_DEPTH]:
			var p: Vector2 = front + side * dx + face * dz
			var y: float = game.ctx.terrain.height(p.x, p.y)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	return hi - lo
