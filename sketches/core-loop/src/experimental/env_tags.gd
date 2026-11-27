extends RefCounted


const Palette := preload("res://src/core/palette.gd")

signal tag_applied(payload: Dictionary)
signal reaction_triggered(event: Dictionary)

const TAG_ELECTRIFIED: StringName = &"electrified"
const TAG_BURNING: StringName = &"burning"
const TAG_SLAG_COATED: StringName = &"slag_coated"
const TAG_MAGNETIC: StringName = &"magnetic"
const TAG_COOLANT_BRITTLE: StringName = &"coolant_brittle"
const TAG_SOAKED_CONDUCTIVE: StringName = &"soaked_conductive"

const CANONICAL_TAGS: Array[StringName] = [
	TAG_ELECTRIFIED,
	TAG_BURNING,
	TAG_SLAG_COATED,
	TAG_MAGNETIC,
	TAG_COOLANT_BRITTLE,
	TAG_SOAKED_CONDUCTIVE,
]

const REQUIRED_PAYLOAD_KEYS: Array[String] = [
	"tag",
	"origin",
	"radius_m",
	"source_id",
	"intensity",
	"ttl_s",
]

const MAX_CASCADE_DEPTH := 2
const MAX_REACTIONS_PER_PASS := 12
const MAX_ACTIVE_ZONES := 64

const VISUAL_GRAMMAR := {
	TAG_ELECTRIFIED: {
		"color": Palette.ARC,
		"shape": "ring_bolt",
		"sound": "arc_crackle",
		"word": "Live current",
	},
	TAG_BURNING: {
		"color": Palette.COPPER,
		"shape": "starburst_ember",
		"sound": "forge_hiss",
		"word": "Hot slag flame",
	},
	TAG_SLAG_COATED: {
		"color": Palette.AMBER,
		"shape": "hex_puddle",
		"sound": "slag_bubble",
		"word": "Conductive slag",
	},
	TAG_MAGNETIC: {
		"color": Palette.COBALT,
		"shape": "bracket_flux",
		"sound": "coil_hum",
		"word": "Magnetic pull",
	},
	TAG_COOLANT_BRITTLE: {
		"color": Palette.ICE,
		"shape": "shard_crust",
		"sound": "cryo_tick",
		"word": "Brittle quench",
	},
	TAG_SOAKED_CONDUCTIVE: {
		"color": Color("548b84"),
		"shape": "ripple_pool",
		"sound": "sluice_wash",
		"word": "Wet conductor",
	},
}

