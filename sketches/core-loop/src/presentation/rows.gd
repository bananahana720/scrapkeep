extends RefCounted

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Roster := preload("res://src/combat/roster.gd")
const EventJuice := preload("res://src/presentation/event_juice.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")


const FALLBACK := {
	"beacon_unsealed": {"group": "flow", "color": Palette.ARC, "shape": "star", "sound": "stinger_unseal", "priority": 3},
	"heft_class_changed": {"group": "economy", "color": Palette.AMBER, "shape": "star", "sound": "class_up", "priority": 3},
	"scrap_lost": {"group": "economy", "color": Palette.RUST, "shape": "cross", "sound": "scrap_rip", "priority": 2},
	"strike_deflected": {"group": "combat", "color": Palette.SAND, "shape": "square", "sound": "clank", "priority": 1},
	"threat_rose": {"group": "event", "color": Palette.RUST, "shape": "chevron", "sound": "threat_up", "priority": 2},
	"core_gained": {"group": "economy", "color": Palette.AMBER, "shape": "diamond", "sound": "core_socket", "priority": 2},
	"synergy_discovered": {"group": "economy", "color": Palette.ARC, "shape": "star", "sound": "synergy_fanfare", "priority": 3},
	"interaction_found": {"group": "event", "color": Palette.SAND, "shape": "diamond", "sound": "found_chime", "priority": 2},
	"element_resolved": {"group": "event", "color": Palette.ARC, "shape": "burst", "sound": "element_resolved", "priority": 1},
}

const ELEMENT_SOUNDS := {"freeze": "ice_form", "ice": "ice_form", "frost": "ice_form", "chill": "ice_form",
	"electr": "zap_hum", "zap": "zap_hum", "arc": "zap_hum", "shock": "zap_hum", "charge": "zap_hum",
	"shatter": "shatter", "break": "shatter", "crack": "shatter"}


const WEIGHT := {
	"none": {"stop_ms": 0.0, "shake": 0.0, "kick": 0.0, "punch_fov": 0.0, "fx_scale": 0.8, "body": "", "body_st": 0.0},
	"hit": {"stop_ms": "hit", "shake": 0.1, "kick": 0.1, "punch_fov": 0.0, "fx_scale": 1.0, "body": "", "body_st": 0.0},
	"heavy": {"stop_ms": "heavy", "shake": 0.3, "kick": 0.45, "punch_fov": -4.0, "fx_scale": 1.4, "body": "womp", "body_st": 0.0},
	"massive": {"stop_ms": 55.0, "shake": 0.4, "kick": 0.6, "punch_fov": -6.0, "fx_scale": 1.9, "body": "chunk_low", "body_st": -12.0},
	"climax": {"stop_ms": 60.0, "shake": 0.5, "kick": 0.6, "punch_fov": 9.0, "fx_scale": 2.5, "body": "chunk_low", "body_st": -17.0},
}

const WEIGHTED := {
	"enemy_struck": {"rule": "strike", "allegiance": "player", "visual": ""},
	"enemy_killed": {"rule": "death_parts", "allegiance": "player", "visual": ""},
	"gauge_released": {"rule": "gauge", "allegiance": "player", "visual": ""},
	"player_hit": {"rule": "amount", "allegiance": "hostile", "visual": ""},
	"posture_changed": {"rule": "posture", "allegiance": "player", "visual": "spark_core"},
	"posture_break": {"class": "massive", "allegiance": "player", "visual": "spark_core"},
	"ultimate_landed": {"class": "massive", "allegiance": "player", "visual": ""},
	"boss_defeated": {"class": "climax", "allegiance": "player", "visual": ""},
	"boss_weak_point_hit": {"class": "heavy", "allegiance": "player", "visual": ""},
	"player_died": {"class": "massive", "allegiance": "hostile", "visual": ""},
	"slammed": {"class": "heavy", "allegiance": "player", "visual": ""},
	"sticky_detonated": {"class": "heavy", "allegiance": "player", "visual": ""},
	"enemy_rebounded": {"class": "heavy", "allegiance": "player", "visual": ""},
	"cloak_broken": {"class": "hit", "allegiance": "player", "visual": ""},
	"hold_broken": {"class": "hit", "allegiance": "player", "visual": ""},
	"swarm_scattered": {"class": "hit", "allegiance": "player", "visual": ""},
	"enemy_pinned": {"class": "hit", "allegiance": "player", "visual": ""},
	"enemy_ringed_out": {"class": "heavy", "allegiance": "player", "visual": ""},
	"arc_slammed": {"class": "none", "allegiance": "player", "visual": ""},
	"skid_smashed": {"class": "none", "allegiance": "player", "visual": ""},
	"demo_slammed": {"class": "none", "allegiance": "player", "visual": ""},
	"cloak_started": {"class": "none", "allegiance": "player", "visual": ""},
	"sprint_started": {"class": "none", "allegiance": "motion", "visual": ""},
	"cc_ignored": {"class": "none", "allegiance": "player", "visual": ""},
	"blink_used": {"class": "none", "allegiance": "motion", "visual": ""},
	"vault_kicked": {"class": "none", "allegiance": "motion", "visual": ""},
}

