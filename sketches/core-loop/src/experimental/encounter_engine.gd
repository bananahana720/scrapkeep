extends RefCounted


const EnvTags := preload("res://src/experimental/env_tags.gd")
const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")

const DEFAULT_CATALOG_PATH := "res://src/experimental/resources/director/spillway_encounter_catalog.tres"
const DIG_CATALOG_PATH := "res://src/experimental/resources/director/dig_encounter_catalog.tres"
const HIGHDRAFT_CATALOG_PATH := "res://src/experimental/resources/director/highdraft_encounter_catalog.tres"
const MIN_TELL_S := 0.6
const BEACON_WAVE_GAP_S := 1.8
const WALL_SPRING := 60.0
const WALL_DAMP := 8.0
const WALL_ACCEL_CAP := 120.0

signal fact_emitted(fact: Dictionary)
signal env_tag_emitted(payload: Dictionary)
signal encounter_state_changed(encounter_id: String, state: StringName)
signal payout_awarded(encounter_id: String, payout: Dictionary)

var catalog: Resource
var rng := RandomNumberGenerator.new()
var triggered_volumes: Dictionary = {}
var active_triggered_id := ""
var active_random: Dictionary = {}
var random_cooldown_s := 14.0
var _serial := 0
var _greed_rewards_paid := 0
var settled_history: Array[Dictionary] = []


func _init(seed_value: int = 20261126, custom_catalog: Resource = null) -> void:
	rng.seed = seed_value
	catalog = custom_catalog if custom_catalog != null else ResourceLoader.load(DEFAULT_CATALOG_PATH)
	random_cooldown_s = float(_cat("initial_random_cooldown_s", 14.0))


func _cat(prop: String, fallback):
	if catalog != null and prop in catalog:
		return catalog.get(prop)
	return fallback


func _triggered_specs() -> Dictionary:
	return _cat("triggered_specs", {})


func _random_specs() -> Dictionary:
	return _cat("random_specs", {})


func register_triggered_volume(
		id: String,
		kind: StringName,
		origin: Vector3,
		biome_id: StringName = &"") -> Dictionary:
	var specs := _triggered_specs()
	if not specs.has(kind):
		return {}
	var spec: Dictionary = specs[kind]
	var resolved_biome := biome_id if biome_id != &"" else StringName(_cat("default_biome_id", &""))
	var volume := {
		"id": id,
		"kind": kind,
		"display_name": String(spec["display_name"]),
		"opt_in_line": String(spec["opt_in_line"]),
		"origin": origin,
		"biome_id": resolved_biome,
		"trigger_radius_m": float(spec["trigger_radius_m"]),
		"lock_radius_m": float(spec["lock_radius_m"]),
		"state": &"armed",
		"payout_settled": false,
		"wave_index": 0,
		"wave_wait_s": 0.0,
		"wave_remaining": 0,
		"elapsed_s": 0.0,
		"apex": null,
		"chain_kills": 0,
		"chain_speed_sum": 0.0,
		"chain_multiplier": 1.0,
	}
	triggered_volumes[id] = volume
	return volume.duplicate(true)


static func build_trigger_area(volume: Dictionary) -> Area3D:
	var area := Area3D.new()
	area.name = "EncounterVolume_%s" % String(volume.get("id", "unknown"))
	area.monitoring = true
	area.monitorable = false
	area.position = volume.get("origin", Vector3.ZERO)
	area.set_meta("encounter_id", String(volume.get("id", "")))
	area.set_meta("encounter_kind", StringName(volume.get("kind", &"")))
	area.set_meta("opt_in_line", String(volume.get("opt_in_line", "")))
	var shape_node := CollisionShape3D.new()
	shape_node.name = "TriggerShape"
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(1.0, float(volume.get("trigger_radius_m", 7.5)))
	shape_node.shape = sphere
	area.add_child(shape_node)
	return area


func has_active_lockdown() -> bool:
	if active_triggered_id == "" or not triggered_volumes.has(active_triggered_id):
		return false
	var vol: Dictionary = triggered_volumes[active_triggered_id]
	return vol["kind"] == &"scrap_beacon_lockdown" and vol["state"] in [&"locked_waves", &"apex_active"]


