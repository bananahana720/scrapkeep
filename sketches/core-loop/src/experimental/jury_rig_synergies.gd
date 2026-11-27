extends RefCounted


const EnvTags := preload("res://src/experimental/env_tags.gd")
const PartResource := preload("res://src/experimental/part_resource.gd")

signal part_fired(receipt: Dictionary)
signal synergy_emerged(synergy: Dictionary)
signal heat_band_changed(old_band: StringName, new_band: StringName)
signal overclock_vented(vent: Dictionary)
signal meltdown_cooked(cook: Dictionary)

const BAND_COOL: StringName = &"cool"
const BAND_HOT: StringName = &"hot"
const BAND_REDLINE: StringName = &"redline"

const HEAT_MAX := 100.0
const HEAT_OVERDRIVE_CAP := 120.0
const HEAT_HOT_AT := 40.0
const HEAT_REDLINE_AT := 80.0
const BASE_VENT_HEAT_DUMP := 55.0

const CRUISE_MPS := 14.0
const VENT_MIN_SPEED_MPS := 12.0
const STALL_SPEED_MPS := 6.0
const AIRFLOW_COOL_CRUISE := 9.0
const AIRFLOW_COOL_STALL := 2.0
const COOK_DPS_STALLED := 14.0

const MAX_EVENTS_PER_PASS := 16
const PART_SOURCE_PREFIX := "part:"

const PARTS_DIR := "res://src/experimental/resources/parts"
const PART_RESOURCE_PATHS: Array[String] = [
	"res://src/experimental/resources/parts/arc_welder_dash.tres",
	"res://src/experimental/resources/parts/magnetized_sawblades.tres",
	"res://src/experimental/resources/parts/brine_tap_vent.tres",
	"res://src/experimental/resources/parts/hoard_coil_ballast.tres",
	"res://src/experimental/resources/parts/harpoon_grounding_spike.tres",
	"res://src/experimental/resources/parts/slag_skid_crucible.tres",
	"res://src/experimental/resources/parts/requisition_leech.tres",
	"res://src/experimental/resources/parts/thermite_flail_spool.tres",
]

const BATCH2_PART_RESOURCE_PATHS: Array[String] = [
	"res://src/experimental/resources/parts/caustic_bore_auger.tres",
	"res://src/experimental/resources/parts/choir_arc_lance.tres",
	"res://src/experimental/resources/parts/tremor_pile_driver.tres",
	"res://src/experimental/resources/parts/gale_shear_slipstream.tres",
	"res://src/experimental/resources/parts/cryo_slurry_manifold.tres",
	"res://src/experimental/resources/parts/overclock_capacitor_shunt.tres",
]

var env_tags: RefCounted = null
var heat := 0.0
var hull_cooked_total := 0.0
var heft_bonus_left_s := 0.0
var heft_bonus_tiers := 0

var _equipped: Dictionary = {}
var _extra_parts: Array[Resource] = []
var _synergies_log: Array[Dictionary] = []
var _dispatch_log: Array[Dictionary] = []
var _last_band: StringName = BAND_COOL
var _in_dispatch := false
var _active_dispatch_queue: Array[Dictionary] = []
var _pending_band_changes: Array[Dictionary] = []


static func reset() -> void:
	pass


static func catalogue() -> Array[Resource]:
	return _load_paths(PART_RESOURCE_PATHS)


static func catalogue_batch2() -> Array[Resource]:
	return _load_paths(BATCH2_PART_RESOURCE_PATHS)


static func all_catalogue() -> Array[Resource]:
	var combined: Array[String] = []
	combined.append_array(PART_RESOURCE_PATHS)
	combined.append_array(BATCH2_PART_RESOURCE_PATHS)
	return _load_paths(combined)


static func _load_paths(paths: Array[String]) -> Array[Resource]:
	var out: Array[Resource] = []
	for path in paths:
		var res := ResourceLoader.load(path)
		if res != null:
			out.append(res)
	return out


static func load_part(part_id: StringName) -> Resource:
	var path := "%s/%s.tres" % [PARTS_DIR, String(part_id)]
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path)


static func validate_catalogue() -> Array[String]:
	return _validate_paths(PART_RESOURCE_PATHS)


static func validate_all_catalogues() -> Array[String]:
	var combined: Array[String] = []
	combined.append_array(PART_RESOURCE_PATHS)
	combined.append_array(BATCH2_PART_RESOURCE_PATHS)
	return _validate_paths(combined)


