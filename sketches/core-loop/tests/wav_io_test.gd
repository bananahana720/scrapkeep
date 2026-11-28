extends SceneTree

const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const WavIo := preload("res://src/presentation/wav_io.gd")
const T := preload("res://tests/support/t.gd")

const ALLOWED_RIFF_FILES := ["sfx_bank.gd", "voice_synth.gd"]

var t := T.new("wav_io_test")


func _initialize() -> void:
	_shipped_raw_digests()
	_shipped_stream_digests()
	_shipped_file_samples_digests()
	_shipped_voice_digests()
	_malformed_inputs()
	_riff_guard()
	quit(t.verdict())


func _hash_bytes(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 16)


func _hash_floats(samples: PackedFloat32Array) -> String:
	return _hash_bytes(samples.to_byte_array())


func _stream_summary(wav: AudioStreamWAV) -> Array:
	if wav == null:
		return []
	return [
		wav.format,
		wav.stereo,
		wav.mix_rate,
		wav.loop_mode,
		wav.loop_begin,
		wav.loop_end,
		wav.data.size(),
		_hash_bytes(wav.data),
	]


func _shipped_raw_digests() -> void:
	var expected := {
		"res://assets/audio/foley/lift_cage_arrive.wav": [1, false, 44100, 0, 0, 0, 123480, "9d05844492de0535"],
		"res://assets/audio/foley/prop_crew_presence.wav": [1, false, 44100, 0, 0, 0, 176400, "84f99592286a360b"],
		"res://assets/audio/specials/jolt_layer_presence.wav": [1, false, 44100, 0, 0, 0, 176400, "ba2295cb7aa45c2b"],
		"res://assets/audio/specials/jolt_layer_tell.wav": [1, false, 44100, 0, 0, 0, 88200, "beb2d5116a0c5dc8"],
		"res://assets/audio/world/spill_falls.wav": [1, false, 44100, 0, 0, 0, 352800, "f1c3b990d372acba"],
		"res://assets/audio/world/spill_splash.wav": [1, false, 44100, 0, 0, 0, 70560, "ddfc24b98865f33c"],
	}
	for p in expected:
		var bytes := FileAccess.get_file_as_bytes(p)
		t.eq("wav_io load_wav raw " + p, _stream_summary(WavIo.load_wav(p, true)), expected[p])
		t.eq("wav_io from_riff " + p, _stream_summary(WavIo.from_riff(bytes)), expected[p])
	t.eq("wav_io missing path returns null", WavIo.load_wav("res://assets/audio/foley/__missing__.wav", true), null)


func _shipped_stream_digests() -> void:
	var foley_loops := {
		"lift_cage_arrive": [false, [1, false, 44100, 0, 0, 0, 123480, "9d05844492de0535"]],
		"prop_crew_presence": [true, [1, false, 44100, 1, 0, 88200, 176400, "84f99592286a360b"]],
	}
	for id in foley_loops:
		var s := FoleyAudio.stream(id)
		var p := SfxBank.file_path(id)
		var is_loop: bool = foley_loops[id][0]
		if ResourceLoader.exists(p):
			var imported := load(p) as AudioStreamWAV
			var want_loop_end := imported.data.size() / (2 * (2 if imported.stereo else 1)) if is_loop else 0
			var want := [
				imported.format,
				imported.stereo,
				imported.mix_rate,
				AudioStreamWAV.LOOP_FORWARD if is_loop else AudioStreamWAV.LOOP_DISABLED,
				0,
				want_loop_end,
				imported.data.size(),
				_hash_bytes(imported.data),
			]
			t.eq("foley stream " + id, _stream_summary(s), want)
		else:
			t.eq("foley stream " + id, _stream_summary(s), foley_loops[id][1])
		t.check("foley stream cache " + id, FoleyAudio.stream(id) == s)

	var jolt_loops := {
		"presence": [true, [1, false, 44100, 1, 0, 88200, 176400, "ba2295cb7aa45c2b"]],
		"tell": [false, [1, false, 44100, 0, 0, 0, 88200, "beb2d5116a0c5dc8"]],
	}
	for part in jolt_loops:
		var s := FoleyAudio.stream("jolt_layer_" + part)
		var p := SfxBank.file_path("jolt_layer_" + part)
		var is_loop: bool = jolt_loops[part][0]
		if ResourceLoader.exists(p):
			var imported := load(p) as AudioStreamWAV
			var want_loop_end := imported.data.size() / (2 * (2 if imported.stereo else 1)) if is_loop else 0
			var want := [
				imported.format,
				imported.stereo,
				imported.mix_rate,
				AudioStreamWAV.LOOP_FORWARD if is_loop else AudioStreamWAV.LOOP_DISABLED,
				0,
				want_loop_end,
				imported.data.size(),
				_hash_bytes(imported.data),
			]
			t.eq("jolt stream " + part, _stream_summary(s), want)
		else:
			t.eq("jolt stream " + part, _stream_summary(s), jolt_loops[part][1])
		t.check("jolt stream cache " + part, FoleyAudio.stream("jolt_layer_" + part) == s)


