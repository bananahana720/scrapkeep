extends SceneTree

const PlayWatch := preload("res://src/core/play_watch.gd")
const T := preload("res://tests/support/t.gd")

# The play watch's rows, each made to fire and each given the look-alike that must not fire
# (src/core/play_watch.gd). The world 1 run test and the sitting notes judge a run by "no wedged
# row, no fell row, no blank row", so a watch that had gone quiet would pass them: this is the
# proof that it still speaks. No game is built: the watch reads a stand-in with the same few
# members it reads off the game, so each fault is planted exactly and the file runs in under a second.
#   fell    a rescue from under the floor, and from off the map; not a long move over the floor,
#           not a blink, not the placing of the ball as a run starts
#   wedged  at rest on the ground against a wall-steep contact; not on a floor-flat contact
#   hung    at rest off the ground
#   stuck   STUCK_S inside STUCK_M while moving; not while frozen
#   re-arm  the same fault within REARM_M writes one row, further away a second
#   blank   an empty objective plate for BLANK_S of play, once a stretch; not on the victory lap,
#           not outside play
#   objective  one row a plate change
#   bar     a hull bar off the hull for BAR_S of play, once a stretch; not a bar that catches up
#           sooner, not one within BAR_OFF, not one reading off after a long gap, not outside play
# Evidence limit: the stand-in is not the game. That the game's own members still carry these
# names is what sitting_notes_test (a real game, a real stuck row) and world1_run_test hold.

const TICK := 1.0 / 90.0


class Events:
	signal blink_used(from, to)


class BallState:
	var velocity := Vector3(5.0, 0.0, 0.0)
	var grounded := true
	var contact_normal := Vector3.UP


class Kit:
	var hooked := false
	var mounted := false


class Player:
	var at := Vector3(0.0, 1.0, 0.0)
	var state := BallState.new()
	var kit := Kit.new()
	var held := false

	func ball_position() -> Vector3:
		return at

	func frozen() -> bool:
		return held


class Flow:
	var now := "stage"
	var gate = null
	var sealed := false

	func state_name() -> String:
		return now

	func in_play() -> bool:
		return now in ["stage", "beacon", "gates", "launch", "boss", "lap"]


class Run:
	var stage := 1
	var stage_time := 0.0
	var hp := 100.0
	var max_hp := 100.0


# A flat map 1 km square with its floor at height 0.
class Terrain:
	func contains(p: Vector3) -> bool:
		return absf(p.x) <= 500.0 and absf(p.z) <= 500.0

	func floor_height(_x: float, _z: float) -> float:
		return 0.0


class Ctx:
	var terrain := Terrain.new()


class Hud:
	var id := "find_warden"
	var words := "FIND THE WARDEN"

	var shown := 1.0

	func objective_reading() -> Dictionary:
		return {"id": id, "words": words}

	func hull_shown() -> float:
		return shown


class Stand:
	var events := Events.new()
	var player := Player.new()
	var flow := Flow.new()
	var run := Run.new()
	var ctx := Ctx.new()
	var hud := Hud.new()


var _t := T.new("play_watch_test")
var _game: Stand
var _watch
var _rows := []


func _initialize() -> void:
	_fell()
	_rest()
	_stuck()
	_plate()
	_bar()
	quit(_t.verdict())


# A new stand-in and a watch on it, two ticks into play (the first tick only takes the stage).
func _fresh(state := "stage") -> void:
	_game = Stand.new()
	_game.flow.now = state
	_watch = PlayWatch.new()
	_rows = []
	_watch.watch(_game, func(row): _rows.append(row))
	_step(2)


func _step(ticks: int) -> void:
	for i in ticks:
		_game.run.stage_time += TICK
		_watch.step(TICK)


func _of(kind: String) -> Array:
	return _rows.filter(func(row): return row["kind"] == kind)


func _count(kind: String) -> int:
	return int(_watch.counts.get(kind, 0))


