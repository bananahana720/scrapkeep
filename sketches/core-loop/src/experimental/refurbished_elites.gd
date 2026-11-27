extends RefCounted


const ENV_TAGS: Array[StringName] = [
	&"electrified",
	&"burning",
	&"slag_coated",
	&"magnetic",
	&"coolant_brittle",
	&"soaked_conductive",
]

const DEFAULT_ELITE_PATHS: Array[String] = [
	"res://src/experimental/resources/director/elite_over_plated_juggernaut.tres",
	"res://src/experimental/resources/director/elite_arc_capacitor_relay.tres",
	"res://src/experimental/resources/director/elite_magnetic_tow_winch.tres",
	"res://src/experimental/resources/director/elite_slag_spill_exhaust.tres",
	"res://src/experimental/resources/director/elite_coolant_cryo_hauler.tres",
	"res://src/experimental/resources/director/elite_overclocked_foreman_spec.tres",
	"res://src/experimental/resources/director/elite_corrosive_bore_warden.tres",
	"res://src/experimental/resources/director/elite_cryo_slurry_tanker.tres",
	"res://src/experimental/resources/director/elite_gale_shear_harrier.tres",
	"res://src/experimental/resources/director/elite_choir_resonator_pylon.tres",
]

const MIN_TELL_S := 0.6
const RAM_BREAK_SPEED_RATIO := 0.85
const RAM_PLATE_MULT := 1.5
const WEAK_TAG_PLATE_MULT := 2.0
const PLATE_SHATTER_SCRAP := 14


static func make_env_tag_payload(
		tag: StringName,
		origin: Vector3,
		radius_m: float,
		source_id: String,
		intensity: float,
		ttl_s: float) -> Dictionary:
	return {
		"tag": tag,
		"origin": origin,
		"radius_m": maxf(0.1, radius_m),
		"source_id": source_id,
		"intensity": maxf(0.0, intensity),
		"ttl_s": maxf(0.1, ttl_s),
	}


static func is_valid_env_tag_payload(payload: Dictionary) -> bool:
	if not (payload.has("tag") and payload.has("origin") and payload.has("radius_m") \
			and payload.has("source_id") and payload.has("intensity") and payload.has("ttl_s")):
		return false
	var tag_name: StringName = StringName(payload["tag"])
	if not ENV_TAGS.has(tag_name):
		return false
	if not (payload["origin"] is Vector3):
		return false
	if float(payload["radius_m"]) <= 0.0 or float(payload["ttl_s"]) <= 0.0 or float(payload["intensity"]) < 0.0:
		return false
	return String(payload["source_id"]) != ""


static func never_brake(accel: Vector3, velocity: Vector3) -> Vector3:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() < 0.5:
		return accel
	var along := flat.normalized()
	var against := accel.dot(along)
	if against < 0.0:
		accel -= along * against
	return accel


static func load_default_pool() -> Array:
	var pool: Array = []
	for path in DEFAULT_ELITE_PATHS:
		var res := ResourceLoader.load(path)
		if res != null and res.has_method("to_spec_dict"):
			pool.append(res)
	return pool


static func catalog_from_pool(pool: Array = []) -> Dictionary:
	var source: Array = pool if not pool.is_empty() else load_default_pool()
	var out := {}
	for entry in source:
		if entry is Resource and entry.has_method("to_spec_dict"):
			var spec: Dictionary = entry.call("to_spec_dict")
			var id: StringName = StringName(spec.get("id", &""))
			if id != &"":
				out[id] = spec
		elif entry is Dictionary and entry.has("id"):
			var id: StringName = StringName(entry["id"])
			if id != &"":
				out[id] = (entry as Dictionary).duplicate(true)
	return out


static func variant_ids(pool: Array = []) -> Array[StringName]:
	var cat := catalog_from_pool(pool)
	var out: Array[StringName] = []
	for key in cat.keys():
		out.append(StringName(key))
	return out


static func variant_def(variant_id: StringName, pool: Array = []) -> Dictionary:
	var cat := catalog_from_pool(pool)
	if not cat.has(variant_id):
		return {}
	return (cat[variant_id] as Dictionary).duplicate(true)


static func min_cost_for_tier(hazard_tier: int, pool: Array = []) -> float:
	var cat := catalog_from_pool(pool)
	var best := INF
	for key in cat:
		var def: Dictionary = cat[key]
		if int(def["min_tier"]) <= hazard_tier:
			best = minf(best, float(def["credit_cost"]))
	return best


