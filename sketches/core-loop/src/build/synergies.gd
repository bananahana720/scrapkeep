extends RefCounted

# Maker tricks and evolutions: the build's combination rules (systems audit pass D, fold 2;
# Andrew 11 Nov 2026). There is one set rule a player learns: parts of one maker (maker_sets.gd).
# Two distinct pieces of one maker wake its trick, a rule change below; three turn on its set
# bonus (maker_bonuses.gd). The tricks are the rule changes the named synergies (hidden tag
# pairs) and the three-part sets (a second member list) used to make, moved onto the makers so
# none of them is a hidden list any more. Each row names its maker; a maker has one or two.
#
# Each trick changes behaviour, never just a number. Its effects are transformer ids (build or
# combat act on them), pattern levels, element triggers and dials, folded in by build_sheet.gd.
# A trick is derived from the part list, never held, so a retry that restores the list restores
# the tricks. `tags` are the trick's glyphs (EventKinds.cause_glyphs, accretion); `callout` is
# what the why callout draws when it fires: two of the maker's parts as icons, then three words.
# A trick with transformers is discovered on its first firing (build.gd _fire). One that only
# adds an element to an action (a former three-part set) is told when it wakes: a banner in its
# `color` and a chime in its element (presentation.gd, build.gd set_completed).
#
# This file works on maker counts (maker -> distinct pieces held, Parts.maker_counts), so it
# never needs the catalogue. declarations() is the codex card data (category "build").
#
# Evolutions stay part pairs: both ingredients held and the run gains the Evolved part once
# (build.gd). An Evolved part gives nothing while an ingredient is missing.

const Palette := preload("res://src/core/palette.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")

const CATEGORY := "build"
# Distinct pieces of one maker that wake its trick. The maker's set bonus needs its own count
# (MakerSets.SETS[maker]["pieces"], three for every maker but Moss).
const AT := 2

# The stage table the build runs on, set by the build at setup. A table's
# synergy_in_play(id) names the tricks it keeps; null keeps them all.
static var table = null

