extends "res://tools/wform_probe2.gd"
# Scratch only, never committed (re-page probe, PR 701): WFORM_STEM_DIR points MusicRows.stem_dir before the game boots.
const MusicRowsP := preload("res://src/presentation/music_rows.gd")


func _initialize() -> void:
	var d := OS.get_environment("WFORM_STEM_DIR")
	if d != "":
		MusicRowsP.stem_dir = d
	print("wform_probe3: stem_dir=[", MusicRowsP.stem_dir, "]")
	super._initialize()
