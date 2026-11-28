extends Node


const AppShell := preload("res://src/core/app_shell.gd")
const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")
const JuryRig := preload("res://src/experimental/jury_rig_synergies.gd")
const Ecology := preload("res://src/experimental/ecology_actors.gd")
const AdversityDirector := preload("res://src/experimental/adversity_director.gd")
const EncounterEngine := preload("res://src/experimental/encounter_engine.gd")
const DynamicSetpieces := preload("res://src/experimental/dynamic_setpieces.gd")
const ExperimentalAudioBank := preload("res://src/presentation/experimental_audio_bank.gd")
const CampCraftMeshes := preload("res://src/presentation/craft/camp_craft_meshes.gd")
const CraftLookdev := preload("res://src/presentation/craft/craft_lookdev.gd")
const LiveWorldActors := preload("res://src/experimental/live_world_actors.gd")

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

const CHUNK_SCENES: Array[String] = [
	"res://src/experimental/smelter_crane_chunk.tscn",
	"res://src/experimental/compactor_canyon_chunk.tscn",
	"res://src/experimental/orbital_graveyard_chunk.tscn",
]
const LIVE_LOADOUTS: Array[Array] = [
	[&"magnetized_sawblades", &"arc_welder_dash", &"brine_tap_vent"],
	[&"caustic_bore_auger", &"tremor_pile_driver", &"cryo_slurry_manifold"],
	[&"choir_arc_lance", &"gale_shear_slipstream", &"overclock_capacitor_shunt"],
]
const CHUNK_HOLDER_NAME := "ExperimentalArenaChunk"
const CHUNK_FOOTPRINT_HALF_M := 34.0
const CHUNK_SITE_RANGES_M: Array[float] = [84.0, 112.0, 144.0, 180.0, 220.0, 265.0]
const CHUNK_SITE_ANGLES_DEG: Array[float] = [90.0, -90.0, 112.5, -112.5, 135.0, -135.0, 157.5, -157.5, 180.0,
	67.5, -67.5, 45.0, -45.0, 22.5, -22.5, 0.0]
const CHUNK_SITE_SAMPLES: Array[float] = [-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0]
const CHUNK_LINE_SAMPLES: Array[float] = [-1.0, -0.5, 0.0, 0.5, 1.0]
const CHUNK_SITE_GOOD_COST_M := 3.0
const CHUNK_DECK_CLEARANCE_M := 0.35
const CHUNK_DECK_SCAN_STEP_M := 2.0
const CHUNK_RELIEF_COST := 2.5
const CHUNK_OVERHANG_DROP_M := 12.0
const CHUNK_OVERHANG_COST_M := 60.0
const CHUNK_SITE_DENSE_PICKS := 8
const CHUNK_CLEAR_RADIUS_M := CHUNK_FOOTPRINT_HALF_M + 8.0
const CHUNK_BEACON_CLEAR_M := 52.0
const CHUNK_SPAWN_CLEAR_M := 80.0
const CHUNK_LINE_REACH_M := 15.0
const CHUNK_LINE_COST_M := 25.0
const CHUNK_BLOCKED_COST_M := 1000.0
const CHUNK_APPROACH_MARGIN_M := 3.0
const LIVE_SEED_STRIDE := 97
const FACT_CALLOUTS := {
	"hazard_announced": "Squall incoming",
	"encounter_lockdown_started": "Press lockdown",
	"apex_construct_spawned": "Foreman rig deployed",
	"foreman_rig_scrapped": "Foreman rig scrapped",
	"refurbished_elite_scrapped": "Elite scrapped",
	"hauler_scrapped": "Hauler scrapped",
}
const ENCOUNTER_CALLOUTS := {
	&"airdrop_salvage_pod": "Salvage pod inbound",
	&"rogue_compactor_chase": "Rogue compactor loose",
	&"greed_ambush_swarm": "Scrap ambush",
}

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
var _live_ctx = null
var _live_chunk: Node3D = null
var _live_stage := 0
var _live_stale := false
var _live_links: Array[Dictionary] = []
var _live_site: Dictionary = {}
var live_actors: Node3D = null


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


static func chunk_scene_for_stage(stage_num: int) -> String:
	var bucket := clampi(int((maxi(1, stage_num) - 1) / 2), 0, CHUNK_SCENES.size() - 1)
	return CHUNK_SCENES[bucket]


static func loadout_for_stage(stage_num: int) -> Array:
	var bucket := clampi(int((maxi(1, stage_num) - 1) / 2), 0, LIVE_LOADOUTS.size() - 1)
	return LIVE_LOADOUTS[bucket]


