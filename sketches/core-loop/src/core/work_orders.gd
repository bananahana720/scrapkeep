class_name WorkOrders
extends RefCounted

const WordBudget := preload("res://src/core/word_budget.gd")


const ClassDef := preload("res://src/core/class_def.gd")
const Items := preload("res://src/build/items.gd")
const MakerSets := preload("res://src/build/maker_sets.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const RunTier := preload("res://src/core/run_tier.gd")

const MAX_ACTIVE := 2
const ROTATION_OFFERS := 3
const MAX_COUNT := 10
const NAME_WORDS := 3
const TEXT_WORDS := 12

const CAMP_KEY := "work_orders"
const RUN_KEY := "work_orders"
const SETTLE_ORDER_PREFIX := "order:"
const SETTLE_LICENSE_PREFIX := "license:"
const LICENSE_SHIFT_STAT_PREFIX := "license.shift."
const LICENSE_TIERS := ["", "Temp Pass", "Yard Ticket", "Full License"]
const LICENSE_STAMPS_MAX := 3

const BANNED_KEY_WORDS := ["price", "cost", "stat", "discount", "cogs", "currency", "hp_bonus", "damage_bonus"]
const ORDER_FIELDS := ["name", "text", "track", "issuer", "maker", "world", "pilot", "min_tier", "requires", "objective", "pays", "post_sync_pool"]
const PAY_KINDS := ["item", "tune", "option", "override_code", "alt_loadout", "license_stamp"]
const LICENSE_PAY_KINDS := ["item", "plaque"]
const NEED_KEYS := ["world", "pilot", "min_tier", "no_kindness"]

const CREW_ORDERS := {
	"wo_moss_1": {
		"name": "First Docket", "text": "Break a Warden and clear a Spillway stage.",
		"track": "crew", "issuer": "moss", "maker": "moss", "world": 1,
		"objective": {"all": [
			{"on": "beacon_unsealed", "count": 1, "need": {"world": 1}},
			{"on": "stage_cleared", "count": 1, "need": {"world": 1}},
		]},
		"pays": {"item": "momentum_thief"},
	},
	"wo_moss_2": {
		"name": "Deep Survey", "text": "Enter the Dig and clear the deep works.",
		"track": "crew", "issuer": "moss", "maker": "moss", "world": 2,
		"requires": ["wo_moss_1"],
		"objective": {"all": [
			{"on": "world_entered", "where": {"world": 2}, "count": 1},
			{"on": "stage_cleared", "where": {"stage": 4}, "count": 1},
		]},
		"pays": {"license_stamp": "moss"},
	},
	"wo_moss_3": {
		"name": "Closing Shift", "text": "Quiet the Mind in the Highdraft.",
		"track": "crew", "issuer": "moss", "maker": "moss", "world": 3,
		"requires": ["wo_moss_2"],
		"objective": {"on": "boss_defeated", "count": 1, "need": {"world": 3}},
		"pays": {"option": "shelf_preview"},
	},
	"wo_sable_1": {
		"name": "Spillway Line", "text": "Fire a line skill and break a Spillway Warden.",
		"track": "crew", "issuer": "pylon_engineer", "maker": "spillway_works", "world": 1,
		"pilot": "pylon_engineer",
		"objective": {"all": [
			{"on": "line_skill_fired", "count": 1, "need": {"pilot": "pylon_engineer"}},
			{"on": "beacon_unsealed", "count": 1, "need": {"world": 1, "pilot": "pylon_engineer"}},
		]},
		"pays": {"item": "reserve_tank"},
	},
	"wo_sable_2": {
		"name": "Arch Clearance", "text": "Clear a Dig stage or shatter two pieces.",
		"track": "crew", "issuer": "pylon_engineer", "maker": "spillway_works", "world": 2,
		"pilot": "pylon_engineer", "requires": ["wo_sable_1"],
		"objective": {"any": [
			{"on": "stage_cleared", "count": 1, "need": {"world": 2, "pilot": "pylon_engineer"}},
			{"on": "world_fact", "where": {"kind": "piece_shattered"}, "count": 2, "need": {"pilot": "pylon_engineer"}},
		]},
		"pays": {"license_stamp": "spillway_works"},
	},
	"wo_sable_3": {
		"name": "Glass Rail", "text": "Break a Highdraft Warden flying Sable.",
		"track": "crew", "issuer": "pylon_engineer", "maker": "spillway_works", "world": 3,
		"pilot": "pylon_engineer", "requires": ["wo_sable_2"],
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 3, "pilot": "pylon_engineer"}},
		"pays": {"override_code": "code_glass_rail"},
	},
	"wo_rivet_1": {
		"name": "Drum Run", "text": "Fire Line Drive and break a kill-first special.",
		"track": "crew", "issuer": "runner_gunner", "maker": "fleet_surplus", "world": 1,
		"pilot": "runner_gunner",
		"objective": {"all": [
			{"on": "line_skill_fired", "where": {"ability_id": "line_drive"}, "count": 1, "need": {"pilot": "runner_gunner"}},
			{"on": "special_broken", "count": 1, "need": {"pilot": "runner_gunner"}},
		]},
		"pays": {"item": "brass_drum"},
	},
	"wo_rivet_2": {
		"name": "Seam Breaker", "text": "Shatter three pieces in the Dig flying Rivet.",
		"track": "crew", "issuer": "runner_gunner", "maker": "fleet_surplus", "world": 2,
		"pilot": "runner_gunner", "requires": ["wo_rivet_1"],
		"objective": {"on": "world_fact", "where": {"kind": "piece_shattered"}, "count": 3, "need": {"world": 2, "pilot": "runner_gunner"}},
		"pays": {"item": "warden_ward"},
	},
	"wo_rivet_3": {
		"name": "No Favors", "text": "Down a Highdraft boss or Warden with no kindness.",
		"track": "crew", "issuer": "runner_gunner", "maker": "fleet_surplus", "world": 3,
		"pilot": "runner_gunner", "requires": ["wo_rivet_2"],
		"objective": {"any": [
			{"on": "boss_defeated", "count": 1, "need": {"world": 3, "pilot": "runner_gunner", "no_kindness": true}},
			{"on": "beacon_unsealed", "count": 1, "need": {"world": 3, "pilot": "runner_gunner", "no_kindness": true}},
		]},
		"pays": {"override_code": "code_single_docket"},
	},
	"wo_kest_1": {
		"name": "Bench Drop", "text": "Land a slam or break a Dig Warden flying Kest.",
		"track": "crew", "issuer": "demolitions_caster", "maker": "highdraft_roosts", "world": 2,
		"pilot": "demolitions_caster",
		"objective": {"any": [
			{"on": "drop_landed", "at_least": {"hit_count": 1}, "count": 1, "need": {"world": 2, "pilot": "demolitions_caster"}},
			{"on": "beacon_unsealed", "count": 1, "need": {"world": 2, "pilot": "demolitions_caster"}},
		]},
		"pays": {"item": "flywheel"},
	},
	"wo_kest_2": {
		"name": "Open Span", "text": "Clear stage five in the Highdraft flying Kest.",
		"track": "crew", "issuer": "demolitions_caster", "maker": "highdraft_roosts", "world": 3,
		"pilot": "demolitions_caster", "requires": ["wo_kest_1"],
		"objective": {"on": "stage_cleared", "where": {"stage": 5}, "count": 1, "need": {"pilot": "demolitions_caster"}},
		"pays": {"item": "long_lane"},
	},
	"wo_kest_3": {
		"name": "Cut Governor", "text": "Break a Highdraft Warden flying Kest.",
		"track": "crew", "issuer": "demolitions_caster", "maker": "highdraft_roosts", "world": 3,
		"pilot": "demolitions_caster", "requires": ["wo_kest_2"],
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 3, "pilot": "demolitions_caster"}},
		"pays": {"override_code": "code_cut_governor"},
	},
	"wo_tarn_1": {
		"name": "Heavy Frame", "text": "Shatter three pieces or break a special flying Tarn.",
		"track": "crew", "issuer": "tarn", "maker": "redjaw", "world": 1,
		"pilot": "tarn",
		"objective": {"any": [
			{"on": "world_fact", "where": {"kind": "piece_shattered"}, "count": 3, "need": {"pilot": "tarn"}},
			{"on": "special_broken", "count": 1, "need": {"pilot": "tarn"}},
		]},
		"pays": {"item": "heavy_breech"},
	},
	"wo_tarn_2": {
		"name": "Dig Heavy", "text": "Still the Waking flying Tarn.",
		"track": "crew", "issuer": "tarn", "maker": "redjaw", "world": 2,
		"pilot": "tarn", "requires": ["wo_tarn_1"],
		"objective": {"on": "boss_defeated", "count": 1, "need": {"world": 2, "pilot": "tarn"}},
		"pays": {"alt_loadout": "alt_tarn_claw_rake"},
	},
	"wo_tarn_3": {
		"name": "Heavy Roster", "text": "Clock out two ballast heavies flying Tarn.",
		"track": "crew", "issuer": "tarn", "maker": "redjaw", "world": 3,
		"pilot": "tarn", "requires": ["wo_tarn_2"],
		"objective": {"on": "enemy_killed", "where": {"kind": "ballast_heavy"}, "count": 2, "need": {"world": 3, "pilot": "tarn"}},
		"pays": {"override_code": "code_full_roster"},
	},
	"wo_tally_1": {
		"name": "Trunk Tap", "text": "Fire link clips and land an ultimate flying Tally.",
		"track": "crew", "issuer": "tally", "maker": "waking", "world": 1,
		"pilot": "tally",
		"objective": {"all": [
			{"on": "line_skill_fired", "where": {"ability_id": "link_clips"}, "count": 1, "need": {"pilot": "tally"}},
			{"on": "ultimate_landed", "count": 1, "need": {"pilot": "tally"}},
		]},
		"pays": {"license_stamp": "waking"},
	},
	"wo_tally_2": {
		"name": "Double Tap", "text": "Finish two Dig activities or still the Waking flying Tally.",
		"track": "crew", "issuer": "tally", "maker": "waking", "world": 2,
		"pilot": "tally", "requires": ["wo_tally_1"],
		"objective": {"any": [
			{"on": "activity_done", "count": 2, "need": {"world": 2, "pilot": "tally"}},
			{"on": "boss_defeated", "count": 1, "need": {"world": 2, "pilot": "tally"}},
		]},
		"pays": {"alt_loadout": "alt_tally_link_double"},
	},
	"wo_tally_3": {
		"name": "Open Wire", "text": "Break a Highdraft Warden flying Tally.",
		"track": "crew", "issuer": "tally", "maker": "waking", "world": 3,
		"pilot": "tally", "requires": ["wo_tally_2"],
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 3, "pilot": "tally"}},
		"pays": {"override_code": "code_open_manifest"},
	},
	"wo_cannon_1": {
		"name": "Proof Shot", "text": "Shatter two pieces in the Highdraft flying the Cannon.",
		"track": "crew", "issuer": "remembered_cannon", "maker": "mind_glass", "world": 3,
		"pilot": "remembered_cannon",
		"objective": {"on": "world_fact", "where": {"kind": "piece_shattered"}, "count": 2, "need": {"world": 3, "pilot": "remembered_cannon"}},
		"pays": {"license_stamp": "mind_glass"},
	},
	"wo_cannon_2": {
		"name": "Clean Fire", "text": "Down any world boss with no kindness flying the Cannon.",
		"track": "crew", "issuer": "remembered_cannon", "maker": "mind_glass", "world": 1,
		"pilot": "remembered_cannon", "requires": ["wo_cannon_1"],
		"objective": {"on": "boss_defeated", "count": 1, "need": {"pilot": "remembered_cannon", "no_kindness": true}},
		"pays": {"alt_loadout": "alt_cannon_rush_wake"},
	},
	"wo_cannon_3": {
		"name": "Hard Proof", "text": "Win a hard run flying the Cannon.",
		"track": "crew", "issuer": "remembered_cannon", "maker": "mind_glass", "world": 3,
		"pilot": "remembered_cannon", "min_tier": 1, "requires": ["wo_cannon_2"],
		"objective": {"on": "run_ended", "where": {"won": true}, "count": 1, "need": {"pilot": "remembered_cannon", "min_tier": 1}},
		"pays": {"tune": "secret-highdraft-rain"},
	},
	"wo_patch_1": {
		"name": "Loose Wire", "text": "Find a Signal cache or down Crane Fourteen.",
		"track": "crew", "issuer": "patch", "maker": "moss", "world": 1,
		"objective": {"any": [
			{"on": "radio_take_found", "where": {"source": "cache"}, "count": 1},
			{"on": "enemy_killed", "where": {"kind": "rogue_crane"}, "count": 1},
		]},
		"pays": {"option": "pocket_tint"},
	},
	"wo_patch_2": {
		"name": "Skip Trace", "text": "Crack a Dig cache or down Skip Thirty-One.",
		"track": "crew", "issuer": "patch", "maker": "moss", "world": 2,
		"requires": ["wo_patch_1"],
		"objective": {"any": [
			{"on": "activity_done", "where": {"id": "cracked_cache"}, "count": 1, "need": {"world": 2}},
			{"on": "enemy_killed", "where": {"kind": "rogue_skip"}, "count": 1},
		]},
		"pays": {"tune": "secret-dig-dub"},
	},
	"wo_patch_3": {
		"name": "West Signal", "text": "Crack a Highdraft cache or down Cable Tender Seven.",
		"track": "crew", "issuer": "patch", "maker": "moss", "world": 3,
		"requires": ["wo_patch_2"],
		"objective": {"any": [
			{"on": "activity_done", "where": {"id": "cracked_cache"}, "count": 1, "need": {"world": 3}},
			{"on": "enemy_killed", "where": {"kind": "rogue_tender"}, "count": 1},
		]},
		"pays": {"override_code": "code_double_shift"},
	},
}

