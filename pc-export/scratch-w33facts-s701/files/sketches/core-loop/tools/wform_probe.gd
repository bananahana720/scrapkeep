extends "res://tools/ace_bounce.gd"
# Scratch only, never committed (Warden-form measurement, PR 701). An ace_bounce run that also:
#  - records the Music bus, the SFX bus and Master (three AudioEffectRecord, same start tick),
#  - takes over audio._process so every pumped music block (audio.out_music) is copied sample-exact
#    in transport samples to <out>.music.f32 (interleaved float32 stereo, first sample = transport
#    sample cap_start),
#  - logs posture_changed, the Warden's guard each tick it changes, the sequencer's own events_log
#    and key_log in transport samples, the ring's queued frames and the bus volumes.
# Extra args: --drive=1 (script drives the guard if the bot does not; see _drive), --label=<text>.

var _rec_music: AudioEffectRecord
var _rec_sfx: AudioEffectRecord
var _taken := false
var _cap := PackedVector2Array()
var _cap_prev := -1
var _cap_start := -1
var _cap_mismatch := 0
var _ticks: Array = []
var _last_sig := ""
var _posture_rows: Array = []
var _frame_rows: Array = []
var _drive_state := 0
var _drive_t := 0.0
var _guard_log: Array = []
var _ace_id := 0
var _ev_idx := 0
var _ev_all: Array = []
var _key_all: Array = []
var _key_idx := 0
var _ult_rows: Array = []


func _bus_rec(bus: String) -> AudioEffectRecord:
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), rec)
	return rec


func _process(delta: float) -> bool:
	if not _taken or _game == null or _game.presentation == null:
		return false
	var audio = _game.presentation.audio
	audio._process(delta)
	var now: int = audio.engine.clock
	if _cap_prev >= 0 and now > _cap_prev:
		var n := now - _cap_prev
		var out: PackedVector2Array = audio.out_music
		if out.size() == n:
			_cap.append_array(out)
		else:
			_cap_mismatch += 1
			var pad := PackedVector2Array()
			pad.resize(n)
			_cap.append_array(pad)
	_cap_prev = now
	return false


func _physics_process(delta: float) -> bool:
	var had_driver := _driver != null
	var out := super(delta)
	if _record != null and _rec_music == null:
		_rec_music = _bus_rec("Music")
		_rec_sfx = _bus_rec("SFX")
	if _driver != null and not had_driver:
		var audio = _game.presentation.audio
		_rec_music.set_recording_active(true)
		_rec_sfx.set_recording_active(true)
		audio.set_process(false)
		_taken = true
		_cap_start = audio.engine.clock
		_cap_prev = audio.engine.clock
		_game.events.posture_changed.connect(_on_posture_row)
		_game.events.ultimate_started.connect(func(_id: String, _path: String, _from: Vector3, _to: Vector3, _s: float):
			_ult_rows.append([snappedf(_now(), 0.001), audio.engine.clock - _base_sample]))
	if _driver == null or not _taken:
		return out
	var audio2 = _game.presentation.audio
	var ace = audio2.ace
	var w = _game.flow.get("warden") if _game.flow != null else null
	var wv = is_instance_valid(w)
	var sec: String = ace.section if ace != null else ""
	var ws: String = ace.warden_state if ace != null else ""
	var post := -1.0
	var stag := false
	var chunks := -1
	if wv and w.has_method("posture"):
		post = snappedf(w.posture(), 1.0)
		stag = w.staggered()
		chunks = w.chunks_left()
	var sig := "%s|%s|%s|%s|%s|%s" % [sec, ws, post, stag, chunks, audio2.mix_state()]
	if sig != _last_sig:
		_last_sig = sig
		_ticks.append([snappedf(_now(), 0.001), audio2.engine.clock - _base_sample, sec, ws, post, stag, chunks, audio2.mix_state(),
			ace.mode if ace != null else "", _queued(audio2), AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))])
	_frame_rows.append(delta)
	if ace != null:
		if ace.get_instance_id() != _ace_id:
			_ace_id = ace.get_instance_id()
			_ev_idx = 0
			_key_idx = 0
			_ev_all.append(["ace_instance", snappedf(_now(), 0.001), ace.manifest.get("theme", "") if ace.get("manifest") != null else ""])
		while _ev_idx < ace.events_log.size():
			var e = ace.events_log[_ev_idx]
			_ev_all.append([e[0], int(e[1]) - _base_sample, e[2], snappedf(_now(), 0.001), ace.mode])
			_ev_idx += 1
		while _key_idx < ace.key_log.size():
			_key_all.append([int(ace.key_log[_key_idx][0]) - _base_sample, ace.key_log[_key_idx][1]])
			_key_idx += 1
	if _settings.get("hold_ult", "0") == "1":
		_driver._ult_wait = 1000.0
	if _settings.get("drive", "0") == "1":
		_drive(delta, w)
	return out


