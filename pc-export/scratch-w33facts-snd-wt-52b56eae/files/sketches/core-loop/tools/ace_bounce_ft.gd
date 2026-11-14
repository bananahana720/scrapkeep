extends "res://tools/ace_bounce.gd"
# Scratch only (untracked): logs every process frame 1200-1340 with wall ms, process ms, and whether the
# recorder had started, so the ACE stall frame can be placed against the recording's start.
var _ft_prev := -1
var _ft_rows: Array = []

func _process(delta: float) -> bool:
	var f := Engine.get_process_frames()
	var now := Time.get_ticks_usec()
	if f >= 1200 and f <= 1340:
		var stage := -1
		if _game != null and _game.run != null:
			stage = _game.run.stage
		_ft_rows.append("FT f=%d wall_ms=%.2f delta_ms=%.2f proc_ms=%.2f phys_ms=%.2f recording=%s stage=%d" % [f, (now - _ft_prev) / 1000.0 if _ft_prev >= 0 else -1.0, delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, str(_started >= 0), stage])
	if f == 1341:
		for r in _ft_rows:
			print(r)
	_ft_prev = now
	return false

const _FtTerrain := preload("res://src/world/terrain.gd")

func _initialize() -> void:
	super()
	if "--ft-threaded=1" in OS.get_cmdline_user_args():
		_FtTerrain.threaded_in_bot_runs = true
		print("FT threaded stages on")
