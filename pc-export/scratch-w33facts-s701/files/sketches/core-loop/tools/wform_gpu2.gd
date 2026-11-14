extends "res://tools/wform_gpu.gd"
# Scratch only, never committed (Warden-form measurement, PR 701, new head). wform_gpu plus:
#   --drive-guard=1   once the Warden fight has played its build for 2 bars, the player is frozen and a stand-in guard
#                     (as tests/warden_form_test.gd uses) is read through audio._on_posture_changed: the tight build,
#                     a drain back to the build, an unlanded breath, then a breath and the shattering hit. Rows go to
#                     the events file as kind "drive".
#   --ult-max=N       the bot may fire N ultimates, then it is held (hold-ult=1 still holds from the start)

class Guard extends Node3D:
	var chunks := 4

	func chunks_left() -> int:
		return chunks

var _dg_state := 0
var _dg_start := -1
var _dg_build_since := -1
var _dg_guard
var _dg_real = null
var _dg_steps := [
	[0.0, 80.0, false, 0, "tight"],
	[3.0, 40.0, false, 0, "drain"],
	[6.0, 80.0, false, 0, "tight2"],
	[8.0, 100.0, true, 0, "stagger_unlanded"],
	[9.5, 0.0, false, 0, "unlanded_end"],
	[13.0, 80.0, false, 0, "tight3"],
	[14.0, 100.0, true, 0, "stagger_hit"],
	[15.0, 0.0, false, -1, "shatter"],
	[23.0, 0.0, false, 0, "end"],
]
var _dg_i := 0


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _driver != null and _settings.has("ult-max") and _settings.get("hold-ult", "0") != "1":
		var n := 0
		for r in _ev_rows:
			if r.contains("\tultimate_started\t"):
				n += 1
		if n >= int(_settings["ult-max"]):
			_driver._ult_wait = 1000.0
	if _settings.get("drive-guard", "0") != "1" or _game == null or _game.presentation == null:
		return out
	var audio = _game.presentation.audio
	if audio == null or audio.ace == null:
		return out
	var ace = audio.ace
	if _dg_state == 0:
		if ace.mode == "warden" and ace.section == "build":
			if _dg_build_since < 0:
				_dg_build_since = audio.engine.clock
			elif audio.engine.clock - _dg_build_since > int(audio.engine.bar_len() * 2.0):
				_dg_state = 1
				_dg_start = audio.engine.clock
				_dg_guard = Guard.new()
				_game.add_child(_dg_guard)
				_dg_real = _game.flow.warden
				_game.flow.warden = _dg_guard
				_game.player.set_frozen(true)
				_ev_add("drive", "begin")
		return out
	if _dg_state == 1:
		while _dg_i < _dg_steps.size() and audio.engine.clock >= _dg_start + int(audio.engine.bar_len() * float(_dg_steps[_dg_i][0])):
			var s: Array = _dg_steps[_dg_i]
			if int(s[3]) == -1:
				_dg_guard.chunks -= 1
			_ev_add("drive", String(s[4]))
			if String(s[4]) == "end":
				_game.flow.warden = _dg_real
				_game.player.set_frozen(false)
				_dg_guard.queue_free()
				_dg_state = 2
				_dg_i += 1
				break
			audio._on_posture_changed(_dg_guard, float(s[1]), bool(s[2]))
			_dg_i += 1
	return out
