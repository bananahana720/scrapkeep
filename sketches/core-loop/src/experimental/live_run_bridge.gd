extends Node


const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const ExperimentalAudioBank := preload("res://src/presentation/experimental_audio_bank.gd")

const FLAG_ARG_ON := "--experimental-depth=on"
const FLAG_ARG_OFF := "--experimental-depth=off"
const FLAG_ARG_BARE := "--experimental-depth"
const ENV_VAR := "SCRAPKEEP_EXPERIMENTAL"

const WORLD_PROFILES: Array[Dictionary] = [
	{
		"director_path": AdversityDirector.DEFAULT_CONFIG_PATH,
		"encounter_path": EncounterEngine.DEFAULT_CATALOG_PATH,
	},
	{
		"director_path": AdversityDirector.DIG_CONFIG_PATH,
		"encounter_path": EncounterEngine.DIG_CATALOG_PATH,
	},
	{
		"director_path": AdversityDirector.HIGHDRAFT_CONFIG_PATH,
		"encounter_path": EncounterEngine.HIGHDRAFT_CATALOG_PATH,
	},
]

signal bridge_configured(summary: Dictionary)
signal bridge_fact_emitted(fact: Dictionary)
signal audio_cue_triggered(cue: Dictionary)
signal audio_cue_stopped(event_id: String)

var stage_index := 1
var biome_id: StringName = &""
var sim_time_s := 0.0
var configured := false

var env_tags: RefCounted = null
var synergies: RefCounted = null
var ecology: RefCounted = null
var director: RefCounted = null
var encounters: RefCounted = null
var setpieces: Node3D = null

var _owns_setpieces := false
var _audio_players: Dictionary = {}
var _active_loops: Dictionary = {}
var _audio_log: Array[Dictionary] = []
var _fact_log: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _exiting := false


static func _reset() -> void:
	ExperimentalAudioBank._reset()


static func is_enabled(args: Variant = null, env: Variant = null) -> bool:
	var arg_list: PackedStringArray = PackedStringArray()
	if args == null:
		arg_list.append_array(OS.get_cmdline_args())
		arg_list.append_array(OS.get_cmdline_user_args())
	elif args is PackedStringArray:
		arg_list = args
	elif args is Array:
		for item in args:
			arg_list.append(String(item))

	for raw in arg_list:
		var token := String(raw).strip_edges().to_lower()
		if token == FLAG_ARG_OFF or token == "--experimental-depth=0" or token == "--experimental-depth=false":
			return false
		if token == FLAG_ARG_ON or token == FLAG_ARG_BARE or token == "--experimental-depth=1" or token == "--experimental-depth=true":
			return true

	var env_val := ""
	if env == null:
		env_val = OS.get_environment(ENV_VAR)
	elif env is Dictionary:
		env_val = String(env.get(ENV_VAR, ""))
	var norm := env_val.strip_edges().to_lower()
	return norm in ["1", "true", "on", "yes"]


static func profile_for_stage(stage_num: int) -> Dictionary:
	var clamped_stage := maxi(1, stage_num)
	var bucket := clampi(int((clamped_stage - 1) / 2), 0, WORLD_PROFILES.size() - 1)
	var row: Dictionary = WORLD_PROFILES[bucket]
	var director_path := String(row["director_path"])
	var encounter_path := String(row["encounter_path"])
	var dir_cfg := ResourceLoader.load(director_path)
	var enc_cat := ResourceLoader.load(encounter_path)
	var resolved_biome: StringName = StringName(dir_cfg.get("default_biome_id")) if dir_cfg != null else &""
	return {
		"stage_index": clamped_stage,
		"profile_bucket": bucket,
		"biome_id": resolved_biome,
		"director_path": director_path,
		"encounter_path": encounter_path,
		"director_config": dir_cfg,
		"encounter_catalog": enc_cat,
	}


static func _is_headless_audio() -> bool:
	var disp := DisplayServer.get_name().to_lower()
	var drv := AudioServer.get_driver_name().to_lower()
	return disp == "headless" or drv == "dummy" or drv == ""