const SHIFT_ORDERS := {
	"so_w1_spillway_warden": {
		"name": "Spillway Sweep", "text": "Break a Spillway Warden in one run.",
		"track": "shift", "issuer": "moss", "maker": "spillway_works", "world": 1,
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 1}},
		"pays": {"license_stamp": "spillway_works"},
	},
	"so_w1_fleet_specials": {
		"name": "Break Specials", "text": "Break two kill-first specials in one run.",
		"track": "shift", "issuer": "moss", "maker": "fleet_surplus", "world": 1,
		"objective": {"on": "special_broken", "count": 2},
		"pays": {"license_stamp": "fleet_surplus"},
	},
	"so_w1_redjaw_heft": {
		"name": "Heavy Roll", "text": "Reach heft tier three in one run.",
		"track": "shift", "issuer": "moss", "maker": "redjaw", "world": 1,
		"objective": {"on": "heft_class_changed", "at_least": {"heft_class": 3}, "count": 1},
		"pays": {"license_stamp": "redjaw"},
	},
	"so_w1_moss_gamble": {
		"name": "Keeper Odds", "text": "Take a keeper's gamble trade once.",
		"track": "shift", "issuer": "moss", "maker": "moss", "world": 1,
		"objective": {"on": "trade_taken", "where": {"kind": "trade_risk"}, "count": 1},
		"pays": {"license_stamp": "moss"},
	},
	"so_w1_roosts_drops": {
		"name": "Drop Strike", "text": "Land two slams that hit machines.",
		"track": "shift", "issuer": "moss", "maker": "highdraft_roosts", "world": 1,
		"objective": {"on": "drop_landed", "at_least": {"hit_count": 1}, "count": 2},
		"pays": {"license_stamp": "highdraft_roosts"},
	},
	"so_w1_set_complete": {
		"name": "Full Bench", "text": "Complete any maker set in one run.",
		"track": "shift", "issuer": "moss", "maker": "waking", "world": 1,
		"objective": {"on": "maker_set_completed", "count": 1},
		"pays": {"license_stamp": "waking"},
	},
	"so_w2_waking_warden": {
		"name": "Bench Sweep", "text": "Break a Swarm Warden in the Dig.",
		"track": "shift", "issuer": "moss", "maker": "waking", "world": 2,
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 2}},
		"pays": {"license_stamp": "waking"},
	},
	"so_w2_redjaw_activities": {
		"name": "Dig Sites", "text": "Finish two standing activities in the Dig.",
		"track": "shift", "issuer": "moss", "maker": "redjaw", "world": 2,
		"objective": {"on": "activity_done", "count": 2, "need": {"world": 2}},
		"pays": {"license_stamp": "redjaw"},
	},
	"so_w2_spillway_clear": {
		"name": "Deep Clear", "text": "Clear both stages of the Dig.",
		"track": "shift", "issuer": "moss", "maker": "spillway_works", "world": 2,
		"objective": {"on": "stage_cleared", "count": 2, "need": {"world": 2}},
		"pays": {"license_stamp": "spillway_works"},
	},
	"so_w3_mind_warden": {
		"name": "Crown Sweep", "text": "Break a Mind Warden in the Highdraft.",
		"track": "shift", "issuer": "moss", "maker": "mind_glass", "world": 3,
		"objective": {"on": "beacon_unsealed", "count": 1, "need": {"world": 3}},
		"pays": {"license_stamp": "mind_glass"},
	},
	"so_w3_roosts_ult": {
		"name": "Highdraft Finale", "text": "Land two ultimates in the Highdraft.",
		"track": "shift", "issuer": "moss", "maker": "highdraft_roosts", "world": 3,
		"objective": {"on": "ultimate_landed", "count": 2, "need": {"world": 3}},
		"pays": {"license_stamp": "highdraft_roosts"},
	},
	"so_hard_fleet_clear": {
		"name": "Overtime Shift", "text": "Win any run on hard rung one.",
		"track": "shift", "issuer": "moss", "maker": "fleet_surplus", "world": 1,
		"min_tier": 1,
		"objective": {"on": "run_ended", "where": {"won": true}, "count": 1, "need": {"min_tier": 1}},
		"pays": {"license_stamp": "fleet_surplus"},
	},
}

