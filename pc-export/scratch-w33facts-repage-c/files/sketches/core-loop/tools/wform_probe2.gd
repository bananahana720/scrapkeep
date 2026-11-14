extends "res://tools/wform_probe.gd"
# Scratch only, never committed (Warden-form measurement, PR 701, new head). wform_probe plus ultimate control:
#   --ult_max=N         the bot may fire N ultimates, then it is held (0 = same as --hold_ult=1)
#   --ult_script=a,b,c  the bot never fires on its own; at each transport second (from the capture start) the
#                       probe fills the meter and presses the ultimate once it reads READY (roaming or arena alike)
const AbilityState := preload("res://src/core/ability_state.gd")

var _script_t: Array = []
var _script_i := 0
var _press_log: Array = []


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	if _driver == null or not _taken:
		return out
	var audio = _game.presentation.audio
	if _script_t.is_empty() and _settings.has("ult_script"):
		for s in String(_settings["ult_script"]).split(","):
			_script_t.append(float(s))
	var t: float = float(audio.engine.clock - _base_sample) / 44100.0
	if not _script_t.is_empty():
		_driver._ult_wait = 1000.0
		if _script_i < _script_t.size() and t >= float(_script_t[_script_i]):
			var ab = _game.player.abilities
			if ab.meter != null:
				ab.meter.value = ab.meter.CAP
			var st := String(ab.ultimate().get("state", ""))
			if st == AbilityState.READY:
				_driver.source.press["ultimate_pressed"] = true
				_press_log.append([snappedf(t, 0.01), audio.ace.mode if audio.ace != null else "", audio.ace.section if audio.ace != null else ""])
				_script_i += 1
			elif int(Engine.get_physics_frames()) % 90 == 0:
				_press_log.append([snappedf(t, 0.01), "waiting", st])
	if _script_i > 0 and int(Engine.get_physics_frames()) % 20 == 0 and t < float(_script_t[0]) + 26.0 and audio.ace != null:
		_press_log.append([snappedf(t, 0.01), "state", audio.engine.track, audio._ult_took_band, audio._ace_arrival_stage, audio._ace_arrival_at, audio.ace_playing(), audio.ace.mode, audio.engine.in_drop(), audio._ult_armed, audio._stage_now])
	if not _script_t.is_empty():
		pass
	elif _settings.has("ult_max") and _ult_rows.size() >= int(_settings["ult_max"]):
		_driver._ult_wait = 1000.0
	return out


func _finish() -> void:
	var f := FileAccess.open("%s/%s.presses.json" % [String(_settings["out"]).get_base_dir(), String(_settings["out"]).get_file().get_basename()], FileAccess.WRITE)
	f.store_string(JSON.stringify(_press_log))
	f.close()
	super()