static func _validate_paths(paths: Array[String]) -> Array[String]:
	var problems: Array[String] = []
	var seen_ids := {}
	for path in paths:
		if not ResourceLoader.exists(path):
			problems.append("missing part resource: %s" % path)
			continue
		var res := ResourceLoader.load(path)
		if res == null:
			problems.append("failed to load part resource: %s" % path)
			continue
		if not res.has_method("validate"):
			problems.append("resource %s does not expose validate()" % path)
			continue
		var p_err: Array[String] = res.validate()
		problems.append_array(p_err)
		if seen_ids.has(res.id):
			problems.append("duplicate part id: %s" % String(res.id))
		seen_ids[res.id] = true
	return problems


func _init(env_tags_ref: RefCounted = null) -> void:
	env_tags = env_tags_ref if env_tags_ref != null else EnvTags.new()


func clear() -> void:
	heat = 0.0
	hull_cooked_total = 0.0
	heft_bonus_left_s = 0.0
	heft_bonus_tiers = 0
	_equipped.clear()
	_extra_parts.clear()
	_synergies_log.clear()
	_dispatch_log.clear()
	_last_band = BAND_COOL
	_in_dispatch = false
	_active_dispatch_queue.clear()
	_pending_band_changes.clear()


func equip(part: Resource) -> Dictionary:
	if part == null:
		return {"ok": false, "problems": ["part is null"]}
	var problems: Array[String] = part.validate()
	if not problems.is_empty():
		return {"ok": false, "problems": problems}
	var replaced: Resource = _equipped.get(part.slot, null)
	_equipped[part.slot] = part
	return {"ok": true, "slot": part.slot_name(), "replaced": replaced.id if replaced != null else &""}


func equip_by_id(part_id: StringName) -> Dictionary:
	var part := load_part(part_id)
	if part == null:
		return {"ok": false, "problems": ["unknown part resource: %s" % String(part_id)]}
	return equip(part)


func unequip(slot: int) -> void:
	_equipped.erase(slot)


func equipped_parts() -> Array[Resource]:
	var out: Array[Resource] = []
	for slot in [PartResource.Slot.WEAPON, PartResource.Slot.DASH_LINE, PartResource.Slot.CORE_HUSK]:
		if _equipped.has(slot):
			out.append(_equipped[slot])
	out.append_array(_extra_parts)
	return out


func heat_band() -> StringName:
	if heat >= HEAT_REDLINE_AT:
		return BAND_REDLINE
	if heat >= HEAT_HOT_AT:
		return BAND_HOT
	return BAND_COOL


func overclock_scale() -> float:
	if heat >= HEAT_REDLINE_AT:
		return 1.75
	if heat >= HEAT_HOT_AT:
		var t := (heat - HEAT_HOT_AT) / (HEAT_REDLINE_AT - HEAT_HOT_AT)
		return lerpf(1.15, 1.45, clampf(t, 0.0, 1.0))
	return 1.0


func heat_chain_bonus() -> int:
	if heat >= HEAT_REDLINE_AT:
		return 2
	if heat >= HEAT_HOT_AT:
		return 1
	return 0


func add_heat(delta: float) -> void:
	var old_band := heat_band()
	heat = clampf(heat + delta, 0.0, HEAT_OVERDRIVE_CAP)
	var new_band := heat_band()
	if new_band != old_band:
		_last_band = new_band
		if _in_dispatch:
			_pending_band_changes.append({"old": old_band, "new": new_band})
		else:
			heat_band_changed.emit(old_band, new_band)


func step(dt: float, ball_speed_mps: float, ball_pos: Vector3 = Vector3.ZERO) -> Dictionary:
	if dt <= 0.0:
		return {"band": heat_band(), "cook_damage": 0.0, "cooled": 0.0, "stall_magnet_pull_risk": false}
	if heft_bonus_left_s > 0.0:
		heft_bonus_left_s = maxf(0.0, heft_bonus_left_s - dt)
		if heft_bonus_left_s <= 0.0:
			heft_bonus_tiers = 0

	var cook_damage := 0.0
	var band := heat_band()
	if band == BAND_REDLINE and ball_speed_mps < STALL_SPEED_MPS:
		var stall_ratio := clampf(1.0 - (ball_speed_mps / STALL_SPEED_MPS), 0.25, 1.0)
		cook_damage = COOK_DPS_STALLED * stall_ratio * dt
		hull_cooked_total += cook_damage
		meltdown_cooked.emit({
			"cook_damage": cook_damage,
			"heat": heat,
			"ball_speed_mps": ball_speed_mps,
		})

	var cool_rate := AIRFLOW_COOL_STALL
	if ball_speed_mps >= CRUISE_MPS:
		cool_rate = AIRFLOW_COOL_CRUISE
	elif ball_speed_mps > STALL_SPEED_MPS:
		var t := (ball_speed_mps - STALL_SPEED_MPS) / (CRUISE_MPS - STALL_SPEED_MPS)
		cool_rate = lerpf(AIRFLOW_COOL_STALL, AIRFLOW_COOL_CRUISE, t)

	if band != BAND_REDLINE:
		for part in equipped_parts():
			var mod := float(part.params.get("cool_scale_below_redline", 1.0))
			cool_rate *= mod

	var stall_mag_risk: bool = ball_speed_mps < STALL_SPEED_MPS \
		and not (env_tags.zones_at(ball_pos, 2.0, EnvTags.TAG_MAGNETIC) as Array).is_empty()

	var before := heat
	add_heat(-cool_rate * dt)
	return {
		"band": heat_band(),
		"cook_damage": cook_damage,
		"cooled": before - heat,
		"stall_magnet_pull_risk": stall_mag_risk,
	}