const LICENSES := {
	"spillway_works": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:spillway_works:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:spillway_works:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:spillway_works:3"}},
	},
	"fleet_surplus": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:fleet_surplus:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:fleet_surplus:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:fleet_surplus:3"}},
	},
	"redjaw": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:redjaw:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:redjaw:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:redjaw:3"}},
	},
	"highdraft_roosts": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:highdraft_roosts:1"}},
		2: {"name": "Yard Ticket", "pays": {"item": "gutter_guard"}},
		3: {"name": "Full License", "pays": {"item": "light_frame"}},
	},
	"waking": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:waking:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:waking:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:waking:3"}},
	},
	"mind_glass": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:mind_glass:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:mind_glass:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:mind_glass:3"}},
	},
	"moss": {
		1: {"name": "Temp Pass", "pays": {"plaque": "license:moss:1"}},
		2: {"name": "Yard Ticket", "pays": {"plaque": "license:moss:2"}},
		3: {"name": "Full License", "pays": {"plaque": "license:moss:3"}},
	},
}


static func order(id: String) -> Dictionary:
	if CREW_ORDERS.has(id):
		return CREW_ORDERS[id]
	return SHIFT_ORDERS.get(id, {})


static func all_orders() -> Dictionary:
	var out := CREW_ORDERS.duplicate(false)
	for id in SHIFT_ORDERS:
		out[id] = SHIFT_ORDERS[id]
	return out