static func eligible_variants(
		hazard_tier: int,
		credit_budget: float,
		exclude_id: StringName = &"",
		pool: Array = []) -> Array[StringName]:
	var cat := catalog_from_pool(pool)
	var out_pool: Array[StringName] = []
	var fallback: Array[StringName] = []
	for key in cat:
		var id: StringName = StringName(key)
		var def: Dictionary = cat[id]
		if int(def["min_tier"]) <= hazard_tier and float(def["credit_cost"]) <= credit_budget:
			fallback.append(id)
			if id != exclude_id:
				out_pool.append(id)
	return out_pool if not out_pool.is_empty() else fallback


static func select_variant(
		rng: RandomNumberGenerator,
		hazard_tier: int,
		credit_budget: float,
		biome_id: StringName = &"",
		exclude_id: StringName = &"",
		pool: Array = []) -> Dictionary:
	var cat := catalog_from_pool(pool)
	var candidates := eligible_variants(hazard_tier, credit_budget, exclude_id, pool)
	if candidates.is_empty():
		return {}
	var total := 0.0
	var weights: Array[float] = []
	for id in candidates:
		var def: Dictionary = cat[id]
		var biome_map: Dictionary = def.get("biome_weights", {})
		var w: float = float(biome_map.get(biome_id, 1.0))
		if int(def["min_tier"]) >= 2 and hazard_tier >= 3:
			w *= 1.25
		weights.append(w)
		total += w
	if total <= 0.0:
		return (cat[candidates[0]] as Dictionary).duplicate(true)
	var pick := rng.randf() * total
	for i in candidates.size():
		pick -= weights[i]
		if pick < 0.0:
			return (cat[candidates[i]] as Dictionary).duplicate(true)
	return (cat[candidates[-1]] as Dictionary).duplicate(true)


static func spawn_instance(
		variant_id: StringName,
		instance_id: String,
		origin: Vector3,
		stage_threat := 1.0,
		pool: Array = []) -> RefurbishedInstance:
	var def := variant_def(variant_id, pool)
	if def.is_empty():
		return null
	return RefurbishedInstance.new(def, instance_id, origin, stage_threat)