func _fell() -> void:
	_fresh()
	_game.player.at = Vector3(0.0, -10.0, 0.0)
	_step(1)
	_t.check("a long move over the floor is not a fall", _count("fell") == 0, "%d rows" % _count("fell"))
	_game.player.at = Vector3(0.0, 5.0, 20.0)
	_step(1)
	var fell: Array = _of("fell")
	_t.check("a rescue from under the floor is one fell row, with where from and where to", fell.size() == 1 and _count("fell") == 1 and fell[0]["at"] == [0.0, -10.0, 0.0]
		and fell[0]["to"] == [0.0, 5.0, 20.0] and int(fell[0]["stage"]) == 1 and fell[0]["flow"] == "stage", "%s" % [fell])

	_fresh()
	_game.player.at = Vector3(900.0, 1.0, 0.0)
	_step(1)
	_game.player.at = Vector3(0.0, 5.0, 0.0)
	_step(1)
	_t.check("a rescue from off the map is a fell row", _count("fell") == 1 and _of("fell")[0]["at"] == [900.0, 1.0, 0.0], "%s" % [_of("fell")])

	_fresh()
	_game.player.at = Vector3(0.0, -10.0, 0.0)
	_step(1)
	_game.events.blink_used.emit(Vector3.ZERO, Vector3.ZERO)
	_game.player.at = Vector3(0.0, 5.0, 20.0)
	_step(1)
	_t.check("the same move right after a blink is not a fall", _count("fell") == 0, "%d rows" % _count("fell"))

	_fresh("title")
	_game.player.at = Vector3(900.0, 60.0, 0.0)
	_step(30)
	_game.flow.now = "stage"
	_game.player.at = Vector3(0.0, 5.0, 0.0)
	_step(2)
	_t.check("the ball placed as a run starts is not a fall", _count("fell") == 0, "%d rows" % _count("fell"))
	_game.player.at = Vector3(0.0, -10.0, 0.0)
	_step(1)
	_game.player.at = Vector3(0.0, 5.0, 20.0)
	_step(1)
	_t.check("and a fall later in that run still is", _count("fell") == 1, "%d rows" % _count("fell"))


func _rest() -> void:
	var second := int(PlayWatch.HUNG_S / TICK) + 2
	_fresh()
	_game.player.state.velocity = Vector3.ZERO
	_game.player.state.contact_normal = Vector3(0.98, 0.2, 0.0)
	_step(second)
	var wedged: Array = _of("wedged")
	_t.check("at rest on the ground against a wall-steep contact is one wedged row", wedged.size() == 1 and _count("hung") == 0 and wedged[0]["n"] == [1.0, 0.2, 0.0], "%s" % [wedged])
	_step(second * 3)
	_t.check("staying wedged there writes no second row", _count("wedged") == 1, "%d rows" % _count("wedged"))
	_game.player.at += Vector3(PlayWatch.REARM_M - 3.0, 0.0, 0.0)
	_step(second)
	_t.check("nor does a wedge within %d m of the first" % int(PlayWatch.REARM_M), _count("wedged") == 1, "%d rows" % _count("wedged"))
	_game.player.at += Vector3(6.0, 0.0, 0.0)
	_step(second)
	_t.check("a wedge further away is a second row", _count("wedged") == 2, "%d rows" % _count("wedged"))

	_fresh()
	_game.player.state.velocity = Vector3.ZERO
	_step(second * 3)
	_t.check("at rest on a floor-flat contact is not wedged and not hung", _count("wedged") == 0 and _count("hung") == 0, "wedged %d, hung %d" % [_count("wedged"), _count("hung")])
	_game.player.state.grounded = false
	_step(second)
	var hung: Array = _of("hung")
	_t.check("at rest off the ground is one hung row", hung.size() == 1 and _count("wedged") == 0 and hung[0]["grounded"] == false, "%s" % [hung])

	# SA-F2: a pylon engineer mounted on a pylon rests in the air by choice.
	_fresh()
	_game.player.state.velocity = Vector3.ZERO
	_game.player.state.grounded = false
	_game.player.kit.mounted = true
	_step(int(PlayWatch.STUCK_S / TICK) + 2)
	_t.check("mounted on a pylon is neither hung nor stuck", _count("hung") == 0 and _count("stuck") == 0, "hung %d, stuck %d" % [_count("hung"), _count("stuck")])
	_game.player.kit.mounted = false
	_step(second)
	_t.check("and off the mount, at rest in the air, is hung again", _count("hung") == 1, "%d rows" % _count("hung"))


func _stuck() -> void:
	var long := int(PlayWatch.STUCK_S / TICK) + 2
	_fresh()
	_step(long - 90)
	_t.check("moving inside %d m for under %d s is not stuck yet" % [int(PlayWatch.STUCK_M), int(PlayWatch.STUCK_S)], _count("stuck") == 0, "%d rows" % _count("stuck"))
	_step(92)
	var stuck: Array = _of("stuck")
	_t.check("and for %d s is one stuck row with the ball's motion" % int(PlayWatch.STUCK_S), stuck.size() == 1 and stuck[0]["v"] == [5.0, 0.0, 0.0] and float(stuck[0]["s"]) >= PlayWatch.STUCK_S, "%s" % [stuck])

	_fresh()
	_game.player.held = true
	_step(long * 2)
	_t.check("a frozen ball (a cutscene, a card) is never stuck", _count("stuck") == 0, "%d rows" % _count("stuck"))


