class_name ExperimentalAudioBank
extends RefCounted

const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"
const BUS_FALLBACK := "Master"
const VALID_BUSES := [BUS_AMBIENT, BUS_SFX]

const EVENT_SPECS := {
	"smelter_ambience": {
		"path": "res://assets/audio/experimental/smelter_ambience_loop.ogg",
		"bus": BUS_AMBIENT,
		"loop": true,
		"volume_db": -8.0,
		"cooldown_s": 0.0,
		"duck_db": 0.0,
		"duck_bus": "",
		"category": "ambience",
	},
	"hazard_squall_alarm": {
		"path": "res://assets/audio/experimental/hazard_squall_alarm.ogg",
		"bus": BUS_SFX,
		"loop": true,
		"volume_db": -4.0,
		"cooldown_s": 1.5,
		"duck_db": -3.0,
		"duck_bus": BUS_AMBIENT,
		"category": "alarm",
	},
	"apex_lockdown": {
		"path": "res://assets/audio/experimental/apex_lockdown_stem.ogg",
		"bus": BUS_AMBIENT,
		"loop": true,
		"volume_db": -3.5,
		"cooldown_s": 0.0,
		"duck_db": -4.0,
		"duck_bus": BUS_AMBIENT,
		"category": "combat_stem",
	},
	"pa_salvage_press_lockdown": {
		"path": "res://assets/audio/experimental/pa_salvage_press_lockdown.ogg",
		"bus": BUS_SFX,
		"loop": false,
		"volume_db": -1.5,
		"cooldown_s": 4.0,
		"duck_db": -6.0,
		"duck_bus": BUS_AMBIENT,
		"category": "pa_dispatch",
		"voice": "foreman",
		"transcript": "Salvage press lockdown active. Remain stationary.",
	},
	"pa_foreman_rig_deployed": {
		"path": "res://assets/audio/experimental/pa_foreman_rig_deployed.ogg",
		"bus": BUS_SFX,
		"loop": false,
		"volume_db": -1.5,
		"cooldown_s": 4.0,
		"duck_db": -6.0,
		"duck_bus": BUS_AMBIENT,
		"category": "pa_dispatch",
		"voice": "foreman",
		"transcript": "Foreman rig deployed. Alignment begins now.",
	},
	"pa_hazard_squall_incoming": {
		"path": "res://assets/audio/experimental/pa_hazard_squall_incoming.ogg",
		"bus": BUS_SFX,
		"loop": false,
		"volume_db": -1.5,
		"cooldown_s": 3.5,
		"duck_db": -5.5,
		"duck_bus": BUS_AMBIENT,
		"category": "pa_dispatch",
		"voice": "works_pa",
		"transcript": "Hazard squall inbound. Clear the yard.",
	},
	"pa_airdrop_pod_inbound": {
		"path": "res://assets/audio/experimental/pa_airdrop_pod_inbound.ogg",
		"bus": BUS_SFX,
		"loop": false,
		"volume_db": -1.0,
		"cooldown_s": 3.5,
		"duck_db": -5.0,
		"duck_bus": BUS_AMBIENT,
		"category": "pa_dispatch",
		"voice": "moss",
		"transcript": "Airdrop pod inbound. Moss packed spares.",
	},
}

const PBR_MASK_SPECS := {
	"pitted_iron": {
		"path": "res://assets/textures/pbr/salvage_pitted_iron_mask.png",
		"r_channel": "convex_edge_wear",
		"g_channel": "pitted_cavity_grime",
		"b_channel": "micro_weld_speckle",
	},
	"slag_crust": {
		"path": "res://assets/textures/pbr/salvage_slag_crust_mask.png",
		"r_channel": "cracked_cooling_crust",
		"g_channel": "ash_crevices",
		"b_channel": "ember_fissures",
	},
	"corrosive_brine": {
		"path": "res://assets/textures/pbr/salvage_corrosive_brine_mask.png",
		"r_channel": "oxidized_rim",
		"g_channel": "mineral_salt_streak",
		"b_channel": "acid_pit",
	},
}

static var _stream_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _last_trigger_s: Dictionary = {}


static func _reset() -> void:
	_stream_cache.clear()
	_texture_cache.clear()
	_last_trigger_s.clear()