static func order_ids() -> Array:
	return CREW_ORDERS.keys() + SHIFT_ORDERS.keys()


static func completed(id: String, profile) -> bool:
	if profile == null or order(id).is_empty():
		return false
	return profile.is_settled(SETTLE_ORDER_PREFIX + id)


static func issuer_label(id: String, profile) -> String:
	var row := order(id)
	var issuer := String(row.get("issuer", ""))
	if issuer == "patch" and not completed("wo_patch_2", profile):
		return "Unsigned"
	if issuer == "patch":
		return "Patch"
	if issuer == "moss":
		return "Moss"
	var def := ClassDef.by_id(issuer)
	return String(def.display_name) if def != null else issuer


static func unlocked(id: String, profile, sitting := false) -> bool:
	var row := order(id)
	if row.is_empty():
		return false
	for req in row.get("requires", []):
		if not completed(String(req), profile):
			return false
	if sitting:
		return true
	var pilot := String(row.get("pilot", ""))
	if pilot != "":
		var def := ClassDef.by_id(pilot)
		if def == null or (not def.starter and (profile == null or not profile.has_pilot(pilot))):
			return false
	var min_tier := int(row.get("min_tier", 0))
	if min_tier > 0 and not RunTier.unlocked(profile, min_tier):
		return false
	var world := int(row.get("world", 1))
	if world == 2:
		if profile == null or not (profile.earned("brindle_routed") or profile.earned("ach_d7_mushroom")):
			return false
	elif world >= 3:
		if profile == null or not (profile.earned("waking_stilled") or profile.earned("highdraft_reached")):
			return false
	return true


static func available_crew(profile, sitting := false) -> Array:
	var out: Array = []
	for id in CREW_ORDERS:
		if not completed(id, profile) and unlocked(id, profile, sitting):
			out.append(id)
	return out


