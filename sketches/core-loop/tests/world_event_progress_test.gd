extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# The event_progress seam (presentation's REQUEST): a live participatory event
# publishes event_progress(event_id, fraction) from its own model, in steps of at
# least 0.01, rising from 0 to 1 before it ends won. Presentation's escalation then
# follows the published value instead of its elapsed-time estimate. Stage 3's Hold the
# Relay is armed and the ball is held at the relay until it transmits.

const LIMIT := 90 * 30

# Preserve the legacy three-stage rule on a double using surviving maps.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
var _offer := {}
var _values: Array[float] = []
var _ended := ""
var _ended_after := -1
var _audio_live_before := true
var _audio_live_after := false
var _audio_ready := false


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	var world = _game.get_node("World")
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_audio().bake_now()
			if _game.events.has_signal("event_progress"):
				_game.events.connect("event_progress", func(id: String, fraction: float):
					if id == "hold_the_relay":
						_values.append(fraction)
						if _values.size() == 1:
							_audio_live_after = _audio().get("_event_progress_live") == true)
			_game.events.event_ended.connect(func(id: String, outcome: String):
				if id == "hold_the_relay":
					_ended = outcome
					_ended_after = _values.size())
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_game.flow.enter_stage(3, Vector3(0.0, 0.0, 12.0), false)
			for offer in world.events.offers:
				if offer["id"] == "hold_the_relay":
					_offer = offer
			_phase = "arm"
			_wait = 0
		"arm":
			if _offer.is_empty():
				_report("relay offered", false, "stage 3 offered no Hold the Relay")
				return _finish()
			if _wait == 2:
				_audio_ready = _audio().get("sound_ready") == true
				_audio_live_before = _audio().get("_event_progress_live") == true
				_offer["phase"] = EventDirector.ARMED
				_hold_at_relay()
				_phase = "hold"
				_wait = 0
		"hold":
			if _wait % 45 == 0:
				_hold_at_relay()
			if _ended != "" or _wait > LIMIT:
				return _finish()
	return false


func _audio():
	return _game.presentation.audio


func _hold_at_relay() -> void:
	var model = _offer["model"]
	var at: Vector3 = _game.ctx.terrain.drop_point(model.relay.x, model.relay.y, 1.2)
	_game.player.reset_to(at, Vector3.ZERO)
	_game.player.body().global_position = at


func _finish() -> bool:
	var rising := true
	var steps_ok := true
	for i in range(1, _values.size()):
		rising = rising and _values[i] > _values[i - 1]
		if i < _values.size() - 1:
			steps_ok = steps_ok and _values[i] - _values[i - 1] >= 0.0099
	var first: float = _values[0] if not _values.is_empty() else -1.0
	var last: float = _values[-1] if not _values.is_empty() else -1.0
	_report("progress on the bus", _values.size() >= 20 and first <= 0.01 and is_equal_approx(last, 1.0) and rising and steps_ok,
		"Hold the Relay published %d event_progress values from %.3f to %.3f, rising %s, every step but the last at least 0.01 %s"
			% [_values.size(), first, last, rising, steps_ok])
	_report("ends after full progress", _ended == "won" and _ended_after == _values.size() and _ended_after > 0,
		"event_ended(%s) came after %d of %d progress values" % [_ended, _ended_after, _values.size()])
	_report("presentation follows it", _audio_ready and not _audio_live_before and _audio_live_after,
		"presentation ready %s; on its elapsed-time estimate before the first value (live %s), on the published value from the first one (live %s)"
			% [_audio_ready, _audio_live_before, _audio_live_after])
	print("world_event_progress_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
	return true