static func callout_for(fact: Dictionary) -> String:
	var kind := String(fact.get("kind", ""))
	if kind == "random_encounter_announced":
		return String(ENCOUNTER_CALLOUTS.get(StringName(fact.get("encounter_kind", &"")), ""))
	return String(FACT_CALLOUTS.get(kind, ""))


static func _is_headless_audio() -> bool:
	var drv := AudioServer.get_driver_name().to_lower()
	return AppShell.headless() or drv == "dummy" or drv == ""


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
	for sp_fact in sp_facts:
		if String(sp_fact.get("kind", "")) == "ball_momentum_boost":
			total_accel += sp_fact.get("accel", Vector3.ZERO) as Vector3
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
		"live_site": _live_site.duplicate(),
		"live_actors": live_actors.snapshot() if is_instance_valid(live_actors) else {},
	}


func attach_live(ctx) -> void:
	detach_live()
	if ctx == null:
		return
	_live_ctx = ctx
	_link_live(ctx.events, &"flow_changed", _on_live_flow_changed)
	_link_live(ctx.events, &"run_started", _on_live_run_started)
	_link_live(ctx.events, &"stage_entered", _on_live_stage_entered)
	_link_live(ctx.events, &"shot_fired", _on_live_shot_fired)
	_link_live(ctx.events, &"boosted", _on_live_dashed)
	_link_live(ctx.events, &"dashed", _on_live_dashed)
	_link_live(ctx.terrain, &"stage_built", _on_live_stage_built)
	_link_live(ctx.terrain, &"stage_freed", _on_live_stage_freed)
	_link_live(ctx.player, &"shockwave", _on_live_shockwave)
	sync_live()


func detach_live() -> void:
	for link in _live_links:
		var obj: Variant = (link["obj"] as WeakRef).get_ref()
		var sig_name: StringName = link["signal"]
		var cb: Callable = link["cb"]
		if obj != null and is_instance_valid(obj) and obj.is_connected(sig_name, cb):
			obj.disconnect(sig_name, cb)
	_live_links.clear()
	_free_live_actors()
	_live_ctx = null
	_live_stage = 0
	_live_stale = false
	if not _exiting:
		_free_live_chunk()
	_live_chunk = null


func sync_live() -> void:
	if _live_ctx == null:
		return
	var stage: int = _live_ctx.run.stage
	var terrain = _live_ctx.terrain
	if not (_live_ctx.flow.in_stage() and terrain != null and terrain.is_ready(stage)):
		if configured:
			teardown()
		if _live_ctx.flow.state_name() != "dead":
			_free_live_chunk()
			_live_stage = 0
		return
	if configured and not _live_stale and _live_stage == stage:
		return
	if _live_stage != stage or not is_instance_valid(_live_chunk):
		_free_live_chunk()
		_live_chunk = _spawn_live_chunk(stage)
	_live_stage = stage
	_live_stale = false
	configure_stage(stage, int(_live_ctx.run.run_seed) + stage * LIVE_SEED_STRIDE, 1.0, _live_chunk)
	for part_id in loadout_for_stage(stage):
		equip_part(part_id)
	_mount_live_actors(stage)


func live_chunk() -> Node3D:
	return _live_chunk if is_instance_valid(_live_chunk) else null


func live_step(delta: float) -> Dictionary:
	if _live_ctx == null or not configured or not _live_ctx.flow.in_stage():
		return {}
	var player = _live_ctx.player
	var result := step(delta, {
		"ball_pos": player.ball_position(),
		"ball_vel": player.state.velocity,
		"grounded": player.state.grounded,
		"heft_tier": _live_ctx.run.heft_class(),
		"cruise_mps": _live_ctx.tuning.f("cruise"),
	})
	player.add_external_accel(result["ball_accel"] as Vector3)
	if is_instance_valid(live_actors):
		live_actors.step(delta, result)
	return result


func _mount_live_actors(stage: int) -> void:
	_free_live_actors()
	if not is_instance_valid(_live_chunk) or _live_chunk.get_parent() == null:
		return
	live_actors = LiveWorldActors.new()
	_live_chunk.get_parent().add_child(live_actors)
	live_actors.setup(self, _live_ctx, _live_chunk, stage)
	var self_ref: WeakRef = weakref(self)
	_connect_tracked(live_actors, &"fact_emitted", func(fact: Dictionary) -> void:
		var inst: Variant = self_ref.get_ref()
		if inst != null:
			inst._on_bridge_fact(fact)
	)


