extends SceneTree

# Runs the POC join timeline under this project's 48 kHz mixer and prints one line the
# parent test compares with its own 44.1 kHz run. Args after "--": --fixtures=<abs dir>.


func _initialize() -> void:
	var fixtures := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="):
			fixtures = arg.trim_prefix("--fixtures=")
	var poc = load(fixtures.get_base_dir().path_join("poc_sequencer.gd"))
	var r: Dictionary = poc.join_timeline(fixtures)
	# The contrast: one stem pulled at rate_scale 1.0 is resampled to the mixer rate.
	var stream := AudioStreamOggVorbis.load_from_file(fixtures.path_join("stem_drums.ogg"))
	var counts := []
	for scale in [1.0, AudioServer.get_mix_rate() / 44100.0]:
		var pb := stream.instantiate_playback()
		pb.start(0.0)
		var got := 0
		while true:
			var block := pb.mix_audio(scale, 4096)
			got += block.size()
			if block.size() < 4096:
				break
		counts.append(got)
	print("mix48 rate=%d scale=%.6f frames=%d l=%s r=%s short=%d misses=%d unscaled=%d scaled=%d" % [
		int(AudioServer.get_mix_rate()), r["rate_scale"], r["frames"], str(r["l"]).md5_text(), str(r["r"]).md5_text(),
		r["short_reads"], r["misses"], counts[0], counts[1]])
	quit(0)