const ROWS := {
	# Spillway Works: the dam's ice road.
	"ballast_rig": {
		"name": "Ballast Rig", "maker": "spillway_works", "tags": ["frost"], "color": Palette.RUST,
		"text": "Your dash trails frost that freezes water into road.",
		"elements": {"dash": "frost"},
	},
	"shatter_crew": {
		"name": "Shatter Crew", "maker": "spillway_works", "tags": ["frost", "kinetic"], "color": Palette.COPPER,
		"text": "Shots freeze water where they land, and ice you shatter hits harder.",
		"elements": {"shot": "frost"}, "dials": {"shatter_damage": 1.5},
	},
	# Fleet Surplus: heavy hull, hard rams.
	"wrecking_ball": {
		"name": "Wrecking Ball", "maker": "fleet_surplus", "tags": ["speed", "kinetic"],
		"text": "Rams send out a shockwave that hits everything around the target.",
		"transformers": ["wrecking_ball"],
		"callout": {"a": "double_feed", "b": "hot_rivets", "words": "Rams carry through"},
	},
	"glacier_hull": {
		"name": "Glacier Hull", "maker": "fleet_surplus", "tags": ["mass", "frost"],
		"text": "Hard landings crack out a frost ring that hits machines near you and freezes water.",
		"transformers": ["glacier_hull"],
		"callout": {"a": "slag_rounds", "b": "rivet_plating", "words": "Landings ring cold"},
	},
	# Redjaw Workshops: teeth and splinters.
	"shrapnel_bloom": {
		"name": "Shrapnel Bloom", "maker": "redjaw", "tags": ["split", "kinetic"],
		"text": "Kills burst into shrapnel that hits up to three machines nearby.",
		"transformers": ["shrapnel_bloom"],
		"callout": {"a": "cross_split", "b": "pin_setter", "words": "Kills come apart"},
	},
	"storm_lattice": {
		"name": "Storm Lattice", "maker": "redjaw", "tags": ["chain", "split"],
		"text": "Every fragment of a cross split jumps to a neighbour.",
		"transformers": ["storm_lattice"], "patterns": {"chain_arc": 1},
		"callout": {"a": "cross_split", "b": "hairline_fracture", "words": "Bolts find neighbours"},
	},
	# Mind-glass: the Mind's live current.
	"tesla_pylon": {
		"name": "Tesla Pylon", "maker": "mind_glass", "tags": ["anchor", "arc"],
		"text": "While mounted or hooked, arcs leap from you to the two nearest machines twice a second.",
		"transformers": ["tesla_pylon"],
		"callout": {"a": "focus_lens", "b": "live_line", "words": "Hooked means live"},
	},
	"live_wire": {
		"name": "Live Wire", "maker": "mind_glass", "tags": ["arc"], "color": Palette.ARC,
		"text": "Every slam bursts an arc, and shots spark where they land.",
		"elements": {"slam": "arc", "shot": "arc"},
	},
	# Highdraft Roosts: speed and air.
	"pinwheel": {
		"name": "Pinwheel", "maker": "highdraft_roosts", "tags": ["spiral", "speed"],
		"text": "At fast speed and above you spin a blade ring that cuts the machines you pass.",
		"transformers": ["pinwheel"],
		"callout": {"a": "loose_trigger", "b": "long_barrel", "words": "Speed grows blades"},
	},
	"hair_trigger": {
		"name": "Hair Trigger", "maker": "highdraft_roosts", "tags": ["arc", "speed"], "color": Palette.AMBER,
		"text": "Your dash trails arc that electrifies water.",
		"elements": {"dash": "arc"},
	},
	# Waking-made: the ground answers.
	"storm_front": {
		"name": "Storm Front", "maker": "waking", "tags": ["frost", "mass"], "color": Palette.SLATE,
		"text": "Every slam cracks out a frost ring that freezes water and lays ice.",
		"elements": {"slam": "frost"},
	},
	"thermal_shock": {
		"name": "Thermal Shock", "maker": "waking", "tags": ["frost", "arc"],
		"text": "A slam's arc shatters nearby ice into a shard nova at double damage, then fresh ice freezes around you.",
		"transformers": ["thermal_shock"], "elements": {"slam": ["arc", "frost"]}, "dials": {"shatter_damage": 2.0},
		"callout": {"a": "spiral_wave", "b": "echo_locator", "words": "Ice cracks loud"},
	},
	"linked_spiral": {
		"name": "Linked Spiral", "maker": "waking", "tags": ["spiral", "chain"],
		"text": "A spiral carrying chain links its arcs into a ring.",
		"transformers": ["linked_spiral"], "found": "A spiral carrying chain links its arcs into a ring.",
		"callout": {"a": "spiral_wave", "b": "brace_frame", "words": "Spirals link up"},
	},
	# Moss's Spares: scrap that bites back.
	"lightning_rod": {
		"name": "Lightning Rod", "maker": "moss", "tags": ["arc", "mass"],
		"text": "Every piece of scrap you pick up sparks an arc at the nearest machine.",
		"transformers": ["lightning_rod"],
		"callout": {"a": "arc_coil", "b": "drop_weight", "words": "Scrap sparks back"},
	},
}

