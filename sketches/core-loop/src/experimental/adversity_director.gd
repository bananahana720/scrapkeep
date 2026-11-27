extends RefCounted


const RefurbishedElites := preload("res://src/experimental/refurbished_elites.gd")

const DEFAULT_CONFIG_PATH := "res://src/experimental/resources/director/spillway_adversity_config.tres"
const DIG_CONFIG_PATH := "res://src/experimental/resources/director/dig_adversity_config.tres"
const HIGHDRAFT_CONFIG_PATH := "res://src/experimental/resources/director/highdraft_adversity_config.tres"
const MIN_SPAWN_GAP_M := 25.0
const ARRIVAL_TELL_S := 1.0
const HAZARD_TELL_FLOOR_S := 0.6

enum HazardPhase { IDLE, WARNING, RAMP, PEAK, RECEDE, COOLDOWN }

signal fact_emitted(fact: Dictionary)
signal env_tag_emitted(payload: Dictionary)
signal elite_purchased(instance)
signal hazard_phase_changed(hazard_id: StringName, phase: int)

var config: Resource
var rng := RandomNumberGenerator.new()
var biome_id: StringName = &""
var stage_threat := 1.0
var elapsed_s := 0.0
var credit_pool := 0.0
var credits_accrued := 0.0
var credits_spent := 0.0
var hazard_tier := 1
var setpiece_spike_tiers := 0
var alive_cap := 18

var stall_meter := 0.0
var flow_meter := 0.0
var escape_lane_open := true
var _camp_anchor := Vector3.ZERO
var _camp_anchor_set := false
var _camp_time_s := 0.0
var _stall_tier_active := false
var _highest_announced_tier := 1
var _last_heading := 0.0
var _have_heading := false
var _held_line_s := 0.0

var _purchase_serial := 0
var _elite_cooldown_s := 0.0
var _last_elite_variant: StringName = &""
var _last_pack_id: StringName = &""
var _next_purchase: Dictionary = {}
var active_elites: Array = []
var pending_arrivals: Array[Dictionary] = []

var hazard_phase: int = HazardPhase.IDLE
var active_hazard_id: StringName = &""
var _next_hazard_id: StringName = &""
var hazard_elapsed_s := 0.0
var hazard_cooldown_s := 10.0
var hazard_origin := Vector3.ZERO
var hazard_floor_y := 0.0
var _slag_hold_waited_s := 0.0
var _slag_rise_elapsed_s := 0.0
var _hazard_tag_emit_timer := 0.0
var _last_hazard_id: StringName = &""
var hazard_cycles_completed := 0


func _init(
		seed_value: int = 20261126,
		biome: StringName = &"",
		threat: float = 1.0,
		custom_config: Resource = null) -> void:
	rng.seed = seed_value
	config = custom_config if custom_config != null else ResourceLoader.load(DEFAULT_CONFIG_PATH)
	biome_id = biome if biome != &"" else StringName(_cfg("default_biome_id", &""))
	stage_threat = maxf(0.5, threat)
	alive_cap = int(_cfg("alive_cap", 18))
	hazard_tier = 1


func _cfg(prop: String, fallback):
	if config != null and prop in config:
		return config.get(prop)
	return fallback


func _elite_pool() -> Array:
	var pool: Array = _cfg("elite_pool", [])
	return pool if not pool.is_empty() else RefurbishedElites.load_default_pool()


func _hazard_defs() -> Dictionary:
	return _cfg("hazard_configs", {})


func _fleet_packs() -> Array:
	return _cfg("fleet_packs", [])


func _enemy_roles() -> Dictionary:
	return _cfg("enemy_roles", {})


func _foreman_memos() -> Array:
	return _cfg("foreman_tier_memos", ["Throughput adjustment approved. Carry on."])


func enemy_role_clarity(role_id: StringName) -> Dictionary:
	var roles := _enemy_roles()
	return (roles[role_id] as Dictionary).duplicate(true) if roles.has(role_id) else {}


func behavioral_escalation_snapshot() -> Dictionary:
	var unlocked_packs: Array[StringName] = []
	for pack in _fleet_packs():
		if int(pack["min_tier"]) <= hazard_tier:
			unlocked_packs.append(StringName(pack["id"]))
	var unlocked_elites := RefurbishedElites.eligible_variants(hazard_tier, INF, &"", _elite_pool())
	var unlocked_hazards: Array[StringName] = []
	var hdefs := _hazard_defs()
	for key in hdefs:
		if int((hdefs[key] as Dictionary)["min_tier"]) <= hazard_tier:
			unlocked_hazards.append(StringName(key))
	return {
		"hazard_tier": hazard_tier,
		"base_hull_hp_scale": stage_threat,
		"unlocked_packs": unlocked_packs,
		"unlocked_elites": unlocked_elites,
		"unlocked_hazards": unlocked_hazards,
		"income_rate": effective_income_rate(),
	}


