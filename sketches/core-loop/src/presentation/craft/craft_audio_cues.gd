class_name CraftAudioCues
extends RefCounted


const AUDIO_DIR := "res://assets/audio/experimental"

const CUES := {
	"smelter_ambience": {
		"path": AUDIO_DIR + "/smelter_ambience.mp3",
		"kind": "ambience",
		"speaker": "environment",
		"maker": "old_works",
		"bus": "Ambient",
		"volume_db": -9.0,
		"loop": true,
		"caption": "Smelter pit turbine hum, distant crane creaks, and canyon furnace rumble.",
	},
	"foreman_lockdown": {
		"path": AUDIO_DIR + "/callout_foreman_lockdown.wav",
		"kind": "callout",
		"speaker": "foreman",
		"maker": "old_works",
		"bus": "SFX",
		"volume_db": -2.0,
		"loop": false,
		"caption": "Salvage Press lockdown initiated. Efficiency compliance is now mandatory. Thank you for your contributions.",
	},
	"moss_compactor_warning": {
		"path": AUDIO_DIR + "/callout_moss_compactor.wav",
		"kind": "callout",
		"speaker": "moss",
		"maker": "keepers",
		"bus": "SFX",
		"volume_db": -1.5,
		"loop": false,
		"caption": "Heads up, crew. Rogue compactor loose on the lower rail. Keep rolling.",
	},
	"brindle_ledger_audit": {
		"path": AUDIO_DIR + "/callout_brindle_audit.wav",
		"kind": "callout",
		"speaker": "brindle",
		"maker": "fleet",
		"bus": "SFX",
		"volume_db": -2.0,
		"loop": false,
		"caption": "Unrefined inventory detected. Dispatching requisition retrieval.",
	},
}


static func cue_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in CUES.keys():
		ids.append(String(key))
	ids.sort()
	return ids


static func cue_meta(cue_id: String) -> Dictionary:
	if not CUES.has(cue_id):
		return {}
	return (CUES[cue_id] as Dictionary).duplicate(true)


static func cue_exists(cue_id: String) -> bool:
	var meta := cue_meta(cue_id)
	if meta.is_empty():
		return false
	var path: String = meta["path"]
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


static func load_stream(cue_id: String) -> AudioStream:
	var meta := cue_meta(cue_id)
	if meta.is_empty():
		return null
	var path: String = meta["path"]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null and FileAccess.file_exists(path):
		if path.ends_with(".wav"):
			stream = AudioStreamWAV.load_from_file(path)
		elif path.ends_with(".mp3"):
			stream = AudioStreamMP3.load_from_file(path)
	if stream != null and bool(meta.get("loop", false)):
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


static func resolve_bus(preferred_bus: String) -> StringName:
	if AudioServer.get_bus_index(preferred_bus) >= 0:
		return StringName(preferred_bus)
	return &"Master"


static func create_player(cue_id: String, parent: Node = null) -> AudioStreamPlayer:
	var meta := cue_meta(cue_id)
	if meta.is_empty():
		return null
	var stream := load_stream(cue_id)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "CraftAudio_" + cue_id
	player.stream = stream
	player.bus = resolve_bus(String(meta.get("bus", "Master")))
	player.volume_db = float(meta.get("volume_db", 0.0))
	if parent != null:
		parent.add_child(player)
	return player


static func audit_manifest() -> Dictionary:
	var report := {
		"total": CUES.size(),
		"resolved": 0,
		"missing": [],
		"cues": {},
	}
	for cue_id in cue_ids():
		var meta := cue_meta(cue_id)
		var path: String = meta["path"]
		var stream := load_stream(cue_id)
		var size_bytes := 0
		if FileAccess.file_exists(path):
			var fa := FileAccess.open(path, FileAccess.READ)
			if fa != null:
				size_bytes = fa.get_length()
				fa.close()
		var length_s := stream.get_length() if stream != null else 0.0
		var ok := stream != null and size_bytes > 0 and length_s > 0.0
		if ok:
			report["resolved"] = int(report["resolved"]) + 1
		else:
			(report["missing"] as Array).append(cue_id)
		report["cues"][cue_id] = {
			"path": path,
			"ok": ok,
			"size_bytes": size_bytes,
			"length_s": length_s,
			"kind": meta["kind"],
			"speaker": meta["speaker"],
			"bus": String(resolve_bus(String(meta["bus"]))),
		}
	return report