func _plate() -> void:
	_fresh()
	_watch.read_text(1.0)
	_t.check("the first plate read is one objective row with its words", _watch.plates == 1 and _of("objective").size() == 1 and _of("objective")[0]["words"] == "FIND THE WARDEN", "%s" % [_of("objective")])
	_watch.read_text(1.0)
	_game.hud.id = "break_clamp_crews"
	_game.hud.words = "BREAK THE CLAMP CREWS"
	_watch.read_text(1.0)
	_t.check("a row a plate change, none while it stands", _watch.plates == 2 and _of("objective").size() == 2, "%d rows" % _of("objective").size())

	_game.hud.id = ""
	_game.hud.words = ""
	_watch.read_text(1.0)
	_watch.read_text(1.0)
	_t.check("an empty plate under %d s is not a blank row" % int(PlayWatch.BLANK_S), _count("blank") == 0 and _watch.blank_max == 2.0, "%d rows, longest %s s" % [_count("blank"), _watch.blank_max])
	_watch.read_text(1.0)
	_watch.read_text(1.0)
	_t.check("at %d s it is one blank row, and the stretch keeps counting" % int(PlayWatch.BLANK_S), _count("blank") == 1 and _of("blank").size() == 1 and _watch.blank_max == 4.0,
		"%d rows, longest %s s" % [_count("blank"), _watch.blank_max])
	_game.hud.id = "find_warden"
	_game.hud.words = "FIND THE WARDEN"
	_watch.read_text(1.0)
	_game.hud.id = ""
	_game.hud.words = ""
	for i in 3:
		_watch.read_text(1.0)
	_t.check("a second empty stretch is a second row", _count("blank") == 2, "%d rows" % _count("blank"))

	_fresh("lap")
	_game.hud.id = ""
	_game.hud.words = ""
	for i in 6:
		_watch.read_text(1.0)
	_t.check("the victory lap's empty plate is not a blank row", _count("blank") == 0 and _watch.blank_max == 0.0, "%d rows, longest %s s" % [_count("blank"), _watch.blank_max])

	_fresh("summary")
	_game.hud.id = ""
	_game.hud.words = ""
	for i in 6:
		_watch.read_text(1.0)
	_t.check("nor is an empty plate outside play", _count("blank") == 0 and _watch.plates == 0, "%d rows" % _count("blank"))


func _bar() -> void:
	_fresh()
	for i in 4:
		_watch.read_text(1.0)
	_t.check("a bar that shows the hull is never a bar row", _count("bar") == 0 and _watch.bar_off_max == 0.0, "%d rows, longest %s s" % [_count("bar"), _watch.bar_off_max])
	# A stretch is timed from the first reading that found the bar off: three readings are 2 s.
	_game.run.hp = 50.0
	for i in 3:
		_watch.read_text(1.0)
	_game.hud.shown = 0.5
	_watch.read_text(1.0)
	_watch.read_text(1.0)
	_t.check("a bar that catches up inside %d s is not a bar row" % int(PlayWatch.BAR_S), _count("bar") == 0 and _watch.bar_off_max == 2.0, "%d rows, longest %s s" % [_count("bar"), _watch.bar_off_max])
	_game.hud.shown = 0.5 + PlayWatch.BAR_OFF * 0.8
	for i in 5:
		_watch.read_text(1.0)
	_t.check("nor is a bar within %.2f of the hull" % PlayWatch.BAR_OFF, _count("bar") == 0 and _watch.bar_off_max == 2.0, "%d rows, longest %s s" % [_count("bar"), _watch.bar_off_max])
	# One reading off the hull after a long gap (the frame a pause lifts, before the HUD has drawn
	# again) is one reading, not the gap: a healthy game must never write this row.
	_game.hud.shown = 1.0
	_watch.read_text(30.0)
	_game.hud.shown = 0.5
	_watch.read_text(1.0)
	_t.check("one reading off after a long gap is not a bar row", _count("bar") == 0 and _watch.bar_off_max == 2.0, "%d rows, longest %s s" % [_count("bar"), _watch.bar_off_max])
	_game.hud.shown = 1.0
	for i in 6:
		_watch.read_text(1.0)
	var rows := _of("bar")
	_t.check("a bar that stays full over half a hull is one bar row, with both readings", _count("bar") == 1 and rows.size() == 1 and rows[0]["shown"] == 1.0 and rows[0]["hull"] == 0.5 and _watch.bar_off_max == 5.0,
		"%s, longest %s s" % [rows, _watch.bar_off_max])
	_game.hud.shown = 0.5
	_watch.read_text(1.0)
	_game.run.hp = 20.0
	for i in 4:
		_watch.read_text(1.0)
	_t.check("a second stretch is a second row", _count("bar") == 2, "%d rows" % _count("bar"))

	_fresh("summary")
	_game.run.hp = 50.0
	for i in 6:
		_watch.read_text(1.0)
	_t.check("a bar off the hull outside play is not a bar row", _count("bar") == 0 and _watch.bar_off_max == 0.0, "%d rows, longest %s s" % [_count("bar"), _watch.bar_off_max])