func _queued(audio) -> int:
	if audio._music_pb == null:
		return -1
	return audio._ring_capacity - audio._music_pb.get_frames_available()


func _on_posture_row(enemy: Node3D, posture: float, staggered: bool) -> void:
	var audio = _game.presentation.audio
	var chunks := -1
	if is_instance_valid(enemy) and enemy.has_method("chunks_left"):
		chunks = enemy.chunks_left()
	_posture_rows.append([snappedf(_now(), 0.001), audio.engine.clock - _base_sample, posture, staggered, chunks, _queued(audio)])


# Not used unless --drive=1: nothing here runs in the default capture.
func _drive(_delta: float, _w) -> void:
	pass


func _finish() -> void:
	var audio = _game.presentation.audio
	_rec_music.set_recording_active(false)
	_rec_sfx.set_recording_active(false)
	var dir: String = String(_settings["out"]).get_base_dir()
	var stem: String = String(_settings["out"]).get_file().get_basename()
	var wm: AudioStreamWAV = _rec_music.get_recording()
	wm.save_to_wav("%s/%s.music_bus.wav" % [dir, stem])
	var ws: AudioStreamWAV = _rec_sfx.get_recording()
	ws.save_to_wav("%s/%s.sfx_bus.wav" % [dir, stem])
	var f := FileAccess.open("%s/%s.music.f32" % [dir, stem], FileAccess.WRITE)
	f.store_buffer(_cap.to_byte_array())
	f.close()
	var ev := _ev_all
	var keys := _key_all
	var raw := []
	for row in audio.cue_log:
		if row.size() > 3 and int(row[3]) >= _base_sample:
			raw.append([row[0], row[1], row[2], int(row[3]) - _base_sample])
	var avg := 0.0
	var worst := 0.0
	for d in _frame_rows:
		avg += d
		worst = maxf(worst, d)
	var info := {"label": _settings.get("label", ""), "warden_form": _game.tuning.option("warden_form"), "cap_start": _cap_start - _base_sample,
		"cap_samples": _cap.size(), "cap_mismatch": _cap_mismatch, "base_sample": _base_sample,
		"events_log": ev, "key_log": keys, "ticks_cols": ["wall_s", "transport_sample", "section", "warden_state", "posture", "staggered", "chunks", "mix_state", "ace_mode", "ring_queued", "music_bus_db"],
		"ticks": _ticks, "posture_cols": ["wall_s", "transport_sample", "posture", "staggered", "chunks", "ring_queued"], "posture_rows": _posture_rows,
		"cue_log_raw": raw, "ultimate_started": _ult_rows, "hold_ult": _settings.get("hold_ult", "0"), "physics_ticks": _frame_rows.size(), "delta_avg": avg / maxf(_frame_rows.size(), 1), "delta_max": worst}
	var jf := FileAccess.open("%s/%s.probe.json" % [dir, stem], FileAccess.WRITE)
	jf.store_string(JSON.stringify(info, "  "))
	jf.close()
	super()
