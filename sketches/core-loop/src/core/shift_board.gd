extends RefCounted


const Achievements := preload("res://src/core/achievements.gd")
const Items := preload("res://src/build/items.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const WorkOrders := preload("res://src/core/work_orders.gd")

const FIELDS := ["name", "text", "when", "stamp", "pays", "pilot"]
const WORLD_FIELDS := ["name", "text", "when", "stamp", "pays", "pilot", "act", "gate_rung", "hidden_until_stamped"]
const PAY_KINDS := ["pilot", "cosmetic", "item", "tune", "option"]
const WORLD_PAY_KINDS := ["pilot", "cosmetic", "item", "tune", "option", "mark"]
const STAMPS := ["CLOCKED IN", "LOGGED", "HIRED", "FOUND"]
const NAME_WORDS := 3
const TEXT_WORDS := 12
const PUNCH_STAT := "shift.punches"

const RUNGS := {
	"clock_in": {"name": "Clocked In", "text": "Finish your first shift, however it ends.",
		"when": {"earned": "ach_d7_salt_skip"}, "stamp": "CLOCKED IN", "pays": {"cosmetic": "trail_salt_skip"}},
	"first_warden": {"name": "Warden Breaker", "text": "Break a Warden's core in the Spillway.",
		"when": {"earned": "warden_broken"}, "stamp": "LOGGED", "pays": {"cosmetic": "paint_any_night"}},
	"rivet_freed": {"name": "Rivet Freed", "text": "Find the cage on the dam and ram it open.",
		"when": {"earned": "rivet_rescued"}, "stamp": "HIRED", "pays": {"pilot": "runner_gunner"}},
	"lost_tape": {"name": "Lost Tape", "text": "Something by the flume weir still plays. Find it.",
		"when": {"tune": "secret-lost-tape"}, "stamp": "FOUND", "pays": {"tune": "secret-lost-tape"}},
	"brindle_routed": {"name": "Brindle Routed", "text": "Rout Admiral Brindle in the Slag Bowl.",
		"when": {"earned": "brindle_routed"}, "stamp": "HIRED", "pays": {"pilot": "tarn"}},
	"mark_sable": {"name": "Sable's Mark", "text": "Rout Brindle flying Sable.", "pilot": "pylon_engineer",
		"when": {"earned": "brindle_mark_sable"}, "stamp": "LOGGED", "pays": {"item": "strike_pocket"}},
	"mark_rivet": {"name": "Rivet's Mark", "text": "Rout Brindle flying Rivet.", "pilot": "runner_gunner",
		"when": {"earned": "brindle_mark_rivet"}, "stamp": "LOGGED", "pays": {"item": "clean_break"}},
	"mark_tarn": {"name": "Tarn's Mark", "text": "Rout Brindle flying Tarn.", "pilot": "tarn",
		"when": {"earned": "brindle_mark_tarn"}, "stamp": "LOGGED", "pays": {"item": "warhead_slug"}},
	"mark_kest": {"name": "Kest's Mark", "text": "Rout Brindle flying Kest.", "pilot": "demolitions_caster",
		"when": {"earned": "brindle_mark_kest"}, "stamp": "LOGGED", "pays": {"item": "ring_wave"}},
	"mark_tally": {"name": "Tally's Mark", "text": "Rout Brindle flying Tally.", "pilot": "tally",
		"when": {"earned": "brindle_mark_tally"}, "stamp": "LOGGED", "pays": {"item": "salvage_drone"}},
	"mark_cannon": {"name": "Cannon's Mark", "text": "Rout Brindle flying the Cannon.", "pilot": "remembered_cannon",
		"when": {"earned": "brindle_mark_cannon"}, "stamp": "LOGGED", "pays": {"item": "scrap_geyser"}},
}

const TIME_CARD := {"holes": 3, "min_kills": 5}
const CARDS := [
	{"name": "First Card", "pays": {"item": "spring_hull"}},
	{"name": "Second Card", "pays": {"item": "shock_liner"}},
	{"name": "Third Card", "pays": {"item": "rebound_skin"}},
]

const SEED_KINDS := ["stage_variant", "run_modifier"]
const SEEDS := {
	"dam_night_shift": {"kind": "stage_variant", "gate": "brindle_routed",
		"text": "The dam at night has floodlights, a fuller crew, one more cage."},
	"flume_backwash": {"kind": "stage_variant", "gate": "mark_rivet",
		"text": "The flume runs backwards, and the weir becomes the drop-in."},
	"overtime": {"kind": "run_modifier", "gate": "first_warden",
		"text": "Overtime wakes Wardens one tick early and pays one more panel."},
	"crew_short": {"kind": "run_modifier", "gate": "mark_sable",
		"text": "Short crew means no dam shop and a cache instead."},
}

const WORLD_RUNGS := {
	"dig_warden": {"name": "Swarm Breaker", "text": "Break a Swarm Warden in the Dig.", "act": 2, "gate_rung": "brindle_routed",
		"when": {"earned": "dig_warden_broken"}, "stamp": "LOGGED", "pays": {"mark": "dig_warden"}},
	"kest_freed": {"name": "Kest Freed", "text": "Dig out Kest in the upper bench.", "act": 2, "gate_rung": "brindle_routed",
		"when": {"earned": "dig_rescued"}, "stamp": "HIRED", "pays": {"pilot": "demolitions_caster"}},
	"waking_stilled": {"name": "Waking Stilled", "text": "Still the Waking in the Dig.", "act": 2, "gate_rung": "brindle_routed",
		"when": {"earned": "waking_stilled"}, "stamp": "LOGGED", "pays": {"cosmetic": "paint_tarn_dig"}},
	"dig_mark_sable": {"name": "Sable's Dig Mark", "text": "Still the Waking flying Sable.", "act": 2, "gate_rung": "brindle_routed", "pilot": "pylon_engineer",
		"when": {"earned": "dig_mark_sable"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_sable"}},
	"dig_mark_rivet": {"name": "Rivet's Dig Mark", "text": "Still the Waking flying Rivet.", "act": 2, "gate_rung": "brindle_routed", "pilot": "runner_gunner",
		"when": {"earned": "dig_mark_rivet"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_rivet"}},
	"dig_mark_tarn": {"name": "Tarn's Dig Mark", "text": "Still the Waking flying Tarn.", "act": 2, "gate_rung": "brindle_routed", "pilot": "tarn",
		"when": {"earned": "dig_mark_tarn"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_tarn"}},
	"dig_mark_kest": {"name": "Kest's Dig Mark", "text": "Still the Waking flying Kest.", "act": 2, "gate_rung": "brindle_routed", "pilot": "demolitions_caster",
		"when": {"earned": "dig_mark_kest"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_kest"}},
	"dig_mark_tally": {"name": "Tally's Dig Mark", "text": "Still the Waking flying Tally.", "act": 2, "gate_rung": "brindle_routed", "pilot": "tally",
		"when": {"earned": "dig_mark_tally"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_tally"}},
	"dig_mark_cannon": {"name": "Cannon's Dig Mark", "text": "Still the Waking flying the Cannon.", "act": 2, "gate_rung": "brindle_routed", "pilot": "remembered_cannon",
		"when": {"earned": "dig_mark_cannon"}, "stamp": "LOGGED", "pays": {"mark": "dig_mark_cannon"}},
	"highdraft_reached": {"name": "Highdraft Reached", "text": "Climb into the Highdraft cableways.", "act": 3, "gate_rung": "waking_stilled",
		"when": {"earned": "highdraft_reached"}, "stamp": "LOGGED", "pays": {"cosmetic": "paint_any_sky"}},
	"highdraft_warden": {"name": "Crown Breaker", "text": "Break a Mind Warden in the Highdraft.", "act": 3, "gate_rung": "waking_stilled",
		"when": {"earned": "highdraft_warden_broken"}, "stamp": "LOGGED", "pays": {"mark": "highdraft_warden"}},
	"tally_hired": {"name": "Ledger Balanced", "text": "Return three ledger leaves to Moss.", "act": 3, "gate_rung": "waking_stilled",
		"when": {"earned": "ledger_balanced"}, "stamp": "HIRED", "pays": {"pilot": "tally"}},
	"mind_quieted": {"name": "Mind Quieted", "text": "Quiet the Mind atop the Crown.", "act": 3, "gate_rung": "waking_stilled",
		"when": {"earned": "mind_quieted"}, "stamp": "HIRED", "pays": {"pilot": "remembered_cannon"}},
	"crown_mark_sable": {"name": "Sable's Crown Mark", "text": "Quiet the Mind flying Sable.", "act": 3, "gate_rung": "waking_stilled", "pilot": "pylon_engineer",
		"when": {"earned": "crown_mark_sable"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_sable"}},
	"crown_mark_rivet": {"name": "Rivet's Crown Mark", "text": "Quiet the Mind flying Rivet.", "act": 3, "gate_rung": "waking_stilled", "pilot": "runner_gunner",
		"when": {"earned": "crown_mark_rivet"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_rivet"}},
	"crown_mark_tarn": {"name": "Tarn's Crown Mark", "text": "Quiet the Mind flying Tarn.", "act": 3, "gate_rung": "waking_stilled", "pilot": "tarn",
		"when": {"earned": "crown_mark_tarn"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_tarn"}},
	"crown_mark_kest": {"name": "Kest's Crown Mark", "text": "Quiet the Mind flying Kest.", "act": 3, "gate_rung": "waking_stilled", "pilot": "demolitions_caster",
		"when": {"earned": "crown_mark_kest"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_kest"}},
	"crown_mark_tally": {"name": "Tally's Crown Mark", "text": "Quiet the Mind flying Tally.", "act": 3, "gate_rung": "waking_stilled", "pilot": "tally",
		"when": {"earned": "crown_mark_tally"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_tally"}},
	"crown_mark_cannon": {"name": "Cannon's Crown Mark", "text": "Quiet the Mind flying the Cannon.", "act": 3, "gate_rung": "waking_stilled", "pilot": "remembered_cannon",
		"when": {"earned": "crown_mark_cannon"}, "stamp": "LOGGED", "pays": {"mark": "crown_mark_cannon"}},
	"patch_backdoor": {"name": "Unsigned Trail", "text": "Find all three wire rooms along the trail.", "act": 3, "gate_rung": "brindle_routed",
		"hidden_until_stamped": true, "when": {"earned": "ach_patch_trail"}, "stamp": "FOUND", "pays": {"mark": "patch_backdoor"}},
}

const WORLD_CARDS := [
	{"name": "Fourth Card", "act": 2, "pays": {"item": "tumbler_bearing"}},
	{"name": "Fifth Card", "act": 2, "pays": {"item": "slipstream"}},
	{"name": "Sixth Card", "act": 3, "pays": {"item": "low_rider"}},
]

const WORLD_SEEDS := {
	"pit_seismic_shift": {"kind": "stage_variant", "gate": "dig_warden",
		"text": "The upper bench shakes loose extra scrap and falling rock."},
	"skylight_blackout": {"kind": "stage_variant", "gate": "waking_stilled",
		"text": "Deep works lights cut out while swarm lamps burn brighter."},
	"cut_command_lines": {"kind": "run_modifier", "gate": "patch_backdoor",
		"text": "A rogue machine joins each stage outside the Foreman's grid."},
	"crown_squall_shift": {"kind": "stage_variant", "gate": "highdraft_warden",
		"text": "Crosswinds sweep the islands and double thermal lift."},
	"foreman_audit": {"kind": "run_modifier", "gate": "mind_quieted",
		"text": "Wardens wake earlier and pay one extra cobalt gate."},
}


static func ids() -> Array:
	return RUNGS.keys()


static func rung(id: String) -> Dictionary:
	return RUNGS.get(id, {})


static func stamped(id: String, profile) -> bool:
	if profile == null or not RUNGS.has(id):
		return false
	var when: Dictionary = RUNGS[id]["when"]
	if when.has("earned"):
		return profile.earned(String(when["earned"]))
	return profile.has_tune(String(when["tune"]))


static func stamped_ids(profile) -> Array:
	return RUNGS.keys().filter(func(id): return stamped(id, profile))


static func shown(id: String, profile, sitting := false) -> bool:
	var pilot := String(RUNGS[id].get("pilot", ""))
	if pilot == "" or sitting:
		return true
	var def = ClassDef.by_id(pilot)
	return (def != null and def.starter) or (profile != null and profile.has_pilot(pilot))


static func next_rung(profile, sitting := false) -> String:
	for id in RUNGS:
		if shown(id, profile, sitting) and not stamped(id, profile):
			return id
	return ""


static func punches(profile) -> int:
	return int(profile.stat(PUNCH_STAT)) if profile != null else 0


static func cards_paid(profile) -> int:
	return mini(punches(profile) / int(TIME_CARD["holes"]), CARDS.size())


static func holes_on_card(profile) -> int:
	if cards_paid(profile) >= CARDS.size():
		return int(TIME_CARD["holes"])
	return punches(profile) % int(TIME_CARD["holes"])


static func opened_items(profile, bot_driven := false) -> Array:
	var out: Array = []
	for id in RUNGS:
		var item := String(RUNGS[id]["pays"].get("item", ""))
		if item != "" and stamped(id, profile) and not out.has(item):
			out.append(item)
	for i in cards_paid(profile):
		var item := String(CARDS[i]["pays"]["item"])
		if not out.has(item):
			out.append(item)
	if bot_driven or profile == null:
		return out
	for id in WORLD_RUNGS:
		var item := String(WORLD_RUNGS[id]["pays"].get("item", ""))
		if item != "" and world_rung_stamped(id, profile) and not out.has(item):
			out.append(item)
	for i in world_cards_paid(profile):
		var item := String(WORLD_CARDS[i]["pays"]["item"])
		if not out.has(item):
			out.append(item)
	for item in WorkOrders.opened_items(profile, bot_driven):
		if not out.has(item):
			out.append(item)
	return out


static func all_rungs() -> Dictionary:
	var out := RUNGS.duplicate(false)
	for id in WORLD_RUNGS:
		out[id] = WORLD_RUNGS[id]
	return out


static func world_rung_stamped(id: String, profile) -> bool:
	if profile == null:
		return false
	if RUNGS.has(id):
		return stamped(id, profile)
	if not WORLD_RUNGS.has(id):
		return false
	var when: Dictionary = WORLD_RUNGS[id]["when"]
	if when.has("earned"):
		return profile.earned(String(when["earned"]))
	return profile.has_tune(String(when["tune"]))


static func world_rung_shown(id: String, profile, sitting := false) -> bool:
	if RUNGS.has(id):
		return shown(id, profile, sitting)
	if not WORLD_RUNGS.has(id):
		return false
	var r: Dictionary = WORLD_RUNGS[id]
	if bool(r.get("hidden_until_stamped", false)) and not world_rung_stamped(id, profile):
		return false
	var gate := String(r.get("gate_rung", ""))
	if gate != "" and not sitting and not world_rung_stamped(gate, profile):
		return false
	var pilot := String(r.get("pilot", ""))
	if pilot == "" or sitting:
		return true
	var def = ClassDef.by_id(pilot)
	return (def != null and def.starter) or (profile != null and profile.has_pilot(pilot))


static func act_rungs(act: int, profile, sitting := false) -> Array:
	if act == 1:
		return RUNGS.keys().filter(func(id): return shown(id, profile, sitting))
	var out: Array = []
	for id in WORLD_RUNGS:
		if int(WORLD_RUNGS[id].get("act", 0)) == act and world_rung_shown(id, profile, sitting):
			out.append(id)
	return out


static func world_cards_paid(profile) -> int:
	if profile == null or not stamped("brindle_routed", profile):
		return 0
	var holes := int(TIME_CARD["holes"])
	var extra_punches := punches(profile) - CARDS.size() * holes
	if extra_punches <= 0:
		return 0
	return mini(extra_punches / holes, WORLD_CARDS.size())


static func open_world_seeds(profile) -> Array:
	return WORLD_SEEDS.keys().filter(func(id): return world_rung_stamped(String(WORLD_SEEDS[id]["gate"]), profile))


static func all_items() -> Array:
	var out: Array = []
	for id in RUNGS:
		var item := String(RUNGS[id]["pays"].get("item", ""))
		if item != "":
			out.append(item)
	for card in CARDS:
		out.append(String(card["pays"]["item"]))
	return out


static func open_seeds(profile) -> Array:
	return SEEDS.keys().filter(func(id): return stamped(String(SEEDS[id]["gate"]), profile))


static func run_line(before: Array, profile, punched: bool) -> String:
	var fresh: Array = stamped_ids(profile).filter(func(id): return not id in before)
	if not fresh.is_empty():
		return _deeds_sentence(fresh)
	if punched:
		var holes := int(TIME_CARD["holes"])
		if cards_paid(profile) >= CARDS.size() and punches(profile) > holes * CARDS.size():
			return "Time card punched. Every card is paid, and the clerk punches it anyway."
		var on_card := holes_on_card(profile)
		if on_card == 0 or on_card == holes:
			var card: Dictionary = CARDS[cards_paid(profile) - 1]
			return "Time card full. %s pays %s next shift." % [String(card["name"]), item_name(String(card["pays"]["item"]))]
		return "Time card punched, %d of %d." % [on_card, holes]
	if profile != null:
		var next := next_rung(profile)
		if next != "":
			return "Next on the shift board, %s. %s" % [String(RUNGS[next]["name"]), String(RUNGS[next]["text"])]
		return "Short shift. Clear %d machines to punch the time card." % int(TIME_CARD["min_kills"])
	return ""


static func _deeds_sentence(ids: Array) -> String:
	var deeds := PackedStringArray()
	for id in ids:
		if id != "clock_in":
			deeds.append(String(RUNGS[id]["name"]))
	var clocked: bool = "clock_in" in ids
	if deeds.is_empty():
		return "You clocked in. Your first shift is on the shift board."
	var list := deeds[0] if deeds.size() == 1 else "%s and %s" % [", ".join(deeds.slice(0, deeds.size() - 1)), deeds[deeds.size() - 1]]
	return "You %smarked off %s on the shift board." % ["clocked in and " if clocked else "", list]


static func reading(profile, sitting := false) -> Dictionary:
	var shown_ids: Array = RUNGS.keys().filter(func(id): return shown(id, profile, sitting))
	var done: Array = shown_ids.filter(func(id): return stamped(id, profile))
	var next := next_rung(profile, sitting)
	var out := {"stamped": done.size(), "shown": shown_ids.size(), "next": next, "next_name": "", "next_text": "",
		"next_pays": "", "holes": holes_on_card(profile), "holes_max": int(TIME_CARD["holes"]),
		"card_next": "", "items_open": opened_items(profile).size()}
	if next != "":
		out["next_name"] = String(RUNGS[next]["name"])
		out["next_text"] = String(RUNGS[next]["text"])
		out["next_pays"] = pays_words(RUNGS[next]["pays"])
	if cards_paid(profile) < CARDS.size():
		out["card_next"] = item_name(String(CARDS[cards_paid(profile)]["pays"]["item"]))
	var act_progress := {}
	for act in [1, 2, 3]:
		var act_shown := act_rungs(act, profile, sitting)
		var act_done := act_shown.filter(func(id): return world_rung_stamped(id, profile))
		act_progress[act] = {"stamped": act_done.size(), "shown": act_shown.size()}
	out["active_orders"] = WorkOrders.active_ids(profile)
	out["licenses"] = WorkOrders.camp_state(profile, sitting)["licenses"]
	out["act_progress"] = act_progress
	return out


static func pays_words(pays: Dictionary) -> String:
	for kind in pays:
		var id := String(pays[kind])
		match kind:
			"item":
				return "%s can turn up in runs" % item_name(id)
			"pilot":
				return "Signs on a pilot"
			"cosmetic":
				return "A new look"
			"tune":
				return "A record for the jukebox"
			"option":
				return "A head start"
			"mark":
				return "Logged on the shift board"
	return ""


static func item_name(id: String) -> String:
	var parts = load("res://src/build/parts.gd")
	var row: Dictionary = parts.row(id)
	return String(row.get("name", id))


static func _words(s: String) -> int:
	return s.split(" ", false).size()


static func validate(rows: Dictionary, grants: Dictionary, tunes: Array) -> Array:
	var problems: Array = []
	var items_seen := {}
	for id in rows:
		var r: Dictionary = rows[id]
		for key in r:
			if not FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		if _words(String(r.get("name", ""))) < 1 or _words(String(r.get("name", ""))) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		if _words(String(r.get("text", ""))) < 1 or _words(String(r.get("text", ""))) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		if not STAMPS.has(String(r.get("stamp", ""))):
			problems.append("%s: stamp %s is not one of %s" % [id, r.get("stamp", ""), STAMPS])
		var when = r.get("when", {})
		if not (when is Dictionary) or when.size() != 1:
			problems.append("%s: when must carry exactly one of earned or tune" % id)
			continue
		var pays = r.get("pays", {})
		if not (pays is Dictionary) or pays.size() != 1 or not PAY_KINDS.has(pays.keys()[0]):
			problems.append("%s: pays must carry exactly one of %s" % [id, PAY_KINDS])
			continue
		var kind: String = pays.keys()[0]
		var target := String(pays[kind])
		if when.has("earned"):
			var grant := String(when["earned"])
			if not grants.has(grant):
				problems.append("%s: earned row %s is not an achievement" % [id, grant])
			elif kind != "tune":
				var reward: Dictionary = grants[grant].get("reward", {})
				if String(reward.get(kind, "")) != target:
					problems.append("%s: pays %s %s but %s rewards %s" % [id, kind, target, grant, reward])
		elif when.has("tune"):
			if not tunes.has(String(when["tune"])):
				problems.append("%s: tune %s is not a jukebox row" % [id, when["tune"]])
		else:
			problems.append("%s: when key %s is unknown" % [id, when.keys()[0]])
		if kind == "item":
			if not Items.TABLE.has(target):
				problems.append("%s: item %s is not an items.gd row" % [id, target])
			elif items_seen.has(target):
				problems.append("%s: item %s is already opened by %s" % [id, target, items_seen[target]])
			else:
				items_seen[target] = id
	for card in CARDS:
		var item := String(card.get("pays", {}).get("item", ""))
		if not Items.TABLE.has(item):
			problems.append("card %s: item %s is not an items.gd row" % [card.get("name", ""), item])
		elif items_seen.has(item):
			problems.append("card %s: item %s is already opened by %s" % [card.get("name", ""), item, items_seen[item]])
		else:
			items_seen[item] = String(card.get("name", ""))
	for grant in grants:
		var reward = grants[grant].get("reward", {})
		if not (reward is Dictionary) or not reward.has("item"):
			continue
		var item := String(reward["item"])
		if not Items.TABLE.has(item):
			problems.append("%s: reward item %s is not an items.gd row" % [grant, item])
		elif not rows.keys().any(func(r): return rows[r].get("when", {}).get("earned", "") == grant):
			problems.append("%s: pays item %s but no rung reads it, so the item could never show" % [grant, item])
	for item in items_seen:
		var row: Dictionary = Items.TABLE[item]
		if row.has("class") or row.has("needs"):
			problems.append("%s: an opened item must suit every pilot and need no seam" % item)
	for id in SEEDS:
		var s: Dictionary = SEEDS[id]
		if not SEED_KINDS.has(String(s.get("kind", ""))):
			problems.append("seed %s: kind must be one of %s" % [id, SEED_KINDS])
		if not rows.has(String(s.get("gate", ""))):
			problems.append("seed %s: gate %s is not a rung" % [id, s.get("gate", "")])
		if _words(String(s.get("text", ""))) > TEXT_WORDS:
			problems.append("seed %s: text must be %d words or fewer" % [id, TEXT_WORDS])
	return problems


static func validate_world_rungs(all_grants: Dictionary, tunes: Array, rows_to_check: Dictionary = WORLD_RUNGS) -> Array:
	var problems: Array = []
	var items_seen := {}
	for item in all_items():
		items_seen[item] = "w1_board"
	var merged := RUNGS.duplicate(false)
	for id in rows_to_check:
		if RUNGS.has(id):
			problems.append("%s: collides with W1 RUNGS" % id)
		merged[id] = rows_to_check[id]
	for id in rows_to_check:
		var r: Dictionary = rows_to_check[id]
		for key in r:
			if not WORLD_FIELDS.has(key):
				problems.append("%s: unknown field %s" % [id, key])
		if _words(String(r.get("name", ""))) < 1 or _words(String(r.get("name", ""))) > NAME_WORDS:
			problems.append("%s: name must be 1 to %d words" % [id, NAME_WORDS])
		if _words(String(r.get("text", ""))) < 1 or _words(String(r.get("text", ""))) > TEXT_WORDS:
			problems.append("%s: text must be 1 to %d words" % [id, TEXT_WORDS])
		if not STAMPS.has(String(r.get("stamp", ""))):
			problems.append("%s: stamp %s is not one of %s" % [id, r.get("stamp", ""), STAMPS])
		var act := int(r.get("act", 0))
		if act < 2 or act > 3:
			problems.append("%s: act must be 2 or 3" % id)
		var gate := String(r.get("gate_rung", ""))
		if gate != "" and not merged.has(gate):
			problems.append("%s: gate_rung %s is not a rung" % [id, gate])
		var when = r.get("when", {})
		if not (when is Dictionary) or when.size() != 1:
			problems.append("%s: when must carry exactly one of earned or tune" % id)
			continue
		var pays = r.get("pays", {})
		if not (pays is Dictionary) or pays.size() != 1 or not WORLD_PAY_KINDS.has(pays.keys()[0]):
			problems.append("%s: pays must carry exactly one of %s" % [id, WORLD_PAY_KINDS])
			continue
		var kind := String(pays.keys()[0])
		var target := String(pays[kind])
		if when.has("earned"):
			var grant := String(when["earned"])
			if not all_grants.has(grant):
				problems.append("%s: earned row %s is not an achievement" % [id, grant])
			elif kind != "tune" and kind != "mark":
				var reward: Dictionary = all_grants[grant].get("reward", {})
				if String(reward.get(kind, "")) != target:
					problems.append("%s: pays %s %s but %s rewards %s" % [id, kind, target, grant, reward])
		elif when.has("tune"):
			if not tunes.has(String(when["tune"])):
				problems.append("%s: tune %s is not a jukebox row" % [id, when["tune"]])
		else:
			problems.append("%s: when key %s is unknown" % [id, when.keys()[0]])
		if kind == "item":
			if not Items.TABLE.has(target):
				problems.append("%s: item %s is not an items.gd row" % [id, target])
			elif items_seen.has(target):
				problems.append("%s: item %s already opened by %s" % [id, target, items_seen[target]])
			else:
				items_seen[target] = id
	for card in WORLD_CARDS:
		var item := String(card.get("pays", {}).get("item", ""))
		if not Items.TABLE.has(item):
			problems.append("world card %s: item %s is not an items.gd row" % [card.get("name", ""), item])
		elif items_seen.has(item):
			problems.append("world card %s: item %s already opened by %s" % [card.get("name", ""), item, items_seen[item]])
		else:
			items_seen[item] = String(card.get("name", ""))
	for item in items_seen:
		if items_seen[item] == "w1_board":
			continue
		var row: Dictionary = Items.TABLE[item]
		if row.has("class") or row.has("needs"):
			problems.append("%s: an opened item must suit every pilot and need no seam" % item)
		if ParkDefs.part_in_play(item):
			problems.append("%s: an opened item must not already be in ParkDefs.part_in_play" % item)
	for id in WORLD_SEEDS:
		var s: Dictionary = WORLD_SEEDS[id]
		if not SEED_KINDS.has(String(s.get("kind", ""))):
			problems.append("world seed %s: kind must be one of %s" % [id, SEED_KINDS])
		if not merged.has(String(s.get("gate", ""))):
			problems.append("world seed %s: gate %s is not a rung" % [id, s.get("gate", "")])
		if _words(String(s.get("text", ""))) > TEXT_WORDS:
			problems.append("world seed %s: text must be %d words or fewer" % [id, TEXT_WORDS])
	return problems