static func shift_offers(profile, seed := 0, sitting := false) -> Array:
	var box := _camp_box(profile)
	var stored = box.get("rotation", [])
	var valid: Array = []
	if stored is Array:
		for id in stored:
			var sid := String(id)
			if SHIFT_ORDERS.has(sid) and unlocked(sid, profile, sitting) and not valid.has(sid):
				valid.append(sid)
	if not valid.is_empty():
		return valid.slice(0, ROTATION_OFFERS)
	return _pick_shift_offers(profile, seed, sitting)


static func rotate_shift_offers(profile, seed := 0, sitting := false) -> Array:
	var offers := _pick_shift_offers(profile, seed, sitting)
	if profile != null:
		var box := _camp_box(profile)
		box["rotation"] = offers.duplicate()
		_save_camp_box(profile, box)
	return offers


static func _pick_shift_offers(profile, seed: int, sitting: bool) -> Array:
	var pool: Array = []
	for id in SHIFT_ORDERS:
		if unlocked(id, profile, sitting):
			pool.append(id)
	if pool.size() <= ROTATION_OFFERS:
		return pool
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "shift_offers", pool.size()])
	var copy := pool.duplicate()
	var out: Array = []
	while out.size() < ROTATION_OFFERS and not copy.is_empty():
		var idx := rng.randi_range(0, copy.size() - 1)
		out.append(copy[idx])
		copy.remove_at(idx)
	return out


static func active_ids(profile) -> Array:
	if profile == null:
		return []
	var box := _camp_box(profile)
	var pinned = box.get("pinned", [])
	if not (pinned is Array):
		return []
	var out: Array = []
	var has_crew := false
	var has_shift := false
	for raw in pinned:
		var id := String(raw)
		var row := order(id)
		if row.is_empty():
			continue
		var track := String(row.get("track", ""))
		if track == "crew":
			if has_crew or completed(id, profile):
				continue
			has_crew = true
			out.append(id)
		elif track == "shift":
			if has_shift:
				continue
			has_shift = true
			out.append(id)
		if out.size() >= MAX_ACTIVE:
			break
	return out


static func pin(profile, id: String, sitting := false) -> bool:
	if profile == null:
		return false
	var row := order(id)
	if row.is_empty() or not unlocked(id, profile, sitting):
		return false
	var track := String(row.get("track", ""))
	if track == "crew" and completed(id, profile):
		return false
	var current := active_ids(profile)
	var crew_slot := ""
	var shift_slot := ""
	for existing in current:
		if String(order(existing).get("track", "")) == "crew":
			crew_slot = existing
		else:
			shift_slot = existing
	if track == "crew":
		crew_slot = id
	else:
		shift_slot = id
	var next: Array = []
	if crew_slot != "":
		next.append(crew_slot)
	if shift_slot != "":
		next.append(shift_slot)
	var box := _camp_box(profile)
	box["pinned"] = next
	_save_camp_box(profile, box)
	return true


static func unpin(profile, id: String) -> bool:
	if profile == null:
		return false
	var current := active_ids(profile)
	if not current.has(id):
		return false
	current.erase(id)
	var box := _camp_box(profile)
	box["pinned"] = current
	_save_camp_box(profile, box)
	return true


static func ensure_default_pin(profile, sitting := false, pilot_id := "") -> Array:
	if profile == null:
		return []
	var current := active_ids(profile)
	var has_crew := current.any(func(id): return String(order(id).get("track", "")) == "crew")
	if not has_crew:
		var avail := available_crew(profile, sitting)
		if not avail.is_empty():
			var chosen := String(avail[0])
			if pilot_id != "":
				var for_pilot := avail.filter(func(id): return String(order(id).get("pilot", "")) == pilot_id)
				if not for_pilot.is_empty():
					chosen = String(for_pilot[0])
				else:
					var universal := avail.filter(func(id): return String(order(id).get("pilot", "")) == "")
					if not universal.is_empty():
						chosen = String(universal[0])
			pin(profile, chosen, sitting)
			current = active_ids(profile)
	return current


static func license_stamps(maker: String, profile) -> int:
	if profile == null or not LICENSES.has(maker):
		return 0
	var count := 0
	for id in CREW_ORDERS:
		if String(CREW_ORDERS[id]["maker"]) == maker and completed(id, profile):
			count += 1
	count += int(profile.stat(LICENSE_SHIFT_STAT_PREFIX + maker))
	return count


static func license_tier(maker: String, profile) -> int:
	return clampi(license_stamps(maker, profile), 0, LICENSE_STAMPS_MAX)


static func license_tier_name(tier: int) -> String:
	return LICENSE_TIERS[clampi(tier, 0, LICENSE_STAMPS_MAX)]


static func opened_items(profile, bot_driven := false) -> Array:
	if bot_driven or profile == null:
		return []
	var out: Array = []
	for id in CREW_ORDERS:
		var item := String(CREW_ORDERS[id].get("pays", {}).get("item", ""))
		if item != "" and completed(id, profile) and not out.has(item):
			out.append(item)
	for maker in LICENSES:
		var tier := license_tier(maker, profile)
		for t in range(1, tier + 1):
			var item := String(LICENSES[maker][t].get("pays", {}).get("item", ""))
			if item != "" and not out.has(item):
				out.append(item)
	return out


static func opened_override_codes(profile) -> Array:
	if profile == null:
		return []
	var out: Array = []
	for id in CREW_ORDERS:
		var code := String(CREW_ORDERS[id].get("pays", {}).get("override_code", ""))
		if code != "" and completed(id, profile) and not out.has(code):
			out.append(code)
	return out


