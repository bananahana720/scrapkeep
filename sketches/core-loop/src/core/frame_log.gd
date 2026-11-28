extends Node

# MangoHud does not run on macOS; RenderingServer.frame_post_draw emits once per presented frame to match its CSV.

const SafeStore := preload("res://src/core/safe_store.gd")
const CliFlags := preload("res://src/core/cli_flags.gd")

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
	return CliFlags.has_prefix(FLAG)


func _ready() -> void:
	name = "FrameLog"
	path = CliFlags.value_of(FLAG)
	if CliFlags.has_prefix(WARMUP_FLAG):
		warmup_s = maxf(float(CliFlags.value_of(WARMUP_FLAG)), 0.0)
	if CliFlags.has_prefix(SECONDS_FLAG):
		seconds = maxf(float(CliFlags.value_of(SECONDS_FLAG)), 0.001)
	if path.is_empty():
		push_error("frame_log: %s needs a path" % FLAG)
		written = true
		return
	RenderingServer.frame_post_draw.connect(_on_frame_drawn)


func _exit_tree() -> void:
	_disconnect()


func _disconnect() -> void:
	if RenderingServer.frame_post_draw.is_connected(_on_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_on_frame_drawn)


func _on_frame_drawn() -> void:
	frame(Time.get_ticks_usec())


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
	_disconnect()
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