func configure_stage(
		stage_num: int,
		seed_value: int = 20261126,
		stage_threat: float = 1.0,
		chunk_root: Node = null,
		opts: Dictionary = {}) -> Dictionary:
	teardown()
	_exiting = false
	name = "ExperimentalLiveRunBridge"
	stage_index = maxi(1, stage_num)
	sim_time_s = 0.0

	var profile := profile_for_stage(stage_index)
	biome_id = StringName(profile["biome_id"])
	var dir_cfg: Resource = profile["director_config"]
	var enc_cat: Resource = profile["encounter_catalog"]

	env_tags = EnvTags.new()
	synergies = JuryRig.new(env_tags)
	ecology = Ecology.new(env_tags)
	director = AdversityDirector.new(seed_value, biome_id, stage_threat, dir_cfg)
	encounters = EncounterEngine.new(seed_value, enc_cat)

	var setpiece_info := {}
	if chunk_root != null:
		setpieces = DynamicSetpieces.new()
		_owns_setpieces = true
		add_child(setpieces)
		var sp_opts := {
			"seed": seed_value,
			"cruise_speed": float(opts.get("cruise_speed", 14.0)),
		}
		setpiece_info = setpieces.setup_from_chunk(chunk_root, sp_opts)

	_wire_signals()
	configured = true

	var start_ambience := bool(opts.get("start_ambience", true))
	if start_ambience:
		trigger_audio_cue("smelter_ambience")

	var summary := {
		"stage_index": stage_index,
		"profile_bucket": int(profile["profile_bucket"]),
		"biome_id": biome_id,
		"director_path": String(profile["director_path"]),
		"encounter_path": String(profile["encounter_path"]),
		"setpieces_attached": setpieces != null,
		"setpiece_info": setpiece_info,
		"active_loops": active_audio_loops(),
	}
	bridge_configured.emit(summary)
	return summary


func equip_part(part_id: StringName) -> Dictionary:
	if synergies == null:
		return {"ok": false, "problems": ["bridge not configured"]}
	return synergies.equip_by_id(part_id)


func dispatch_player_event(trigger: StringName, ctx: Dictionary = {}) -> Dictionary:
	if synergies == null:
		return {"trigger": trigger, "fired": [], "reactions": [], "synergies": [], "chain_hits": []}
	return synergies.dispatch(trigger, ctx)


func attempt_redline_vent(origin: Vector3, ball_speed_mps: float, verb: StringName = &"slam") -> Dictionary:
	if synergies == null:
		return {"vented": false, "reason": "not_configured"}
	return synergies.attempt_redline_vent(origin, ball_speed_mps, verb)


func step(dt: float, run_ctx: Dictionary = {}) -> Dictionary:
	if not configured or dt <= 0.0:
		return {
			"configured": configured,
			"sim_time_s": sim_time_s,
			"ball_accel": Vector3.ZERO,
			"facts": [],
		}
	sim_time_s += dt
	var ball_pos: Vector3 = run_ctx.get("ball_pos", Vector3.ZERO)
	var ball_vel: Vector3 = run_ctx.get("ball_vel", Vector3.ZERO)
	var speed := Vector2(ball_vel.x, ball_vel.z).length()
	var cruise_mps := float(run_ctx.get("cruise_mps", 14.0))
	var alive_count := int(run_ctx.get("alive_count", 0))
	var grounded := bool(run_ctx.get("grounded", true))
	var heft_tier := int(run_ctx.get("heft_tier", 1))

	var dir_res: Dictionary = director.advance(dt, ball_pos, ball_vel, alive_count, cruise_mps, grounded)

	var enc_ctx := run_ctx.duplicate(true)
	enc_ctx["ball_pos"] = ball_pos
	enc_ctx["ball_vel"] = ball_vel
	enc_ctx["cruise_mps"] = cruise_mps
	enc_ctx["biome_id"] = biome_id
	enc_ctx["elapsed_s"] = director.elapsed_s
	enc_ctx["hazard_tier"] = director.hazard_tier
	var enc_res: Dictionary = encounters.advance(dt, enc_ctx)

	var sp_facts: Array[Dictionary] = []
	if setpieces != null:
		sp_facts = setpieces.step(dt, ball_pos, ball_vel, heft_tier)

	var rig_res: Dictionary = synergies.step(dt, speed, ball_pos)
	var eco_res: Dictionary = ecology.step(dt, ball_pos, ball_vel)

	var total_accel: Vector3 = (dir_res.get("ball_accel", Vector3.ZERO) as Vector3) \
		+ (enc_res.get("ball_accel", Vector3.ZERO) as Vector3)
	var facts: Array = []
	facts.append_array(dir_res.get("facts", []))
	facts.append_array(enc_res.get("facts", []))
	facts.append_array(sp_facts)

	return {
		"configured": true,
		"sim_time_s": sim_time_s,
		"biome_id": biome_id,
		"director": dir_res,
		"encounters": enc_res,
		"setpieces": sp_facts,
		"synergies": rig_res,
		"ecology": eco_res,
		"ball_accel": total_accel,
		"facts": facts,
		"active_loops": active_audio_loops(),
	}