func attempt_redline_vent(origin: Vector3, ball_speed_mps: float, verb: StringName = &"slam") -> Dictionary:
	if heat < HEAT_REDLINE_AT:
		return {"vented": false, "reason": "not_redline", "heat": heat}
	if ball_speed_mps < VENT_MIN_SPEED_MPS:
		return {"vented": false, "reason": "speed_too_low", "heat": heat}

	var scale := overclock_scale()
	var radius_m := 6.5 * scale
	var damage := 28.0 * scale
	var emitted_tag := EnvTags.TAG_BURNING
	var extra_reactions: Array[Dictionary] = []
	var synergies: Array[Dictionary] = []
	var heat_before := heat

	if _has_trigger_subscriber(PartResource.TRIG_ON_OVERHEAT):
		var bus_res := dispatch(PartResource.TRIG_ON_OVERHEAT, {
			"origin": origin,
			"ball_speed_mps": ball_speed_mps,
			"verb": verb,
		})
		if bool(bus_res.get("deferred", false)):
			return {
				"vented": false,
				"deferred": true,
				"reason": "queued_in_active_dispatch",
				"heat_after": heat,
				"reactions": [],
				"synergies": [],
			}
		extra_reactions.append_array(bus_res["reactions"])
		synergies.append_array(bus_res["synergies"])
		if not bus_res["fired"].is_empty():
			var first_meta: Dictionary = bus_res["fired"][0]["meta"]
			radius_m = float(first_meta.get("vent_radius_m", radius_m))
			damage = float(first_meta.get("vent_damage", damage))
			emitted_tag = StringName(first_meta.get("emitted_tag", emitted_tag))
		if heat >= heat_before:
			add_heat(-BASE_VENT_HEAT_DUMP)
	else:
		add_heat(-BASE_VENT_HEAT_DUMP)
		var tag_res: Dictionary = env_tags.apply_tag(
			EnvTags.make_payload(EnvTags.TAG_BURNING, origin, radius_m, "overclock_vent", scale, 3.5)
		)
		extra_reactions.append_array(tag_res["reactions"])

	var receipt := {
		"vented": true,
		"verb": verb,
		"origin": origin,
		"radius_m": radius_m,
		"damage": damage,
		"emitted_tag": emitted_tag,
		"heat_after": heat,
		"reactions": extra_reactions,
		"synergies": synergies,
	}
	overclock_vented.emit(receipt)
	return receipt