func trigger_setpiece_spike(extra_tiers: int = 1, bonus_credits: float = -1.0) -> void:
	var credits_add := float(_cfg("setpiece_spike_credits", 12.0)) if bonus_credits < 0.0 else bonus_credits
	var cap_val := float(_cfg("credit_pool_cap", 48.0))
	setpiece_spike_tiers = maxi(0, setpiece_spike_tiers + extra_tiers)
	credit_pool = minf(cap_val, credit_pool + maxf(0.0, credits_add))
	credits_accrued += maxf(0.0, credits_add)


func clear_setpiece_spike() -> void:
	setpiece_spike_tiers = 0


func effective_income_rate() -> float:
	var base_rate := float(_cfg("base_income_per_s", 2.4))
	var step := float(_cfg("tier_income_step", 0.55))
	var stall_bonus := float(_cfg("stall_income_max_bonus", 0.85))
	var tier_base := base_rate + float(hazard_tier - 1) * step
	var stall_mult := 1.0 + stall_meter * stall_bonus
	return tier_base * stall_mult


func _sightline_hazard_def() -> Dictionary:
	var hdefs := _hazard_defs()
	if active_hazard_id != &"" and hdefs.has(active_hazard_id):
		var active_def: Dictionary = hdefs[active_hazard_id]
		if active_def.has("min_sightline_m"):
			return active_def
	for key in hdefs:
		var def: Dictionary = hdefs[key]
		if def.has("min_sightline_m"):
			return def
	return {}


func current_sightline_m() -> float:
	var squall := _sightline_hazard_def()
	var base_m := float(squall.get("base_sightline_m", 360.0))
	var hdefs := _hazard_defs()
	if active_hazard_id == &"" or not hdefs.has(active_hazard_id):
		return base_m
	var active_def: Dictionary = hdefs[active_hazard_id]
	if not active_def.has("min_sightline_m"):
		return base_m
	return lerpf(base_m, float(active_def.get("min_sightline_m", 85.0)), hazard_intensity())


func close_silhouette_boost() -> float:
	var hdefs := _hazard_defs()
	if active_hazard_id == &"" or not hdefs.has(active_hazard_id):
		return 1.0
	var active_def: Dictionary = hdefs[active_hazard_id]
	if not active_def.has("silhouette_boost_max"):
		return 1.0
	return lerpf(1.0, float(active_def.get("silhouette_boost_max", 1.65)), hazard_intensity())


func telegraph_contrast_boost() -> float:
	var hdefs := _hazard_defs()
	if active_hazard_id == &"" or not hdefs.has(active_hazard_id):
		return 1.0
	var active_def: Dictionary = hdefs[active_hazard_id]
	if not active_def.has("telegraph_contrast_max"):
		return 1.0
	return lerpf(1.0, float(active_def.get("telegraph_contrast_max", 1.4)), hazard_intensity())


func slag_tide_depth_m() -> float:
	var slag: Dictionary = _hazard_defs().get(&"rising_slag_tide", {})
	var hidden := float(slag.get("hidden_below_m", 1.5))
	if active_hazard_id != &"rising_slag_tide":
		return -hidden
	var peak := float(slag.get("peak_depth_m", 2.4))
	match hazard_phase:
		HazardPhase.RAMP:
			var frac := clampf(_slag_rise_elapsed_s / maxf(0.01, float(slag.get("ramp_s", 4.0))), 0.0, 1.0)
			return lerpf(-hidden, peak, frac)
		HazardPhase.PEAK:
			return peak
		HazardPhase.RECEDE:
			var frac := clampf(hazard_elapsed_s / maxf(0.01, float(slag.get("recede_s", 5.0))), 0.0, 1.0)
			return lerpf(peak, -hidden, frac)
		_:
			return -hidden


func is_slag_floor_clear() -> bool:
	return slag_tide_depth_m() <= 0.0


func hazard_intensity() -> float:
	var hdefs := _hazard_defs()
	if active_hazard_id == &"" or not hdefs.has(active_hazard_id):
		return 0.0
	var def: Dictionary = hdefs[active_hazard_id]
	match hazard_phase:
		HazardPhase.RAMP:
			if active_hazard_id == &"rising_slag_tide":
				return clampf(_slag_rise_elapsed_s / maxf(0.01, float(def["ramp_s"])), 0.0, 1.0)
			return clampf(hazard_elapsed_s / maxf(0.01, float(def["ramp_s"])), 0.0, 1.0)
		HazardPhase.PEAK:
			return 1.0
		HazardPhase.RECEDE:
			return 1.0 - clampf(hazard_elapsed_s / maxf(0.01, float(def["recede_s"])), 0.0, 1.0)
		_:
			return 0.0