const REACTIONS := {
	"electrified+slag_coated": {
		"id": &"conductive_arc_chain",
		"name": "Conductive Arc Chain",
		"damage_mult": 1.45,
		"base_damage": 22.0,
		"radius_m": 7.5,
		"chain_hops": 3,
		"consumes": [TAG_SLAG_COATED],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 6.0,
		"armor_shred": 0.0,
		"interrupts_tether": true,
		"summary": "Live current leaps across coated slag and jumps to nearby machines.",
	},
	"burning+coolant_brittle": {
		"id": &"thermal_shatter_steam",
		"name": "Thermal Shatter Steam",
		"damage_mult": 1.85,
		"base_damage": 30.0,
		"radius_m": 6.0,
		"chain_hops": 0,
		"consumes": [TAG_BURNING, TAG_COOLANT_BRITTLE],
		"emits_tag": TAG_SOAKED_CONDUCTIVE,
		"emits_ttl_s": 3.5,
		"emits_radius_m": 5.0,
		"knock_force": 10.0,
		"armor_shred": 0.5,
		"interrupts_tether": false,
		"summary": "Flash-boiled coolant shatters brittle plating and leaves conductive steam condensate.",
	},
	"electrified+magnetic": {
		"id": &"rail_surge",
		"name": "Rail Surge",
		"damage_mult": 1.55,
		"base_damage": 26.0,
		"radius_m": 7.0,
		"chain_hops": 2,
		"consumes": [TAG_MAGNETIC],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 18.0,
		"ball_boost_mps": 6.5,
		"armor_shred": 0.15,
		"interrupts_tether": true,
		"summary": "Magnetized current snaps metal targets inward and kicks the ball forward.",
	},
	"electrified+soaked_conductive": {
		"id": &"spillway_discharge",
		"name": "Spillway Discharge",
		"damage_mult": 1.5,
		"base_damage": 20.0,
		"radius_m": 8.0,
		"chain_hops": 2,
		"consumes": [TAG_SOAKED_CONDUCTIVE],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 5.0,
		"armor_shred": 0.0,
		"interrupts_tether": true,
		"summary": "Wet surfaces carry the arc across the lane and sever active tethers.",
	},
	"burning+slag_coated": {
		"id": &"molten_rekindle",
		"name": "Molten Rekindle",
		"damage_mult": 1.35,
		"base_damage": 18.0,
		"radius_m": 5.5,
		"chain_hops": 0,
		"consumes": [TAG_BURNING],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 4.0,
		"armor_shred": 0.35,
		"drops_shield": true,
		"interrupts_tether": false,
		"summary": "Flame re-liquefies slag pools, softening plated hulls and dropping shields.",
	},
	"coolant_brittle+slag_coated": {
		"id": &"quench_slag_crust",
		"name": "Quench Slag Crust",
		"damage_mult": 1.3,
		"base_damage": 16.0,
		"radius_m": 5.0,
		"chain_hops": 0,
		"consumes": [TAG_SLAG_COATED],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 0.0,
		"armor_shred": 0.35,
		"heft_tier_drop": 1,
		"interrupts_tether": false,
		"summary": "Rapid cooling hardens slag into brittle crust that breaks one heft tier lower.",
	},
	"burning+soaked_conductive": {
		"id": &"boiler_cloud",
		"name": "Boiler Cloud",
		"damage_mult": 1.2,
		"base_damage": 14.0,
		"radius_m": 5.5,
		"chain_hops": 0,
		"consumes": [TAG_BURNING, TAG_SOAKED_CONDUCTIVE],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 12.0,
		"armor_shred": 0.0,
		"interrupts_tether": false,
		"summary": "Boiled water erupts in a pressure ring that shoves stalled machines back.",
	},
	"coolant_brittle+magnetic": {
		"id": &"cryo_clamp",
		"name": "Cryo Clamp",
		"damage_mult": 1.35,
		"base_damage": 18.0,
		"radius_m": 5.0,
		"chain_hops": 0,
		"consumes": [TAG_MAGNETIC],
		"emits_tag": &"",
		"emits_ttl_s": 0.0,
		"emits_radius_m": 0.0,
		"knock_force": 0.0,
		"slow_factor": 0.45,
		"armor_shred": 0.2,
		"interrupts_tether": false,
		"summary": "Supercooled coils lock loose chassis joints and slow non-elite machines.",
	},
}

var _clock := 0.0
var _next_zone_id := 1
var _next_tag_serial := 1
var _zones: Array[Dictionary] = []
var _actors: Dictionary = {}
var _in_pass := false
var _active_queue: Array[Dictionary] = []
var _active_depth := 0
var _stats := {
	"applied": 0,
	"reactions": 0,
	"depth_capped": 0,
	"budget_capped": 0,
	"duplicate_refused": 0,
	"reentrant_queued": 0,
	"max_depth_seen": 0,
}


static func reset() -> void:
	pass


static func is_canonical_tag(tag: StringName) -> bool:
	return CANONICAL_TAGS.has(tag)


static func pair_key(a: StringName, b: StringName) -> String:
	var sa := String(a)
	var sb := String(b)
	return "%s+%s" % [sa, sb] if sa < sb else "%s+%s" % [sb, sa]


static func lookup_reaction(a: StringName, b: StringName) -> Dictionary:
	if a == b or not is_canonical_tag(a) or not is_canonical_tag(b):
		return {}
	return REACTIONS.get(pair_key(a, b), {})


static func make_payload(tag: StringName, origin: Vector3, radius_m: float, source_id: String,
		intensity: float = 1.0, ttl_s: float = 4.0) -> Dictionary:
	return {
		"tag": tag,
		"origin": origin,
		"radius_m": maxf(radius_m, 0.1),
		"source_id": source_id,
		"intensity": clampf(intensity, 0.0, 10.0),
		"ttl_s": maxf(ttl_s, 0.0),
	}