# Evolved part -> its two ingredient parts (Parts.EVOLVED holds the Evolved rows).
const EVOLUTIONS := {
	"breaker_drive": ["double_feed", "hot_rivets"],
	"bladestorm_rotor": ["spiral_wave", "loose_trigger"],
	"storm_mast": ["focus_lens", "live_line"],
	"grounding_spike": ["arc_coil", "drop_weight"],
	"grapeshot_press": ["cross_split", "pin_setter"],
	"hoar_barrel": ["frost_barb", "rime_rounds"],
	"fault_hammer": ["echo_locator", "brace_frame"],
}
# The trick each evolution grew out of, the name its text ends on ("From Wrecking Ball.").
const EVOLVED_FROM := {
	"breaker_drive": "wrecking_ball",
	"bladestorm_rotor": "pinwheel",
	"storm_mast": "tesla_pylon",
	"grounding_spike": "lightning_rod",
	"grapeshot_press": "shrapnel_bloom",
	"hoar_barrel": "shatter_crew",
	"fault_hammer": "thermal_shock",
}

# W50-ISAAC-PARTS: 3 additional verb-changing evolutions with strictly disjoint ingredient pairs
# (zero overlap with EVOLUTIONS' 14 ingredients or each other). Kept beside EVOLUTIONS so existing
# 7-row pins stay intact while runtime evolution helpers merge all 10 cleanly.
const EVOLUTIONS_W50 := {
	"gyro_foundry": ["orbital_flywheel", "basalt_ram"],
	"arc_prism": ["prism_splitter", "galvanic_rounds"],
	"whiplash_spool": ["boomerang_spool", "long_leash"],
}
const EVOLVED_FROM_W50 := {
	"gyro_foundry": "storm_front",
	"arc_prism": "live_wire",
	"whiplash_spool": "lightning_rod",
}


static func all_evolutions() -> Dictionary:
	var out := EVOLUTIONS.duplicate(true)
	for into in EVOLUTIONS_W50:
		out[into] = (EVOLUTIONS_W50[into] as Array).duplicate()
	return out


static func all_evolved_from() -> Dictionary:
	var out := EVOLVED_FROM.duplicate(true)
	for into in EVOLVED_FROM_W50:
		out[into] = EVOLVED_FROM_W50[into]
	return out


# True when the table in use keeps this trick.
static func in_play(trick_id: String) -> bool:
	return table == null or table.synergy_in_play(trick_id)


# The tricks a maker carries that the table keeps, in row order.
static func of_maker(maker: String) -> Array:
	return ROWS.keys().filter(func(key): return ROWS[key]["maker"] == maker and in_play(key))


# The tricks awake for these maker counts (maker -> distinct pieces), in row order.
static func active(counted: Dictionary) -> Array:
	return ROWS.keys().filter(func(key): return in_play(key) and int(counted.get(ROWS[key]["maker"], 0)) >= AT)


# The first trick one more distinct piece of `maker` would wake, or "".
static func completed_by(counted: Dictionary, maker: String) -> String:
	if maker == "" or int(counted.get(maker, 0)) != AT - 1:
		return ""
	var tricks := of_maker(maker)
	return tricks[0] if not tricks.is_empty() else ""


# The first trick a first distinct piece of `maker` starts toward, or "" (the lens perk names it).
static func started_by(counted: Dictionary, maker: String) -> String:
	if maker == "" or int(counted.get(maker, 0)) != 0:
		return ""
	var tricks := of_maker(maker)
	return tricks[0] if not tricks.is_empty() else ""


# True for a trick that only adds elements to actions: told when it wakes, not when it fires.
static func told_on_wake(trick_id: String) -> bool:
	return ROWS.has(trick_id) and ROWS[trick_id].get("transformers", []).is_empty()


# The element a trick's rule adds first, "frost" or "arc", or "": what its chime rings in.
static func element(trick_id: String) -> String:
	var elements: Dictionary = ROWS.get(trick_id, {}).get("elements", {})
	if elements.is_empty():
		return ""
	var first = elements.values()[0]
	return String(first[0] if first is Array else first)


static func callout(trick_id: String) -> Dictionary:
	return ROWS.get(trick_id, {}).get("callout", {})


