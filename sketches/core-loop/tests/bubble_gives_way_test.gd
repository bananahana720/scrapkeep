extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const LoreRows := preload("res://src/core/lore_rows.gd")

# One thing to read at a time (moss_bubble.gd _tick_turn): the stage's hello and the Warden's
# line give the screen to a comic beat's words and take their turn again when the beat has been
# read. Found on film at the flume: the Warden's reveal card comes up over the crew's hello, in
# the bubble's place, on the sighting that also brings the Warden's own line.
#
#   W1-W3  the film's case, by the game's real sighting: the flume Warden's reveal card comes up
#          over the crew's hello; the hello goes down, the Warden's line waits, and both take
#          their turns when the card has gone
#   W4-W5  a Warden's line that is up when a beat starts goes down and comes back whole
#   H1-H2  a hello never starts under a beat
#   H3-H6  a hello that is up when a beat starts goes down, keeps its line, leaves the talk key
#          to the world, and comes back at the same line
#   H7     cruise speed leaves a held hello behind, as it leaves one that is up
#   H8     the Warden's engagement ends a held hello
#   B1     a boss's line is not held by a card (ruling cf: his line follows his picture)

const SETTLE_FRAMES := 12
const DT := 0.1
const BEAT := "spillway_clear"

var _game
var _bubble
var _beat
var _phase := "boot"
var _frames := 0
var _t := T.new("bubble_gives_way_test")


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)


func _intro(zone: String, subject: String, pilot := "") -> Dictionary:
	for row in LoreRows.ROWS:
		if row["kind"] == "intro" and row["zone"] == zone and row["subject"] == subject and row.get("pilot", "") == pilot:
			return row
	return {}


func _showing(row: Dictionary) -> bool:
	return not row.is_empty() and _bubble.visible and _bubble.text == row["text"]


func _press(action: String) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event, true)


func _hello() -> void:
	_bubble._zones_played.clear()
	_bubble._begin_exchange(_game.run.stage)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _phase != "boot" and _frames < SETTLE_FRAMES:
		return false
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_bubble = _game.get_node("Workshop").bubble
			_beat = _game.presentation.flourish
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "flume"
			_frames = 0
		"flume":
			# A calm test game places no Warden; the reveal reads the real one's kind.
			_game.flow.force_warden = true
			_game.flow.enter_stage(2, Vector3.ZERO, false)
			_phase = "checks"
			_frames = 0
		"checks":
			_wardens_line()
			_hellos()
			_boss_line()
			print("bubble_gives_way_test: %s" % ("PASS" if _t.verdict() == 0 else "FAIL"))
			quit(_t.verdict())
			return true
	return false


func _wardens_line() -> void:
	var line := _intro("1-2", "warden")
	# The run's cold open is still reading after the jump to the flume, and the hello waits for it.
	_beat.stop_all()
	_bubble._process(DT)
	var hello: String = _bubble.text
	_t.check("the flume crew's hello is up", _bubble.visible and _bubble._exchange.size() > 1 and _bubble._exchange_index == 0, "bubble '%s'" % hello)
	_game.flow._read_sighting(_game.flow._warden_at)
	_t.check("W1 the flume Warden's sighting plays its reveal card", _beat.id == "flume_warden_reveal" and _game.presentation.reading(),
		"beat '%s', reading %s" % [_beat.id, _game.presentation.reading()])
	_bubble._process(DT)
	_t.check("W2 the hello goes down for the card and the Warden's line waits: nothing in the bubble", not line.is_empty() and not _bubble.visible
			and not _bubble._exchange.is_empty() and _bubble._intro_queue.size() == 1,
		"bubble '%s', hello lines %d, queued %d" % [_bubble.text, _bubble._exchange.size(), _bubble._intro_queue.size()])
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("W3 the card gone, the hello is back at its line and the Warden's line still waits its turn", _bubble.visible and _bubble.text == hello
			and _bubble._intro_queue.size() == 1, "bubble '%s', queued %d" % [_bubble.text, _bubble._intro_queue.size()])
	for i in _bubble._exchange.size():
		_press("cl_interact")
	_t.check("W3b and comes up after the hello's last line", _showing(line), "bubble '%s'" % _bubble.text)
	_t.check("the beat stands in for any card", _beat.play(BEAT) and _game.presentation.reading())
	_bubble._process(DT)
	_t.check("W4 a Warden's line that is up when a beat starts goes down and waits", not _bubble.visible and _bubble._intro_queue.size() == 1,
		"bubble '%s', queued %d" % [_bubble.text, _bubble._intro_queue.size()])
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("W5 and comes back with its whole time", _showing(line) and _bubble._hold >= _bubble.INTRO_HOLD - DT,
		"bubble '%s', hold %.2f s" % [_bubble.text, _bubble._hold])
	_bubble._end_intro()


