extends RefCounted

const Items := preload("res://src/build/items.gd")
const Palette := preload("res://src/core/palette.gd")
const MakerDefs := preload("res://src/build/maker_defs.gd")

const MICRO_MUTATIONS := {
	"tread_plating": {
		"id": "wall_carve_move_refill",
		"part_id": "tread_plating",
		"name": "Wall-Carve Refill",
		"text": "Wall-carving refills movement 25% faster.",
		"rate_bonus": 0.25,
	},
	"long_spool": {
		"id": "grapple_air_steer_surge",
		"part_id": "long_spool",
		"name": "Release Air Surge",
		"text": "Harpoon release grants 0.4 s air-steer surge.",
		"duration_s": 0.4,
		"steer_mult": 1.65,
	},
	"dash_vane": {
		"id": "air_dash_shell_bat",
		"part_id": "dash_vane",
		"name": "Shell-Bat Dash",
		"text": "Air-dashing through a shell bats it back.",
		"window_s": 0.28,
		"reach_bonus": 0.6,
	},
	"loose_trigger": {
		"id": "cadence_window_extend",
		"part_id": "loose_trigger",
		"name": "Cadence Carry",
		"text": "Landing a skilled window extends the next +25%.",
		"window_extend": 0.25,
	},
	"long_barrel": {
		"id": "long_range_stagger",
		"part_id": "long_barrel",
		"name": "Long-Range Stagger",
		"text": "Hits past 20 m add +15% knockback stagger.",
		"min_range_m": 20.0,
		"knock_bonus": 0.15,
	},
	"boost_coil": {
		"id": "heft_break_cd_refresh",
		"part_id": "boost_coil",
		"name": "Smash Cooldown Cut",
		"text": "Boosting through heft props cuts cooldown 50%.",
		"window_s": 0.5,
		"cd_refresh": 0.5,
	},
}

const FLAT_MICRO_MUTATIONS := {
	"rivet_plating": {
		"id": "hull_shatter_pulse",
		"part_id": "rivet_plating",
		"name": "Rivet Shrapnel",
		"text": "Taking hull damage pulses 4.5 m steel shrapnel.",
		"radius_m": 4.5,
		"damage_base": 14.0,
		"knock": 7.0,
		"cooldown_s": 1.0,
	},
	"magnet_spool": {
		"id": "scrap_whip_arc",
		"part_id": "magnet_spool",
		"name": "Scrap Whip",
		"text": "Every 5th scrap whips an arc spark.",
		"every_scrap": 5,
		"reach_m": 10.0,
		"damage_base": 12.0,
	},
	"grip_tread": {
		"id": "brake_skid_flare",
		"part_id": "grip_tread",
		"name": "Skid Flare",
		"text": "Wall-carving sheds a 2.8 m friction flare.",
		"radius_m": 2.8,
		"damage_base": 12.0,
		"knock": 5.0,
		"cooldown_s": 0.6,
	},
	"live_line": {
		"id": "latch_arc_snap",
		"part_id": "live_line",
		"name": "Latch Snap",
		"text": "Harpoon bites snap a 7 m arc jump.",
		"reach_m": 7.0,
		"damage_base": 16.0,
		"cooldown_s": 0.5,
	},
	"vent_baffle": {
		"id": "boost_exhaust_gust",
		"part_id": "vent_baffle",
		"name": "Exhaust Gust",
		"text": "Boosting vents a 5 m rear steam gust.",
		"radius_m": 5.0,
		"damage_base": 12.0,
		"knock": 9.0,
	},
	"winch_pawl": {
		"id": "winch_haul_jolt",
		"part_id": "winch_pawl",
		"name": "Winch Jolt",
		"text": "Harpoon smashes shock machines within 4.5 m.",
		"radius_m": 4.5,
		"damage_base": 16.0,
		"knock": 7.0,
	},
	"spring_shims": {
		"id": "jump_pad_ripple",
		"part_id": "spring_shims",
		"name": "Spring Ripple",
		"text": "Ground jumps ripple a 4 m shock ring.",
		"radius_m": 4.0,
		"damage_base": 10.0,
		"knock": 6.0,
		"cooldown_s": 0.5,
	},
	"gatling_heart": {
		"id": "spool_overheat_vent",
		"part_id": "gatling_heart",
		"name": "Spool Vent",
		"text": "Every 12th shot vents a 5.5 m blast.",
		"every_shots": 12,
		"radius_m": 5.5,
		"damage_base": 18.0,
		"knock": 6.0,
	},
	"horizon_optic": {
		"id": "far_sight_ping",
		"part_id": "horizon_optic",
		"name": "Far-Sight Ping",
		"text": "Hits past 22 m add a 20% piercing ping.",
		"min_range_m": 22.0,
		"bonus_share": 0.20,
		"cooldown_s": 0.6,
	},
	"ram_plow": {
		"id": "plow_wake_cleave",
		"part_id": "ram_plow",
		"name": "Plow Cleave",
		"text": "Fast rams cleave a 4.5 m steel wake.",
		"radius_m": 4.5,
		"damage_base": 20.0,
		"knock": 9.0,
		"min_tier": 2,
		"cooldown_s": 0.4,
	},
}