# Codex cards, one per trick in play: {id, category, name, hint, clue, text, maker, tags}.
# maker_name turns a maker id into its display name; the hint says what wakes it, the clue the
# piece still to find.
static func declarations(maker_name: Callable) -> Array:
	var cards: Array = []
	for key in ROWS:
		if not in_play(key):
			continue
		var row: Dictionary = ROWS[key]
		cards.append({
			"id": key,
			"category": CATEGORY,
			"name": row["name"],
			"hint": "Two %s parts" % maker_name.call(row["maker"]),
			"clue": "Another %s part" % maker_name.call(row["maker"]),
			"text": row["text"],
			"maker": row["maker"],
			"tags": row["tags"],
		})
	return cards


# The Evolved parts that should be gained now: both ingredients held, the Evolved part not.
static func evolutions_ready(held: Array) -> Array:
	var all := all_evolutions()
	return all.keys().filter(func(into): return not into in held and _holds_all(held, all[into]))


# True while an Evolved part's ingredients are both held; an Evolved part gives nothing otherwise.
# True for any part that is not an Evolved part.
static func evolution_live(part_id: String, held: Array) -> bool:
	var all := all_evolutions()
	return not all.has(part_id) or _holds_all(held, all[part_id])


# True while the run holds this Evolved part and both its ingredients: the one call combat makes
# before an evolution rewrites a verb (design-v3/ABILITY-MUTATIONS.md section 7 D).
static func evolved_live(part_id: String, held: Array) -> bool:
	var all := all_evolutions()
	return all.has(part_id) and part_id in held and _holds_all(held, all[part_id])


# The trick an Evolved part grew out of, or "".
static func evolution_of(part_id: String) -> String:
	if EVOLVED_FROM.has(part_id):
		return EVOLVED_FROM[part_id]
	return EVOLVED_FROM_W50.get(part_id, "")


# True for an Evolved part or one of its ingredients.
static func in_evolution(part_id: String) -> bool:
	var all := all_evolutions()
	return all.has(part_id) or all.values().any(func(pair): return part_id in pair)


# Admission for an evolution table (Elements.problems' shape): every pair is two distinct parts
# `known` answers true for, no part sits in two pairs or is itself an Evolved part, and each
# Evolved part names the trick it grew out of. Returns one line per problem; [] is clean.
static func evolution_problems(table: Dictionary, grew_from: Dictionary, known: Callable) -> Array:
	var found: Array = []
	var owner := {}
	for into in table:
		var pair: Array = table[into]
		if pair.size() != 2 or pair[0] == pair[1]:
			found.append("%s is not a pair of two different parts" % into)
		for part_id in pair:
			if not known.call(part_id):
				found.append("%s names an unknown ingredient %s" % [into, part_id])
			if table.has(part_id):
				found.append("%s takes the Evolved part %s as an ingredient" % [into, part_id])
			if owner.has(part_id) and owner[part_id] != into:
				found.append("%s shares the ingredient %s with %s" % [into, part_id, owner[part_id]])
			owner[part_id] = into
		if not ROWS.has(String(grew_from.get(into, ""))):
			found.append("%s names no trick it grew out of" % into)
	return found


static func _holds_all(held: Array, parts: Array) -> bool:
	return parts.all(func(part_id): return part_id in held)