func dispatch(trigger: StringName, context: Dictionary = {}) -> Dictionary:
	if _in_dispatch:
		_active_dispatch_queue.append({
			"trigger": trigger,
			"context": context.duplicate(true),
			"parent_part_id": &"",
		})
		return {
			"trigger": trigger,
			"deferred": true,
			"fired": [],
			"reactions": [],
			"synergies": [],
			"chain_hits": [],
			"heat": heat,
			"heat_band": heat_band(),
			"overclock_scale": overclock_scale(),
			"capped": false,
		}

	_in_dispatch = true
	_active_dispatch_queue = [{
		"trigger": trigger,
		"context": context.duplicate(true),
		"parent_part_id": &"",
	}]
	var resolved_keys := {}
	var fired_parts: Array[Dictionary] = []
	var reactions_all: Array[Dictionary] = []
	var synergies_hit: Array[Dictionary] = []
	var chain_hits: Array[Dictionary] = []
	var seen_synergy_keys := {}
	var events_processed := 0
	var capped := false

	var flushed_fired_idx := 0
	var flushed_syn_idx := 0

	while true:
		while not _active_dispatch_queue.is_empty():
			if events_processed >= MAX_EVENTS_PER_PASS:
				capped = true
				_active_dispatch_queue.clear()
				break
			var entry: Dictionary = _active_dispatch_queue.pop_front()
			var cur_trig: StringName = entry["trigger"]
			var cur_ctx: Dictionary = entry["context"]
			var parent_part_id: StringName = entry["parent_part_id"]
			events_processed += 1

			for part in equipped_parts():
				if not part.matches_trigger(cur_trig):
					continue
				var guard_key := "%s|%s" % [String(part.id), String(cur_trig)]
				if resolved_keys.has(guard_key):
					continue
				resolved_keys[guard_key] = true
				var outcome := _execute_part(part, cur_ctx)
				fired_parts.append(outcome)
				reactions_all.append_array(outcome["reactions"])
				chain_hits.append_array(outcome["chain_hits"])

				for r in outcome["reactions"]:
					var other_part := _part_id_from_source(String(r.get("existing_source_id", "")))
					if other_part != &"" and other_part != part.id:
						_record_synergy(synergies_hit, seen_synergy_keys, &"tag_reaction_synergy",
							other_part, part.id, StringName(r["reaction_id"]),
							float(r["damage"]) * 0.45, int(r.get("chain_hops", 0)))

				for bridged_src in outcome["meta"].get("bridged_sources", []):
					var other_part := _part_id_from_source(String(bridged_src))
					if other_part != &"" and other_part != part.id:
						_record_synergy(synergies_hit, seen_synergy_keys, &"tag_bridge_synergy",
							other_part, part.id, cur_trig,
							16.0 * overclock_scale(), 1)

				if parent_part_id != &"" and parent_part_id != part.id:
					_record_synergy(synergies_hit, seen_synergy_keys, &"signal_chain_synergy",
						parent_part_id, part.id, cur_trig,
						14.0 * overclock_scale(), 0)

				var outcome_reactions: Array = outcome["reactions"]
				var ctx_reactions: Array = cur_ctx.get("source_reactions", [])
				var has_reactions: bool = (not outcome_reactions.is_empty()) or (not ctx_reactions.is_empty())
				if has_reactions and cur_trig != PartResource.TRIG_ON_TAG_REACTION:
					_active_dispatch_queue.append({
						"trigger": PartResource.TRIG_ON_TAG_REACTION,
						"context": {
							"origin": cur_ctx.get("origin", Vector3.ZERO),
							"ball_speed_mps": float(cur_ctx.get("ball_speed_mps", CRUISE_MPS)),
							"targets": cur_ctx.get("targets", []),
							"source_reactions": outcome_reactions if not outcome_reactions.is_empty() else ctx_reactions,
						},
						"parent_part_id": part.id,
					})

		while flushed_fired_idx < fired_parts.size():
			var fp: Dictionary = fired_parts[flushed_fired_idx]
			flushed_fired_idx += 1
			part_fired.emit(fp)
		while flushed_syn_idx < synergies_hit.size():
			var syn: Dictionary = synergies_hit[flushed_syn_idx]
			flushed_syn_idx += 1
			synergy_emerged.emit(syn)
		while not _pending_band_changes.is_empty():
			var bc: Dictionary = _pending_band_changes.pop_front()
			heat_band_changed.emit(bc["old"], bc["new"])

		if _active_dispatch_queue.is_empty() or capped:
			break

	_active_dispatch_queue.clear()
	_pending_band_changes.clear()
	_in_dispatch = false

	var receipt := {
		"trigger": trigger,
		"fired": fired_parts,
		"reactions": reactions_all,
		"synergies": synergies_hit,
		"chain_hits": chain_hits,
		"heat": heat,
		"heat_band": heat_band(),
		"overclock_scale": overclock_scale(),
		"capped": capped,
	}
	_dispatch_log.append(receipt)
	return receipt


func dispatch_log() -> Array[Dictionary]:
	return _dispatch_log.duplicate(true)


func synergies_log() -> Array[Dictionary]:
	return _synergies_log.duplicate(true)


func _has_trigger_subscriber(trig: StringName) -> bool:
	for p in equipped_parts():
		if p.matches_trigger(trig):
			return true
	return false


func _record_synergy(out: Array[Dictionary], seen: Dictionary, kind: StringName,
		producer_a: StringName, producer_b: StringName, via: StringName,
		bonus_damage: float, extra_hops: int) -> void:
	var sa := String(producer_a)
	var sb := String(producer_b)
	var ordered: Array[StringName] = []
	if sa < sb:
		ordered.append(producer_a)
		ordered.append(producer_b)
	else:
		ordered.append(producer_b)
		ordered.append(producer_a)
	var key := "%s|%s|%s|%s" % [String(kind), String(ordered[0]), String(ordered[1]), String(via)]
	if seen.has(key):
		return
	seen[key] = true
	var entry := {
		"kind": kind,
		"producers": ordered,
		"via": via,
		"bonus_damage": bonus_damage,
		"extra_hops": extra_hops,
		"overclock_scale": overclock_scale(),
	}
	out.append(entry)
	_synergies_log.append(entry)


