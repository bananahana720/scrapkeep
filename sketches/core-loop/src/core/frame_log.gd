extends Node

# --frame-log=<file>: the game logs its own frame times for scripts/frametime-check.mjs where
# MangoHud does not run (macOS). The CSV reads as MangoHud's does to that tool: an info pair of
# rows, a "frametime" header, then one row a drawn frame in milliseconds.
# --frame-log-warmup=<s> (default 10): logging starts this many seconds after the engine started.
# --frame-log-seconds=<s> (default 300): and stops once the logged frames add up to this; the file is
# written then, in one go. A game that closes before that writes nothing, as MangoHud's log.
# The clock: Time.get_ticks_usec() read on RenderingServer.frame_post_draw, which the engine emits
# once a frame after the viewports are drawn and the frame is handed to the display, and not at all
# when no frame is drawn, so each delta is one presented frame to the next, like MangoHud's.
# Cost: without the flag this node is never made. With it, one clock read and one append a frame.
# It only reads the clock: nothing in the game or the simulation reads it back.

const SafeStore := preload("res://src/core/safe_store.gd")

const FLAG := "--frame-log="
const WARMUP_FLAG := "--frame-log-warmup="
const SECONDS_FLAG := "--frame-log-seconds="
const INFO := "scrapkeep_frame_log"

var path := ""
var warmup_s := 10.0
var seconds := 300.0
var written := false

var _last_usec := -1
var _logged_ms := 0.0
var _frames := PackedFloat64Array()


static func wanted() -> bool:
	return Array(OS.get_cmdline_user_args()).any(func(arg: String): return arg.begins_with(FLAG))


func _ready() -> void:
	name = "FrameLog"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(FLAG):
			path = arg.trim_prefix(FLAG)
		elif arg.begins_with(WARMUP_FLAG):
			warmup_s = maxf(float(arg.trim_prefix(WARMUP_FLAG)), 0.0)
		elif arg.begins_with(SECONDS_FLAG):
			seconds = maxf(float(arg.trim_prefix(SECONDS_FLAG)), 0.001)
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)


func _on_frame_drawn() -> void:
	frame(Time.get_ticks_usec())


# One drawn frame at now_usec on the engine's clock (microseconds since it started).
func frame(now_usec: int) -> void:
	if written:
		return
	if _last_usec >= 0 and now_usec >= int(warmup_s * 1000000.0):
		var ms := (now_usec - _last_usec) / 1000.0
		_frames.append(ms)
		_logged_ms += ms
	_last_usec = now_usec
	if _logged_ms >= seconds * 1000.0:
		write()


func write() -> void:
	written = true
	_exit_tree()
	var info := PackedStringArray([INFO])
	for value in [Engine.get_version_info().get("string", ""), RenderingServer.get_current_rendering_driver_name(),
			RenderingServer.get_video_adapter_name(), DisplayServer.window_get_vsync_mode()]:
		info.append(str(value).replace(",", " ").replace("\n", " "))
	var lines := PackedStringArray([",".join([INFO, "engine", "driver", "adapter", "vsync"]), ",".join(info), "frametime"])
	for ms in _frames:
		lines.append("%.3f" % ms)
	var err := SafeStore.write_atomic(path, "\n".join(lines) + "\n")
	if err != OK:
		push_error("frame_log: cannot write %s: %s" % [path, error_string(err)])
		return
	print("SCRAPKEEP_FRAME_LOG %d frames %s" % [_frames.size(), path])