func start_hazard(hazard_id: StringName, origin: Vector3, floor_y: float = 0.0) -> bool:
	var hdefs := _hazard_defs()
	if not hdefs.has(hazard_id):
		return false
	if hazard_phase != HazardPhase.IDLE and hazard_phase != HazardPhase.COOLDOWN:
		return false
	active_hazard_id = hazard_id
	hazard_phase = HazardPhase.WARNING
	hazard_elapsed_s = 0.0
	hazard_origin = origin
	hazard_floor_y = floor_y
	_slag_hold_waited_s = 0.0
	_slag_rise_elapsed_s = 0.0
	_hazard_tag_emit_timer = 0.0
	hazard_phase_changed.emit(active_hazard_id, hazard_phase)
	return true


func compute_magnetic_force(
		entity_pos: Vector3,
		entity_vel: Vector3,
		mass_class: StringName,
		cruise_mps: float = -1.0) -> Vector3:
	if active_hazard_id != &"magnetic_storm":
		return Vector3.ZERO
	var intensity := hazard_intensity()
	if intensity <= 0.0:
		return Vector3.ZERO
	var hdefs := _hazard_defs()
	if not hdefs.has(&"magnetic_storm"):
		return Vector3.ZERO
	var def: Dictionary = hdefs[&"magnetic_storm"]
	var cruise := float(_cfg("default_cruise_mps", 14.0)) if cruise_mps <= 0.0 else cruise_mps
	var fast_ratio := float(_cfg("fast_speed_ratio", 0.85))
	var radius := float(def["radius_m"])
	var to_pole := Vector3(hazard_origin.x - entity_pos.x, 0.0, hazard_origin.z - entity_pos.z)
	var dist := to_pole.length()
	if dist > radius or dist < 0.001:
		return Vector3.ZERO
	var inward := to_pole / dist
	var swirl := Vector3(-inward.z, 0.0, inward.x)
	var falloff := clampf(1.0 - (dist / radius) * 0.65, 0.25, 1.0) * intensity

	match mass_class:
		&"loose_scrap":
			return (inward * float(def["pull_strength"]) * 1.45 + swirl * float(def["swirl_strength"]) * 1.2) * falloff
		&"metallic_prop":
			return (inward * float(def["pull_strength"]) * 0.95 + swirl * float(def["swirl_strength"]) * 0.85) * falloff
		&"metal_projectile":
			var flat_v := Vector3(entity_vel.x, 0.0, entity_vel.z)
			if flat_v.length() < 0.1:
				return inward * float(def["projectile_deflect"]) * falloff
			var perp := Vector3(-flat_v.z, 0.0, flat_v.x).normalized()
			return (perp * float(def["projectile_deflect"]) + inward * float(def["pull_strength"]) * 0.35) * falloff
		&"player_ball":
			var flat_v := Vector3(entity_vel.x, 0.0, entity_vel.z)
			var speed := flat_v.length()
			if speed >= cruise * fast_ratio:
				var forward := flat_v.normalized()
				var lateral := inward - forward * inward.dot(forward)
				var boost_scale := 0.0 if speed >= cruise * 1.65 else 1.0
				var raw := lateral * float(def["pull_strength"]) * 0.55 * falloff \
					+ forward * float(def["slingshot_boost"]) * falloff * boost_scale
				return RefurbishedElites.never_brake(raw, entity_vel)
			return (inward * float(def["pull_strength"]) * 0.45 + swirl * float(def["swirl_strength"]) * 0.25) * falloff
		_:
			return Vector3.ZERO