static func opened_alt_loadouts(profile) -> Array:
	if profile == null:
		return []
	var out: Array = []
	for id in CREW_ORDERS:
		var alt := String(CREW_ORDERS[id].get("pays", {}).get("alt_loadout", ""))
		if alt != "" and completed(id, profile) and not out.has(alt):
			out.append(alt)
	return out


static func camp_state(profile, sitting := false) -> Dictionary:
	var lic := {}
	for maker in LICENSES:
		var stamps := license_stamps(maker, profile)
		var tier := clampi(stamps, 0, LICENSE_STAMPS_MAX)
		lic[maker] = {"stamps": stamps, "tier": tier, "tier_name": license_tier_name(tier)}
	var done_crew := 0
	for id in CREW_ORDERS:
		if completed(id, profile):
			done_crew += 1
	return {
		"pinned": active_ids(profile),
		"available_crew": available_crew(profile, sitting),
		"shift_offers": shift_offers(profile, 0, sitting),
		"licenses": lic,
		"completed_count": done_crew,
		"total_crew": CREW_ORDERS.size(),
	}


static func begin_run(run, profile, bot_driven := false, sitting := false) -> Dictionary:
	if bot_driven or profile == null or run == null:
		if run != null and "extra" in run and run.extra is Dictionary:
			run.extra.erase(RUN_KEY)
		return {}
	var pilot_id: String = String(run.class_id()) if run.has_method("class_id") else ""
	var pinned := ensure_default_pin(profile, sitting, pilot_id)
	if pinned.is_empty():
		if "extra" in run and run.extra is Dictionary:
			run.extra.erase(RUN_KEY)
		return {}
	var tracker := {
		"pinned": pinned.duplicate(),
		"progress": {},
		"completed": [],
		"took_kindness": false,
	}
	if "extra" in run and run.extra is Dictionary:
		run.extra[RUN_KEY] = tracker
	return tracker


static func eval_fact(tracker: Dictionary, signal_name: String, fact: Dictionary, ctx: Dictionary) -> Array[String]:
	var newly: Array[String] = []
	if tracker.is_empty():
		return newly
	if signal_name == "trade_taken" and String(fact.get("kind", "")) == "trade_safe":
		tracker["took_kindness"] = true
	var pinned: Array = tracker.get("pinned", [])
	var progress: Dictionary = tracker.get("progress", {})
	var done_list: Array = tracker.get("completed", [])
	var took_kindness := bool(tracker.get("took_kindness", false))
	for raw_id in pinned:
		var id := String(raw_id)
		if done_list.has(id):
			continue
		var row := order(id)
		if row.is_empty():
			continue
		var obj: Dictionary = row.get("objective", {})
		if _eval_objective(id, obj, progress, signal_name, fact, ctx, took_kindness):
			done_list.append(id)
			newly.append(id)
	tracker["progress"] = progress
	tracker["completed"] = done_list
	return newly


static func close_run(run, profile, tracker: Dictionary = {}, bot_driven := false, sitting := false) -> Dictionary:
	if bot_driven or profile == null:
		return {"completed": []}
	var live := tracker
	if live.is_empty() and run != null and "extra" in run and run.extra is Dictionary and run.extra.get(RUN_KEY) is Dictionary:
		live = run.extra[RUN_KEY]
	var completed_ids: Array = live.get("completed", []).duplicate()
	if not completed_ids.is_empty():
		var box := _camp_box(profile)
		box["last_completed"] = completed_ids
		var remaining: Array = active_ids(profile).filter(func(id): return not completed_ids.has(id))
		box["pinned"] = remaining
		_save_camp_box(profile, box)
	var rot_seed: int = int(run.run_seed) if run != null and "run_seed" in run else int(profile.stat("habit.runs_total"))
	rotate_shift_offers(profile, rot_seed, sitting)
	return {"completed": completed_ids}


static func _eval_objective(id: String, obj: Dictionary, progress: Dictionary, signal_name: String, fact: Dictionary, ctx: Dictionary, took_kindness: bool) -> bool:
	if obj.has("all"):
		var leaves: Array = obj["all"]
		var all_done := true
		for i in leaves.size():
			var key := "%s#%d" % [id, i]
			if not _eval_leaf(key, leaves[i], progress, signal_name, fact, ctx, took_kindness):
				all_done = false
		return all_done and not leaves.is_empty()
	if obj.has("any"):
		var leaves: Array = obj["any"]
		var any_done := false
		for i in leaves.size():
			var key := "%s?%d" % [id, i]
			if _eval_leaf(key, leaves[i], progress, signal_name, fact, ctx, took_kindness):
				any_done = true
		return any_done
	return _eval_leaf(id, obj, progress, signal_name, fact, ctx, took_kindness)


static func _eval_leaf(key: String, leaf: Dictionary, progress: Dictionary, signal_name: String, fact: Dictionary, ctx: Dictionary, took_kindness: bool) -> bool:
	var need_count := int(leaf.get("count", 1))
	var current := int(progress.get(key, 0))
	if current >= need_count:
		return true
	if String(leaf.get("on", "")) != signal_name:
		return false
	var where: Dictionary = leaf.get("where", {})
	for wkey in where:
		if not fact.has(wkey) or fact[wkey] != where[wkey]:
			return false
	var at_least: Dictionary = leaf.get("at_least", {})
	for akey in at_least:
		var value = fact.get(akey)
		if not (value is int or value is float) or float(value) < float(at_least[akey]):
			return false
	var need: Dictionary = leaf.get("need", {})
	if need.has("world") and int(ctx.get("world", 0)) != int(need["world"]):
		return false
	if need.has("pilot") and String(ctx.get("pilot", "")) != String(need["pilot"]):
		return false
	if need.has("min_tier") and int(ctx.get("run_tier", 0)) < int(need["min_tier"]):
		return false
	if bool(need.get("no_kindness", false)) and took_kindness:
		return false
	current += 1
	progress[key] = current
	return current >= need_count