static func validate_payload(payload: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for key in REQUIRED_PAYLOAD_KEYS:
		if not payload.has(key):
			problems.append("missing key: %s" % key)
	if not problems.is_empty():
		return problems
	var tag: Variant = payload["tag"]
	if not (tag is StringName or tag is String) or not is_canonical_tag(StringName(tag)):
		problems.append("non-canonical tag: %s" % str(tag))
	if not (payload["origin"] is Vector3):
		problems.append("origin must be Vector3")
	if float(payload["radius_m"]) <= 0.0:
		problems.append("radius_m must be > 0")
	if String(payload["source_id"]).strip_edges() == "":
		problems.append("source_id must be non-empty")
	if float(payload["intensity"]) < 0.0:
		problems.append("intensity must be >= 0")
	if float(payload["ttl_s"]) < 0.0:
		problems.append("ttl_s must be >= 0")
	return problems


static func grammar_for(tag: StringName) -> Dictionary:
	return VISUAL_GRAMMAR.get(tag, {})


static func _emitter_base(source_id: String) -> String:
	var cut := source_id.find("#")
	var base := source_id.substr(0, cut) if cut >= 0 else source_id
	var arrow := base.find(">")
	return base.substr(0, arrow) if arrow >= 0 else base


static func _same_emitter(src_a: String, src_b: String) -> bool:
	if src_a == "" or src_b == "":
		return false
	return _emitter_base(src_a) == _emitter_base(src_b)


func clear() -> void:
	_clock = 0.0
	_next_zone_id = 1
	_next_tag_serial = 1
	_zones.clear()
	_actors.clear()
	_in_pass = false
	_active_queue.clear()
	_active_depth = 0
	_stats = {
		"applied": 0,
		"reactions": 0,
		"depth_capped": 0,
		"budget_capped": 0,
		"duplicate_refused": 0,
		"reentrant_queued": 0,
		"max_depth_seen": 0,
	}


func clock() -> float:
	return _clock


func stats() -> Dictionary:
	return _stats.duplicate(true)


func active_zone_count() -> int:
	return _zones.size()


func active_zones() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for z in _zones:
		out.append(z.duplicate(true))
	return out


func register_actor(actor_id: String, pos: Vector3, radius_m: float = 1.0, meta: Dictionary = {}) -> void:
	if actor_id == "":
		return
	var existing_tags: Dictionary = _actors[actor_id]["tags"] if _actors.has(actor_id) else {}
	_actors[actor_id] = {
		"id": actor_id,
		"pos": pos,
		"radius_m": maxf(radius_m, 0.1),
		"tags": existing_tags,
		"meta": meta.duplicate(true),
	}


func update_actor(actor_id: String, pos: Vector3) -> void:
	if _actors.has(actor_id):
		_actors[actor_id]["pos"] = pos


func unregister_actor(actor_id: String) -> void:
	_actors.erase(actor_id)


func actor_tags(actor_id: String) -> Array[StringName]:
	var out: Array[StringName] = []
	if not _actors.has(actor_id):
		return out
	var tags_map: Dictionary = _actors[actor_id]["tags"]
	for tag_name in CANONICAL_TAGS:
		if tags_map.has(tag_name) and float(tags_map[tag_name]["expires"]) > _clock:
			out.append(tag_name)
	return out


func actor_has_tag(actor_id: String, tag: StringName) -> bool:
	if not _actors.has(actor_id):
		return false
	var tags_map: Dictionary = _actors[actor_id]["tags"]
	return tags_map.has(tag) and float(tags_map[tag]["expires"]) > _clock


func actor_tag_serial(actor_id: String, tag: StringName) -> int:
	if not _actors.has(actor_id):
		return 0
	var tags_map: Dictionary = _actors[actor_id]["tags"]
	if not tags_map.has(tag) or float(tags_map[tag]["expires"]) <= _clock:
		return 0
	return int(tags_map[tag].get("serial", 0))


func zones_at(point: Vector3, radius_m: float = 0.0, tag_filter: StringName = &"") -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for z in _zones:
		if tag_filter != &"" and z["tag"] != tag_filter:
			continue
		var reach := float(z["radius_m"]) + maxf(radius_m, 0.0)
		var dist_sq := (z["origin"] as Vector3).distance_squared_to(point)
		if dist_sq <= reach * reach:
			hits.append({"zone": z, "dist_sq": dist_sq})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a["dist_sq"]
		var db: float = b["dist_sq"]
		if not is_equal_approx(da, db):
			return da < db
		return int(a["zone"]["zone_id"]) < int(b["zone"]["zone_id"])
	)
	var out: Array[Dictionary] = []
	for item in hits:
		out.append((item["zone"] as Dictionary).duplicate(true))
	return out