const GRAPPLE_MUTATION_PREFIX := "grapple_mut:"
const GRAPPLE_SWAP_SLOTS := ["head", "line", "drive"]
const GRAPPLE_MUT_MODEL_DIR := "res://assets/models/grapple_muts/"

const GRAPPLE_MUTATIONS := {
	"hot_wire": {
		"id": "hot_wire",
		"part_id": "grapple_mut:hot_wire",
		"name": "Hot-Wire Arc Cutter",
		"family": "heat",
		"tags": ["heat"],
		"swaps": "line",
		"maker": "spillway_works",
		"asset_id": "grapple_mut_hot_wire_line",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_hot_wire_line.glb",
		"color": Palette.AMBER,
		"uses_amber_glow": true,
		"actuator_bones": [],
		"text": "Taut amber line slices enemies, boom floats, and Tier 1-2 props.",
		"line_width_m": 1.6,
		"damage_base": 24.0,
		"max_destructible_tier": 2,
		"float_reach_m": 2.2,
		"hit_cooldown_s": 0.35,
	},
	"det_cord": {
		"id": "det_cord",
		"part_id": "grapple_mut:det_cord",
		"name": "Det-Cord Line",
		"family": "burst",
		"tags": ["split"],
		"swaps": "line",
		"maker": "redjaw",
		"asset_id": "grapple_mut_det_cord_line",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_det_cord_line.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": [],
		"text": "Release detonates sequenced shaped charges down the tether path.",
		"spacing_m": 3.5,
		"max_nodes": 6,
		"step_delay_s": 0.06,
		"blast_radius_m": 4.2,
		"damage_base": 22.0,
		"knock": 9.0,
		"tier_bonus": 1,
	},
	"dragnet_siphon": {
		"id": "dragnet_siphon",
		"part_id": "grapple_mut:dragnet_siphon",
		"name": "Dragnet Siphon",
		"family": "salvage",
		"tags": ["mass"],
		"swaps": "head",
		"maker": "moss",
		"asset_id": "grapple_mut_dragnet_siphon_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_dragnet_siphon_head.glb",
		"color": Palette.STEEL,
		"uses_amber_glow": false,
		"actuator_bones": ["mouth"],
		"text": "Tether span vacuums scrap, cogs, and pocket consumables within 5 m.",
		"vacuum_radius_m": 5.0,
		"pull_speed": 26.0,
	},
	"sonic_snap_sling": {
		"id": "sonic_snap_sling",
		"part_id": "grapple_mut:sonic_snap_sling",
		"name": "Sonic Snap-Sling",
		"family": "speed",
		"tags": ["speed"],
		"swaps": "drive",
		"maker": "highdraft_roosts",
		"asset_id": "grapple_mut_sonic_snap_sling_drive",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_sonic_snap_sling_drive.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": ["pawl"],
		"text": "Pendulum apex release grants +12 m/s Blazing burst and Air-Jump.",
		"burst_speed": 12.0,
		"apex_vy_tol": 6.5,
		"min_drop_m": 0.5,
		"min_swing_s": 0.05,
	},
	"live_bus": {
		"id": "live_bus",
		"part_id": "grapple_mut:live_bus",
		"name": "Live-Bus Conductor",
		"family": "arc",
		"tags": ["arc", "chain"],
		"swaps": "head",
		"maker": "mind_glass",
		"asset_id": "grapple_mut_live_bus_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_live_bus_head.glb",
		"color": Palette.AMBER,
		"uses_amber_glow": true,
		"actuator_bones": ["jaw.0", "jaw.1"],
		"text": "Latching powered world props charges next strike with amber bus current.",
		"bonus_mult": 1.65,
		"bonus_flat": 24.0,
		"charge_duration_s": 8.0,
		"arc_radius_m": 8.0,
	},
	"tether_slam": {
		"id": "tether_slam",
		"part_id": "grapple_mut:tether_slam",
		"name": "Tether-Slam Clutch",
		"family": "pull",
		"tags": ["kinetic"],
		"swaps": "drive",
		"maker": "waking",
		"asset_id": "grapple_mut_tether_slam_drive",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_tether_slam_drive.glb",
		"color": Palette.COPPER,
		"uses_amber_glow": false,
		"actuator_bones": [],
		"text": "Smash while tethered yanks both ends to mid-point for 2x crush.",
		"crush_mult": 2.0,
		"slam_radius_m": 8.0,
		"damage_base": 32.0,
		"knock": 16.0,
		"yank_speed": 24.0,
		"armed_window_s": 1.2,
	},
	"wrecking_flail": {
		"id": "wrecking_flail",
		"part_id": "grapple_mut:wrecking_flail",
		"name": "Wrecking Flail",
		"family": "mass",
		"tags": ["mass"],
		"swaps": "head",
		"maker": "fleet_surplus",
		"asset_id": "grapple_mut_wrecking_flail_head",
		"glb_path": GRAPPLE_MUT_MODEL_DIR + "grapple_mut_wrecking_flail_head.glb",
		"color": Palette.STEEL,
		"uses_amber_glow": false,
		"actuator_bones": ["flail"],
		"text": "Taut swing through Heft props or armor adds +1 effective Heft tier.",
		"heft_bonus": 1,
		"armor_shred_bonus": 25.0,
		"swing_reach_m": 3.2,
		"min_speed": 8.0,
	},
}