static func _source_tag_for(part_id: StringName, suffix: String = "") -> String:
	return "%s%s%s" % [PART_SOURCE_PREFIX, String(part_id), ("#" + suffix) if suffix != "" else ""]


static func _part_id_from_source(source_id: String) -> StringName:
	if not source_id.begins_with(PART_SOURCE_PREFIX):
		return &""
	var rest := source_id.trim_prefix(PART_SOURCE_PREFIX)
	var cut := rest.find("#")
	if cut >= 0:
		rest = rest.substr(0, cut)
	var arrow := rest.find(">")
	if arrow >= 0:
		rest = rest.substr(0, arrow)
	return StringName(rest)


func _execute_part(part: Resource, ctx: Dictionary) -> Dictionary:
	var origin: Vector3 = ctx.get("origin", Vector3.ZERO)
	var dir: Vector3 = ctx.get("dir", Vector3.FORWARD)
	if dir.length_squared() < 1e-6:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	var speed: float = float(ctx.get("ball_speed_mps", CRUISE_MPS))
	var scale := overclock_scale()
	var reactions: Array[Dictionary] = []
	var chain_hits: Array[Dictionary] = []
	var meta := {}
	var heat_delta: float = float(part.heat_cost)
	var src_base := _source_tag_for(part.id)

	match part.effect_id:
		&"weld_seam_trail":
			var segs: int = int(part.params.get("seam_segments", 3))
			var slag_r: float = float(part.params.get("slag_radius_m", 3.4)) * scale
			var arc_r: float = float(part.params.get("arc_radius_m", 3.0)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 5.5))
			var dash_len: float = float(ctx.get("dash_length_m", 8.0))
			for i in segs:
				var pt := origin + dir * (dash_len * float(i) / maxf(float(segs - 1), 1.0))
				var r_slag: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, pt, slag_r, src_base, scale, ttl_s)
				)
				reactions.append_array(r_slag["reactions"])
				if i == segs - 1 and bool(ctx.get("ignite_seam_tip", true)):
					var r_arc: Dictionary = env_tags.apply_tag(
						EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, pt, arc_r, _source_tag_for(part.id, "tip"), scale, ttl_s * 0.75)
					)
					reactions.append_array(r_arc["reactions"])
			meta["seam_segments"] = segs
			meta["slag_radius_m"] = slag_r

		&"mag_sawblade_chain":
			var target_pos: Vector3 = ctx.get("target_pos", origin + dir * 6.0)
			var chain_r: float = float(part.params.get("chain_radius_m", 8.5)) * scale
			var base_hops: int = int(part.params.get("base_hops", 3)) + heat_chain_bonus()
			var mag_r: float = float(part.params.get("mag_radius_m", 4.2))
			var blade_dmg: float = float(part.params.get("blade_damage", 18.0)) * scale
			var mag_deflect_rad := 0.0
			var nearby_mags: Array[Dictionary] = env_tags.zones_at(target_pos, chain_r, EnvTags.TAG_MAGNETIC)
			if not nearby_mags.is_empty():
				var pull_vec: Vector3 = (nearby_mags[0]["origin"] as Vector3) - origin
				pull_vec.y = 0.0
				if pull_vec.length() > 0.2:
					mag_deflect_rad = clampf(dir.angle_to(pull_vec.normalized()) * 0.35, 0.0, 0.45)
			var bridged_sources: Array[String] = []
			var conductive := false
			for z in env_tags.zones_at(target_pos, chain_r):
				var ztag: StringName = z["tag"]
				if part.consumes_tag(ztag):
					bridged_sources.append(String(z.get("source_id", "")))
					if ztag == EnvTags.TAG_SLAG_COATED or ztag == EnvTags.TAG_ELECTRIFIED or ztag == EnvTags.TAG_SOAKED_CONDUCTIVE:
						conductive = true
			var r_mag: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_MAGNETIC, target_pos, mag_r, src_base, scale, 4.0)
			)
			reactions.append_array(r_mag["reactions"])
			if conductive:
				var r_bridge: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, target_pos, chain_r * 0.7, _source_tag_for(part.id, "bridge"), scale, 2.5)
				)
				reactions.append_array(r_bridge["reactions"])
				var sorted_targets := _sort_targets_near(ctx.get("targets", []), target_pos, chain_r)
				var hops := mini(base_hops, sorted_targets.size())
				for h in hops:
					var t_entry: Dictionary = sorted_targets[h]
					var falloff := pow(0.85, float(h))
					chain_hits.append({
						"target_id": String(t_entry["id"]),
						"pos": t_entry["pos"],
						"damage": blade_dmg * 1.35 * falloff,
						"hop": h + 1,
						"source": &"sawblade_lightning_chain",
					})
			meta["conductive"] = conductive
			meta["hops_allowed"] = base_hops
			meta["bridged_sources"] = bridged_sources
			meta["magnetic_deflection_rad"] = mag_deflect_rad

		&"brine_quench_vent":
			var vent_r: float = float(part.params.get("vent_radius_m", 7.5)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 5.0))
			var r_cool: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, origin, vent_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_cool["reactions"])
			var r_wet: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, origin, vent_r * 0.85, _source_tag_for(part.id, "pool"), scale, ttl_s)
			)
			reactions.append_array(r_wet["reactions"])
			meta["vent_radius_m"] = vent_r
			meta["vent_damage"] = float(part.params.get("quench_damage", 26.0)) * scale
			meta["emitted_tag"] = EnvTags.TAG_COOLANT_BRITTLE

		&"magnetic_flywheel_pulse":
			var pulse_r: float = float(part.params.get("pulse_radius_m", 5.5)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 3.5))
			var r_mag: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_MAGNETIC, origin, pulse_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_mag["reactions"])
			meta["speed_bonus_mps"] = float(part.params.get("speed_bonus_mps", 1.8)) * scale
			meta["pull_force"] = float(part.params.get("pull_force", 14.0)) * scale

		&"grounding_spike_surge":
			var clean_snap: bool = bool(ctx.get("clean_snap", true))
			if not clean_snap:
				heat_delta = float(part.params.get("miss_heat_penalty", 12.0))
				meta["clean_snap"] = false
			else:
				var anchor_pos: Vector3 = ctx.get("anchor_pos", origin)
				var spike_r: float = float(part.params.get("spike_radius_m", 6.5)) * scale
				var ttl_s: float = float(part.params.get("ttl_s", 4.0))
				var r_elec: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, anchor_pos, spike_r, src_base, scale, ttl_s)
				)
				reactions.append_array(r_elec["reactions"])
				meta["clean_snap"] = true
				meta["anchor_pos"] = anchor_pos

		&"crucible_slag_pour":
			var min_speed: float = float(part.params.get("min_speed_mps", 10.0))
			if speed < min_speed:
				meta["poured"] = false
				meta["reason"] = "below_fast_roll"
			else:
				var pour_r: float = float(part.params.get("pour_radius_m", 6.0)) * scale
				var ttl_s: float = float(part.params.get("ttl_s", 6.0))
				var r_slag: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, origin, pour_r, src_base, scale, ttl_s)
				)
				reactions.append_array(r_slag["reactions"])
				var r_burn: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_BURNING, origin, pour_r * 0.85, _source_tag_for(part.id, "fire"), scale, ttl_s * 0.7)
				)
				reactions.append_array(r_burn["reactions"])
				meta["poured"] = true
				meta["pour_radius_m"] = pour_r

		&"ledger_siphon_bolt":
			var dmg: float = float(part.params.get("siphon_damage", 28.0)) * scale
			var siphoned_tag := &""
			var bridged_sources: Array[String] = []
			for z in env_tags.zones_at(origin, 4.5):
				if part.consumes_tag(z["tag"]):
					if siphoned_tag == &"":
						siphoned_tag = z["tag"]
					bridged_sources.append(String(z.get("source_id", "")))
			var targets: Array = _sort_targets_near(ctx.get("targets", []), origin, 24.0)
			if not targets.is_empty():
				var target_pos: Vector3 = targets[0]["pos"]
				chain_hits.append({
					"target_id": String(targets[0]["id"]),
					"pos": target_pos,
					"damage": dmg,
					"hop": 1,
					"siphoned_tag": siphoned_tag,
					"source": &"requisition_leech",
				})
				if siphoned_tag != &"":
					var r_siph: Dictionary = env_tags.apply_tag(
						EnvTags.make_payload(siphoned_tag, target_pos, 3.5, src_base, scale, 3.5)
					)
					reactions.append_array(r_siph["reactions"])
			meta["siphoned_tag"] = siphoned_tag
			meta["bridged_sources"] = bridged_sources
			meta["bonus_scrap"] = int(part.params.get("bonus_scrap", 2))
			meta["aggro_ping_radius_m"] = float(part.params.get("aggro_ping_radius_m", 22.0))

		&"thermite_reaction_whip":
			var whip_r: float = float(part.params.get("whip_radius_m", 5.2)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 3.5))
			heft_bonus_tiers = maxi(heft_bonus_tiers, int(part.params.get("heft_bonus_tiers", 1)))
			heft_bonus_left_s = maxf(heft_bonus_left_s, 3.0)
			var r_burn: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_BURNING, origin, whip_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_burn["reactions"])
			meta["heft_bonus_tiers"] = heft_bonus_tiers

		&"caustic_auger_spray":
			var target_pos: Vector3 = ctx.get("target_pos", origin + dir * 5.0)
			var spray_r: float = float(part.params.get("corrosive_radius_m", 6.8)) * scale
			var auger_dmg: float = float(part.params.get("auger_damage", 22.0)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 4.8))
			if speed < STALL_SPEED_MPS:
				heat_delta += float(part.params.get("stall_overpressure_heat", 8.0))
			var bridged_sources: Array[String] = []
			var primed := false
			for z in env_tags.zones_at(target_pos, spray_r):
				if part.consumes_tag(z["tag"]):
					bridged_sources.append(String(z.get("source_id", "")))
					primed = true
			var r_wet: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_SOAKED_CONDUCTIVE, target_pos, spray_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_wet["reactions"])
			var r_slag: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_SLAG_COATED, target_pos, spray_r * 0.85, _source_tag_for(part.id, "slag"), scale, ttl_s)
			)
			reactions.append_array(r_slag["reactions"])
			var sorted_targets := _sort_targets_near(ctx.get("targets", []), target_pos, spray_r)
			var hits_max := mini(2 + heat_chain_bonus(), sorted_targets.size())
			var dmg_mult := 1.35 if primed else 1.0
			for h in hits_max:
				var t_entry: Dictionary = sorted_targets[h]
				chain_hits.append({
					"target_id": String(t_entry["id"]),
					"pos": t_entry["pos"],
					"damage": auger_dmg * dmg_mult * pow(0.88, float(h)),
					"hop": h + 1,
					"source": &"caustic_auger_spray",
				})
			meta["primed"] = primed
			meta["bridged_sources"] = bridged_sources

		&"harmonic_lance_beam":
			var target_pos: Vector3 = ctx.get("target_pos", origin + dir * 6.5)
			var min_speed: float = float(part.params.get("min_speed_mps", 10.0))
			var fast_enough := speed >= min_speed
			if not fast_enough:
				heat_delta += float(part.params.get("slow_bleed_heat", 6.0))
			var lance_r: float = float(part.params.get("lance_radius_m", 9.0)) * scale * (1.0 if fast_enough else 0.5)
			var base_hops: int = int(part.params.get("base_hops", 3)) + heat_chain_bonus()
			var lance_dmg: float = float(part.params.get("lance_damage", 20.0)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 3.5))
			var bridged_sources: Array[String] = []
			var bridged := false
			for z in env_tags.zones_at(target_pos, lance_r):
				if part.consumes_tag(z["tag"]):
					bridged_sources.append(String(z.get("source_id", "")))
					bridged = true
			var r_elec: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, target_pos, lance_r * 0.8, src_base, scale, ttl_s)
			)
			reactions.append_array(r_elec["reactions"])
			var sorted_targets := _sort_targets_near(ctx.get("targets", []), target_pos, lance_r)
			var hops := mini(base_hops if bridged else 1, sorted_targets.size())
			for h in hops:
				var t_entry: Dictionary = sorted_targets[h]
				chain_hits.append({
					"target_id": String(t_entry["id"]),
					"pos": t_entry["pos"],
					"damage": lance_dmg * (1.3 if bridged else 1.0) * pow(0.86, float(h)),
					"hop": h + 1,
					"source": &"harmonic_lance_beam",
				})
			meta["bridged"] = bridged
			meta["fast_enough"] = fast_enough
			meta["hops_allowed"] = base_hops
			meta["bridged_sources"] = bridged_sources

		&"tremor_shock_slam":
			var min_speed: float = float(part.params.get("min_speed_mps", 10.0))
			var shock_r: float = float(part.params.get("shock_radius_m", 6.8)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 4.5))
			var bridged_sources: Array[String] = []
			for z in env_tags.zones_at(origin, shock_r):
				if part.consumes_tag(z["tag"]):
					bridged_sources.append(String(z.get("source_id", "")))
			var r_burn: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_BURNING, origin, shock_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_burn["reactions"])
			if speed >= min_speed:
				heft_bonus_tiers = maxi(heft_bonus_tiers, int(part.params.get("heft_bonus_tiers", 1)))
				heft_bonus_left_s = maxf(heft_bonus_left_s, 3.0)
				var r_mag: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_MAGNETIC, origin, shock_r * 0.9, _source_tag_for(part.id, "mag"), scale, ttl_s * 0.85)
				)
				reactions.append_array(r_mag["reactions"])
				meta["tremor_full"] = true
			else:
				meta["tremor_full"] = false
				meta["reason"] = "below_fast_roll"
			meta["heft_bonus_tiers"] = heft_bonus_tiers
			meta["bridged_sources"] = bridged_sources

		&"gale_cryo_slipstream":
			var segs: int = int(part.params.get("wake_segments", 3))
			var shear_r: float = float(part.params.get("shear_radius_m", 5.8)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 4.2))
			var dash_len: float = float(ctx.get("dash_length_m", 8.0))
			var bridged_sources: Array[String] = []
			for i in segs:
				var pt := origin + dir * (dash_len * float(i) / maxf(float(segs - 1), 1.0))
				for z in env_tags.zones_at(pt, shear_r):
					if part.consumes_tag(z["tag"]):
						bridged_sources.append(String(z.get("source_id", "")))
				var r_cryo: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, pt, shear_r, src_base, scale, ttl_s)
				)
				reactions.append_array(r_cryo["reactions"])
				if i == segs - 1:
					var r_mag: Dictionary = env_tags.apply_tag(
						EnvTags.make_payload(EnvTags.TAG_MAGNETIC, pt, shear_r * 0.95, _source_tag_for(part.id, "shear"), scale, ttl_s * 0.9)
					)
					reactions.append_array(r_mag["reactions"])
			meta["wake_segments"] = segs
			meta["speed_bonus_mps"] = float(part.params.get("speed_bonus_mps", 2.2)) * scale
			meta["bridged_sources"] = bridged_sources

		&"slurry_quench_manifold":
			var slurry_r: float = float(part.params.get("slurry_radius_m", 7.0)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 5.0))
			var bridged_sources: Array[String] = []
			for z in env_tags.zones_at(origin, slurry_r):
				if part.consumes_tag(z["tag"]):
					bridged_sources.append(String(z.get("source_id", "")))
			var r_cool: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_COOLANT_BRITTLE, origin, slurry_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_cool["reactions"])
			meta["quench_damage"] = float(part.params.get("quench_damage", 22.0)) * scale
			meta["slurry_radius_m"] = slurry_r
			meta["bridged_sources"] = bridged_sources

		&"capacitor_shunt_discharge":
			var shunt_r: float = float(part.params.get("shunt_radius_m", 6.5)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 3.2))
			var shunt_dmg: float = float(part.params.get("shunt_damage", 18.0)) * scale
			var base_hops: int = int(part.params.get("base_hops", 2)) + heat_chain_bonus()
			var bridged_sources: Array[String] = []
			for z in env_tags.zones_at(origin, shunt_r):
				if part.consumes_tag(z["tag"]):
					bridged_sources.append(String(z.get("source_id", "")))
			var r_elec: Dictionary = env_tags.apply_tag(
				EnvTags.make_payload(EnvTags.TAG_ELECTRIFIED, origin, shunt_r, src_base, scale, ttl_s)
			)
			reactions.append_array(r_elec["reactions"])
			var sorted_targets := _sort_targets_near(ctx.get("targets", []), origin, shunt_r * 1.35)
			var hops := mini(base_hops, sorted_targets.size())
			for h in hops:
				var t_entry: Dictionary = sorted_targets[h]
				chain_hits.append({
					"target_id": String(t_entry["id"]),
					"pos": t_entry["pos"],
					"damage": shunt_dmg * pow(0.85, float(h)),
					"hop": h + 1,
					"source": &"capacitor_shunt_discharge",
				})
			meta["hops_allowed"] = base_hops
			meta["bridged_sources"] = bridged_sources

		_:
			var radius_m: float = float(part.params.get("radius_m", 5.0)) * scale
			var ttl_s: float = float(part.params.get("ttl_s", 4.0))
			var emit_pos: Vector3 = ctx.get("anchor_pos", origin)
			for tag in part.emits_tags:
				var res: Dictionary = env_tags.apply_tag(
					EnvTags.make_payload(tag, emit_pos, radius_m, src_base, scale, ttl_s)
				)
				reactions.append_array(res["reactions"])
			meta["generic_emitted"] = part.emits_tags.size()

	add_heat(heat_delta)
	return {
		"part_id": part.id,
		"effect_id": part.effect_id,
		"trigger": part.trigger,
		"heat_delta": heat_delta,
		"heat_after": heat,
		"overclock_scale": scale,
		"reactions": reactions,
		"chain_hits": chain_hits,
		"meta": meta,
	}


static func _sort_targets_near(targets: Array, origin: Vector3, max_radius: float) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var max_sq := max_radius * max_radius
	for t in targets:
		if not (t is Dictionary) or not t.has("pos"):
			continue
		var pos: Vector3 = t["pos"]
		var dsq := pos.distance_squared_to(origin)
		if dsq <= max_sq:
			found.append({"id": String(t.get("id", "")), "pos": pos, "dist_sq": dsq})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a["dist_sq"]
		var db: float = b["dist_sq"]
		if not is_equal_approx(da, db):
			return da < db
		return String(a["id"]) < String(b["id"])
	)
	return found