func tags_at(point: Vector3, radius_m: float = 0.0) -> Array[StringName]:
	var seen := {}
	for z in zones_at(point, radius_m):
		seen[z["tag"]] = true
	var out: Array[StringName] = []
	for tag_name in CANONICAL_TAGS:
		if seen.has(tag_name):
			out.append(tag_name)
	return out


func apply_tag(payload: Dictionary, target_actor_id: String = "", create_zone: bool = true) -> Dictionary:
	var problems := validate_payload(payload)
	if not problems.is_empty():
		return {"ok": false, "problems": problems, "reactions": [], "max_depth_reached": 0, "capped": false}

	var root_payload := make_payload(
		StringName(payload["tag"]),
		payload["origin"] as Vector3,
		float(payload["radius_m"]),
		String(payload["source_id"]),
		float(payload["intensity"]),
		float(payload["ttl_s"])
	)

	if _in_pass:
		var next_depth := _active_depth + 1
		_stats["reentrant_queued"] += 1
		if next_depth > MAX_CASCADE_DEPTH:
			_stats["depth_capped"] += 1
			return {"ok": true, "deferred": false, "capped": true, "reactions": [], "max_depth_reached": _active_depth}
		_active_queue.append({
			"payload": root_payload,
			"target_actor_id": target_actor_id,
			"create_zone": create_zone,
			"depth": next_depth,
		})
		return {"ok": true, "deferred": true, "capped": false, "reactions": [], "max_depth_reached": next_depth}

	_in_pass = true
	_active_queue = [{
		"payload": root_payload,
		"target_actor_id": target_actor_id,
		"create_zone": create_zone,
		"depth": 0,
	}]
	var reactions_out: Array[Dictionary] = []
	var emitted_zones: Array[int] = []
	var pass_resolved := {}
	var max_depth_reached := 0
	var capped := false

	while not _active_queue.is_empty():
		var item: Dictionary = _active_queue.pop_front()
		var depth: int = int(item["depth"])
		if depth > MAX_CASCADE_DEPTH:
			_stats["depth_capped"] += 1
			capped = true
			continue
		_active_depth = depth
		max_depth_reached = maxi(max_depth_reached, depth)
		_stats["max_depth_seen"] = maxi(int(_stats["max_depth_seen"]), depth)

		var p: Dictionary = item["payload"]
		var tag: StringName = p["tag"]
		var origin: Vector3 = p["origin"]
		var radius_m: float = float(p["radius_m"])
		var actor_id: String = String(item["target_actor_id"])
		var make_zone: bool = bool(item["create_zone"])

		_stats["applied"] += 1
		var step_reactions: Array[Dictionary] = []
		var consumed_incoming := false
		var budget_hit := false

		var zone_matches := _matching_zone_indices(origin, radius_m)
		var consumed_zone_ids := {}
		for idx in zone_matches:
			if idx >= _zones.size():
				continue
			var z: Dictionary = _zones[idx]
			if _same_emitter(String(p["source_id"]), String(z.get("source_id", ""))):
				continue
			var row := lookup_reaction(tag, z["tag"])
			if row.is_empty():
				continue
			var subject_key := "zone:%d" % int(z["zone_id"])
			var guard_key := "%s|%s" % [subject_key, String(row["id"])]
			if pass_resolved.has(guard_key):
				_stats["duplicate_refused"] += 1
				continue
			if reactions_out.size() >= MAX_REACTIONS_PER_PASS:
				_stats["budget_capped"] += 1
				capped = true
				budget_hit = true
				break
			pass_resolved[guard_key] = true
			var ev := _build_reaction_event(row, tag, z["tag"], origin.lerp(z["origin"], 0.5),
				p, subject_key, depth, "", String(z.get("source_id", "")))
			reactions_out.append(ev)
			step_reactions.append(ev)
			_stats["reactions"] += 1
			var consumes: Array = row.get("consumes", [])
			if consumes.has(z["tag"]):
				consumed_zone_ids[int(z["zone_id"])] = true
			if consumes.has(tag):
				consumed_incoming = true
			_enqueue_derived(_active_queue, row, ev, p, depth)

		if not consumed_zone_ids.is_empty():
			var kept: Array[Dictionary] = []
			for z in _zones:
				if not consumed_zone_ids.has(int(z["zone_id"])):
					kept.append(z)
			_zones = kept

		var actor_ids: Array[String] = []
		if not budget_hit:
			actor_ids = _matching_actor_ids(origin, radius_m, actor_id)
		for aid in actor_ids:
			var actor: Dictionary = _actors[aid]
			var tags_map: Dictionary = actor["tags"]
			var existing_tags := actor_tags(aid)
			var actor_consumed_incoming := false
			for existing in existing_tags:
				var existing_src := String(tags_map.get(existing, {}).get("source_id", ""))
				if _same_emitter(String(p["source_id"]), existing_src):
					continue
				var row := lookup_reaction(tag, existing)
				if row.is_empty():
					continue
				var subject_key := "actor:%s" % aid
				var guard_key := "%s|%s" % [subject_key, String(row["id"])]
				if pass_resolved.has(guard_key):
					_stats["duplicate_refused"] += 1
					continue
				if reactions_out.size() >= MAX_REACTIONS_PER_PASS:
					_stats["budget_capped"] += 1
					capped = true
					budget_hit = true
					break
				pass_resolved[guard_key] = true
				var ev := _build_reaction_event(row, tag, existing, actor["pos"], p, subject_key, depth, aid, existing_src)
				reactions_out.append(ev)
				step_reactions.append(ev)
				_stats["reactions"] += 1
				var consumes: Array = row.get("consumes", [])
				if consumes.has(existing):
					tags_map.erase(existing)
				if consumes.has(tag):
					actor_consumed_incoming = true
				_enqueue_derived(_active_queue, row, ev, p, depth)
			if not actor_consumed_incoming and float(p["ttl_s"]) > 0.0:
				var serial := _next_tag_serial
				_next_tag_serial += 1
				tags_map[tag] = {
					"expires": _clock + float(p["ttl_s"]),
					"intensity": float(p["intensity"]),
					"source_id": String(p["source_id"]),
					"serial": serial,
				}
			if budget_hit:
				break

		if make_zone and actor_id == "" and not consumed_incoming and float(p["ttl_s"]) > 0.0:
			var zid := _store_zone(p)
			emitted_zones.append(zid)

		tag_applied.emit(p.duplicate(true))
		for ev in step_reactions:
			reaction_triggered.emit(ev.duplicate(true))

		if budget_hit:
			_active_queue.clear()
			break

	_active_queue.clear()
	_active_depth = 0
	_in_pass = false

	return {
		"ok": true,
		"reactions": reactions_out,
		"max_depth_reached": max_depth_reached,
		"capped": capped,
		"emitted_zones": emitted_zones,
	}