func _free_live_actors() -> void:
	if is_instance_valid(live_actors):
		live_actors.teardown()
		var parent := live_actors.get_parent()
		if not _exiting and parent != null:
			parent.remove_child(live_actors)
		live_actors.queue_free()
	live_actors = null


func _link_live(obj: Object, sig_name: StringName, cb: Callable) -> void:
	if obj == null or not obj.has_signal(sig_name):
		return
	obj.connect(sig_name, cb)
	_live_links.append({"obj": weakref(obj), "signal": sig_name, "cb": cb})


func _spawn_live_chunk(stage: int) -> Node3D:
	var site := _live_chunk_site(stage)
	var packed := load(chunk_scene_for_stage(stage)) as PackedScene
	if site.is_empty() or packed == null:
		return null
	_live_site = site.duplicate()
	var holder := Node3D.new()
	holder.name = CHUNK_HOLDER_NAME
	(_live_ctx.terrain.geometry_root(stage) as Node3D).add_child(holder)
	holder.global_transform = Transform3D(Basis.IDENTITY, site["origin"] as Vector3)
	_build_chunk_foundation_and_ramp(holder, site)
	var chunk := packed.instantiate() as Node3D
	holder.add_child(chunk)
	return chunk


func _build_chunk_foundation_and_ramp(holder: Node3D, site: Dictionary) -> void:
	var origin: Vector3 = site["origin"]
	var low: float = float(site.get("low", origin.y))
	var approach_pt: Vector3 = site.get("approach", origin + Vector3.FORWARD * (CHUNK_FOOTPRINT_HALF_M + CHUNK_APPROACH_MARGIN_M))
	var approach_y: float = float(site.get("approach_floor", origin.y))
	var skirt_h := maxf(4.0, (origin.y - low) + 4.0)
	var skirt_size := Vector3(CHUNK_FOOTPRINT_HALF_M * 1.96, skirt_h, CHUNK_FOOTPRINT_HALF_M * 1.96)
	var mat := CraftLookdev.preset_material("scorched_concrete")
	var body := StaticBody3D.new()
	body.name = "ChunkFoundationBody"
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var st_skirt := SurfaceTool.new()
	st_skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c_flat := CraftLookdev.encode_mask(0.18, 0.34)
	var c_edge := CraftLookdev.encode_mask(0.62, 0.16)
	var c_bot := CraftLookdev.encode_mask(0.08, 0.78)
	var skirt_center := Vector3(0.0, -0.35 - skirt_h * 0.5, 0.0)
	CampCraftMeshes.add_bevel_box(st_skirt, skirt_center, skirt_size, 0.45, 0.12, Transform3D.IDENTITY, c_flat, c_edge, c_bot)
	st_skirt.generate_tangents()
	var skirt_view := MeshInstance3D.new()
	skirt_view.name = "ChunkFoundationSkirt"
	skirt_view.mesh = st_skirt.commit()
	skirt_view.material_override = mat
	holder.add_child(skirt_view)
	var skirt_col := CollisionShape3D.new()
	var skirt_shape := BoxShape3D.new()
	skirt_shape.size = skirt_size
	skirt_col.shape = skirt_shape
	skirt_col.position = skirt_center
	body.add_child(skirt_col)
	var drop := origin.y - approach_y
	if drop > 0.35:
		var to_spawn := Vector3(approach_pt.x - origin.x, 0.0, approach_pt.z - origin.z)
		var out_dir := to_spawn.normalized() if to_spawn.length() > 0.01 else Vector3.FORWARD
		var horiz := maxf(drop * 2.6, 8.0)
		var ramp_len := sqrt(horiz * horiz + (drop + 0.6) * (drop + 0.6))
		var pitch := atan2(drop + 0.6, horiz)
		var rim_edge := out_dir * (CHUNK_FOOTPRINT_HALF_M * 0.94)
		var mid := rim_edge + out_dir * (horiz * 0.5) + Vector3(0.0, -(drop + 0.6) * 0.5 - 0.35, 0.0)
		var yaw := atan2(out_dir.x, out_dir.z)
		var ramp_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var ramp_xf := Transform3D(ramp_basis, mid)
		var ramp_size := Vector3(9.5, 0.9, ramp_len)
		var st_ramp := SurfaceTool.new()
		st_ramp.begin(Mesh.PRIMITIVE_TRIANGLES)
		CampCraftMeshes.add_bevel_box(st_ramp, Vector3.ZERO, ramp_size, 0.18, 0.16, Transform3D.IDENTITY, c_flat, c_edge, c_bot)
		st_ramp.generate_tangents()
		var ramp_view := MeshInstance3D.new()
		ramp_view.name = "ChunkApproachRamp"
		ramp_view.mesh = st_ramp.commit()
		ramp_view.material_override = mat
		ramp_view.transform = ramp_xf
		holder.add_child(ramp_view)
		var ramp_col := CollisionShape3D.new()
		var ramp_shape := BoxShape3D.new()
		ramp_shape.size = ramp_size
		ramp_col.shape = ramp_shape
		ramp_col.transform = ramp_xf
		body.add_child(ramp_col)