# --- W47-C2: Cross-system build-blossoming synergies (NORTHSTAR §4.4, REBASELINE §7) ---
# Separate from the 14 maker tricks in ROWS so maker-set counts, AlphaDefs/ParkDefs tables and
# single-maker callouts stay untouched. Each row pairs two distinct build systems and fires in
# combat at proc depth 1 (SYNERGY / item_proc, bits 0).
const CROSS_SYSTEM := {
	"demolition_derby": {
		"name": "Demolition Derby",
		"systems": ["mass", "speed"],
		"tags": ["mass", "speed"],
		"color": Palette.AMBER,
		"text": "Shattering heft props fires a 12 m debris shockwave and refills boost.",
		"radius_m": 12.0,
		"damage_base": 24.0,
		"knock": 10.0,
	},
	"pendulum_tesla": {
		"name": "Pendulum Tesla",
		"systems": ["anchor", "arc"],
		"tags": ["anchor", "arc"],
		"color": Palette.ARC,
		"text": "A taut harpoon cable zaps swept machines and charges special +15% per swing.",
		"cable_width_m": 1.8,
		"damage_base": 18.0,
		"special_charge_share": 0.15,
	},
	"ricochet_canyon": {
		"name": "Ricochet Canyon",
		"systems": ["bounce", "split"],
		"tags": ["bounce", "split"],
		"color": Palette.COPPER,
		"text": "Firing while wall-carving adds +2 wall bounces and curves shards toward machines.",
		"extra_bounces": 2,
		"home_reach_m": 26.0,
		"home_turn": 0.75,
	},
	"thermobaric_dunk": {
		"name": "Thermobaric Dunk",
		"systems": ["heat", "kinetic"],
		"tags": ["heat", "kinetic"],
		"color": Palette.RUST,
		"text": "Air-slamming a heated machine launches nearby machines skyward to detonate on impact.",
		"launch_radius_m": 10.0,
		"launch_speed": 14.0,
		"detonate_radius_m": 6.5,
		"detonate_damage": 28.0,
		"pin_timeout_s": 1.6,
	},
	"gravity_ledger": {
		"name": "Gravity Ledger",
		"systems": ["pull", "mass"],
		"tags": ["pull", "mass"],
		"color": Palette.VERDIGRIS,
		"text": "Pulling two or more machines together crushes them for bonus damage and drops cogs.",
		"cluster_radius_m": 5.5,
		"crush_damage": 22.0,
		"cog_count": 3,
		"cooldown_s": 0.35,
	},
	"catalyst_cartridge": {
		"name": "Catalyst Cartridge",
		"systems": ["consumable", "active"],
		"tags": ["consumable", "active"],
		"color": Palette.SAND,
		"text": "Using a pocket consumable adds +40% active charge and fires a free visual burst ring.",
		"active_charge_gain": 0.40,
		"burst_radius_m": 8.0,
	},
}

# --- W50-ISAAC-PARTS: 6 additional cross-system synergies (6 -> 12 total) ---
# Kept beside CROSS_SYSTEM so synergies_test.gd's 6-row W47 pin stays untouched while all runtime
# evaluators (cross_system_active, cross_system_awake, cross_system_row, cross_system_problems)
# operate seamlessly across all 12 rows.
const CROSS_SYSTEM_W50 := {
	"overclocked_circuit": {
		"name": "Overclocked Circuit",
		"systems": ["speed", "arc"],
		"tags": ["speed", "arc"],
		"color": Palette.ARC,
		"text": "Fast speed overcharges weapon hits into a 9 m arc circuit burst.",
		"radius_m": 9.0,
		"damage_base": 20.0,
		"cooldown_s": 0.45,
		"min_tier": 2,
	},
	"orbital_furnace": {
		"name": "Orbital Furnace",
		"systems": ["orbital", "heat"],
		"tags": ["spiral", "arc"],
		"color": Palette.COPPER,
		"text": "Orbiting satellites scorch struck machines and widen molten slag zones.",
		"bonus_damage_mult": 1.45,
		"slag_radius_bonus": 1.5,
	},
	"scrap_magnetron": {
		"name": "Scrap Magnetron",
		"systems": ["magnet", "arc"],
		"tags": ["mass", "arc"],
		"color": Palette.VERDIGRIS,
		"text": "Every 4th scrap or cog pickup fires an 8 m magnetic arc ring.",
		"pickup_threshold": 4,
		"radius_m": 8.0,
		"damage_base": 22.0,
		"cooldown_s": 0.50,
	},
	"railgun_ricochet": {
		"name": "Railgun Ricochet",
		"systems": ["pierce", "bounce"],
		"tags": ["kinetic", "chain"],
		"color": Palette.LEDGER,
		"text": "Bounced piercing bolts accelerate +40% and strike +35% harder.",
		"speed_mult": 1.40,
		"damage_mult": 1.35,
		"max_stacks": 2,
	},
	"ghost_conductor": {
		"name": "Ghost Conductor",
		"systems": ["husk", "arc"],
		"tags": ["arc", "chain"],
		"color": Palette.AMBER,
		"text": "Raised husks tether amber arcs to the ball that zap crossed machines.",
		"link_width_m": 1.8,
		"damage_base": 18.0,
		"tick_cooldown_s": 0.50,
		"max_links": 4,
	},
	"heavy_dividend": {
		"name": "Heavy Dividend",
		"systems": ["burden", "mass"],
		"tags": ["mass", "kinetic"],
		"color": Palette.BRASS,
		"text": "Held burdens and high heft add +12% hit payout per burden, up to +60%.",
		"per_burden": 0.12,
		"cap_bonus": 0.60,
		"slam_radius_bonus": 2.0,
	},
}