func compute_crosswind_force(
		entity_pos: Vector3,
		entity_vel: Vector3,
		mass_class: StringName,
		cruise_mps: float = -1.0) -> Vector3:
	if active_hazard_id != &"gale_shear_crosswind":
		return Vector3.ZERO
	var intensity := hazard_intensity()
	if intensity <= 0.0:
		return Vector3.ZERO
	var hdefs := _hazard_defs()
	if not hdefs.has(&"gale_shear_crosswind"):
		return Vector3.ZERO
	var def: Dictionary = hdefs[&"gale_shear_crosswind"]
	var radius := float(def.get("radius_m", 52.0))
	var dist := Vector2(entity_pos.x - hazard_origin.x, entity_pos.z - hazard_origin.z).length()
	if dist > radius:
		return Vector3.ZERO
	var cruise := float(_cfg("default_cruise_mps", 14.0)) if cruise_mps <= 0.0 else cruise_mps
	var fast_ratio := float(_cfg("fast_speed_ratio", 0.85))
	var strength := float(def.get("crosswind_strength", 13.5)) * intensity
	var wind_dir := Vector3(0.0, 0.0, 1.0) if int(hazard_cycles_completed) % 2 == 0 else Vector3(1.0, 0.0, 0.0)
	match mass_class:
		&"loose_scrap", &"metallic_prop":
			return wind_dir * strength * 1.15
		&"metal_projectile":
			return wind_dir * float(def.get("projectile_deflect", 14.0)) * intensity
		&"player_ball":
			var flat_v := Vector3(entity_vel.x, 0.0, entity_vel.z)
			var speed := flat_v.length()
			if speed >= cruise * fast_ratio:
				var forward := flat_v.normalized()
				var lateral := wind_dir - forward * wind_dir.dot(forward)
				var boost_scale := 0.0 if speed >= cruise * 1.65 else 1.0
				var raw := lateral * strength * 0.45 + forward * float(def.get("slingshot_boost", 11.5)) * intensity * boost_scale
				return RefurbishedElites.never_brake(raw, entity_vel)
			return wind_dir * strength * 0.55
		_:
			return Vector3.ZERO


func compute_tremor_force(
		entity_pos: Vector3,
		entity_vel: Vector3,
		cruise_mps: float = -1.0) -> Vector3:
	if active_hazard_id != &"subterranean_tremor":
		return Vector3.ZERO
	var intensity := hazard_intensity()
	if intensity <= 0.0:
		return Vector3.ZERO
	var hdefs := _hazard_defs()
	if not hdefs.has(&"subterranean_tremor"):
		return Vector3.ZERO
	var def: Dictionary = hdefs[&"subterranean_tremor"]
	var radius := float(def.get("radius_m", 48.0))
	var dist := Vector2(entity_pos.x - hazard_origin.x, entity_pos.z - hazard_origin.z).length()
	if dist > radius:
		return Vector3.ZERO
	var cruise := float(_cfg("default_cruise_mps", 14.0)) if cruise_mps <= 0.0 else cruise_mps
	var fast_ratio := float(_cfg("fast_speed_ratio", 0.85))
	var pulse_sign := 1.0 if sin(hazard_elapsed_s * 5.0) >= 0.0 else -1.0
	var lateral_dir := Vector3(pulse_sign, 0.0, -pulse_sign * 0.5).normalized()
	var raw := lateral_dir * float(def.get("tremor_lateral_accel", 11.5)) * intensity
	var flat_v := Vector3(entity_vel.x, 0.0, entity_vel.z)
	if flat_v.length() >= cruise * fast_ratio:
		return RefurbishedElites.never_brake(raw * 0.35, entity_vel)
	return raw


func advance(
		delta: float,
		ball_pos: Vector3,
		ball_vel: Vector3,
		alive_count: int,
		cruise_mps: float = -1.0,
		grounded: bool = true) -> Dictionary:
	var cruise := float(_cfg("default_cruise_mps", 14.0)) if cruise_mps <= 0.0 else cruise_mps
	var result := {
		"facts": [],
		"due_spawns": [],
		"new_elites": [],
		"env_tags": [],
		"ball_accel": Vector3.ZERO,
		"hazard_tier": hazard_tier,
		"stall_meter": stall_meter,
		"flow_meter": flow_meter,
		"escape_lane_open": escape_lane_open,
		"sightline_m": current_sightline_m(),
		"slag_depth_m": slag_tide_depth_m(),
	}
	if delta <= 0.0:
		return result

	elapsed_s += delta
	_elite_cooldown_s = maxf(0.0, _elite_cooldown_s - delta)

	_update_momentum_pressure(delta, ball_pos, ball_vel, cruise)
	_update_hazard_tier(result["facts"])

	var income := effective_income_rate() * delta
	var cap_val := float(_cfg("credit_pool_cap", 48.0))
	credit_pool = minf(cap_val, credit_pool + income)
	credits_accrued += income

	_step_arrivals(delta, ball_pos, result["due_spawns"])
	_step_active_elites(delta, ball_pos, ball_vel, cruise, result)

	_step_hazard(delta, ball_pos, ball_vel, grounded, cruise, result)

	var total_live := alive_count + pending_arrivals.size() + active_elites.size()
	_spend_credits(ball_pos, ball_vel, total_live, result)

	for fact in result["facts"]:
		fact_emitted.emit(fact)
	for tag_payload in result["env_tags"]:
		env_tag_emitted.emit(tag_payload)

	result["hazard_tier"] = hazard_tier
	result["stall_meter"] = stall_meter
	result["flow_meter"] = flow_meter
	result["escape_lane_open"] = escape_lane_open
	result["sightline_m"] = current_sightline_m()
	result["slag_depth_m"] = slag_tide_depth_m()
	return result