func evaluate_random_weights(run_ctx: Dictionary) -> Dictionary:
	var specs := _random_specs()
	var threshold := int(_cat("greed_scrap_threshold", 120))
	var biome: StringName = StringName(run_ctx.get("biome_id", _cat("default_biome_id", &"")))
	var elapsed: float = maxf(0.0, float(run_ctx.get("elapsed_s", 0.0)))
	var tier: int = maxi(1, int(run_ctx.get("hazard_tier", 1)))
	var unrefined_scrap: int = maxi(0, int(run_ctx.get("unrefined_scrap", 0)))
	var courier_bounty: int = maxi(0, int(run_ctx.get("courier_bounty", 0)))

	var airdrop_w := 0.0
	if specs.has(&"airdrop_salvage_pod"):
		var airdrop_spec: Dictionary = specs[&"airdrop_salvage_pod"]
		airdrop_w = float(airdrop_spec["base_weight"]) \
			* float((airdrop_spec["biome_weights"] as Dictionary).get(biome, 1.0)) \
			* (1.0 + minf(0.6, elapsed / 180.0))

	var compactor_w := 0.0
	if specs.has(&"rogue_compactor_chase"):
		var compactor_spec: Dictionary = specs[&"rogue_compactor_chase"]
		compactor_w = float(compactor_spec["base_weight"]) \
			* float((compactor_spec["biome_weights"] as Dictionary).get(biome, 1.0)) \
			* (0.75 + 0.25 * float(tier))

	var greed_w := 0.0
	if specs.has(&"greed_ambush_swarm") and (unrefined_scrap >= threshold or courier_bounty > 0):
		var scrap_pressure := maxf(0.0, float(unrefined_scrap - threshold + 60) / 140.0)
		var courier_pressure := float(courier_bounty) / 55.0
		greed_w = clampf(0.8 + scrap_pressure * 1.65 + courier_pressure * 2.1, 0.0, 6.5)

	return {
		&"airdrop_salvage_pod": airdrop_w,
		&"rogue_compactor_chase": compactor_w,
		&"greed_ambush_swarm": greed_w,
	}


func activate_triggered(id: String, run_ctx: Dictionary) -> Dictionary:
	var result := {"started": false, "reason": "", "facts": [], "spawns": [], "env_tags": []}
	if not triggered_volumes.has(id):
		result["reason"] = "unknown_volume"
		return result
	var vol: Dictionary = triggered_volumes[id]
	if vol["state"] != &"armed":
		result["reason"] = "not_armed"
		return result
	if active_triggered_id != "":
		result["reason"] = "another_triggered_active"
		return result
	var is_lockdown: bool = vol["kind"] == &"scrap_beacon_lockdown"
	if is_lockdown and (bool(run_ctx.get("active_lockdown", false)) or bool(run_ctx.get("warden_awake", false))):
		result["reason"] = "lockdown_blocked"
		return result

	active_triggered_id = id
	vol["elapsed_s"] = 0.0
	var specs := _triggered_specs()
	if is_lockdown:
		var spec: Dictionary = specs[&"scrap_beacon_lockdown"]
		vol["state"] = &"locked_waves"
		vol["wave_index"] = 0
		vol["wave_wait_s"] = 0.0
		var wave_kinds: Array = (spec["waves"] as Array)[0]
		vol["wave_remaining"] = wave_kinds.size()
		_emit_wave_spawns(vol, wave_kinds, result["spawns"])
		encounter_state_changed.emit(id, &"locked_waves")
		result["facts"].append({
			"kind": "encounter_lockdown_started",
			"id": id,
			"encounter_kind": &"scrap_beacon_lockdown",
			"origin": vol["origin"],
			"lock_radius_m": float(vol["lock_radius_m"]),
			"wave": 1,
		})
	elif vol["kind"] == &"over_audit_blitz_gate":
		var spec: Dictionary = specs[&"over_audit_blitz_gate"]
		vol["state"] = &"blitz_live"
		vol["chain_kills"] = 0
		vol["chain_speed_sum"] = 0.0
		vol["chain_multiplier"] = 1.0
		encounter_state_changed.emit(id, &"blitz_live")
		result["facts"].append({
			"kind": "encounter_blitz_started",
			"id": id,
			"encounter_kind": &"over_audit_blitz_gate",
			"origin": vol["origin"],
			"duration_s": float(spec["duration_s"]),
		})
	result["started"] = true
	for f in result["facts"]:
		fact_emitted.emit(f)
	return result


