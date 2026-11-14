extends "res://tools/bot_run.gd"
# Scratch (untracked): bot_run unchanged, plus one line of window/viewport facts a few frames in and at the end.
var _uw_said := false
var _uw_last := 0


func _uw_facts(tag: String) -> void:
	var img := root.get_texture().get_image()
	print("uwrows: ", tag, " frame=", _frame_index, " window=", DisplayServer.window_get_size(), " visible_rect=", root.get_visible_rect(),
		" aspect=", root.content_scale_aspect, " mode=", root.content_scale_mode, " content_size=", root.content_scale_size,
		" texture=", root.get_texture().get_size(), " image=", img.get_size(), " adapter=", RenderingServer.get_video_adapter_name())


func _process(delta: float) -> bool:
	if not _uw_said and _frame_index >= 40:
		_uw_said = true
		_uw_facts("start")
	_uw_last = _frame_index
	return super._process(delta)


func _finish() -> void:
	_uw_facts("end")
	super._finish()
