extends RefCounted

const WavIo := preload("res://src/presentation/wav_io.gd")

const DIR := "res://assets/audio/specials/jolt_layer_"
const TELL_LEAD := 1.0
const TRIM_DB := {"presence": -14.0, "tell": -4.0, "jam": -4.0, "fizzle": -4.0, "break": -3.0}
const UNIT_SIZE := 12.0
const MAX_DISTANCE := 70.0

static var _streams := {}


static func path(part: String) -> String:
	return DIR + part + ".wav"


static func stream(part: String) -> AudioStreamWAV:
	if _streams.has(part):
		return _streams[part]
	var out := WavIo.load_wav(path(part))
	if out != null and part == "presence":
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = out.data.size() / (2 * (2 if out.stereo else 1))
	_streams[part] = out
	return out


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
