extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

# The world effects' sounds (FX-09, Specs.SOUNDS): the water and steam of the Spillway heard where they
# are drawn. Anchors and WorldFx ask for a voice by their set or hook; this owns the files, the 3D
# distances, the bus and the cue log line the mix tools read.
#   var v := WorldSound.voice("spill_falls", anchor)    # a 3D player on the anchor, or null with no row or file
#   WorldSound.one_shot("ball_splash", parent, at, 0.0) # a voice that frees itself when it ends
#   WorldSound.heard("spill_falls", v)                  # logs a start into the game's cue log (mixsim)
const DIR := "res://assets/audio/world/"
const SILENT_DB := -60.0

# The game's sound director (audio.gd), set by WorldFx on stage entry; null in tests and captures.
static var audio = null
static var _streams := {}


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


# A spatial player for the key on host, at the row's `at`, on the Ambient bus. Not playing yet.
static func voice(key: String, host: Node3D) -> AudioStreamPlayer3D:
	var s := stream(key)
	if s == null or host == null:
		return null
	var r := row(key)
	var p := AudioStreamPlayer3D.new()
	p.name = "Sound_" + key
	p.stream = s
	p.bus = bus()
	p.volume_db = float(r["db"])
	p.unit_size = float(r["unit_m"])
	p.max_distance = float(r["reach_m"])
	# Inverse distance boosts a voice closer than unit_m; the world never gets louder than its row.
	p.max_db = 0.0
	p.position = r.get("at", Vector3.ZERO)
	host.add_child(p)
	return p


# One play of a "once" row at `at`, extra_db over its trim; the voice frees itself when it ends.
static func one_shot(key: String, parent: Node, at: Vector3, extra_db := 0.0) -> AudioStreamPlayer3D:
	if parent == null or not parent.is_inside_tree() or stream(key) == null:
		return null
	var anchor := Node3D.new()
	anchor.name = "WorldSound_" + key
	parent.add_child(anchor)
	anchor.global_position = at
	var p := voice(key, anchor)
	p.volume_db += extra_db
	p.finished.connect(anchor.queue_free)
	p.play()
	heard(key, p)
	return p


static func bus() -> String:
	for name in ["Ambient", "SFX"]:
		if AudioServer.get_bus_index(name) >= 0:
			return name
	return "Master"


# Logs one start of the key's sound into the game's cue log (audio.cue_log, which tools/ace_bounce.gd
# writes as cue_rows for tools/mix/mixsim.py). The level is the one the player hears relative to the
# effects bus: the voice's trim, its distance from the listener and the Ambient bus against SFX now,
# so mixsim (which gives every effect one gain) weighs it fairly. No-op with no director.
static func heard(key: String, p: AudioStreamPlayer3D) -> void:
	if audio == null or not is_instance_valid(audio) or p == null or not p.is_inside_tree():
		return
	var lens := p.get_viewport().get_camera_3d()
	var dist := lens.global_position.distance_to(p.global_position) if lens != null else p.unit_size
	var level := p.volume_db + falloff_db(dist, p.unit_size, p.max_distance) + _bus_db(p.bus) - _bus_db("SFX")
	# A voice out of reach makes no sound: nothing to log.
	if level > SILENT_DB:
		audio.note_cue("world_fx", String(row(key).get("file", key)), level)


# Godot's inverse-distance law with max_db 0: full level inside unit, silent past reach.
static func falloff_db(dist: float, unit: float, reach: float) -> float:
	if dist >= reach:
		return -80.0
	return minf(0.0, linear_to_db(unit / maxf(dist, 0.001)))


static func _bus_db(name: String) -> float:
	return float(MixRows.BUS_DB.get(name, 0.0)) + float(audio.mix_db.get(name, 0.0))