func report_encounter_kill(ball_speed_mps: float = 14.0, cruise_mps: float = 14.0) -> Dictionary:
	var out := {"facts": [], "payout": {}, "unlocked": false}
	if active_triggered_id == "" or not triggered_volumes.has(active_triggered_id):
		return out
	var vol: Dictionary = triggered_volumes[active_triggered_id]
	if vol["kind"] == &"scrap_beacon_lockdown" and vol["state"] == &"locked_waves":
		vol["wave_remaining"] = maxi(0, int(vol["wave_remaining"]) - 1)
		var prog := {
			"kind": "lockdown_wave_progress",
			"id": vol["id"],
			"wave": int(vol["wave_index"]) + 1,
			"remaining": int(vol["wave_remaining"]),
		}
		out["facts"].append(prog)
		fact_emitted.emit(prog)
	elif vol["kind"] == &"over_audit_blitz_gate" and vol["state"] == &"blitz_live":
		vol["chain_kills"] = int(vol["chain_kills"]) + 1
		vol["chain_speed_sum"] = float(vol["chain_speed_sum"]) + ball_speed_mps
		var speed_ratio := ball_speed_mps / maxf(1.0, cruise_mps)
		if speed_ratio >= 1.0:
			vol["chain_multiplier"] = minf(3.0, float(vol["chain_multiplier"]) + 0.35)
		elif speed_ratio >= 0.8:
			vol["chain_multiplier"] = minf(3.0, float(vol["chain_multiplier"]) + 0.15)
		var spec: Dictionary = _triggered_specs()[&"over_audit_blitz_gate"]
		if int(vol["chain_kills"]) >= int(spec["target_kills"]):
			_settle_blitz(vol, &"won", out)
	return out


func damage_apex_construct(
		damage: float,
		hit_speed_mps: float,
		cruise_mps: float,
		active_tags: Array[StringName] = []) -> Dictionary:
	var out := {"hit": {}, "facts": [], "payout": {}, "env_tags": [], "unlocked": false}
	if active_triggered_id == "" or not triggered_volumes.has(active_triggered_id):
		return out
	var vol: Dictionary = triggered_volumes[active_triggered_id]
	if vol["state"] != &"apex_active" or vol["apex"] == null:
		return out
	var apex = vol["apex"]
	var hit: Dictionary = apex.apply_hit(damage, hit_speed_mps, cruise_mps, active_tags)
	out["hit"] = hit
	out["env_tags"].append_array(hit["env_tags"])
	for tag_payload in hit["env_tags"]:
		env_tag_emitted.emit(tag_payload)
	if bool(hit["defeated"]):
		_settle_lockdown(vol, &"won", out)
	return out


func evaluate_compactor_crusher(enemies: Array[Dictionary]) -> Dictionary:
	var out := {"crushed_ids": [], "scrap_bonus": 0, "crusher_damage": 0.0, "facts": []}
	if active_random.is_empty() or active_random["kind"] != &"rogue_compactor_chase" \
			or active_random["phase"] != &"live":
		return out
	var spec: Dictionary = _random_specs()[&"rogue_compactor_chase"]
	out["crusher_damage"] = float(spec.get("crusher_damage", 220.0))
	var pos: Vector3 = active_random["pos"]
	var dir: Vector3 = active_random["dir"]
	var half_w := float(spec["lane_half_width_m"])
	var scrap_each := int(spec["crushed_enemy_scrap"])
	var crushed_set: Dictionary = active_random["crushed_set"]
	for enemy in enemies:
		var eid := String(enemy.get("id", ""))
		if eid == "" or crushed_set.has(eid):
			continue
		var epos: Vector3 = enemy.get("origin", Vector3.ZERO)
		var rel := Vector3(epos.x - pos.x, 0.0, epos.z - pos.z)
		var along := rel.dot(dir)
		var across := (rel - dir * along).length()
		if absf(along) <= half_w * 1.4 and across <= half_w:
			crushed_set[eid] = true
			out["crushed_ids"].append(eid)
			out["scrap_bonus"] = int(out["scrap_bonus"]) + scrap_each
			var fact := {
				"kind": "rogue_compactor_crushed_enemy",
				"enemy_id": eid,
				"crew_number": int(spec.get("crew_number", 38)),
				"at": epos,
			}
			out["facts"].append(fact)
			fact_emitted.emit(fact)
	return out


