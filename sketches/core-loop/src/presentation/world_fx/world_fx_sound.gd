extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")

# The world effects' sounds (FX-09, Specs.SOUNDS): the water and steam of the Spillway heard where they
# are drawn. Anchors and WorldFx ask for a voice by their set or hook; this owns the files, the 3D
# distances, the bus and the cue log line the mix tools read.
#   var v := WorldSound.voice("spill_falls", anchor)    # a 3D player on the anchor, or null with no row or file
#   WorldSound.one_shot("ball_splash", parent, at, 0.0) # a voice that frees itself when it ends
#   WorldSound.tend(v, db)                              # its level now: trim less the distance falloff
#   WorldSound.heard("spill_falls", v)                  # logs a start into the game's cue log (mixsim)
const DIR := "res://assets/audio/world/"
const BUS := "Ambient"
const SILENT_DB := -60.0

# The game's sound director (audio.gd), set by WorldFx on stage entry; null in tests and captures.
static var audio = null
static var _streams := {}


static func reset_for_tests() -> void:
	audio = null


static func row(key: String) -> Dictionary:
	return Specs.SOUNDS.get(key, {})


static func path(key: String) -> String:
	return DIR + String(row(key).get("file", key)) + ".wav"


# The key's stream, looping when its row loops, or null with no row or no file.
static func stream(key: String) -> AudioStreamWAV:
	if _streams.has(key):
		return _streams[key]
	var r := row(key)
	var out: AudioStreamWAV = FoleyAudio.wav(path(key)) if not r.is_empty() else null
	if out != null and r["play"] == "loop":
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = roundi(out.get_length() * out.mix_rate)
	_streams[key] = out
	return out


# The file's own 16-bit PCM by its file name (a cue log row's sound), for the mix tools; null if none.
static func pcm(file: String) -> AudioStreamWAV:
	return FoleyAudio.wav(DIR + file + ".wav", true)


# A spatial player for the key on host, at the row's `at`, on the Ambient bus. Not playing yet. Godot's
# own distance law is off (it would boost a voice closer than unit_m past its trim): tend() sets the
# level from the row's law each time the caller moves or levels it, so what plays is what heard() logs.
# The bus is named even before audio.gd makes it (a mix routes a missing bus to Master until then).
static func voice(key: String, host: Node3D) -> AudioStreamPlayer3D:
	var s := stream(key)
	if s == null or host == null:
		return null
	var r := row(key)
	var p := AudioStreamPlayer3D.new()
	p.name = "Sound_" + key
	p.stream = s
	p.bus = BUS
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.max_distance = 0.0
	p.unit_size = float(r["unit_m"])
	p.set_meta("reach_m", float(r["reach_m"]))
	p.volume_db = float(r["db"])
	p.position = r.get("at", Vector3.ZERO)
	host.add_child(p)
	return p


# Sets the voice's level: base_db (the row's trim plus the caller's own, a flood's calm or the ball's
# speed) less the falloff from the listener. Returns the level.
static func tend(p: AudioStreamPlayer3D, base_db: float) -> float:
	var lens := p.get_viewport().get_camera_3d() if p.is_inside_tree() else null
	var dist := lens.global_position.distance_to(p.global_position) if lens != null else p.unit_size
	p.volume_db = base_db + falloff_db(dist, p.unit_size, float(p.get_meta("reach_m", 0.0)))
	return p.volume_db


# One play of a "once" row at `at`, extra_db over its trim; the voice frees itself when it ends.
static func one_shot(key: String, parent: Node, at: Vector3, extra_db := 0.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree() or stream(key) == null:
		return null
	var anchor := Node3D.new()
	anchor.name = "WorldSound_" + key
	parent.add_child(anchor)
	anchor.global_position = at
	var p := voice(key, anchor)
	tend(p, float(row(key)["db"]) + extra_db)
	p.finished.connect(anchor.queue_free)
	p.play()
	heard(key, p)
	return p


# Logs one start of the key's sound into the game's cue log (audio.note_cue, which tools/ace_bounce.gd
# writes as cue_rows for tools/mix/mixsim.py) at the level it plays now, distance included; audio.gd
# adds its bus against the effects bus. No-op with no director, or for a voice out of reach.
static func heard(key: String, p: AudioStreamPlayer3D) -> void:
	if audio == null or not is_instance_valid(audio) or p == null or p.volume_db <= SILENT_DB:
		return
	audio.note_cue("world_fx", String(row(key).get("file", key)), p.volume_db, p.bus)


# The world's distance law: full level inside unit, inverse distance beyond (6 dB a doubling),
# silent past reach.
static func falloff_db(dist: float, unit: float, reach: float) -> float:
	if dist >= reach:
		return -80.0
	return minf(0.0, linear_to_db(unit / maxf(dist, 0.001)))
