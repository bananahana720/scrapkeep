extends RefCounted

# The Dig and Highdraft events' own sounds (PR #12, music thread), rendered files under
# assets/audio/foley/<id>.wav: the Dig's in E, the Highdraft's in G. Each is loaded only if
# present, so the events run on their row sounds alone until the files land, as the jolt
# layer's voice does (jolt_layer_audio.gd).
# - lift_cage_arrive 1.4 s, its clank at 0: on the cage's arrival frame.
# - zipline_whine 2.0 s, ending on the landing: WHINE_LEAD before zipline_landed.
# - zipline_snap 0.5 s: on the cut or the landing frame.
# - cave_in_rumble 1.2 s: with the cave-in's warning. cave_in_debris 1.0 s: on impact.
# - prop_crew_presence: a seamless 2.0 s loop on the crew while it lives.
# - prop_crew_strain 1.0 s: with the roof's warning. prop_crew_collapse 1.5 s, its slab
#   landing at COLLAPSE_LAND: started that long before the roof lands.

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


# The id's stream, or null with no file (wav below).
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


# The WAV at p: the imported resource when there is one, else the raw 16-bit RIFF (a headless run
# with no import cache), else null. raw reads the file's own PCM even when imported (the mix tools
# decode it). The world's sounds load through it too (world_fx_sound.gd).
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


# A spatial player for one id on `host`, or null with no file. A loop id loops.
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


# A one-shot that outlives its source, parented to `parent` at `at` and freed when it
# finishes. False with no file or no parent in the tree.
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