func resolve_active_random(outcome: StringName = &"won", run_ctx: Dictionary = {}) -> Dictionary:
	var out := {"facts": [], "payout": {}}
	if active_random.is_empty():
		return out
	if bool(active_random.get("payout_settled", false)):
		return out
	active_random["payout_settled"] = true
	var enc_id := String(active_random["id"])
	var kind: StringName = active_random["kind"]
	if outcome == &"won":
		var spec: Dictionary = _random_specs()[kind]
		if spec.has("payout"):
			var payout: Dictionary = (spec["payout"] as Dictionary).duplicate(true)
			if kind == &"greed_ambush_swarm":
				var carried := maxi(0, int(run_ctx.get("unrefined_scrap", 0)))
				var cap_div := int(spec.get("dividend_scrap_cap", 160))
				var dividend := mini(cap_div, int(round(float(carried) * float(spec["dividend_scrap_share"]))))
				if _greed_rewards_paid > 0:
					payout["scrap"] = int(round(float(dividend) * 0.5))
					payout["cogs"] = int(round(float(payout["cogs"]) * 0.5))
					payout["cores"] = 0
					payout["part_rolls"] = 0
					payout["guaranteed_rarity"] = &""
				else:
					payout["scrap"] = int(payout["scrap"]) + dividend
				_greed_rewards_paid += 1
			out["payout"] = payout
			payout_awarded.emit(enc_id, payout)
	var fact := {
		"kind": "random_encounter_ended",
		"id": enc_id,
		"encounter_kind": kind,
		"outcome": outcome,
	}
	out["facts"].append(fact)
	fact_emitted.emit(fact)
	encounter_state_changed.emit(enc_id, &"settled")
	settled_history.append({"id": enc_id, "kind": kind, "outcome": outcome})
	active_random = {}
	random_cooldown_s = float(_cat("random_cooldown_s", 24.0))
	return out


func abort_all(reason: StringName = &"stage_ended") -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if active_triggered_id != "" and triggered_volumes.has(active_triggered_id):
		var vol: Dictionary = triggered_volumes[active_triggered_id]
		var sink := {"facts": [], "payout": {}, "unlocked": false}
		if vol["kind"] == &"scrap_beacon_lockdown":
			_settle_lockdown(vol, reason, sink)
		elif vol["kind"] == &"over_audit_blitz_gate":
			_settle_blitz(vol, reason, sink)
		for f in sink["facts"]:
			facts.append(f)
	if not active_random.is_empty():
		var ended := resolve_active_random(reason)
		for f in ended["facts"]:
			facts.append(f)
	return facts


func advance(delta: float, run_ctx: Dictionary) -> Dictionary:
	var result := {
		"facts": [],
		"spawns": [],
		"env_tags": [],
		"cover_spawned": [],
		"payout": {},
		"ball_accel": Vector3.ZERO,
		"active_lockdown": has_active_lockdown(),
	}
	if delta <= 0.0:
		return result

	var ball_pos: Vector3 = run_ctx.get("ball_pos", Vector3.ZERO)
	var ball_vel: Vector3 = run_ctx.get("ball_vel", Vector3.ZERO)
	var cruise_mps: float = float(run_ctx.get("cruise_mps", 14.0))
	var warden_awake: bool = bool(run_ctx.get("warden_awake", false))

	if active_triggered_id == "" and not warden_awake:
		for id in triggered_volumes:
			var vol: Dictionary = triggered_volumes[id]
			if vol["state"] != &"armed":
				continue
			var dist := ball_pos.distance_to(vol["origin"] as Vector3)
			if dist <= float(vol["trigger_radius_m"]):
				var act := activate_triggered(id, run_ctx)
				if bool(act["started"]):
					result["facts"].append_array(act["facts"])
					result["spawns"].append_array(act["spawns"])
					result["env_tags"].append_array(act["env_tags"])
				break

	if active_triggered_id != "" and triggered_volumes.has(active_triggered_id):
		var vol: Dictionary = triggered_volumes[active_triggered_id]
		_step_triggered(vol, delta, ball_pos, ball_vel, cruise_mps, warden_awake, result)

	_step_random(delta, run_ctx, result)

	for tag_payload in result["env_tags"]:
		env_tag_emitted.emit(tag_payload)

	result["active_lockdown"] = has_active_lockdown()
	return result


