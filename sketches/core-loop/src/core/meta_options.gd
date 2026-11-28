extends RefCounted

const WordBudget := preload("res://src/core/word_budget.gd")

const KINDS := ["option", "discovery", "pocket_key"]
const FIELDS := ["name", "text", "kind", "effect", "grant"]
const BANNED_KEY_WORDS := ["price", "cost", "stat", "discount", "cogs", "currency", "hp_bonus", "damage_bonus"]
const OVERRIDE_FIELDS := ["name", "text", "upside", "downside", "downside_text", "unlock"]
const ALT_FIELDS := ["pilot", "slot", "relic", "swap", "name", "text", "unlock"]
const CAMP_OVERRIDES_KEY := "meta_overrides"
const CAMP_ALT_LOADOUTS_KEY := "alt_loadouts"
const ORDER_SETTLE_PREFIX := "order:"
const MAX_GRANT_COUNT := 10
const NAME_WORDS := 3
const TEXT_WORDS := 12

const ROWS := {
	"spare_reroll": {"name": "Spare Reroll", "text": "One extra reroll at each shelf.",
		"kind": "option", "effect": "extra_reroll", "grant": "ach_meta_spare_reroll"},
	"shelf_preview": {"name": "Shelf Preview", "text": "See the next shelf's offers before you reach it.",
		"kind": "option", "effect": "shelf_preview", "grant": "ach_meta_shelf_preview"},
	"pocket_key": {"name": "Pocket Key", "text": "Sealed pockets open for you on later runs.",
		"kind": "pocket_key", "effect": "pocket_key", "grant": "ach_meta_pocket_key"},
	"pocket_tint": {"name": "Pocket Tint", "text": "A seen pocket door tints its zone on the map.",
		"kind": "discovery", "effect": "pocket_tint", "grant": "ach_meta_pocket_tint"},
}

const OVERRIDE_CODES := {
	"code_glass_rail": {
		"name": "Glass Rail",
		"text": "Double hit and smash force. Hull is cut in half.",
		"upside": "impact_force_2x",
		"downside": "hull_half",
		"downside_text": "Hull is cut in half.",
		"unlock": {"order": "wo_sable_3", "or_earned": "waking_stilled"},
	},
	"code_single_docket": {
		"name": "Single Docket",
		"text": "Shelves roll your pinned maker. Foreman kindness kiosks stay shut.",
		"upside": "maker_focused_shelves",
		"downside": "kindness_sealed",
		"downside_text": "Foreman kindness kiosks stay shut.",
		"unlock": {"order": "wo_rivet_3"},
	},
	"code_full_roster": {
		"name": "Full Roster",
		"text": "Every pack spawns elite frames. Wardens offer one extra cobalt.",
		"upside": "warden_extra_cobalt",
		"downside": "all_packs_elite",
		"downside_text": "Every pack spawns elite frames.",
		"unlock": {"order": "wo_tarn_3"},
	},
	"code_cut_governor": {
		"name": "Cut Governor",
		"text": "Launch at cruise with air jump refill. Stopping drains hull.",
		"upside": "cruise_launch_air_reset",
		"downside": "stall_drains_hull",
		"downside_text": "Stopping drains hull.",
		"unlock": {"order": "wo_kest_3"},
	},
	"code_open_manifest": {
		"name": "Open Manifest",
		"text": "Downed machines and walls drop parts. Shops and crates shut.",
		"upside": "drops_from_wrecks",
		"downside": "shops_and_crates_shut",
		"downside_text": "Shops and crates shut.",
		"unlock": {"order": "wo_tally_3"},
	},
	"code_double_shift": {
		"name": "Double Shift",
		"text": "Twice the machines at half guard. Double scrap bursts.",
		"upside": "double_packs_scrap",
		"downside": "half_guard_double_count",
		"downside_text": "Twice the machines at half guard.",
		"unlock": {"order": "wo_patch_3", "or_earned": "mind_quieted"},
	},
}