func step(dt: float) -> void:
	if dt <= 0.0:
		return
	_clock += dt
	var alive_zones: Array[Dictionary] = []
	for z in _zones:
		z["ttl_s"] = float(z["ttl_s"]) - dt
		if float(z["ttl_s"]) > 0.0:
			alive_zones.append(z)
	_zones = alive_zones
	for aid in _actors:
		var tags_map: Dictionary = _actors[aid]["tags"]
		for tag_name in tags_map.keys():
			if float(tags_map[tag_name]["expires"]) <= _clock:
				tags_map.erase(tag_name)


func _store_zone(p: Dictionary) -> int:
	for z in _zones:
		if z["tag"] == p["tag"] and (z["origin"] as Vector3).distance_to(p["origin"] as Vector3) <= float(z["radius_m"]) * 0.5:
			z["ttl_s"] = maxf(float(z["ttl_s"]), float(p["ttl_s"]))
			z["intensity"] = maxf(float(z["intensity"]), float(p["intensity"]))
			z["radius_m"] = maxf(float(z["radius_m"]), float(p["radius_m"]))
			return int(z["zone_id"])
	while _zones.size() >= MAX_ACTIVE_ZONES:
		_zones.pop_front()
	var zid := _next_zone_id
	_next_zone_id += 1
	var entry := p.duplicate(true)
	entry["zone_id"] = zid
	_zones.append(entry)
	return zid