func _step_triggered(
		vol: Dictionary,
		delta: float,
		ball_pos: Vector3,
		ball_vel: Vector3,
		cruise_mps: float,
		warden_awake: bool,
		result: Dictionary) -> void:
	vol["elapsed_s"] = float(vol["elapsed_s"]) + delta
	var specs := _triggered_specs()
	if vol["kind"] == &"scrap_beacon_lockdown":
		var spec: Dictionary = specs[&"scrap_beacon_lockdown"]
		if warden_awake:
			_settle_lockdown(vol, &"warden_preempted", result)
			return
		if float(vol["elapsed_s"]) >= float(spec["max_duration_s"]):
			_settle_lockdown(vol, &"timed_out", result)
			return
		result["ball_accel"] = (result["ball_accel"] as Vector3) + _perimeter_spring_accel(
			ball_pos, ball_vel, vol["origin"], float(vol["lock_radius_m"])
		)
		if vol["state"] == &"locked_waves":
			if int(vol["wave_remaining"]) <= 0:
				var waves: Array = spec["waves"]
				if float(vol["wave_wait_s"]) <= 0.0:
					vol["wave_wait_s"] = BEACON_WAVE_GAP_S
					var f := {"kind": "lockdown_wave_cleared", "id": vol["id"], "wave": int(vol["wave_index"]) + 1}
					result["facts"].append(f)
					fact_emitted.emit(f)
				else:
					vol["wave_wait_s"] = float(vol["wave_wait_s"]) - delta
					if float(vol["wave_wait_s"]) <= 0.0:
						var next_idx := int(vol["wave_index"]) + 1
						if next_idx < waves.size():
							vol["wave_index"] = next_idx
							var wave_kinds: Array = waves[next_idx]
							vol["wave_remaining"] = wave_kinds.size()
							_emit_wave_spawns(vol, wave_kinds, result["spawns"])
							var f := {"kind": "lockdown_wave_started", "id": vol["id"], "wave": next_idx + 1}
							result["facts"].append(f)
							fact_emitted.emit(f)
						else:
							_spawn_apex_construct(vol, spec, result)
		elif vol["state"] == &"apex_active" and vol["apex"] != null:
			var apex_tick: Dictionary = vol["apex"].step(delta, ball_pos, ball_vel, cruise_mps)
			result["facts"].append_array(apex_tick["facts"])
			for f in apex_tick["facts"]:
				fact_emitted.emit(f)
			result["env_tags"].append_array(apex_tick["env_tags"])
			result["ball_accel"] = (result["ball_accel"] as Vector3) + (apex_tick["ball_accel"] as Vector3)
	elif vol["kind"] == &"over_audit_blitz_gate" and vol["state"] == &"blitz_live":
		var spec: Dictionary = specs[&"over_audit_blitz_gate"]
		if float(vol["elapsed_s"]) >= float(spec["duration_s"]):
			var outcome := &"won" if int(vol["chain_kills"]) >= 4 else &"timed_out"
			_settle_blitz(vol, outcome, result)