func _shipped_file_samples_digests() -> void:
	var expected := {
		"hype_drop": [141120, "5b3c6213d93a035a"],
		"foreman_tell": [41845, "c8c1f69f5c7f269a"],
		"lift_cage_arrive": [61740, "e80a1ba2f016572a"],
		SfxBank.stinger_id("1-1", "sting_cold_open"): [70560, "343bf77b893247d4"],
	}
	for id in expected:
		var samples := SfxBank.file_samples(id)
		t.eq("file_samples " + id, [samples.size(), _hash_floats(samples)], expected[id])


func _shipped_voice_digests() -> void:
	var expected := {
		"res://assets/audio/foley/lift_cage_arrive.wav": [44, 123480, 61740, "b041147bc4f0e24f"],
		"res://assets/audio/foley/prop_crew_presence.wav": [44, 176400, 88200, "b8e3bac9325f602c"],
		"res://assets/audio/specials/jolt_layer_tell.wav": [44, 88200, 44100, "bc622ef81e554fdc"],
		"res://assets/audio/world/spill_splash.wav": [44, 70560, 35280, "bfa61334296412a5"],
	}
	for p in expected:
		var info := VoiceSynth._read_wav_info(p)
		var voice := VoiceSynth.load_voice_wav(p)
		t.eq("voice wav " + p, [
			int(info.get("offset", -1)),
			int(info.get("size", -1)),
			voice.size(),
			_hash_floats(voice),
		], expected[p])
	t.eq("voice wav rejects 48 kHz shipped file", VoiceSynth._read_wav_info("res://assets/audio/event_set/land_thud.wav"), {})


func _build_wav(channels: int, rate: int, bits: int, audio_fmt: int, pcm: PackedByteArray, extra_odd := false, fmt_after_data := false, magic := "RIFF", wave := "WAVE") -> PackedByteArray:
	var fmt := PackedByteArray()
	fmt.resize(24)
	fmt.encode_u32(0, 0x20746d66)
	fmt.encode_u32(4, 16)
	fmt.encode_u16(8, audio_fmt)
	fmt.encode_u16(10, channels)
	fmt.encode_u32(12, rate)
	fmt.encode_u32(16, rate * channels * (bits / 8))
	fmt.encode_u16(20, channels * (bits / 8))
	fmt.encode_u16(22, bits)

	var data := PackedByteArray()
	data.resize(8)
	data.encode_u32(0, 0x61746164)
	data.encode_u32(4, pcm.size())
	data.append_array(pcm)
	if (pcm.size() & 1) == 1:
		data.append(0)

	var body := PackedByteArray()
	if extra_odd:
		body.append_array("JUNK".to_ascii_buffer())
		var sz := PackedByteArray()
		sz.resize(4)
		sz.encode_u32(0, 3)
		body.append_array(sz)
		body.append_array(PackedByteArray([1, 2, 3, 0]))
	if fmt_after_data:
		body.append_array(data)
		body.append_array(fmt)
	else:
		body.append_array(fmt)
		body.append_array(data)

	var out := PackedByteArray()
	out.append_array(magic.to_ascii_buffer())
	var rsz := PackedByteArray()
	rsz.resize(4)
	rsz.encode_u32(0, 4 + body.size())
	out.append_array(rsz)
	out.append_array(wave.to_ascii_buffer())
	out.append_array(body)
	return out


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)


