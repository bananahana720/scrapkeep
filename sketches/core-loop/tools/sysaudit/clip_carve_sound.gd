extends SceneTree

# Systems audit pass C clip: renders the carve's release cue (SfxBank "carve_release") to a WAV
# for a listening review, and prints its length and peak. It writes only to --out.
#   $GODOT_BIN --headless --path sketches/core-loop --script res://tools/sysaudit/clip_carve_sound.gd -- --out=<dir>

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Synth := preload("res://src/presentation/synth.gd")


func _initialize() -> void:
	var out := "."
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var buf := SfxBank.samples("carve_release")
	var wav := Synth.to_wav(buf)
	var path := out.path_join("carve_release.wav")
	var err := wav.save_to_wav(path)
	print("clip_carve_sound: %s, %.3f s, peak %.3f, trim %.1f dB, save %s" % [path, buf.size() / float(Synth.RATE), Synth.wav_peak(wav), SfxBank.trim_db("carve_release"), error_string(err)])
	quit(0 if err == OK and buf.size() > 0 else 1)