static func all_cross_system() -> Dictionary:
	var out := CROSS_SYSTEM.duplicate(true)
	for key in CROSS_SYSTEM_W50:
		out[key] = (CROSS_SYSTEM_W50[key] as Dictionary).duplicate(true)
	return out


static func cross_system_ids(include_w50 := true) -> Array:
	return (CROSS_SYSTEM.keys() + CROSS_SYSTEM_W50.keys()) if include_w50 else CROSS_SYSTEM.keys()


static func cross_system_row(id: String) -> Dictionary:
	if CROSS_SYSTEM.has(id):
		return (CROSS_SYSTEM[id] as Dictionary).duplicate(true)
	if CROSS_SYSTEM_W50.has(id):
		return (CROSS_SYSTEM_W50[id] as Dictionary).duplicate(true)
	return {}


# Cross-system synergies awake for `held` (part id list), `part_info` (Callable(part_id) -> {tags, bits}),
# and runtime `context` ({heft_class, mass, has_consumable, has_active, has_pull, has_husk, burden_count, ...}), in row order.
static func cross_system_active(held: Array, part_info: Callable, context := {}) -> Array:
	var out: Array = []
	for id in cross_system_ids(true):
		if cross_system_awake(id, held, part_info, context):
			out.append(id)
	return out


static func cross_system_awake(id: String, held: Array, part_info: Callable, context := {}) -> bool:
	var row: Dictionary = cross_system_row(id)
	if row.is_empty():
		return false
	var systems: Array = row.get("systems", [])
	if systems.size() != 2:
		return false
	return _pair_awake(String(systems[0]), String(systems[1]), held, part_info, context)


static func cross_system_declarations(include_w50 := false) -> Array:
	var source: Dictionary = all_cross_system() if include_w50 else CROSS_SYSTEM
	var cards: Array = []
	for key in source:
		var row: Dictionary = source[key]
		var systems: Array = row["systems"]
		cards.append({
			"id": key,
			"category": CATEGORY,
			"name": row["name"],
			"hint": "%s + %s" % [String(systems[0]).capitalize(), String(systems[1]).capitalize()],
			"clue": "Pair %s with %s" % [String(systems[0]), String(systems[1])],
			"text": row["text"],
			"systems": systems.duplicate(),
			"tags": row["tags"].duplicate(),
		})
	return cards


static func all_cross_system_declarations() -> Array:
	return cross_system_declarations(true)