static func reset_cooldowns() -> void:
	_last_trigger_s.clear()


static func event_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in EVENT_SPECS.keys():
		ids.append(String(key))
	return ids


static func has_event(event_id: String) -> bool:
	return EVENT_SPECS.has(event_id)


static func spec(event_id: String) -> Dictionary:
	if not EVENT_SPECS.has(event_id):
		return {}
	return (EVENT_SPECS[event_id] as Dictionary).duplicate(true)


static func bus_for(event_id: String) -> String:
	if not EVENT_SPECS.has(event_id):
		return BUS_FALLBACK
	return String(EVENT_SPECS[event_id]["bus"])


static func cooldown_for(event_id: String) -> float:
	if not EVENT_SPECS.has(event_id):
		return 0.0
	return float(EVENT_SPECS[event_id]["cooldown_s"])


static func ducking_for(event_id: String) -> Dictionary:
	if not EVENT_SPECS.has(event_id):
		return {"duck_db": 0.0, "duck_bus": ""}
	var row: Dictionary = EVENT_SPECS[event_id]
	return {
		"duck_db": float(row["duck_db"]),
		"duck_bus": String(row["duck_bus"]),
	}


static func resolve_bus(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	return BUS_FALLBACK


static func can_trigger(event_id: String, sim_time_s: float) -> bool:
	if not EVENT_SPECS.has(event_id):
		return false
	var cooldown: float = cooldown_for(event_id)
	if cooldown <= 0.0 or not _last_trigger_s.has(event_id):
		return true
	return (sim_time_s - float(_last_trigger_s[event_id])) >= cooldown


static func mark_triggered(event_id: String, sim_time_s: float) -> void:
	if EVENT_SPECS.has(event_id):
		_last_trigger_s[event_id] = sim_time_s


static func stream_for(event_id: String) -> AudioStreamOggVorbis:
	if not EVENT_SPECS.has(event_id):
		return null
	if _stream_cache.has(event_id):
		return _stream_cache[event_id] as AudioStreamOggVorbis
	var row: Dictionary = EVENT_SPECS[event_id]
	var resource_path: String = String(row["path"])
	var loaded: AudioStreamOggVorbis = null
	if ResourceLoader.exists(resource_path):
		loaded = ResourceLoader.load(resource_path) as AudioStreamOggVorbis
	if loaded == null:
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		if FileAccess.file_exists(absolute_path):
			loaded = AudioStreamOggVorbis.load_from_file(absolute_path)
	if loaded != null:
		loaded.loop = bool(row["loop"])
		_stream_cache[event_id] = loaded
	return loaded


static func configure_player(player: AudioStreamPlayer, event_id: String) -> bool:
	if player == null or not EVENT_SPECS.has(event_id):
		return false
	var stream := stream_for(event_id)
	if stream == null:
		return false
	var row: Dictionary = EVENT_SPECS[event_id]
	player.stream = stream
	player.bus = resolve_bus(String(row["bus"]))
	player.volume_db = float(row["volume_db"])
	return true


static func pbr_mask_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key in PBR_MASK_SPECS.keys():
		ids.append(String(key))
	return ids


static func pbr_mask_spec(mask_id: String) -> Dictionary:
	if not PBR_MASK_SPECS.has(mask_id):
		return {}
	return (PBR_MASK_SPECS[mask_id] as Dictionary).duplicate(true)


static func load_pbr_mask(mask_id: String) -> Texture2D:
	if not PBR_MASK_SPECS.has(mask_id):
		return null
	if _texture_cache.has(mask_id):
		return _texture_cache[mask_id] as Texture2D
	var resource_path: String = String(PBR_MASK_SPECS[mask_id]["path"])
	var loaded: Texture2D = null
	if ResourceLoader.exists(resource_path):
		loaded = ResourceLoader.load(resource_path) as Texture2D
	if loaded == null:
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		if FileAccess.file_exists(absolute_path):
			var img := Image.load_from_file(absolute_path)
			if img != null and not img.is_empty():
				loaded = ImageTexture.create_from_image(img)
	if loaded != null:
		_texture_cache[mask_id] = loaded
	return loaded