const ALT_LOADOUTS := {
	"alt_sable_crater": {
		"pilot": "pylon_engineer", "slot": "smash", "relic": "crater_heart", "swap": "crater_slam",
		"name": "Crater Slam", "text": "Smash spends the special for a crater.",
		"unlock": {"earned": "brindle_mark_sable"},
	},
	"alt_rivet_point_blank": {
		"pilot": "runner_gunner", "slot": "special", "relic": "muzzle_heart", "swap": "point_blank",
		"name": "Point Blank", "text": "Special becomes a point-blank blast.",
		"unlock": {"earned": "brindle_mark_rivet"},
	},
	"alt_kest_sticky_rain": {
		"pilot": "demolitions_caster", "slot": "weapon", "relic": "rain_heart", "swap": "sticky_rain",
		"name": "Sticky Rain", "text": "Sticky charges scatter three at once.",
		"unlock": {"earned": "brindle_mark_kest"},
	},
	"alt_tarn_rend_drag": {
		"pilot": "tarn", "slot": "smash", "relic": "gutter_heart", "swap": "rend_drag",
		"name": "Rend Drag", "text": "Rend slams drag machines into the crater.",
		"unlock": {"earned": "brindle_mark_tarn"},
	},
	"alt_tarn_claw_rake": {
		"pilot": "tarn", "slot": "weapon", "relic": "rake_heart", "swap": "claw_rake",
		"name": "Claw Rake", "text": "Each sweep rakes again on return.",
		"unlock": {"order": "wo_tarn_2"},
	},
	"alt_tally_stamp_ink": {
		"pilot": "tally", "slot": "smash", "relic": "ink_heart", "swap": "stamp_ink",
		"name": "Stamp Ink", "text": "Stamped machines refill pressure on balance due.",
		"unlock": {"earned": "brindle_mark_tally"},
	},
	"alt_tally_link_double": {
		"pilot": "tally", "slot": "line", "relic": "double_entry", "swap": "link_double",
		"name": "Double Entry", "text": "Settled clips jump to one fresh machine.",
		"unlock": {"order": "wo_tally_2"},
	},
	"alt_cannon_lane_walk": {
		"pilot": "remembered_cannon", "slot": "weapon", "relic": "walking_lane", "swap": "cannon_lane_walk",
		"name": "Walking Lane", "text": "Second call walks the lane further out.",
		"unlock": {"earned": "brindle_mark_cannon"},
	},
	"alt_cannon_rush_wake": {
		"pilot": "remembered_cannon", "slot": "smash", "relic": "rush_wake", "swap": "cannon_rush_wake",
		"name": "Rush Wake", "text": "Rush landings leave a lane behind.",
		"unlock": {"order": "wo_cannon_2"},
	},
}


static func ids() -> Array:
	return ROWS.keys()


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func open_earned(profile) -> Array:
	var out: Array = []
	for id in ROWS:
		if profile.earned(String(ROWS[id]["grant"])) and profile.open_option(id):
			out.append(id)
	return out


static func level(profile) -> int:
	return ROWS.keys().filter(func(id): return profile.has_option(id)).size()


static func _keys(value, out: Array) -> Array:
	if value is Dictionary:
		for key in value:
			out.append(String(key).to_lower())
			_keys(value[key], out)
	elif value is Array:
		for item in value:
			_keys(item, out)
	return out


