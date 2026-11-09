extends SceneTree

const Game := preload("res://src/game.gd")
const SittingNotes := preload("res://src/core/sitting_notes.gd")
const PlayWatch := preload("res://src/core/play_watch.gd")
const T := preload("res://tests/support/t.gd")

# --sitting-notes (ruling cg): the build writes down what a player would report while they play.
# Here a test_mode game carries the notes node by hand (the launch flag is for a launched game):
#   - a game made without the flag has no notes node;
#   - the file opens with a start row;
#   - a ball held in one place in play for STUCK_S is written as a stuck row, with its place;
#   - frames at or over the hitch limit close into one row a burst; shorter frames write nothing;
#   - F8 writes a mark with the place, and both stick clicks together write one mark, not two;
#   - every row carries both clocks, and closing the game writes the end row.
# Evidence limit: frame lengths are fed in, so the real frame clock and the cost on a GPU are
# not measured here.

const SABLE := 0
# The test map's slopes never let a free ball rest, so the test pins it where it is after
# PIN_AFTER ticks; the stuck row is waited for, up to STUCK_WAIT_TICKS.
const PIN_AFTER := 90
const STUCK_WAIT_TICKS := 20 * 90

var _t := T.new("sitting_notes_test")
var _game
var _notes
var _step := 0
var _ticks := 0
var _pin := Vector3.INF


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _rows() -> Array:
	var out := []
	for line in FileAccess.get_file_as_string(_notes.path).split("\n", false):
		out.append(JSON.parse_string(line))
	return out


func _of(kind: String) -> Array:
	return _rows().filter(func(row): return row["kind"] == kind)


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _stick(button: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _game.hud == null:
		return false
	match _step:
		0:
			_t.check("a game made without the flag carries no notes", _game.get_node_or_null("SittingNotes") == null and not SittingNotes.wanted(), "no SittingNotes child")
			_notes = SittingNotes.new()
			_notes.game = _game
			_notes.dir = String(_game.storage_dir).path_join("sitting-notes")
			_game.add_child(_notes)
			var start: Array = _of("start")
			_t.check("the file opens with a start row", start.size() == 1 and _rows()[0]["kind"] == "start" and start[0]["mark_key"] == "F8" and float(start[0]["hitch_ms"]) == SittingNotes.HITCH_MS,
				"%s: %s" % [_notes.path.get_file(), start])
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(SABLE)
			_step = 1
		1:
			_ticks += 1
			if _ticks >= PIN_AFTER:
				var body: RigidBody3D = _game.player.body()
				if _pin == Vector3.INF:
					_pin = body.global_position
				body.global_position = _pin
				body.linear_velocity = Vector3.ZERO
				body.angular_velocity = Vector3.ZERO
			if int(_notes._watch.counts.get("stuck", 0)) == 0 and _ticks < STUCK_WAIT_TICKS:
				return false
			var stuck: Array = _of("stuck")
			var hitches_before: int = _notes.hitches
			_t.check("a ball held in one place in play is written as stuck", stuck.size() == 1 and int(stuck[0]["stage"]) == 1 and stuck[0]["at"].size() == 3 and float(stuck[0]["s"]) >= PlayWatch.STUCK_S,
				"%d rows%s" % [stuck.size(), "" if stuck.is_empty() else ": stage %s at %s after %s s, flow %s" % [stuck[0]["stage"], stuck[0]["at"], stuck[0]["s"], stuck[0]["flow"]]])
			_hitches()
			_marks()
			var rows := _rows()
			_t.check("every row carries both clocks", rows.all(func(row): return row.has("t") and String(row.get("utc", "")).length() >= 19), "%d rows" % rows.size())
			var path: String = _notes.path
			_game.remove_child(_notes)
			_notes.free()
			var last: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path).split("\n", false)[-1])
			_t.check("closing writes the end row", last["kind"] == "end" and int(last["marks"]) == 2 and int(last["hitches"]) == hitches_before + 2 and int(last["watch"].get("stuck", 0)) == 1,
				"marks %s, hitches %s, watch %s" % [last.get("marks"), last.get("hitches"), last.get("watch")])
			quit(_t.verdict())
	return false


func _hitches() -> void:
	var before: int = _of("hitch").size()
	# Three long frames 20 ms apart, a short frame, then quiet: one burst. A second burst a second later.
	_notes.frame(40.0, 100.00)
	_notes.frame(26.0, 100.03)
	_notes.frame(120.0, 100.15)
	_notes.frame(7.0, 100.16)
	_notes.frame(24.9, 100.40)
	_t.check("a burst is held open while its frames keep coming", _of("hitch").size() == before, "%d rows" % _of("hitch").size())
	_notes.frame(7.0, 100.70)
	var one: Array = _of("hitch")
	_t.check("three long frames close into one hitch row", one.size() == before + 1 and int(one[-1]["frames"]) == 3 and float(one[-1]["worst_ms"]) == 120.0
		and float(one[-1]["total_ms"]) == 186.0 and float(one[-1]["t"]) == 100.0 and int(one[-1]["stage"]) == 1,
		"%s" % [one[-1] if one.size() > before else "no row"])
	_notes.frame(25.0, 101.50)
	_notes.frame(7.0, 102.10)
	var two: Array = _of("hitch")
	_t.check("a frame at the limit a second later is its own row; shorter frames write none", two.size() == before + 2 and int(two[-1]["frames"]) == 1, "%d rows" % two.size())


func _marks() -> void:
	_notes._input(_key(KEY_F8))
	var echo := _key(KEY_F8)
	echo.echo = true
	_notes._input(echo)
	_notes._input(_key(KEY_F7))
	var marks: Array = _of("mark")
	_t.check("F8 writes one mark with the place; a held key and another key write none", marks.size() == 1 and int(marks[0]["n"]) == 1 and int(marks[0]["stage"]) == 1 and marks[0].has("at") and marks[0].has("words"),
		"%s" % [marks])
	_notes._input(_stick(JOY_BUTTON_LEFT_STICK, true))
	_t.check("one stick click is not a mark", _of("mark").size() == 1, "%d marks" % _of("mark").size())
	_notes._input(_stick(JOY_BUTTON_RIGHT_STICK, true))
	_notes._input(_stick(JOY_BUTTON_RIGHT_STICK, false))
	_notes._input(_stick(JOY_BUTTON_LEFT_STICK, false))
	_t.check("both stick clicks together are one mark", _of("mark").size() == 2, "%d marks" % _of("mark").size())
