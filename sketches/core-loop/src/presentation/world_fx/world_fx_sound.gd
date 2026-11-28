extends RefCounted

const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const WavIo := preload("res://src/presentation/wav_io.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")

const DIR := "res://assets/audio/world/"
const SILENT_DB := -60.0

static var audio = null
static var _streams := {}


static func reset_for_tests() -> void:
	audio = null


static func row(key: String) -> Dictionary:
	return Specs.SOUNDS.get(key, {})


static func path(key: String) -> String:
	return DIR + String(row(key).get("file", key)) + ".wav"


static func stream(key: String) -> AudioStreamWAV:
	if _streams.has(key):
		return _streams[key]
	var r := row(key)
	var out: AudioStreamWAV = WavIo.load_wav(path(key)) if not r.is_empty() else null
	if out != null and r["play"] == "loop":
		out = out.duplicate()
		out.loop_mode = AudioStreamWAV.LOOP_FORWARD
		out.loop_begin = 0
		out.loop_end = roundi(out.get_length() * out.mix_rate)
	_streams[key] = out
	return out


static func pcm(file: String) -> AudioStreamWAV:
	return WavIo.load_wav(DIR + file + ".wav", true)


# Godot distance attenuation boosts closer than unit_m past trim; tend() computes falloff manually.
static func voice(key: String, host: Node3D) -> AudioStreamPlayer3D:
	var s := stream(key)
	if s == null or host == null:
		return null
	var r := row(key)
	var p := AudioStreamPlayer3D.new()
	p.name = "Sound_" + key
	p.stream = s
	p.bus = MixRows.BUS_AMBIENT
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	p.max_distance = 0.0
	p.unit_size = float(r["unit_m"])
	p.set_meta("reach_m", float(r["reach_m"]))
	p.volume_db = float(r["db"])
	p.position = r.get("at", Vector3.ZERO)
	host.add_child(p)
	return p


static func tend(p: AudioStreamPlayer3D, base_db: float) -> float:
	var lens := p.get_viewport().get_camera_3d() if p.is_inside_tree() else null
	var dist := lens.global_position.distance_to(p.global_position) if lens != null else p.unit_size
	p.volume_db = base_db + falloff_db(dist, p.unit_size, float(p.get_meta("reach_m", 0.0)))
	return p.volume_db


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


static func heard(key: String, p: AudioStreamPlayer3D) -> void:
	if audio == null or not is_instance_valid(audio) or p == null or p.volume_db <= SILENT_DB:
		return
	audio.note_cue("world_fx", String(row(key).get("file", key)), p.volume_db, p.bus)


static func falloff_db(dist: float, unit: float, reach: float) -> float:
	if dist >= reach:
		return -80.0
	return minf(0.0, linear_to_db(unit / maxf(dist, 0.001)))