static func validate(rows: Dictionary, grants: Dictionary) -> Array:
	var problems: Array = []
	var granted := {}
	for id in rows:
		var r = rows[id]
		if not (r is Dictionary):
			problems.append("%s: row must be a dictionary" % id)
			continue
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		for key in _keys(r, []):
			for word in BANNED_KEY_WORDS:
				if key.contains(word):
					problems.append("%s: key %s names a %s" % [id, key, word])
		var title := str(r.get("name", ""))
		if title == "" or WordBudget.words_in(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text := str(r.get("text", ""))
		if text == "" or WordBudget.words_in(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		if not KINDS.has(r.get("kind", "")):
			problems.append("%s: kind %s is not one of %s" % [id, r.get("kind", ""), KINDS])
		if not (r.get("effect") is String) or String(r.get("effect")) == "":
			problems.append("%s: effect must be an id" % id)
		var grant := str(r.get("grant", ""))
		var g = grants.get(grant)
		if not (g is Dictionary):
			problems.append("%s: grant %s is not an achievement row" % [id, grant])
			continue
		var reward = g.get("reward", {})
		if reward != {"option": id} and not (reward is Dictionary and reward.size() == 1 and reward.has("cosmetic")):
			problems.append("%s: grant %s must pay {\"option\": \"%s\"} or one cosmetic" % [id, grant, id])
		if not (g.get("count", 0) is int) or int(g.get("count", 0)) < 1 or int(g["count"]) > MAX_GRANT_COUNT:
			problems.append("%s: grant %s count must be 1 to %d" % [id, grant, MAX_GRANT_COUNT])
		if g.has("sum"):
			problems.append("%s: grant %s adds up a sum, not a one-run count" % [id, grant])
		granted[grant] = id
	for grant in grants:
		var reward = grants[grant].get("reward", {}) if grants[grant] is Dictionary else {}
		if reward is Dictionary and reward.has("option"):
			var target := str(reward["option"])
			if not rows.has(target):
				problems.append("%s: option reward %s is not a node row" % [grant, target])
			elif granted.get(grant, "") != target:
				problems.append("%s: pays node %s but is not that node's grant" % [grant, target])
	return problems


static func _camp_get(profile, key: String, fallback: Variant) -> Variant:
	if profile == null:
		return fallback
	if profile.has_method("camp_get"):
		var got = profile.camp_get(key)
		return got if got != null else fallback
	var doc: Dictionary = profile.camp()
	return doc.get(key, fallback)


static func _camp_set(profile, key: String, value: Variant) -> void:
	if profile == null:
		return
	if profile.has_method("camp_set"):
		profile.camp_set(key, value)
		return
	var doc: Dictionary = profile.camp()
	doc[key] = value
	profile.set_camp(doc)


static func _unlock_met(unlock: Dictionary, profile, sitting := false) -> bool:
	if sitting:
		return true
	if profile == null or unlock.is_empty():
		return false
	if unlock.has("order") and profile.is_settled(ORDER_SETTLE_PREFIX + String(unlock["order"])):
		return true
	if unlock.has("or_order") and profile.is_settled(ORDER_SETTLE_PREFIX + String(unlock["or_order"])):
		return true
	if unlock.has("earned") and profile.earned(String(unlock["earned"])):
		return true
	if unlock.has("or_earned") and profile.earned(String(unlock["or_earned"])):
		return true
	return false


static func _validate_unlock(id: String, unlock: Variant, order_ids: Array, grant_ids: Array, problems: Array[String]) -> void:
	if not (unlock is Dictionary) or unlock.is_empty():
		problems.append("%s: unlock must be a non-empty dictionary" % id)
		return
	var allowed := ["order", "or_order", "earned", "or_earned"]
	for key in unlock:
		if not allowed.has(key):
			problems.append("%s: unknown unlock key %s" % [id, key])
			continue
		var target := String(unlock[key])
		if key == "order" or key == "or_order":
			if not order_ids.has(target):
				problems.append("%s: unlock order %s does not resolve" % [id, target])
		else:
			if not grant_ids.has(target):
				problems.append("%s: unlock grant %s does not resolve" % [id, target])


static func override_ids() -> Array:
	return OVERRIDE_CODES.keys()


static func override_row(id: String) -> Dictionary:
	return OVERRIDE_CODES.get(id, {})


static func override_open(id: String, profile, sitting := false) -> bool:
	if not OVERRIDE_CODES.has(id):
		return false
	return _unlock_met(OVERRIDE_CODES[id]["unlock"], profile, sitting)


static func active_overrides(profile, bot_driven := false, sitting := false) -> Array[String]:
	var out: Array[String] = []
	if bot_driven or profile == null:
		return out
	var box = _camp_get(profile, CAMP_OVERRIDES_KEY, {})
	if not (box is Dictionary):
		return out
	var raw = box.get("active", [])
	if not (raw is Array):
		return out
	for id in OVERRIDE_CODES:
		if raw.has(id) and override_open(id, profile, sitting):
			out.append(id)
	return out


static func toggle_override(profile, id: String, sitting := false) -> bool:
	if profile == null or not override_open(id, profile, sitting):
		return false
	var box_raw = _camp_get(profile, CAMP_OVERRIDES_KEY, {})
	var box: Dictionary = (box_raw as Dictionary).duplicate(true) if box_raw is Dictionary else {}
	var active: Array = []
	if box.get("active") is Array:
		for existing in box["active"]:
			var sid := String(existing)
			if OVERRIDE_CODES.has(sid) and not active.has(sid):
				active.append(sid)
	if active.has(id):
		active.erase(id)
	else:
		active.append(id)
	box["active"] = active
	_camp_set(profile, CAMP_OVERRIDES_KEY, box)
	return true


static func override_effects(profile, bot_driven := false, sitting := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in active_overrides(profile, bot_driven, sitting):
		var r: Dictionary = OVERRIDE_CODES[id]
		out.append({"id": id, "upside": String(r["upside"]), "downside": String(r["downside"])})
	return out


static func validate_overrides(order_ids: Array, grant_ids: Array, rows_to_check: Dictionary = OVERRIDE_CODES) -> Array[String]:
	var problems: Array[String] = []
	for id in rows_to_check:
		var r = rows_to_check[id]
		if not (r is Dictionary):
			problems.append("%s: override row must be a dictionary" % id)
			continue
		for key in r:
			if not OVERRIDE_FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		for key in _keys(r, []):
			for word in BANNED_KEY_WORDS:
				if key.contains(word):
					problems.append("%s: key %s names banned word %s" % [id, key, word])
		var title := str(r.get("name", ""))
		if title == "" or WordBudget.words_in(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text := str(r.get("text", ""))
		if text == "" or WordBudget.words_in(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		var upside := str(r.get("upside", ""))
		if upside == "":
			problems.append("%s: upside must be non-empty" % id)
		var downside := str(r.get("downside", ""))
		if downside == "":
			problems.append("%s: downside must be non-empty" % id)
		var downside_text := str(r.get("downside_text", ""))
		if downside_text == "" or WordBudget.words_in(downside_text) > TEXT_WORDS:
			problems.append("%s: downside_text must be 1 to %d words" % [id, TEXT_WORDS])
		_validate_unlock(String(id), r.get("unlock"), order_ids, grant_ids, problems)
	return problems


static func alt_loadout_ids() -> Array:
	return ALT_LOADOUTS.keys()


static func alt_loadout(id: String) -> Dictionary:
	return ALT_LOADOUTS.get(id, {})


static func alt_loadouts_for(pilot_id: String) -> Array:
	return ALT_LOADOUTS.keys().filter(func(id): return String(ALT_LOADOUTS[id]["pilot"]) == pilot_id)


static func alt_loadout_open(id: String, profile, sitting := false) -> bool:
	if not ALT_LOADOUTS.has(id):
		return false
	return _unlock_met(ALT_LOADOUTS[id]["unlock"], profile, sitting)


static func equipped_alt_loadouts(profile, pilot_id: String, bot_driven := false, sitting := false) -> Dictionary:
	if bot_driven or profile == null or pilot_id == "":
		return {}
	var all_raw = _camp_get(profile, CAMP_ALT_LOADOUTS_KEY, {})
	if not (all_raw is Dictionary):
		return {}
	var mine = all_raw.get(pilot_id, {})
	if not (mine is Dictionary):
		return {}
	var out := {}
	for slot in mine:
		var alt_id := String(mine[slot])
		if alt_id == "" or not ALT_LOADOUTS.has(alt_id):
			continue
		var r: Dictionary = ALT_LOADOUTS[alt_id]
		if String(r["pilot"]) == pilot_id and String(r["slot"]) == String(slot) and alt_loadout_open(alt_id, profile, sitting):
			out[String(slot)] = alt_id
	return out


static func equip_alt_loadout(profile, alt_id: String, sitting := false) -> bool:
	if profile == null or not ALT_LOADOUTS.has(alt_id) or not alt_loadout_open(alt_id, profile, sitting):
		return false
	var r: Dictionary = ALT_LOADOUTS[alt_id]
	var pilot_id := String(r["pilot"])
	var slot := String(r["slot"])
	var all_raw = _camp_get(profile, CAMP_ALT_LOADOUTS_KEY, {})
	var all_map: Dictionary = (all_raw as Dictionary).duplicate(true) if all_raw is Dictionary else {}
	var mine: Dictionary = (all_map[pilot_id] as Dictionary).duplicate(true) if all_map.get(pilot_id) is Dictionary else {}
	mine[slot] = alt_id
	all_map[pilot_id] = mine
	_camp_set(profile, CAMP_ALT_LOADOUTS_KEY, all_map)
	return true


static func clear_alt_loadout(profile, pilot_id: String, slot: String) -> void:
	if profile == null or pilot_id == "" or slot == "":
		return
	var all_raw = _camp_get(profile, CAMP_ALT_LOADOUTS_KEY, {})
	if not (all_raw is Dictionary) or not all_raw.has(pilot_id):
		return
	var all_map: Dictionary = (all_raw as Dictionary).duplicate(true)
	if all_map[pilot_id] is Dictionary:
		var mine: Dictionary = (all_map[pilot_id] as Dictionary).duplicate(true)
		mine.erase(slot)
		if mine.is_empty():
			all_map.erase(pilot_id)
		else:
			all_map[pilot_id] = mine
		_camp_set(profile, CAMP_ALT_LOADOUTS_KEY, all_map)


static func validate_alt_loadouts(relic_rows: Dictionary, pilot_ids: Array, order_ids: Array, grant_ids: Array, rows_to_check: Dictionary = ALT_LOADOUTS) -> Array[String]:
	var problems: Array[String] = []
	for id in rows_to_check:
		var r = rows_to_check[id]
		if not (r is Dictionary):
			problems.append("%s: alt loadout row must be a dictionary" % id)
			continue
		for key in r:
			if not ALT_FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		for key in _keys(r, []):
			for word in BANNED_KEY_WORDS:
				if key.contains(word):
					problems.append("%s: key %s names banned word %s" % [id, key, word])
		var title := str(r.get("name", ""))
		if title == "" or WordBudget.words_in(title) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		var text := str(r.get("text", ""))
		if text == "" or WordBudget.words_in(text) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		var pilot := str(r.get("pilot", ""))
		if not pilot_ids.has(pilot):
			problems.append("%s: pilot %s is not a ClassDef id" % [id, pilot])
		var slot := str(r.get("slot", ""))
		var relic := str(r.get("relic", ""))
		var swap := str(r.get("swap", ""))
		if not relic_rows.has(relic):
			problems.append("%s: relic %s is not in Relics.ROWS" % [id, relic])
		else:
			var rr: Dictionary = relic_rows[relic]
			if not rr.has("swap") or str(rr["swap"]) == "":
				problems.append("%s: relic %s is not a swap relic" % [id, relic])
			elif str(rr["swap"]) != swap:
				problems.append("%s: swap %s disagrees with relic swap %s" % [id, swap, rr["swap"]])
			if not rr.get("pilots", []).has(pilot):
				problems.append("%s: relic %s does not fit pilot %s" % [id, relic, pilot])
			if str(rr.get("slot", "")) != slot:
				problems.append("%s: slot %s disagrees with relic slot %s" % [id, slot, rr.get("slot", "")])
			if rr.has("cooldown"):
				problems.append("%s: relic %s carries a cooldown buff, not a lateral swap" % [id, relic])
			if rr.has("charges"):
				problems.append("%s: relic %s carries a charges buff, not a lateral swap" % [id, relic])
		_validate_unlock(String(id), r.get("unlock"), order_ids, grant_ids, problems)
	return problems
