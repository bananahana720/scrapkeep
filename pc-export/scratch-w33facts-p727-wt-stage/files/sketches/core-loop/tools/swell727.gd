extends "res://tools/sight_reel.gd"
# Scratch (p727, untracked, never committed): the reel's plated_brute clip with a per-frame log of the
# ball's shell (juice.shell) and its drawn width, plus one single scrap pickup in place of the pop step.
#   --script res://tools/swell727.gd -- --out=<abs dir> --only=pop,plated_brute

var _log: FileAccess
var _vp_said := false


func _pop() -> void:
	_say("one scrap piece")
	await _seconds(1.0)
	var at: Vector3 = game.player.shown_position()
	print("swell727: one scrap at clock ", snappedf(clock, 0.001))
	_mark("one_scrap")
	game.events.scrap_collected.emit(1, at, 1)
	await _seconds(2.0)
	_say("")
	await _seconds(GAP)


func _beat(id: String) -> void:
	super._beat(id)
	_mark(id)


func _mark(what: String) -> void:
	if _log != null:
		_log.store_line("#mark\t%.4f\t%s" % [clock, what])
		_log.flush()


func _process(delta: float) -> bool:
	var r: bool = super._process(delta)
	if game == null or game.presentation == null or game.player == null:
		return r
	if not _vp_said:
		_vp_said = true
		print("swell727: VIEWPORT window=", root.size, " visible_rect=", root.get_visible_rect().size, " texture=", root.get_texture().get_size(), " adapter=", RenderingServer.get_video_adapter_name())
		_log = FileAccess.open(out.path_join("shell.tsv"), FileAccess.WRITE)
		_log.store_line("clock_s\tframe\tshell\tball_px_x\tball_px_y\tcage_width_px_est\tcaption")
	var cam := root.get_camera_3d()
	if cam == null:
		return r
	var j = game.presentation.juice
	var s: float = float(j.shell)
	var c: Vector3 = game.player.shown_position()
	var p := cam.unproject_position(c)
	var w := cam.unproject_position(c + cam.global_basis.x * s).distance_to(cam.unproject_position(c - cam.global_basis.x * s))
	_log.store_line("%.4f\t%d\t%.4f\t%.0f\t%.0f\t%.1f\t%s" % [clock, Engine.get_frames_drawn(), s, p.x, p.y, w, _caption.text if _caption != null else ""])
	return r
