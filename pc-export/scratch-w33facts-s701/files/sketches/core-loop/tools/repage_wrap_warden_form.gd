extends "res://tests/warden_form_test.gd"
# Scratch only, never committed (re-page probe, PR 701): sets MusicRows.stem_dir from WFORM_STEM_DIR, then runs the test.
const MusicRowsW := preload("res://src/presentation/music_rows.gd")


func _initialize() -> void:
	var d := OS.get_environment("WFORM_STEM_DIR")
	if d != "":
		MusicRowsW.stem_dir = d
	print("repage_wrap: stem_dir=[", MusicRowsW.stem_dir, "]")
	super._initialize()
