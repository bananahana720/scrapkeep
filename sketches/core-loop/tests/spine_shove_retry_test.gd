extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# A killing blow's shove must not survive death (FIXWAVE spine [C]). Combat resolves a
# lethal hit as damage first, then the shove through add_external_accel, the way a
# lobber shell or Brindle's slag lands. After R the ball must re-enter the stage the
# way the launch delivered it: its velocity two ticks into the retry is the snapshot's
# entry velocity plus gravity, with no trace of the old blast. The same holds for a
# shove that lands while the ball is already frozen.

const SHOVE := Vector3(9.0, 0.0, -6.0)
const TOLERANCE := 0.35

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _entry := Vector3.ZERO
var _results := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	var flow = _game.flow
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			flow.press_start()
			flow.choose_class(0)
			_phase = "rolling"
			_wait = 0
		"rolling":
			if _wait == 30:
				_game.run.damage(1.0e9, "test")
				_game.player.add_external_accel(SHOVE / delta)
				_results["dead_state"] = flow.state_name()
				_phase = "dead"
				_wait = 0
		"dead":
			if _wait == 3:
				_game.player.add_external_accel(SHOVE / delta)
				flow.retry_stage()
				_entry = _game.run.snapshot_value("entry_velocity")
				_phase = "retry"
				_wait = 0
		"retry":
			if _wait == 2:
				var v: Vector3 = _game.player.body().linear_velocity
				var flat := Vector2(v.x - _entry.x, v.z - _entry.z).length()
				_report("retry after a lethal shove", _results["dead_state"] == "dead" and flow.state_name() == "stage" and flat <= TOLERANCE,
					"died to a %.0f m/s shove (state %s); two ticks into the retry the ball moves at %s against entry %s, horizontal gap %.2f m/s (needs <= %.2f)"
						% [SHOVE.length(), _results["dead_state"], _fmt(v), _fmt(_entry), flat, TOLERANCE])
				print("spine_shove_retry_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


static func _fmt(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