func _spawn_apex_construct(vol: Dictionary, spec: Dictionary, result: Dictionary) -> void:
	_serial += 1
	var variant_id: StringName = StringName(spec["apex_variant"])
	var apex := RefurbishedElites.spawn_instance(
		variant_id,
		"apex_compactor_%d" % _serial,
		(vol["origin"] as Vector3) + Vector3(8.0, 0.0, 0.0),
		1.25
	)
	if apex != null:
		apex.display_name = String(spec["apex_name"])
		apex.card_line = String(spec.get("apex_card_line", "Salvage press override engaged. Clearing floor."))
		if spec.has("apex_silhouette"):
			apex.silhouette_cue = String(spec["apex_silhouette"])
		if spec.has("apex_cadence"):
			apex.movement_cadence = String(spec["apex_cadence"])
		var extra := int(spec.get("apex_extra_plates", 1))
		for i in extra:
			apex.plates.append({
				"slot": apex.plates.size(),
				"label": "apex_plate_%d" % i,
				"integrity": 45.0,
				"max_integrity": 45.0,
				"intact": true,
				"weak_tags": [&"coolant_brittle", &"electrified"],
			})
	vol["apex"] = apex
	vol["state"] = &"apex_active"
	encounter_state_changed.emit(String(vol["id"]), &"apex_active")
	var fact := {
		"kind": "apex_construct_spawned",
		"id": vol["id"],
		"apex_id": apex.instance_id if apex != null else "",
		"display_name": String(spec["apex_name"]),
		"plate_count": apex.intact_plate_count() if apex != null else 0,
		"silhouette_cue": apex.silhouette_cue if apex != null else "",
		"movement_cadence": apex.movement_cadence if apex != null else "",
	}
	result["facts"].append(fact)
	fact_emitted.emit(fact)


func _settle_lockdown(vol: Dictionary, outcome: StringName, out: Dictionary) -> void:
	if outcome != &"won" and vol["apex"] != null:
		vol["apex"].bounty_paid = true
	vol["state"] = &"settled"
	vol["apex"] = null
	var vol_id := String(vol["id"])
	if active_triggered_id == vol_id:
		active_triggered_id = ""
	if outcome == &"won" and not bool(vol["payout_settled"]):
		vol["payout_settled"] = true
		var spec: Dictionary = _triggered_specs()[&"scrap_beacon_lockdown"]
		var payout: Dictionary = (spec["payout"] as Dictionary).duplicate(true)
		out["payout"] = payout
		payout_awarded.emit(vol_id, payout)
	else:
		vol["payout_settled"] = true
	out["unlocked"] = true
	encounter_state_changed.emit(vol_id, &"settled")
	var fact := {
		"kind": "encounter_lockdown_ended",
		"id": vol_id,
		"outcome": outcome,
		"paid": outcome == &"won",
	}
	out["facts"].append(fact)
	fact_emitted.emit(fact)
	settled_history.append({"id": vol_id, "kind": &"scrap_beacon_lockdown", "outcome": outcome})


func _settle_blitz(vol: Dictionary, outcome: StringName, out: Dictionary) -> void:
	vol["state"] = &"settled"
	var vol_id := String(vol["id"])
	if active_triggered_id == vol_id:
		active_triggered_id = ""
	if outcome == &"won" and not bool(vol["payout_settled"]):
		vol["payout_settled"] = true
		var spec: Dictionary = _triggered_specs()[&"over_audit_blitz_gate"]
		var base: Dictionary = (spec["base_payout"] as Dictionary).duplicate(true)
		var mult := float(vol["chain_multiplier"])
		base["cores"] = maxi(1, int(round(float(base["cores"]) * mult)))
		base["cogs"] = int(round(float(base["cogs"]) * mult))
		base["chain_multiplier"] = mult
		out["payout"] = base
		payout_awarded.emit(vol_id, base)
	else:
		vol["payout_settled"] = true
	encounter_state_changed.emit(vol_id, &"settled")
	var fact := {
		"kind": "encounter_blitz_ended",
		"id": vol_id,
		"outcome": outcome,
		"chain_kills": int(vol["chain_kills"]),
		"chain_multiplier": float(vol["chain_multiplier"]),
	}
	out["facts"].append(fact)
	fact_emitted.emit(fact)
	settled_history.append({"id": vol_id, "kind": &"over_audit_blitz_gate", "outcome": outcome})


