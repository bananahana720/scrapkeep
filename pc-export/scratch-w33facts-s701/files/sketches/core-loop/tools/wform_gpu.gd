extends "res://tools/bot_run.gd"
# Scratch only, never committed (Warden-form frame times, PR 701). tools/bot_run.gd unchanged (use --frame-log=1), plus:
#  WFORM_EV=<abs .tsv>: one row per event with the frame-log frame index: columns frame, tick, kind, detail.
#  Kinds: ace_enter / ace_gap / ace_stop (the sequencer's own events_log, detail = section and transport sample),
#  posture (posture, staggered, chunks), warden_engaged, ultimate_started.
#  --hold-ult=1 keeps the bot from pressing its ultimate (the ultimate ends the recorded band; see wform notes).

var _ev_out := ""
var _ev_rows := PackedStringArray()
var _ev_hooked = null
var _ace_id := 0
var _ev_idx := 0
var _op_rows := PackedStringArray()
var _op_out := ""


func _initialize() -> void:
	_ev_out = OS.get_environment("WFORM_EV")
	_op_out = OS.get_environment("WFORM_OP")
	process_frame.connect(_ev_tick)
	super._initialize()


func _ev_add(kind: String, detail: String) -> void:
	_ev_rows.append("%d\t%d\t%s\t%s" % [_frame_index, Engine.get_physics_frames(), kind, detail])


func _op_add(src: String) -> void:
	if _game == null or not is_instance_valid(_game) or _game.get("presentation") == null or _game.presentation == null:
		return
	var audio = _game.presentation.audio
	if audio == null or audio.ace == null:
		return
	var ace = audio.ace
	var pend: String = String(ace.pending.get("section", "")) if ace.pending is Dictionary else ""
	_op_rows.append("%s\t%d\t%d\t%d\t%s\t%s\t%s\t%d" % [src, _frame_index, ace.opened, ace.open_usec, pend, ace.section, ace.mode, audio.engine.clock])


func _physics_process(delta: float) -> bool:
	var out := super(delta)
	_op_add("P")
	if _driver != null and _settings.get("hold-ult", "0") == "1":
		_driver._ult_wait = 1000.0
	return out


func _ev_tick() -> void:
	_op_add("F")
	if _game == null or not is_instance_valid(_game) or _game.get("ctx") == null or _game.ctx.get("events") == null:
		return
	if _ev_hooked != _game:
		_ev_hooked = _game
		var ev = _game.ctx.events
		ev.warden_engaged.connect(func(s: int): _ev_add("warden_engaged", str(s)))
		ev.ultimate_started.connect(func(id: String, _p: String, _f: Vector3, _t: Vector3, _s: float): _ev_add("ultimate_started", id))
		ev.stage_entered.connect(func(s: int, retry: bool): _ev_add("stage_entered", str(s) + (" retry" if retry else "")))
		ev.posture_changed.connect(func(enemy: Node3D, posture: float, staggered: bool):
			var chunks: int = enemy.chunks_left() if is_instance_valid(enemy) and enemy.has_method("chunks_left") else -1
			_ev_add("posture", "%.1f\t%s\t%d" % [posture, staggered, chunks]))
	var audio = _game.presentation.audio if _game.presentation != null else null
	if audio == null or audio.ace == null:
		return
	var ace = audio.ace
	if ace.get_instance_id() != _ace_id:
		_ace_id = ace.get_instance_id()
		_ev_idx = 0
	while _ev_idx < ace.events_log.size():
		var e = ace.events_log[_ev_idx]
		var kind: String = {"enter": "ace_enter", "gap": "ace_gap", "stop": "ace_stop", "release": "ace_release"}.get(String(e[0]), "ace_" + String(e[0]))
		_ev_add(kind, "%s\t%d\tengine_clock=%d" % [e[2], int(e[1]), audio.engine.clock])
		_ev_idx += 1


func _finalize() -> void:
	if _op_out != "":
		var g := FileAccess.open(_op_out, FileAccess.WRITE)
		g.store_string("src\tframe\topened\topen_usec\tpending\tsection\tmode\tclock\n" + "\n".join(_op_rows) + "\n")
		g.close()
	if _ev_out != "":
		var f := FileAccess.open(_ev_out, FileAccess.WRITE)
		f.store_string("frame\ttick\tkind\tdetail\n" + "\n".join(_ev_rows) + "\n")
		f.close()