func trigger_audio_cue(event_id: String, force: bool = false) -> Dictionary:
	if not ExperimentalAudioBank.has_event(event_id):
		return {"triggered": false, "reason": "unknown_event", "event_id": event_id}
	var spec: Dictionary = ExperimentalAudioBank.spec(event_id)
	var is_loop := bool(spec.get("loop", false))
	if is_loop and bool(_active_loops.get(event_id, false)) and not force:
		return {"triggered": false, "reason": "loop_already_active", "event_id": event_id}
	if not force and not ExperimentalAudioBank.can_trigger(event_id, sim_time_s):
		return {"triggered": false, "reason": "cooldown", "event_id": event_id}

	ExperimentalAudioBank.mark_triggered(event_id, sim_time_s)
	var player := _ensure_audio_player(event_id)
	var player_ok := false
	if player != null:
		player_ok = ExperimentalAudioBank.configure_player(player, event_id)
		if player_ok and not _is_headless_audio():
			player.play()
	if is_loop:
		_active_loops[event_id] = true

	var cue := {
		"triggered": true,
		"event_id": event_id,
		"sim_time_s": sim_time_s,
		"bus": ExperimentalAudioBank.bus_for(event_id),
		"loop": is_loop,
		"duck": ExperimentalAudioBank.ducking_for(event_id),
		"player_configured": player_ok,
		"headless": _is_headless_audio(),
		"category": String(spec.get("category", "")),
	}
	_audio_log.append(cue)
	audio_cue_triggered.emit(cue)
	return cue


func stop_audio_cue(event_id: String) -> bool:
	var was_active := bool(_active_loops.get(event_id, false))
	_active_loops.erase(event_id)
	if _audio_players.has(event_id):
		var player := _audio_players[event_id] as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
	if was_active:
		audio_cue_stopped.emit(event_id)
	return was_active


func active_audio_loops() -> Array[String]:
	var out: Array[String] = []
	for key in _active_loops.keys():
		if bool(_active_loops[key]):
			out.append(String(key))
	out.sort()
	return out


func audio_cue_log() -> Array[Dictionary]:
	return _audio_log.duplicate(true)


func fact_log() -> Array[Dictionary]:
	return _fact_log.duplicate(true)


func snapshot() -> Dictionary:
	return {
		"configured": configured,
		"stage_index": stage_index,
		"biome_id": biome_id,
		"sim_time_s": sim_time_s,
		"hazard_tier": director.hazard_tier if director != null else 0,
		"active_hazard_id": director.active_hazard_id if director != null else &"",
		"active_lockdown": encounters.has_active_lockdown() if encounters != null else false,
		"active_zone_count": env_tags.active_zone_count() if env_tags != null else 0,
		"heat": synergies.heat if synergies != null else 0.0,
		"active_loops": active_audio_loops(),
		"audio_cue_count": _audio_log.size(),
		"audio_player_count": _audio_players.size(),
	}


func teardown() -> void:
	_disconnect_signals()
	for event_id in _active_loops.keys():
		if _audio_players.has(event_id):
			var p := _audio_players[event_id] as AudioStreamPlayer
			if is_instance_valid(p):
				p.stop()
	_active_loops.clear()

	for key in _audio_players.keys():
		var player := _audio_players[key] as AudioStreamPlayer
		if is_instance_valid(player):
			player.stop()
			if not _exiting and player.get_parent() == self:
				remove_child(player)
			player.free()
	_audio_players.clear()

	if setpieces != null:
		if is_instance_valid(setpieces):
			setpieces.teardown()
			if _owns_setpieces:
				if not _exiting and setpieces.get_parent() == self:
					remove_child(setpieces)
				setpieces.free()
		setpieces = null
	_owns_setpieces = false

	if encounters != null:
		encounters.abort_all(&"bridge_teardown")
		encounters = null
	if ecology != null:
		ecology.dispose()
		ecology = null
	if synergies != null:
		synergies.clear()
		synergies = null
	if env_tags != null:
		env_tags.clear()
		env_tags = null
	director = null
	_audio_log.clear()
	_fact_log.clear()
	configured = false
	sim_time_s = 0.0


func _exit_tree() -> void:
	_exiting = true
	teardown()


func _ensure_audio_player(event_id: String) -> AudioStreamPlayer:
	if _audio_players.has(event_id):
		var existing := _audio_players[event_id] as AudioStreamPlayer
		if is_instance_valid(existing):
			return existing
	var player := AudioStreamPlayer.new()
	player.name = "ExpAudio_" + event_id
	add_child(player)
	_audio_players[event_id] = player
	return player