func _live_chunk_site(stage: int) -> Dictionary:
	var terrain = _live_ctx.terrain
	if int(terrain.stage) != stage:
		return {}
	var spawn: Vector3 = terrain.spawn_point(stage)
	var heading: Vector3 = terrain.entry_heading(stage)
	heading = Vector3(heading.x, 0.0, heading.z)
	heading = heading.normalized() if heading.length() > 0.01 else Vector3.FORWARD
	var spawn_floor: float = terrain.height(spawn.x, spawn.z)
	var beacon: Variant = terrain.beacon_point(stage) if terrain.has_method("beacon_point") else null
	var map: Variant = terrain.map_for(stage) if terrain.has_method("map_for") else null
	var ride_lines: bool = map != null and map.has_method("line_within")
	var coarse := _footprint_offsets(CHUNK_SITE_SAMPLES)
	var dense := _dense_offsets()
	var shortlist: Array[Dictionary] = []
	for range_m in CHUNK_SITE_RANGES_M:
		var ring_best := INF
		for angle_deg in CHUNK_SITE_ANGLES_DEG:
			var at: Vector3 = spawn + heading.rotated(Vector3.UP, deg_to_rad(angle_deg)) * range_m
			var inside := true
			for corner: Vector2 in [Vector2(-1.0, -1.0), Vector2(-1.0, 1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0)]:
				inside = inside and terrain.contains(Vector3(at.x + corner.x * CHUNK_FOOTPRINT_HALF_M, 0.0, at.z + corner.y * CHUNK_FOOTPRINT_HALF_M))
			if not inside:
				continue
			var line_hits := 0
			if ride_lines:
				for sx in CHUNK_LINE_SAMPLES:
					for sz in CHUNK_LINE_SAMPLES:
						if map.line_within(Vector2(at.x + sx * CHUNK_CLEAR_RADIUS_M, at.z + sz * CHUNK_CLEAR_RADIUS_M), CHUNK_LINE_REACH_M):
							line_hits += 1
			var flat := Vector2(at.x, at.z)
			var beacon_m := flat.distance_to(Vector2(beacon.x, beacon.z)) if beacon != null else INF
			var spawn_m := flat.distance_to(Vector2(spawn.x, spawn.z))
			var blocked := beacon_m < CHUNK_BEACON_CLEAR_M or spawn_m < CHUNK_SPAWN_CLEAR_M
			var approach: Vector3 = at + (spawn - at).normalized() * (CHUNK_FOOTPRINT_HALF_M + CHUNK_APPROACH_MARGIN_M)
			var site := {"origin": Vector3(at.x, 0.0, at.z), "approach": approach, "approach_floor": float(terrain.height(approach.x, approach.z)),
				"beacon_m": beacon_m, "spawn_m": spawn_m, "line_hits": line_hits, "clear": not blocked and line_hits == 0,
				"fixed_cost": float(line_hits) * CHUNK_LINE_COST_M + (CHUNK_BLOCKED_COST_M if blocked else 0.0),
				"rank": shortlist.size()}
			_score_site(terrain, site, coarse, spawn_floor)
			ring_best = minf(ring_best, float(site["cost"]))
			shortlist.append(site)
		if ring_best <= CHUNK_SITE_GOOD_COST_M:
			break
	shortlist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["cost"]) < float(b["cost"]) or (float(a["cost"]) == float(b["cost"]) and int(a["rank"]) < int(b["rank"])))
	var best := {}
	for site in shortlist.slice(0, CHUNK_SITE_DENSE_PICKS):
		_score_site(terrain, site, dense, spawn_floor)
		if best.is_empty() or float(site["cost"]) < float(best["cost"]) - 0.01:
			best = site
	if best.is_empty():
		return {}
	var top := float(best["terrain_top"])
	var origin: Vector3 = best["origin"]
	best["origin"] = Vector3(origin.x, top + CHUNK_DECK_CLEARANCE_M, origin.z)
	best.erase("fixed_cost")
	best.erase("rank")
	return best


