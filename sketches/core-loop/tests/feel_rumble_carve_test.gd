extends SceneTree

const Game := preload("res://src/game.gd")
const RigidBall := preload("res://src/movement/rigid_ball.gd")

# Systems audit pass C (docs/systems-audit/mechanics/): the pad's half of the feel and the
# carve's bus fact, in the real game. A near miss, a hit taken, a slam and a carve each ask the
# pad for their RUMBLE row; a weaker fact under a stronger one is dropped; the Screen shake
# comfort row at zero stills the pad. A carve held past CARVE_MIN_S publishes carved once when it
# ends, a seam hop publishes nothing, and juice answers carved with its sound and a tap.

var _game
var _juice
var _failures := 0
var _frames := 0
var _carved: Array = []
var _phase := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _process(_delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	_frames += 1
	match _phase:
		0:
			_phase = 1
			_game.ctx.calm = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_juice = _game.presentation.juice
			_game.events.carved.connect(func(at: Vector3, seconds: float, speed: float): _carved.append([at, seconds, speed]))
			_rumbles()
			_carve_facts()
		1:
			# The kit's facts go out on the ball's next physics tick; give it a few.
			if _frames > 8:
				_phase = 2
				_check("one carved per held carve", _carved.size() == 1 and absf(float(_carved[0][1]) - 0.5) < 0.02,
					"a 0.5 s carve and a 0.1 s hop: %s" % [_carved])
				var tapped: Array = _juice.rumble_log.filter(func(r: Array): return r[0] == "carved")
				_check("juice answers carved with a tap", tapped.size() == 1, "rumble log rows for carved: %s" % [tapped])
				var heard: Array = _game.presentation.audio.cue_log.filter(func(r: Array): return r[0] == "carved") if _game.presentation.audio != null else []
				_check("juice answers carved with the release", heard.size() == 1 and heard[0][1] == "carve_release",
					"audio cue log rows for carved: %s" % [heard])
				print("feel_rumble_carve_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _rumbles() -> void:
	_juice.rumble_log.clear()
	_game.events.near_miss.emit("threat_instant", _game.player.ball_position())
	var row: Array = _juice.rumble_log.back() if not _juice.rumble_log.is_empty() else []
	_check("near miss taps the light motor", row.size() == 5 and row[0] == "near_miss" and row[4] and float(row[1]) > 0.5 and float(row[2]) == 0.0,
		"near_miss rumble row %s" % [row])
	_juice.rumble("near_miss", 0.5)
	row = _juice.rumble_log.back()
	_check("a weaker fact under a running one is dropped", row[0] == "near_miss" and not row[4], "a half near miss inside the first one's 60 ms: %s" % [row])
	_juice.rumble("player_hit")
	row = _juice.rumble_log.back()
	_check("a stronger fact takes over", row[0] == "player_hit" and row[4], "player_hit over the near miss: %s" % [row])
	_juice.set_comfort("shake", 0.0)
	_juice.rumble("beacon_unsealed")
	row = _juice.rumble_log.back()
	_check("Screen shake at zero stills the pad", not row[4] and float(row[2]) == 0.0, "beacon_unsealed at shake 0: %s" % [row])
	_juice.set_comfort("shake", 1.0)
	_juice.rumble("no_such_fact")
	_check("an unlisted fact asks nothing", _juice.rumble_log.back()[0] != "no_such_fact", "last row %s" % [_juice.rumble_log.back()])


func _carve_facts() -> void:
	var rigid = _game.player.get_node("RigidBall")
	var state = _game.player.state
	# A 0.5 s carve, then its end: one fact.
	state.carving = true
	for i in 45:
		rigid._track_carve(Vector3.ZERO, 1.0 / 90.0)
	state.carving = false
	rigid._track_carve(Vector3(1, 0, 0), 1.0 / 90.0)
	# A 0.1 s hop: none.
	state.carving = true
	for i in 9:
		rigid._track_carve(Vector3.ZERO, 1.0 / 90.0)
	state.carving = false
	rigid._track_carve(Vector3.ZERO, 1.0 / 90.0)
	var facts: Array = _game.player.kit.facts.filter(func(f: Array): return f[0] == "carved")
	_check("the ball leaves one carved fact", facts.size() == 1 and RigidBall.CARVE_MIN_S == 0.3, "kit facts %s" % [facts])


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