const WEIGHT_EXEMPT := {
	"line_skill_fired": "The line skill's bite; its landed strike is enemy_struck.",
	"active_fired": "The active's launch cue; its landed strikes are enemy_struck.",
	"active_heat": "A building heat tick under the active's sound row; it lands no hit, its cut is enemy_struck.",
	"achievement_earned": "Reward and economy ladders own the cue; rewards never stop time.",
	"activity_done": "World, interaction and activity rows own their contextual glyph and sound.",
	"ambush_ended": "World, interaction and activity rows own their contextual glyph and sound.",
	"bay_entered": "World, interaction and activity rows own their contextual glyph and sound.",
	"bay_left": "World, interaction and activity rows own their contextual glyph and sound.",
	"beacon_charge_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"beacon_unsealed": "The beacon is a reward with no stop; the breaking strike is posture_break.",
	"bet_resolved": "World, interaction and activity rows own their contextual glyph and sound.",
	"boosted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"boss_arena_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"boss_attack_telegraphed": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"boss_phase_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"boss_reeled": "Reward and economy ladders own the cue; rewards never stop time. Its strike is enemy_struck.",
	"cause_armed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"cause_fired": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"cogs_collected": "Reward and economy ladders own the cue; rewards never stop time.",
	"consumable_used": "Consumable slots own their cue; the bus signal carries item hooks only.",
	"core_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"dashed": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"dismounted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"element_resolved": "World, interaction and activity rows own their contextual glyph and sound.",
	"enemy_spawned": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_announced": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_ended": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_progress": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"event_started": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"flow_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"gauge_cancelled": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"gauge_charging": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"grapple_fired": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"grapple_released": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"harpoon_bit": "Latch feedback owns its dedicated stop and glyph; damage is weighted through enemy_struck.",
	"harpoon_smashed": "Harpoon contact owns its latch glyph; damage is weighted through enemy_struck.",
	"heft_class_changed": "Reward and economy ladders own the cue; rewards never stop time.",
	"heft_class_dropped": "Reward and economy ladders own the cue; rewards never stop time.",
	"hold_ended": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"hold_started": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"interact_armed": "World, interaction and activity rows own their contextual glyph and sound.",
	"interact_fired": "World, interaction and activity rows own their contextual glyph and sound.",
	"interaction_found": "World, interaction and activity rows own their contextual glyph and sound.",
	"jumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"landed": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"bumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"enemy_walled": "A thrown body stopped by a wall deals no damage; its thud, dust and stagger are juice.gd's and enemy.gd's.",
	"launched": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"line_skill_loaded": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"line_state_changed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"milestone_won": "Reward and economy ladders own the cue; rewards never stop time.",
	"mind_adapted": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"mounted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"near_miss": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"pack_arrived": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"part_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"panel_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"pressure_changed": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"rescue_completed": "Reward and economy ladders own the cue; rewards never stop time.",
	"reward_chosen": "Reward and economy ladders own the cue; rewards never stop time.",
	"reward_offered": "Reward and economy ladders own the cue; rewards never stop time.",
	"rocket_jumped": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"run_ended": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"run_started": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"scrap_collected": "Reward and economy ladders own the cue; rewards never stop time.",
	"scrap_lost": "Reward and economy ladders own the cue; rewards never stop time.",
	"shield_vaulted": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"carved": "Ball motion preserves momentum; its existing camera and cue profile owns it.",
	"shot_fired": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"special_used": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"stage_cleared": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"stage_content_cleared": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"stage_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"strike_deflected": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"synergy_discovered": "Reward and economy ladders own the cue; rewards never stop time.",
	"tenacity_gained": "Reward and economy ladders own the cue; rewards never stop time.",
	"threat_rose": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"tree_offered": "Reward and economy ladders own the cue; rewards never stop time.",
	"tree_picked": "Reward and economy ladders own the cue; rewards never stop time.",
	"ultimate_cancelled": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"special_broken": "Achievement facts own no impact; the earned toast is the cue.",
	"radio_take_found": "Achievement facts own no impact; the earned toast is the cue.",
	"relay_stake_paid": "Achievement facts own no impact; the earned toast is the cue.",
	"maker_set_completed": "Achievement facts own no impact; the earned toast is the cue.",
	"overflow_cashed": "Achievement facts own no impact; the earned toast is the cue.",
	"trade_taken": "World, interaction and activity rows own their contextual glyph and sound.",
	"ultimate_peak": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"ultimate_ready": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"ultimate_started": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"vent_charging": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"vent_erupted": "Hostile floor eruption owns its danger geometry and reactor cue; it never shakes, kicks or stops the screen.",
	"verb_failed": "The verb or ability grammar owns this cue; its landed strike is enemy_struck.",
	"warden_engaged": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"warden_sighted": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"weak_point_opened": "Threat, windup and floor cues keep their committed geometry and sound; impact must not restyle them.",
	"world_entered": "Run and stage lifecycle owns music and cleanup, not an impact.",
	"world_fact": "World, interaction and activity rows own their contextual glyph and sound.",
}


