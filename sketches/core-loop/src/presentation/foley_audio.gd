extends RefCounted

const DIR := "res://assets/audio/foley/"
const WHINE_LEAD := 2.0
const COLLAPSE_LAND := 0.12
const LOOPS := ["prop_crew_presence"]
const TRIM_DB := {"lift_cage_arrive": -4.0, "zipline_whine": -6.0, "zipline_snap": -4.0, "cave_in_rumble": -5.0,
	"cave_in_debris": -4.0, "prop_crew_presence": -14.0, "prop_crew_strain": -4.0, "prop_crew_collapse": -3.0}
const UNIT_SIZE := 12.0
const MAX_DISTANCE := 80.0

static var _streams := {}


static func path(id: String) -> String:
	return DIR + id + ".wav"


static func stream(id: String) -> AudioStreamWAV:
	if _streams.has(id):
		return _streams[id]
	var out := wav(path(id))
	if out != null and id in LOOPS:
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = out.data.size() / (2 * (2 if out.stereo else 1))
	_streams[id] = out
	return out


# Headless Godot runs without an import cache, falling back to raw 16-bit RIFF.
static func wav(p: String, raw := false) -> AudioStreamWAV:
	if not raw and ResourceLoader.exists(p):
		return load(p) as AudioStreamWAV
	if FileAccess.file_exists(p):
		return _from_riff(FileAccess.get_file_as_bytes(p))
	return null


static func _from_riff(bytes: PackedByteArray) -> AudioStreamWAV:
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


static func player(id: String, host: Node3D) -> AudioStreamPlayer3D:
	var s := stream(id)
	if s == null or host == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = "Foley_" + id
	p.stream = s
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	p.volume_db = float(TRIM_DB.get(id, 0.0))
	p.unit_size = UNIT_SIZE
	p.max_distance = MAX_DISTANCE
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