static func all_signals() -> Array[String]:
	var out: Array[String] = []
	for dict in [CREW_ORDERS, SHIFT_ORDERS]:
		for id in dict:
			_collect_objective_signals(dict[id].get("objective", {}), out)
	if not out.has("trade_taken"):
		out.append("trade_taken")
	return out


static func _collect_objective_signals(obj: Dictionary, out: Array[String]) -> void:
	if obj.has("all"):
		for leaf in obj["all"]:
			_collect_objective_signals(leaf, out)
		return
	if obj.has("any"):
		for leaf in obj["any"]:
			_collect_objective_signals(leaf, out)
		return
	var on := String(obj.get("on", ""))
	if on != "" and not out.has(on):
		out.append(on)


static func _camp_box(profile) -> Dictionary:
	if profile == null:
		return {}
	if profile.has_method("camp_get"):
		var got = profile.camp_get(CAMP_KEY)
		return (got as Dictionary).duplicate(true) if got is Dictionary else {}
	var doc: Dictionary = profile.camp()
	var got = doc.get(CAMP_KEY, {})
	return (got as Dictionary).duplicate(true) if got is Dictionary else {}


static func _save_camp_box(profile, box: Dictionary) -> void:
	if profile == null:
		return
	if profile.has_method("camp_set"):
		profile.camp_set(CAMP_KEY, box)
		return
	var doc: Dictionary = profile.camp()
	doc[CAMP_KEY] = box
	profile.set_camp(doc)


static func _keys(value: Variant, out: Array) -> Array:
	if value is Dictionary:
		for key in value:
			out.append(String(key).to_lower())
			_keys(value[key], out)
	elif value is Array:
		for item in value:
			_keys(item, out)
	return out


static func _has_banned_copy(text: String) -> bool:
	return text.contains("!") or text.contains("...") or text.contains("\u2014") or text.contains("\u2013") or text.contains("\u00b7")


static func validate(
	signal_names: Variant,
	item_ids: Array,
	tune_ids: Array,
	override_ids: Array,
	alt_ids: Array,
	option_ids: Array,
	crew_to_check: Dictionary = CREW_ORDERS,
	shift_to_check: Dictionary = SHIFT_ORDERS,
	licenses_to_check: Dictionary = LICENSES
) -> Array[String]:
	var problems: Array[String] = []
	var sig_map := {}
	if signal_names is Dictionary:
		sig_map = signal_names
	else:
		for s in signal_names:
			sig_map[String(s)] = null
	if crew_to_check.size() != 24:
		problems.append("crew_orders: expected 24 rows, has %d" % crew_to_check.size())
	if shift_to_check.size() != 12:
		problems.append("shift_orders: expected 12 rows, has %d" % shift_to_check.size())
	if licenses_to_check.size() != MakerSets.SETS.size():
		problems.append("licenses: expected %d makers, has %d" % [MakerSets.SETS.size(), licenses_to_check.size()])
	var all_ids := {}
	for id in crew_to_check:
		all_ids[id] = true
	for id in shift_to_check:
		if all_ids.has(id):
			problems.append("%s: duplicate order id across crew and shift" % id)
		all_ids[id] = true
	var items_seen := {}
	for group in [[crew_to_check, "crew"], [shift_to_check, "shift"]]:
		var table: Dictionary = group[0]
		var expected_track: String = group[1]
		for id in table:
			var r = table[id]
			if not (r is Dictionary):
				problems.append("%s: order must be a dictionary" % id)
				continue
			for key in r:
				if not ORDER_FIELDS.has(key):
					problems.append("%s: unknown field %s" % [id, key])
			for key in _keys(r, []):
				for word in BANNED_KEY_WORDS:
					if key.contains(word):
						problems.append("%s: key %s names banned word %s" % [id, key, word])
			var title := str(r.get("name", ""))
			if title == "" or WordBudget.words_in(title) > NAME_WORDS or _has_banned_copy(title):
				problems.append("%s: invalid name %s" % [id, title])
			var text := str(r.get("text", ""))
			if text == "" or WordBudget.words_in(text) > TEXT_WORDS or _has_banned_copy(text):
				problems.append("%s: invalid text %s" % [id, text])
			if str(r.get("track", "")) != expected_track:
				problems.append("%s: track must be %s" % [id, expected_track])
			if not MakerSets.SETS.has(str(r.get("maker", ""))):
				problems.append("%s: unknown maker %s" % [id, r.get("maker", "")])
			var w := int(r.get("world", 0))
			if w < 1 or w > 3:
				problems.append("%s: world must be 1 to 3" % id)
			for req in r.get("requires", []):
				if String(req) == String(id) or not all_ids.has(String(req)):
					problems.append("%s: invalid requires %s" % [id, req])
			_validate_objective(String(id), r.get("objective"), sig_map, problems)
			_validate_pays(String(id), r.get("pays"), item_ids, tune_ids, override_ids, alt_ids, option_ids, items_seen, problems)
	for maker in MakerSets.SETS:
		if not licenses_to_check.has(maker) or not (licenses_to_check[maker] is Dictionary):
			problems.append("license %s: missing maker entry" % maker)
			continue
		var tiers: Dictionary = licenses_to_check[maker]
		for t in [1, 2, 3]:
			if not tiers.has(t) or not (tiers[t] is Dictionary):
				problems.append("license %s tier %d: missing" % [maker, t])
				continue
			var tr: Dictionary = tiers[t]
			for key in _keys(tr, []):
				for word in BANNED_KEY_WORDS:
					if key.contains(word):
						problems.append("license %s:%d: banned key %s" % [maker, t, key])
			var pays = tr.get("pays", {})
			if not (pays is Dictionary) or pays.size() != 1 or not LICENSE_PAY_KINDS.has(pays.keys()[0]):
				problems.append("license %s:%d: pays must carry one of %s" % [maker, t, LICENSE_PAY_KINDS])
				continue
			var kind := String(pays.keys()[0])
			var target := String(pays[kind])
			if kind == "item":
				_validate_item_target("license %s:%d" % [maker, t], target, item_ids, items_seen, problems)
			elif target == "":
				problems.append("license %s:%d: empty plaque target" % [maker, t])
	return problems