func _matching_zone_indices(origin: Vector3, radius_m: float) -> Array[int]:
	var pairs: Array[Dictionary] = []
	for i in _zones.size():
		var z: Dictionary = _zones[i]
		var reach := float(z["radius_m"]) + radius_m
		var dist_sq := (z["origin"] as Vector3).distance_squared_to(origin)
		if dist_sq <= reach * reach:
			pairs.append({"idx": i, "dist_sq": dist_sq, "zone_id": int(z["zone_id"])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a["dist_sq"]
		var db: float = b["dist_sq"]
		if not is_equal_approx(da, db):
			return da < db
		return int(a["zone_id"]) < int(b["zone_id"])
	)
	var out: Array[int] = []
	for item in pairs:
		out.append(int(item["idx"]))
	return out


func _matching_actor_ids(origin: Vector3, radius_m: float, explicit_actor_id: String) -> Array[String]:
	var out: Array[String] = []
	if explicit_actor_id != "":
		if _actors.has(explicit_actor_id):
			out.append(explicit_actor_id)
		return out
	var pairs: Array[Dictionary] = []
	for aid in _actors:
		var actor: Dictionary = _actors[aid]
		var reach := radius_m + float(actor["radius_m"])
		var dist_sq := (actor["pos"] as Vector3).distance_squared_to(origin)
		if dist_sq <= reach * reach:
			pairs.append({"id": String(aid), "dist_sq": dist_sq})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = a["dist_sq"]
		var db: float = b["dist_sq"]
		if not is_equal_approx(da, db):
			return da < db
		return String(a["id"]) < String(b["id"])
	)
	for item in pairs:
		out.append(String(item["id"]))
	return out


func _build_reaction_event(row: Dictionary, incoming: StringName, existing: StringName,
		at: Vector3, payload: Dictionary, subject_key: String, depth: int, actor_id: String = "",
		existing_source_id: String = "") -> Dictionary:
	var intensity := float(payload["intensity"])
	return {
		"reaction_id": row["id"],
		"name": row["name"],
		"pair": pair_key(incoming, existing),
		"incoming_tag": incoming,
		"existing_tag": existing,
		"origin": at,
		"radius_m": float(row["radius_m"]),
		"damage": float(row["base_damage"]) * float(row["damage_mult"]) * maxf(0.5, intensity),
		"damage_mult": float(row["damage_mult"]),
		"chain_hops": int(row.get("chain_hops", 0)),
		"knock_force": float(row.get("knock_force", 0.0)),
		"ball_boost_mps": float(row.get("ball_boost_mps", 0.0)),
		"armor_shred": float(row.get("armor_shred", 0.0)),
		"slow_factor": float(row.get("slow_factor", 1.0)),
		"heft_tier_drop": int(row.get("heft_tier_drop", 0)),
		"drops_shield": bool(row.get("drops_shield", false)),
		"interrupts_tether": bool(row.get("interrupts_tether", false)),
		"source_id": String(payload["source_id"]),
		"existing_source_id": existing_source_id,
		"subject_key": subject_key,
		"actor_id": actor_id,
		"depth": depth,
	}


func _enqueue_derived(queue: Array[Dictionary], row: Dictionary, ev: Dictionary,
		parent_payload: Dictionary, depth: int) -> void:
	var derived_tag: StringName = row.get("emits_tag", &"")
	if derived_tag == &"":
		return
	var next_depth := depth + 1
	if next_depth > MAX_CASCADE_DEPTH:
		_stats["depth_capped"] += 1
		return
	var derived_payload := make_payload(
		derived_tag,
		ev["origin"] as Vector3,
		float(row.get("emits_radius_m", 4.5)),
		"%s>%s" % [String(parent_payload["source_id"]), String(row["id"])],
		clampf(float(parent_payload["intensity"]) * 0.85, 0.25, 10.0),
		float(row.get("emits_ttl_s", 3.0))
	)
	queue.append({
		"payload": derived_payload,
		"target_actor_id": "",
		"create_zone": true,
		"depth": next_depth,
	})
