extends RefCounted

const WavIo := preload("res://src/presentation/wav_io.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const Cues := preload("res://src/presentation/positional_cue_rows.gd")

const WHINE_LEAD := 2.0
const COLLAPSE_LAND := 0.12
const JOLT_TELL_LEAD := 1.0

static var _streams := {}


static func reset_for_tests() -> void:
	_streams.clear()


static func stream(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id]
	var row: Dictionary = Cues.ROWS[id]
	var out := WavIo.load_wav(Cues.DIR + String(row["file"]))
	if out != null and row.get("loop", false):
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = out.data.size() / (2 * (2 if out.stereo else 1))
	_streams[id] = out
	return out


static func player(id: String, host: Node3D, source: AudioStream = null) -> AudioStreamPlayer3D:
	var s: AudioStream = source if source != null else stream(id)
	if s == null:
		return null
	var row: Dictionary = Cues.ROWS[id]
	var p := AudioStreamPlayer3D.new()
	p.name = "Foley_" + id
	p.stream = s
	p.bus = MixRows.resolve_bus(MixRows.BUS_SFX)
	p.volume_db = float(row["db"])
	p.unit_size = Cues.UNIT_SIZE
	p.max_distance = float(row["range"])
	if host != null:
		host.add_child(p)
	return p


static func one_shot(id: String, parent: Node, at: Vector3) -> bool:
	if parent == null or not parent.is_inside_tree() or stream(id) == null:
		return false
	var anchor := Node3D.new()
	parent.add_child(anchor)
	anchor.global_position = at
	var p := player(id, anchor)
	p.finished.connect(anchor.queue_free)
	p.play()
	return true