static func _footprint_offsets(samples: Array[float]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for sx in samples:
		for sz in samples:
			out.append(Vector2(sx, sz) * CHUNK_FOOTPRINT_HALF_M)
	return out


static func _dense_offsets() -> PackedVector2Array:
	var out := PackedVector2Array()
	var span := CHUNK_FOOTPRINT_HALF_M * 2.0
	var steps := int(ceil(span / CHUNK_DECK_SCAN_STEP_M))
	for ix in steps + 1:
		for iz in steps + 1:
			out.append(Vector2(minf(float(ix) * CHUNK_DECK_SCAN_STEP_M, span), minf(float(iz) * CHUNK_DECK_SCAN_STEP_M, span)) - Vector2.ONE * CHUNK_FOOTPRINT_HALF_M)
	return out


static func _score_site(terrain, site: Dictionary, offsets: PackedVector2Array, spawn_floor: float) -> void:
	var origin: Vector3 = site["origin"]
	var points := PackedVector2Array()
	for off in offsets:
		points.append(Vector2(origin.x, origin.z) + off)
	var heights: Variant = terrain.heights(points) if terrain.has_method("heights") else null
	if heights == null:
		heights = PackedFloat64Array()
		for p in points:
			heights.append(terrain.height(p.x, p.y))
	var high := -INF
	var low := INF
	for h in heights:
		high = maxf(high, h)
		low = minf(low, h)
	var overhung := 0
	for h in heights:
		if high - h > CHUNK_OVERHANG_DROP_M:
			overhung += 1
	var overhang := float(overhung) / float(heights.size())
	site["terrain_top"] = high
	site["low"] = low
	site["relief"] = high - low
	site["overhang"] = overhang
	site["cost"] = absf(high - float(site["approach_floor"])) + absf(high - spawn_floor) \
		+ (high - low) * CHUNK_RELIEF_COST + overhang * CHUNK_OVERHANG_COST_M + float(site["fixed_cost"])


func _free_live_chunk() -> void:
	if is_instance_valid(_live_chunk):
		var holder := _live_chunk.get_parent()
		var doomed: Node = holder if holder != null and holder.name == CHUNK_HOLDER_NAME else _live_chunk
		if doomed.get_parent() != null:
			doomed.get_parent().remove_child(doomed)
		doomed.queue_free()
	_live_chunk = null


func _on_live_flow_changed(_state: String) -> void:
	sync_live()


func _on_live_run_started(_class_id: String) -> void:
	_live_stale = true
	sync_live()


func _on_live_stage_entered(_stage: int, _retry: bool) -> void:
	_live_stale = true
	sync_live()


func _on_live_stage_built(_stage: int) -> void:
	sync_live()


func _on_live_stage_freed(stage: int) -> void:
	if stage != _live_stage:
		return
	_live_chunk = null
	_live_stage = 0
	if configured:
		teardown()


func _on_live_shockwave(at: Vector3, strength: float) -> void:
	_dispatch_live(PartResource.TRIG_ON_SLAM, at)
	if configured and is_instance_valid(live_actors):
		live_actors.on_slam(at, strength)


func _on_live_shot_fired(_weapon_id: String, from: Vector3, to: Vector3) -> void:
	_dispatch_live(PartResource.TRIG_ON_WEAPON_FIRE, from, to - from)
	if configured and is_instance_valid(live_actors):
		live_actors.on_shot(from, to)


func _on_live_dashed(direction: Vector3) -> void:
	_dispatch_live(PartResource.TRIG_ON_DASH, _live_ctx.player.ball_position(), direction)


func _dispatch_live(trigger: StringName, origin: Vector3, dir: Vector3 = Vector3.ZERO) -> void:
	if not configured or _live_ctx == null:
		return
	var velocity: Vector3 = _live_ctx.player.state.velocity
	dispatch_player_event(trigger, {
		"origin": origin,
		"dir": dir if dir.length_squared() > 1e-6 else velocity,
		"ball_speed_mps": Vector2(velocity.x, velocity.z).length(),
	})


func teardown() -> void:
	_disconnect_signals()
	_free_live_actors()
	ExperimentalAudioBank.reset_cooldowns()
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
	detach_live()
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
	if is_instance_valid(live_actors):
		live_actors.spawn_elite(elite_inst)


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