static func _validate_objective(id: String, obj: Variant, sig_map: Dictionary, problems: Array[String]) -> void:
	if not (obj is Dictionary) or obj.is_empty():
		problems.append("%s: objective must be a non-empty dictionary" % id)
		return
	if obj.has("all"):
		if not (obj["all"] is Array) or (obj["all"] as Array).is_empty():
			problems.append("%s: objective all must be a non-empty array" % id)
			return
		for leaf in obj["all"]:
			_validate_leaf(id, leaf, sig_map, problems)
		return
	if obj.has("any"):
		if not (obj["any"] is Array) or (obj["any"] as Array).is_empty():
			problems.append("%s: objective any must be a non-empty array" % id)
			return
		for leaf in obj["any"]:
			_validate_leaf(id, leaf, sig_map, problems)
		return
	_validate_leaf(id, obj, sig_map, problems)


static func _validate_leaf(id: String, leaf: Variant, sig_map: Dictionary, problems: Array[String]) -> void:
	if not (leaf is Dictionary):
		problems.append("%s: objective leaf must be a dictionary" % id)
		return
	var on := str(leaf.get("on", ""))
	if not sig_map.has(on):
		problems.append("%s: unknown signal %s" % [id, on])
	var count := int(leaf.get("count", 0))
	if not (leaf.get("count", 0) is int) or count < 1 or count > MAX_COUNT:
		problems.append("%s: count %s must be 1 to %d" % [id, str(leaf.get("count")), MAX_COUNT])
	var args = sig_map.get(on)
	if args is Array:
		for wkey in leaf.get("where", {}):
			if not args.has(wkey):
				problems.append("%s: where key %s is not an arg of %s" % [id, wkey, on])
		for akey in leaf.get("at_least", {}):
			if not args.has(akey):
				problems.append("%s: at_least key %s is not an arg of %s" % [id, akey, on])
	var need = leaf.get("need", {})
	if not (need is Dictionary):
		problems.append("%s: need must be a dictionary" % id)
	else:
		for nkey in need:
			if not NEED_KEYS.has(nkey):
				problems.append("%s: unknown need key %s" % [id, nkey])


static func _validate_pays(
	id: String,
	pays: Variant,
	item_ids: Array,
	tune_ids: Array,
	override_ids: Array,
	alt_ids: Array,
	option_ids: Array,
	items_seen: Dictionary,
	problems: Array[String]
) -> void:
	if not (pays is Dictionary) or pays.size() != 1 or not PAY_KINDS.has(pays.keys()[0]):
		problems.append("%s: pays must carry exactly one of %s" % [id, PAY_KINDS])
		return
	var kind := String(pays.keys()[0])
	var target := String(pays[kind])
	match kind:
		"item":
			_validate_item_target(id, target, item_ids, items_seen, problems)
		"tune":
			if not tune_ids.has(target):
				problems.append("%s: unknown tune %s" % [id, target])
		"option":
			if not option_ids.has(target):
				problems.append("%s: unknown option %s" % [id, target])
		"override_code":
			if not override_ids.has(target):
				problems.append("%s: unknown override_code %s" % [id, target])
		"alt_loadout":
			if not alt_ids.has(target):
				problems.append("%s: unknown alt_loadout %s" % [id, target])
		"license_stamp":
			if not MakerSets.SETS.has(target):
				problems.append("%s: unknown license_stamp maker %s" % [id, target])


static func _validate_item_target(owner: String, target: String, item_ids: Array, items_seen: Dictionary, problems: Array[String]) -> void:
	if not item_ids.has(target) or not Items.TABLE.has(target):
		problems.append("%s: unknown item %s" % [owner, target])
		return
	var row: Dictionary = Items.TABLE[target]
	if row.has("class") or row.has("needs"):
		problems.append("%s: item %s must be universal (no class or needs)" % [owner, target])
	if ParkDefs.part_in_play(target):
		problems.append("%s: item %s is already in ParkDefs.part_in_play" % [owner, target])
	if items_seen.has(target):
		problems.append("%s: item %s already paid by %s" % [owner, target, items_seen[target]])
	else:
		items_seen[target] = owner