func _update_momentum_pressure(delta: float, ball_pos: Vector3, ball_vel: Vector3, cruise_mps: float) -> void:
	var stall_ratio := float(_cfg("stall_speed_ratio", 0.55))
	var fast_ratio := float(_cfg("fast_speed_ratio", 0.85))
	var camp_r := float(_cfg("camp_radius_m", 8.5))
	var stall_rise := float(_cfg("stall_rise_per_s", 0.28))
	var stall_decay := float(_cfg("stall_decay_per_s", 0.45))
	var flow_rise := float(_cfg("flow_rise_per_s", 0.30))
	var flow_decay := float(_cfg("flow_decay_per_s", 0.25))

	var flat_v := Vector3(ball_vel.x, 0.0, ball_vel.z)
	var speed := flat_v.length()
	var speed_ratio := speed / maxf(1.0, cruise_mps)

	if not _camp_anchor_set:
		_camp_anchor = ball_pos
		_camp_anchor_set = true
		_camp_time_s = 0.0
	var camp_dist := Vector2(ball_pos.x - _camp_anchor.x, ball_pos.z - _camp_anchor.z).length()
	if camp_dist <= camp_r:
		_camp_time_s += delta
	else:
		_camp_anchor = ball_pos
		_camp_time_s = 0.0
	var camping := _camp_time_s >= 2.0

	var turning := false
	if speed >= 3.0:
		var heading := atan2(flat_v.z, flat_v.x)
		if _have_heading:
			var turn_rate := absf(wrapf(heading - _last_heading, -PI, PI)) / maxf(0.001, delta)
			if turn_rate >= 0.45:
				turning = true
				_held_line_s = 0.0
			else:
				_held_line_s += delta
		_last_heading = heading
		_have_heading = true
	else:
		_have_heading = false
		_held_line_s = 0.0

	if speed_ratio < stall_ratio or camping:
		var stall_rate := stall_rise * (1.35 if speed_ratio < stall_ratio and camping else 1.0)
		stall_meter = clampf(stall_meter + stall_rate * delta, 0.0, 1.0)
		flow_meter = clampf(flow_meter - flow_decay * delta, 0.0, 1.0)
	elif speed_ratio >= fast_ratio:
		var decay_mult := 1.25 if turning else 1.0
		stall_meter = clampf(stall_meter - stall_decay * decay_mult * delta, 0.0, 1.0)
		flow_meter = clampf(flow_meter + flow_rise * decay_mult * delta, 0.0, 1.0)
	else:
		stall_meter = clampf(stall_meter - stall_decay * 0.25 * delta, 0.0, 1.0)
		flow_meter = clampf(flow_meter - flow_decay * 0.2 * delta, 0.0, 1.0)

	escape_lane_open = speed_ratio >= fast_ratio or stall_meter < 0.75


func _update_hazard_tier(facts: Array) -> void:
	var interval := maxf(1.0, float(_cfg("tier_interval_s", 45.0)))
	var max_clock := maxi(1, int(_cfg("max_clock_tier", 5)))
	var memos := _foreman_memos()
	var clock_tier := mini(1 + int(elapsed_s / interval), max_clock)
	if stall_meter >= 0.85:
		_stall_tier_active = true
	elif stall_meter <= 0.60:
		_stall_tier_active = false
	var stall_tier := 1 if _stall_tier_active else 0
	var desired := clock_tier + setpiece_spike_tiers + stall_tier
	if desired > hazard_tier:
		for next_tier in range(hazard_tier + 1, desired + 1):
			if next_tier > _highest_announced_tier:
				_highest_announced_tier = next_tier
				var reason := "stall_pressure" if stall_tier > 0 and next_tier == desired else \
					("setpiece_spike" if setpiece_spike_tiers > 0 else "clock_escalation")
				var memo_idx := clampi(next_tier - 1, 0, maxi(0, memos.size() - 1))
				facts.append({
					"kind": "hazard_tier_rose",
					"tier": next_tier,
					"reason": reason,
					"memo": String(memos[memo_idx]) if not memos.is_empty() else "",
				})
		hazard_tier = desired
	elif desired < hazard_tier:
		hazard_tier = maxi(clock_tier, desired)