func _malformed_inputs() -> void:
	var pcm8 := PackedByteArray([0, 16, 0, 32, 0, 48, 0, 64])
	var pcm8_hash := _hash_bytes(pcm8)
	var trunc_data := _build_wav(1, 44100, 16, 1, pcm8)
	trunc_data.encode_u32(40, 100)
	var trunc_fmt := PackedByteArray()
	trunc_fmt.append_array("RIFF".to_ascii_buffer())
	trunc_fmt.append_array(PackedByteArray([12, 0, 0, 0]))
	trunc_fmt.append_array("WAVEfmt ".to_ascii_buffer())
	trunc_fmt.append_array(PackedByteArray([16, 0, 0, 0]))

	var cases := {
		"empty": PackedByteArray(),
		"trunc_4": "RIFF".to_ascii_buffer(),
		"missing_data": _build_wav(1, 44100, 16, 1, pcm8).slice(0, 36),
		"trunc_data": trunc_data,
		"data_1byte": _build_wav(1, 44100, 16, 1, PackedByteArray([42])),
		"odd_chunk": _build_wav(1, 44100, 16, 1, pcm8, true),
		"non_16bit_8": _build_wav(1, 44100, 8, 1, pcm8),
		"non_16bit_float": _build_wav(1, 44100, 16, 3, pcm8),
		"stereo": _build_wav(2, 44100, 16, 1, pcm8),
		"rate_48k": _build_wav(1, 48000, 16, 1, pcm8),
		"rate_24k": _build_wav(1, 24000, 16, 1, pcm8),
		"bad_magic": _build_wav(1, 44100, 16, 1, pcm8, false, false, "XXXX", "YYYY"),
		"fmt_after_data": _build_wav(2, 48000, 16, 1, pcm8, false, true),
	}
	var expected_riff := {
		"empty": [],
		"trunc_4": [],
		"missing_data": [],
		"trunc_data": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
		"data_1byte": [1, false, 44100, 0, 0, 0, 1, "684888c0ebb17f37"],
		"odd_chunk": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
		"non_16bit_8": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
		"non_16bit_float": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
		"stereo": [1, true, 44100, 0, 0, 0, 8, pcm8_hash],
		"rate_48k": [1, false, 48000, 0, 0, 0, 8, pcm8_hash],
		"rate_24k": [1, false, 24000, 0, 0, 0, 8, pcm8_hash],
		"bad_magic": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
		"fmt_after_data": [1, false, 44100, 0, 0, 0, 8, pcm8_hash],
	}
	var expected_voice := {
		"empty": [0, 0],
		"trunc_4": [0, 0],
		"missing_data": [0, 0],
		"trunc_data": [4, 4],
		"data_1byte": [0, 0],
		"odd_chunk": [4, 4],
		"non_16bit_8": [0, 0],
		"non_16bit_float": [0, 0],
		"stereo": [0, 0],
		"rate_48k": [0, 0],
		"rate_24k": [0, 0],
		"bad_magic": [0, 0],
		"fmt_after_data": [0, 0],
		"trunc_fmt": [0, 0],
	}

	var tmp_dir := ProjectSettings.globalize_path("user://wav_io_test_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	for name in cases:
		var bytes: PackedByteArray = cases[name]
		t.eq("wav_io malformed " + name, _stream_summary(WavIo.from_riff(bytes)), expected_riff[name])
		var p := tmp_dir.path_join(name + ".wav")
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
		var info := VoiceSynth._read_wav_info(p)
		var voice := VoiceSynth.load_voice_wav(p)
		t.eq("voice malformed " + name, [int(info.get("frames", 0)), voice.size()], expected_voice[name])
		t.eq("wav_io disk malformed " + name, _stream_summary(WavIo.load_wav(p, true)), expected_riff[name])

	var trunc_fmt_path := tmp_dir.path_join("trunc_fmt.wav")
	var tf := FileAccess.open(trunc_fmt_path, FileAccess.WRITE)
	tf.store_buffer(trunc_fmt)
	tf.close()
	var tf_info := VoiceSynth._read_wav_info(trunc_fmt_path)
	var tf_voice := VoiceSynth.load_voice_wav(trunc_fmt_path)
	t.eq("voice malformed trunc_fmt", [int(tf_info.get("frames", 0)), tf_voice.size()], expected_voice["trunc_fmt"])
	t.eq("voice wav rejects 24 kHz file", VoiceSynth._read_wav_info(tmp_dir.path_join("rate_24k.wav")), {})
	t.check("voice wav reads a 16-bit mono 44.1 kHz file", int(VoiceSynth._read_wav_info(tmp_dir.path_join("odd_chunk.wav")).get("frames", 0)) == 4)

	_remove_dir_recursive(tmp_dir)


func _collect_gd(root_dir: String, prefix: String, out: Array) -> void:
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var rel := entry if prefix == "" else prefix + "/" + entry
			var full := root_dir.path_join(entry)
			if dir.current_is_dir():
				_collect_gd(full, rel, out)
			elif entry.ends_with(".gd"):
				out.append(rel)
		entry = dir.get_next()
	dir.list_dir_end()


func _riff_guard() -> void:
	var files: Array = []
	_collect_gd("res://src/presentation", "", files)
	files.sort()
	t.check("presentation scan found scripts", files.size() > 10, str(files.size()))
	var found: Array = []
	for rel in files:
		if rel == "wav_io.gd":
			continue
		var text := FileAccess.get_file_as_string("res://src/presentation/" + rel)
		if text.contains("RIFF") or text.contains("fmt "):
			found.append(rel)
	t.eq("only allowed presentation files read WAV chunks", found, ALLOWED_RIFF_FILES)