static func row(kind: String) -> Dictionary:
	if EventKinds.has(kind):
		return EventKinds.row(kind)
	for table in [EventKinds.UI_ROWS, EventKinds.LOOT_ROWS, EventKinds.WORLD_ROWS, FALLBACK]:
		if table.has(kind):
			return table[kind]
	return {}


static func sound(kind: String, context := {}) -> String:
	return heard(row(kind), context)


static func heard(entry: Dictionary, context := {}) -> String:
	var next := resolve(String(entry.get("sound_next", "")), context)
	if next != "" and SfxBank.has_recipe(next):
		return next
	return resolve(String(entry.get("sound", "")), context)


static func resolve(id: String, context := {}) -> String:
	var motif := String(context.get("motif", ""))
	match id:
		"class_motif":
			return _baked(motif + "_ready") if motif != "" else ""
		"class_break":
			return _baked(motif + "_break") if motif != "" else ""
		"motif_release":
			return release_of(motif)
		"hold_by_kind":
			return hold_of(String(context.get("hold", "")))
		"faction_arrival":
			if not context.has("faction"):
				return ""
			return Roster.voiced(String(Roster.faction(String(context["faction"]))["arrival"]), motif)
		"mind_quote":
			return Roster.voiced(id, motif) if motif != "" else ""
		"motif_accumulate", "motif_line", "motif_stinger":
			return SfxBank.motif_cue_id(id, motif) if motif != "" else id
	return id


static func _baked(id: String) -> String:
	return id if SfxBank.has_recipe(id) else ""


static func release_of(motif: String) -> String:
	var found := releases(motif)
	return found[0] if found.size() == 1 else ""


static func releases(motif: String) -> Array:
	var found: Array = []
	if motif == "":
		return found
	var named := _named_by_rows()
	for id in SfxBank.TRIM_DB:
		if id.begins_with(motif + "_") and not id in [motif + "_ready", motif + "_break"] and not id in named:
			found.append(id)
	return found