func _step_arrivals(delta: float, ball_pos: Vector3, due_spawns: Array) -> void:
	for i in range(pending_arrivals.size() - 1, -1, -1):
		var arrival: Dictionary = pending_arrivals[i]
		arrival["left_s"] = float(arrival["left_s"]) - delta
		if float(arrival["left_s"]) <= 0.0:
			pending_arrivals.remove_at(i)
			var at: Vector3 = arrival["at"]
			var dist := Vector2(at.x - ball_pos.x, at.z - ball_pos.z).length()
			if dist >= MIN_SPAWN_GAP_M:
				due_spawns.append(arrival)


func _step_active_elites(
		delta: float,
		ball_pos: Vector3,
		ball_vel: Vector3,
		cruise_mps: float,
		result: Dictionary) -> void:
	var kept: Array = []
	for elite in active_elites:
		if elite == null or elite.is_defeated():
			continue
		var tick: Dictionary = elite.step(delta, ball_pos, ball_vel, cruise_mps)
		result["facts"].append_array(tick["facts"])
		result["env_tags"].append_array(tick["env_tags"])
		result["ball_accel"] = (result["ball_accel"] as Vector3) + (tick["ball_accel"] as Vector3)
		kept.append(elite)
	active_elites = kept


func _spend_credits(ball_pos: Vector3, ball_vel: Vector3, total_live: int, result: Dictionary) -> void:
	if total_live >= alive_cap:
		return
	if hazard_phase == HazardPhase.IDLE and _next_hazard_id != &"":
		return
	var room := alive_cap - total_live
	var pool := _elite_pool()
	var max_elites := int(_cfg("max_active_elites", 2))
	var elite_cd := float(_cfg("elite_min_cooldown_s", 18.0))

	if _next_purchase.is_empty():
		_next_purchase = _draw_next_purchase(room, pool, max_elites)
	if _next_purchase.is_empty():
		return

	var kind: StringName = StringName(_next_purchase["purchase_kind"])
	var cost := float(_next_purchase["cost"])
	if credit_pool < cost:
		return

	if kind == &"elite":
		if active_elites.size() >= max_elites or _elite_cooldown_s > 0.0:
			_next_purchase = {}
			return
		var spec: Dictionary = _next_purchase["spec"]
		credit_pool -= cost
		credits_spent += cost
		_purchase_serial += 1
		_elite_cooldown_s = elite_cd * lerpf(1.0, 0.72, stall_meter)
		_last_elite_variant = StringName(spec["id"])
		var spot := _spawn_spot(ball_pos, ball_vel, 44.0, 68.0)
		var inst := RefurbishedElites.spawn_instance(
			_last_elite_variant,
			"refurb_%d" % _purchase_serial,
			spot,
			stage_threat,
			pool
		)
		_next_purchase = {}
		if inst != null:
			active_elites.append(inst)
			result["new_elites"].append(inst)
			elite_purchased.emit(inst)
			result["facts"].append({
				"kind": "refurbished_elite_purchased",
				"instance_id": inst.instance_id,
				"variant_id": inst.variant_id,
				"display_name": inst.display_name,
				"card_line": inst.card_line,
				"cost": cost,
				"at": spot,
			})
		return

	var pack: Dictionary = _next_purchase["pack"]
	var kinds: Array = pack["kinds"]
	if kinds.size() > room:
		return
	credit_pool -= cost
	credits_spent += cost
	_purchase_serial += 1
	_last_pack_id = StringName(pack["id"])
	_next_purchase = {}
	var base_spot := _spawn_spot(ball_pos, ball_vel, 38.0, 72.0)
	for i in kinds.size():
		var offset := Vector3(float(i - 1) * 4.0, 0.0, float(i % 2) * 3.0)
		pending_arrivals.append({
			"kind": StringName(kinds[i]),
			"pack_id": _last_pack_id,
			"pack_seq": _purchase_serial,
			"at": base_spot + offset,
			"left_s": ARRIVAL_TELL_S,
		})
	result["facts"].append({
		"kind": "fleet_pack_queued",
		"pack_id": _last_pack_id,
		"pack_seq": _purchase_serial,
		"count": kinds.size(),
		"cost": cost,
		"at": base_spot,
	})


func _draw_next_purchase(room: int, pool: Array, max_elites: int) -> Dictionary:
	var can_elite := active_elites.size() < max_elites and _elite_cooldown_s <= 0.0 and room >= 1
	if can_elite:
		var elite_chance := 0.28 + stall_meter * 0.35
		if rng.randf() < elite_chance:
			var spec := RefurbishedElites.select_variant(
				rng, hazard_tier, INF, biome_id, _last_elite_variant, pool
			)
			if not spec.is_empty():
				return {"purchase_kind": &"elite", "cost": float(spec["credit_cost"]), "spec": spec}
	var pack := _pick_fleet_pack(room)
	if pack.is_empty():
		return {}
	return {"purchase_kind": &"pack", "cost": float(pack["cost"]), "pack": pack}


