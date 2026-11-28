extends RefCounted


static func load_wav(path: String, raw := false) -> AudioStreamWAV:
	if not raw and ResourceLoader.exists(path):
		return load(path) as AudioStreamWAV
	if FileAccess.file_exists(path):
		return from_riff(FileAccess.get_file_as_bytes(path))
	return null


static func from_riff(bytes: PackedByteArray) -> AudioStreamWAV:
	var out := AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	var at := 12
	while at + 8 <= bytes.size():
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if tag == "fmt ":
			out.stereo = bytes.decode_u16(at + 10) == 2
			out.mix_rate = bytes.decode_u32(at + 12)
		elif tag == "data":
			out.data = bytes.slice(at + 8, at + 8 + size)
			return out
		at += 8 + size + (size & 1)
	return null
