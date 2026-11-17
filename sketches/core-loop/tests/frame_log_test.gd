extends SceneTree

const FrameLog := preload("res://src/core/frame_log.gd")
const T := preload("res://tests/support/t.gd")

# --frame-log (src/core/frame_log.gd), the frame log scripts/frametime-check.mjs reads on macOS:
#   - without the flag the game is not asked for one (wanted() is false);
#   - frames before the warmup are not logged; the first one after it is timed from the frame before;
#   - the file is written once the logged frames reach --frame-log-seconds, and frames after are not;
#   - the file holds an info pair, a "frametime" header, then one row a frame in milliseconds.
# Evidence limit: headless draws no frames, so the frames here are fed to frame() by hand. That
# RenderingServer.frame_post_draw fires once a presented frame, and what the log costs on a GPU,
# is shown only by a windowed run (node scripts/frametime-check.mjs --capture=engine).

var _t := T.new("frame_log_test")


func _initialize() -> void:
	_t.check("no --frame-log flag, no log wanted", not FrameLog.wanted(), "user args %s" % [OS.get_cmdline_user_args()])
	var file := OS.get_user_data_dir().path_join("frame-log-test-%d.csv" % OS.get_process_id())
	var frame_log = FrameLog.new()
	frame_log.path = file
	frame_log.warmup_s = 1.0
	frame_log.seconds = 0.1
	# 0.99 s and 0.995 s are warmup; 1.005 s is the first logged frame, 10 ms after the one before.
	for usec in [990000, 995000, 1005000, 1021700, 1081700, 1091700]:
		frame_log.frame(usec)
	_t.check("not written before the logged frames reach the seconds", not frame_log.written and not FileAccess.file_exists(file), "written %s" % frame_log.written)
	frame_log.frame(1101700)
	_t.check("written once the logged frames reach the seconds", frame_log.written and FileAccess.file_exists(file), "written %s" % frame_log.written)
	frame_log.frame(1201700)
	var lines := FileAccess.get_file_as_string(file).split("\n", false)
	_t.check("an info pair before the header", lines.size() >= 2 and lines[0].begins_with(FrameLog.INFO + ",") and lines[1].begins_with(FrameLog.INFO + ","), "%s" % [lines.slice(0, 2)])
	_t.eq("one header cell, frametime", lines[2] if lines.size() > 2 else "", "frametime")
	_t.eq("one row a logged frame, in ms, none after the end", Array(lines.slice(3)), ["10.000", "16.700", "60.000", "10.000", "10.000"])
	DirAccess.remove_absolute(file)
	frame_log.free()
	quit(_t.verdict())
