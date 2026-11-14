extends "res://tools/bot_run.gd"
# 4080 event recorder: tools/bot_run.gd unchanged, plus one TSV row per game event with the frame-log frame index.
#   GPUWIN_EV=<abs .tsv>  columns: frame, tick, kind, detail

var _ev_out := ""
var _ev_rows := PackedStringArray()
var _ev_hooked = null
# Optional: GPUWIN_SHOT=<abs .png> and GPUWIN_SHOT_STAGE=<n> save the screen 10 frames after stage n is entered.
var _shot_out := ""
var _shot_stage := 0
var _shot_in := 0


func _initialize() -> void:
	_ev_out = OS.get_environment("GPUWIN_EV")
	_shot_out = OS.get_environment("GPUWIN_SHOT")
	_shot_stage = int(OS.get_environment("GPUWIN_SHOT_STAGE"))
	process_frame.connect(_ev_tick)
	super._initialize()


func _ev_add(kind: String, detail: String) -> void:
	_ev_rows.append("%d\t%d\t%s\t%s" % [_frame_index, Engine.get_physics_frames(), kind, detail])


func _ev_tick() -> void:
	if _shot_in > 0:
		_shot_in -= 1
		if _shot_in == 0:
			root.get_texture().get_image().save_png(_shot_out)
	if _game == null or not is_instance_valid(_game) or _ev_hooked == _game:
		return
	if _game.get("ctx") == null or _game.ctx.get("events") == null:
		return
	_ev_hooked = _game
	var ev = _game.ctx.events
	ev.stage_entered.connect(func(s: int, retry: bool): _ev_add("stage_entered", str(s) + (" retry" if retry else "")))
	if _shot_out != "":
		ev.stage_entered.connect(func(s: int, _retry: bool):
			if s == _shot_stage:
				_shot_in = 10)
	ev.warden_engaged.connect(func(s: int): _ev_add("warden_engaged", str(s)))
	ev.ultimate_started.connect(func(id: String, _p: String, _f: Vector3, _t: Vector3, _s: float): _ev_add("ultimate_started", id))
	ev.event_started.connect(func(id: String): _ev_add("event_started", id))
	ev.event_ended.connect(func(id: String, outcome: String): _ev_add("event_ended", id + " " + outcome))
	# A Dispatcher spawn, with how many terrain overlays (landed slides, lips) stand at that moment.
	ev.enemy_spawned.connect(func(_e: Node3D, kind: String):
		if kind == "dispatcher":
			var terr = _game.ctx.get("terrain")
			var downs = terr.overlays.filter(func(o): return String(o).ends_with("_after")) if terr != null else []
			_ev_add("dispatcher_spawned", "overlays=%d after=%d" % [terr.overlays.size() if terr != null else -1, downs.size()]))
	ev.enemy_killed.connect(func(kind: String, _at: Vector3, _v: int): _ev_add("enemy_killed", kind))
	ev.near_miss.connect(func(kind: String, _at: Vector3): _ev_add("near_miss", kind))
	ev.slammed.connect(func(_at: Vector3, strength: float, _f: float): _ev_add("slammed", "%.2f" % strength))
	ev.player_died.connect(func(): _ev_add("player_died", ""))
	ev.boss_arena_entered.connect(func(): _ev_add("boss_arena_entered", ""))
	ev.boss_phase_changed.connect(func(phase: int, pname: String): _ev_add("boss_phase_changed", "%d %s" % [phase, pname]))
	ev.fight_phase_changed.connect(func(fid: String, phase: int, phases: int): _ev_add("fight_phase_changed", "%s %d/%d" % [fid, phase, phases]))
	ev.boss_defeated.connect(func(): _ev_add("boss_defeated", ""))
	ev.event_announced.connect(func(id: String, secs: float): _ev_add("event_announced", "%s %.1f" % [id, secs]))


func _finalize() -> void:
	if _ev_out != "":
		var f := FileAccess.open(_ev_out, FileAccess.WRITE)
		f.store_string("frame\ttick\tkind\tdetail\n" + "\n".join(_ev_rows) + "\n")
		f.close()
