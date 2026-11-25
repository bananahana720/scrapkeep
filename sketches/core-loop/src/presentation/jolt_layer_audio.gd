extends RefCounted

const DIR := "res://assets/audio/specials/jolt_layer_"
const TELL_LEAD := 1.0
const TRIM_DB := {"presence": -14.0, "tell": -4.0, "jam": -4.0, "fizzle": -4.0, "break": -3.0}
const UNIT_SIZE := 12.0
const MAX_DISTANCE := 70.0

static var _streams := {}


static func path(part: String) -> String:
	return DIR + part + ".wav"


# Headless Godot runs without an import cache, falling back to raw 16-bit RIFF.
static func stream(part: String) -> AudioStreamWAV:
	if _streams.has(part):
		return _streams[part]
	var p := path(part)
	var out: AudioStreamWAV = null
	if ResourceLoader.exists(p):
		out = load(p) as AudioStreamWAV
	elif FileAccess.file_exists(p):
		out = _from_riff(FileAccess.get_file_as_bytes(p))
	if out != null and part == "presence":
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = out.data.size() / (2 * (2 if out.stereo else 1))
	_streams[part] = out
	return out


static func _from_riff(bytes: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var at := 12
	while at + 8 <= bytes.size():
		var tag := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		if tag == "fmt ":
			wav.stereo = bytes.decode_u16(at + 10) == 2
			wav.mix_rate = bytes.decode_u32(at + 12)
		elif tag == "data":
			wav.data = bytes.slice(at + 8, at + 8 + size)
			return wav
		at += 8 + size + (size & 1)
	return null


static func player(part: String, host: Node3D) -> AudioStreamPlayer3D:
	var s := stream(part)
	if s == null or host == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "Jolt_" + part
	p.stream = s
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.volume_db = float(TRIM_DB.get(part, 0.0))
	p.unit_size = UNIT_SIZE
	p.max_distance = MAX_DISTANCE
	host.add_child(p)
	return p


static func one_shot(part: String, parent: Node, at: Vector3) -> bool:
	if parent == null or stream(part) == null:
		return false
	var anchor := Node3D.new()
	parent.add_child(anchor)
	anchor.global_position = at
	var p := player(part, anchor)
	p.finished.connect(anchor.queue_free)
	p.play()
	return true