func _step_random(delta: float, run_ctx: Dictionary, result: Dictionary) -> void:
	var warden_awake: bool = bool(run_ctx.get("warden_awake", false))
	if warden_awake and not active_random.is_empty():
		var preempted := resolve_active_random(&"warden_preempted", run_ctx)
		result["facts"].append_array(preempted["facts"])
		return
	var blocked: bool = has_active_lockdown() \
		or bool(run_ctx.get("active_lockdown", false)) \
		or warden_awake
	if active_random.is_empty():
		if blocked:
			return
		random_cooldown_s -= delta
		if random_cooldown_s <= 0.0:
			var picked := _draw_random_kind(run_ctx)
			if picked != &"":
				_start_random_encounter(picked, run_ctx, result)
		return

	active_random["timer_s"] = float(active_random["timer_s"]) - delta
	var kind: StringName = active_random["kind"]
	var specs := _random_specs()
	match kind:
		&"airdrop_salvage_pod":
			var spec: Dictionary = specs[&"airdrop_salvage_pod"]
			if active_random["phase"] == &"telegraph" and float(active_random["timer_s"]) <= 0.0:
				active_random["phase"] = &"live"
				active_random["timer_s"] = float(spec["contest_s"])
				var at: Vector3 = active_random["origin"]
				result["env_tags"].append(EnvTags.make_payload(
					&"burning", at, float(spec["impact_radius_m"]), String(active_random["id"]), 0.9, 3.5, EnvTags.BOUNDS_ELITE
				))
				result["env_tags"].append(EnvTags.make_payload(
					&"slag_coated", at, float(spec["impact_radius_m"]) * 0.8, String(active_random["id"]) + "#slag", 0.75, 4.0, EnvTags.BOUNDS_ELITE
				))
				result["cover_spawned"].append({
					"id": String(active_random["id"]) + "_cover",
					"kind": &"salvage_pod_hull",
					"origin": at,
					"half_extents": spec["cover_half_extents"],
					"destructible_tier": int(spec["cover_destructible_tier"]),
				})
				for k in spec["scavenger_pack"]:
					result["spawns"].append({"kind": StringName(k), "at": at + Vector3(5.0, 0.0, 0.0), "source": String(active_random["id"])})
				var f := {"kind": "airdrop_pod_landed", "id": String(active_random["id"]), "at": at}
				result["facts"].append(f)
				fact_emitted.emit(f)
			elif active_random["phase"] == &"live" and float(active_random["timer_s"]) <= 0.0:
				var ended := resolve_active_random(&"expired", run_ctx)
				result["facts"].append_array(ended["facts"])
		&"rogue_compactor_chase":
			var spec: Dictionary = specs[&"rogue_compactor_chase"]
			if active_random["phase"] == &"telegraph" and float(active_random["timer_s"]) <= 0.0:
				active_random["phase"] = &"live"
				active_random["timer_s"] = float(spec["duration_s"])
				var f := {
					"kind": "rogue_compactor_rolling",
					"id": String(active_random["id"]),
					"crew_number": int(spec.get("crew_number", 38)),
					"at": active_random["pos"],
					"dir": active_random["dir"],
				}
				result["facts"].append(f)
				fact_emitted.emit(f)
			elif active_random["phase"] == &"live":
				active_random["pos"] = (active_random["pos"] as Vector3) + (active_random["dir"] as Vector3) * float(spec["speed_mps"]) * delta
				if float(active_random["timer_s"]) <= 0.0:
					var ended := resolve_active_random(&"passed", run_ctx)
					result["facts"].append_array(ended["facts"])
		&"greed_ambush_swarm":
			var spec: Dictionary = specs[&"greed_ambush_swarm"]
			if active_random["phase"] == &"telegraph" and float(active_random["timer_s"]) <= 0.0:
				active_random["phase"] = &"live"
				active_random["timer_s"] = 35.0
				var at: Vector3 = active_random["origin"]
				for k in spec["interceptor_pack"]:
					result["spawns"].append({"kind": StringName(k), "at": at, "source": String(active_random["id"])})
				result["spawns"].append({
					"kind": &"refurbished_elite",
					"variant_id": StringName(spec["elite_variant"]),
					"at": at,
					"source": String(active_random["id"]),
				})
				var f := {
					"kind": "greed_ambush_landed",
					"id": String(active_random["id"]),
					"call_line": String(spec["call_line"]),
					"at": at,
				}
				result["facts"].append(f)
				fact_emitted.emit(f)
			elif active_random["phase"] == &"live" and float(active_random["timer_s"]) <= 0.0:
				var ended := resolve_active_random(&"escaped", run_ctx)
				result["facts"].append_array(ended["facts"])