static func cross_system_problems() -> Array:
	var found: Array = []
	var pairs := {}
	var all := all_cross_system()
	for id in all:
		var row: Dictionary = all[id]
		for key in ["name", "text", "systems", "tags", "color"]:
			if not row.has(key):
				found.append("%s missing %s" % [id, key])
		var systems: Array = row.get("systems", [])
		if systems.size() != 2 or String(systems[0]) == String(systems[1]):
			found.append("%s must pair two distinct systems" % id)
		else:
			var a := String(systems[0])
			var b := String(systems[1])
			var pk := (a + "+" + b) if a < b else (b + "+" + a)
			if pairs.has(pk):
				found.append("%s duplicates system pair %s of %s" % [id, pk, pairs[pk]])
			pairs[pk] = id
		if String(row.get("text", "")).strip_edges().is_empty():
			found.append("%s has empty text" % id)
	return found


static func _pair_awake(sys_a: String, sys_b: String, held: Array, part_info: Callable, context: Dictionary) -> bool:
	var ctx_a := _context_has_system(sys_a, context)
	var ctx_b := _context_has_system(sys_b, context)
	if ctx_a and ctx_b:
		return true
	var parts_a := {}
	var parts_b := {}
	var seen := {}
	for raw_id in held:
		var part_id := String(raw_id)
		if seen.has(part_id):
			continue
		seen[part_id] = true
		var info: Dictionary = part_info.call(part_id) if part_info.is_valid() else {}
		var tags: Array = info.get("tags", [])
		var bits: int = int(info.get("bits", 0))
		if _part_matches_system(sys_a, part_id, tags, bits):
			parts_a[part_id] = true
		if _part_matches_system(sys_b, part_id, tags, bits):
			parts_b[part_id] = true
	if ctx_a and not parts_b.is_empty():
		return true
	if ctx_b and not parts_a.is_empty():
		return true
	for pa in parts_a:
		for pb in parts_b:
			if pa != pb:
				return true
	return false


static func _part_matches_system(system: String, part_id: String, tags: Array, bits: int) -> bool:
	match system:
		"mass":
			return "mass" in tags
		"speed":
			return "speed" in tags
		"anchor":
			return "anchor" in tags
		"arc":
			return "arc" in tags or "chain" in tags
		"bounce":
			return ShotBits.has(bits, ShotBits.bit("bounce")) or "chain" in tags or "bounce" in tags
		"split":
			return ShotBits.has(bits, ShotBits.bit("split")) or "split" in tags
		"heat":
			return ShotBits.has(bits, ShotBits.bit("heat")) or "arc" in tags or "heat" in tags or part_id == "slag_furnace"
		"kinetic":
			return "kinetic" in tags or part_id in ["drop_weight", "fault_hammer", "ram_plow", "basalt_ram"]
		"pull":
			return ShotBits.has(bits, ShotBits.bit("pull")) or "anchor" in tags or "pull" in tags
		"consumable":
			return "consumable" in tags or part_id == "patch_tether"
		"active":
			return "active" in tags
		"orbital":
			return part_id in ["orbital_flywheel", "gyro_foundry"]
		"magnet":
			return part_id in ["magnet_spool", "magnet_coil", "scrap_gravity", "debt_collector"]
		"pierce":
			return ShotBits.has(bits, ShotBits.bit("pierce")) or "kinetic" in tags or part_id in ["helix_drill", "slag_pike", "horizon_optic"]
		"husk":
			return part_id in ["link_clips", "link_double"]
		"burden":
			return part_id in ["load_dividend", "debt_collector", "cracked_plating", "thin_pickings", "slack_coil"]
	return false


static func _context_has_system(system: String, context: Dictionary) -> bool:
	if context.is_empty():
		return false
	match system:
		"mass":
			return int(context.get("heft_class", 0)) >= 2 or float(context.get("mass", 0.0)) >= 120.0
		"pull":
			return bool(context.get("has_pull", false))
		"consumable":
			return bool(context.get("has_consumable", false))
		"active":
			return bool(context.get("has_active", false))
		"husk":
			return bool(context.get("has_husk", false))
		"burden":
			return int(context.get("burden_count", 0)) > 0 or bool(context.get("has_burden", false))
		_:
			return bool(context.get("has_" + system, false))