static func _named_by_rows() -> Array:
	var named: Array = []
	for table in (EventKinds as GDScript).get_script_constant_map().values():
		if not table is Dictionary:
			continue
		for row in table.values():
			if row is Dictionary:
				named.append(String(row.get("sound_next", "")))
				named.append(String(row.get("sound", "")))
	return named


static func hold_of(kind: String) -> String:
	for id in Roster.ROWS:
		var unit: Dictionary = Roster.ROWS[id]
		if unit["mechanic"] != kind:
			continue
		for candidate in [String(unit.get("hold", "")), String(unit.get("tag", ""))]:
			if candidate.begins_with("hold_") and SfxBank.has_recipe(candidate):
				return candidate
		return String(unit.get("hold", ""))
	return ""


static func priority(kind: String) -> int:
	return int(row(kind).get("priority", 1))


static func color(kind: String) -> Color:
	return row(kind).get("color", Palette.SAND)


static func shape(kind: String) -> String:
	return String(row(kind).get("shape", "none"))


static func element_sound(behaviour: String) -> String:
	var lowered := behaviour.to_lower()
	for key in ELEMENT_SOUNDS:
		if lowered.contains(key):
			return ELEMENT_SOUNDS[key]
	return "element_resolved"


static func sound_ids() -> Array:
	var ids := []
	for kind in EventKinds.ROWS:
		var id: String = EventKinds.ROWS[kind]["sound"]
		if not id in ids:
			ids.append(id)
	for kind in FALLBACK:
		var id: String = FALLBACK[kind]["sound"]
		if not id in ids:
			ids.append(id)
	for id in ["ice_form", "zap_hum", "shatter", "class_down"]:
		if not id in ids:
			ids.append(id)
	return ids


static func weigh(fact: String, args: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = WEIGHTED.get(fact, {})
	var weight := String(entry.get("class", "none"))
	var strength := 1.0
	var damage := maxf(float(args.get("damage", args.get("force", 0.0))), 0.0)
	match String(entry.get("rule", "")):
		"strike":
			weight = String(EventKinds.impact(String(args.get("kind", "")))["stop"])
			strength = damage / 30.0
		"death_parts":
			var kind := String(args.get("kind", ""))
			var parts := int(WindupRows.ROWS.get(kind, {}).get("death", {}).get("parts", 4))
			weight = "climax" if kind == "warden" else ("massive" if parts >= 8 else ("heavy" if parts >= 5 else "hit"))
		"gauge":
			strength = float(args.get("fraction", 0.0))
			weight = "heavy" if strength >= 1.0 else "hit"
		"amount":
			var amount := float(args.get("amount", 0.0))
			weight = "massive" if amount >= 20.0 else ("heavy" if amount >= 10.0 else "hit")
			strength = amount / 25.0
		"posture":
			var lost := maxi(int(args.get("chunks_lost", 0)), 0)
			weight = "massive" if bool(args.get("staggered", false)) else ("heavy" if lost > 0 else "none")
			if lost > 0:
				strength = float(lost) / BossPosture.CHUNKS
	strength = clampf(float(args.get("strength", strength)), 0.0, 1.0)
	var profile: Dictionary = WEIGHT[weight]
	var allegiance := String(entry.get("allegiance", "motion" if String(EventKinds.ROWS.get(fact, {}).get("group", "")) == "movement" or fact == "launched" else "reward"))
	var stop := 0.0
	if profile.stop_ms is String:
		stop = EventJuice.stop_ms_for(damage, bool(args.get("crit", false)), profile.stop_ms == "heavy")
	else:
		stop = float(profile.stop_ms)
	return {
		"fact": fact, "weight": weight, "allegiance": allegiance, "strength": strength,
		"stop_ms": stop if allegiance == "player" else 0.0,
		"shake": 0.0 if allegiance == "hostile" else float(profile.shake) * strength,
		"kick": 0.0 if allegiance == "hostile" else float(profile.kick) * strength,
		"punch_fov": float(profile.punch_fov) * strength, "fx_scale": float(profile.fx_scale),
		"body": String(profile.body), "body_ratio": pow(2.0, float(profile.body_st) / 12.0), "body_db": 0.0,
		"visual": String(entry.get("visual", "")), "sound": sound(fact),
	}