static func micro_mutation(part_id: String) -> Dictionary:
	if MICRO_MUTATIONS.has(part_id):
		return (MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true)
	if FLAT_MICRO_MUTATIONS.has(part_id):
		return (FLAT_MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true)
	return {}


static func micro_mutation_ids() -> Array:
	return MICRO_MUTATIONS.keys()


static func all_micro_mutation_ids() -> Array:
	return MICRO_MUTATIONS.keys() + FLAT_MICRO_MUTATIONS.keys()


static func has_micro_mutation(held: Array, part_id: String) -> bool:
	return (MICRO_MUTATIONS.has(part_id) or FLAT_MICRO_MUTATIONS.has(part_id)) and part_id in held


static func active_micro_mutations(held: Array) -> Array:
	var out: Array = []
	for part_id in MICRO_MUTATIONS:
		if part_id in held:
			out.append((MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true))
	for part_id in FLAT_MICRO_MUTATIONS:
		if part_id in held:
			out.append((FLAT_MICRO_MUTATIONS[part_id] as Dictionary).duplicate(true))
	return out


static func micro_mutation_problems(catalogue: Dictionary) -> Array:
	var found: Array = []
	for part_id in MICRO_MUTATIONS:
		if not catalogue.has(part_id):
			found.append("%s is not in CATALOGUE" % part_id)
			continue
		var cat: Dictionary = catalogue[part_id]
		if String(cat.get("rarity", "")) != "common" or int(cat.get("tier", 0)) != 1:
			found.append("%s must stay a Tier-1 common part" % part_id)
		var row: Dictionary = MICRO_MUTATIONS[part_id]
		for key in ["id", "part_id", "name", "text"]:
			if String(row.get(key, "")).strip_edges().is_empty():
				found.append("%s micro-mutation missing %s" % [part_id, key])
		if String(row.get("part_id", "")) != part_id:
			found.append("%s micro-mutation part_id mismatch" % part_id)
	return found


static func all_micro_mutation_problems(catalogue: Dictionary) -> Array:
	var found := micro_mutation_problems(catalogue)
	var seen_ids := {}
	for pid in MICRO_MUTATIONS:
		seen_ids[String(MICRO_MUTATIONS[pid]["id"])] = pid
	for part_id in FLAT_MICRO_MUTATIONS:
		if not catalogue.has(part_id):
			found.append("%s is not in CATALOGUE" % part_id)
			continue
		var row: Dictionary = FLAT_MICRO_MUTATIONS[part_id]
		for key in ["id", "part_id", "name", "text"]:
			if String(row.get(key, "")).strip_edges().is_empty():
				found.append("%s flat micro-mutation missing %s" % [part_id, key])
		if String(row.get("part_id", "")) != part_id:
			found.append("%s flat micro-mutation part_id mismatch" % part_id)
		var mid := String(row.get("id", ""))
		if seen_ids.has(mid):
			found.append("%s duplicate micro-mutation id %s" % [part_id, mid])
		seen_ids[mid] = part_id
	return found