class RefurbishedInstance extends RefCounted:
	var instance_id := ""
	var variant_id: StringName = &""
	var display_name := ""
	var maker: StringName = &"fleet"
	var requisition_code := ""
	var chassis: StringName = &""
	var card_line := ""
	var silhouette_cue := ""
	var movement_cadence := ""
	var counterplay_cue := ""
	var origin := Vector3.ZERO
	var def: Dictionary = {}

	var max_hull_hp := 100.0
	var hull_hp := 100.0
	var plates: Array[Dictionary] = []

	var phase: StringName = &"idle"
	var phase_timer := 0.0
	var cooldown_left := 0.0
	var stagger_left := 0.0
	var bounty_paid := false
	var stripped_backfire_fired := false
	var tell_target := Vector3.ZERO

	func _init(spec: Dictionary, id: String, at: Vector3, stage_threat := 1.0) -> void:
		def = spec.duplicate(true)
		instance_id = id
		variant_id = StringName(def["id"])
		display_name = String(def["display_name"])
		maker = StringName(def["maker"])
		requisition_code = String(def["requisition_code"])
		chassis = StringName(def["chassis"])
		card_line = String(def["card_line"])
		silhouette_cue = String(def.get("silhouette_cue", ""))
		movement_cadence = String(def.get("movement_cadence", ""))
		counterplay_cue = String(def.get("counterplay_cue", ""))
		origin = at
		var threat_clamped := maxf(0.5, stage_threat)
		max_hull_hp = float(def["base_hull_hp"]) * threat_clamped
		hull_hp = max_hull_hp
		cooldown_left = 1.0
		var count := int(def["plate_count"])
		var integrity := float(def["plate_integrity"])
		var weak: Array = def.get("plate_weak_tags", [])
		for i in count:
			plates.append({
				"slot": i,
				"label": "plate_%d" % i,
				"integrity": integrity,
				"max_integrity": integrity,
				"intact": true,
				"weak_tags": weak.duplicate(),
			})

	func intact_plate_count() -> int:
		var count := 0
		for plate in plates:
			if bool(plate["intact"]):
				count += 1
		return count

	func is_defeated() -> bool:
		return phase == &"defeated"

	func pack_aura_rest_scale() -> float:
		if is_defeated() or stagger_left > 0.0 or intact_plate_count() == 0:
			return 1.0
		return float(def.get("aura_pack_rest_scale", 1.0))

	static func _make_tag(
			tag: StringName,
			at: Vector3,
			radius_m: float,
			source_id: String,
			intensity: float,
			ttl_s: float) -> Dictionary:
		return {
			"tag": tag,
			"origin": at,
			"radius_m": maxf(0.1, radius_m),
			"source_id": source_id,
			"intensity": maxf(0.0, intensity),
			"ttl_s": maxf(0.1, ttl_s),
		}

	static func _never_brake_local(accel: Vector3, velocity: Vector3) -> Vector3:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if flat.length() < 0.5:
			return accel
		var along := flat.normalized()
		var against := accel.dot(along)
		if against < 0.0:
			accel -= along * against
		return accel

	func apply_hit(
			damage: float,
			hit_speed_mps: float,
			cruise_mps: float,
			active_tags: Array[StringName] = [],
			impact_origin := Vector3.INF) -> Dictionary:
		var out := {
			"plate_damaged": false,
			"plates_broken": 0,
			"hull_damage": 0.0,
			"scrap_spilled": 0,
			"staggered": false,
			"defeated": false,
			"bounty": {},
			"env_tags": [],
			"backfire_friendly_fire": false,
		}
		if damage <= 0.0 or is_defeated():
			return out
		var hit_at := origin if impact_origin == Vector3.INF else impact_origin
		var speed_ratio := hit_speed_mps / maxf(1.0, cruise_mps)
		var remaining := damage

		for plate in plates:
			if remaining <= 0.0:
				break
			if not bool(plate["intact"]):
				continue
			var mult := 1.0
			if speed_ratio >= RAM_BREAK_SPEED_RATIO:
				mult *= RAM_PLATE_MULT
			var weak_tags: Array = plate["weak_tags"]
			for tag in active_tags:
				if weak_tags.has(tag):
					mult *= WEAK_TAG_PLATE_MULT
					break
			var effective := remaining * mult
			var cur := float(plate["integrity"])
			out["plate_damaged"] = true
			if effective >= cur:
				plate["integrity"] = 0.0
				plate["intact"] = false
				var consumed := cur / maxf(0.001, mult)
				remaining = maxf(0.0, remaining - consumed)
				out["plates_broken"] = int(out["plates_broken"]) + 1
				out["scrap_spilled"] = int(out["scrap_spilled"]) + PLATE_SHATTER_SCRAP
				var shatter_tag: StringName = StringName(def.get("shatter_tag", &"slag_coated"))
				out["env_tags"].append(_make_tag(
					shatter_tag,
					hit_at,
					float(def.get("shatter_radius_m", 5.0)),
					"%s:plate_%d" % [instance_id, int(plate["slot"])],
					0.85,
					float(def.get("shatter_ttl_s", 3.0))
				))
				if phase == &"telegraph" or phase == &"execute":
					stagger_left = maxf(stagger_left, float(def.get("stagger_on_brace_break_s", 2.0)))
					phase = &"stagger"
					phase_timer = stagger_left
					out["staggered"] = true
			else:
				plate["integrity"] = cur - effective
				remaining = 0.0

		if bool(def.get("backfires_on_strip", false)) and not stripped_backfire_fired and intact_plate_count() == 0:
			stripped_backfire_fired = true
			out["backfire_friendly_fire"] = true
			out["env_tags"].append(_make_tag(
				&"electrified",
				origin,
				float(def.get("ability_radius_m", 11.0)),
				"%s:backfire" % instance_id,
				1.25,
				3.0
			))

		if remaining > 0.0 and intact_plate_count() == 0:
			var hull_mult := 1.25 if stagger_left > 0.0 else 1.0
			var applied := remaining * hull_mult
			hull_hp = maxf(0.0, hull_hp - applied)
			out["hull_damage"] = applied
			if hull_hp <= 0.0:
				phase = &"defeated"
				out["defeated"] = true
				if not bounty_paid:
					bounty_paid = true
					out["bounty"] = (def["bounty"] as Dictionary).duplicate(true)
		return out

	func step(delta: float, ball_pos: Vector3, ball_vel: Vector3, cruise_mps: float) -> Dictionary:
		var out := {
			"phase": phase,
			"facts": [],
			"env_tags": [],
			"ball_accel": Vector3.ZERO,
		}
		if is_defeated() or delta <= 0.0:
			return out

		if phase == &"stagger":
			stagger_left = maxf(0.0, stagger_left - delta)
			phase_timer = stagger_left
			if stagger_left <= 0.0:
				phase = &"idle"
				cooldown_left = maxf(0.8, float(def["cooldown_s"]) * 0.5)
			out["phase"] = phase
			return out

		match phase:
			&"idle":
				cooldown_left -= delta
				var flat_dist := Vector2(ball_pos.x - origin.x, ball_pos.z - origin.z).length()
				var reach := float(def["ability_radius_m"]) * 1.45
				if cooldown_left <= 0.0 and flat_dist <= reach:
					var tell := maxf(MIN_TELL_S, float(def["tell_s"]))
					phase = &"telegraph"
					phase_timer = tell
					var speed := Vector2(ball_vel.x, ball_vel.z).length()
					var lead_s := 0.35 if speed < cruise_mps * 0.85 else 0.0
					tell_target = ball_pos + Vector3(ball_vel.x, 0.0, ball_vel.z) * lead_s
					out["facts"].append({
						"kind": "elite_telegraph",
						"instance_id": instance_id,
						"variant_id": variant_id,
						"telegraph_kind": def["telegraph_kind"],
						"tell_s": tell,
						"target": tell_target,
						"radius_m": float(def["ability_radius_m"]),
					})
			&"telegraph":
				phase_timer -= delta
				if phase_timer <= 0.0:
					phase = &"execute"
					phase_timer = float(def["execute_s"])
					var primary_tag: StringName = StringName(def["ability_tag"])
					var emit_at := tell_target if def["telegraph_kind"] == &"projectile" else origin
					out["env_tags"].append(_make_tag(
						primary_tag,
						emit_at,
						float(def["ability_radius_m"]),
						"%s:ability" % instance_id,
						float(def["ability_intensity"]),
						float(def["ability_ttl_s"])
					))
					if def.has("secondary_tag") and StringName(def["secondary_tag"]) != &"":
						out["env_tags"].append(_make_tag(
							StringName(def["secondary_tag"]),
							emit_at,
							float(def["ability_radius_m"]) * 0.85,
							"%s:ability#secondary" % instance_id,
							float(def["ability_intensity"]) * 0.8,
							float(def["ability_ttl_s"])
						))
					out["facts"].append({
						"kind": "elite_execute",
						"instance_id": instance_id,
						"variant_id": variant_id,
						"at": emit_at,
					})
			&"execute":
				phase_timer -= delta
				if float(def.get("pull_accel", 0.0)) > 0.0:
					out["ball_accel"] = _magnetic_tether_accel(ball_pos, ball_vel, cruise_mps)
				if phase_timer <= 0.0:
					phase = &"idle"
					cooldown_left = float(def["cooldown_s"])
		out["phase"] = phase
		return out

	func _magnetic_tether_accel(ball_pos: Vector3, ball_vel: Vector3, cruise_mps: float) -> Vector3:
		var delta_xz := Vector3(origin.x - ball_pos.x, 0.0, origin.z - ball_pos.z)
		var dist := delta_xz.length()
		var max_r := float(def["ability_radius_m"])
		if dist < 0.5 or dist > max_r:
			return Vector3.ZERO
		var inward := delta_xz / dist
		var falloff := 1.0 - (dist / max_r) * 0.5
		var pull := float(def.get("pull_accel", 14.0)) * falloff
		var flat_v := Vector3(ball_vel.x, 0.0, ball_vel.z)
		var speed := flat_v.length()
		if speed >= cruise_mps * 0.85:
			var tangent := flat_v.normalized()
			var lateral := inward - tangent * inward.dot(tangent)
			var boost_scale := 0.0 if speed >= cruise_mps * 1.65 else 1.0
			var boost := tangent * (pull * 0.35 * float(def.get("slingshot_bonus", 1.35)) * boost_scale)
			return _never_brake_local(lateral * pull * 0.65 + boost, ball_vel)
		return inward * pull