func _hellos() -> void:
	_beat.play(BEAT)
	_hello()
	_bubble._process(DT)
	_t.check("H1 a hello does not start under a beat", not _bubble.visible and _bubble._hello_due == _game.run.stage,
		"bubble '%s', hello due %d" % [_bubble.text, _bubble._hello_due])
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("H2 and starts when the beat has been read", _bubble.visible and _bubble._exchange.size() > 1 and _bubble._hello_due == 0,
		"bubble '%s', %d lines" % [_bubble.text, _bubble._exchange.size()])
	_press("cl_interact")
	var line: String = _bubble.text
	var index: int = _bubble._exchange_index
	_t.check("the hello is on its second line", index == 1 and _bubble.visible, "line %d, '%s'" % [index, line])
	_beat.play(BEAT)
	_bubble._process(DT)
	_t.check("H3 a hello that is up when a beat starts goes down and keeps its place", not _bubble.visible and _bubble._exchange_index == index
			and not _bubble._exchange.is_empty(), "bubble '%s', line %d" % [_bubble.text, _bubble._exchange_index])
	_press("cl_interact")
	_t.check("H4 the talk key advances nothing it cannot show", _bubble._exchange_index == index and not _bubble.visible,
		"line %d" % _bubble._exchange_index)
	_bubble._process(DT)
	_t.check("H5 it stays down while the beat reads", not _bubble.visible and _game.presentation.reading())
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("H6 and comes back at the same line", _bubble.visible and _bubble.text == line and _bubble._exchange_index == index,
		"bubble '%s', line %d" % [_bubble.text, _bubble._exchange_index])
	_beat.play(BEAT)
	_bubble._process(DT)
	var was: Vector3 = _game.player.state.velocity
	_game.player.state.velocity = Vector3(_game.ctx.tuning.f("cruise") + 2.0, 0.0, 0.0)
	_bubble._process(DT)
	_t.check("H7 cruise speed leaves a held hello behind", _bubble._exchange.is_empty() and not _bubble.visible, "bubble '%s'" % _bubble.text)
	_game.player.state.velocity = was
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("and it does not come back", not _bubble.visible, "bubble '%s'" % _bubble.text)
	_hello()
	_beat.play(BEAT)
	_bubble._process(DT)
	var held: bool = not _bubble.visible and not _bubble._exchange.is_empty()
	_game.events.warden_engaged.emit(_game.run.stage)
	_beat.stop_all()
	_bubble._process(DT)
	_t.check("H8 the Warden's engagement ends a held hello", held and _bubble._exchange.is_empty() and not _bubble.visible,
		"held %s, bubble '%s'" % [held, _bubble.text])


func _boss_line() -> void:
	var line := _intro("1-2", "brindle", _game.run.class_id())
	_beat.play(BEAT)
	_game.events.boss_arena_entered.emit()
	_t.check("B1 a boss's line comes up beside a card", _game.presentation.reading() and _showing(line), "bubble '%s'" % _bubble.text)
	_beat.stop_all()
	_bubble._end_intro()