static func grapple_mutation_ids() -> Array:
	return GRAPPLE_MUTATIONS.keys()


static func is_grapple_mutation_part(part_id: String) -> bool:
	return part_id.begins_with(GRAPPLE_MUTATION_PREFIX) and GRAPPLE_MUTATIONS.has(part_id.substr(GRAPPLE_MUTATION_PREFIX.length()))


static func grapple_mutation_id_of(part_id: String) -> String:
	if GRAPPLE_MUTATIONS.has(part_id):
		return part_id
	if part_id.begins_with(GRAPPLE_MUTATION_PREFIX):
		var stripped := part_id.substr(GRAPPLE_MUTATION_PREFIX.length())
		return stripped if GRAPPLE_MUTATIONS.has(stripped) else ""
	var from_item := Items.grapple_mutation_of(part_id)
	return from_item if GRAPPLE_MUTATIONS.has(from_item) else ""


static func grapple_mutation(id_or_part: String) -> Dictionary:
	var mid := grapple_mutation_id_of(id_or_part)
	if mid == "":
		return {}
	return (GRAPPLE_MUTATIONS[mid] as Dictionary).duplicate(true)


static func grapple_mut_spec(part_id: String) -> Dictionary:
	var m := grapple_mutation(part_id)
	if m.is_empty():
		return {}
	return {"name": String(m["name"]), "verb": String(m["text"]), "text": String(m["text"]),
		"tags": (m["tags"] as Array).duplicate(), "maker": String(m.get("maker", "")),
		"rarity": "rare", "tier": 2, "family": "mobility", "icon": "mobility",
		"cap": 1, "stack": "capped"}


static func active_grapple_mutations(held: Array, maker_muts: Array, maker_counts_fn: Callable) -> Dictionary:
	var by_slot := {}
	var makers_to_check := maker_muts
	if makers_to_check.is_empty() and not held.is_empty():
		makers_to_check = MakerDefs.live_grapple_mutations_from(maker_counts_fn.call(held))
	for mid in makers_to_check:
		if GRAPPLE_MUTATIONS.has(mid):
			var row: Dictionary = GRAPPLE_MUTATIONS[mid]
			by_slot[String(row["swaps"])] = row.duplicate(true)
	for raw_id in held:
		var mid := grapple_mutation_id_of(String(raw_id))
		if mid != "":
			var row: Dictionary = GRAPPLE_MUTATIONS[mid]
			by_slot[String(row["swaps"])] = row.duplicate(true)
	return by_slot


static func has_grapple_mutation(held: Array, mut_id: String, maker_muts: Array, maker_counts_fn: Callable) -> bool:
	var mid := grapple_mutation_id_of(mut_id)
	if mid == "":
		return false
	var active := active_grapple_mutations(held, maker_muts, maker_counts_fn)
	for slot in active:
		if String(active[slot]["id"]) == mid:
			return true
	return false


static func grapple_mutation_problems() -> Array:
	var found: Array = []
	var allowed := [Palette.AMBER, Palette.COPPER, Palette.STEEL, Palette.SAND, Palette.VERDIGRIS]
	for mid in GRAPPLE_MUTATIONS:
		var row: Dictionary = GRAPPLE_MUTATIONS[mid]
		if String(row.get("id", "")) != mid:
			found.append("%s id mismatch" % mid)
		if not String(row.get("swaps", "")) in GRAPPLE_SWAP_SLOTS:
			found.append("%s swaps invalid slot %s" % [mid, row.get("swaps", "")])
		if String(row.get("glb_path", "")).strip_edges().is_empty():
			found.append("%s missing glb_path" % mid)
		var col: Color = row.get("color", Color.BLACK)
		var ok := false
		for a: Color in allowed:
			if col.is_equal_approx(a):
				ok = true
				break
		if not ok:
			found.append("%s uses disallowed colour" % mid)
		if mid in ["hot_wire", "live_bus"] and not col.is_equal_approx(Palette.AMBER):
			found.append("%s must use Palette.AMBER" % mid)
	return found