func _draw_random_kind(run_ctx: Dictionary) -> StringName:
	var weights := evaluate_random_weights(run_ctx)
	var total := 0.0
	var keys: Array[StringName] = [&"airdrop_salvage_pod", &"rogue_compactor_chase", &"greed_ambush_swarm"]
	for k in keys:
		total += float(weights.get(k, 0.0))
	if total <= 0.0:
		return &""
	var pick := rng.randf() * total
	for k in keys:
		pick -= float(weights.get(k, 0.0))
		if pick < 0.0:
			return k
	return keys[-1]


func _start_random_encounter(kind: StringName, run_ctx: Dictionary, result: Dictionary) -> void:
	_serial += 1
	var spec: Dictionary = _random_specs()[kind]
	var min_gap := float(_cat("min_random_gap_m", 28.0))
	var ball_pos: Vector3 = run_ctx.get("ball_pos", Vector3.ZERO)
	var ball_vel: Vector3 = run_ctx.get("ball_vel", Vector3.ZERO)
	var flat_v := Vector3(ball_vel.x, 0.0, ball_vel.z)
	var forward := flat_v.normalized() if flat_v.length() > 1.0 else Vector3(1.0, 0.0, 0.0)
	var spot := ball_pos + forward * 38.0
	for id in triggered_volumes:
		var vol_pos: Vector3 = triggered_volumes[id]["origin"]
		if Vector2(spot.x - vol_pos.x, spot.z - vol_pos.z).length() < min_gap:
			spot += Vector3(-forward.z, 0.0, forward.x) * min_gap
	var tell_s := maxf(MIN_TELL_S, float(spec["tell_s"]))
	var enc_id := "%s_%d" % [String(kind), _serial]
	active_random = {
		"id": enc_id,
		"kind": kind,
		"phase": &"telegraph",
		"timer_s": tell_s,
		"origin": spot,
		"pos": spot - forward * 24.0,
		"dir": forward,
		"crushed_set": {},
		"payout_settled": false,
	}
	encounter_state_changed.emit(enc_id, &"telegraph")
	var fact := {
		"kind": "random_encounter_announced",
		"id": enc_id,
		"encounter_kind": kind,
		"display_name": String(spec["display_name"]),
		"tell_s": tell_s,
		"at": spot,
	}
	result["facts"].append(fact)
	fact_emitted.emit(fact)


func _emit_wave_spawns(vol: Dictionary, kinds: Array, spawns: Array) -> void:
	var origin: Vector3 = vol["origin"]
	var r := float(vol["lock_radius_m"]) * 0.65
	var base_a := float(vol["wave_index"]) * 1.4
	for i in kinds.size():
		var a := base_a + (float(i) / maxf(1.0, float(kinds.size()))) * TAU
		spawns.append({
			"kind": StringName(kinds[i]),
			"at": origin + Vector3(cos(a) * r, 0.0, sin(a) * r),
			"source": String(vol["id"]),
		})


static func _perimeter_spring_accel(
		ball_pos: Vector3,
		ball_vel: Vector3,
		centre: Vector3,
		radius: float) -> Vector3:
	if radius <= 0.0:
		return Vector3.ZERO
	var out := Vector3(ball_pos.x - centre.x, 0.0, ball_pos.z - centre.z)
	var dist := out.length()
	if dist <= radius or dist < 0.001:
		return Vector3.ZERO
	var n := out / dist
	var outward := maxf(0.0, ball_vel.dot(n))
	return -n * minf(WALL_ACCEL_CAP, WALL_SPRING * (dist - radius) + WALL_DAMP * outward)