func _connect_tracked(obj: Object, sig_name: StringName, cb: Callable) -> void:
	if obj == null or not obj.has_signal(sig_name):
		return
	obj.connect(sig_name, cb)
	_connections.append({"obj": weakref(obj), "signal": sig_name, "cb": cb})


func _disconnect_signals() -> void:
	for entry in _connections:
		var obj: Variant = (entry["obj"] as WeakRef).get_ref()
		var sig_name: StringName = entry["signal"]
		var cb: Callable = entry["cb"]
		if obj != null and is_instance_valid(obj) and obj.is_connected(sig_name, cb):
			obj.disconnect(sig_name, cb)
	_connections.clear()


func _wire_signals() -> void:
	var self_ref: WeakRef = weakref(self)

	_connect_tracked(director, &"env_tag_emitted", func(payload: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null and inst.env_tags != null:
			inst.env_tags.apply_tag(payload)
	)
	_connect_tracked(encounters, &"env_tag_emitted", func(payload: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null and inst.env_tags != null:
			inst.env_tags.apply_tag(payload)
	)
	_connect_tracked(director, &"hazard_phase_changed", func(hazard_id: StringName, phase: int) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_hazard_phase_changed(hazard_id, phase)
	)
	_connect_tracked(director, &"elite_purchased", func(elite_inst: RefCounted) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_elite_purchased(elite_inst)
	)
	_connect_tracked(director, &"fact_emitted", func(fact: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_bridge_fact(fact)
	)
	_connect_tracked(encounters, &"fact_emitted", func(fact: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_encounter_fact(fact)
	)
	_connect_tracked(ecology, &"prop_ruptured", func(receipt: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null and inst.synergies != null:
			inst.synergies.dispatch(PartResource.TRIG_ON_PROP_RUPTURE, {
				"origin": receipt.get("origin", Vector3.ZERO),
				"prop_id": String(receipt.get("prop_id", "")),
				"ball_speed_mps": 14.0,
			})
	)

	if setpieces != null:
		_connect_tracked(setpieces, &"env_tag_emitted", func(payload: Dictionary) -> void:
			var inst: Variant = self_ref.get_ref()
			if inst != null and inst.env_tags != null:
				inst.env_tags.apply_tag(payload)
		)
		_connect_tracked(env_tags, &"tag_applied", func(payload: Dictionary) -> void:
			var inst: Variant = self_ref.get_ref()
			if inst == null or inst.setpieces == null:
				return
			var src := String(payload.get("source_id", ""))
			if src.begins_with("em_crane:") or src.begins_with("slag_furnace:") \
					or src.begins_with("cryo_pipe:") or src.begins_with("crane_magnet_drop:"):
				return
			inst.setpieces.apply_external_tag(payload)
		)


func _on_hazard_phase_changed(_hazard_id: StringName, phase: int) -> void:
	match phase:
		AdversityDirector.HazardPhase.WARNING:
			trigger_audio_cue("pa_hazard_squall_incoming")
		AdversityDirector.HazardPhase.RAMP, AdversityDirector.HazardPhase.PEAK:
			trigger_audio_cue("hazard_squall_alarm")
		AdversityDirector.HazardPhase.RECEDE, AdversityDirector.HazardPhase.COOLDOWN, AdversityDirector.HazardPhase.IDLE:
			stop_audio_cue("hazard_squall_alarm")


func _on_elite_purchased(elite_inst: RefCounted) -> void:
	if elite_inst == null:
		return
	var maker_val: StringName = elite_inst.get("maker") if "maker" in elite_inst else &""
	var chassis_val: StringName = elite_inst.get("chassis") if "chassis" in elite_inst else &""
	if maker_val == &"old_works" or chassis_val == &"foreman":
		trigger_audio_cue("pa_foreman_rig_deployed")


func _on_encounter_fact(fact: Dictionary) -> void:
	_on_bridge_fact(fact)
	var kind := String(fact.get("kind", ""))
	match kind:
		"encounter_lockdown_started":
			trigger_audio_cue("pa_salvage_press_lockdown")
			trigger_audio_cue("apex_lockdown")
		"apex_construct_spawned":
			trigger_audio_cue("pa_foreman_rig_deployed")
			trigger_audio_cue("apex_lockdown")
		"encounter_lockdown_ended":
			stop_audio_cue("apex_lockdown")
		"random_encounter_announced":
			if StringName(fact.get("encounter_kind", &"")) == &"airdrop_salvage_pod":
				trigger_audio_cue("pa_airdrop_pod_inbound")


func _on_bridge_fact(fact: Dictionary) -> void:
	var copy := fact.duplicate(true)
	_fact_log.append(copy)
	bridge_fact_emitted.emit(copy)