func _pick_fleet_pack(room: int) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var total := 0.0
	for pack in _fleet_packs():
		var kinds: Array = pack["kinds"]
		if int(pack["min_tier"]) > hazard_tier or kinds.size() > room:
			continue
		var w := float(pack["weight"])
		if StringName(pack["id"]) == _last_pack_id:
			w *= 0.35
		w *= lerpf(1.0, float(pack["stall_bias"]), stall_meter)
		candidates.append({"pack": pack, "w": w})
		total += w
	if candidates.is_empty() or total <= 0.0:
		return {}
	var pick := rng.randf() * total
	for entry in candidates:
		pick -= float(entry["w"])
		if pick < 0.0:
			return entry["pack"]
	return candidates[-1]["pack"]


func _spawn_spot(ball_pos: Vector3, ball_vel: Vector3, min_dist: float, max_dist: float) -> Vector3:
	var flat_v := Vector3(ball_vel.x, 0.0, ball_vel.z)
	var base_angle := atan2(flat_v.z, flat_v.x) if flat_v.length() > 1.0 else rng.randf() * TAU
	var cone := 0.65 if escape_lane_open else 1.4
	var angle := base_angle + rng.randf_range(-cone, cone)
	var dist := maxf(MIN_SPAWN_GAP_M + 4.0, rng.randf_range(min_dist, max_dist))
	return ball_pos + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _step_hazard(
		delta: float,
		ball_pos: Vector3,
		ball_vel: Vector3,
		grounded: bool,
		cruise_mps: float,
		result: Dictionary) -> void:
	var hdefs := _hazard_defs()
	match hazard_phase:
		HazardPhase.IDLE:
			hazard_cooldown_s -= delta * (1.0 + stall_meter * 0.4)
			if hazard_cooldown_s <= 0.0:
				if _next_hazard_id == &"" or not hdefs.has(_next_hazard_id):
					_next_hazard_id = _pick_hazard()
				if _next_hazard_id != &"" and hdefs.has(_next_hazard_id):
					var def: Dictionary = hdefs[_next_hazard_id]
					var cost := float(def["credit_cost"])
					if credit_pool >= cost:
						var chosen := _next_hazard_id
						_next_hazard_id = &""
						credit_pool -= cost
						credits_spent += cost
						var anchor := ball_pos + Vector3(ball_vel.x, 0.0, ball_vel.z) * 0.5
						start_hazard(chosen, anchor, ball_pos.y)
						_last_hazard_id = chosen
						result["facts"].append({
							"kind": "hazard_announced",
							"id": chosen,
							"display_name": String(def["display_name"]),
							"warning_s": maxf(HAZARD_TELL_FLOOR_S, float(def["warning_s"])),
							"at": hazard_origin,
						})
		HazardPhase.COOLDOWN:
			hazard_cooldown_s -= delta
			if hazard_cooldown_s <= 0.0:
				hazard_phase = HazardPhase.IDLE
				hazard_phase_changed.emit(&"", hazard_phase)
		HazardPhase.WARNING:
			var def: Dictionary = hdefs[active_hazard_id]
			var warn_s := maxf(HAZARD_TELL_FLOOR_S, float(def["warning_s"]))
			hazard_elapsed_s += delta
			if hazard_elapsed_s >= warn_s:
				hazard_phase = HazardPhase.RAMP
				hazard_elapsed_s = 0.0
				_slag_hold_waited_s = 0.0
				_slag_rise_elapsed_s = 0.0
				_hazard_tag_emit_timer = 0.0
				hazard_phase_changed.emit(active_hazard_id, hazard_phase)
				result["facts"].append({
					"kind": "hazard_started",
					"id": active_hazard_id,
					"at": hazard_origin,
				})
		HazardPhase.RAMP:
			var def: Dictionary = hdefs[active_hazard_id]
			var ramp_s := float(def["ramp_s"])
			var hold_cap := float(_cfg("slag_hold_cap_s", 2.0))
			if active_hazard_id == &"rising_slag_tide":
				var inside := Vector2(ball_pos.x - hazard_origin.x, ball_pos.z - hazard_origin.z).length() <= float(def["radius_m"])
				var low_basin := ball_pos.y <= hazard_floor_y + float(def["peak_depth_m"])
				if inside and low_basin and grounded and _slag_hold_waited_s < hold_cap:
					_slag_hold_waited_s += delta
				else:
					_slag_rise_elapsed_s += delta
				hazard_elapsed_s += delta
				if _slag_rise_elapsed_s >= ramp_s:
					hazard_phase = HazardPhase.PEAK
					hazard_elapsed_s = 0.0
					hazard_phase_changed.emit(active_hazard_id, hazard_phase)
					_emit_hazard_tags(def, result["env_tags"])
			else:
				hazard_elapsed_s += delta
				if hazard_elapsed_s >= ramp_s:
					hazard_phase = HazardPhase.PEAK
					hazard_elapsed_s = 0.0
					hazard_phase_changed.emit(active_hazard_id, hazard_phase)
					_emit_hazard_tags(def, result["env_tags"])
			_apply_active_hazard_effects(delta, ball_pos, ball_vel, cruise_mps, def, result)
		HazardPhase.PEAK:
			var def: Dictionary = hdefs[active_hazard_id]
			hazard_elapsed_s += delta
			_apply_active_hazard_effects(delta, ball_pos, ball_vel, cruise_mps, def, result)
			if hazard_elapsed_s >= float(def["peak_s"]):
				hazard_phase = HazardPhase.RECEDE
				hazard_elapsed_s = 0.0
				hazard_phase_changed.emit(active_hazard_id, hazard_phase)
				result["facts"].append({
					"kind": "hazard_receding",
					"id": active_hazard_id,
					"at": hazard_origin,
				})
		HazardPhase.RECEDE:
			var def: Dictionary = hdefs[active_hazard_id]
			hazard_elapsed_s += delta
			_apply_active_hazard_effects(delta, ball_pos, ball_vel, cruise_mps, def, result)
			if hazard_elapsed_s >= float(def["recede_s"]):
				var finished_id := active_hazard_id
				hazard_phase = HazardPhase.COOLDOWN
				active_hazard_id = &""
				hazard_elapsed_s = 0.0
				hazard_cooldown_s = float(_cfg("hazard_cooldown_s", 16.0))
				hazard_cycles_completed += 1
				hazard_phase_changed.emit(finished_id, hazard_phase)
				result["facts"].append({
					"kind": "hazard_ended",
					"id": finished_id,
					"outcome": "receded",
				})


