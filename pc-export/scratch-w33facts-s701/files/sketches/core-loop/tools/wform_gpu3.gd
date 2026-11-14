extends "res://tools/wform_gpu2.gd"
# Scratch only, never committed (re-page probe, PR 701). wform_gpu2 plus: WFORM_STEM_DIR=<abs dir> points
# MusicRows.stem_dir at that tree (<stem_dir>/<pack>/<file>) before the game boots.
const MusicRows3 := preload("res://src/presentation/music_rows.gd")


func _initialize() -> void:
	var d := OS.get_environment("WFORM_STEM_DIR")
	if d != "":
		MusicRows3.stem_dir = d
		print("wform_gpu3: stem_dir=", MusicRows3.stem_dir)
	super._initialize()
