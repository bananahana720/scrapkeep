extends "res://tools/ev_rec_kills.gd"
# Scratch only (job 18): the 4080 event recorder plus a forced Live Wire set completion at physics frame
# GPUWIN_CHIME_TICK (default 1800, 20 s at 90 Hz), logged as a chime_grant row. The set's banner, and so its
# chime, is logged as banner_up from presentation's banner signal when it fires.

var _chime_tick := 1800
var _chime_game = null


func _initialize() -> void:
	var t := OS.get_environment("GPUWIN_CHIME_TICK")
	if t != "":
		_chime_tick = int(t)
	process_frame.connect(_chime_tick_check)
	super._initialize()


func _chime_tick_check() -> void:
	if _game == null or not is_instance_valid(_game) or _chime_game == _game:
		return
	if _game.get("ctx") == null or _game.ctx.get("run") == null:
		return
	if Engine.get_physics_frames() < _chime_tick:
		return
	_chime_game = _game
	_ev_add("chime_grant", "live_wire")
	var banner = _game.presentation.get("banner") if _game.get("presentation") != null else null
	if banner != null:
		for part in ["live_line", "beacon_lamp", "echo_locator"]:
			banner._mark_seen("part:" + part)
		if not banner.came_up.is_connected(_on_chime_banner):
			banner.came_up.connect(_on_chime_banner)
	for part in ["live_line", "beacon_lamp", "echo_locator"]:
		_game.ctx.run.add_part(part, "probe")
	# Drop the queued part banners (headless runs use the plain banner style, which ignores seen),
	# clear the one on screen, and let the set banner come up at the next calm moment.
	var bn = _game.presentation.get("banner")
	if bn != null:
		bn._queue = bn._queue.filter(func(item: Array): return not String(item[6]).begins_with("part:"))
		bn.dismiss(false)
		bn._next()


func _on_chime_banner(key: String) -> void:
	_ev_add("banner_up", key)