func _apply_active_hazard_effects(
		delta: float,
		ball_pos: Vector3,
		ball_vel: Vector3,
		cruise_mps: float,
		def: Dictionary,
		result: Dictionary) -> void:
	_hazard_tag_emit_timer -= delta
	if _hazard_tag_emit_timer <= 0.0 and hazard_intensity() >= 0.35:
		_hazard_tag_emit_timer = 2.0
		_emit_hazard_tags(def, result["env_tags"])
	if active_hazard_id == &"magnetic_storm":
		result["ball_accel"] = (result["ball_accel"] as Vector3) + compute_magnetic_force(
			ball_pos, ball_vel, &"player_ball", cruise_mps
		)
	elif active_hazard_id == &"gale_shear_crosswind":
		result["ball_accel"] = (result["ball_accel"] as Vector3) + compute_crosswind_force(
			ball_pos, ball_vel, &"player_ball", cruise_mps
		)
	elif active_hazard_id == &"subterranean_tremor":
		result["ball_accel"] = (result["ball_accel"] as Vector3) + compute_tremor_force(
			ball_pos, ball_vel, cruise_mps
		)


func _emit_hazard_tags(def: Dictionary, out_tags: Array) -> void:
	_hazard_tag_emit_timer = 2.0
	var intensity := maxf(0.4, hazard_intensity())
	var radius := float(def["radius_m"])
	var id_str := String(def["id"])
	out_tags.append(RefurbishedElites.make_env_tag_payload(
		StringName(def["primary_tag"]),
		hazard_origin,
		radius,
		"hazard:%s" % id_str,
		intensity,
		2.5
	))
	if def.has("secondary_tag") and StringName(def["secondary_tag"]) != &"":
		out_tags.append(RefurbishedElites.make_env_tag_payload(
			StringName(def["secondary_tag"]),
			hazard_origin,
			radius * 0.85,
			"hazard:%s#secondary" % id_str,
			intensity * 0.85,
			2.5
		))


func _pick_hazard() -> StringName:
	var hdefs := _hazard_defs()
	var pool: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for key in hdefs:
		var id: StringName = StringName(key)
		var def: Dictionary = hdefs[id]
		if int(def["min_tier"]) > hazard_tier:
			continue
		var biome_map: Dictionary = def.get("biome_weights", {})
		var w := float(biome_map.get(biome_id, 1.0))
		if id == _last_hazard_id:
			w *= 0.25
		pool.append(id)
		weights.append(w)
		total += w
	if pool.is_empty() or total <= 0.0:
		return &""
	var pick := rng.randf() * total
	for i in pool.size():
		pick -= weights[i]
		if pick < 0.0:
			return pool[i]
	return pool[-1]
